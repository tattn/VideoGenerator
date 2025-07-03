import Foundation
import AVFoundation
import CoreGraphics

/// A media item that represents a transition effect
public struct TransitionMediaItem: MediaItem, Sendable {
    public let id: UUID
    public let duration: CMTime
    public let mediaType: MediaType = .shape // Use shape type for now
    
    /// The type of transition effect
    public let transitionType: TransitionType
    
    /// Parameters for the transition
    public let parameters: TransitionParameters
    
    public init(
        id: UUID = UUID(),
        duration: CMTime,
        transitionType: TransitionType,
        parameters: TransitionParameters = TransitionParameters()
    ) {
        self.id = id
        self.duration = duration
        self.transitionType = transitionType
        self.parameters = parameters
    }
}

/// Types of transition effects
public enum TransitionType: String, CaseIterable, Sendable {
    // Basic transitions
    case fade = "fade"
    case dissolve = "dissolve"
    
    // Directional wipes
    case wipeLeft = "wipeLeft"
    case wipeRight = "wipeRight"
    case wipeUp = "wipeUp"
    case wipeDown = "wipeDown"
    case wipeRadial = "wipeRadial"
    case wipeDiagonal = "wipeDiagonal"
    
    // Slides
    case slideLeft = "slideLeft"
    case slideRight = "slideRight"
    case slideUp = "slideUp"
    case slideDown = "slideDown"
    case slidePush = "slidePush"
    
    // Geometric transitions
    case circleExpand = "circleExpand"
    case circleContract = "circleContract"
    case rectangleExpand = "rectangleExpand"
    case diamondExpand = "diamondExpand"
    case blindsHorizontal = "blindsHorizontal"
    case blindsVertical = "blindsVertical"
    
    // Advanced effects
    case ripple = "ripple"
    case swirl = "swirl"
    case pixelate = "pixelate"
    case mosaic = "mosaic"
    case kaleidoscope = "kaleidoscope"
    case glitch = "glitch"
    case shatter = "shatter"
    case burn = "burn"
    case pageFlip = "pageFlip"
    
    // Metal-based effects
    case metalWave = "metalWave"
    case metalTwist = "metalTwist"
    case metalZoom = "metalZoom"
    case metalMorph = "metalMorph"
    case metalDisplace = "metalDisplace"
    case metalLiquid = "metalLiquid"
}

/// Parameters for configuring transition effects
public struct TransitionParameters: Sendable {
    /// Color for the transition (used in wipes, fades)
    public var color: CGColor
    
    /// Easing function for the transition animation
    public var easing: TransitionEasing
    
    /// Direction angle for diagonal transitions (in degrees)
    public var angle: Double
    
    /// Intensity of the effect (0.0 to 1.0)
    public var intensity: Double
    
    /// Number of segments for blinds, mosaic effects
    public var segments: Int
    
    /// Blur amount for certain transitions
    public var blurAmount: Double
    
    /// Distortion amount for advanced effects
    public var distortionAmount: Double
    
    /// Custom parameters for specific effects
    public var customParameters: [String: Double]
    
    public init(
        color: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        easing: TransitionEasing = .linear,
        angle: Double = 45,
        intensity: Double = 1.0,
        segments: Int = 10,
        blurAmount: Double = 0,
        distortionAmount: Double = 1.0,
        customParameters: [String: Double] = [:]
    ) {
        self.color = color
        self.easing = easing
        self.angle = angle
        self.intensity = intensity
        self.segments = segments
        self.blurAmount = blurAmount
        self.distortionAmount = distortionAmount
        self.customParameters = customParameters
    }
}

/// Easing functions for transition animations
public enum TransitionEasing: String, CaseIterable, Sendable {
    case linear = "linear"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case easeInOut = "easeInOut"
    case easeInQuad = "easeInQuad"
    case easeOutQuad = "easeOutQuad"
    case easeInOutQuad = "easeInOutQuad"
    case easeInCubic = "easeInCubic"
    case easeOutCubic = "easeOutCubic"
    case easeInOutCubic = "easeInOutCubic"
    case easeInQuart = "easeInQuart"
    case easeOutQuart = "easeOutQuart"
    case easeInOutQuart = "easeInOutQuart"
    case easeInExpo = "easeInExpo"
    case easeOutExpo = "easeOutExpo"
    case easeInOutExpo = "easeInOutExpo"
    case easeInCirc = "easeInCirc"
    case easeOutCirc = "easeOutCirc"
    case easeInOutCirc = "easeInOutCirc"
    case easeInBack = "easeInBack"
    case easeOutBack = "easeOutBack"
    case easeInOutBack = "easeInOutBack"
    case easeInElastic = "easeInElastic"
    case easeOutElastic = "easeOutElastic"
    case easeInOutElastic = "easeInOutElastic"
    case bounce = "bounce"
}