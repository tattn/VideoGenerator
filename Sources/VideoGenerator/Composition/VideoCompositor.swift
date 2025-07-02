import Foundation
@preconcurrency import CoreImage
import AVFoundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - VideoCompositor

public actor VideoCompositor {
    private let ciContext: CIContext
    private let renderContext: DefaultRenderContext
    
    public init(size: CGSize, frameRate: Int = 30) async throws {
        self.ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false,
            .name: "VideoGeneratorContext"
        ])
        self.renderContext = DefaultRenderContext(size: size, frameRate: frameRate)
    }
    
    public func compose(timeline: Timeline, at time: CMTime) async throws -> CVPixelBuffer {
        await renderContext.setTime(time)
        
        // Use renderContext size (which should match export size) instead of timeline size
        let size = renderContext.size
        let backgroundColor = await timeline.backgroundColor
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as Any,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw VideoGeneratorError.pixelBufferCreationFailed
        }
        
        let baseImage = CIImage(color: CIColor(cgColor: backgroundColor))
            .cropped(to: CGRect(origin: .zero, size: size))
        
        var compositeImage = baseImage
        
        let tracks = await timeline.tracks
        
        // Render tracks in order they were added (first track = bottom layer, last track = top layer)
        for track in tracks where track.isEnabled {
            guard track.trackType == .video || track.trackType == .overlay else { continue }
            
            let clips = track.clips(at: time)
            for clip in clips {
                let clipImage = try await renderClip(clip, at: time)
                
                let opacity = Double(track.opacity ?? 1.0) * clip.opacity
                let blendedImage = clipImage.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ])
                
                compositeImage = blendedImage.composited(over: compositeImage)
            }
        }
        
        ciContext.render(compositeImage, to: buffer)
        return buffer
    }
    
    private func renderClip(_ clip: Clip, at time: CMTime) async throws -> CIImage {
        let mediaItem = clip.mediaItem
        var image: CIImage
        
        if mediaItem.mediaType == .video {
            image = try await extractVideoFrame(from: mediaItem as! VideoMediaItem, at: time)
        } else if mediaItem.mediaType == .text {
            // For text, render at timeline size and position will be handled in renderTextForClip
            let canvasSize = renderContext.size
            image = try await renderTextForClip(mediaItem as! TextMediaItem, clip: clip, canvasSize: canvasSize)
        } else {
            image = try await renderContext.image(for: mediaItem)
        }
        
        let frame = clip.frame
        let transform = clip.transform
        
        // Apply positioning and scaling only for non-text items
        if mediaItem.mediaType != .text {
            let imageSize = image.extent.size
            let targetFrame = frame
            
            switch clip.contentMode {
            case .scaleToFill:
                // Original behavior - scale to fill the entire frame
                image = image
                    .transformed(by: CGAffineTransform(scaleX: targetFrame.width / imageSize.width,
                                                      y: targetFrame.height / imageSize.height))
                    .transformed(by: CGAffineTransform(translationX: targetFrame.minX, y: targetFrame.minY))
                
            case .aspectFit:
                // Calculate scale to fit within frame while maintaining aspect ratio
                let widthScale = targetFrame.width / imageSize.width
                let heightScale = targetFrame.height / imageSize.height
                let scale = min(widthScale, heightScale)
                
                // Calculate size after scaling
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                
                // Center the scaled image within the frame
                let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
                let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
                
                image = image
                    .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
                
            case .aspectFill:
                // Calculate scale to fill frame while maintaining aspect ratio
                let widthScale = targetFrame.width / imageSize.width
                let heightScale = targetFrame.height / imageSize.height
                let scale = max(widthScale, heightScale)
                
                // Calculate size after scaling
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                
                // Center the scaled image within the frame
                let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
                let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
                
                image = image
                    .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    .transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
            }
        }
        
        // Apply clip transform
        image = image.transformed(by: transform)
        
        for effect in clip.effects {
            image = try await effect.apply(to: image, at: time, renderContext: renderContext)
        }
        
        return image
    }
    
    private func renderTextForClip(_ textItem: TextMediaItem, clip: Clip, canvasSize: CGSize) async throws -> CIImage {
        #if canImport(UIKit)
        // Create renderer with explicit scale of 1.0 to match pixel dimensions
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { context in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byTruncatingTail
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textItem.font,
                .foregroundColor: UIColor(cgColor: textItem.color),
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: textItem.text, attributes: attributes)
            
            // Calculate text bounds
            let textBounds = attributedString.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            let targetFrame = clip.frame
            var drawRect: CGRect
            
            switch clip.contentMode {
            case .scaleToFill:
                // Draw text to fill the entire frame
                drawRect = targetFrame
                
            case .aspectFit:
                // Scale text to fit within frame while maintaining aspect ratio
                let widthScale = targetFrame.width / textBounds.width
                let heightScale = targetFrame.height / textBounds.height
                let scale = min(widthScale, heightScale, 1.0) // Don't scale up beyond original size
                
                let scaledWidth = textBounds.width * scale
                let scaledHeight = textBounds.height * scale
                
                // Center the text within the frame
                let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
                let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
                
                drawRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
                
            case .aspectFill:
                // Scale text to fill frame while maintaining aspect ratio
                let widthScale = targetFrame.width / textBounds.width
                let heightScale = targetFrame.height / textBounds.height
                let scale = max(widthScale, heightScale)
                
                let scaledWidth = textBounds.width * scale
                let scaledHeight = textBounds.height * scale
                
                // Center the text within the frame
                let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
                let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
                
                drawRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
            }
            
            // Draw text in calculated rectangle
            attributedString.draw(in: drawRect)
        }
        
        return CIImage(image: image) ?? CIImage.black
        #else
        // Create bitmap representation with explicit scale factor of 1.0 to avoid retina scaling
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width),
            pixelsHigh: Int(canvasSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmap = bitmapRep else {
            return CIImage.black
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textItem.font as NSFont,
            .foregroundColor: NSColor(cgColor: textItem.color) ?? NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: textItem.text, attributes: attributes)
        
        // Calculate text bounds
        let textBounds = attributedString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        
        let targetFrame = clip.frame
        var drawRect: CGRect
        
        switch clip.contentMode {
        case .scaleToFill:
            // Draw text to fill the entire frame
            drawRect = targetFrame
            
        case .aspectFit:
            // Scale text to fit within frame while maintaining aspect ratio
            let widthScale = targetFrame.width / textBounds.width
            let heightScale = targetFrame.height / textBounds.height
            let scale = min(widthScale, heightScale, 1.0) // Don't scale up beyond original size
            
            let scaledWidth = textBounds.width * scale
            let scaledHeight = textBounds.height * scale
            
            // Center the text within the frame
            let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
            let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
            
            drawRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
            
        case .aspectFill:
            // Scale text to fill frame while maintaining aspect ratio
            let widthScale = targetFrame.width / textBounds.width
            let heightScale = targetFrame.height / textBounds.height
            let scale = max(widthScale, heightScale)
            
            let scaledWidth = textBounds.width * scale
            let scaledHeight = textBounds.height * scale
            
            // Center the text within the frame
            let xOffset = targetFrame.minX + (targetFrame.width - scaledWidth) / 2
            let yOffset = targetFrame.minY + (targetFrame.height - scaledHeight) / 2
            
            drawRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
        }
        
        // Draw text in calculated rectangle
        attributedString.draw(in: drawRect)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = bitmap.cgImage else {
            return CIImage.black
        }
        
        return CIImage(cgImage: cgImage)
        #endif
    }
    
    private func extractVideoFrame(from videoItem: VideoMediaItem, at time: CMTime) async throws -> CIImage {
        let asset = AVAsset(url: videoItem.url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        return CIImage(cgImage: cgImage)
    }
}

// MARK: - Error Types

public enum VideoGeneratorError: LocalizedError {
    case pixelBufferCreationFailed
    case videoFrameExtractionFailed
    case renderingFailed
    case unsupportedMediaType
    case metalNotAvailable
    case metalResourceCreationFailed
    case textureCreationFailed
    
    public var errorDescription: String? {
        switch self {
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .videoFrameExtractionFailed:
            return "Failed to extract video frame"
        case .renderingFailed:
            return "Failed to render frame"
        case .unsupportedMediaType:
            return "Unsupported media type"
        case .metalNotAvailable:
            return "Metal is not available on this device"
        case .metalResourceCreationFailed:
            return "Failed to create Metal resources"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        }
    }
}
