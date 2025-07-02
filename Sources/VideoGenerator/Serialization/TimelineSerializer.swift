import Foundation
import AVFoundation

// MARK: - TimelineSerializer

public final class TimelineSerializer {
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    public init() {
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Save Timeline
    
    public func save(_ timeline: Timeline, to url: URL) async throws {
        let codableTimeline = await TimelineConverter.convertToCodable(timeline)
        let data = try encoder.encode(codableTimeline)
        try data.write(to: url)
    }
    
    public func saveToData(_ timeline: Timeline) async throws -> Data {
        let codableTimeline = await TimelineConverter.convertToCodable(timeline)
        return try encoder.encode(codableTimeline)
    }
    
    public func saveToString(_ timeline: Timeline) async throws -> String {
        let data = try await saveToData(timeline)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TimelineSerializationError.invalidData
        }
        return string
    }
    
    // MARK: - Load Timeline
    
    public func load(from url: URL) async throws -> Timeline {
        let data = try Data(contentsOf: url)
        return try await load(from: data)
    }
    
    public func load(from data: Data) async throws -> Timeline {
        let codableTimeline = try decoder.decode(CodableTimeline.self, from: data)
        return try await TimelineConverter.convertFromCodable(codableTimeline)
    }
    
    public func load(from string: String) async throws -> Timeline {
        guard let data = string.data(using: .utf8) else {
            throw TimelineSerializationError.invalidData
        }
        return try await load(from: data)
    }
    
    // MARK: - Validation
    
    public func validate(url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        return validate(data: data)
    }
    
    public func validate(data: Data) -> Bool {
        do {
            _ = try decoder.decode(CodableTimeline.self, from: data)
            return true
        } catch {
            return false
        }
    }
    
    public func validate(string: String) -> Bool {
        guard let data = string.data(using: .utf8) else {
            return false
        }
        return validate(data: data)
    }
}

// MARK: - TimelineSerializationError Extension

extension TimelineSerializationError {
    static let invalidData = TimelineSerializationError.missingRequiredField("Invalid data format")
}