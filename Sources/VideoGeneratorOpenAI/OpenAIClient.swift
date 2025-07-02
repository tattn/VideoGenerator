import Foundation
import VideoGenerator

public actor OpenAIClient: Sendable {
    public struct Configuration: Sendable {
        public let apiKey: String
        public let baseURL: URL
        public let model: String
        
        public init(
            apiKey: String,
            baseURL: URL = URL(string: "https://api.openai.com/v1")!,
            model: String = "gpt-4.1"
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
        }
    }
    
    public struct ChatCompletionRequest: Codable, Sendable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat?
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case responseFormat = "response_format"
        }
    }
    
    public struct Message: Codable, Sendable {
        let role: String
        let content: String
    }
    
    public struct ResponseFormat: Codable, Sendable {
        let type: String
        let jsonSchema: JSONSchema?
        
        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }
    
    public struct JSONSchema: Codable, Sendable {
        let name: String
        let strict: Bool
        let schemaData: Data
        
        enum CodingKeys: String, CodingKey {
            case name
            case strict
            case schema
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(strict, forKey: .strict)
            try container.encode(schemaData, forKey: .schema)
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            strict = try container.decode(Bool.self, forKey: .strict)
            schemaData = try container.decode(Data.self, forKey: .schema)
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
    
    public enum OpenAIError: Error, Sendable {
        case invalidResponse
        case networkError(String)
        case decodingError(String)
        case invalidTimelineSchema
    }
    
    private let configuration: Configuration
    private let session: URLSession
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.session = URLSession.shared
    }
    
    public func generateTimeline(prompt: String) async throws -> Timeline {
        let timelineSchema = try loadTimelineSchema()
        
        let request = ChatCompletionRequest(
            model: configuration.model,
            messages: [
                Message(
                    role: "system",
                    content: "You are a video timeline generator. Generate a timeline JSON that follows the provided schema based on the user's prompt."
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
        return try await serializer.load(from: data)
    }
    
    private func performRequest(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
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
}
