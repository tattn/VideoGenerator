//
//  UIImage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import UIKit

extension UIImage {
    public func resized(to newSize: CGSize, scalingMode: ScalingMode) -> UIImage {
        let aspectRatio = scalingMode.aspectRatio(between: newSize, and: size)

        let aspectRect = CGRect(x: (newSize.width - size.width * aspectRatio) / 2.0,
                                y: (newSize.height - size.height * aspectRatio) / 2.0,
                                width: size.width * aspectRatio,
                                height: size.height * aspectRatio)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            draw(in: aspectRect)
        }
    }

    public enum ScalingMode: Sendable {
        case aspectFill
        case aspectFit

        func aspectRatio(between size: CGSize, and otherSize: CGSize) -> CGFloat {
            let aspectWidth  = size.width / otherSize.width
            let aspectHeight = size.height / otherSize.height

            switch self {
            case .aspectFill: return max(aspectWidth, aspectHeight)
            case .aspectFit: return min(aspectWidth, aspectHeight)
            }
        }
    }
}
