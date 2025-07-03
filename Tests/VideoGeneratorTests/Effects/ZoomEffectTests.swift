import Testing
import Foundation
import CoreMedia
import CoreImage
@testable import VideoGenerator

@Suite("ZoomEffect Tests")
struct ZoomEffectTests {
    
    @Test("ZoomEffect initialization")
    func testInitialization() async throws {
        let effect = ZoomEffect(zoomFactor: 2.0, centerX: 0.3, centerY: 0.7)
        
        #expect(effect.id != UUID())
        let zoomFactor: Float? = effect.parameters["zoomFactor"]
        let centerX: Float? = effect.parameters["centerX"]
        let centerY: Float? = effect.parameters["centerY"]
        #expect(zoomFactor == 2.0)
        #expect(centerX == 0.3)
        #expect(centerY == 0.7)
    }
    
    @Test("ZoomEffect default values")
    func testDefaultValues() async throws {
        let effect = ZoomEffect()
        
        let zoomFactor: Float? = effect.parameters["zoomFactor"]
        let centerX: Float? = effect.parameters["centerX"]
        let centerY: Float? = effect.parameters["centerY"]
        #expect(zoomFactor == 1.5)
        #expect(centerX == 0.5)
        #expect(centerY == 0.5)
    }
    
    @Test("ZoomEffect convenience initializers")
    func testConvenienceInitializers() async throws {
        let zoomIn = ZoomEffect.zoomIn(factor: 2.0, center: CGPoint(x: 0.3, y: 0.7))
        let zoomInFactor: Float? = zoomIn.parameters["zoomFactor"]
        let zoomInCenterX: Float? = zoomIn.parameters["centerX"]
        let zoomInCenterY: Float? = zoomIn.parameters["centerY"]
        #expect(zoomInFactor == 2.0)
        #expect(zoomInCenterX == 0.3)
        #expect(zoomInCenterY == 0.7)
        
        let zoomOut = ZoomEffect.zoomOut(factor: 0.5, center: CGPoint(x: 0.2, y: 0.8))
        let zoomOutFactor: Float? = zoomOut.parameters["zoomFactor"]
        let zoomOutCenterX: Float? = zoomOut.parameters["centerX"]
        let zoomOutCenterY: Float? = zoomOut.parameters["centerY"]
        #expect(zoomOutFactor == 0.5)
        #expect(zoomOutCenterX == 0.2)
        #expect(zoomOutCenterY == 0.8)
    }
    
    @Test("AnimatedZoomEffect initialization")
    func testAnimatedZoomEffectInitialization() async throws {
        let duration = CMTime(seconds: 3, preferredTimescale: 30)
        let effect = AnimatedZoomEffect(
            startZoom: 1.0,
            endZoom: 2.0,
            duration: duration,
            centerX: 0.4,
            centerY: 0.6
        )
        
        #expect(effect.id != UUID())
        let centerX: Float? = effect.parameters["centerX"]
        let centerY: Float? = effect.parameters["centerY"]
        #expect(centerX == 0.4)
        #expect(centerY == 0.6)
    }
    
    @Test("KenBurnsEffect initialization")
    func testKenBurnsEffectInitialization() async throws {
        let startRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let endRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let duration = CMTime(seconds: 5, preferredTimescale: 30)
        
        let effect = KenBurnsEffect(
            startRect: startRect,
            endRect: endRect,
            duration: duration
        )
        
        #expect(effect.id != UUID())
    }
    
    @Test("KenBurnsEffect convenience initializers")
    func testKenBurnsConvenienceInitializers() async throws {
        let duration = CMTime(seconds: 4, preferredTimescale: 30)
        
        let zoomInPan = KenBurnsEffect.zoomInPan(
            from: CGPoint(x: 0.2, y: 0.3),
            to: CGPoint(x: 0.8, y: 0.7),
            zoomFactor: 2.0,
            duration: duration
        )
        #expect(zoomInPan.id != UUID())
        
        let zoomOutPan = KenBurnsEffect.zoomOutPan(
            from: CGPoint(x: 0.3, y: 0.4),
            to: CGPoint(x: 0.7, y: 0.6),
            zoomFactor: 0.5,
            duration: duration
        )
        #expect(zoomOutPan.id != UUID())
    }
    
    @Test("ZoomEffect CIImage rendering")
    func testZoomEffectRendering() async throws {
        // Create a test CIImage
        let size = CGSize(width: 100, height: 100)
        let ciImage = CIImage(color: CIColor.red).cropped(to: CGRect(origin: .zero, size: size))
        
        // Create render context
        let context = ZoomMockRenderContext(size: size, frameRate: 30)
        
        // Test zoom effect
        let zoomEffect = ZoomEffect(zoomFactor: 2.0, centerX: 0.5, centerY: 0.5)
        let resultImage = try await zoomEffect.apply(
            to: ciImage,
            at: CMTime(seconds: 1, preferredTimescale: 30),
            renderContext: context
        )
        
        // When zoomed in by 2.0, the frame should be twice as large
        let expectedSize = CGSize(width: size.width * 2.0, height: size.height * 2.0)
        #expect(resultImage.extent.size == expectedSize)
    }
    
    @Test("AnimatedZoomEffect progress calculation")
    func testAnimatedZoomProgress() async throws {
        let size = CGSize(width: 100, height: 100)
        let ciImage = CIImage(color: CIColor.blue).cropped(to: CGRect(origin: .zero, size: size))
        
        let context = ZoomMockRenderContext(size: size, frameRate: 30)
        let duration = CMTime(seconds: 2, preferredTimescale: 30)
        
        let animatedZoom = AnimatedZoomEffect(
            startZoom: 1.0,
            endZoom: 2.0,
            duration: duration
        )
        
        // Test at different time points
        let times = [
            CMTime.zero, // Start
            CMTime(seconds: 1, preferredTimescale: 30), // Middle
            CMTime(seconds: 2, preferredTimescale: 30)  // End
        ]
        
        for time in times {
            let result = try await animatedZoom.apply(
                to: ciImage,
                at: time,
                renderContext: context
            )
            // Calculate expected size based on progress
            let progress = CMTimeGetSeconds(time) / CMTimeGetSeconds(duration)
            let currentZoom = 1.0 + (2.0 - 1.0) * min(1.0, max(0.0, progress))
            let expectedSize = CGSize(width: size.width * currentZoom, height: size.height * currentZoom)
            #expect(abs(result.extent.size.width - expectedSize.width) < 0.01)
            #expect(abs(result.extent.size.height - expectedSize.height) < 0.01)
        }
    }
}

// Mock render context for testing
private struct ZoomMockRenderContext: RenderContext {
    let size: CGSize
    let time: CMTime = .zero
    let frameRate: Int
    
    init(size: CGSize, frameRate: Int) {
        self.size = size
        self.frameRate = frameRate
    }
    
    func image(for mediaItem: any MediaItem) async throws -> CIImage {
        // Return a dummy image for testing
        return CIImage(color: CIColor.gray).cropped(to: CGRect(origin: .zero, size: size))
    }
}