//
//  CMSampleBuffer+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/05.
//

import CoreMedia

extension CMSampleBuffer {
    static func createSilentAudio(presentationTimeStamp time: CMTime, numberOfFrames: Int, sampleRate: Float64 = 44100, numberOfChannels: UInt32 = 1) -> CMSampleBuffer? {
        let bytesPerFrame = UInt32(2 * numberOfChannels)
        let blockSize = numberOfFrames * Int(bytesPerFrame)

        var block: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: blockSize,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: blockSize,
            flags: 0,
            blockBufferOut: &block
        )
        assert(status == kCMBlockBufferNoErr)

        status = CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: blockSize)
        assert(status == kCMBlockBufferNoErr)

        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: numberOfChannels,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var formatDesc: CMAudioFormatDescription?
        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)
        assert(status == noErr)

        var sampleBuffer: CMSampleBuffer?

        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: block!,
            formatDescription: formatDesc!,
            sampleCount: numberOfFrames,
            presentationTimeStamp: time,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        assert(status == noErr)

        return sampleBuffer
    }
}
