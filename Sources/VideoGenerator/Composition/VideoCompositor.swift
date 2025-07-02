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
        
        for effect in clip.effects {
            image = try await effect.apply(to: image, at: time, renderContext: renderContext)
        }
        
        return image
    }
    
    private func renderTextForClip(_ textItem: TextMediaItem, clip: Clip, canvasSize: CGSize) async throws -> CIImage {
        let paragraphStyle = createParagraphStyle(for: textItem)
        let attributes = createTextAttributes(for: textItem, paragraphStyle: paragraphStyle)
        let attributedString = NSAttributedString(string: textItem.text, attributes: attributes)
        
        let textBounds = calculateTextBounds(for: attributedString, textItem: textItem, clip: clip)
        let drawRect = calculateDrawRect(for: textItem, clip: clip, textBounds: textBounds, attributedString: attributedString)
        
        #if canImport(UIKit)
        // Create renderer with explicit scale of 1.0 to match pixel dimensions
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { context in
            drawText(textItem: textItem, attributes: attributes, drawRect: drawRect, targetFrame: clip.frame, textBounds: textBounds)
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
        
        drawText(textItem: textItem, attributes: attributes, drawRect: drawRect, targetFrame: clip.frame, textBounds: textBounds)
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = bitmap.cgImage else {
            return CIImage.black
        }
        
        return CIImage(cgImage: cgImage)
        #endif
    }
    
    private func createParagraphStyle(for textItem: TextMediaItem) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        // Set text alignment
        switch textItem.alignment {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        case .justified:
            paragraphStyle.alignment = .justified
        case .natural:
            paragraphStyle.alignment = .natural
        }
        
        // Set line break mode based on text behavior
        switch textItem.behavior {
        case .wrap:
            paragraphStyle.lineBreakMode = .byWordWrapping
        case .truncate:
            paragraphStyle.lineBreakMode = .byTruncatingTail
        case .autoScale:
            paragraphStyle.lineBreakMode = .byClipping // We'll handle scaling manually
        }
        
        return paragraphStyle
    }
            
    private func createTextAttributes(for textItem: TextMediaItem, paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        
        #if canImport(UIKit)
        attributes[.font] = textItem.font
        attributes[.foregroundColor] = UIColor(cgColor: textItem.color)
        
        // Add shadow if present
        if let shadow = textItem.shadow {
            let shadowObj = NSShadow()
            shadowObj.shadowColor = UIColor(cgColor: shadow.color)
            shadowObj.shadowOffset = shadow.offset
            shadowObj.shadowBlurRadius = shadow.blur
            attributes[.shadow] = shadowObj
        }
        #else
        attributes[.font] = textItem.font as NSFont
        attributes[.foregroundColor] = NSColor(cgColor: textItem.color) ?? NSColor.white
        
        // Add shadow if present
        if let shadow = textItem.shadow {
            let shadowObj = NSShadow()
            shadowObj.shadowColor = NSColor(cgColor: shadow.color) ?? NSColor.black
            shadowObj.shadowOffset = shadow.offset
            shadowObj.shadowBlurRadius = shadow.blur
            attributes[.shadow] = shadowObj
        }
        #endif
        
        return attributes
    }
            
    private func calculateTextBounds(for attributedString: NSAttributedString, textItem: TextMediaItem, clip: Clip) -> CGRect {
        switch textItem.behavior {
        case .wrap:
            // For wrapping, calculate bounds with frame width constraint
            return attributedString.boundingRect(
                with: CGSize(width: clip.frame.width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        case .truncate, .autoScale:
            // For truncate and autoScale, calculate unbounded size
            return attributedString.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
    }
            
    private func calculateDrawRect(for textItem: TextMediaItem, clip: Clip, textBounds: CGRect, attributedString: NSAttributedString) -> CGRect {
        let targetFrame = clip.frame
        var drawRect: CGRect
        
        // Calculate the actual text bounds based on behavior
        let actualTextBounds: CGRect
        if textItem.behavior == .wrap {
            // For wrapping, calculate with width constraint
            actualTextBounds = attributedString.boundingRect(
                with: CGSize(width: targetFrame.width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        } else {
            actualTextBounds = textBounds
        }
        
        // Calculate draw rect based on content mode
        switch clip.contentMode {
        case .scaleToFill:
            drawRect = targetFrame
            
        case .aspectFit, .aspectFill:
            // Center the text block within the frame
            if textItem.behavior == .wrap {
                // For wrap, use full width for drawing but the text alignment will handle horizontal centering
                let yOffset = targetFrame.minY + max(0, (targetFrame.height - actualTextBounds.height) / 2)
                drawRect = CGRect(x: targetFrame.minX, y: yOffset, width: targetFrame.width, height: min(actualTextBounds.height, targetFrame.height))
            } else if textItem.behavior != .autoScale {
                // For non-wrap, non-autoscale, center the text bounds
                let xOffset = targetFrame.minX + max(0, (targetFrame.width - actualTextBounds.width) / 2)
                let yOffset = targetFrame.minY + max(0, (targetFrame.height - actualTextBounds.height) / 2)
                drawRect = CGRect(x: xOffset, y: yOffset, width: min(actualTextBounds.width, targetFrame.width), height: min(actualTextBounds.height, targetFrame.height))
            } else {
                // For autoScale, use full frame for initial calculation
                drawRect = targetFrame
            }
        }
        
        return drawRect
    }
            
    private func drawText(textItem: TextMediaItem, attributes: [NSAttributedString.Key: Any], drawRect: CGRect, targetFrame: CGRect, textBounds: CGRect) {
        var finalAttributes = attributes
        var finalDrawRect = drawRect
            
        
        // Handle auto-scaling if needed
        if textItem.behavior == .autoScale && (textBounds.width > targetFrame.width || textBounds.height > targetFrame.height) {
            // Calculate scale factor to fit text within frame
            let widthScale = targetFrame.width / textBounds.width
            let heightScale = targetFrame.height / textBounds.height
            let scale = min(widthScale, heightScale)
            
            // Create scaled font
            let fontName = CTFontCopyName(textItem.font, kCTFontPostScriptNameKey) as String? ?? ".AppleSystemUIFont"
            let scaledFont = CTFont(fontName as CFString, size: CTFontGetSize(textItem.font) * scale)
            
            #if canImport(UIKit)
            finalAttributes[.font] = scaledFont
            #else
            finalAttributes[.font] = scaledFont as NSFont
            #endif
            
            // Update attributes for strokes
            let scaledAttributedString = NSAttributedString(string: textItem.text, attributes: finalAttributes)
            
            // Calculate scaled text bounds
            let scaledTextBounds = scaledAttributedString.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            // Center the scaled text
            let xOffset = targetFrame.minX + max(0, (targetFrame.width - scaledTextBounds.width) / 2)
            let yOffset = targetFrame.minY + max(0, (targetFrame.height - scaledTextBounds.height) / 2)
            finalDrawRect = CGRect(x: xOffset, y: yOffset, width: scaledTextBounds.width, height: scaledTextBounds.height)
            
            // Draw strokes with scaled attributes
            if !textItem.strokes.isEmpty {
                var strokeAttributes = finalAttributes
                strokeAttributes.removeValue(forKey: .shadow)
                
                for stroke in textItem.strokes.reversed() {
                    #if canImport(UIKit)
                    strokeAttributes[.strokeColor] = UIColor(cgColor: stroke.color)
                    #else
                    strokeAttributes[.strokeColor] = NSColor(cgColor: stroke.color) ?? NSColor.black
                    #endif
                    strokeAttributes[.strokeWidth] = -stroke.width * scale // Scale stroke width too
                    #if canImport(UIKit)
                    strokeAttributes[.font] = scaledFont
                    #else
                    strokeAttributes[.font] = scaledFont as NSFont
                    #endif
                    let strokeString = NSAttributedString(string: textItem.text, attributes: strokeAttributes)
                    strokeString.draw(in: finalDrawRect)
                }
            }
            
            // Draw scaled text
            scaledAttributedString.draw(in: finalDrawRect)
        } else {
            // Normal drawing without scaling
            let attributedString = NSAttributedString(string: textItem.text, attributes: finalAttributes)
            
            // Draw strokes from outer to inner (reverse order)
            if !textItem.strokes.isEmpty {
                // Remove shadow for stroke drawing
                var strokeAttributes = finalAttributes
                strokeAttributes.removeValue(forKey: .shadow)
                
                // Draw strokes in reverse order (largest to smallest)
                for stroke in textItem.strokes.reversed() {
                    #if canImport(UIKit)
                    strokeAttributes[.strokeColor] = UIColor(cgColor: stroke.color)
                    #else
                    strokeAttributes[.strokeColor] = NSColor(cgColor: stroke.color) ?? NSColor.black
                    #endif
                    strokeAttributes[.strokeWidth] = -stroke.width // Negative for outer stroke
                    let strokeString = NSAttributedString(string: textItem.text, attributes: strokeAttributes)
                    strokeString.draw(in: finalDrawRect)
                }
            }
            
            // Draw text in calculated rectangle (with shadow if present)
            attributedString.draw(in: finalDrawRect)
        }
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
