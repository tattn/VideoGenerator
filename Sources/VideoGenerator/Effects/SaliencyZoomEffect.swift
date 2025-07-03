import Foundation
import CoreMedia
import CoreImage
import Vision

/// An effect that automatically zooms into the most salient (attention-grabbing) areas of an image or video frame
public struct SaliencyZoomEffect: Effect, Sendable {
    public let id: UUID
    public var parameters: EffectParameters
    
    private let zoomFactor: Float
    private let animationDuration: CMTime
    private let smoothness: Float
    private let useFineGrainedSaliency: Bool
    
    public init(
        id: UUID = UUID(),
        zoomFactor: Float = 1.8,
        animationDuration: CMTime = CMTime(seconds: 2.0, preferredTimescale: 600),
        smoothness: Float = 0.5,
        useFineGrainedSaliency: Bool = false
    ) {
        self.id = id
        self.zoomFactor = zoomFactor
        self.animationDuration = animationDuration
        self.smoothness = smoothness
        self.useFineGrainedSaliency = useFineGrainedSaliency
        
        self.parameters = EffectParameters([
            "zoomFactor": .float(zoomFactor),
            "animationDuration": .double(CMTimeGetSeconds(animationDuration)),
            "smoothness": .float(smoothness),
            "useFineGrainedSaliency": .bool(useFineGrainedSaliency)
        ])
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Detect salient region
        let salientRegion = try await detectSaliency(in: image)
        
        // Calculate animation progress
        let progress = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(animationDuration))
        let clampedProgress = max(0, min(1, progress))
        
        // Apply easing for smooth animation
        let easedProgress = easeInOutCubic(clampedProgress)
        
        // Interpolate zoom parameters
        let currentZoom = 1.0 + (zoomFactor - 1.0) * easedProgress
        
        // Calculate center point with smoothing
        let targetCenterX = Float(salientRegion.centerX)
        let targetCenterY = Float(salientRegion.centerY)
        
        // Blend between center of image and salient point based on smoothness
        let centerX = 0.5 + (targetCenterX - 0.5) * smoothness * easedProgress
        let centerY = 0.5 + (targetCenterY - 0.5) * smoothness * easedProgress
        
        // Apply zoom effect
        let zoomEffect = ZoomEffect(
            id: UUID(),
            zoomFactor: currentZoom,
            centerX: centerX,
            centerY: centerY
        )
        
        return try await zoomEffect.apply(to: image, at: time, renderContext: renderContext)
    }
    
    private func detectSaliency(in image: CIImage) async throws -> SalientRegion {
        // Convert CIImage to CGImage for Vision framework
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            throw VideoGeneratorError.renderingFailed
        }
        
        // Create saliency request
        let request: VNImageBasedRequest
        if useFineGrainedSaliency {
            request = VNGenerateAttentionBasedSaliencyImageRequest()
        } else {
            request = VNGenerateObjectnessBasedSaliencyImageRequest()
        }
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        // Process results
        guard let result = request.results?.first as? VNSaliencyImageObservation else {
            // If no saliency detected, return center of image
            return SalientRegion(centerX: 0.5, centerY: 0.5, confidence: 0.0)
        }
        
        // Find the most salient region
        let salientObjects = result.salientObjects ?? []
        
        if let mostSalient = salientObjects.max(by: { $0.confidence < $1.confidence }) {
            // Convert from Vision coordinate system (origin at bottom-left) to normalized coordinates
            let centerX = mostSalient.boundingBox.midX
            let centerY = 1.0 - mostSalient.boundingBox.midY // Flip Y coordinate
            
            return SalientRegion(
                centerX: centerX,
                centerY: centerY,
                confidence: mostSalient.confidence
            )
        } else {
            // If no specific salient objects, use the heat map to find the brightest area
            let pixelBuffer = result.pixelBuffer
            let brightestPoint = findBrightestPoint(in: pixelBuffer)
            return SalientRegion(
                centerX: brightestPoint.x,
                centerY: brightestPoint.y,
                confidence: 0.5
            )
        }
    }
    
    private func findBrightestPoint(in pixelBuffer: CVPixelBuffer) -> CGPoint {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var maxBrightness: UInt8 = 0
        var brightestX = width / 2
        var brightestY = height / 2
        
        // Sample every 4th pixel for performance
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let pixel = buffer[y * bytesPerRow + x]
                if pixel > maxBrightness {
                    maxBrightness = pixel
                    brightestX = x
                    brightestY = y
                }
            }
        }
        
        // Convert to normalized coordinates
        return CGPoint(
            x: CGFloat(brightestX) / CGFloat(width),
            y: 1.0 - (CGFloat(brightestY) / CGFloat(height)) // Flip Y coordinate
        )
    }
    
    private func easeInOutCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let p = 2 * t - 2
            return 1 + p * p * p / 2
        }
    }
}

private struct SalientRegion {
    let centerX: CGFloat
    let centerY: CGFloat
    let confidence: Float
}

// Convenience initializers
extension SaliencyZoomEffect {
    /// Creates a saliency zoom effect with attention-based detection (better for faces and objects)
    public static func attentionBased(
        zoomFactor: Float = 2.0,
        duration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)
    ) -> SaliencyZoomEffect {
        SaliencyZoomEffect(
            zoomFactor: zoomFactor,
            animationDuration: duration,
            smoothness: 0.7,
            useFineGrainedSaliency: true
        )
    }
    
    /// Creates a saliency zoom effect with objectness-based detection (better for general objects)
    public static func objectBased(
        zoomFactor: Float = 1.5,
        duration: CMTime = CMTime(seconds: 2.0, preferredTimescale: 600)
    ) -> SaliencyZoomEffect {
        SaliencyZoomEffect(
            zoomFactor: zoomFactor,
            animationDuration: duration,
            smoothness: 0.5,
            useFineGrainedSaliency: false
        )
    }
    
    /// Creates a subtle saliency zoom effect
    public static func subtle(duration: CMTime = CMTime(seconds: 4.0, preferredTimescale: 600)) -> SaliencyZoomEffect {
        SaliencyZoomEffect(
            zoomFactor: 1.3,
            animationDuration: duration,
            smoothness: 0.3,
            useFineGrainedSaliency: false
        )
    }
    
    /// Creates a dramatic saliency zoom effect
    public static func dramatic(duration: CMTime = CMTime(seconds: 1.5, preferredTimescale: 600)) -> SaliencyZoomEffect {
        SaliencyZoomEffect(
            zoomFactor: 2.5,
            animationDuration: duration,
            smoothness: 0.8,
            useFineGrainedSaliency: true
        )
    }
}