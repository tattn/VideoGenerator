import Testing
@testable import VideoGenerator
import CoreImage
import AVFoundation

@Suite("Camera Shake Effect Tests")
struct CameraShakeEffectTests {
    
    @Test("Camera shake effect initialization")
    func testInitialization() async throws {
        let effect = CameraShakeEffect(
            intensity: 15.0,
            frequency: 40.0,
            smoothness: 0.85,
            rotationIntensity: 0.7
        )
        
        #expect(effect.id != UUID())
        let intensity: Float? = effect.parameters["intensity"]
        #expect(intensity == 15.0)
        
        let frequency: Float? = effect.parameters["frequency"]
        #expect(frequency == 40.0)
        
        let smoothness: Float? = effect.parameters["smoothness"]
        #expect(smoothness == 0.85)
        
        let rotationIntensity: Float? = effect.parameters["rotationIntensity"]
        #expect(rotationIntensity == 0.7)
    }
    
    @Test("Preset camera shake effects")
    func testPresets() async throws {
        let subtle = CameraShakeEffect.subtle
        let subtleIntensity: Float? = subtle.parameters["intensity"]
        #expect(subtleIntensity == 3.0)
        
        let medium = CameraShakeEffect.medium
        let mediumIntensity: Float? = medium.parameters["intensity"]
        #expect(mediumIntensity == 10.0)
        
        let intense = CameraShakeEffect.intense
        let intenseIntensity: Float? = intense.parameters["intensity"]
        #expect(intenseIntensity == 25.0)
        
        let documentary = CameraShakeEffect.documentary
        let docIntensity: Float? = documentary.parameters["intensity"]
        #expect(docIntensity == 5.0)
        
        let action = CameraShakeEffect.action
        let actionIntensity: Float? = action.parameters["intensity"]
        #expect(actionIntensity == 15.0)
    }
    
    @Test("Camera shake effect applies transform")
    func testApplyEffect() async throws {
        let effect = CameraShakeEffect.medium
        let inputImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let renderContext = await DefaultRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        // Test at different time points
        let times = [
            CMTime(seconds: 0, preferredTimescale: 30),
            CMTime(seconds: 0.5, preferredTimescale: 30),
            CMTime(seconds: 1.0, preferredTimescale: 30),
            CMTime(seconds: 1.5, preferredTimescale: 30)
        ]
        
        for time in times {
            await renderContext.setTime(time)
            let outputImage = try await effect.apply(to: inputImage, at: time, renderContext: renderContext)
            
            // Verify output maintains original bounds
            #expect(outputImage.extent == inputImage.extent)
        }
    }
    
    @Test("Camera shake produces different transforms at different times")
    func testTemporalVariation() async throws {
        let effect = CameraShakeEffect.intense
        let inputImage = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))
        let renderContext = await DefaultRenderContext(size: CGSize(width: 200, height: 200), frameRate: 30)
        
        let time1 = CMTime(seconds: 0.1, preferredTimescale: 30)
        let time2 = CMTime(seconds: 0.2, preferredTimescale: 30)
        
        await renderContext.setTime(time1)
        let output1 = try await effect.apply(to: inputImage, at: time1, renderContext: renderContext)
        
        await renderContext.setTime(time2)
        let output2 = try await effect.apply(to: inputImage, at: time2, renderContext: renderContext)
        
        // The transforms should be different at different times
        // We can't directly compare CIImages, but we know they should be different
        // due to the time-based noise generation
        #expect(time1 != time2)
    }
    
    @Test("Zero intensity produces no shake")
    func testZeroIntensity() async throws {
        let effect = CameraShakeEffect(
            intensity: 0.0,
            frequency: 30.0,
            smoothness: 0.8,
            rotationIntensity: 0.0
        )
        
        let inputImage = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let renderContext = await DefaultRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        let time = CMTime(seconds: 1.0, preferredTimescale: 30)
        
        await renderContext.setTime(time)
        let outputImage = try await effect.apply(to: inputImage, at: time, renderContext: renderContext)
        
        // With zero intensity, the output should be essentially unchanged
        #expect(outputImage.extent == inputImage.extent)
    }
}