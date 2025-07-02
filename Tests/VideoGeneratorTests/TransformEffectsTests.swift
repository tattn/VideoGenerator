import Testing
import Foundation
import AVFoundation
@preconcurrency import CoreImage
import CoreGraphics
@testable import VideoGenerator

// MARK: - Transform Effects Tests

@Suite("Transform Effects Tests")
struct TransformEffectsTests {
    
    // Helper to create a test image
    private func createTestImage() -> CIImage {
        CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    
    @Test("Scale effect initialization")
    func testScaleEffectInit() {
        let effect = ScaleEffect(scaleX: 2.0, scaleY: 0.5)
        
        let scaleX: Float? = effect.parameters["scaleX"]
        let scaleY: Float? = effect.parameters["scaleY"]
        
        #expect(scaleX == 2.0)
        #expect(scaleY == 0.5)
    }
    
    @Test("Rotation effect initialization")
    func testRotationEffectInit() {
        let angle: Float = .pi / 2
        let effect = RotationEffect(angle: angle)
        
        let storedAngle: Float? = effect.parameters["angle"]
        #expect(storedAngle == angle)
    }
    
    @Test("Translation effect initialization")
    func testTranslationEffectInit() {
        let effect = TranslationEffect(x: 50, y: -30)
        
        let x: Float? = effect.parameters["x"]
        let y: Float? = effect.parameters["y"]
        
        #expect(x == 50)
        #expect(y == -30)
    }
    
    @Test("Animated rotation effect initialization")
    func testAnimatedRotationEffectInit() {
        let effect = AnimatedRotationEffect(duration: 2.0, rotations: 3.0)
        
        let duration: Float? = effect.parameters["duration"]
        let rotations: Float? = effect.parameters["rotations"]
        
        #expect(duration == 2.0)
        #expect(rotations == 3.0)
    }
    
    @Test("Scale effect application")
    func testScaleEffectApplication() async throws {
        let effect = ScaleEffect(scaleX: 2.0, scaleY: 2.0)
        let inputImage = createTestImage()
        let context = TestRenderContext(size: CGSize(width: 200, height: 200), frameRate: 30)
        
        let outputImage = try await effect.apply(to: inputImage, at: .zero, renderContext: context)
        
        // The output image should have double the size
        let expectedWidth = inputImage.extent.width * 2
        let expectedHeight = inputImage.extent.height * 2
        
        #expect(outputImage.extent.width == expectedWidth)
        #expect(outputImage.extent.height == expectedHeight)
    }
    
    @Test("Translation effect application")
    func testTranslationEffectApplication() async throws {
        let effect = TranslationEffect(x: 50, y: 30)
        let inputImage = createTestImage()
        let context = TestRenderContext(size: CGSize(width: 200, height: 200), frameRate: 30)
        
        let outputImage = try await effect.apply(to: inputImage, at: .zero, renderContext: context)
        
        // The output image should be translated
        #expect(outputImage.extent.origin.x == inputImage.extent.origin.x + 50)
        #expect(outputImage.extent.origin.y == inputImage.extent.origin.y + 30)
    }
    
    @Test("Animated rotation effect at different times")
    func testAnimatedRotationAtDifferentTimes() async throws {
        let effect = AnimatedRotationEffect(duration: 1.0, rotations: 1.0)
        let inputImage = createTestImage()
        let context = TestRenderContext(size: CGSize(width: 200, height: 200), frameRate: 30)
        
        // Test at t=0 (no rotation)
        let output0 = try await effect.apply(to: inputImage, at: .zero, renderContext: context)
        
        // Test at t=0.5s (half rotation)
        let halfTime = CMTime(seconds: 0.5, preferredTimescale: 30)
        let output05 = try await effect.apply(to: inputImage, at: halfTime, renderContext: context)
        
        // The images should be different due to rotation
        // We can't directly compare transforms, but we can verify the extent is calculated
        #expect(output0.extent.size == inputImage.extent.size)
        #expect(output05.extent.size == inputImage.extent.size)
    }
}

// MARK: - Test Render Context

private actor TestRenderContext: RenderContext {
    nonisolated let size: CGSize
    nonisolated let frameRate: Int
    private var _time: CMTime = .zero
    
    init(size: CGSize, frameRate: Int) {
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
        // Return a simple test image
        return CIImage(color: CIColor(red: 0, green: 0, blue: 1, alpha: 1))
            .cropped(to: CGRect(origin: .zero, size: size))
    }
}