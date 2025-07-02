import Foundation
@preconcurrency import CoreImage
import CoreGraphics

// MARK: - CIImage Extensions

extension CIImage {
    public static var clear: CIImage {
        CIImage(color: CIColor.clear)
    }
    
    public static var black: CIImage {
        CIImage(color: CIColor.black)
    }
    
    public static var white: CIImage {
        CIImage(color: CIColor.white)
    }
    
    public func resized(to size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        return transformed(by: transform)
    }
    
    public func croppedToRect(_ rect: CGRect) -> CIImage {
        cropped(to: rect)
    }
    
    public func opacity(_ opacity: Double) -> CIImage {
        applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
        ])
    }
    
    public func blended(with image: CIImage, mode: String = "CISourceOverCompositing") -> CIImage {
        applyingFilter(mode, parameters: [
            "inputBackgroundImage": self
        ])
    }
}