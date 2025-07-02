import Foundation
@preconcurrency import CoreImage
import AVFoundation

// MARK: - Gaussian Blur Effect

public struct GaussianBlurEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(radius: Float = 10.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "radius": .float(radius)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let radius: Float = parameters["radius"] ?? 10.0
        
        return image.applyingFilter("CIGaussianBlur", parameters: [
            "inputRadius": radius
        ]).cropped(to: image.extent)
    }
}

// MARK: - Motion Blur Effect

public struct MotionBlurEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(radius: Float = 20.0, angle: Float = 0.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "radius": .float(radius),
            "angle": .float(angle)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let radius: Float = parameters["radius"] ?? 20.0
        let angle: Float = parameters["angle"] ?? 0.0
        
        return image.applyingFilter("CIMotionBlur", parameters: [
            "inputRadius": radius,
            "inputAngle": angle
        ]).cropped(to: image.extent)
    }
}

// MARK: - Box Blur Effect

public struct BoxBlurEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(radius: Float = 10.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "radius": .float(radius)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let radius: Float = parameters["radius"] ?? 10.0
        
        return image.applyingFilter("CIBoxBlur", parameters: [
            "inputRadius": radius
        ]).cropped(to: image.extent)
    }
}