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

        let (writer, videoWriterAdaptor) = try makeWriter(configuration: configuration, outputURL: outputURL)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        await Task.detached {
            var clips = clips
            for index in clips.indices {
                clips[index].prepare(with: configuration)
            }
            
            var totalFrameCount = CMTimeValue(0)

            for (clip, nextClip) in zip(clips, Array(clips.dropFirst()) + [nil]) {
                let numberOfFrames = Int(clip.duration * TimeInterval(configuration.fps))

                for frame in 0..<numberOfFrames {
                    autoreleasepool {
                        let effected = clip.render(nextClip: nextClip, configuration: configuration, numberOfFrames: numberOfFrames, currentFrame: frame)
                        context.render(effected, to: pixelBuffer!)
                    }

                    while !videoWriterAdaptor.assetWriterInput.isReadyForMoreMediaData {
                        try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
                    }

                    let time = CMTime(value: totalFrameCount * 600 / Int64(configuration.fps), timescale: CMTimeScale(600))
                    videoWriterAdaptor.append(pixelBuffer!, withPresentationTime: time)

                    totalFrameCount += 1
                }
            }
        }.value

        await writer.finishWriting()
        try await VideoSaver().save(destination: outputURL)
    }

    func makeWriter(configuration: VideoConfiguration, outputURL: URL) throws -> (AVAssetWriter, AVAssetWriterInputPixelBufferAdaptor) {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerVideoInput = AVAssetWriterInput(
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
        let videoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerVideoInput)

        writerVideoInput.expectsMediaDataInRealTime = false
        writer.add(writerVideoInput)

        return (writer, videoWriterAdaptor)
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
}
