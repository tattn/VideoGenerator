import XCTest
@testable import VideoGeneratorOpenAI

final class TimelineSchemaEncodingTests: XCTestCase {
    func testTimelineSchemaEncodesCorrectly() throws {
        // Load the actual timeline schema
        guard let url = Bundle.module.url(forResource: "timeline.schema", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let schema = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to load timeline schema")
            return
        }
        
        let jsonSchema = try OpenAIClient.JSONSchema(
            name: "timeline",
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
        
        // Encode the request
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let requestData = try encoder.encode(request)
        let requestJSON = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        
        // Verify the structure
        XCTAssertNotNil(requestJSON)
        let responseFormatJSON = requestJSON?["response_format"] as? [String: Any]
        XCTAssertNotNil(responseFormatJSON)
        
        let jsonSchemaJSON = responseFormatJSON?["json_schema"] as? [String: Any]
        XCTAssertNotNil(jsonSchemaJSON)
        
        let schemaJSON = jsonSchemaJSON?["schema"] as? [String: Any]
        XCTAssertNotNil(schemaJSON)
        
        // Check specific properties to ensure numeric values are preserved
        let definitions = schemaJSON?["definitions"] as? [String: Any]
        XCTAssertNotNil(definitions)
        
        // Check color definition
        let colorDef = definitions?["color"] as? [String: Any]
        let colorProps = colorDef?["properties"] as? [String: Any]
        _ = colorProps?["red"] as? [String: Any]
        
        // Verify minimum and maximum are encoded as numbers in the JSON
        // We need to check the actual JSON string to ensure they're not encoded as booleans
        if let jsonString = String(data: requestData, encoding: .utf8) {
            // Check that the red property has numeric min/max values
            XCTAssertTrue(jsonString.contains("\"red\":{\"description\":\"Red component (0-1)\",\"maximum\":1,\"minimum\":0,\"type\":\"number\"}"), 
                         "Red property should have numeric minimum and maximum values")
            
            // Ensure there are no boolean values where we expect numbers
            XCTAssertFalse(jsonString.contains("\"minimum\":true") || jsonString.contains("\"minimum\":false"),
                          "minimum values should not be encoded as booleans")
            XCTAssertFalse(jsonString.contains("\"maximum\":true") || jsonString.contains("\"maximum\":false"),
                          "maximum values should not be encoded as booleans")
        }
        
        // Check size definition
        let sizeDef = definitions?["size"] as? [String: Any]
        let sizeProps = sizeDef?["properties"] as? [String: Any]
        let widthProp = sizeProps?["width"] as? [String: Any]
        
        if let minimum = widthProp?["minimum"] {
            XCTAssertTrue(minimum is Int || minimum is Double, "minimum should be a number, but was \(type(of: minimum))")
            XCTAssertEqual(minimum as? Int, 1)
        }
    }
}