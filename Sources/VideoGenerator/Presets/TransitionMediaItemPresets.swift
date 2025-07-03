import AVFoundation
import CoreGraphics

/// Pre-configured transition presets for common scene transitions
public struct TransitionMediaItemPresets {
    
    // MARK: - Basic Transitions
    
    /// Simple fade to black transition
    public static func fadeToBlack(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .fade,
            parameters: TransitionParameters(
                color: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                easing: .easeInOut
            )
        )
    }
    
    /// Simple fade to white transition
    public static func fadeToWhite(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .fade,
            parameters: TransitionParameters(
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                easing: .easeInOut
            )
        )
    }
    
    /// Dissolve transition
    public static func dissolve(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .dissolve,
            parameters: TransitionParameters(easing: .linear)
        )
    }
    
    // MARK: - Directional Wipes
    
    /// Wipe from left to right
    public static func wipeRight(duration: CMTime = .init(seconds: 0.5, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeRight,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Wipe from right to left
    public static func wipeLeft(duration: CMTime = .init(seconds: 0.5, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeLeft,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Wipe from bottom to top
    public static func wipeUp(duration: CMTime = .init(seconds: 0.5, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeUp,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Wipe from top to bottom
    public static func wipeDown(duration: CMTime = .init(seconds: 0.5, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeDown,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Diagonal wipe
    public static func diagonalWipe(duration: CMTime = .init(seconds: 0.6, preferredTimescale: 600), angle: Double = 45) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeDiagonal,
            parameters: TransitionParameters(
                easing: .easeInOutQuad,
                angle: angle
            )
        )
    }
    
    /// Radial wipe
    public static func radialWipe(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .wipeRadial,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                angle: 0
            )
        )
    }
    
    // MARK: - Slide Transitions
    
    /// Slide to the left
    public static func slideLeft(duration: CMTime = .init(seconds: 0.75, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideLeft,
            parameters: TransitionParameters(easing: .easeInOutCubic)
        )
    }
    
    /// Slide to the right
    public static func slideRight(duration: CMTime = .init(seconds: 0.75, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideRight,
            parameters: TransitionParameters(easing: .easeInOutCubic)
        )
    }
    
    /// Slide upwards
    public static func slideUp(duration: CMTime = .init(seconds: 0.75, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideUp,
            parameters: TransitionParameters(easing: .easeInOutCubic)
        )
    }
    
    /// Slide downwards
    public static func slideDown(duration: CMTime = .init(seconds: 0.75, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideDown,
            parameters: TransitionParameters(easing: .easeInOutCubic)
        )
    }
    
    /// Slide with push effect
    public static func slidePush(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slidePush,
            parameters: TransitionParameters(easing: .easeInOutQuart)
        )
    }
    
    // MARK: - Geometric Transitions
    
    /// Circle expanding from center
    public static func circleExpand(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .circleExpand,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Circle contracting to center
    public static func circleContract(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .circleContract,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Rectangle expanding from center
    public static func rectangleExpand(duration: CMTime = .init(seconds: 0.7, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .rectangleExpand,
            parameters: TransitionParameters(easing: .easeInOutCubic)
        )
    }
    
    /// Diamond expanding from center
    public static func diamondExpand(duration: CMTime = .init(seconds: 0.9, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .diamondExpand,
            parameters: TransitionParameters(easing: .easeInOutQuad)
        )
    }
    
    /// Horizontal blinds
    public static func blindsHorizontal(duration: CMTime = .init(seconds: 1, preferredTimescale: 600), segments: Int = 10) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .blindsHorizontal,
            parameters: TransitionParameters(
                easing: .easeInOut,
                segments: segments
            )
        )
    }
    
    /// Vertical blinds
    public static func blindsVertical(duration: CMTime = .init(seconds: 1, preferredTimescale: 600), segments: Int = 10) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .blindsVertical,
            parameters: TransitionParameters(
                easing: .easeInOut,
                segments: segments
            )
        )
    }
    
    // MARK: - Advanced Effects
    
    /// Ripple effect
    public static func ripple(duration: CMTime = .init(seconds: 1.2, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .ripple,
            parameters: TransitionParameters(
                easing: .linear,
                intensity: 1.0
            )
        )
    }
    
    /// Swirl effect
    public static func swirl(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .swirl,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                intensity: 2.0
            )
        )
    }
    
    /// Pixelate effect
    public static func pixelate(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .pixelate,
            parameters: TransitionParameters(
                easing: .linear,
                intensity: 1.0
            )
        )
    }
    
    /// Mosaic effect
    public static func mosaic(duration: CMTime = .init(seconds: 1, preferredTimescale: 600), segments: Int = 20) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .mosaic,
            parameters: TransitionParameters(
                easing: .linear,
                segments: segments
            )
        )
    }
    
    /// Kaleidoscope effect
    public static func kaleidoscope(duration: CMTime = .init(seconds: 1.5, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .kaleidoscope,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                intensity: 1.0
            )
        )
    }
    
    /// Glitch effect
    public static func glitch(duration: CMTime = .init(seconds: 0.6, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .glitch,
            parameters: TransitionParameters(
                easing: .linear,
                intensity: 1.0
            )
        )
    }
    
    /// Shatter effect
    public static func shatter(duration: CMTime = .init(seconds: 1.2, preferredTimescale: 600), segments: Int = 10) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .shatter,
            parameters: TransitionParameters(
                easing: .easeInQuart,
                intensity: 1.0,
                segments: segments
            )
        )
    }
    
    /// Burn effect
    public static func burn(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .burn,
            parameters: TransitionParameters(easing: .linear)
        )
    }
    
    /// Page flip effect
    public static func pageFlip(duration: CMTime = .init(seconds: 1.5, preferredTimescale: 600), angle: Double = -90) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .pageFlip,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                angle: angle
            )
        )
    }
    
    // MARK: - Metal-based Effects
    
    /// Metal wave effect
    public static func metalWave(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalWave,
            parameters: TransitionParameters(
                easing: .easeInOutSine,
                intensity: 1.0
            )
        )
    }
    
    /// Metal twist effect
    public static func metalTwist(duration: CMTime = .init(seconds: 1.2, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalTwist,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                intensity: 2.0
            )
        )
    }
    
    /// Metal zoom blur effect
    public static func metalZoom(duration: CMTime = .init(seconds: 0.8, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalZoom,
            parameters: TransitionParameters(
                easing: .easeInOutQuad,
                intensity: 1.5
            )
        )
    }
    
    /// Metal morph effect
    public static func metalMorph(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalMorph,
            parameters: TransitionParameters(
                easing: .easeInOutBack,
                intensity: 1.0
            )
        )
    }
    
    /// Metal displace effect
    public static func metalDisplace(duration: CMTime = .init(seconds: 0.9, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalDisplace,
            parameters: TransitionParameters(
                easing: .easeInOutCubic,
                distortionAmount: 1.0
            )
        )
    }
    
    /// Metal liquid effect
    public static func metalLiquid(duration: CMTime = .init(seconds: 1.1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .metalLiquid,
            parameters: TransitionParameters(
                easing: .linear,
                intensity: 1.0
            )
        )
    }
    
    // MARK: - Dramatic Transitions
    
    /// Flash transition
    public static func flash(duration: CMTime = .init(seconds: 0.3, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .fade,
            parameters: TransitionParameters(
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                easing: .easeOutExpo
            )
        )
    }
    
    /// Slow dramatic fade
    public static func dramaticFade(duration: CMTime = .init(seconds: 2, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .fade,
            parameters: TransitionParameters(
                color: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                easing: .easeInQuart
            )
        )
    }
    
    /// Bounce effect
    public static func bounce(duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideLeft,
            parameters: TransitionParameters(easing: .bounce)
        )
    }
    
    /// Elastic effect
    public static func elastic(duration: CMTime = .init(seconds: 1.2, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .slideRight,
            parameters: TransitionParameters(easing: .easeOutElastic)
        )
    }
    
    // MARK: - Custom Transitions
    
    /// Custom fade to color
    public static func fadeToColor(_ color: CGColor, duration: CMTime = .init(seconds: 1, preferredTimescale: 600)) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: .fade,
            parameters: TransitionParameters(
                color: color,
                easing: .easeInOut
            )
        )
    }
    
    /// Custom transition with parameters
    public static func custom(
        type: TransitionType,
        duration: CMTime,
        parameters: TransitionParameters
    ) -> TransitionMediaItem {
        TransitionMediaItem(
            duration: duration,
            transitionType: type,
            parameters: parameters
        )
    }
}

// Add missing easing case
extension TransitionEasing {
    static let easeInOutSine = TransitionEasing.easeInOut // Alias for compatibility
}