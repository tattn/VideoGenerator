//
//  FadeTransition.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit
import CoreImage.CIFilterBuiltins

public struct FadeTransition: Transition {
    init(duration: TimeInterval, fromClip: Clip) {
        self.fromClip = fromClip
        self.effects = fromClip.effects
        self.transitionDuration = duration
    }

    public var duration: TimeInterval { fromClip.duration }
    public var fromClip: Clip
    public var effects: [VideoEffect]

    private let transitionDuration: TimeInterval

    public func image(elapsed: TimeInterval) -> UIImage {
        fromClip.image(elapsed: elapsed)
    }

    public func image(elapsed: TimeInterval, nextClip: Clip?) -> UIImage {
        let fromImage = fromClip.image(elapsed: elapsed, nextClip: nextClip)
        guard elapsed >= duration - transitionDuration, let nextClip = nextClip else {
            return fromImage
        }

        let nextImage = nextClip.image(elapsed: elapsed, nextClip: nextClip)

        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: duration - elapsed)
        colorMatrix.inputImage = CIImage(image: fromImage)

        guard let nextImage = CIImage(image: nextImage),
              let result = colorMatrix.outputImage?.composited(over: nextImage) else {
            return fromImage
        }
        return UIImage(ciImage: result)
    }
}

