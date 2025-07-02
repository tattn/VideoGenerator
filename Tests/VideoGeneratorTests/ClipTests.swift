import Testing
import Foundation
import AVFoundation
import CoreGraphics
@testable import VideoGenerator

// MARK: - Clip Tests

@Suite("Clip Tests")
struct ClipTests {
    
    @Test("Clip initialization with VideoMediaItem")
    func testClipInitWithVideo() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let mediaItem = VideoMediaItem(url: url, duration: CMTime(seconds: 5, preferredTimescale: 30))
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        let frame = CGRect(x: 100, y: 200, width: 640, height: 480)
        
        let clip = Clip(
            mediaItem: mediaItem,
            timeRange: timeRange,
            frame: frame,
            opacity: 0.8
        )
        
        #expect(clip.timeRange == timeRange)
        #expect(clip.frame == frame)
        #expect(clip.opacity == 0.8)
        #expect(clip.effects.isEmpty)
    }
    
    @Test("Clip initialization with MediaItemBuilder")
    func testClipInitWithBuilder() throws {
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 30))
        
        let videoClip = Clip(
            mediaItem: .video(url: URL(fileURLWithPath: "/tmp/video.mp4")),
            timeRange: timeRange
        )
        
        #expect(videoClip.mediaItem is VideoMediaItem)
        #expect(videoClip.timeRange == timeRange)
        
        let width = 100
        let height = 100
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
            throw TestError.contextCreationFailed
        }
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        let imageClip = Clip(
            mediaItem: .image(cgImage),
            timeRange: timeRange
        )
        
        #expect(imageClip.mediaItem is ImageMediaItem)
        
        let textClip = Clip(
            mediaItem: .text("Hello"),
            timeRange: timeRange
        )
        
        #expect(textClip.mediaItem is TextMediaItem)
    }
    
    @Test("Clip with effects")
    func testClipWithEffects() {
        let mediaItem = VideoMediaItem(
            url: URL(fileURLWithPath: "/tmp/video.mp4"),
            duration: CMTime(seconds: 5, preferredTimescale: 30)
        )
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        let effects: [any Effect] = [
            BrightnessEffect(brightness: 0.2),
            GaussianBlurEffect(radius: 5)
        ]
        
        let clip = Clip(
            mediaItem: mediaItem,
            timeRange: timeRange,
            effects: effects
        )
        
        #expect(clip.effects.count == 2)
    }
}