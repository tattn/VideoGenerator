//
//  SpeechClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/06.
//

import AVKit

public struct SpeechClip: AudioClip {
    public init(_ text: String) {
        self.text = text
    }

    let text: String

    public func render() async throws -> AVAudioPCMBuffer {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let synthesizer = AVSpeechSynthesizer()

        return try await withCheckedThrowingContinuation { continuation in
            var buffers: [AVAudioPCMBuffer] = []
            synthesizer.write(utterance) { audioBuffer in
                guard let pcmBuffer = audioBuffer as? AVAudioPCMBuffer else {
                    return continuation.resume(throwing: Error.unknown)
                }

                buffers.append(pcmBuffer)

                if pcmBuffer.frameLength == 0 {
                    let result = AVAudioPCMBuffer(concatenating: buffers)!
                    do {
                        continuation.resume(returning: try result.convertToDefaultFormat())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public enum Error: Swift.Error {
        case unknown
    }
}

