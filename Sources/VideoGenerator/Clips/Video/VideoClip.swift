//
//  VideoClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit
import CoreImage

public protocol VideoClip: Sendable {
    var duration: TimeInterval { get }
    var effects: [VideoEffect] { get }

    mutating func prepare(with configuration: VideoConfiguration)

    func image(elapsed: TimeInterval) async -> CIImage

    func image(elapsed: TimeInterval, nextClip: VideoClip?) async -> CIImage

    func render(nextClip: VideoClip?, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) async -> CIImage
}

public extension VideoClip {
    mutating func prepare(with configuration: VideoConfiguration) {
    }

    func image(elapsed: TimeInterval) async -> CIImage {
        CIImage(color: .clear)
    }

    func image(elapsed: TimeInterval, nextClip: VideoClip?) async -> CIImage {
        await image(elapsed: elapsed)
    }

    func render(nextClip: VideoClip?, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) async -> CIImage {
        let elapsed = self.elapsed(numberOfFrames: numberOfFrames, currentFrame: currentFrame)
        guard elapsed <= duration else { return .clear }

        let image = await image(elapsed: elapsed, nextClip: nextClip)
        return effects.reduce(image) { partialResult, effect in
            effect.apply(partialResult, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: currentFrame)
        }
    }

    func elapsed(numberOfFrames: Int, currentFrame: Int) -> TimeInterval {
        TimeInterval(currentFrame) / TimeInterval(numberOfFrames) * duration
    }
}
