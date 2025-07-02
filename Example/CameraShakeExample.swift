import VideoGenerator
import AVFoundation
import CoreImage

/// Example demonstrating how to use the camera shake effect
struct CameraShakeExample {
    
    static func runExample() async throws {
        // Create a timeline
        let timeline = await Timeline(size: CGSize(width: 1920, height: 1080), frameRate: 30)
        
        // Create a video track
        var videoTrack = Track(id: UUID(), trackType: .video, clips: [], isEnabled: true)
        
        // Add a video clip
        let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
        let videoClip = Clip(
            mediaItem: VideoMediaItem(
                id: UUID(),
                url: videoURL,
                duration: CMTime(seconds: 10, preferredTimescale: 30)
            ),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 10, preferredTimescale: 30)
            ),
            effects: [] // We'll add shake effect below
        )
        
        // Add camera shake effect to specific parts of the video
        var shakenClip = videoClip
        
        // Example 1: Subtle documentary-style shake throughout
        shakenClip.effects = [CameraShakeEffect.documentary]
        
        // Example 2: Intense shake for action scene (2-4 seconds)
        // You would need to split the clip and apply different effects to different segments
        
        // Example 3: Custom shake parameters
        let customShake = CameraShakeEffect(
            intensity: 12.0,        // Pixels of movement
            frequency: 25.0,        // Oscillation frequency
            smoothness: 0.75,       // How smooth the movement is (0-1)
            rotationIntensity: 0.6  // Degrees of rotation
        )
        shakenClip.effects = [customShake]
        
        // Add clip to track
        videoTrack.clips.append(shakenClip)
        
        // Add track to timeline
        await timeline.tracks = [videoTrack]
        
        // Export the video
        let exporter = try await VideoExporter()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("output_with_shake.mp4")
        
        let settings = ExportSettings(
            outputURL: outputURL,
            videoCodec: .h265,
            preset: .high
        )
        
        let exportedURL = try await exporter.export(
            timeline: timeline,
            settings: settings
        )
        
        print("Video exported with camera shake to: \(exportedURL)")
    }
    
    /// Example showing different shake presets
    static func demonstrateShakePresets() {
        // Subtle handheld camera movement
        let subtle = CameraShakeEffect.subtle
        // Good for: Documentary footage, handheld camera feel
        
        // Medium camera shake  
        let medium = CameraShakeEffect.medium
        // Good for: General purpose shake, mild action scenes
        
        // Intense camera shake
        let intense = CameraShakeEffect.intense
        // Good for: Earthquakes, explosions, heavy impacts
        
        // Documentary-style handheld
        let documentary = CameraShakeEffect.documentary
        // Good for: Realistic handheld camera movement
        
        // Action scene shake
        let action = CameraShakeEffect.action
        // Good for: Fight scenes, chase sequences
        
        print("Available shake presets:")
        print("- Subtle: intensity=3.0, frequency=15.0")
        print("- Medium: intensity=10.0, frequency=30.0")
        print("- Intense: intensity=25.0, frequency=60.0")
        print("- Documentary: intensity=5.0, frequency=8.0")
        print("- Action: intensity=15.0, frequency=45.0")
    }
    
    /// Example of applying shake to only part of a clip
    static func applyShakeToPartOfClip() async throws {
        let timeline = await Timeline(size: CGSize(width: 1920, height: 1080), frameRate: 30)
        var videoTrack = Track(id: UUID(), trackType: .video, clips: [], isEnabled: true)
        
        let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
        let totalDuration = CMTime(seconds: 10, preferredTimescale: 30)
        
        // First part: no shake (0-3 seconds)
        let clip1 = Clip(
            mediaItem: VideoMediaItem(id: UUID(), url: videoURL, duration: totalDuration),
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3, preferredTimescale: 30)
            ),
            effects: []
        )
        
        // Second part: intense shake (3-5 seconds) - explosion or impact
        let clip2 = Clip(
            mediaItem: VideoMediaItem(id: UUID(), url: videoURL, duration: totalDuration),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 3, preferredTimescale: 30),
                duration: CMTime(seconds: 2, preferredTimescale: 30)
            ),
            effects: [CameraShakeEffect.intense]
        )
        
        // Third part: subtle shake (5-10 seconds) - aftermath
        let clip3 = Clip(
            mediaItem: VideoMediaItem(id: UUID(), url: videoURL, duration: totalDuration),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 5, preferredTimescale: 30),
                duration: CMTime(seconds: 5, preferredTimescale: 30)
            ),
            effects: [CameraShakeEffect.subtle]
        )
        
        videoTrack.clips = [clip1, clip2, clip3]
        await timeline.tracks = [videoTrack]
        
        // Export as before...
    }
}