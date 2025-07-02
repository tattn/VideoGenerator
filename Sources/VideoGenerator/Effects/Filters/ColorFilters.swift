import Foundation
@preconcurrency import CoreImage
import AVFoundation

// MARK: - Brightness Effect

public struct BrightnessEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(brightness: Float = 0.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "brightness": .float(brightness)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let brightness: Float = parameters["brightness"] ?? 0.0
        
        return image.applyingFilter("CIColorControls", parameters: [
            "inputBrightness": brightness,
            "inputSaturation": 1.0,
            "inputContrast": 1.0
        ])
    }
}

// MARK: - Contrast Effect

public struct ContrastEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(contrast: Float = 1.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "contrast": .float(contrast)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let contrast: Float = parameters["contrast"] ?? 1.0
        
        return image.applyingFilter("CIColorControls", parameters: [
            "inputBrightness": 0.0,
            "inputSaturation": 1.0,
            "inputContrast": contrast
        ])
    }
}

// MARK: - Saturation Effect

public struct SaturationEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(saturation: Float = 1.0) {
        self.id = UUID()
        self.parameters = EffectParameters([
            "saturation": .float(saturation)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let saturation: Float = parameters["saturation"] ?? 1.0
        
        return image.applyingFilter("CIColorControls", parameters: [
            "inputBrightness": 0.0,
            "inputSaturation": saturation,
            "inputContrast": 1.0
        ])
    }
}