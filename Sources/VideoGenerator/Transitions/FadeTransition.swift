//
//  FadeTransition.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit
import CoreImage.CIFilterBuiltins

public struct FadeTransition: Transition {
    init(duration: TimeInterval, fromClip: VideoClip) {
        self.fromClip = fromClip
        self.effects = fromClip.effects
        self.transitionDuration = duration
    }

    public var duration: TimeInterval { fromClip.duration }
    public var fromClip: VideoClip
    public var effects: [VideoEffect]

    private let transitionDuration: TimeInterval

    public mutating func prepare(with configuration: VideoConfiguration) {
        fromClip.prepare(with: configuration)
    }

    public func render(nextClip: VideoClip?, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) async -> CIImage {
        let fromImage = await fromClip.render(nextClip: nextClip, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: currentFrame)
        let elapsed = self.elapsed(numberOfFrames: numberOfFrames, currentFrame: currentFrame)
        guard elapsed >= duration - transitionDuration, let nextClip = nextClip else {
            return fromImage
        }

        let nextImage = await nextClip.render(nextClip: nextClip, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: 0) // TODO: 0

        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: duration - elapsed)
        colorMatrix.inputImage = fromImage
        return colorMatrix.outputImage?.composited(over: nextImage) ?? fromImage
    }
}
