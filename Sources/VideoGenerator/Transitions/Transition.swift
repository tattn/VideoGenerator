//
//  Transition.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import Foundation

public protocol Transition: Clip {
}

public extension Clip {
    func fade(duration: TimeInterval) -> some Clip {
        FadeTransition(duration: duration, fromClip: self)
    }
}
