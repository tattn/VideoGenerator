import Foundation
import CoreImage
import CoreGraphics
import AVFoundation

/// Camera shake effect that simulates handheld camera movement
public struct CameraShakeEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    
    /// Initialize with default parameters
    public init(
        intensity: Float = 10.0,
        frequency: Float = 30.0,
        smoothness: Float = 0.8,
        rotationIntensity: Float = 0.5
    ) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "intensity": .float(intensity),
            "frequency": .float(frequency),
            "smoothness": .float(smoothness),
            "rotationIntensity": .float(rotationIntensity)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let intensity: Float = parameters["intensity"] ?? 10.0
        let frequency: Float = parameters["frequency"] ?? 30.0
        let smoothness: Float = parameters["smoothness"] ?? 0.8
        let rotationIntensity: Float = parameters["rotationIntensity"] ?? 0.5
        
        // Convert time to seconds
        let timeInSeconds = Float(time.seconds)
        
        // Generate smooth random values using multiple sine waves
        let shakeX = generateSmoothNoise(time: timeInSeconds, frequency: frequency, seed: 1.0) * intensity
        let shakeY = generateSmoothNoise(time: timeInSeconds, frequency: frequency * 0.7, seed: 2.0) * intensity
        let rotation = generateSmoothNoise(time: timeInSeconds, frequency: frequency * 0.5, seed: 3.0) * rotationIntensity
        
        // Apply low-pass filter for smoothness
        let smoothedX = shakeX * smoothness
        let smoothedY = shakeY * smoothness
        let smoothedRotation = rotation * smoothness
        
        // Create transform
        var transform = CGAffineTransform.identity
        
        // Apply rotation around center
        let imageBounds = image.extent
        let centerX = imageBounds.midX
        let centerY = imageBounds.midY
        
        transform = transform.translatedBy(x: centerX, y: centerY)
        transform = transform.rotated(by: CGFloat(smoothedRotation * .pi / 180))
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        
        // Apply translation
        transform = transform.translatedBy(x: CGFloat(smoothedX), y: CGFloat(smoothedY))
        
        // Apply transform to image
        let transformedImage = image.transformed(by: transform)
        
        // Create a background to ensure the output fills the entire extent
        let backgroundImage = CIImage(color: .clear).cropped(to: imageBounds)
        
        // Composite the transformed image over the background
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
        compositeFilter.setValue(transformedImage, forKey: kCIInputImageKey)
        compositeFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
        
        // Crop to original bounds to maintain exact dimensions
        return compositeFilter.outputImage!.cropped(to: imageBounds)
    }
    
    /// Generate smooth noise using layered sine waves
    private func generateSmoothNoise(time: Float, frequency: Float, seed: Float) -> Float {
        // Layer multiple sine waves with different frequencies for organic movement
        let wave1 = sin(time * frequency * 0.1 + seed * 100)
        let wave2 = sin(time * frequency * 0.3 + seed * 200) * 0.5
        let wave3 = sin(time * frequency * 0.7 + seed * 300) * 0.25
        let wave4 = sin(time * frequency * 1.3 + seed * 400) * 0.125
        
        // Combine waves
        let combined = wave1 + wave2 + wave3 + wave4
        
        // Add some randomness
        let randomComponent = sin(time * frequency * 2.1 + seed * 500) * 0.1
        
        return combined + randomComponent
    }
}

// MARK: - Convenience Extensions

public extension CameraShakeEffect {
    /// Subtle handheld camera movement
    static var subtle: CameraShakeEffect {
        CameraShakeEffect(
            intensity: 3.0,
            frequency: 15.0,
            smoothness: 0.9,
            rotationIntensity: 0.2
        )
    }
    
    /// Medium camera shake
    static var medium: CameraShakeEffect {
        CameraShakeEffect(
            intensity: 10.0,
            frequency: 30.0,
            smoothness: 0.8,
            rotationIntensity: 0.5
        )
    }
    
    /// Intense camera shake (like an earthquake or explosion)
    static var intense: CameraShakeEffect {
        CameraShakeEffect(
            intensity: 25.0,
            frequency: 60.0,
            smoothness: 0.6,
            rotationIntensity: 1.5
        )
    }
    
    /// Documentary-style handheld camera
    static var documentary: CameraShakeEffect {
        CameraShakeEffect(
            intensity: 5.0,
            frequency: 8.0,
            smoothness: 0.95,
            rotationIntensity: 0.3
        )
    }
    
    /// Action scene camera shake
    static var action: CameraShakeEffect {
        CameraShakeEffect(
            intensity: 15.0,
            frequency: 45.0,
            smoothness: 0.7,
            rotationIntensity: 0.8
        )
    }
}