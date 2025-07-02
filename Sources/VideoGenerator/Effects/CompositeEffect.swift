import Foundation
@preconcurrency import CoreImage
import CoreMedia

/// A composite effect that combines multiple effects into a single effect
public struct CompositeEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    
    /// The effects to apply in order
    public let effects: [any Effect]
    
    /// How to blend between effects
    public let blendMode: BlendMode
    
    public init(id: UUID = UUID(),
                effects: [any Effect],
                blendMode: BlendMode = .sequential,
                parameters: EffectParameters = EffectParameters()) {
        self.id = id
        self.effects = effects
        self.blendMode = blendMode
        self.parameters = parameters
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        guard !effects.isEmpty else {
            return image
        }
        
        switch blendMode {
        case .sequential:
            return try await applySequential(to: image, at: time, renderContext: renderContext)
            
        case .parallel(let blendFunction):
            return try await applyParallel(to: image, at: time, renderContext: renderContext, blendFunction: blendFunction)
            
        case .custom(let processor):
            return try await processor(image, effects, time, renderContext)
        }
    }
    
    private func applySequential(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        var currentImage = image
        
        for effect in effects {
            currentImage = try await effect.apply(to: currentImage, at: time, renderContext: renderContext)
        }
        
        return currentImage
    }
    
    private func applyParallel(to image: CIImage, at time: CMTime, renderContext: any RenderContext, blendFunction: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage) async throws -> CIImage {
        guard effects.count >= 2 else {
            if let firstEffect = effects.first {
                return try await firstEffect.apply(to: image, at: time, renderContext: renderContext)
            }
            return image
        }
        
        // Apply all effects in parallel
        let results = try await withThrowingTaskGroup(of: CIImage.self) { group in
            for effect in effects {
                group.addTask {
                    try await effect.apply(to: image, at: time, renderContext: renderContext)
                }
            }
            
            var images: [CIImage] = []
            for try await result in group {
                images.append(result)
            }
            return images
        }
        
        // Blend all results together
        guard var blendedImage = results.first else {
            return image
        }
        
        for i in 1..<results.count {
            blendedImage = try await blendFunction(blendedImage, results[i], renderContext)
        }
        
        return blendedImage
    }
}

/// Defines how multiple effects are combined
public enum BlendMode: Sendable {
    /// Apply effects one after another
    case sequential
    
    /// Apply effects in parallel and blend results
    case parallel(blendFunction: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage)
    
    /// Custom processing logic
    case custom(processor: @Sendable (CIImage, [any Effect], CMTime, any RenderContext) async throws -> CIImage)
}

// MARK: - Effect Builder

/// A builder for creating composite effects with a fluent API
@MainActor
public final class EffectChain: Sendable {
    private var effects: [any Effect] = []
    private var blendMode: BlendMode = .sequential
    
    public init() {}
    
    /// Add an effect to the chain
    public func add(_ effect: any Effect) -> EffectChain {
        effects.append(effect)
        return self
    }
    
    /// Add multiple effects to the chain
    public func add(_ effects: [any Effect]) -> EffectChain {
        self.effects.append(contentsOf: effects)
        return self
    }
    
    /// Set the blend mode
    public func blendMode(_ mode: BlendMode) -> EffectChain {
        self.blendMode = mode
        return self
    }
    
    /// Build the composite effect
    public func build() -> CompositeEffect {
        CompositeEffect(effects: effects, blendMode: blendMode)
    }
}

// MARK: - Convenience Extensions

extension CompositeEffect {
    /// Create a composite effect that applies effects sequentially
    public static func sequential(_ effects: [any Effect]) -> CompositeEffect {
        CompositeEffect(effects: effects, blendMode: .sequential)
    }
    
    /// Create a composite effect that applies effects in parallel with a blend function
    public static func parallel(_ effects: [any Effect], 
                              blend: @escaping @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage) -> CompositeEffect {
        CompositeEffect(effects: effects, blendMode: .parallel(blendFunction: blend))
    }
}

// MARK: - Common Blend Functions

public enum BlendFunctions {
    /// Average blend - combines images with 50/50 opacity
    public static let average: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage = { image1, image2, context in
        // Using Core Image filters for blending
        guard let filter = CIFilter(name: "CISourceOverCompositing") else {
            return image1
        }
        let alphaImage = image2.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 1, y: 0, z: 0, w: 0.5) // Set alpha to 0.5
        ])
        filter.setValue(alphaImage, forKey: kCIInputImageKey)
        filter.setValue(image1, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? image1
    }
    
    /// Additive blend - adds pixel values
    public static let additive: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage = { image1, image2, context in
        guard let filter = CIFilter(name: "CIAdditionCompositing") else {
            return image1
        }
        filter.setValue(image2, forKey: kCIInputImageKey)
        filter.setValue(image1, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? image1
    }
    
    /// Multiply blend - multiplies pixel values
    public static let multiply: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage = { image1, image2, context in
        guard let filter = CIFilter(name: "CIMultiplyCompositing") else {
            return image1
        }
        filter.setValue(image2, forKey: kCIInputImageKey)
        filter.setValue(image1, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? image1
    }
    
    /// Screen blend - inverted multiply
    public static let screen: @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage = { image1, image2, context in
        guard let filter = CIFilter(name: "CIScreenBlendMode") else {
            return image1
        }
        filter.setValue(image2, forKey: kCIInputImageKey)
        filter.setValue(image1, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? image1
    }
}

// MARK: - Effect Combination Operators

extension Effect {
    /// Combine this effect with another sequentially
    public func then(_ other: any Effect) -> CompositeEffect {
        CompositeEffect.sequential([self, other])
    }
    
    /// Combine this effect with another in parallel
    public func parallel(with other: any Effect, 
                        blend: @escaping @Sendable (CIImage, CIImage, any RenderContext) async throws -> CIImage = BlendFunctions.average) -> CompositeEffect {
        CompositeEffect.parallel([self, other], blend: blend)
    }
}