import Foundation
import AVFoundation

// MARK: - TrackType

public enum TrackType: Sendable {
    case video
    case audio
    case overlay
    case effect
}

// MARK: - Track

public struct Track: Identifiable, Sendable {
    public let id: UUID
    public var trackType: TrackType
    public var clips: [Clip]
    public var isEnabled: Bool
    public var volume: Float?
    public var opacity: Float?
    
    public init(
        id: UUID = UUID(),
        trackType: TrackType,
        clips: [Clip] = [],
        isEnabled: Bool = true,
        volume: Float? = nil,
        opacity: Float? = nil
    ) {
        self.id = id
        self.trackType = trackType
        self.clips = clips
        self.isEnabled = isEnabled
        self.volume = volume
        self.opacity = opacity
    }
}

// MARK: - Track Extensions

extension Track {
    public var duration: CMTime {
        clips.reduce(.zero) { max($0, $1.timeRange.end) }
    }
    
    public func clips(at time: CMTime) -> [Clip] {
        clips.filter { $0.timeRange.containsTime(time) }
    }
}