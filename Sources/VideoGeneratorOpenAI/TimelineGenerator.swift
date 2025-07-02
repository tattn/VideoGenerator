import Foundation
import VideoGenerator

public struct TimelineGenerator: Sendable {
    private let client: OpenAIClient
    
    public init(apiKey: String, baseURL: URL? = nil, model: String? = nil) {
        let configuration = OpenAIClient.Configuration(
            apiKey: apiKey,
            baseURL: baseURL ?? URL(string: "https://api.openai.com/v1")!,
            model: model ?? "gpt-4.1"
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
