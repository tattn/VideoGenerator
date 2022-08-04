//
//  ImageClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

public struct ImageClip: Clip {
    public init(_ image: UIImage, scalingMode: UIImage.ScalingMode? = nil, duration: TimeInterval, effects: [VideoEffect]) {
        self.rawImage = image
        self.scalingMode = scalingMode
        self.duration = duration
        self.effects = effects
    }

    private let rawImage: UIImage
    private var image: CIImage!
    private let scalingMode: UIImage.ScalingMode?
    public let duration: TimeInterval
    public let effects: [VideoEffect]

    public mutating func prepare(with configuration: VideoConfiguration) {
        if let scalingMode = scalingMode {
            self.image = CIImage(image: rawImage.resized(to: configuration.size, scalingMode: scalingMode)) ?? .clear
        } else {
            self.image = CIImage(image: rawImage) ?? .clear
        }
    }

    public func image(elapsed: TimeInterval) -> CIImage {
        image
    }
}
