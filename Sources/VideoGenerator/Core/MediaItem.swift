import Foundation
@preconcurrency import CoreImage
@preconcurrency import CoreText
import AVFoundation

// MARK: - MediaType

public enum MediaType: Sendable {
    case video
    case image
    case text
    case audio
    case shape
}

// MARK: - MediaItem Protocol

public protocol MediaItem: Sendable {
    var id: UUID { get }
    var duration: CMTime { get }
    var mediaType: MediaType { get }
}

// MARK: - Video Media Item

public struct VideoMediaItem: MediaItem, Sendable {
    public let id: UUID
    public let url: URL
    public let duration: CMTime
    public let mediaType: MediaType = .video
    
    public init(id: UUID = UUID(), url: URL, duration: CMTime) {
        self.id = id
        self.url = url
        self.duration = duration
    }
}

// MARK: - Image Media Item

public struct ImageMediaItem: MediaItem, Sendable {
    public let id: UUID
    private let imageData: Data
    private let imageWidth: Int
    private let imageHeight: Int
    public let duration: CMTime
    public let mediaType: MediaType = .image
    
    public init(id: UUID = UUID(), image: CGImage, duration: CMTime) {
        self.id = id
        self.imageWidth = image.width
        self.imageHeight = image.height
        
        if let cfData = CFDataCreateMutable(nil, 0),
           let destination = CGImageDestinationCreateWithData(cfData, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
            self.imageData = cfData as Data
        } else {
            self.imageData = Data()
        }
        
        self.duration = duration
    }
    
    public var cgImage: CGImage? {
        guard let dataProvider = CGDataProvider(data: imageData as CFData),
              let image = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        return image
    }
}

// MARK: - Text Stroke

public struct TextStroke: Sendable {
    public let color: CGColor
    public let width: CGFloat
    
    public init(color: CGColor, width: CGFloat) {
        self.color = color
        self.width = width
    }
}

// MARK: - Text Shadow

public struct TextShadow: Sendable {
    public let color: CGColor
    public let offset: CGSize
    public let blur: CGFloat
    
    public init(color: CGColor, offset: CGSize, blur: CGFloat) {
        self.color = color
        self.offset = offset
        self.blur = blur
    }
}

// MARK: - Text Behavior

public enum TextBehavior: Sendable {
    case wrap           // Text wraps to multiple lines within frame
    case truncate       // Text is truncated with ellipsis
    case autoScale      // Text scales to fit within frame
}

// MARK: - Text Alignment

public enum TextAlignment: Sendable {
    case left
    case center
    case right
    case justified
    case natural
}

// MARK: - Text Media Item

public struct TextMediaItem: MediaItem, Sendable {
    public let id: UUID
    public let text: String
    private let fontData: Data
    private let fontSize: CGFloat
    private let colorRed: CGFloat
    private let colorGreen: CGFloat
    private let colorBlue: CGFloat
    private let colorAlpha: CGFloat
    public let duration: CMTime
    public let mediaType: MediaType = .text
    public let strokes: [TextStroke]
    public let shadow: TextShadow?
    public let behavior: TextBehavior
    public let alignment: TextAlignment
    
    public init(id: UUID = UUID(), text: String, font: CTFont, color: CGColor, duration: CMTime, strokes: [TextStroke] = [], shadow: TextShadow? = nil, behavior: TextBehavior = .truncate, alignment: TextAlignment = .center) {
        self.id = id
        self.text = text
        self.fontSize = CTFontGetSize(font)
        let descriptor = CTFontCopyFontDescriptor(font)
        self.fontData = (CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String ?? "")
            .data(using: .utf8) ?? Data()
        
        let components = color.components ?? [0, 0, 0, 1]
        self.colorRed = components.count > 0 ? components[0] : 0
        self.colorGreen = components.count > 1 ? components[1] : 0
        self.colorBlue = components.count > 2 ? components[2] : 0
        self.colorAlpha = components.count > 3 ? components[3] : 1
        
        self.duration = duration
        self.strokes = strokes
        self.shadow = shadow
        self.behavior = behavior
        self.alignment = alignment
    }
    
    public var font: CTFont {
        let name = String(data: fontData, encoding: .utf8) ?? ".SFUI-Regular"
        return CTFont(name as CFString, size: fontSize)
    }
    
    public var color: CGColor {
        CGColor(red: colorRed, green: colorGreen, blue: colorBlue, alpha: colorAlpha)
    }
}

// MARK: - Audio Media Item

public struct AudioMediaItem: MediaItem, Sendable {
    public let id: UUID
    public let url: URL
    public let duration: CMTime
    public let mediaType: MediaType = .audio
    
    public init(id: UUID = UUID(), url: URL, duration: CMTime) {
        self.id = id
        self.url = url
        self.duration = duration
    }
}

// MARK: - Path Elements

public enum PathElement: Sendable {
    case moveTo(x: CGFloat, y: CGFloat)
    case lineTo(x: CGFloat, y: CGFloat)
    case quadCurveTo(x1: CGFloat, y1: CGFloat, x: CGFloat, y: CGFloat)
    case curveTo(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, x: CGFloat, y: CGFloat)
    case arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool)
    case addRect(CGRect)
    case addEllipse(in: CGRect)
    case closeSubpath
}

// MARK: - Shape Types

public enum ShapeType: Sendable {
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
    case circle
    case ellipse
    case triangle
    case polygon(sides: Int)
    case star(points: Int, innerRadius: CGFloat)
    case path([PathElement])
}

// MARK: - Shape Media Item

public struct ShapeMediaItem: MediaItem, Sendable {
    public let id: UUID
    public let shapeType: ShapeType
    private let fillColorRed: CGFloat
    private let fillColorGreen: CGFloat
    private let fillColorBlue: CGFloat
    private let fillColorAlpha: CGFloat
    private let strokeColorRed: CGFloat
    private let strokeColorGreen: CGFloat
    private let strokeColorBlue: CGFloat
    private let strokeColorAlpha: CGFloat
    public let strokeWidth: CGFloat
    public let duration: CMTime
    public let mediaType: MediaType = .shape
    
    public init(
        id: UUID = UUID(),
        shapeType: ShapeType,
        fillColor: CGColor,
        strokeColor: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0),
        strokeWidth: CGFloat = 0,
        duration: CMTime
    ) {
        self.id = id
        self.shapeType = shapeType
        self.strokeWidth = strokeWidth
        self.duration = duration
        
        let fillComponents = fillColor.components ?? [0, 0, 0, 1]
        self.fillColorRed = fillComponents.count > 0 ? fillComponents[0] : 0
        self.fillColorGreen = fillComponents.count > 1 ? fillComponents[1] : 0
        self.fillColorBlue = fillComponents.count > 2 ? fillComponents[2] : 0
        self.fillColorAlpha = fillComponents.count > 3 ? fillComponents[3] : 1
        
        let strokeComponents = strokeColor.components ?? [0, 0, 0, 0]
        self.strokeColorRed = strokeComponents.count > 0 ? strokeComponents[0] : 0
        self.strokeColorGreen = strokeComponents.count > 1 ? strokeComponents[1] : 0
        self.strokeColorBlue = strokeComponents.count > 2 ? strokeComponents[2] : 0
        self.strokeColorAlpha = strokeComponents.count > 3 ? strokeComponents[3] : 0
    }
    
    public var fillColor: CGColor {
        CGColor(red: fillColorRed, green: fillColorGreen, blue: fillColorBlue, alpha: fillColorAlpha)
    }
    
    public var strokeColor: CGColor {
        CGColor(red: strokeColorRed, green: strokeColorGreen, blue: strokeColorBlue, alpha: strokeColorAlpha)
    }
}

// MARK: - MediaItemBuilder

public enum MediaItemBuilder {
    case video(url: URL, duration: CMTime? = nil)
    case image(CGImage, duration: CMTime = CMTime(seconds: 3, preferredTimescale: 30))
    case text(String, font: CTFont = CTFont(.system, size: 48), color: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1), strokes: [TextStroke] = [], shadow: TextShadow? = nil, behavior: TextBehavior = .truncate, alignment: TextAlignment = .center)
    case audio(url: URL, duration: CMTime? = nil)
    case shape(ShapeType, fillColor: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1), strokeColor: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0), strokeWidth: CGFloat = 0, duration: CMTime = CMTime(seconds: 3, preferredTimescale: 30))
}

// MARK: - Path Builder

public struct PathBuilder {
    private var elements: [PathElement] = []
    
    public init() {}
    
    public mutating func move(to point: CGPoint) -> PathBuilder {
        elements.append(.moveTo(x: point.x, y: point.y))
        return self
    }
    
    public mutating func line(to point: CGPoint) -> PathBuilder {
        elements.append(.lineTo(x: point.x, y: point.y))
        return self
    }
    
    public mutating func quadCurve(to point: CGPoint, control: CGPoint) -> PathBuilder {
        elements.append(.quadCurveTo(x1: control.x, y1: control.y, x: point.x, y: point.y))
        return self
    }
    
    public mutating func curve(to point: CGPoint, control1: CGPoint, control2: CGPoint) -> PathBuilder {
        elements.append(.curveTo(x1: control1.x, y1: control1.y, x2: control2.x, y2: control2.y, x: point.x, y: point.y))
        return self
    }
    
    public mutating func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) -> PathBuilder {
        elements.append(.arc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise))
        return self
    }
    
    public mutating func addRect(_ rect: CGRect) -> PathBuilder {
        elements.append(.addRect(rect))
        return self
    }
    
    public mutating func addEllipse(in rect: CGRect) -> PathBuilder {
        elements.append(.addEllipse(in: rect))
        return self
    }
    
    public mutating func close() -> PathBuilder {
        elements.append(.closeSubpath)
        return self
    }
    
    public func build() -> [PathElement] {
        return elements
    }
}