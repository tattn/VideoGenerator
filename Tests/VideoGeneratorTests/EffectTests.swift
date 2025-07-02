import Testing
import Foundation
import AVFoundation
@preconcurrency import CoreImage
@testable import VideoGenerator

// MARK: - Effect Tests

@Suite("Effect Tests")
struct EffectTests {
    
    @Test("EffectParameters initialization and access")
    func testEffectParameters() {
        let params = EffectParameters([
            "brightness": .float(0.5),
            "contrast": .float(1.2),
            "enabled": .bool(true),
            "name": .string("Test Effect"),
            "size": .size(CGSize(width: 100, height: 200))
        ])
        
        let brightness: Float? = params["brightness"]
        #expect(brightness == 0.5)
        
        let contrast: Float? = params["contrast"]
        #expect(contrast == 1.2)
        
        let enabled: Bool? = params["enabled"]
        #expect(enabled == true)
        
        let name: String? = params["name"]
        #expect(name == "Test Effect")
        
        let size: CGSize? = params["size"]
        #expect(size == CGSize(width: 100, height: 200))
        
        let missing: Int? = params["missing"]
        #expect(missing == nil)
    }
    
    @Test("Brightness effect initialization")
    func testBrightnessEffect() {
        let effect = BrightnessEffect(brightness: 0.3)
        
        let brightness: Float? = effect.parameters["brightness"]
        #expect(brightness == 0.3)
    }
    
    @Test("Contrast effect initialization")
    func testContrastEffect() {
        let effect = ContrastEffect(contrast: 1.5)
        
        let contrast: Float? = effect.parameters["contrast"]
        #expect(contrast == 1.5)
    }
    
    @Test("Saturation effect initialization")
    func testSaturationEffect() {
        let effect = SaturationEffect(saturation: 0.8)
        
        let saturation: Float? = effect.parameters["saturation"]
        #expect(saturation == 0.8)
    }
    
    @Test("Gaussian blur effect initialization")
    func testGaussianBlurEffect() {
        let effect = GaussianBlurEffect(radius: 15.0)
        
        let radius: Float? = effect.parameters["radius"]
        #expect(radius == 15.0)
    }
    
    @Test("Motion blur effect initialization")
    func testMotionBlurEffect() {
        let effect = MotionBlurEffect(radius: 25.0, angle: Float.pi / 4)
        
        let radius: Float? = effect.parameters["radius"]
        #expect(radius == 25.0)
        
        let angle: Float? = effect.parameters["angle"]
        #expect(angle == Float.pi / 4)
    }
    
    @Test("Scale effect initialization")
    func testScaleEffect() {
        let effect = ScaleEffect(scaleX: 1.5, scaleY: 2.0)
        
        let scaleX: Float? = effect.parameters["scaleX"]
        #expect(scaleX == 1.5)
        
        let scaleY: Float? = effect.parameters["scaleY"]
        #expect(scaleY == 2.0)
    }
    
    @Test("Rotation effect initialization")
    func testRotationEffect() {
        let effect = RotationEffect(angle: Float.pi / 2)
        
        let angle: Float? = effect.parameters["angle"]
        #expect(angle == Float.pi / 2)
    }
    
    @Test("Translation effect initialization")
    func testTranslationEffect() {
        let effect = TranslationEffect(x: 50, y: -30)
        
        let x: Float? = effect.parameters["x"]
        #expect(x == 50)
        
        let y: Float? = effect.parameters["y"]
        #expect(y == -30)
    }
    
    @Test("Base effect with custom apply function")
    func testBaseEffect() async throws {
        let customEffect = BaseEffect(
            parameters: EffectParameters(["multiplier": .float(2.0)])
        ) { image, time, context in
            image
        }
        
        let multiplier: Float? = customEffect.parameters["multiplier"]
        #expect(multiplier == 2.0)
        
        let testImage = CIImage(color: CIColor.black)
        let resultImage = try await customEffect.apply(
            to: testImage,
            at: .zero,
            renderContext: TestRenderContext()
        )
        
        #expect(resultImage.extent == testImage.extent)
    }
}

// MARK: - Test Render Context

private actor TestRenderContext: RenderContext {
    nonisolated let size: CGSize
    nonisolated let frameRate: Int
    private var _time: CMTime = .zero
    
    init(size: CGSize = CGSize(width: 1920, height: 1080), frameRate: Int = 30) {
        self.size = size
        self.frameRate = frameRate
    }
    
    var time: CMTime {
        _time
    }
    
    func setTime(_ time: CMTime) {
        self._time = time
    }
    
    func image(for mediaItem: any MediaItem) async throws -> CIImage {
        CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
    }
}