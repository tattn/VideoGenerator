import Foundation
@preconcurrency import AVFoundation

// MARK: - AudioMixer

public actor AudioMixer {
    private let engine: AVAudioEngine
    private let mixer: AVAudioMixerNode
    
    // Cache for audio assets to avoid recreating AVAssetReaders
    private var assetCache: [URL: AVAsset] = [:]
    private var trackCache: [URL: AVAssetTrack] = [:]
    
    public init() {
        self.engine = AVAudioEngine()
        self.mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }
    
    public func mix(tracks: [Track], at timeRange: CMTimeRange) async throws -> AVAudioPCMBuffer? {
        let audioTracks = tracks.filter { $0.trackType == .audio && $0.isEnabled }
        guard !audioTracks.isEmpty else { return nil }
        
        // Determine the sample rate from the first audio clip
        let sampleRate = try await determineSampleRate(from: audioTracks)
        
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
    
    private func determineSampleRate(from tracks: [Track]) async throws -> Double {
        // Find the first audio clip and get its sample rate
        for track in tracks {
            for clip in track.clips {
                if let audioItem = clip.mediaItem as? AudioMediaItem {
                    let asset = getOrCreateAsset(for: audioItem.url)
                    if let audioTrack = try await getOrLoadAudioTrack(for: audioItem.url, asset: asset) {
                        let assetTrack = try await audioTrack.load(.naturalTimeScale)
                        return Double(assetTrack)
                    }
                }
            }
        }
        // Default to 48000 if no audio tracks found
        return 48000
    }
    
    private func getOrCreateAsset(for url: URL) -> AVAsset {
        if let cachedAsset = assetCache[url] {
            return cachedAsset
        }
        let asset = AVAsset(url: url)
        assetCache[url] = asset
        return asset
    }
    
    private func getOrLoadAudioTrack(for url: URL, asset: AVAsset) async throws -> AVAssetTrack? {
        if let cachedTrack = trackCache[url] {
            return cachedTrack
        }
        
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        if let track = tracks.first {
            trackCache[url] = track
            return track
        }
        return nil
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
                
                let volume = track.volume ?? 1.0
                
                let buffer = try await extractAudioFromClip(
                    audioItem: audioItem,
                    clipTimeRange: clip.timeRange,
                    requestedTimeRange: timeRange,
                    format: format,
                    volume: volume
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
        let asset = getOrCreateAsset(for: audioItem.url)
        guard let audioTrack = try await getOrLoadAudioTrack(for: audioItem.url, asset: asset) else {
            return nil
        }
        
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true  // Changed to non-interleaved to match AVAudioPCMBuffer format
        ]
        
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        
        // Calculate the intersection of clip time range and requested time range
        let intersection = clipTimeRange.intersection(requestedTimeRange)
        
        // Calculate the offset in the audio file
        // If the clip starts at 0 and we're requesting time 1-2, we need to read from 1-2 in the audio file
        let offsetInAudioFile = requestedTimeRange.start - clipTimeRange.start
        let audioStartTime = max(.zero, offsetInAudioFile)
        let audioReadTimeRange = CMTimeRange(start: audioStartTime, duration: intersection.duration)
        
        
        reader.timeRange = audioReadTimeRange
        
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
                    let bytesPerChannel = length / Int(format.channelCount)
                    let frameLength = AVAudioFrameCount(bytesPerChannel / MemoryLayout<Float>.size)
                    let samplesToRead = min(frameLength, frameCount - totalFramesRead)
                    
                    dataPointer.withMemoryRebound(to: Float.self, capacity: Int(samplesToRead) * Int(format.channelCount)) { floatPointer in
                        
                        // Non-interleaved format: all samples for channel 0, then all samples for channel 1, etc.
                        for channel in 0..<Int(format.channelCount) {
                            let channelOffset = channel * Int(samplesToRead)
                            for frame in 0..<Int(samplesToRead) {
                                let rawValue = floatPointer[channelOffset + frame]
                                floatChannelData[channel][Int(totalFramesRead) + frame] = rawValue * volume
                            }
                        }
                    }
                    
                    totalFramesRead += samplesToRead
                }
            }
        }
        
        buffer.frameLength = totalFramesRead
        
        // Apply very short fade in/out only at the actual start and end of the clip
        if let floatChannelData = buffer.floatChannelData {
            // Only apply fades at the actual boundaries of the audio clip
            let isStartOfClip = offsetInAudioFile == .zero
            let isEndOfClip = (offsetInAudioFile + intersection.duration) >= audioItem.duration
            
            if isStartOfClip || isEndOfClip {
                let fadeFrames = min(32, Int(totalFramesRead) / 20) // Very short fade
                
                for channel in 0..<Int(format.channelCount) {
                    let channelData = floatChannelData[channel]
                    
                    // Fade in only at start of clip
                    if isStartOfClip {
                        for i in 0..<fadeFrames {
                            let factor = Float(i) / Float(fadeFrames)
                            channelData[i] *= factor
                        }
                    }
                    
                    // Fade out only at end of clip
                    if isEndOfClip {
                        let startFadeOut = Int(totalFramesRead) - fadeFrames
                        for i in 0..<fadeFrames {
                            let factor = Float(fadeFrames - i) / Float(fadeFrames)
                            channelData[startFadeOut + i] *= factor
                        }
                    }
                }
            }
        }
        
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