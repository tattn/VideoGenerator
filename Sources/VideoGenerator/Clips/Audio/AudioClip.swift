//
//  AudioClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import Foundation
import AVKit

public protocol AudioClip {
    func render() async throws -> AVAudioPCMBuffer
}
