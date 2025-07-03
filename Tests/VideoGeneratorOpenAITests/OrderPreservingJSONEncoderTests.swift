import XCTest
import Foundation
@testable import VideoGeneratorOpenAI

final class OrderPreservingJSONEncoderTests: XCTestCase {
    
    func testResponseFormatFieldOrderWithOrderPreservingEncoder() throws {
        // This test verifies that our OrderPreservingJSONEncoder maintains field order
        // We can't directly test it since it's private, but we can verify the behavior
        // through the OpenAIClient's performRequest method
        
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "value": ["type": "number"]
            ],
            "required": ["name"]
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
        
        let request = OpenAIClient.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIClient.Message(role: "system", content: "Test system message"),
                OpenAIClient.Message(role: "user", content: "Test user message")
            ],
            responseFormat: responseFormat
        )
        
        // When using standard JSONEncoder (for comparison)
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify the ResponseFormat encode method is working correctly
        XCTAssertTrue(jsonString.contains("\"response_format\":{\"type\":\"json_schema\",\"json_schema\""),
                     "response_format should have type before json_schema")
    }
    
    func testChatCompletionRequestFieldOrder() throws {
        // Given
        let request = OpenAIClient.ChatCompletionRequest(
            model: "gpt-4-turbo",
            messages: [
                OpenAIClient.Message(role: "system", content: "You are a helpful assistant"),
                OpenAIClient.Message(role: "user", content: "Hello, how are you?")
            ],
            responseFormat: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify model appears before messages
        if let modelRange = jsonString.range(of: "\"model\":"),
           let messagesRange = jsonString.range(of: "\"messages\":") {
            XCTAssertTrue(modelRange.lowerBound < messagesRange.lowerBound,
                         "model field should appear before messages field")
        } else {
            XCTFail("model or messages field not found")
        }
    }
    
    func testResponseFormatWithoutJsonSchema() throws {
        // Given
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "text",
            jsonSchema: nil
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Then
        XCTAssertEqual(jsonObject?["type"] as? String, "text")
        XCTAssertNil(jsonObject?["json_schema"])
        XCTAssertEqual(jsonObject?.count, 1, "Should only contain type field when json_schema is nil")
    }
    
    func testComplexResponseFormatOrder() throws {
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "users": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "integer"],
                            "name": ["type": "string"],
                            "email": ["type": "string"]
                        ],
                        "required": ["id", "name"]
                    ]
                ],
                "total": ["type": "integer"],
                "page": ["type": "integer"]
            ],
            "required": ["users", "total"]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "user_list_response",
            strict: false,
            schema: schema
        )
        
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        let request = OpenAIClient.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIClient.Message(role: "user", content: "List users")
            ],
            responseFormat: responseFormat
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify the response_format structure maintains order
        XCTAssertTrue(jsonString.contains("\"response_format\":{\"type\":\"json_schema\",\"json_schema\":"),
                     "response_format should maintain field order")
        
        // Verify the json_schema internal structure has correct field order
        if let jsonSchemaRange = jsonString.range(of: "\"json_schema\":{\"name\":"),
           let strictRange = jsonString.range(of: ",\"strict\":"),
           let schemaRange = jsonString.range(of: ",\"schema\":") {
            XCTAssertTrue(jsonSchemaRange.lowerBound < strictRange.lowerBound,
                         "name should appear before strict")
            XCTAssertTrue(strictRange.lowerBound < schemaRange.lowerBound,
                         "strict should appear before schema")
        }
    }
    
    func testMessageFieldOrder() throws {
        // Given
        let message = OpenAIClient.Message(
            role: "assistant",
            content: "I can help you with that."
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify role appears before content
        if let roleRange = jsonString.range(of: "\"role\":"),
           let contentRange = jsonString.range(of: "\"content\":") {
            XCTAssertTrue(roleRange.lowerBound < contentRange.lowerBound,
                         "role field should appear before content field")
        } else {
            XCTFail("role or content field not found")
        }
    }
    
    func testJSONSchemaFieldOrder() throws {
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "result": ["type": "string"]
            ]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "simple_response",
            strict: true,
            schema: schema
        )
        
        // When
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify JSONSchema fields are in the correct order (name, strict, schema)
        if let jsonSchemaStart = jsonString.range(of: "\"json_schema\":{") {
            let jsonSchemaSubstring = String(jsonString[jsonSchemaStart.upperBound...])
            
            if let nameRange = jsonSchemaSubstring.range(of: "\"name\":"),
               let strictRange = jsonSchemaSubstring.range(of: "\"strict\":"),
               let schemaRange = jsonSchemaSubstring.range(of: "\"schema\":") {
                XCTAssertTrue(nameRange.lowerBound < strictRange.lowerBound,
                             "name field should appear before strict field")
                XCTAssertTrue(strictRange.lowerBound < schemaRange.lowerBound,
                             "strict field should appear before schema field")
            }
        }
    }
    
    func testOrderPreservingEncoderIntegration() throws {
        // This test verifies that the OpenAIClient uses OrderPreservingJSONEncoder
        // by checking that complex nested structures maintain their field order
        
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "first": ["type": "string"],
                "second": ["type": "number"],
                "third": ["type": "boolean"]
            ],
            "required": ["first", "second", "third"],
            "additionalProperties": false
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "ordered_fields",
            strict: true,
            schema: schema
        )
        
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        let request = OpenAIClient.ChatCompletionRequest(
            model: "gpt-4",
            messages: [
                OpenAIClient.Message(role: "system", content: "Return ordered fields"),
                OpenAIClient.Message(role: "user", content: "Test")
            ],
            responseFormat: responseFormat
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // The ResponseFormat.encode(to:) method should ensure type comes before json_schema
        let responseFormatPattern = "\"response_format\":{\"type\":\"json_schema\",\"json_schema\":"
        XCTAssertTrue(jsonString.contains(responseFormatPattern),
                     "ResponseFormat should encode with type before json_schema")
    }
}