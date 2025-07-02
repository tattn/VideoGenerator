import Foundation
@preconcurrency import AVFoundation

// MARK: - AudioMixer

public actor AudioMixer {
    private let engine: AVAudioEngine
    private let mixer: AVAudioMixerNode
    private let sampleRate: Double = 44100
    
    public init() {
        self.engine = AVAudioEngine()
        self.mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }
    
    public func mix(tracks: [Track], at timeRange: CMTimeRange) async throws -> AVAudioPCMBuffer? {
        let audioTracks = tracks.filter { $0.trackType == .audio && $0.isEnabled }
        guard !audioTracks.isEmpty else { return nil }
        
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!
        
        let frameCount = AVAudioFrameCount(timeRange.duration.seconds * sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VideoGeneratorError.audioMixingFailed
        }
        outputBuffer.frameLength = frameCount
        
        let buffers = try await extractAudioBuffers(from: audioTracks, timeRange: timeRange, format: format)
        
        if buffers.isEmpty {
            return createSilentBuffer(format: format, frameCount: frameCount)
        }
        
        mixBuffers(buffers, into: outputBuffer, tracks: audioTracks)
        
        return outputBuffer
    }
    
    private func extractAudioBuffers(
        from tracks: [Track],
        timeRange: CMTimeRange,
        format: AVAudioFormat
    ) async throws -> [AVAudioPCMBuffer] {
        var buffers: [AVAudioPCMBuffer] = []
        
        for track in tracks {
            let clips = track.clips.filter { clip in
                clip.mediaItem.mediaType == .audio &&
                clip.timeRange.intersection(timeRange).duration.seconds > 0
            }
            
            for clip in clips {
                guard let audioItem = clip.mediaItem as? AudioMediaItem else { continue }
                
                let buffer = try await extractAudioFromClip(
                    audioItem: audioItem,
                    clipTimeRange: clip.timeRange,
                    requestedTimeRange: timeRange,
                    format: format,
                    volume: track.volume ?? 1.0
                )
                
                if let buffer = buffer {
                    buffers.append(buffer)
                }
            }
        }
        
        return buffers
    }
    
    private func extractAudioFromClip(
        audioItem: AudioMediaItem,
        clipTimeRange: CMTimeRange,
        requestedTimeRange: CMTimeRange,
        format: AVAudioFormat,
        volume: Float
    ) async throws -> AVAudioPCMBuffer? {
        let asset = AVAsset(url: audioItem.url)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }
        
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        
        let intersection = clipTimeRange.intersection(requestedTimeRange)
        reader.timeRange = intersection
        
        guard reader.startReading() else {
            throw VideoGeneratorError.audioExtractionFailed
        }
        
        let frameCount = AVAudioFrameCount(intersection.duration.seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        var totalFramesRead: AVAudioFrameCount = 0
        
        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            
            let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
            var length: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            
            if let blockBuffer = blockBuffer {
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil,
                                          totalLengthOut: &length, dataPointerOut: &dataPointer)
                
                if let dataPointer = dataPointer, let floatChannelData = buffer.floatChannelData {
                    let frameLength = AVAudioFrameCount(length) / format.streamDescription.pointee.mBytesPerFrame
                    let samplesToRead = min(frameLength, frameCount - totalFramesRead)
                    
                    dataPointer.withMemoryRebound(to: Float.self, capacity: Int(samplesToRead) * Int(format.channelCount)) { floatPointer in
                        for channel in 0..<Int(format.channelCount) {
                            for frame in 0..<Int(samplesToRead) {
                                let index = frame * Int(format.channelCount) + channel
                                floatChannelData[channel][Int(totalFramesRead) + frame] = floatPointer[index] * volume
                            }
                        }
                    }
                    
                    totalFramesRead += samplesToRead
                }
            }
        }
        
        buffer.frameLength = totalFramesRead
        return buffer
    }
    
    private func mixBuffers(_ buffers: [AVAudioPCMBuffer], into outputBuffer: AVAudioPCMBuffer, tracks: [Track]) {
        guard let outputFloatChannelData = outputBuffer.floatChannelData else { return }
        
        let channelCount = Int(outputBuffer.format.channelCount)
        let frameLength = Int(outputBuffer.frameLength)
        
        for channel in 0..<channelCount {
            let outputChannel = outputFloatChannelData[channel]
            
            for frame in 0..<frameLength {
                outputChannel[frame] = 0
            }
            
            for buffer in buffers {
                guard let inputFloatChannelData = buffer.floatChannelData else { continue }
                let inputChannel = inputFloatChannelData[min(channel, Int(buffer.format.channelCount) - 1)]
                
                for frame in 0..<min(frameLength, Int(buffer.frameLength)) {
                    outputChannel[frame] += inputChannel[frame]
                }
            }
            
            for frame in 0..<frameLength {
                outputChannel[frame] = max(-1.0, min(1.0, outputChannel[frame]))
            }
        }
    }
    
    private func createSilentBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        
        if let floatChannelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                let channelData = floatChannelData[channel]
                for frame in 0..<Int(frameCount) {
                    channelData[frame] = 0
                }
            }
        }
        
        return buffer
    }
}

// MARK: - Error Extensions

extension VideoGeneratorError {
    static let audioMixingFailed = VideoGeneratorError.renderingFailed
    static let audioExtractionFailed = VideoGeneratorError.renderingFailed
}