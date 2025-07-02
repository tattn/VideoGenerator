import XCTest
import VideoGenerator
@testable import VideoGeneratorOpenAI

final class ImageGenerationTests: XCTestCase {
    
    func testImageGenerationOptionsInitialization() {
        let options = ImageGenerationOptions(
            maxImages: 3,
            model: "dall-e-2",
            size: "512x512",
            quality: "hd"
        )
        
        XCTAssertEqual(options.maxImages, 3)
        XCTAssertEqual(options.model, "dall-e-2")
        XCTAssertEqual(options.size, "512x512")
        XCTAssertEqual(options.quality, "hd")
    }
    
    func testImageGenerationOptionsDefaults() {
        let options = ImageGenerationOptions()
        
        XCTAssertEqual(options.maxImages, 0)
        XCTAssertEqual(options.model, "dall-e-3")
        XCTAssertEqual(options.size, "1024x1024")
        XCTAssertEqual(options.quality, "standard")
    }
    
    func testTimelineGeneratorWithImageGenerationOptions() {
        let apiKey = "test-api-key"
        let imageOptions = ImageGenerationOptions(maxImages: 2)
        
        let generator = TimelineGenerator(
            apiKey: apiKey,
            baseURL: nil,
            model: nil,
            imageGenerationOptions: imageOptions
        )
        
        XCTAssertNotNil(generator)
    }
    
    func testOpenAIClientConfigurationWithImageOptions() {
        let config = OpenAIClient.Configuration(
            apiKey: "test-api-key",
            imageGenerationOptions: ImageGenerationOptions(maxImages: 3)
        )
        
        XCTAssertEqual(config.imageGenerationOptions.maxImages, 3)
        XCTAssertEqual(config.apiKey, "test-api-key")
    }
    
    func testImageGenerationDisabledWhenMaxImagesIsZero() {
        let options = ImageGenerationOptions(maxImages: 0)
        XCTAssertEqual(options.maxImages, 0)
    }
    
    func testImageGenerationEnabledWhenMaxImagesIsPositive() {
        let options = ImageGenerationOptions(maxImages: 5)
        XCTAssertEqual(options.maxImages, 5)
    }
}