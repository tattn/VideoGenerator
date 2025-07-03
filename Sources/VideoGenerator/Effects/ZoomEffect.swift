import Foundation
import CoreMedia
import CoreImage

public struct ZoomEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    
    public init(id: UUID = UUID(), zoomFactor: Float = 1.5, centerX: Float = 0.5, centerY: Float = 0.5) {
        self.id = id
        self.parameters = EffectParameters([
            "zoomFactor": .float(zoomFactor),
            "centerX": .float(centerX),
            "centerY": .float(centerY)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let zoomFactor: Float = parameters["zoomFactor"] ?? 1.5
        let centerX: Float = parameters["centerX"] ?? 0.5
        let centerY: Float = parameters["centerY"] ?? 0.5
        
        let imageExtent = image.extent
        let centerPoint = CGPoint(
            x: imageExtent.width * CGFloat(centerX),
            y: imageExtent.height * CGFloat(centerY)
        )
        
        // Create transform for zoom effect
        // Scale the image up by zoomFactor
        let transform = CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
            .scaledBy(x: CGFloat(zoomFactor), y: CGFloat(zoomFactor))
            .translatedBy(x: -centerPoint.x, y: -centerPoint.y)
        
        // Apply transform - this will scale both pixel data and frame
        return image.transformed(by: transform)
    }
}

// Convenience initializers
extension ZoomEffect {
    public static func zoomIn(factor: Float = 1.5, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> ZoomEffect {
        ZoomEffect(zoomFactor: factor, centerX: Float(center.x), centerY: Float(center.y))
    }
    
    public static func zoomOut(factor: Float = 0.5, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> ZoomEffect {
        ZoomEffect(zoomFactor: factor, centerX: Float(center.x), centerY: Float(center.y))
    }
}

// Animated zoom effect
public struct AnimatedZoomEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    private let startZoom: Float
    private let endZoom: Float
    private let duration: CMTime
    
    public init(id: UUID = UUID(), 
                startZoom: Float = 1.0, 
                endZoom: Float = 1.5, 
                duration: CMTime,
                centerX: Float = 0.5, 
                centerY: Float = 0.5) {
        self.id = id
        self.startZoom = startZoom
        self.endZoom = endZoom
        self.duration = duration
        self.parameters = EffectParameters([
            "centerX": .float(centerX),
            "centerY": .float(centerY),
            "startZoom": .float(startZoom),
            "endZoom": .float(endZoom),
            "duration": .double(CMTimeGetSeconds(duration))
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Calculate progress (0.0 to 1.0)
        let progress = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
        let clampedProgress = max(0, min(1, progress))
        
        // Interpolate zoom factor
        let currentZoom = startZoom + (endZoom - startZoom) * clampedProgress
        
        // Create a static zoom effect with the current zoom factor
        let zoomEffect = ZoomEffect(
            id: UUID(),
            zoomFactor: currentZoom,
            centerX: parameters["centerX"] ?? 0.5,
            centerY: parameters["centerY"] ?? 0.5
        )
        
        return try await zoomEffect.apply(to: image, at: time, renderContext: renderContext)
    }
}

// Ken Burns effect (pan and zoom)
public struct KenBurnsEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    private let startRect: CGRect
    private let endRect: CGRect
    private let duration: CMTime
    
    public init(id: UUID = UUID(),
                startRect: CGRect,
                endRect: CGRect,
                duration: CMTime) {
        self.id = id
        self.startRect = startRect
        self.endRect = endRect
        self.duration = duration
        self.parameters = EffectParameters([
            "startRectX": .double(Double(startRect.origin.x)),
            "startRectY": .double(Double(startRect.origin.y)),
            "startRectWidth": .double(Double(startRect.width)),
            "startRectHeight": .double(Double(startRect.height)),
            "endRectX": .double(Double(endRect.origin.x)),
            "endRectY": .double(Double(endRect.origin.y)),
            "endRectWidth": .double(Double(endRect.width)),
            "endRectHeight": .double(Double(endRect.height)),
            "duration": .double(CMTimeGetSeconds(duration))
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Calculate progress
        let progress = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
        let clampedProgress = max(0, min(1, progress))
        
        // Interpolate between start and end rectangles
        let currentRect = CGRect(
            x: startRect.origin.x + (endRect.origin.x - startRect.origin.x) * CGFloat(clampedProgress),
            y: startRect.origin.y + (endRect.origin.y - startRect.origin.y) * CGFloat(clampedProgress),
            width: startRect.width + (endRect.width - startRect.width) * CGFloat(clampedProgress),
            height: startRect.height + (endRect.height - startRect.height) * CGFloat(clampedProgress)
        )
        
        let imageExtent = image.extent
        
        // Convert from normalized coordinates to actual image coordinates
        let actualRect = CGRect(
            x: currentRect.origin.x * imageExtent.width,
            y: currentRect.origin.y * imageExtent.height,
            width: currentRect.width * imageExtent.width,
            height: currentRect.height * imageExtent.height
        )
        
        // First, crop the image to the desired rectangle
        let croppedImage = image.cropped(to: actualRect)
        
        // Calculate the zoom factor based on the current rectangle
        // A smaller rectangle means more zoom (inverse relationship)
        let zoomFactor = 1.0 / currentRect.width // Assuming width and height scale proportionally
        
        // Calculate the new frame size after zoom
        let newWidth = imageExtent.width * zoomFactor
        let newHeight = imageExtent.height * zoomFactor
        
        // Calculate scale to reach the target size
        let scaleX = newWidth / actualRect.width
        let scaleY = newHeight / actualRect.height
        let scale = min(scaleX, scaleY) // Maintain aspect ratio
        
        // Create transform to scale the cropped image
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        
        // Apply transform - this will scale both pixel data and frame
        return croppedImage.transformed(by: transform)
    }
}

// Convenience initializers for Ken Burns effect
extension KenBurnsEffect {
    public static func zoomInPan(from startPoint: CGPoint, to endPoint: CGPoint, zoomFactor: CGFloat = 1.5, duration: CMTime) -> KenBurnsEffect {
        let startRect = CGRect(x: startPoint.x - 0.5, y: startPoint.y - 0.5, width: 1.0, height: 1.0)
        let endRect = CGRect(x: endPoint.x - 0.5 / zoomFactor, y: endPoint.y - 0.5 / zoomFactor, width: 1.0 / zoomFactor, height: 1.0 / zoomFactor)
        return KenBurnsEffect(startRect: startRect, endRect: endRect, duration: duration)
    }
    
    public static func zoomOutPan(from startPoint: CGPoint, to endPoint: CGPoint, zoomFactor: CGFloat = 0.5, duration: CMTime) -> KenBurnsEffect {
        let startRect = CGRect(x: startPoint.x - 0.5 * zoomFactor, y: startPoint.y - 0.5 * zoomFactor, width: zoomFactor, height: zoomFactor)
        let endRect = CGRect(x: endPoint.x - 0.5, y: endPoint.y - 0.5, width: 1.0, height: 1.0)
        return KenBurnsEffect(startRect: startRect, endRect: endRect, duration: duration)
    }
}