import Testing
import Foundation
import AVFoundation
@testable import VideoGenerator

// MARK: - MediaItem Tests

@Suite("MediaItem Tests")
struct MediaItemTests {
    
    @Test("VideoMediaItem initialization")
    func testVideoMediaItemInit() {
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let duration = CMTime(seconds: 5, preferredTimescale: 30)
        let videoItem = VideoMediaItem(url: url, duration: duration)
        
        #expect(videoItem.url == url)
        #expect(videoItem.duration == duration)
        #expect(videoItem.mediaType == .video)
        #expect(videoItem.id != UUID())
    }
    
    @Test("ImageMediaItem initialization")
    func testImageMediaItemInit() throws {
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
        
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        let duration = CMTime(seconds: 3, preferredTimescale: 30)
        let imageItem = ImageMediaItem(image: cgImage, duration: duration)
        
        #expect(imageItem.cgImage != nil)
        #expect(imageItem.duration == duration)
        #expect(imageItem.mediaType == .image)
    }
    
    @Test("TextMediaItem initialization")
    func testTextMediaItemInit() {
        let text = "Hello World"
        let font = CTFont(.system, size: 48)
        let color = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let duration = CMTime(seconds: 2, preferredTimescale: 30)
        
        let textItem = TextMediaItem(text: text, font: font, color: color, duration: duration)
        
        #expect(textItem.text == text)
        #expect(CTFontGetSize(textItem.font) == 48)
        #expect(textItem.duration == duration)
        #expect(textItem.mediaType == .text)
    }
    
    @Test("AudioMediaItem initialization")
    func testAudioMediaItemInit() {
        let url = URL(fileURLWithPath: "/tmp/audio.mp3")
        let duration = CMTime(seconds: 10, preferredTimescale: 44100)
        let audioItem = AudioMediaItem(url: url, duration: duration)
        
        #expect(audioItem.url == url)
        #expect(audioItem.duration == duration)
        #expect(audioItem.mediaType == .audio)
    }
}

enum TestError: Error {
    case contextCreationFailed
    case imageCreationFailed
}