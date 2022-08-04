//
//  Clip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

public protocol Clip {
    var duration: TimeInterval { get }
    var effects: [VideoEffect] { get }

    func image(elapsed: TimeInterval) -> UIImage

    func image(elapsed: TimeInterval, nextClip: Clip?) -> UIImage
}

public extension Clip {
    func image(elapsed: TimeInterval, nextClip: Clip?) -> UIImage {
        image(elapsed: elapsed)
    }
}
