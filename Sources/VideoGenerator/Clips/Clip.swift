//
//  Clip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import Foundation

public struct Clip {
    public init(video: VideoClip, audio: AudioClip? = nil) {
        self.video = video
        self.audio = audio
    }

    public var video: VideoClip
    public let audio: AudioClip?

    public var duration: TimeInterval {
        video.duration
    }

    mutating func prepare(with configuration: VideoConfiguration) {
        video.prepare(with: configuration)
    }
}
