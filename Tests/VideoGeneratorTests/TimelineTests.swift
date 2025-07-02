import Testing
import Foundation
import AVFoundation
import CoreGraphics
@testable import VideoGenerator

// MARK: - Timeline Tests

@Suite("Timeline Tests")
struct TimelineTests {
    
    @Test("Timeline initialization")
    @MainActor
    func testTimelineInit() {
        let timeline = Timeline(
            size: CGSize(width: 1920, height: 1080),
            frameRate: 30
        )
        
        #expect(timeline.size == CGSize(width: 1920, height: 1080))
        #expect(timeline.frameRate == 30)
        #expect(timeline.tracks.isEmpty)
        #expect(timeline.duration == .zero)
    }
    
    @Test("Add and remove tracks")
    @MainActor
    func testAddRemoveTracks() {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        let videoTrack = Track(trackType: .video)
        let audioTrack = Track(trackType: .audio)
        
        timeline.addTrack(videoTrack)
        timeline.addTrack(audioTrack)
        
        #expect(timeline.tracks.count == 2)
        
        timeline.removeTrack(id: videoTrack.id)
        #expect(timeline.tracks.count == 1)
        #expect(timeline.tracks.first?.id == audioTrack.id)
    }
    
    @Test("Timeline duration calculation")
    @MainActor
    func testDurationCalculation() {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        var track1 = Track(trackType: .video)
        let clip1 = Clip(
            mediaItem: VideoMediaItem(url: URL(fileURLWithPath: "/tmp/video.mp4"), duration: CMTime(seconds: 5, preferredTimescale: 30)),
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        )
        track1.clips.append(clip1)
        
        var track2 = Track(trackType: .audio)
        let clip2 = Clip(
            mediaItem: AudioMediaItem(url: URL(fileURLWithPath: "/tmp/audio.mp3"), duration: CMTime(seconds: 10, preferredTimescale: 30)),
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), duration: CMTime(seconds: 5, preferredTimescale: 30))
        )
        track2.clips.append(clip2)
        
        timeline.addTrack(track1)
        timeline.addTrack(track2)
        
        #expect(timeline.duration == CMTime(seconds: 7, preferredTimescale: 30))
    }
    
    @Test("Filter tracks by type")
    @MainActor
    func testFilterTracksByType() {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        timeline.addTrack(Track(trackType: .video))
        timeline.addTrack(Track(trackType: .video))
        timeline.addTrack(Track(trackType: .audio))
        timeline.addTrack(Track(trackType: .overlay))
        timeline.addTrack(Track(trackType: .effect))
        
        #expect(timeline.videoTracks().count == 2)
        #expect(timeline.audioTracks().count == 1)
        #expect(timeline.overlayTracks().count == 1)
        #expect(timeline.effectTracks().count == 1)
    }
    
    @Test("Disabled tracks filtering")
    @MainActor
    func testDisabledTracksFiltering() {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        timeline.addTrack(Track(trackType: .video, isEnabled: true))
        timeline.addTrack(Track(trackType: .video, isEnabled: false))
        timeline.addTrack(Track(trackType: .audio, isEnabled: true))
        timeline.addTrack(Track(trackType: .audio, isEnabled: false))
        
        #expect(timeline.videoTracks().count == 1)
        #expect(timeline.audioTracks().count == 1)
    }
}