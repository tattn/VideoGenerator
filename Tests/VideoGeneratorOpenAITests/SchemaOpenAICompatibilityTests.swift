import XCTest
@testable import VideoGeneratorOpenAI

final class SchemaOpenAICompatibilityTests: XCTestCase {
    func testSchemaHasNoForbiddenConstructs() throws {
        // Load the schema
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schemaString = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to load timeline schema")
            return
        }
        
        // Check for forbidden constructs
        XCTAssertFalse(schemaString.contains("\"oneOf\""), 
                      "Schema must not contain oneOf (not supported by OpenAI)")
        XCTAssertFalse(schemaString.contains("\"allOf\""), 
                      "Schema must not contain allOf (not supported by OpenAI)")
        XCTAssertFalse(schemaString.contains("\"if\""), 
                      "Schema must not contain if/then/else (not supported by OpenAI)")
        XCTAssertFalse(schemaString.contains("\"then\""), 
                      "Schema must not contain if/then/else (not supported by OpenAI)")
        XCTAssertFalse(schemaString.contains("\"anyOf\""), 
                      "Schema must not contain anyOf (not supported by OpenAI)")
        XCTAssertFalse(schemaString.contains("\"not\""), 
                      "Schema must not contain not (not supported by OpenAI)")
        
        // Additional checks for OpenAI requirements
        XCTAssertTrue(schemaString.contains("\"additionalProperties\": false"), 
                     "Schema must have additionalProperties: false")
    }
    
    func testAllObjectsHaveAdditionalPropertiesFalse() throws {
        // This test is inherited from SchemaValidationTests
        let schemaTests = SchemaValidationTests()
        try schemaTests.testSchemaHasAdditionalPropertiesFalse()
    }
    
    func testSchemaValidJSON() throws {
        // Load and validate the schema is valid JSON
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Failed to load timeline schema")
            return
        }
        
        // Should parse without throwing
        _ = try JSONSerialization.jsonObject(with: data, options: [])
    }
    
    func testMixedTypeHandling() throws {
        // Test that mixed types (e.g., ["string", "null"]) are handled correctly
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let definitions = schema["definitions"] as? [String: Any] else {
            XCTFail("Failed to load timeline schema")
            return
        }
        
        // Check that nullable fields use type array notation
        if let mediaItem = definitions["mediaItem"] as? [String: Any],
           let properties = mediaItem["properties"] as? [String: Any] {
            
            // Check nullable fields
            let nullableFields = ["url", "imageData", "text", "font", "color", "strokes", "shadow", 
                                 "behavior", "alignment", "shapeType", "fillColor", "strokeColor", "strokeWidth"]
            
            for field in nullableFields {
                if let fieldDef = properties[field] as? [String: Any],
                   let type = fieldDef["type"] {
                    if let typeArray = type as? [Any] {
                        XCTAssertTrue(typeArray.contains { $0 as? String == "null" },
                                    "\(field) should be nullable")
                    }
                }
            }
        }
    }
}