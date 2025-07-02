import XCTest
@testable import VideoGeneratorOpenAI

final class JSONSchemaEncodingTests: XCTestCase {
    func testJSONSchemaEncodesAsJSONNotBase64() throws {
        // Given
        let testSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "age": ["type": "integer", "minimum": 0, "maximum": 120]
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
        XCTAssertEqual(ageProperty?["minimum"] as? Int, 0)
        XCTAssertEqual(ageProperty?["maximum"] as? Int, 120)
        
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
        
        // Verify that "type" appears before "json_schema" in the JSON string
        if let jsonString = String(data: data, encoding: .utf8) {
            // The ResponseFormat should contain both fields
            XCTAssertTrue(jsonString.contains("\"type\":\"json_schema\""), 
                         "Should contain type field")
            XCTAssertTrue(jsonString.contains("\"json_schema\":{"), 
                         "Should contain json_schema field")
        }
    }
    
    func testNumericValuesEncodedCorrectly() throws {
        // Given a schema with numeric minimum/maximum values
        let testSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "color": [
                    "type": "object",
                    "properties": [
                        "red": ["type": "number", "minimum": 0, "maximum": 1],
                        "green": ["type": "number", "minimum": 0, "maximum": 1],
                        "blue": ["type": "number", "minimum": 0.0, "maximum": 1.0],
                        "alpha": ["type": "number", "minimum": NSNumber(value: 0), "maximum": NSNumber(value: 1)]
                    ]
                ]
            ]
        ]
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "color_test",
            strict: true,
            schema: testSchema
        )
        
        // When
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(jsonSchema)
        
        // Then
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let schemaObject = jsonObject?["schema"] as? [String: Any]
        let properties = schemaObject?["properties"] as? [String: Any]
        let colorProperty = properties?["color"] as? [String: Any]
        let colorProperties = colorProperty?["properties"] as? [String: Any]
        
        // Check red property (integers)
        let redProperty = colorProperties?["red"] as? [String: Any]
        XCTAssertEqual(redProperty?["minimum"] as? Int, 0)
        XCTAssertEqual(redProperty?["maximum"] as? Int, 1)
        XCTAssertNotNil(redProperty?["minimum"] as? Int, "minimum should be an integer, not a boolean")
        
        // Check green property (integers)
        let greenProperty = colorProperties?["green"] as? [String: Any]
        XCTAssertEqual(greenProperty?["minimum"] as? Int, 0)
        XCTAssertEqual(greenProperty?["maximum"] as? Int, 1)
        
        // Check blue property (doubles)
        let blueProperty = colorProperties?["blue"] as? [String: Any]
        XCTAssertEqual(blueProperty?["minimum"] as? Double, 0.0)
        XCTAssertEqual(blueProperty?["maximum"] as? Double, 1.0)
        
        // Check alpha property (NSNumber)
        let alphaProperty = colorProperties?["alpha"] as? [String: Any]
        if let minValue = alphaProperty?["minimum"] as? NSNumber {
            XCTAssertEqual(minValue.intValue, 0)
        } else if let minValue = alphaProperty?["minimum"] as? Int {
            XCTAssertEqual(minValue, 0)
        } else {
            XCTFail("minimum should be a number, not a boolean")
        }
    }
}