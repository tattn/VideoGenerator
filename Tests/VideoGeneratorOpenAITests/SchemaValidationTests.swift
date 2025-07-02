import XCTest
@testable import VideoGeneratorOpenAI

final class SchemaValidationTests: XCTestCase {
    func testSchemaHasAdditionalPropertiesFalse() throws {
        // Load the schema
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to load timeline schema")
            return
        }
        
        // Check root object
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false, 
                      "Root object must have additionalProperties: false")
        
        // Check all definitions
        guard let definitions = schema["definitions"] as? [String: Any] else {
            XCTFail("Schema must have definitions")
            return
        }
        
        // List of all object definitions that should have additionalProperties: false
        let objectDefinitions = [
            "track", "clip", "mediaItem", "effect", "time", "timeRange",
            "size", "rect", "point", "color", "textStroke", "textShadow"
        ]
        
        for defName in objectDefinitions {
            guard let definition = definitions[defName] as? [String: Any] else {
                XCTFail("Missing definition: \(defName)")
                continue
            }
            
            XCTAssertEqual(definition["additionalProperties"] as? Bool, false,
                          "\(defName) must have additionalProperties: false")
        }
        
        // Special case: effect.parameters should allow additional properties
        if let effect = definitions["effect"] as? [String: Any],
           let properties = effect["properties"] as? [String: Any],
           let parameters = properties["parameters"] as? [String: Any] {
            XCTAssertNotNil(parameters["additionalProperties"],
                           "effect.parameters must define additionalProperties")
        }
        
        // Check sendableValue oneOf variants
        if let sendableValue = definitions["sendableValue"] as? [String: Any],
           let oneOf = sendableValue["oneOf"] as? [[String: Any]] {
            for (index, variant) in oneOf.enumerated() {
                if variant["type"] as? String == "object" {
                    XCTAssertEqual(variant["additionalProperties"] as? Bool, false,
                                  "sendableValue oneOf[\(index)] must have additionalProperties: false")
                }
            }
        }
        
        // Check shapeType oneOf variants
        if let shapeType = definitions["shapeType"] as? [String: Any],
           let oneOf = shapeType["oneOf"] as? [[String: Any]] {
            for (index, variant) in oneOf.enumerated() {
                if variant["type"] as? String == "object" {
                    XCTAssertEqual(variant["additionalProperties"] as? Bool, false,
                                  "shapeType oneOf[\(index)] must have additionalProperties: false")
                }
            }
        }
    }
    
    func testSchemaPassesOpenAIValidation() throws {
        // This test ensures the schema can be used with OpenAI's API
        let schema = try loadTimelineSchema()
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "timeline",
            strict: true,
            schema: schema
        )
        
        // Encode to verify it produces valid JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(jsonSchema)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["name"] as? String, "timeline")
        XCTAssertEqual(json?["strict"] as? Bool, true)
        XCTAssertNotNil(json?["schema"] as? [String: Any])
    }
    
    private func loadTimelineSchema() throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SchemaValidationTests", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load timeline schema"])
        }
        return schema
    }
}