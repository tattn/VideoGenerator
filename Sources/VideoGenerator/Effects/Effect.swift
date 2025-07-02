import Foundation
@preconcurrency import CoreImage
import AVFoundation

// MARK: - Effect Protocol

public protocol Effect: Sendable {
    var id: UUID { get }
    var parameters: EffectParameters { get set }
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage
}

// MARK: - EffectParameters

public struct EffectParameters: Sendable {
    private let storage: [String: SendableValue]
    
    public init(_ parameters: [String: SendableValue] = [:]) {
        self.storage = parameters
    }
    
    public subscript<T: Sendable>(key: String) -> T? {
        get { storage[key]?.value as? T }
    }
}

// MARK: - SendableValue

public enum SendableValue: Sendable {
    case double(Double)
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case color(CGColor)
    case size(CGSize)
    case point(CGPoint)
    
    var value: any Sendable {
        switch self {
        case .double(let v): return v
        case .float(let v): return v
        case .int(let v): return v
        case .bool(let v): return v
        case .string(let v): return v
        case .color(let v): return v
        case .size(let v): return v
        case .point(let v): return v
        }
    }
}

// MARK: - Base Effect Class

public struct BaseEffect: Effect {
    public let id: UUID
    public var parameters: EffectParameters
    private let applyFunction: @Sendable (CIImage, CMTime, any RenderContext) async throws -> CIImage
    
    public init(
        id: UUID = UUID(),
        parameters: EffectParameters = EffectParameters(),
        apply: @escaping @Sendable (CIImage, CMTime, any RenderContext) async throws -> CIImage
    ) {
        self.id = id
        self.parameters = parameters
        self.applyFunction = apply
    }
    
    public func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        try await applyFunction(image, time, renderContext)
    }
}