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
            
        case .shape:
            let shapeItem = mediaItem as! ShapeMediaItem
            image = renderShape(shapeItem)
            
        case .video, .audio:
            return CIImage.black
        }
        
        cache[mediaItem.id] = image
        return image
    }
    
    private func renderShape(_ shapeItem: ShapeMediaItem) -> CIImage {
        let size = defaultSize
        
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            renderShapeInContext(cgContext, shapeItem: shapeItem, size: size)
        }
        return CIImage(image: image) ?? CIImage.black
        #else
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmap = bitmapRep else {
            return CIImage.black
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        
        if let context = NSGraphicsContext.current?.cgContext {
            renderShapeInContext(context, shapeItem: shapeItem, size: size)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = bitmap.cgImage else {
            return CIImage.black
        }
        
        return CIImage(cgImage: cgImage)
        #endif
    }
    
    private func renderShapeInContext(_ context: CGContext, shapeItem: ShapeMediaItem, size: CGSize) {
        context.setFillColor(shapeItem.fillColor)
        context.setStrokeColor(shapeItem.strokeColor)
        context.setLineWidth(shapeItem.strokeWidth)
        
        let rect = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        switch shapeItem.shapeType {
        case .rectangle:
            if shapeItem.fillColor.alpha > 0 {
                context.fill(rect)
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.stroke(rect.insetBy(dx: shapeItem.strokeWidth / 2, dy: shapeItem.strokeWidth / 2))
            }
            
        case .roundedRectangle(let cornerRadius):
            let path = CGPath(roundedRect: rect.insetBy(dx: shapeItem.strokeWidth / 2, dy: shapeItem.strokeWidth / 2), 
                             cornerWidth: cornerRadius, 
                             cornerHeight: cornerRadius, 
                             transform: nil)
            if shapeItem.fillColor.alpha > 0 {
                context.addPath(path)
                context.fillPath()
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.addPath(path)
                context.strokePath()
            }
            
        case .circle:
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                .insetBy(dx: shapeItem.strokeWidth / 2, dy: shapeItem.strokeWidth / 2)
            if shapeItem.fillColor.alpha > 0 {
                context.fillEllipse(in: circleRect)
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.strokeEllipse(in: circleRect)
            }
            
        case .ellipse:
            let ellipseRect = rect.insetBy(dx: shapeItem.strokeWidth / 2, dy: shapeItem.strokeWidth / 2)
            if shapeItem.fillColor.alpha > 0 {
                context.fillEllipse(in: ellipseRect)
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.strokeEllipse(in: ellipseRect)
            }
            
        case .triangle:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: shapeItem.strokeWidth))
            path.addLine(to: CGPoint(x: size.width - shapeItem.strokeWidth, y: size.height - shapeItem.strokeWidth))
            path.addLine(to: CGPoint(x: shapeItem.strokeWidth, y: size.height - shapeItem.strokeWidth))
            path.closeSubpath()
            
            if shapeItem.fillColor.alpha > 0 {
                context.addPath(path)
                context.fillPath()
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.addPath(path)
                context.strokePath()
            }
            
        case .polygon(let sides):
            guard sides >= 3 else { return }
            
            let path = CGMutablePath()
            let angle = 2 * .pi / CGFloat(sides)
            let adjustedRadius = radius - shapeItem.strokeWidth
            
            for i in 0..<sides {
                let x = center.x + adjustedRadius * cos(angle * CGFloat(i) - .pi / 2)
                let y = center.y + adjustedRadius * sin(angle * CGFloat(i) - .pi / 2)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            
            if shapeItem.fillColor.alpha > 0 {
                context.addPath(path)
                context.fillPath()
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.addPath(path)
                context.strokePath()
            }
            
        case .star(let points, let innerRadius):
            guard points >= 3 else { return }
            
            let path = CGMutablePath()
            let angle = .pi / CGFloat(points)
            let outerRadius = radius - shapeItem.strokeWidth
            let innerR = outerRadius * innerRadius
            
            for i in 0..<(points * 2) {
                let r = i % 2 == 0 ? outerRadius : innerR
                let x = center.x + r * cos(angle * CGFloat(i) - .pi / 2)
                let y = center.y + r * sin(angle * CGFloat(i) - .pi / 2)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
            
            if shapeItem.fillColor.alpha > 0 {
                context.addPath(path)
                context.fillPath()
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.addPath(path)
                context.strokePath()
            }
            
        case .path(let elements):
            let path = CGMutablePath()
            
            for element in elements {
                switch element {
                case .moveTo(let x, let y):
                    path.move(to: CGPoint(x: x, y: y))
                    
                case .lineTo(let x, let y):
                    path.addLine(to: CGPoint(x: x, y: y))
                    
                case .quadCurveTo(let x1, let y1, let x, let y):
                    path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x1, y: y1))
                    
                case .curveTo(let x1, let y1, let x2, let y2, let x, let y):
                    path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
                    
                case .arc(let center, let radius, let startAngle, let endAngle, let clockwise):
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
                    
                case .addRect(let rect):
                    path.addRect(rect)
                    
                case .addEllipse(let rect):
                    path.addEllipse(in: rect)
                    
                case .closeSubpath:
                    path.closeSubpath()
                }
            }
            
            if shapeItem.fillColor.alpha > 0 {
                context.addPath(path)
                context.fillPath()
            }
            if shapeItem.strokeWidth > 0 && shapeItem.strokeColor.alpha > 0 {
                context.addPath(path)
                context.strokePath()
            }
        }
    }
}