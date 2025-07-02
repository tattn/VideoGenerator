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
            // Text rendering is handled in VideoCompositor.renderTextForClip
            return CIImage.black
            
        case .video, .audio:
            return CIImage.black
        }
        
        cache[mediaItem.id] = image
        return image
    }
}