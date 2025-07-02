import Foundation
@preconcurrency import CoreImage
import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - RenderContext Protocol

public protocol RenderContext: Sendable {
    var size: CGSize { get }
    var time: CMTime { get async }
    var frameRate: Int { get }
    func image(for mediaItem: any MediaItem) async throws -> CIImage
}

// MARK: - DefaultRenderContext

public actor DefaultRenderContext: RenderContext {
    public nonisolated let size: CGSize
    public nonisolated let frameRate: Int
    private var _time: CMTime
    private let imageCache: ImageCache
    
    public init(size: CGSize, frameRate: Int) {
        self.size = size
        self.frameRate = frameRate
        self._time = .zero
        self.imageCache = ImageCache(defaultSize: size)
    }
    
    public var time: CMTime {
        _time
    }
    
    public func setTime(_ time: CMTime) {
        self._time = time
    }
    
    public func image(for mediaItem: any MediaItem) async throws -> CIImage {
        await imageCache.image(for: mediaItem)
    }
}

// MARK: - ImageCache

private actor ImageCache {
    private var cache: [UUID: CIImage] = [:]
    private let defaultSize: CGSize
    
    init(defaultSize: CGSize) {
        self.defaultSize = defaultSize
    }
    
    func image(for mediaItem: any MediaItem) async -> CIImage {
        if let cachedImage = cache[mediaItem.id] {
            return cachedImage
        }
        
        let image: CIImage
        switch mediaItem.mediaType {
        case .image:
            guard let imageItem = mediaItem as? ImageMediaItem,
                  let cgImage = imageItem.cgImage else {
                return CIImage.black
            }
            image = CIImage(cgImage: cgImage)
            
        case .text:
            guard let textItem = mediaItem as? TextMediaItem else {
                return CIImage.black
            }
            image = await renderText(textItem)
            
        case .video, .audio:
            return CIImage.black
        }
        
        cache[mediaItem.id] = image
        return image
    }
    
    private func renderText(_ textItem: TextMediaItem) async -> CIImage {
        #if canImport(UIKit)
        let size = defaultSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textItem.font,
                .foregroundColor: UIColor(cgColor: textItem.color),
                .paragraphStyle: paragraphStyle
            ]
            
            let textSize = textItem.text.size(withAttributes: attributes)
            let rect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            textItem.text.draw(in: rect, withAttributes: attributes)
        }
        return CIImage(image: image) ?? CIImage.black
        #else
        let size = defaultSize
        let image = NSImage(size: size)
        image.lockFocus()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textItem.font as NSFont,
            .foregroundColor: NSColor(cgColor: textItem.color) ?? NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = textItem.text.size(withAttributes: attributes)
        let rect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        textItem.text.draw(in: rect, withAttributes: attributes)
        image.unlockFocus()
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CIImage.black
        }
        return CIImage(cgImage: cgImage)
        #endif
    }
}