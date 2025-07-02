import XCTest
@testable import VideoGeneratorOpenAI

final class JSONSchemaEncodingTests: XCTestCase {
    func testJSONSchemaEncodesAsJSONNotBase64() throws {
        // Given
        let testSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "age": ["type": "integer"]
            ],
            "required": ["name", "age"]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "test",
            strict: true,
            schema: testSchema
        )
        
        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(jsonSchema)
        
        // Then
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        
        // Verify the schema is embedded as a JSON object, not a base64 string
        let schemaObject = jsonObject?["schema"] as? [String: Any]
        XCTAssertNotNil(schemaObject, "Schema should be a dictionary, not a base64 string")
        XCTAssertEqual(schemaObject?["type"] as? String, "object")
        
        // Verify properties
        let properties = schemaObject?["properties"] as? [String: Any]
        XCTAssertNotNil(properties)
        
        let nameProperty = properties?["name"] as? [String: Any]
        XCTAssertEqual(nameProperty?["type"] as? String, "string")
        
        let ageProperty = properties?["age"] as? [String: Any]
        XCTAssertEqual(ageProperty?["type"] as? String, "integer")
        
        // Verify required array
        let required = schemaObject?["required"] as? [String]
        XCTAssertEqual(required, ["name", "age"])
    }
    
    func testResponseFormatWithJSONSchema() throws {
        // Given
        let schema: [String: Any] = ["type": "object"]
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "timeline",
            strict: true,
            schema: schema
        )
        
        let responseFormat = OpenAIClient.ResponseFormat(
            type: "json_schema",
            jsonSchema: jsonSchema
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(responseFormat)
        
        // Then
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["type"] as? String, "json_schema")
        
        let jsonSchemaObject = jsonObject?["json_schema"] as? [String: Any]
        XCTAssertNotNil(jsonSchemaObject)
        XCTAssertEqual(jsonSchemaObject?["name"] as? String, "timeline")
        XCTAssertEqual(jsonSchemaObject?["strict"] as? Bool, true)
        
        let schemaDict = jsonSchemaObject?["schema"] as? [String: Any]
        XCTAssertNotNil(schemaDict, "Schema should be a dictionary")
        XCTAssertEqual(schemaDict?["type"] as? String, "object")
    }
}