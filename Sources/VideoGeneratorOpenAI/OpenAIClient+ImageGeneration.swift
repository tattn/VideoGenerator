import Foundation
import VideoGenerator

// MARK: - Public Image Generation Extensions

public extension OpenAIClient {
    /// Converts base64-encoded image data to Data
    /// - Parameter base64String: The base64-encoded string from DALL-E
    /// - Returns: Decoded image data
    /// - Throws: DecodingError if the base64 string is invalid
    static func imageDataFromBase64(_ base64String: String) throws -> Data {
        guard let data = Data(base64Encoded: base64String) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Invalid base64 image data"
                )
            )
        }
        return data
    }
    
    /// Generates an image using DALL-E based on the provided prompt.
    /// - Parameter prompt: The text description of the image to generate
    /// - Returns: Base64-encoded image data
    /// - Throws: OpenAIError if the generation fails
    func generateImage(prompt: String) async throws -> String {
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
    
    /// Generates an image using DALL-E with custom options.
    /// - Parameters:
    ///   - prompt: The text description of the image to generate
    ///   - model: The DALL-E model to use (default: dall-e-3)
    ///   - size: The size of the generated image (default: 1024x1024)
    ///   - quality: The quality of the generated image (default: standard)
    /// - Returns: Base64-encoded image data
    /// - Throws: OpenAIError if the generation fails
    func generateImage(
        prompt: String,
        model: String? = nil,
        size: String? = nil,
        quality: String? = nil
    ) async throws -> String {
        let request = ImageGenerationRequest(
            model: model ?? configuration.imageGenerationOptions.model,
            prompt: prompt,
            size: size ?? configuration.imageGenerationOptions.size,
            quality: quality ?? configuration.imageGenerationOptions.quality,
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
    
    /// Generates multiple images using DALL-E based on the provided prompt.
    /// - Parameters:
    ///   - prompt: The text description of the images to generate
    ///   - count: The number of images to generate (1-10 for DALL-E 2, only 1 for DALL-E 3)
    ///   - model: The DALL-E model to use (default: dall-e-3)
    ///   - size: The size of the generated images (default: 1024x1024)
    ///   - quality: The quality of the generated images (default: standard)
    /// - Returns: Array of base64-encoded image data
    /// - Throws: OpenAIError if the generation fails
    func generateImages(
        prompt: String,
        count: Int = 1,
        model: String? = nil,
        size: String? = nil,
        quality: String? = nil
    ) async throws -> [String] {
        let request = ImageGenerationRequest(
            model: model ?? configuration.imageGenerationOptions.model,
            prompt: prompt,
            size: size ?? configuration.imageGenerationOptions.size,
            quality: quality ?? configuration.imageGenerationOptions.quality,
            n: count,
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
            throw OpenAIError.imageGenerationError("Failed to generate images: \(errorString)")
        }
        
        let decoder = JSONDecoder()
        let imageResponse = try decoder.decode(ImageGenerationResponse.self, from: data)
        
        return imageResponse.data.map { $0.b64Json }
    }
    
    /// Generates an image and returns a GeneratedImage struct
    /// - Parameter prompt: The text description of the image to generate
    /// - Returns: GeneratedImage containing the result
    /// - Throws: OpenAIError if the generation fails
    func generateImageWithMetadata(prompt: String) async throws -> GeneratedImage {
        let base64Data = try await generateImage(prompt: prompt)
        return GeneratedImage(base64Data: base64Data, prompt: prompt)
    }
    
    /// Generates multiple images and returns GeneratedImage structs
    /// - Parameters:
    ///   - prompt: The text description of the images to generate
    ///   - count: The number of images to generate
    /// - Returns: Array of GeneratedImage containing the results
    /// - Throws: OpenAIError if the generation fails
    func generateImagesWithMetadata(prompt: String, count: Int = 1) async throws -> [GeneratedImage] {
        let base64DataArray = try await generateImages(prompt: prompt, count: count)
        return base64DataArray.map { GeneratedImage(base64Data: $0, prompt: prompt) }
    }
}