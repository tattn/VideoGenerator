//
//  VideoEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import CoreImage

public protocol VideoEffect: Sendable {
    func apply(_ image: CIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> CIImage
}
