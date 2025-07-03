import Foundation

// MARK: - Configuration

public struct OpenAIConfiguration: Sendable {
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

// MARK: - Chat Completion Models

public struct ChatCompletionRequest: Encodable, Sendable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat?

    public init(
        model: String,
        messages: [Message],
        responseFormat: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.responseFormat = responseFormat
    }

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
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ResponseFormat: Encodable, Sendable {
    let type: String
    let jsonSchema: JSONSchema?

    public init(type: String, jsonSchema: JSONSchema? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
    }

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
    public let choices: [Choice]

    public struct Choice: Codable, Sendable {
        public let message: Message
    }
}

// MARK: - Image Generation Models

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

// MARK: - Image Generation Results

/// Result of an image generation request
public struct GeneratedImage: Sendable {
    /// Base64-encoded image data
    public let base64Data: String
    
    /// The prompt used to generate this image
    public let prompt: String
    
    /// Converts the base64 data to raw Data
    public func imageData() throws -> Data {
        guard let data = Data(base64Encoded: base64Data) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid base64 image data"
                )
            )
        }
        return data
    }
}

// MARK: - Errors

public enum OpenAIError: Error, Sendable {
    case invalidResponse
    case networkError(String)
    case decodingError(String)
    case invalidTimelineSchema
    case imageGenerationError(String)
}