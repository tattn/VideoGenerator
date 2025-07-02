import Foundation
import VideoGenerator

public actor OpenAIClient: Sendable {
    public struct Configuration: Sendable {
        public let apiKey: String
        public let baseURL: URL
        public let model: String
        public let imageGenerationOptions: ImageGenerationOptions
        
        public init(
            apiKey: String,
            baseURL: URL = URL(string: "https://api.openai.com/v1")!,
            model: String = "gpt-4.1",
            imageGenerationOptions: ImageGenerationOptions = ImageGenerationOptions()
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
            self.imageGenerationOptions = imageGenerationOptions
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
        self.session = URLSession.shared
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
