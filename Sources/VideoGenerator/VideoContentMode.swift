//
//  VideoContentMode.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import CoreGraphics

public enum VideoContentMode {
    case aspectFit
    case aspectFill

    public func aspectRatio(between size: CGSize, and otherSize: CGSize) -> CGFloat {
        let aspectWidth  = size.width / otherSize.width
        let aspectHeight = size.height / otherSize.height

        switch self {
        case .aspectFill: return max(aspectWidth, aspectHeight)
        case .aspectFit: return min(aspectWidth, aspectHeight)
        }
    }
}
