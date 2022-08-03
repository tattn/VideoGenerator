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
}
