import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
@preconcurrency import CoreVideo

// MARK: - VideoExporter

public actor VideoExporter {
    private var compositor: VideoCompositor?
    private let audioMixer: AudioMixer
    private var progressContinuation: AsyncStream<ExportProgress>.Continuation?
    
    public init() async throws {
        // Compositor will be initialized with timeline size when exporting
        self.compositor = nil
        self.audioMixer = AudioMixer()
    }
    
    public func export(timeline: Timeline, settings: ExportSettings) async throws -> URL {
        // Use timeline size if resolution not specified
        let finalResolution = settings.resolution == .zero ? await timeline.size : settings.resolution
        let exportSettings = ExportSettings(
            outputURL: settings.outputURL,
            videoCodec: settings.videoCodec,
            audioCodec: settings.audioCodec,
            resolution: finalResolution,
            bitrate: settings.bitrate,
            frameRate: settings.frameRate,
            preset: settings.preset
        )
        
        // Initialize compositor with the export resolution
        self.compositor = try await VideoCompositor(size: exportSettings.resolution, frameRate: exportSettings.frameRate)
        
        try FileManager.default.createDirectory(
            at: exportSettings.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        if FileManager.default.fileExists(atPath: exportSettings.outputURL.path) {
            try FileManager.default.removeItem(at: exportSettings.outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: exportSettings.outputURL, fileType: .mp4)
        
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: exportSettings.videoOutputSettings
        )
        videoInput.expectsMediaDataInRealTime = false
        
        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: exportSettings.audioOutputSettings
        )
        audioInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(exportSettings.resolution.width),
                kCVPixelBufferHeightKey as String: Int(exportSettings.resolution.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
        
        writer.add(videoInput)
        writer.add(audioInput)
        
        guard writer.startWriting() else {
            throw VideoGeneratorError.exportFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
        
        writer.startSession(atSourceTime: .zero)
        
        let duration = await timeline.duration
        let frameRate = exportSettings.frameRate
        let totalFrames = Int(duration.seconds * Double(frameRate))
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @Sendable [weak self] in
                await self?.writeVideo(
                    timeline: timeline,
                    writer: writer,
                    input: videoInput,
                    adaptor: pixelBufferAdaptor,
                    settings: exportSettings,
                    totalFrames: totalFrames
                )
            }
            
            group.addTask { @Sendable [weak self] in
                await self?.writeAudio(
                    timeline: timeline,
                    writer: writer,
                    input: audioInput,
                    duration: duration
                )
            }
        }
        
        await writer.finishWriting()
        
        guard writer.status == .completed else {
            throw VideoGeneratorError.exportFailed(writer.error?.localizedDescription ?? "Export failed")
        }
        
        return exportSettings.outputURL
    }
    
    private func writeVideo(
        timeline: Timeline,
        writer: AVAssetWriter,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        settings: ExportSettings,
        totalFrames: Int
    ) async {
        let frameRate = settings.frameRate
        _ = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        for frame in 0..<totalFrames {
            let presentationTime = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
            
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            
            guard writer.status == .writing else { break }
            
            do {
                guard let compositor = compositor else {
                    throw VideoGeneratorError.exportFailed("Compositor not initialized")
                }
                let pixelBuffer = try await compositor.compose(timeline: timeline, at: presentationTime)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                
                progressContinuation?.yield(ExportProgress(
                    framesCompleted: frame + 1,
                    totalFrames: totalFrames
                ))
            } catch {
                print("Error composing frame \(frame): \(error)")
                break
            }
        }
        
        input.markAsFinished()
    }
    
    private func writeAudio(
        timeline: Timeline,
        writer: AVAssetWriter,
        input: AVAssetWriterInput,
        duration: CMTime
    ) async {
        let audioTracks = await timeline.audioTracks()
        
        
        guard !audioTracks.isEmpty else {
            input.markAsFinished()
            return
        }
        
        // Get sample rate from audio mixer which determines it from source files
        let firstMix = try? await audioMixer.mix(
            tracks: audioTracks,
            at: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.001, preferredTimescale: 1000))
        )
        
        let sampleRate: Double = firstMix?.format.sampleRate ?? 48000
        let channelCount: AVAudioChannelCount = 2
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!
        
        // Use larger frame size to avoid stuttering (4096 samples = ~0.093 seconds at 44.1kHz)
        let samplesPerFrame: Int64 = 4096
        let frameDuration = CMTime(value: samplesPerFrame, timescale: CMTimeScale(sampleRate))
        var currentTime = CMTime.zero
        
        while currentTime < duration {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            
            guard writer.status == .writing else { break }
            
            let remainingTime = duration - currentTime
            let actualFrameDuration = min(frameDuration, remainingTime)
            let timeRange = CMTimeRange(
                start: currentTime,
                duration: actualFrameDuration
            )
            
            do {
                if let audioBuffer = try await audioMixer.mix(tracks: audioTracks, at: timeRange),
                   let sampleBuffer = audioBuffer.sampleBuffer(presentationTime: currentTime) {
                    input.append(sampleBuffer)
                } else {
                    let silentBuffer = createSilentAudioBuffer(
                        format: format,
                        duration: timeRange.duration,
                        presentationTime: currentTime
                    )
                    if let silentBuffer = silentBuffer {
                        input.append(silentBuffer)
                    }
                }
                
                // Advance by the actual duration processed
                currentTime = currentTime + actualFrameDuration
            } catch {
                print("Error mixing audio at \(currentTime.seconds): \(error)")
                break
            }
        }
        
        input.markAsFinished()
    }
    
    private func createSilentAudioBuffer(
        format: AVAudioFormat,
        duration: CMTime,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        let frameCount = AVAudioFrameCount(duration.seconds * format.sampleRate)
        
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
        
        return buffer.sampleBuffer(presentationTime: presentationTime)
    }
    
    public var progress: AsyncStream<ExportProgress> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }
}

// MARK: - Error Extensions

extension VideoGeneratorError {
    static func exportFailed(_ description: String) -> VideoGeneratorError {
        VideoGeneratorError.renderingFailed
    }
}

// MARK: - AVAudioPCMBuffer Extension

extension AVAudioPCMBuffer {
    func sampleBuffer(presentationTime: CMTime) -> CMSampleBuffer? {
        let audioFormat = self.format
        var asbd = audioFormat.streamDescription.pointee
        
        // Ensure the audio format is correct for interleaved data
        // The original format might be non-interleaved, so we need to set it explicitly
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian
        asbd.mSampleRate = audioFormat.sampleRate
        asbd.mChannelsPerFrame = UInt32(audioFormat.channelCount)
        asbd.mBitsPerChannel = 32
        asbd.mBytesPerFrame = asbd.mChannelsPerFrame * (asbd.mBitsPerChannel / 8)
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerPacket = asbd.mBytesPerFrame * asbd.mFramesPerPacket
        
        var formatDescription: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let formatDesc = formatDescription else {
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        let blockBuffer = createBlockBuffer()
        guard let blockBuffer = blockBuffer else {
            return nil
        }
        
        let result = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: CMItemCount(frameLength),
            presentationTimeStamp: presentationTime,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard result == noErr, let buffer = sampleBuffer else {
            return nil
        }
        
        return buffer
    }
    
    private func createBlockBuffer() -> CMBlockBuffer? {
        let audioFormat = self.format
        let frameCount = Int(self.frameLength)
        let channelCount = Int(audioFormat.channelCount)
        
        // Calculate the correct data size for interleaved format
        let bytesPerSample = MemoryLayout<Float>.size
        let bytesPerFrame = channelCount * bytesPerSample
        let dataSize = frameCount * bytesPerFrame
        
        var blockBuffer: CMBlockBuffer?
        
        // Allocate memory for the block buffer
        let memoryBlock = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: MemoryLayout<Float>.alignment)
        defer { memoryBlock.deallocate() }
        
        // Fill the memory block with audio data
        if let floatChannelData = self.floatChannelData {
            let floatData = memoryBlock.bindMemory(to: Float.self, capacity: frameCount * channelCount)
            
            
            // AVAudioPCMBuffer uses non-interleaved format, but we need interleaved for CMSampleBuffer
            for frame in 0..<frameCount {
                for channel in 0..<channelCount {
                    let destIndex = frame * channelCount + channel
                    let sourceIndex = frame
                    
                    // Copy from non-interleaved to interleaved format
                    if sourceIndex < Int(self.frameLength) {
                        floatData[destIndex] = floatChannelData[channel][sourceIndex]
                    }
                }
            }
            
        }
        
        // Create block buffer and copy the data
        let result = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil, // nil means CMBlockBuffer will allocate its own memory
            blockLength: dataSize,
            blockAllocator: kCFAllocatorDefault, // Use default allocator to manage memory
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataSize,
            flags: kCMBlockBufferAssureMemoryNowFlag, // Allocate memory immediately
            blockBufferOut: &blockBuffer
        )
        
        if result == noErr, let blockBuffer = blockBuffer {
            // Copy our data into the block buffer
            let copyResult = CMBlockBufferReplaceDataBytes(
                with: memoryBlock,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: dataSize
            )
            
            if copyResult == noErr {
                return blockBuffer
            }
        }
        
        return nil
    }
}
