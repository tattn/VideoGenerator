import Testing
import Foundation
import AVFoundation
@testable import VideoGenerator

// MARK: - Track Tests

@Suite("Track Tests")
struct TrackTests {
    
    @Test("Track initialization")
    func testTrackInit() {
        let track = Track(trackType: .video, isEnabled: true, volume: 0.8, opacity: 0.9)
        
        #expect(track.trackType == .video)
        #expect(track.isEnabled == true)
        #expect(track.volume == 0.8)
        #expect(track.opacity == 0.9)
        #expect(track.clips.isEmpty)
    }
    
    @Test("Track duration calculation")
    func testTrackDuration() {
        var track = Track(trackType: .video)
        
        let clip1 = Clip(
            mediaItem: VideoMediaItem(url: URL(fileURLWithPath: "/tmp/1.mp4"), duration: CMTime(seconds: 5, preferredTimescale: 30)),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        )
        
        let clip2 = Clip(
            mediaItem: VideoMediaItem(url: URL(fileURLWithPath: "/tmp/2.mp4"), duration: CMTime(seconds: 5, preferredTimescale: 30)),
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), duration: CMTime(seconds: 4, preferredTimescale: 30))
        )
        
        track.clips = [clip1, clip2]
        
        #expect(track.duration == CMTime(seconds: 6, preferredTimescale: 30))
    }
    
    @Test("Track clips at time")
    func testTrackClipsAtTime() {
        var track = Track(trackType: .overlay)
        
        let clip1 = Clip(
            mediaItem: .text("First"),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        )
        
        let clip2 = Clip(
            mediaItem: .text("Second"),
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), duration: CMTime(seconds: 3, preferredTimescale: 30))
        )
        
        let clip3 = Clip(
            mediaItem: .text("Third"),
            timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 30), duration: CMTime(seconds: 2, preferredTimescale: 30))
        )
        
        track.clips = [clip1, clip2, clip3]
        
        let clipsAtZero = track.clips(at: .zero)
        #expect(clipsAtZero.count == 1)
        #expect((clipsAtZero[0].mediaItem as? TextMediaItem)?.text == "First")
        
        let clipsAt2_5 = track.clips(at: CMTime(seconds: 2.5, preferredTimescale: 30))
        #expect(clipsAt2_5.count == 2)
        
        let clipsAt5 = track.clips(at: CMTime(seconds: 5, preferredTimescale: 30))
        #expect(clipsAt5.count == 1)
        #expect((clipsAt5[0].mediaItem as? TextMediaItem)?.text == "Third")
    }
}