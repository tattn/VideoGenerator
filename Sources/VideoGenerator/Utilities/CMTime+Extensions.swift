import Foundation
import AVFoundation

// MARK: - CMTime Extensions

extension CMTime {
    public static func seconds(_ seconds: Double, preferredTimescale: CMTimeScale = 30) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: preferredTimescale)
    }
    
    public static func milliseconds(_ milliseconds: Double, preferredTimescale: CMTimeScale = 1000) -> CMTime {
        CMTime(seconds: milliseconds / 1000.0, preferredTimescale: preferredTimescale)
    }
    
    public var milliseconds: Double {
        seconds * 1000.0
    }
}

// MARK: - CMTimeRange Extensions

extension CMTimeRange {
    public static func range(start: CMTime, duration: CMTime) -> CMTimeRange {
        CMTimeRange(start: start, duration: duration)
    }
    
    public static func range(start: Double, duration: Double, preferredTimescale: CMTimeScale = 30) -> CMTimeRange {
        CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: preferredTimescale),
            duration: CMTime(seconds: duration, preferredTimescale: preferredTimescale)
        )
    }
    
    public func contains(_ time: CMTime) -> Bool {
        containsTime(time)
    }
    
    public func overlaps(with range: CMTimeRange) -> Bool {
        let intersection = self.intersection(range)
        return intersection.duration.seconds > 0
    }
}