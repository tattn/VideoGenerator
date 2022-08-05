//
//  AVAudioPCMBuffer+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import AVKit

extension AVAudioPCMBuffer {
    func sampleBuffer(presentationTimeStamp time: CMTime) throws -> CMSampleBuffer {
        let audioSampleBuffer = try CMSampleBuffer(
            dataBuffer: nil,
            dataReady: false,
            formatDescription: format.formatDescription,
            numSamples: CMItemCount(frameLength),
            presentationTimeStamp: time,
            packetDescriptions: []) { _ in return noErr }
        try audioSampleBuffer.setDataBuffer(fromAudioBufferList: audioBufferList, flags: .audioBufferListAssure16ByteAlignment)
        return audioSampleBuffer
    }
}

extension AVAudioPCMBuffer {
    func append(_ buffer: AVAudioPCMBuffer) {
        append(buffer, startingFrame: 0, frameCount: buffer.frameLength)
    }

    func append(_ buffer: AVAudioPCMBuffer, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) {
        precondition(format == buffer.format, "format != buffer.format")
        precondition(startingFrame + AVAudioFramePosition(frameCount) <= AVAudioFramePosition(buffer.frameLength), "Insufficient audio in buffer")
        precondition(frameLength + frameCount <= frameCapacity, "Insufficient space in buffer")

        let dst = int16ChannelData!
        let src = buffer.int16ChannelData!

        memcpy(dst.pointee.advanced(by: stride * Int(frameLength)),
               src.pointee.advanced(by: stride * Int(startingFrame)),
               Int(frameCount) * stride * MemoryLayout<Int16>.size)

        frameLength += frameCount
    }

    convenience init?(concatenating buffers: [AVAudioPCMBuffer]) {
        precondition(buffers.count > 0)
        let totalFrames = buffers.map(\.frameLength).reduce(0, +)
        self.init(pcmFormat: buffers[0].format, frameCapacity: totalFrames)
        buffers.forEach { append($0) }
    }
}
