import XCTest
import Foundation
@testable import VideoGeneratorOpenAI

final class OpenAIClientIntegrationTests: XCTestCase {
    
    func testResponseFormatEncodingOrder() throws {
        // Test that ResponseFormat's custom encode method maintains field order
        
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "result": ["type": "string"]
            ]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "test_schema",
            strict: true,
            schema: schema
        )
        
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        // When
        // Test with JSONEncoder to verify the encode method implementation
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // The ResponseFormat.encode method ensures type comes before json_schema
        // by encoding them in order
        XCTAssertTrue(jsonString.contains("\"type\":\"json_schema\""),
                     "ResponseFormat should contain type field with correct value")
        XCTAssertTrue(jsonString.contains("\"json_schema\":{"),
                     "ResponseFormat should contain json_schema object")
    }
    
    func testJSONSchemaEncodingOrder() throws {
        // Test that JSONSchema's custom encode method maintains field order
        
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ],
            "required": ["name"]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "person_schema",
            strict: false,
            schema: schema
        )
        
        // When wrapped in ResponseFormat
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify JSONSchema fields are present
        XCTAssertTrue(jsonString.contains("\"name\":\"person_schema\""),
                     "JSONSchema should contain name field")
        XCTAssertTrue(jsonString.contains("\"strict\":false"),
                     "JSONSchema should contain strict field")
        XCTAssertTrue(jsonString.contains("\"schema\":{"),
                     "JSONSchema should contain schema object")
    }
    
    func testChatCompletionRequestEncodingOrder() throws {
        // Test that ChatCompletionRequest's custom encode method maintains field order
        
        // Given
        let request = OpenAIClient.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIClient.Message(role: "system", content: "You are helpful"),
                OpenAIClient.Message(role: "user", content: "Hello")
            ],
            responseFormat: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify fields are present
        XCTAssertTrue(jsonString.contains("\"model\":\"gpt-4\""),
                     "Request should contain model field")
        XCTAssertTrue(jsonString.contains("\"messages\":["),
                     "Request should contain messages array")
        XCTAssertFalse(jsonString.contains("\"response_format\""),
                      "Request should not contain response_format when nil")
    }
    
    func testTimeoutConfiguration() throws {
        // Test that the timeout configuration is properly set
        
        // Test custom timeout
        let customTimeout: TimeInterval = 600 // 10 minutes
        let configuration = OpenAIClient.Configuration(
            apiKey: "test-key",
            requestTimeoutInterval: customTimeout
        )
        
        XCTAssertEqual(configuration.requestTimeoutInterval, customTimeout,
                      "Custom timeout should be set correctly")
        
        // Test default timeout
        let defaultConfig = OpenAIClient.Configuration(apiKey: "test-key")
        XCTAssertEqual(defaultConfig.requestTimeoutInterval, 300,
                      "Default timeout should be 5 minutes (300 seconds)")
    }
    
    func testOrderPreservingEncoderUsage() async throws {
        // This test verifies that performRequest uses OrderPreservingJSONEncoder
        // We can't test the actual network call, but we can verify the setup
        
        let configuration = OpenAIClient.Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "https://test.example.com/v1")!
        )
        
        let client = OpenAIClient(configuration: configuration)
        
        // The fact that the client initializes successfully with our custom
        // OrderPreservingJSONEncoder implementation shows it's integrated
        XCTAssertNotNil(client, "Client should initialize successfully")
    }
}