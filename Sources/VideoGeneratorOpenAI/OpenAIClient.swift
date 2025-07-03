import Foundation
import VideoGenerator

// Custom JSONEncoder that preserves key order
private final class OrderPreservingJSONEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = _OrderPreservingEncoder()
        try value.encode(to: encoder)
        guard let topLevel = encoder.storage.last else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }
        
        // Convert to JSON string manually to preserve order
        let jsonString = try convertToJSONString(topLevel)
        guard let data = jsonString.data(using: .utf8) else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Failed to convert JSON string to data"))
        }
        return data
    }
    
    private func convertToJSONString(_ value: Any) throws -> String {
        if let dict = value as? NSMutableDictionary {
            var result = "{"
            var first = true
            for (key, val) in dict {
                if !first { result += "," }
                first = false
                result += "\"\(key)\":"
                result += try convertToJSONString(val)
            }
            result += "}"
            return result
        } else if let array = value as? NSMutableArray {
            var result = "["
            var first = true
            for val in array {
                if !first { result += "," }
                first = false
                result += try convertToJSONString(val)
            }
            result += "]"
            return result
        } else if let string = value as? String {
            let escaped = string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        } else if let number = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return number.boolValue ? "true" : "false"
            } else {
                return "\(number)"
            }
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if value is NSNull {
            return "null"
        } else {
            // Fallback to JSONSerialization for complex types
            let data = try JSONSerialization.data(withJSONObject: value)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}

private final class _OrderPreservingEncoder: Encoder {
    var storage: [Any] = []
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = OrderPreservingKeyedEncodingContainer<Key>(encoder: self)
        storage.append(container.storage)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: self)
        storage.append(container.storage)
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return OrderPreservingSingleValueEncodingContainer(encoder: self)
    }
}

private final class OrderPreservingKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    private let encoder: _OrderPreservingEncoder
    var storage: NSMutableDictionary = NSMutableDictionary()
    var codingPath: [CodingKey] { encoder.codingPath }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil(forKey key: Key) throws {
        storage[key.stringValue] = NSNull()
    }
    
    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        if let value = value as? String {
            storage[key.stringValue] = value
        } else if let value = value as? Int {
            storage[key.stringValue] = value
        } else if let value = value as? Double {
            storage[key.stringValue] = value
        } else if let value = value as? Bool {
            storage[key.stringValue] = value
        } else if value is NSNull {
            storage[key.stringValue] = NSNull()
        } else {
            let subEncoder = _OrderPreservingEncoder()
            subEncoder.codingPath = encoder.codingPath
            try value.encode(to: subEncoder)
            if let encoded = subEncoder.storage.last {
                storage[key.stringValue] = encoded
            }
        }
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        let container = OrderPreservingKeyedEncodingContainer<NestedKey>(encoder: encoder)
        storage[key.stringValue] = container.storage
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }
        
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: encoder)
        storage[key.stringValue] = container.storage
        return container
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }
}

private final class OrderPreservingUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    private let encoder: _OrderPreservingEncoder
    var storage: NSMutableArray = NSMutableArray()
    var codingPath: [CodingKey] { encoder.codingPath }
    var count: Int { storage.count }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil() throws {
        storage.add(NSNull())
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        if let value = value as? String {
            storage.add(value)
        } else if let value = value as? Int {
            storage.add(value)
        } else if let value = value as? Double {
            storage.add(value)
        } else if let value = value as? Bool {
            storage.add(value)
        } else if value is NSNull {
            storage.add(NSNull())
        } else {
            let subEncoder = _OrderPreservingEncoder()
            subEncoder.codingPath = encoder.codingPath
            try value.encode(to: subEncoder)
            if let encoded = subEncoder.storage.last {
                storage.add(encoded)
            }
        }
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let container = OrderPreservingKeyedEncodingContainer<NestedKey>(encoder: encoder)
        storage.add(container.storage)
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = OrderPreservingUnkeyedEncodingContainer(encoder: encoder)
        storage.add(container.storage)
        return container
    }
    
    func superEncoder() -> Encoder {
        return encoder
    }
}

private final class OrderPreservingSingleValueEncodingContainer: SingleValueEncodingContainer {
    private let encoder: _OrderPreservingEncoder
    var codingPath: [CodingKey] { encoder.codingPath }
    
    init(encoder: _OrderPreservingEncoder) {
        self.encoder = encoder
    }
    
    func encodeNil() throws {
        encoder.storage.append(NSNull())
    }
    
    func encode<T: Encodable>(_ value: T) throws {
        if let value = value as? String {
            encoder.storage.append(value)
        } else if let value = value as? Int {
            encoder.storage.append(value)
        } else if let value = value as? Double {
            encoder.storage.append(value)
        } else if let value = value as? Bool {
            encoder.storage.append(value)
        } else if value is NSNull {
            encoder.storage.append(NSNull())
        } else {
            try value.encode(to: encoder)
        }
    }
}

public actor OpenAIClient: Sendable {
    public struct Configuration: Sendable {
        public let apiKey: String
        public let baseURL: URL
        public let model: String
        public let imageGenerationOptions: ImageGenerationOptions
        public let requestTimeoutInterval: TimeInterval
        
        public init(
            apiKey: String,
            baseURL: URL = URL(string: "https://api.openai.com/v1")!,
            model: String = "gpt-4.1",
            imageGenerationOptions: ImageGenerationOptions = ImageGenerationOptions(),
            requestTimeoutInterval: TimeInterval = 300 // Default 5 minutes
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
            self.imageGenerationOptions = imageGenerationOptions
            self.requestTimeoutInterval = requestTimeoutInterval
        }
    }
    
    public struct ChatCompletionRequest: Encodable, Sendable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat?
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case responseFormat = "response_format"
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(model, forKey: .model)
            try container.encode(messages, forKey: .messages)
            try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
        }
    }
    
    public struct Message: Codable, Sendable {
        let role: String
        let content: String
    }
    
    public struct ResponseFormat: Encodable, Sendable {
        let type: String
        let jsonSchema: JSONSchema?
        
        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode type first to ensure it appears first in the JSON
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(jsonSchema, forKey: .jsonSchema)
        }
    }
    
    public struct JSONSchema: Encodable, Sendable {
        let name: String
        let strict: Bool
        private let schemaData: Data
        
        enum CodingKeys: String, CodingKey {
            case name
            case strict
            case schema
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            // Encode in the desired order: name, strict, schema
            try container.encode(name, forKey: .name)
            try container.encode(strict, forKey: .strict)
            
            // Decode the JSON data and encode it directly without base64 encoding
            let jsonObject = try JSONSerialization.jsonObject(with: schemaData)
            try container.encode(AnyEncodable(jsonObject), forKey: .schema)
        }
        
        public init(name: String, strict: Bool, schema: [String: Any]) throws {
            self.name = name
            self.strict = strict
            self.schemaData = try JSONSerialization.data(withJSONObject: schema)
        }
    }
    
    public struct ChatCompletionResponse: Codable, Sendable {
        let choices: [Choice]
        
        public struct Choice: Codable, Sendable {
            let message: Message
        }
    }
    
    public struct ImageGenerationRequest: Codable, Sendable {
        let model: String
        let prompt: String
        let size: String
        let quality: String
        let n: Int
        let responseFormat: String
        
        enum CodingKeys: String, CodingKey {
            case model
            case prompt
            case size
            case quality
            case n
            case responseFormat = "response_format"
        }
    }
    
    public struct ImageGenerationResponse: Codable, Sendable {
        let data: [ImageData]
        
        public struct ImageData: Codable, Sendable {
            let b64Json: String
            
            enum CodingKeys: String, CodingKey {
                case b64Json = "b64_json"
            }
        }
    }
    
    public enum OpenAIError: Error, Sendable {
        case invalidResponse
        case networkError(String)
        case decodingError(String)
        case invalidTimelineSchema
        case imageGenerationError(String)
    }
    
    private let configuration: Configuration
    private let session: URLSession
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeoutInterval
        sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeoutInterval
        
        self.session = URLSession(configuration: sessionConfiguration)
    }
    
    public func generateTimeline(prompt: String) async throws -> Timeline {
        let timelineSchema = try loadTimelineSchema()
        
        var systemPrompt = "You are a video timeline generator. Generate a timeline JSON that follows the provided schema based on the user's prompt."
        
        if configuration.imageGenerationOptions.maxImages > 0 {
            systemPrompt += " When generating image media items, use descriptive text in the 'imageData' field with a special prefix 'GENERATE_IMAGE:' followed by the image description. You can generate up to \(configuration.imageGenerationOptions.maxImages) images."
        }
        
        let request = ChatCompletionRequest(
            model: configuration.model,
            messages: [
                Message(
                    role: "system",
                    content: systemPrompt
                ),
                Message(
                    role: "user",
                    content: prompt
                )
            ],
            responseFormat: ResponseFormat(
                type: "json_schema",
                jsonSchema: try JSONSchema(
                    name: "timeline",
                    strict: true,
                    schema: timelineSchema
                )
            )
        )
        
        let response = try await performRequest(request)
        
        guard let content = response.choices.first?.message.content,
              let data = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        
        let serializer = TimelineSerializer()
        var timeline = try await serializer.load(from: data)
        
        if configuration.imageGenerationOptions.maxImages > 0 {
            timeline = try await processImageGeneration(in: timeline)
        }
        
        return timeline
    }
    
    private func performRequest(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = OrderPreservingJSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw OpenAIError.networkError("Invalid response: \(response)")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw OpenAIError.decodingError(error.localizedDescription)
        }
    }
    
    private func loadTimelineSchema() throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIError.invalidTimelineSchema
        }
        return schema
    }
    
    private func processImageGeneration(in timeline: Timeline) async throws -> Timeline {
        let serializer = TimelineSerializer()
        let timelineData = try await serializer.saveToData(timeline)
        guard var timelineDict = try JSONSerialization.jsonObject(with: timelineData) as? [String: Any],
              var tracks = timelineDict["tracks"] as? [[String: Any]] else {
            return timeline
        }
        
        var generatedCount = 0
        
        for (trackIndex, track) in tracks.enumerated() {
            guard var clips = track["clips"] as? [[String: Any]] else { continue }
            
            for (clipIndex, clip) in clips.enumerated() {
                guard let mediaItem = clip["mediaItem"] as? [String: Any],
                      let mediaType = mediaItem["mediaType"] as? String,
                      mediaType == "image",
                      let imageData = mediaItem["imageData"] as? String,
                      imageData.hasPrefix("GENERATE_IMAGE:") else { continue }
                
                if generatedCount >= configuration.imageGenerationOptions.maxImages {
                    continue
                }
                
                let prompt = String(imageData.dropFirst("GENERATE_IMAGE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                do {
                    let generatedImageData = try await generateImage(prompt: prompt)
                    
                    var updatedMediaItem = mediaItem
                    updatedMediaItem["imageData"] = generatedImageData
                    
                    var updatedClip = clip
                    updatedClip["mediaItem"] = updatedMediaItem
                    
                    clips[clipIndex] = updatedClip
                    generatedCount += 1
                } catch {
                    print("Failed to generate image for prompt: \(prompt), error: \(error)")
                }
            }
            
            var updatedTrack = track
            updatedTrack["clips"] = clips
            tracks[trackIndex] = updatedTrack
        }
        
        timelineDict["tracks"] = tracks
        let updatedData = try JSONSerialization.data(withJSONObject: timelineDict)
        return try await serializer.load(from: updatedData)
    }
    
    private func generateImage(prompt: String) async throws -> String {
        let request = ImageGenerationRequest(
            model: configuration.imageGenerationOptions.model,
            prompt: prompt,
            size: configuration.imageGenerationOptions.size,
            quality: configuration.imageGenerationOptions.quality,
            n: 1,
            responseFormat: "b64_json"
        )
        
        let endpoint = configuration.baseURL.appendingPathComponent("images/generations")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.imageGenerationError("Failed to generate image: \(errorString)")
        }
        
        let decoder = JSONDecoder()
        let imageResponse = try decoder.decode(ImageGenerationResponse.self, from: data)
        
        guard let imageData = imageResponse.data.first?.b64Json else {
            throw OpenAIError.imageGenerationError("No image data in response")
        }
        
        return imageData
    }
}

// Helper structs for encoding/decoding [String: Any]
private struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        if let array = value as? [Any] {
            var container = encoder.unkeyedContainer()
            for item in array {
                try container.encode(AnyEncodable(item))
            }
        } else if let dictionary = value as? [String: Any] {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dictionary {
                try container.encode(AnyEncodable(value), forKey: DynamicCodingKey(stringValue: key))
            }
        } else if let string = value as? String {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        } else if let number = value as? NSNumber {
            // Handle NSNumber properly - check if it's actually a boolean
            // NSNumber can represent booleans, but we need to be careful with 0 and 1
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                var container = encoder.singleValueContainer()
                try container.encode(number.boolValue)
            } else if String(cString: number.objCType) == "c" {
                // This is actually a char/bool
                var container = encoder.singleValueContainer()
                try container.encode(number.boolValue)
            } else if number.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                // It's a whole number, encode as integer
                var container = encoder.singleValueContainer()
                try container.encode(number.intValue)
            } else {
                // It's a decimal number
                var container = encoder.singleValueContainer()
                try container.encode(number.doubleValue)
            }
        } else if let int = value as? Int {
            var container = encoder.singleValueContainer()
            try container.encode(int)
        } else if let double = value as? Double {
            var container = encoder.singleValueContainer()
            try container.encode(double)
        } else if let bool = value as? Bool {
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        } else if value is NSNull {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value of type \(type(of: value))"))
        }
    }
}

private struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var result = [String: Any]()
            for key in container.allKeys {
                result[key.stringValue] = try container.decode(AnyDecodable.self, forKey: key).value
            }
            value = result
        } else if var container = try? decoder.unkeyedContainer() {
            var result = [Any]()
            while !container.isAtEnd {
                result.append(try container.decode(AnyDecodable.self).value)
            }
            value = result
        } else if let container = try? decoder.singleValueContainer() {
            if container.decodeNil() {
                value = NSNull()
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode value"))
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
