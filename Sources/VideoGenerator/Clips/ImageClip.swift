//
//  ImageClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

public struct ImageClip: Clip {
    public init(image: UIImage, duration: TimeInterval, effects: [VideoEffect]) {
        self.image = image
        self.duration = duration
        self.effects = effects
    }

    let image: UIImage
    public let duration: TimeInterval
    public let effects: [VideoEffect]

    public func image(elapsed: TimeInterval) -> UIImage {
        image
    }
}
