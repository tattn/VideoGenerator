import Foundation
import VideoGenerator

public struct ImageGenerationOptions: Sendable {
    public let maxImages: Int
    public let model: String
    public let size: String
    public let quality: String
    
    public init(
        maxImages: Int = 0,
        model: String = "dall-e-3",
        size: String = "1024x1024",
        quality: String = "standard"
    ) {
        self.maxImages = maxImages
        self.model = model
        self.size = size
        self.quality = quality
    }
}

public struct TimelineGenerator: Sendable {
    private let client: OpenAIClient
    
    public init(apiKey: String, baseURL: URL? = nil, model: String? = nil, imageGenerationOptions: ImageGenerationOptions = ImageGenerationOptions()) {
        let configuration = OpenAIClient.Configuration(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.openai.com/v1")!,
            model: model ?? "gpt-4.1",
            imageGenerationOptions: imageGenerationOptions
        )
        self.client = OpenAIClient(configuration: configuration)
    }
    
    public init(configuration: OpenAIClient.Configuration) {
        self.client = OpenAIClient(configuration: configuration)
    }
    
    public func generateTimeline(from prompt: String) async throws -> Timeline {
        return try await client.generateTimeline(prompt: prompt)
    }
}
