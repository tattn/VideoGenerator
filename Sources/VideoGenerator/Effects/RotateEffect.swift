//
//  RotateEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import CoreImage

public struct RotateEffect: VideoEffect {
    public init(speed: CGFloat = .pi * 4, direction: RotateEffect.Direction = .right) {
        self.speed = speed
        self.direction = direction
    }

    let speed: CGFloat // radian per seconds
    let direction: Direction

    public enum Direction: Sendable {
        case left, right

        var sign: CGFloat {
            switch self {
            case .left:
                return 1
            case .right:
                return -1
            }
        }
    }

    public func apply(_ image: CIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> CIImage {
        let angle = speed / CGFloat(configuration.fps) * CGFloat(currentFrame) * direction.sign
        return image.clampedToExtent()
            .transformed(by: .init(translationX: -image.extent.width / 2, y: -image.extent.height / 2))
            .transformed(by: .init(rotationAngle: angle))
            .transformed(by: .init(translationX: image.extent.width / 2, y: image.extent.height / 2))
    }
}
