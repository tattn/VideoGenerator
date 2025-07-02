import Foundation
@preconcurrency import CoreImage
import AVFoundation

// MARK: - Transition Protocol

public protocol Transition: Sendable {
    var duration: CMTime { get }
    func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage
}

// MARK: - Fade Transition

public struct FadeTransition: Transition {
    public let duration: CMTime
    
    public init(duration: CMTime = CMTime(seconds: 1, preferredTimescale: 30)) {
        self.duration = duration
    }
    
    public func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage {
        let fromOpacity = 1.0 - progress
        let toOpacity = progress
        
        let fromImage = from.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(fromOpacity))
        ])
        
        let toImage = to.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(toOpacity))
        ])
        
        return toImage.composited(over: fromImage)
    }
}

// MARK: - Dissolve Transition

public struct DissolveTransition: Transition {
    public let duration: CMTime
    
    public init(duration: CMTime = CMTime(seconds: 1, preferredTimescale: 30)) {
        self.duration = duration
    }
    
    public func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage {
        return from.applyingFilter("CIDissolveTransition", parameters: [
            "inputTargetImage": to,
            "inputTime": progress
        ])
    }
}

// MARK: - Slide Transition

public enum SlideDirection: Sendable {
    case left
    case right
    case up
    case down
}

public struct SlideTransition: Transition {
    public let duration: CMTime
    public let direction: SlideDirection
    
    public init(duration: CMTime = CMTime(seconds: 1, preferredTimescale: 30), direction: SlideDirection = .left) {
        self.duration = duration
        self.direction = direction
    }
    
    public func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage {
        let size = await renderContext.size
        
        var fromTransform: CGAffineTransform = .identity
        var toTransform: CGAffineTransform = .identity
        
        switch direction {
        case .left:
            fromTransform = CGAffineTransform(translationX: -size.width * CGFloat(progress), y: 0)
            toTransform = CGAffineTransform(translationX: size.width * CGFloat(1 - progress), y: 0)
        case .right:
            fromTransform = CGAffineTransform(translationX: size.width * CGFloat(progress), y: 0)
            toTransform = CGAffineTransform(translationX: -size.width * CGFloat(1 - progress), y: 0)
        case .up:
            fromTransform = CGAffineTransform(translationX: 0, y: -size.height * CGFloat(progress))
            toTransform = CGAffineTransform(translationX: 0, y: size.height * CGFloat(1 - progress))
        case .down:
            fromTransform = CGAffineTransform(translationX: 0, y: size.height * CGFloat(progress))
            toTransform = CGAffineTransform(translationX: 0, y: -size.height * CGFloat(1 - progress))
        }
        
        let transformedFrom = from.transformed(by: fromTransform)
        let transformedTo = to.transformed(by: toTransform)
        
        return transformedTo.composited(over: transformedFrom)
    }
}

// MARK: - Wipe Transition

public struct WipeTransition: Transition {
    public let duration: CMTime
    public let direction: SlideDirection
    
    public init(duration: CMTime = CMTime(seconds: 1, preferredTimescale: 30), direction: SlideDirection = .left) {
        self.duration = duration
        self.direction = direction
    }
    
    public func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage {
        let size = await renderContext.size
        
        var cropRect: CGRect
        
        switch direction {
        case .left:
            cropRect = CGRect(x: 0, y: 0, width: size.width * CGFloat(progress), height: size.height)
        case .right:
            cropRect = CGRect(x: size.width * CGFloat(1 - progress), y: 0, width: size.width * CGFloat(progress), height: size.height)
        case .up:
            cropRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * CGFloat(progress))
        case .down:
            cropRect = CGRect(x: 0, y: size.height * CGFloat(1 - progress), width: size.width, height: size.height * CGFloat(progress))
        }
        
        let croppedTo = to.cropped(to: cropRect)
        return croppedTo.composited(over: from)
    }
}

// MARK: - Zoom Transition

public struct ZoomTransition: Transition {
    public let duration: CMTime
    
    public init(duration: CMTime = CMTime(seconds: 1, preferredTimescale: 30)) {
        self.duration = duration
    }
    
    public func blend(from: CIImage, to: CIImage, progress: Float, renderContext: any RenderContext) async throws -> CIImage {
        let scale = 1.0 + (2.0 * progress)
        let opacity = 1.0 - progress
        
        let centerX = from.extent.midX
        let centerY = from.extent.midY
        
        var transform = CGAffineTransform(translationX: centerX, y: centerY)
        transform = transform.scaledBy(x: CGFloat(scale), y: CGFloat(scale))
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        
        let scaledFrom = from.transformed(by: transform).applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
        ])
        
        let toImage = to.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(progress))
        ])
        
        return toImage.composited(over: scaledFrom)
    }
}