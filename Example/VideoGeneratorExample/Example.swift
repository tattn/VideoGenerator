import VideoGenerator
import Foundation
import CoreGraphics
import CoreText
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif
import AVFoundation

// Example: Creating a video with various elements

@MainActor
func createExampleVideo(to outputURL: URL) async throws {
    // Create a timeline with TikTok vertical resolution (9:16)
    let timeline = Timeline(
        size: CGSize(width: 1080, height: 1920),
        frameRate: 30,
        backgroundColor: CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    )

    // Create tracks
    var videoTrack = Track(id: UUID(), trackType: .video, clips: [], isEnabled: true)
    var overlayTrack = Track(id: UUID(), trackType: .overlay, clips: [], isEnabled: true)
    
    // Add a gradient background for TikTok-style aesthetic
    let gradientImage = createGradientImage(
        topColor: CGColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0),
        bottomColor: CGColor(red: 0.8, green: 0.3, blue: 0.5, alpha: 1.0),
        size: timeline.size
    )
    let backgroundClip = Clip(
        mediaItem: .image(gradientImage, duration: CMTime(seconds: 10, preferredTimescale: 30)),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 30)),
        frame: CGRect(origin: .zero, size: timeline.size)
    )
    videoTrack.clips.append(backgroundClip)
    
    // Add animated text overlay (positioned for vertical video)
    let titleClip = Clip(
        mediaItem: .text(
            "Video Generator Demo",
            font: CTFont(.system, size: 80),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ),
        timeRange: CMTimeRange(
            start: CMTime(seconds: 1, preferredTimescale: 30),
            duration: CMTime(seconds: 4, preferredTimescale: 30)
        ),
        frame: CGRect(x: 0, y: 0, width: timeline.size.width, height: timeline.size.height),
        transform: .identity,
        effects: [
            CameraShakeEffect.subtle
        ],
        opacity: 0.9
    )
    overlayTrack.clips.append(titleClip)
    
    // Add subtitle text
    let subtitleClip = Clip(
        mediaItem: .text(
            "Creating amazing videos with Swift",
            font: CTFont(.system, size: 64),
            color: CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        ),
        timeRange: CMTimeRange(
            start: CMTime(seconds: 2, preferredTimescale: 30),
            duration: CMTime(seconds: 3, preferredTimescale: 30)
        ),
        frame: CGRect(x: 0, y: 400, width: timeline.size.width, height: 100),
        transform: .identity,
        opacity: 0.8
    )
    overlayTrack.clips.append(subtitleClip)
    
    // Add some animated shapes
    let shapeImage = createCircleImage(
        color: CGColor(red: 1, green: 0.5, blue: 0.2, alpha: 0.8),
        size: CGSize(width: 200, height: 200)
    )
    let shapeClip1 = Clip(
        mediaItem: .image(shapeImage, duration: CMTime(seconds: 5, preferredTimescale: 30)),
        timeRange: CMTimeRange(
            start: CMTime(seconds: 5, preferredTimescale: 30),
            duration: CMTime(seconds: 5, preferredTimescale: 30)
        ),
        frame: CGRect(x: 0, y: 800, width: 200, height: 200),
        transform: .identity, // CGAffineTransform(rotationAngle: .pi / 4),
        opacity: 0.7
    )
    overlayTrack.clips.append(shapeClip1)
    
    // Add another shape with different color
    let shapeImage2 = createCircleImage(
        color: CGColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 0.8),
        size: CGSize(width: 150, height: 150)
    )
    let shapeClip2 = Clip(
        mediaItem: .image(shapeImage2, duration: CMTime(seconds: 5, preferredTimescale: 30)),
        timeRange: CMTimeRange(
            start: CMTime(seconds: 5, preferredTimescale: 30),
            duration: CMTime(seconds: 5, preferredTimescale: 30)
        ),
        frame: CGRect(x: 0, y: 1200, width: 150, height: 150),
        transform: .identity, // CGAffineTransform(rotationAngle: -.pi / 6),
        opacity: 0.7
    )
    overlayTrack.clips.append(shapeClip2)
    
    // Add end text
    let endTextClip = Clip(
        mediaItem: .text(
            "Thank You!",
            font: CTFont(.system, size: 72),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ),
        timeRange: CMTimeRange(
            start: CMTime(seconds: 7, preferredTimescale: 30),
            duration: CMTime(seconds: 3, preferredTimescale: 30)
        ),
        frame: CGRect(x: 0, y: 860, width: timeline.size.width, height: 200),
        transform: .identity,
        opacity: 1.0
    )
    overlayTrack.clips.append(endTextClip)
    
    // Add tracks to timeline
    timeline.addTrack(videoTrack)
    timeline.addTrack(overlayTrack)
    timeline.updateDuration()
    
    // Create exporter and export
    let exporter = try await VideoExporter()
    let exportSettings = ExportSettings(
        outputURL: outputURL,
        videoCodec: .h264,
        resolution: timeline.size,
        bitrate: 8_000_000,
        frameRate: timeline.frameRate,
        preset: .high
    )
    
    // Export with progress tracking
    Task {
        for await progress in await exporter.progress {
            print("Export progress: \(Int(progress.progress * 100))%")
        }
    }
    
    let exportedURL = try await exporter.export(timeline: timeline, settings: exportSettings)
    print("Video exported successfully to: \(exportedURL)")
}

// Helper function to create a solid color image
func createColorImage(color: CGColor, size: CGSize) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    
    context.setFillColor(color)
    context.fill(CGRect(origin: .zero, size: size))
    
    return context.makeImage()!
}

// Helper function to create a gradient image
func createGradientImage(topColor: CGColor, bottomColor: CGColor, size: CGSize) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0, 1]
    )!
    
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: 0, y: size.height),
        options: []
    )
    
    return context.makeImage()!
}

// Helper function to create a circle image
func createCircleImage(color: CGColor, size: CGSize) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    
    // Clear background
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
    context.fill(CGRect(origin: .zero, size: size))
    
    // Draw circle
    context.setFillColor(color)
    let circleRect = CGRect(
        x: size.width * 0.1,
        y: size.height * 0.1,
        width: size.width * 0.8,
        height: size.height * 0.8
    )
    context.fillEllipse(in: circleRect)
    
    return context.makeImage()!
}
