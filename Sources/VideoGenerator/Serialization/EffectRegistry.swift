import Foundation
import AVFoundation
import CoreImage

// MARK: - EffectRegistry

public actor EffectRegistry {
    public static let shared = EffectRegistry()
    
    private var effectFactories: [String: EffectFactory] = [:]
    private var effectTypeMapping: [ObjectIdentifier: String] = [:]
    
    private init() {
        Task {
            await registerBuiltInEffects()
        }
    }
    
    public func ensureInitialized() async {
        // Wait for initialization if needed
        _ = await effectFactories.count
    }
    
    // MARK: - Registration
    
    public func register<T: Effect>(
        _ effectType: T.Type,
        identifier: String,
        factory: @escaping (UUID, EffectParameters) async throws -> T
    ) {
        let wrappedFactory = EffectFactory { id, parameters in
            try await factory(id, parameters)
        }
        effectFactories[identifier] = wrappedFactory
        effectTypeMapping[ObjectIdentifier(effectType)] = identifier
    }
    
    // MARK: - Effect Creation
    
    public func createEffect(
        type: String,
        id: UUID = UUID(),
        parameters: EffectParameters = EffectParameters()
    ) async throws -> (any Effect)? {
        guard let factory = effectFactories[type] else {
            return nil
        }
        return try await factory.create(id, parameters)
    }
    
    // MARK: - Type Identification
    
    public func effectType(for effect: any Effect) -> String {
        let typeId = ObjectIdentifier(type(of: effect))
        
        // Check registered types first
        if let registered = effectTypeMapping[typeId] {
            return registered
        }
        
        // Fallback to type name
        return String(describing: type(of: effect))
    }
    
    // MARK: - Built-in Effects Registration
    
    private func registerBuiltInEffects() {
        // Brightness Effect
        register(BrightnessEffect.self, identifier: "brightness") { id, parameters in
            var effect = BrightnessEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Contrast Effect
        register(ContrastEffect.self, identifier: "contrast") { id, parameters in
            var effect = ContrastEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Saturation Effect
        register(SaturationEffect.self, identifier: "saturation") { id, parameters in
            var effect = SaturationEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Gaussian Blur Effect
        register(GaussianBlurEffect.self, identifier: "gaussianBlur") { id, parameters in
            var effect = GaussianBlurEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Motion Blur Effect
        register(MotionBlurEffect.self, identifier: "motionBlur") { id, parameters in
            var effect = MotionBlurEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Scale Effect
        register(ScaleEffect.self, identifier: "scale") { id, parameters in
            var effect = ScaleEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Rotation Effect
        register(RotationEffect.self, identifier: "rotation") { id, parameters in
            var effect = RotationEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Zoom Effect
        register(ZoomEffect.self, identifier: "zoom") { id, parameters in
            var effect = ZoomEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Camera Shake Effect
        register(CameraShakeEffect.self, identifier: "cameraShake") { id, parameters in
            var effect = CameraShakeEffect()
            effect.parameters = parameters
            return effect
        }
        
        // Composite Effect
        register(CompositeEffect.self, identifier: "composite") { id, parameters in
            // Composite effects need special handling for nested effects
            CompositeEffect(effects: [])
        }
    }
}

// MARK: - EffectFactory

private struct EffectFactory {
    let create: (UUID, EffectParameters) async throws -> any Effect
}