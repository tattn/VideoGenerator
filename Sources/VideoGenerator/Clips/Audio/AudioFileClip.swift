//
//  AudioFileClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/06.
//

import Foundation
import AVFAudio

public struct AudioFileClip: AudioClip {
    public init(file: AVAudioFile) {
        self.file = file
    }

    public let file: AVAudioFile

    public func render() async throws -> AVAudioPCMBuffer {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw Error.invalidFile
        }

        try file.read(into: buffer)
        return try buffer.convertToDefaultFormat()
    }

    enum Error: Swift.Error {
        case invalidFile
    }
}
