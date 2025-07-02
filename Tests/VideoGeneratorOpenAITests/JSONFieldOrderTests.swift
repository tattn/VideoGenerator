import XCTest
@testable import VideoGeneratorOpenAI

final class JSONFieldOrderTests: XCTestCase {
    func testResponseFormatFieldOrder() throws {
        // Given
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"]
            ]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "test",
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
                OpenAIClient.Message(role: "system", content: "Test"),
                OpenAIClient.Message(role: "user", content: "Test")
            ],
            responseFormat: responseFormat
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Then
        // Verify the exact pattern - this is the most reliable way
        XCTAssertTrue(jsonString.contains("\"response_format\":{\"type\":\"json_schema\",\"json_schema\""),
                     "response_format should have the exact pattern with type before json_schema")
        
        // Also verify by checking the actual positions in the full string
        if let typeRange = jsonString.range(of: "\"response_format\":{\"type\""),
           let jsonSchemaRange = jsonString.range(of: ",\"json_schema\"") {
            XCTAssertTrue(typeRange.lowerBound < jsonSchemaRange.lowerBound,
                         "type field should appear before json_schema field")
        }
    }
    
    func testResponseFormatWithoutJSONSchema() throws {
        // Test when jsonSchema is nil
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "text",
            jsonSchema: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(jsonObject?["type"] as? String, "text")
        XCTAssertNil(jsonObject?["json_schema"])
        
        // Verify it only contains the type field
        XCTAssertEqual(jsonObject?.count, 1)
    }
}