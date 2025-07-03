import Foundation
import AVFoundation
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - TimelineConverter

public final class TimelineConverter {
    
    // MARK: - Conversion to Codable
    
    @MainActor
    public static func convertToCodable(_ timeline: Timeline) async -> CodableTimeline {
        CodableTimeline(
            id: timeline.id.uuidString,
            tracks: await withTaskGroup(of: (Int, CodableTrack).self) { group in
                for (index, track) in timeline.tracks.enumerated() {
                    group.addTask {
                        (index, await convertToCodable(track))
                    }
                }
                var results: [(Int, CodableTrack)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
            },
            size: CodableCGSize(timeline.size),
            frameRate: timeline.frameRate,
            backgroundColor: CodableCGColor(timeline.backgroundColor)
        )
    }
    
    @MainActor
    private static func convertToCodable(_ track: Track) async -> CodableTrack {
        CodableTrack(
            id: track.id.uuidString,
            trackType: convertTrackType(track.trackType),
            clips: await withTaskGroup(of: (Int, CodableClip).self) { group in
                for (index, clip) in track.clips.enumerated() {
                    group.addTask {
                        (index, await convertToCodable(clip))
                    }
                }
                var results: [(Int, CodableClip)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
            },
            isEnabled: track.isEnabled,
            volume: track.volume,
            opacity: track.opacity
        )
    }
    
    private static func convertTrackType(_ type: TrackType) -> String {
        switch type {
        case .video: return "video"
        case .audio: return "audio"
        case .overlay: return "overlay"
        case .effect: return "effect"
        }
    }
    
    @MainActor
    private static func convertToCodable(_ clip: Clip) async -> CodableClip {
        CodableClip(
            id: clip.id.uuidString,
            mediaItem: convertToCodable(clip.mediaItem),
            timeRange: CodableCMTimeRange(clip.timeRange),
            frame: CodableCGRect(clip.frame),
            contentMode: convertContentMode(clip.contentMode),
            effects: await withTaskGroup(of: (Int, CodableEffect).self) { group in
                for (index, effect) in clip.effects.enumerated() {
                    group.addTask {
                        (index, await convertToCodable(effect))
                    }
                }
                var results: [(Int, CodableEffect)] = []
                for await result in group {
                    results.append(result)
                }
                return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
            },
            opacity: clip.opacity
        )
    }
    
    private static func convertContentMode(_ mode: ContentMode) -> String {
        switch mode {
        case .scaleToFill: return "scaleToFill"
        case .aspectFit: return "aspectFit"
        case .aspectFill: return "aspectFill"
        }
    }
    
    private static func convertToCodable(_ mediaItem: any MediaItem) -> CodableMediaItem {
        switch mediaItem.mediaType {
        case .video:
            let video = mediaItem as! VideoMediaItem
            return CodableMediaItem(
                id: video.id.uuidString,
                type: .video,
                duration: CodableCMTime(video.duration),
                url: video.url.path,
                imageData: nil,
                text: nil,
                font: nil,
                color: nil,
                strokes: nil,
                shadow: nil,
                behavior: nil,
                alignment: nil,
                shapeType: nil,
                fillColor: nil,
                strokeColor: nil,
                strokeWidth: nil
            )
            
        case .image:
            let image = mediaItem as! ImageMediaItem
            var imageData: String? = nil
            if let cgImage = image.cgImage,
               let cfData = CFDataCreateMutable(nil, 0),
               let destination = CGImageDestinationCreateWithData(cfData, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, cgImage, nil)
                CGImageDestinationFinalize(destination)
                imageData = (cfData as Data).base64EncodedString()
            }
            
            return CodableMediaItem(
                id: image.id.uuidString,
                type: .image,
                duration: CodableCMTime(image.duration),
                url: nil,
                imageData: imageData,
                text: nil,
                font: nil,
                color: nil,
                strokes: nil,
                shadow: nil,
                behavior: nil,
                alignment: nil,
                shapeType: nil,
                fillColor: nil,
                strokeColor: nil,
                strokeWidth: nil
            )
            
        case .text:
            let text = mediaItem as! TextMediaItem
            return CodableMediaItem(
                id: text.id.uuidString,
                type: .text,
                duration: CodableCMTime(text.duration),
                url: nil,
                imageData: nil,
                text: text.text,
                font: CodableFont(text.font),
                color: CodableCGColor(text.color),
                strokes: text.strokes.map(CodableTextStroke.init),
                shadow: text.shadow.map(CodableTextShadow.init),
                behavior: convertTextBehavior(text.behavior),
                alignment: convertTextAlignment(text.alignment),
                shapeType: nil,
                fillColor: nil,
                strokeColor: nil,
                strokeWidth: nil
            )
            
        case .audio:
            let audio = mediaItem as! AudioMediaItem
            return CodableMediaItem(
                id: audio.id.uuidString,
                type: .audio,
                duration: CodableCMTime(audio.duration),
                url: audio.url.path,
                imageData: nil,
                text: nil,
                font: nil,
                color: nil,
                strokes: nil,
                shadow: nil,
                behavior: nil,
                alignment: nil,
                shapeType: nil,
                fillColor: nil,
                strokeColor: nil,
                strokeWidth: nil
            )
            
        case .shape:
            let shape = mediaItem as! ShapeMediaItem
            return CodableMediaItem(
                id: shape.id.uuidString,
                type: .shape,
                duration: CodableCMTime(shape.duration),
                url: nil,
                imageData: nil,
                text: nil,
                font: nil,
                color: nil,
                strokes: nil,
                shadow: nil,
                behavior: nil,
                alignment: nil,
                shapeType: convertShapeType(shape.shapeType),
                fillColor: CodableCGColor(shape.fillColor),
                strokeColor: CodableCGColor(shape.strokeColor),
                strokeWidth: shape.strokeWidth
            )
        }
    }
    
    private static func convertTextBehavior(_ behavior: TextBehavior) -> String {
        switch behavior {
        case .wrap: return "wrap"
        case .truncate: return "truncate"
        case .autoScale: return "autoScale"
        }
    }
    
    private static func convertTextAlignment(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .center: return "center"
        case .right: return "right"
        case .justified: return "justified"
        case .natural: return "natural"
        }
    }
    
    private static func convertShapeType(_ type: ShapeType) -> CodableShapeType {
        switch type {
        case .rectangle:
            return .rectangle
        case .roundedRectangle(let radius):
            return .roundedRectangle(cornerRadius: radius)
        case .circle:
            return .circle
        case .ellipse:
            return .ellipse
        case .triangle:
            return .triangle
        case .polygon(let sides):
            return .polygon(sides: sides)
        case .star(let points, let innerRadius):
            return .star(points: points, innerRadius: innerRadius)
        case .path(let elements):
            return .path(elements.map(convertPathElement))
        }
    }
    
    private static func convertPathElement(_ element: PathElement) -> CodablePathElement {
        switch element {
        case .moveTo(let x, let y):
            return .moveTo(x: x, y: y)
        case .lineTo(let x, let y):
            return .lineTo(x: x, y: y)
        case .quadCurveTo(let x1, let y1, let x, let y):
            return .quadCurveTo(x1: x1, y1: y1, x: x, y: y)
        case .curveTo(let x1, let y1, let x2, let y2, let x, let y):
            return .curveTo(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y)
        case .arc(let center, let radius, let startAngle, let endAngle, let clockwise):
            return .arc(center: CodableCGPoint(center), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        case .addRect(let rect):
            return .addRect(CodableCGRect(rect))
        case .addEllipse(let rect):
            return .addEllipse(in: CodableCGRect(rect))
        case .closeSubpath:
            return .closeSubpath
        }
    }
    
    @MainActor
    private static func convertToCodable(_ effect: any Effect) async -> CodableEffect {
        let effectType = await EffectRegistry.shared.effectType(for: effect)
        return CodableEffect(
            id: effect.id.uuidString,
            type: effectType,
            parameters: convertParameters(effect.parameters)
        )
    }
    
    private static func convertParameters(_ parameters: EffectParameters) -> CodableEffectParameters {
        // For OpenAI strict mode, we'll use the first parameter value
        // This is a simplified approach - in a real implementation, you'd map specific effect types to parameters
        var double: Double? = nil
        var float: Float? = nil
        var int: Int? = nil
        var bool: Bool? = nil
        var string: String? = nil
        var color: CodableCGColor? = nil
        var size: CodableCGSize? = nil
        var point: CodableCGPoint? = nil
        
        for (_, value) in parameters.storageDict {
            switch value {
            case .double(let v): double = v
            case .float(let v): float = v
            case .int(let v): int = v
            case .bool(let v): bool = v
            case .string(let v): string = v
            case .color(let v): color = CodableCGColor(v)
            case .size(let v): size = CodableCGSize(v)
            case .point(let v): point = CodableCGPoint(v)
            }
        }
        
        return CodableEffectParameters(
            double: double,
            float: float,
            int: int,
            bool: bool,
            string: string,
            color: color,
            size: size,
            point: point
        )
    }
    
    private static func convertSendableValue(_ value: SendableValue) -> CodableSendableValue {
        switch value {
        case .double(let v): return .double(v)
        case .float(let v): return .float(v)
        case .int(let v): return .int(v)
        case .bool(let v): return .bool(v)
        case .string(let v): return .string(v)
        case .color(let v): return .color(CodableCGColor(v))
        case .size(let v): return .size(CodableCGSize(v))
        case .point(let v): return .point(CodableCGPoint(v))
        }
    }
    
    // MARK: - Conversion from Codable
    
    @MainActor
    public static func convertFromCodable(_ codable: CodableTimeline) async throws -> Timeline {
        let timeline = Timeline(
            id: UUID(uuidString: codable.id) ?? UUID(),
            tracks: [],
            size: codable.size.cgSize,
            frameRate: codable.frameRate,
            backgroundColor: codable.backgroundColor.cgColor
        )
        
        for codableTrack in codable.tracks {
            let track = try await convertFromCodable(codableTrack)
            timeline.tracks.append(track)
        }
        
        timeline.updateDuration()
        return timeline
    }
    
    @MainActor
    private static func convertFromCodable(_ codable: CodableTrack) async throws -> Track {
        var clips: [Clip] = []
        for codableClip in codable.clips {
            clips.append(try await convertFromCodable(codableClip))
        }
        
        return Track(
            id: UUID(uuidString: codable.id) ?? UUID(),
            trackType: try convertTrackType(codable.trackType),
            clips: clips,
            isEnabled: codable.isEnabled,
            volume: codable.volume,
            opacity: codable.opacity
        )
    }
    
    private static func convertTrackType(_ type: String) throws -> TrackType {
        switch type {
        case "video": return .video
        case "audio": return .audio
        case "overlay": return .overlay
        case "effect": return .effect
        default: throw TimelineSerializationError.invalidTrackType(type)
        }
    }
    
    @MainActor
    private static func convertFromCodable(_ codable: CodableClip) async throws -> Clip {
        let mediaItem = try await convertFromCodable(codable.mediaItem)
        let effects = try await convertEffects(codable.effects)
        
        return Clip(
            id: UUID(uuidString: codable.id) ?? UUID(),
            mediaItem: mediaItem,
            timeRange: codable.timeRange.cmTimeRange,
            frame: codable.frame.cgRect,
            contentMode: try convertContentMode(codable.contentMode),
            effects: effects,
            opacity: codable.opacity
        )
    }
    
    private static func convertContentMode(_ mode: String) throws -> ContentMode {
        switch mode {
        case "scaleToFill": return .scaleToFill
        case "aspectFit": return .aspectFit
        case "aspectFill": return .aspectFill
        default: throw TimelineSerializationError.invalidContentMode(mode)
        }
    }
    
    @MainActor
    private static func convertFromCodable(_ codable: CodableMediaItem) async throws -> any MediaItem {
        switch codable.type {
        case .video:
            guard let urlString = codable.url else {
                throw TimelineSerializationError.missingRequiredField("url")
            }
            return VideoMediaItem(
                id: UUID(uuidString: codable.id) ?? UUID(),
                url: URL(fileURLWithPath: urlString),
                duration: codable.duration.cmTime
            )
            
        case .image:
            guard let imageData = codable.imageData,
                  let data = Data(base64Encoded: imageData),
                  let dataProvider = CGDataProvider(data: data as CFData),
                  let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
                throw TimelineSerializationError.invalidImageData
            }
            
            return ImageMediaItem(
                id: UUID(uuidString: codable.id) ?? UUID(),
                image: cgImage,
                duration: codable.duration.cmTime
            )
            
        case .text:
            guard let text = codable.text,
                  let font = codable.font,
                  let color = codable.color,
                  let behavior = codable.behavior,
                  let alignment = codable.alignment else {
                throw TimelineSerializationError.missingRequiredField("text properties")
            }
            
            return TextMediaItem(
                id: UUID(uuidString: codable.id) ?? UUID(),
                text: text,
                font: font.ctFont,
                color: color.cgColor,
                duration: codable.duration.cmTime,
                strokes: codable.strokes?.map { $0.textStroke } ?? [],
                shadow: codable.shadow?.textShadow,
                behavior: try convertTextBehavior(behavior),
                alignment: try convertTextAlignment(alignment)
            )
            
        case .audio:
            guard let urlString = codable.url else {
                throw TimelineSerializationError.missingRequiredField("url")
            }
            return AudioMediaItem(
                id: UUID(uuidString: codable.id) ?? UUID(),
                url: URL(fileURLWithPath: urlString),
                duration: codable.duration.cmTime
            )
            
        case .shape:
            guard let shapeType = codable.shapeType,
                  let fillColor = codable.fillColor,
                  let strokeColor = codable.strokeColor,
                  let strokeWidth = codable.strokeWidth else {
                throw TimelineSerializationError.missingRequiredField("shape properties")
            }
            
            return ShapeMediaItem(
                id: UUID(uuidString: codable.id) ?? UUID(),
                shapeType: try convertShapeType(shapeType),
                fillColor: fillColor.cgColor,
                strokeColor: strokeColor.cgColor,
                strokeWidth: strokeWidth,
                duration: codable.duration.cmTime
            )
        }
    }
    
    private static func convertTextBehavior(_ behavior: String) throws -> TextBehavior {
        switch behavior {
        case "wrap": return .wrap
        case "truncate": return .truncate
        case "autoScale": return .autoScale
        default: throw TimelineSerializationError.invalidTextBehavior(behavior)
        }
    }
    
    private static func convertTextAlignment(_ alignment: String) throws -> TextAlignment {
        switch alignment {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justified": return .justified
        case "natural": return .natural
        default: throw TimelineSerializationError.invalidTextAlignment(alignment)
        }
    }
    
    private static func convertShapeType(_ type: CodableShapeType) throws -> ShapeType {
        switch type {
        case .rectangle:
            return .rectangle
        case .roundedRectangle(let radius):
            return .roundedRectangle(cornerRadius: radius)
        case .circle:
            return .circle
        case .ellipse:
            return .ellipse
        case .triangle:
            return .triangle
        case .polygon(let sides):
            return .polygon(sides: sides)
        case .star(let points, let innerRadius):
            return .star(points: points, innerRadius: innerRadius)
        case .path(let elements):
            return .path(try elements.map(convertPathElement))
        }
    }
    
    private static func convertPathElement(_ element: CodablePathElement) throws -> PathElement {
        switch element {
        case .moveTo(let x, let y):
            return .moveTo(x: x, y: y)
        case .lineTo(let x, let y):
            return .lineTo(x: x, y: y)
        case .quadCurveTo(let x1, let y1, let x, let y):
            return .quadCurveTo(x1: x1, y1: y1, x: x, y: y)
        case .curveTo(let x1, let y1, let x2, let y2, let x, let y):
            return .curveTo(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y)
        case .arc(let center, let radius, let startAngle, let endAngle, let clockwise):
            return .arc(center: center.cgPoint, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        case .addRect(let rect):
            return .addRect(rect.cgRect)
        case .addEllipse(let rect):
            return .addEllipse(in: rect.cgRect)
        case .closeSubpath:
            return .closeSubpath
        }
    }
    
    @MainActor
    private static func convertEffects(_ codables: [CodableEffect]) async throws -> [any Effect] {
        var effects: [any Effect] = []
        for codable in codables {
            let parameters = convertParameters(codable.parameters)
            if let effect = try await EffectRegistry.shared.createEffect(
                type: codable.type,
                id: UUID(uuidString: codable.id) ?? UUID(),
                parameters: parameters
            ) {
                effects.append(effect)
            }
        }
        return effects
    }
    
    private static func convertParameters(_ codable: CodableEffectParameters) -> EffectParameters {
        var storage: [String: SendableValue] = [:]
        
        // Convert back from flat structure to dictionary
        // In a real implementation, you'd map based on effect type
        if let double = codable.double {
            storage["value"] = .double(double)
        } else if let float = codable.float {
            storage["value"] = .float(float)
        } else if let int = codable.int {
            storage["value"] = .int(int)
        } else if let bool = codable.bool {
            storage["value"] = .bool(bool)
        } else if let string = codable.string {
            storage["value"] = .string(string)
        } else if let color = codable.color {
            storage["value"] = .color(color.cgColor)
        } else if let size = codable.size {
            storage["value"] = .size(size.cgSize)
        } else if let point = codable.point {
            storage["value"] = .point(point.cgPoint)
        }
        
        return EffectParameters(storage)
    }
    
    private static func convertSendableValue(_ value: CodableSendableValue) -> SendableValue {
        switch value {
        case .double(let v): return .double(v)
        case .float(let v): return .float(v)
        case .int(let v): return .int(v)
        case .bool(let v): return .bool(v)
        case .string(let v): return .string(v)
        case .color(let v): return .color(v.cgColor)
        case .size(let v): return .size(v.cgSize)
        case .point(let v): return .point(v.cgPoint)
        }
    }
}

// MARK: - Errors

public enum TimelineSerializationError: Error {
    case invalidTrackType(String)
    case invalidContentMode(String)
    case missingRequiredField(String)
    case invalidImageData
    case invalidTextBehavior(String)
    case invalidTextAlignment(String)
    case effectNotFound(String)
}