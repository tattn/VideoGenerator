import Foundation
import VideoGenerator

public actor OpenAIClient: Sendable {
    public typealias Configuration = OpenAIConfiguration
    
    let configuration: Configuration
    let session: URLSession
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeoutInterval
        sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeoutInterval
        
        self.session = URLSession(configuration: sessionConfiguration)
    }
    
    public func generateTimeline(prompt: String) async throws -> Timeline {
        let timelineSchema = try loadTimelineSchema()
        
        var systemPrompt = """
            You are a video timeline generator. Generate a timeline JSON that follows the provided schema based on the user's prompt.
            
            IMPORTANT RULES:
            1. Each track MUST contain a 'clips' array with at least one clip
            2. Never generate empty clips arrays - always include relevant content
            3. For video/overlay tracks: add video or image clips
            4. For audio tracks: add audio clips
            5. For effect tracks: add clips with effects applied
            6. Each clip must have all required properties: id, mediaItem, timeRange, frame, contentMode, effects, opacity
            """
        
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
    
    public func performRequest(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
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
    
    nonisolated private func loadTimelineSchema() throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenAIError.invalidTimelineSchema
        }
        
        // Clean and transform the schema for OpenAI API compatibility
        return try transformSchemaForOpenAI(schema)
    }
    
    nonisolated private func transformSchemaForOpenAI(_ schema: [String: Any]) throws -> [String: Any] {
        // OpenAI doesn't support the definitions section, so we need to inline all $ref references
        let definitions = schema["definitions"] as? [String: Any] ?? [:]
        
        // First resolve all references to inline the definitions
        let resolved = resolveReferences(in: schema, definitions: definitions)
        
        // Then clean up unsupported fields
        return cleanSchemaForOpenAI(resolved)
    }
    
    nonisolated private func resolveReferences(in schema: [String: Any], definitions: [String: Any]) -> [String: Any] {
        var resolved = [String: Any]()
        
        for (key, value) in schema {
            if let dictValue = value as? [String: Any] {
                // Check if this is a $ref
                if let ref = dictValue["$ref"] as? String {
                    // Extract the definition name from the $ref
                    let defName = ref.replacingOccurrences(of: "#/definitions/", with: "")
                    if let definition = definitions[defName] as? [String: Any] {
                        // Recursively resolve the definition
                        resolved[key] = resolveReferences(in: definition, definitions: definitions)
                    } else {
                        // Keep the original if we can't resolve
                        resolved[key] = dictValue
                    }
                } else {
                    // Recursively process nested objects
                    resolved[key] = resolveReferences(in: dictValue, definitions: definitions)
                }
            } else if let arrayValue = value as? [[String: Any]] {
                // Process arrays of objects
                resolved[key] = arrayValue.map { resolveReferences(in: $0, definitions: definitions) }
            } else if let arrayValue = value as? [Any] {
                // Process mixed arrays
                resolved[key] = arrayValue.map { item -> Any in
                    if let dictItem = item as? [String: Any] {
                        return resolveReferences(in: dictItem, definitions: definitions)
                    }
                    return item
                }
            } else {
                // Keep primitive values as-is
                resolved[key] = value
            }
        }
        
        return resolved
    }
    
    nonisolated private func cleanSchemaForOpenAI(_ schema: [String: Any], currentDepth: Int = 0) -> [String: Any] {
        var cleaned = [String: Any]()
        
        // OpenAI has a maximum nesting depth of 5
        let maxDepth = 5
        
        // First pass: copy all values except the ones we need to skip or transform
        for (key, value) in schema {
            // Skip OpenAI-unsupported fields but keep $ref
            if key == "$schema" || key == "$id" || key == "format" {
                continue
            }
            
            // Special handling for definitions - OpenAI doesn't support this section
            // but we should keep the structure of the main schema intact
            if key == "definitions" {
                continue
            }
            
            // Don't process required array in the first pass
            if key == "required" {
                continue
            }
            
            // Special handling for effect parameters to avoid deep nesting
            if key == "parameters" && currentDepth >= 3 {
                // This is likely the effect parameters object
                if let parametersDict = value as? [String: Any],
                   let properties = parametersDict["properties"] as? [String: Any] {
                    var simplifiedProperties = [String: Any]()
                    
                    for (propKey, propValue) in properties {
                        if propValue is [String: Any] {
                            // Simplify nested object types to avoid exceeding depth limit
                            if propKey == "color" || propKey == "size" || propKey == "point" {
                                // Skip these nested objects as they cause depth issues
                                // The actual values can still be passed as simple types
                                continue
                            } else {
                                simplifiedProperties[propKey] = propValue
                            }
                        } else {
                            simplifiedProperties[propKey] = propValue
                        }
                    }
                    
                    var simplifiedParameters = parametersDict
                    simplifiedParameters["properties"] = simplifiedProperties
                    simplifiedParameters["additionalProperties"] = false
                    // Remove the required array for parameters as all are nullable
                    simplifiedParameters.removeValue(forKey: "required")
                    cleaned[key] = simplifiedParameters
                    continue
                }
            }
            
            if let dictValue = value as? [String: Any] {
                // Check if this is a deeply nested object that would exceed the depth limit
                if currentDepth >= maxDepth - 1 && hasNestedObjects(dictValue) {
                    // Flatten or skip deeply nested structures
                    continue
                } else {
                    cleaned[key] = cleanSchemaForOpenAI(dictValue, currentDepth: currentDepth + 1)
                }
            } else if let arrayValue = value as? [[String: Any]] {
                cleaned[key] = arrayValue.map { cleanSchemaForOpenAI($0, currentDepth: currentDepth + 1) }
            } else if let arrayValue = value as? [Any] {
                cleaned[key] = arrayValue.map { item -> Any in
                    if let dictItem = item as? [String: Any] {
                        return cleanSchemaForOpenAI(dictItem, currentDepth: currentDepth + 1)
                    }
                    return item
                }
            } else {
                cleaned[key] = value
            }
        }
        
        // Second pass: handle required array after all properties have been processed
        // OpenAI strict mode requires ALL properties to be in the required array
        if let properties = cleaned["properties"] as? [String: Any] {
            // For OpenAI strict mode, all properties must be in the required array
            let allPropertyKeys = Array(properties.keys).sorted()
            cleaned["required"] = allPropertyKeys
        } else if let existingRequired = schema["required"] as? [String] {
            // If there are no properties but there is a required array, keep it
            cleaned["required"] = existingRequired
        }
        
        return cleaned
    }
    
    nonisolated private func hasNestedObjects(_ dict: [String: Any]) -> Bool {
        for (_, value) in dict {
            if let dictValue = value as? [String: Any] {
                // Check if this dictionary has properties that contain objects
                if let properties = dictValue["properties"] as? [String: Any] {
                    for (_, propValue) in properties {
                        if let propDict = propValue as? [String: Any],
                           propDict["type"] as? String == "object" ||
                           (propDict["type"] as? [String])?.contains("object") == true {
                            return true
                        }
                    }
                }
            }
        }
        return false
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
}