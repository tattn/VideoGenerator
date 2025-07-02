import Foundation
import CoreMedia
import CoreImage

// MARK: - Effect Modifiers

/// Protocol for types that can modify effects
public protocol EffectModifier: Sendable {
    func modify(_ effect: any Effect) -> any Effect
}

// MARK: - Parameter Modifiers

/// Modifies effect parameters
public struct ParameterModifier: EffectModifier {
    public let key: String
    public let value: SendableValue
    
    public init(key: String, value: SendableValue) {
        self.key = key
        self.value = value
    }
    
    public func modify(_ effect: any Effect) -> any Effect {
        ModifiedEffect(base: effect, modifier: self)
    }
}

/// An effect with modified parameters
public struct ModifiedEffect: Effect, Sendable {
    public let id: UUID
    public let base: any Effect
    public let modifier: ParameterModifier
    
    public var parameters: EffectParameters {
        get {
            var storage = base.parameters.storageDict
            storage[modifier.key] = modifier.value
            return EffectParameters(storage)
        }
        set {
            // Parameters are read-only for modified effects
        }
    }
    
    init(base: any Effect, modifier: ParameterModifier) {
        self.id = UUID()
        self.base = base
        self.modifier = modifier
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        try await base.apply(to: image, at: time, renderContext: renderContext)
    }
}

// MARK: - Time-based Modifiers

/// Applies an effect only during a specific time range
public struct TimeRangeEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    public let base: any Effect
    public let timeRange: CMTimeRange
    
    public init(effect: any Effect, timeRange: CMTimeRange) {
        self.id = UUID()
        self.parameters = effect.parameters
        self.base = effect
        self.timeRange = timeRange
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        if timeRange.containsTime(time) {
            return try await base.apply(to: image, at: time, renderContext: renderContext)
        }
        return image
    }
}

/// Animates effect parameters over time
public struct AnimatedEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    public let base: any Effect
    public let animation: EffectAnimation
    
    public init(effect: any Effect, animation: EffectAnimation) {
        self.id = UUID()
        self.parameters = effect.parameters
        self.base = effect
        self.animation = animation
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Apply animation to parameters based on time
        let animatedParams = animation.parametersAt(time: time, baseParameters: parameters)
        
        // Create a modified effect with animated parameters
        let animatedEffect = ParameterEffect(base: base, parameters: animatedParams)
        return try await animatedEffect.apply(to: image, at: time, renderContext: renderContext)
    }
}

struct ParameterEffect: Effect {
    let base: any Effect
    var parameters: EffectParameters
    
    var id: UUID { base.id }
    
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        try await base.apply(to: image, at: time, renderContext: renderContext)
    }
}

/// Defines an animation for effect parameters
public struct EffectAnimation: Sendable {
    public let duration: CMTime
    public let keyframes: [Keyframe]
    public let interpolation: InterpolationType
    
    public init(duration: CMTime, keyframes: [Keyframe], interpolation: InterpolationType = .linear) {
        self.duration = duration
        self.keyframes = keyframes
        self.interpolation = interpolation
    }
    
    public func parametersAt(time: CMTime, baseParameters: EffectParameters) -> EffectParameters {
        // Calculate interpolated parameters based on keyframes
        // This is a simplified implementation
        baseParameters
    }
}

public struct Keyframe: Sendable {
    public let time: CMTime
    public let parameters: [String: SendableValue]
    
    public init(time: CMTime, parameters: [String: SendableValue]) {
        self.time = time
        self.parameters = parameters
    }
}

public enum InterpolationType: Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case cubic
}

// MARK: - Conditional Effects

/// Applies an effect based on a condition
public struct ConditionalEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    public let condition: @Sendable (CMTime, any RenderContext) async -> Bool
    public let trueEffect: any Effect
    public let falseEffect: (any Effect)?
    
    public init(condition: @escaping @Sendable (CMTime, any RenderContext) async -> Bool,
                then trueEffect: any Effect,
                else falseEffect: (any Effect)? = nil) {
        self.id = UUID()
        self.parameters = EffectParameters()
        self.condition = condition
        self.trueEffect = trueEffect
        self.falseEffect = falseEffect
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        if await condition(time, renderContext) {
            return try await trueEffect.apply(to: image, at: time, renderContext: renderContext)
        } else if let falseEffect = falseEffect {
            return try await falseEffect.apply(to: image, at: time, renderContext: renderContext)
        }
        return image
    }
}

// MARK: - Effect Extensions

extension Effect {
    /// Apply this effect only during a specific time range
    public func timeRange(_ range: CMTimeRange) -> TimeRangeEffect {
        TimeRangeEffect(effect: self, timeRange: range)
    }
    
    /// Animate this effect's parameters
    public func animated(with animation: EffectAnimation) -> AnimatedEffect {
        AnimatedEffect(effect: self, animation: animation)
    }
    
    /// Apply this effect conditionally
    public func when(_ condition: @escaping @Sendable (CMTime, any RenderContext) async -> Bool) -> ConditionalEffect {
        ConditionalEffect(condition: condition, then: self)
    }
    
    /// Modify a parameter
    public func parameter(_ key: String, value: SendableValue) -> any Effect {
        ModifiedEffect(base: self, modifier: ParameterModifier(key: key, value: value))
    }
}