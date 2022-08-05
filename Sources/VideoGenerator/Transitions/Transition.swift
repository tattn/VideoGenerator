//
//  Transition.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import Foundation

public protocol Transition: VideoClip {
}

public extension VideoClip {
    func fade(duration: TimeInterval) -> some VideoClip {
        FadeTransition(duration: duration, fromClip: self)
    }
}
