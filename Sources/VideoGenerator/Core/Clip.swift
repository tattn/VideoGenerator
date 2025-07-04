import Foundation
@preconcurrency import CoreImage
import AVFoundation

// MARK: - Clip

public enum ContentMode: Sendable {
    case scaleToFill
    case aspectFit
    case aspectFill
}

public struct Clip: Identifiable, Sendable {
    public let id: UUID
    public var mediaItem: any MediaItem
    public var timeRange: CMTimeRange
    public var frame: CGRect
    public var contentMode: ContentMode
    public var effects: [any Effect]
    public var opacity: Double
    
    public init(
        id: UUID = UUID(),
        mediaItem: any MediaItem,
        timeRange: CMTimeRange,
        frame: CGRect? = nil,
        contentMode: ContentMode = .aspectFit,
        effects: [any Effect] = [],
        opacity: Double = 1.0
    ) {
        self.id = id
        self.mediaItem = mediaItem
        self.timeRange = timeRange
        self.frame = frame ?? .zero
        self.contentMode = contentMode
        self.effects = effects
        self.opacity = opacity
    }
}

// MARK: - Convenience Initializers

extension Clip {
    public init(
        mediaItem: MediaItemBuilder,
        timeRange: CMTimeRange,
        frame: CGRect? = nil,
        contentMode: ContentMode = .aspectFit,
        effects: [any Effect] = [],
        opacity: Double = 1.0
    ) {
        switch mediaItem {
        case .video(let url, let duration):
            let videoItem = VideoMediaItem(id: UUID(), url: url, duration: duration ?? CMTime(seconds: 5, preferredTimescale: 30))
            self.init(mediaItem: videoItem, timeRange: timeRange, frame: frame, contentMode: contentMode, effects: effects, opacity: opacity)
            
        case .image(let image, let duration):
            let imageItem = ImageMediaItem(id: UUID(), image: image, duration: duration)
            self.init(mediaItem: imageItem, timeRange: timeRange, frame: frame, contentMode: contentMode, effects: effects, opacity: opacity)
            
        case .text(let text, let font, let color, let strokes, let shadow, let behavior, let alignment):
            let textItem = TextMediaItem(id: UUID(), text: text, font: font, color: color, duration: timeRange.duration, strokes: strokes, shadow: shadow, behavior: behavior, alignment: alignment)
            self.init(mediaItem: textItem, timeRange: timeRange, frame: frame, contentMode: contentMode, effects: effects, opacity: opacity)
            
        case .audio(let url, let duration):
            let audioItem = AudioMediaItem(id: UUID(), url: url, duration: duration ?? CMTime(seconds: 5, preferredTimescale: 30))
            self.init(mediaItem: audioItem, timeRange: timeRange, frame: frame, contentMode: contentMode, effects: effects, opacity: opacity)
            
        case .shape(let shapeType, let fillColor, let strokeColor, let strokeWidth, let duration):
            let shapeItem = ShapeMediaItem(id: UUID(), shapeType: shapeType, fillColor: fillColor, strokeColor: strokeColor, strokeWidth: strokeWidth, duration: duration)
            self.init(mediaItem: shapeItem, timeRange: timeRange, frame: frame, contentMode: contentMode, effects: effects, opacity: opacity)
        }
    }
}

