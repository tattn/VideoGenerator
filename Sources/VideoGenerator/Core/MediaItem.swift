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

// MARK: - MediaItemBuilder

public enum MediaItemBuilder {
    case video(url: URL, duration: CMTime? = nil)
    case image(CGImage, duration: CMTime = CMTime(seconds: 3, preferredTimescale: 30))
    case text(String, font: CTFont = CTFont(.system, size: 48), color: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1), strokes: [TextStroke] = [], shadow: TextShadow? = nil, behavior: TextBehavior = .truncate, alignment: TextAlignment = .center)
    case audio(url: URL, duration: CMTime? = nil)
}