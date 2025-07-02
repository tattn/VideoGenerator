import Foundation
import VideoGenerator
import AVFoundation
import CoreImage
import CoreGraphics
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Example Usage

@main
struct VideoGeneratorExample {
    static func main() async {
        do {
            print("🎬 VideoGenerator Example Started")
            
            // Create a sample video
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("example_output.mp4")
            
            try await createSampleVideo(outputURL: outputURL)
            
            print("✅ Video created successfully at: \(outputURL.path)")
            print("🎥 Video generation completed!")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    static func createSampleVideo(outputURL: URL) async throws {
        // Create timeline with 1080p resolution at 30fps
        let timeline = await Timeline(
            size: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            backgroundColor: CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        )
        
        // Create video track
        var videoTrack = Track(trackType: .video, isEnabled: true)
        
        // Add a colored background clip
        let backgroundImage = createColoredImage(
            color: CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0),
            size: await timeline.size
        )
        
        if let backgroundImage = backgroundImage {
            let backgroundClip = Clip(
                mediaItem: .image(backgroundImage, duration: CMTime(seconds: 10, preferredTimescale: 30)),
                timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 30)),
                frame: CGRect(origin: .zero, size: await timeline.size)
            )
            videoTrack.clips.append(backgroundClip)
        }
        
        // Create overlay track for text
        var overlayTrack = Track(trackType: .overlay, isEnabled: true)
        
        // Add title text
        let titleClip = Clip(
            mediaItem: .text(
                "VideoGenerator",
                font: CTFont(.system, size: 80),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            ),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 30)),
            frame: CGRect(x: 0, y: 400, width: 1920, height: 200),
            effects: [
                AnimatedRotationEffect(duration: 5.0, rotations: 0.5),
                GaussianBlurEffect(radius: 0)
            ],
            opacity: 1.0
        )
        overlayTrack.clips.append(titleClip)
        
        // Add subtitle text with fade effect
        let subtitleClip = Clip(
            mediaItem: .text(
                "iOS & macOS Video Generation",
                font: CTFont(.system, size: 48),
                color: CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
            ),
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), duration: CMTime(seconds: 6, preferredTimescale: 30)),
            frame: CGRect(x: 0, y: 600, width: 1920, height: 100)
        )
        overlayTrack.clips.append(subtitleClip)
        
        // Add animated shapes using images
        if let circleImage = createCircleImage(radius: 100, color: CGColor(red: 1, green: 0.5, blue: 0.2, alpha: 0.8)) {
            let movingCircle = Clip(
                mediaItem: .image(circleImage, duration: CMTime(seconds: 8, preferredTimescale: 30)),
                timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 30), duration: CMTime(seconds: 8, preferredTimescale: 30)),
                frame: CGRect(x: 100, y: 100, width: 200, height: 200),
                effects: [
                    TranslationEffect(x: 800, y: 400),
                    ScaleEffect(scaleX: 2.0, scaleY: 2.0)
                ],
                opacity: 0.7
            )
            overlayTrack.clips.append(movingCircle)
        }
        
        // Add audio track (optional - for demonstration)
        // In real usage, you would load an actual audio file
        var audioTrack = Track(trackType: .audio, isEnabled: true, volume: 1.0)
        
        // Add tracks to timeline
        await timeline.addTrack(videoTrack)
        await timeline.addTrack(overlayTrack)
        await timeline.addTrack(audioTrack)
        
        // Create exporter and export video
        let exporter = try await VideoExporter()
        
        let exportSettings = ExportSettings(
            outputURL: outputURL,
            videoCodec: .h264,
            audioCodec: .aac,
            resolution: await timeline.size,
            frameRate: await timeline.frameRate,
            preset: .high
        )
        
        // Monitor export progress
        Task {
            for await progress in exporter.progress {
                let percentage = Int(progress.progress * 100)
                print("Export progress: \(percentage)% (\(progress.framesCompleted)/\(progress.totalFrames) frames)")
            }
        }
        
        // Export the video
        _ = try await exporter.export(timeline: timeline, settings: exportSettings)
    }
    
    // MARK: - Helper Functions
    
    static func createColoredImage(color: CGColor, size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    static func createCircleImage(radius: CGFloat, color: CGColor) -> CGImage? {
        let size = CGSize(width: radius * 2, height: radius * 2)
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        return context.makeImage()
    }
}