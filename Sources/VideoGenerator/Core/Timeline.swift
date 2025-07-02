import Foundation
import AVFoundation
@preconcurrency import CoreGraphics

// MARK: - Timeline

@MainActor
public final class Timeline: Sendable {
    public nonisolated let id: UUID
    public var tracks: [Track]
    public var duration: CMTime
    public var size: CGSize
    public var frameRate: Int
    public var backgroundColor: CGColor
    
    public init(
        id: UUID = UUID(),
        tracks: [Track] = [],
        size: CGSize,
        frameRate: Int = 30,
        backgroundColor: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ) {
        self.id = id
        self.tracks = tracks
        self.duration = .zero
        self.size = size
        self.frameRate = frameRate
        self.backgroundColor = backgroundColor
        updateDuration()
    }
    
    // MARK: - Public Methods
    
    public func updateDuration() {
        duration = tracks.reduce(.zero) { max($0, $1.duration) }
    }
    
    public func videoTracks() -> [Track] {
        tracks.filter { $0.trackType == .video && $0.isEnabled }
    }
    
    public func audioTracks() -> [Track] {
        tracks.filter { $0.trackType == .audio && $0.isEnabled }
    }
    
    public func overlayTracks() -> [Track] {
        tracks.filter { $0.trackType == .overlay && $0.isEnabled }
    }
    
    public func effectTracks() -> [Track] {
        tracks.filter { $0.trackType == .effect && $0.isEnabled }
    }
    
    public func addTrack(_ track: Track) {
        tracks.append(track)
        updateDuration()
    }
    
    public func removeTrack(id: UUID) {
        tracks.removeAll { $0.id == id }
        updateDuration()
    }
}