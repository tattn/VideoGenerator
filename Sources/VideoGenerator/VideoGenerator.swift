import UIKit
import CoreImage
import AVKit

public struct VideoGenerator {
    public init(configuration: VideoConfiguration = VideoConfiguration(fps: 24, duration: 1)) {
        self.configuration = configuration

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            configuration.width,
            configuration.height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary,
            &pixelBuffer
        )
    }

    private let configuration: VideoConfiguration
    private let context = CIContext(options: [.cacheIntermediates: false, .name: "VideoGenerator"])

    private var pixelBuffer: CVPixelBuffer?

    public func generate(_ clips: [Clip], destination: URL? = nil) async throws {
        let outputURL = destination ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("videogen.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let (writer, videoWriterAdaptor, audioWriterInput) = try makeWriter(configuration: configuration, outputURL: outputURL)

        await Task.detached {
            var clips = clips
            for index in clips.indices {
                clips[index].prepare(with: configuration)
            }

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            await writeAudio(clips: clips, input: audioWriterInput)
            await writeVideo(clips: clips, adaptor: videoWriterAdaptor)

            await writer.finishWriting()
        }.value

        try await VideoSaver().save(destination: outputURL)
    }

    private func writeAudio(clips: [Clip], input: AVAssetWriterInput) async {
        var totalFrameCount = 0

        for clip in clips {
            let timestamp = configuration.time(currentFrame: totalFrameCount)

            await Task { // instead of autoreleasepool
                if let sampleBuffer = try? await clip.audio?.render().sampleBuffer(presentationTimeStamp: timestamp) {
                    let duration = sampleBuffer.duration
                    input.append(sampleBuffer)
                    let restOfFrames = Int(Double(duration.timescale) * max(0, clip.duration - duration.seconds))
                    input.append(.createSilentAudio(presentationTimeStamp: timestamp + duration, numberOfFrames: restOfFrames, sampleRate: Float64(duration.timescale))!)
                } else {
                    input.append(.createSilentAudio(presentationTimeStamp: timestamp, numberOfFrames: Int(44100 * clip.duration))!)
                }
            }.value

            totalFrameCount += Int(clip.duration * TimeInterval(configuration.fps))
        }
        input.markAsFinished()
    }

    private func writeVideo(clips: [Clip], adaptor: AVAssetWriterInputPixelBufferAdaptor) async {
        var totalFrameCount = 0

        for (clip, nextClip) in zip(clips, Array(clips.dropFirst()) + [nil]) {
            let numberOfFrames = Int(clip.duration * TimeInterval(configuration.fps))

            for frame in 0..<numberOfFrames {
                autoreleasepool {
                    let effected = clip.video.render(nextClip: nextClip?.video, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: frame)
                    context.render(effected, to: pixelBuffer!)

                    let time = configuration.time(currentFrame: totalFrameCount)
                    adaptor.append(pixelBuffer!, withPresentationTime: time)

                    totalFrameCount += 1
                }

                while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                    try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 50)
                }
            }
        }
    }

    func makeWriter(configuration: VideoConfiguration, outputURL: URL) throws -> (AVAssetWriter, AVAssetWriterInputPixelBufferAdaptor, AVAssetWriterInput) {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: configuration.width,
                AVVideoHeightKey: configuration.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoExpectedSourceFrameRateKey: configuration.fps,
                    AVVideoAverageBitRateKey: 10485760,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: configuration.fps,
                    AVVideoAllowFrameReorderingKey: 1
                ],
            ]
        )
        let videoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput)

        let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ])

        videoWriterInput.expectsMediaDataInRealTime = false
        audioWriterInput.expectsMediaDataInRealTime = false
        writer.add(videoWriterInput)
        writer.add(audioWriterInput)

        return (writer, videoWriterAdaptor, audioWriterInput)
    }
}

public struct VideoConfiguration: Sendable {
    public init(fps: Int, duration: CGFloat) {
        self.fps = fps
        self.duration = duration
    }

    let fps: Int
    let duration: CGFloat
    let width: Int = 1080
    let height: Int = 1920

    var size: CGSize {
        .init(width: width, height: height)
    }

    func time(currentFrame: Int) -> CMTime {
        CMTime(value: Int64(currentFrame * 600 / fps), timescale: CMTimeScale(600))
    }
}
