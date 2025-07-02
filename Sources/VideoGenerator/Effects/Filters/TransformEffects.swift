import Foundation
@preconcurrency import CoreImage
import AVFoundation
import CoreGraphics

// MARK: - Scale Effect

public struct ScaleEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(scaleX: Float = 1.0, scaleY: Float = 1.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "scaleX": .float(scaleX),
            "scaleY": .float(scaleY)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let scaleX: Float = parameters["scaleX"] ?? 1.0
        let scaleY: Float = parameters["scaleY"] ?? 1.0
        
        let transform = CGAffineTransform(scaleX: CGFloat(scaleX), y: CGFloat(scaleY))
        return image.transformed(by: transform)
    }
}

// MARK: - Rotation Effect

public struct RotationEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(angle: Float = 0.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "angle": .float(angle)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let angle: Float = parameters["angle"] ?? 0.0
        
        let transform = CGAffineTransform(rotationAngle: CGFloat(angle))
        return image.transformed(by: transform)
    }
}

// MARK: - Translation Effect

public struct TranslationEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(x: Float = 0.0, y: Float = 0.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "x": .float(x),
            "y": .float(y)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let x: Float = parameters["x"] ?? 0.0
        let y: Float = parameters["y"] ?? 0.0
        
        let transform = CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y))
        return image.transformed(by: transform)
    }
}

// MARK: - Animated Rotation Effect

public struct AnimatedRotationEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(duration: Float = 1.0, rotations: Float = 1.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "duration": .float(duration),
            "rotations": .float(rotations)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let duration: Float = parameters["duration"] ?? 1.0
        let rotations: Float = parameters["rotations"] ?? 1.0
        
        let progress = Float(time.seconds) / duration
        let angle = progress * rotations * 2 * Float.pi
        
        let centerX = image.extent.midX
        let centerY = image.extent.midY
        
        var transform = CGAffineTransform(translationX: centerX, y: centerY)
        transform = transform.rotated(by: CGFloat(angle))
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        
        return image.transformed(by: transform)
    }
}