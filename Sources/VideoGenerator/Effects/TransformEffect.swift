//
//  TransformEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import CoreImage

public struct TransformEffect: VideoEffect {
    public init(matrix: CGAffineTransform) {
        self.matrix = matrix
    }

    let matrix: CGAffineTransform

    public func apply(_ image: CIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> CIImage {
        image.clampedToExtent().transformed(by: matrix)
    }
}
