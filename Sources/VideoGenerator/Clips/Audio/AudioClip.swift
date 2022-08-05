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

let defaultAudioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: false)!
