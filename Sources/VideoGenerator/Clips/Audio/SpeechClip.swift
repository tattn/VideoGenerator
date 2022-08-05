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
    let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: false)!

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

                    let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(result.frameCapacity) / Double(result.format.sampleRate) * format.sampleRate))!

                    let converter = AVAudioConverter(from: result.format, to: format)!
                    var error: NSError?
                    converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                        outStatus.pointee = .haveData
                        return result
                    }

                    continuation.resume(returning: convertedBuffer)
                }
            }
        }
    }

    public enum Error: Swift.Error {
        case unknown
    }
}

