//
//  CompositeClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import CoreImage

public struct CompositeClip: VideoClip {
    public init(_ clips: [VideoClip], duration: TimeInterval, effects: [VideoEffect] = []) {
        self.clips = clips
        self.duration = duration
        self.effects = effects
    }

    public var clips: [VideoClip]
    public let duration: TimeInterval
    public let effects: [VideoEffect]

    public mutating func prepare(with configuration: VideoConfiguration) {
        for index in clips.indices {
            clips[index].prepare(with: configuration)
        }
    }

    public func render(nextClip: VideoClip?, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> CIImage {
        guard let firstClip = clips.first else {
            return .clear
        }

        let firstImage = firstClip.render(nextClip: nextClip, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: currentFrame)
        return clips.dropFirst().reduce(firstImage) { partialResult, clip in
            autoreleasepool {
                clip.render(nextClip: nextClip, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: currentFrame)
                    .composited(over: partialResult)
            }
        }
    }
}
