import Foundation
import AVFoundation
import CoreGraphics
import VideoToolbox

// MARK: - Video Codec

public enum VideoCodec: String, CaseIterable, Sendable {
    case h264 = "h264"
    case h265 = "hevc"
    case prores = "ap4h"
    
    var avCodec: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .h265: return .hevc
        case .prores: return .proRes422
        }
    }
}

// MARK: - Audio Codec

public enum AudioCodec: String, CaseIterable, Sendable {
    case aac = "aac"
    case alac = "alac"
    case pcm = "lpcm"
    
    var formatID: AudioFormatID {
        switch self {
        case .aac: return kAudioFormatMPEG4AAC
        case .alac: return kAudioFormatAppleLossless
        case .pcm: return kAudioFormatLinearPCM
        }
    }
}

// MARK: - Export Preset

public enum ExportPreset: Sendable {
    case low
    case medium
    case high
    case highest
    case custom(bitrate: Int)
    
    var bitrate: Int {
        switch self {
        case .low: return 2_000_000
        case .medium: return 5_000_000
        case .high: return 10_000_000
        case .highest: return 20_000_000
        case .custom(let bitrate): return bitrate
        }
    }
}

// MARK: - Export Settings

public struct ExportSettings: Sendable {
    public var outputURL: URL
    public var videoCodec: VideoCodec
    public var audioCodec: AudioCodec
    public var resolution: CGSize
    public var bitrate: Int
    public var frameRate: Int
    public var preset: ExportPreset
    
    public init(
        outputURL: URL,
        videoCodec: VideoCodec = .h265,
        audioCodec: AudioCodec = .aac,
        resolution: CGSize? = nil,
        bitrate: Int? = nil,
        frameRate: Int = 30,
        preset: ExportPreset = .high
    ) {
        self.outputURL = outputURL
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        // resolution must be explicitly provided or will be derived from timeline
        self.resolution = resolution ?? .zero
        self.bitrate = bitrate ?? preset.bitrate
        self.frameRate = frameRate
        self.preset = preset
    }
    
    var videoOutputSettings: [String: Any] {
        var settings: [String: Any] = [
            AVVideoCodecKey: videoCodec.avCodec,
            AVVideoWidthKey: Int(resolution.width),
            AVVideoHeightKey: Int(resolution.height)
        ]
        
        if videoCodec != .prores {
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate,
                AVVideoProfileLevelKey: videoCodec == .h265 ? kVTProfileLevel_HEVC_Main_AutoLevel as String : AVVideoProfileLevelH264HighAutoLevel
            ]
        }
        
        return settings
    }
    
    var audioOutputSettings: [String: Any] {
        var settings: [String: Any] = [
            AVFormatIDKey: audioCodec.formatID,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100
        ]
        
        switch audioCodec {
        case .aac:
            settings[AVEncoderBitRateKey] = 128000
        case .alac, .pcm:
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsNonInterleaved] = false
        }
        
        return settings
    }
}

// MARK: - Export Progress

public struct ExportProgress: Sendable {
    public let framesCompleted: Int
    public let totalFrames: Int
    public let progress: Double
    public let estimatedTimeRemaining: TimeInterval?
    
    public init(
        framesCompleted: Int,
        totalFrames: Int,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.framesCompleted = framesCompleted
        self.totalFrames = totalFrames
        self.progress = totalFrames > 0 ? Double(framesCompleted) / Double(totalFrames) : 0
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}