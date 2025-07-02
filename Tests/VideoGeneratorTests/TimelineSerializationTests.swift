import Testing
import Foundation
import AVFoundation
@testable import VideoGenerator

@Suite("Timeline Serialization Tests")
struct TimelineSerializationTests {
    
    @Test("Basic Timeline Serialization and Deserialization")
    @MainActor
    func testBasicTimelineSerialization() async throws {
        // Create a simple timeline
        let timeline = Timeline(
            size: CGSize(width: 1920, height: 1080),
            frameRate: 30,
            backgroundColor: CGColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0)
        )
        
        // Add a video track
        var videoTrack = Track(
            trackType: .video,
            isEnabled: true,
            opacity: 0.8
        )
        
        let videoClip = Clip(
            mediaItem: VideoMediaItem(
                url: URL(fileURLWithPath: "/path/to/video.mp4"),
                duration: CMTime(seconds: 5, preferredTimescale: 30)
            ),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5, preferredTimescale: 30)
            ),
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            contentMode: .aspectFit,
            opacity: 0.9
        )
        
        videoTrack.clips.append(videoClip)
        timeline.tracks.append(videoTrack)
        
        // Serialize
        let serializer = TimelineSerializer()
        let jsonData = try await serializer.saveToData(timeline)
        
        // Deserialize
        let deserializedTimeline = try await serializer.load(from: jsonData)
        
        // Verify
        #expect(deserializedTimeline.size == timeline.size)
        #expect(deserializedTimeline.frameRate == timeline.frameRate)
        #expect(deserializedTimeline.tracks.count == 1)
        #expect(deserializedTimeline.tracks[0].trackType == .video)
        #expect(deserializedTimeline.tracks[0].clips.count == 1)
    }
    
    @Test("Text Media Item Serialization")
    @MainActor
    func testTextMediaItemSerialization() async throws {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        var overlayTrack = Track(trackType: .overlay)
        
        let textClip = Clip(
            mediaItem: TextMediaItem(
                text: "Hello World",
                font: CTFont(.system, size: 48),
                color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                duration: CMTime(seconds: 3, preferredTimescale: 30),
                strokes: [TextStroke(color: .init(red: 0, green: 0, blue: 0, alpha: 1), width: 2)],
                shadow: TextShadow(
                    color: .init(red: 0, green: 0, blue: 0, alpha: 0.5),
                    offset: CGSize(width: 2, height: 2),
                    blur: 4
                ),
                behavior: .wrap,
                alignment: .center
            ),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3, preferredTimescale: 30)
            ),
            frame: CGRect(x: 100, y: 100, width: 800, height: 200)
        )
        
        overlayTrack.clips.append(textClip)
        timeline.tracks.append(overlayTrack)
        
        let serializer = TimelineSerializer()
        let jsonString = try await serializer.saveToString(timeline)
        let deserializedTimeline = try await serializer.load(from: jsonString)
        
        #expect(deserializedTimeline.tracks.count == 1)
        let deserializedClip = deserializedTimeline.tracks[0].clips[0]
        let textItem = deserializedClip.mediaItem as? TextMediaItem
        #expect(textItem != nil)
        #expect(textItem?.text == "Hello World")
        #expect(textItem?.strokes.count == 1)
        #expect(textItem?.shadow != nil)
    }
    
    @Test("Shape Media Item Serialization")
    @MainActor
    func testShapeMediaItemSerialization() async throws {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        var shapeTrack = Track(trackType: .overlay)
        
        let shapeClip = Clip(
            mediaItem: ShapeMediaItem(
                shapeType: .roundedRectangle(cornerRadius: 20),
                fillColor: CGColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1),
                strokeColor: CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1),
                strokeWidth: 3,
                duration: CMTime(seconds: 2, preferredTimescale: 30)
            ),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 1, preferredTimescale: 30),
                duration: CMTime(seconds: 2, preferredTimescale: 30)
            ),
            frame: CGRect(x: 50, y: 50, width: 300, height: 200)
        )
        
        shapeTrack.clips.append(shapeClip)
        timeline.tracks.append(shapeTrack)
        
        let serializer = TimelineSerializer()
        let jsonData = try await serializer.saveToData(timeline)
        let deserializedTimeline = try await serializer.load(from: jsonData)
        
        let deserializedClip = deserializedTimeline.tracks[0].clips[0]
        let shapeItem = deserializedClip.mediaItem as? ShapeMediaItem
        #expect(shapeItem != nil)
        #expect(shapeItem?.strokeWidth == 3)
    }
    
    @Test("Effects Serialization")
    @MainActor
    func testEffectsSerialization() async throws {
        // Ensure EffectRegistry is initialized
        await EffectRegistry.shared.ensureInitialized()
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        var videoTrack = Track(trackType: .video)
        
        // Create effects
        var brightnessEffect = BrightnessEffect()
        brightnessEffect.parameters = EffectParameters([
            "brightness": .double(0.5)
        ])
        
        var blurEffect = GaussianBlurEffect()
        blurEffect.parameters = EffectParameters([
            "radius": .float(10.0)
        ])
        
        let videoClip = Clip(
            mediaItem: VideoMediaItem(
                url: URL(fileURLWithPath: "/path/to/video.mp4"),
                duration: CMTime(seconds: 5, preferredTimescale: 30)
            ),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5, preferredTimescale: 30)
            ),
            effects: [brightnessEffect, blurEffect]
        )
        
        videoTrack.clips.append(videoClip)
        timeline.tracks.append(videoTrack)
        
        let serializer = TimelineSerializer()
        let jsonData = try await serializer.saveToData(timeline)
        let deserializedTimeline = try await serializer.load(from: jsonData)
        
        let deserializedClip = deserializedTimeline.tracks[0].clips[0]
        #expect(deserializedClip.effects.count == 2)
        
        // Check brightness effect
        let deserializedBrightness = deserializedClip.effects[0]
        let brightnessValue: Double? = deserializedBrightness.parameters["brightness"]
        #expect(brightnessValue == 0.5)
        
        // Check blur effect
        let deserializedBlur = deserializedClip.effects[1]
        let blurValue: Float? = deserializedBlur.parameters["radius"]
        #expect(blurValue == 10.0)
    }
    
    @Test("JSON Validation")
    @MainActor
    func testJSONValidation() throws {
        let validJSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "tracks": [],
            "size": {"width": 1920, "height": 1080},
            "frameRate": 30,
            "backgroundColor": {"red": 0, "green": 0, "blue": 0, "alpha": 1}
        }
        """
        
        let invalidJSON = """
        {
            "id": "not-a-uuid",
            "tracks": "not-an-array"
        }
        """
        
        let serializer = TimelineSerializer()
        #expect(serializer.validate(string: validJSON) == true)
        #expect(serializer.validate(string: invalidJSON) == false)
    }
    
    @Test("Complex Timeline Round Trip")
    @MainActor
    func testComplexTimelineRoundTrip() async throws {
        // Create a complex timeline with multiple tracks and clips
        let timeline = Timeline(
            size: CGSize(width: 1920, height: 1080),
            frameRate: 60
        )
        
        // Video track
        var videoTrack = Track(trackType: .video)
        for i in 0..<3 {
            let clip = Clip(
                mediaItem: VideoMediaItem(
                    url: URL(fileURLWithPath: "/video\(i).mp4"),
                    duration: CMTime(seconds: 2, preferredTimescale: 60)
                ),
                timeRange: CMTimeRange(
                    start: CMTime(seconds: Double(i) * 2, preferredTimescale: 60),
                    duration: CMTime(seconds: 2, preferredTimescale: 60)
                )
            )
            videoTrack.clips.append(clip)
        }
        
        // Audio track
        var audioTrack = Track(trackType: .audio, volume: 0.8)
        audioTrack.clips.append(
            Clip(
                mediaItem: AudioMediaItem(
                    url: URL(fileURLWithPath: "/audio.mp3"),
                    duration: CMTime(seconds: 6, preferredTimescale: 60)
                ),
                timeRange: CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: 6, preferredTimescale: 60)
                )
            )
        )
        
        // Overlay track with various media types
        var overlayTrack = Track(trackType: .overlay)
        
        // Add image
        if let image = createTestImage() {
            overlayTrack.clips.append(
                Clip(
                    mediaItem: ImageMediaItem(
                        image: image,
                        duration: CMTime(seconds: 2, preferredTimescale: 60)
                    ),
                    timeRange: CMTimeRange(
                        start: .zero,
                        duration: CMTime(seconds: 2, preferredTimescale: 60)
                    ),
                    contentMode: .aspectFill
                )
            )
        }
        
        // Add text
        overlayTrack.clips.append(
            Clip(
                mediaItem: TextMediaItem(
                    text: "Test Title",
                    font: CTFont(.system, size: 72),
                    color: CGColor(red: 1, green: 0.8, blue: 0, alpha: 1),
                    duration: CMTime(seconds: 3, preferredTimescale: 60)
                ),
                timeRange: CMTimeRange(
                    start: CMTime(seconds: 2, preferredTimescale: 60),
                    duration: CMTime(seconds: 3, preferredTimescale: 60)
                )
            )
        )
        
        // Add shape
        overlayTrack.clips.append(
            Clip(
                mediaItem: ShapeMediaItem(
                    shapeType: .star(points: 5, innerRadius: 0.5),
                    fillColor: CGColor(red: 1, green: 0, blue: 0, alpha: 0.7),
                    duration: CMTime(seconds: 1, preferredTimescale: 60)
                ),
                timeRange: CMTimeRange(
                    start: CMTime(seconds: 5, preferredTimescale: 60),
                    duration: CMTime(seconds: 1, preferredTimescale: 60)
                )
            )
        )
        
        timeline.tracks = [videoTrack, audioTrack, overlayTrack]
        
        // Serialize and deserialize
        let serializer = TimelineSerializer()
        let jsonData = try await serializer.saveToData(timeline)
        let deserializedTimeline = try await serializer.load(from: jsonData)
        
        // Verify structure
        #expect(deserializedTimeline.tracks.count == 3)
        #expect(deserializedTimeline.tracks[0].clips.count == 3) // video
        #expect(deserializedTimeline.tracks[1].clips.count == 1) // audio
        #expect(deserializedTimeline.tracks[2].clips.count == 3) // overlay
        #expect(deserializedTimeline.frameRate == 60)
    }
    
    // Helper function to create test image
    private func createTestImage() -> CGImage? {
        let width = 100
        let height = 100
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        context.setFillColor(CGColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}