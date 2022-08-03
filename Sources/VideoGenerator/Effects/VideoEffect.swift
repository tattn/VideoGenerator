//
//  VideoEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

public protocol VideoEffect {
    func apply(_ image: UIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> UIImage
}
