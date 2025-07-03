import Foundation
import AVFoundation
import CoreGraphics
import CoreText

// MARK: - Codable CMTime

public struct CodableCMTime: Codable, Sendable {
    let seconds: Double
    let preferredTimescale: Int32
    
    init(_ time: CMTime) {
        self.seconds = CMTimeGetSeconds(time)
        self.preferredTimescale = time.timescale
    }
    
    var cmTime: CMTime {
        CMTime(seconds: seconds, preferredTimescale: preferredTimescale)
    }
}

// MARK: - Codable CMTimeRange

public struct CodableCMTimeRange: Codable, Sendable {
    let start: CodableCMTime
    let duration: CodableCMTime
    
    init(_ range: CMTimeRange) {
        self.start = CodableCMTime(range.start)
        self.duration = CodableCMTime(range.duration)
    }
    
    var cmTimeRange: CMTimeRange {
        CMTimeRange(start: start.cmTime, duration: duration.cmTime)
    }
}

// MARK: - Codable CGSize

public struct CodableCGSize: Codable, Sendable {
    let width: Double
    let height: Double
    
    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
    
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - Codable CGRect

public struct CodableCGRect: Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Codable CGPoint

public struct CodableCGPoint: Codable, Sendable {
    let x: Double
    let y: Double
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Codable CGColor

public struct CodableCGColor: Codable, Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    init(_ color: CGColor) {
        let components = color.components ?? [0, 0, 0, 1]
        self.red = components.count > 0 ? components[0] : 0
        self.green = components.count > 1 ? components[1] : 0
        self.blue = components.count > 2 ? components[2] : 0
        self.alpha = components.count > 3 ? components[3] : 1
    }
    
    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Codable Font

public struct CodableFont: Codable, Sendable {
    let name: String
    let size: CGFloat
    
    init(_ font: CTFont) {
        self.size = CTFontGetSize(font)
        let descriptor = CTFontCopyFontDescriptor(font)
        self.name = (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String) ?? ".SFUI-Regular"
    }
    
    var ctFont: CTFont {
        CTFont(name as CFString, size: size)
    }
}

// MARK: - Codable MediaItem

public enum CodableMediaItemType: String, Codable, Sendable {
    case video
    case image
    case text
    case audio
    case shape
}

public struct CodableMediaItem: Codable, Sendable {
    let id: String
    let type: CodableMediaItemType
    let duration: CodableCMTime
    
    // Video/Audio properties
    let url: String?
    
    // Image properties
    let imageData: String? // Base64 encoded
    
    // Text properties
    let text: String?
    let font: CodableFont?
    let color: CodableCGColor?
    
    // Flattened text stroke properties (single stroke support for OpenAI strict mode)
    let strokeColorRed: CGFloat?
    let strokeColorGreen: CGFloat?
    let strokeColorBlue: CGFloat?
    let strokeColorAlpha: CGFloat?
    let textStrokeWidth: CGFloat?
    
    // Flattened shadow properties
    let shadowColorRed: CGFloat?
    let shadowColorGreen: CGFloat?
    let shadowColorBlue: CGFloat?
    let shadowColorAlpha: CGFloat?
    let shadowOffsetWidth: CGFloat?
    let shadowOffsetHeight: CGFloat?
    let shadowBlur: CGFloat?
    
    let behavior: String?
    let alignment: String?
    
    // Shape properties
    let shapeType: String? // Simplified for OpenAI strict mode
    let fillColor: CodableCGColor?
    let strokeColor: CodableCGColor?
    let strokeWidth: CGFloat?
}

// MARK: - Codable Text Stroke (Deprecated - using flattened structure for OpenAI strict mode)

// public struct CodableTextStroke: Codable, Sendable {
//     let color: CodableCGColor
//     let width: CGFloat
//     
//     init(_ stroke: TextStroke) {
//         self.color = CodableCGColor(stroke.color)
//         self.width = stroke.width
//     }
//     
//     var textStroke: TextStroke {
//         TextStroke(color: color.cgColor, width: width)
//     }
// }

// MARK: - Codable Text Shadow (Deprecated - using flattened structure for OpenAI strict mode)

// public struct CodableTextShadow: Codable, Sendable {
//     let color: CodableCGColor
//     let offset: CodableCGSize
//     let blur: CGFloat
//     
//     init(_ shadow: TextShadow) {
//         self.color = CodableCGColor(shadow.color)
//         self.offset = CodableCGSize(shadow.offset)
//         self.blur = shadow.blur
//     }
//     
//     var textShadow: TextShadow {
//         TextShadow(color: color.cgColor, offset: offset.cgSize, blur: blur)
//     }
// }

// MARK: - Codable Shape Type

public enum CodableShapeType: Codable, Sendable {
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
    case circle
    case ellipse
    case triangle
    case polygon(sides: Int)
    case star(points: Int, innerRadius: CGFloat)
    case path([CodablePathElement])
}

// MARK: - Codable Path Element

public enum CodablePathElement: Codable, Sendable {
    case moveTo(x: CGFloat, y: CGFloat)
    case lineTo(x: CGFloat, y: CGFloat)
    case quadCurveTo(x1: CGFloat, y1: CGFloat, x: CGFloat, y: CGFloat)
    case curveTo(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, x: CGFloat, y: CGFloat)
    case arc(center: CodableCGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool)
    case addRect(CodableCGRect)
    case addEllipse(in: CodableCGRect)
    case closeSubpath
}

// MARK: - Codable Clip

public struct CodableClip: Codable, Sendable {
    let id: String
    let mediaItem: CodableMediaItem
    let timeRange: CodableCMTimeRange
    let frame: CodableCGRect
    let contentMode: String
    let effects: [CodableEffect]
    let opacity: Double
}

// MARK: - Codable Effect

public struct CodableEffect: Codable, Sendable {
    let id: String
    let type: String
    let parameters: CodableEffectParameters
}

// MARK: - Codable Effect Parameters

public struct CodableEffectParameters: Codable, Sendable {
    let double: Double?
    let float: Float?
    let int: Int?
    let bool: Bool?
    let string: String?
    let color: CodableCGColor?
    let size: CodableCGSize?
    let point: CodableCGPoint?
}

// MARK: - Codable SendableValue

public enum CodableSendableValue: Codable, Sendable {
    case double(Double)
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case color(CodableCGColor)
    case size(CodableCGSize)
    case point(CodableCGPoint)
}

// MARK: - Codable Track

public struct CodableTrack: Codable, Sendable {
    let id: String
    let trackType: String
    let clips: [CodableClip]?
    let isEnabled: Bool
    let volume: Float?
    let opacity: Float?
}

// MARK: - Codable Timeline

public struct CodableTimeline: Codable, Sendable {
    let id: String
    let tracks: [CodableTrack]
    let size: CodableCGSize
    let frameRate: Int
    let backgroundColor: CodableCGColor
}

// MARK: - Codable Export Settings

public struct CodableExportSettings: Codable, Sendable {
    let outputPath: String
    let videoCodec: String
    let audioCodec: String
    let resolution: CodableCGSize
    let bitrate: Int
    let frameRate: Int
    let preset: String
}