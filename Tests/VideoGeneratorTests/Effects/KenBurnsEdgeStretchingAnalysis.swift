import Testing
import Foundation
import CoreMedia
import CoreImage
@testable import VideoGenerator

@Suite("KenBurns Edge Stretching Analysis")
struct KenBurnsEdgeStretchingAnalysis {
    
    @Test("Analyze KenBurnsEffect edge stretching issue")
    func analyzeEdgeStretching() async throws {
        // Create a test image with a checkerboard pattern to make edge stretching visible
        let size = CGSize(width: 200, height: 200)
        let checkerboardImage = createCheckerboardImage(size: size)
        
        // Create render context
        let context = MockRenderContext(size: size, frameRate: 30)
        
        // Test Case 1: Zoom out (scale < 1) - this is where edge stretching occurs
        print("\n=== Test Case 1: Zoom Out (scale < 1) ===")
        let zoomOutRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5) // Zoomed in start
        let fullRect = CGRect(x: 0, y: 0, width: 1, height: 1) // Full view end
        
        let kenBurnsZoomOut = KenBurnsEffect(
            startRect: zoomOutRect,
            endRect: fullRect,
            duration: CMTime(seconds: 2, preferredTimescale: 30)
        )
        
        // Test at different time points
        let times = [
            CMTime(seconds: 0, preferredTimescale: 30),   // Start (zoomed in)
            CMTime(seconds: 1, preferredTimescale: 30),   // Middle
            CMTime(seconds: 2, preferredTimescale: 30)    // End (zoomed out)
        ]
        
        for time in times {
            print("\nTime: \(time.seconds)s")
            let result = try await kenBurnsZoomOut.apply(
                to: checkerboardImage,
                at: time,
                renderContext: context
            )
            
            // Analyze the result
            analyzeImage(result, originalExtent: checkerboardImage.extent)
        }
        
        // Test Case 2: Zoom in (scale >= 1) - this should work correctly
        print("\n=== Test Case 2: Zoom In (scale >= 1) ===")
        let kenBurnsZoomIn = KenBurnsEffect(
            startRect: fullRect,
            endRect: zoomOutRect,
            duration: CMTime(seconds: 2, preferredTimescale: 30)
        )
        
        for time in times {
            print("\nTime: \(time.seconds)s")
            let result = try await kenBurnsZoomIn.apply(
                to: checkerboardImage,
                at: time,
                renderContext: context
            )
            
            analyzeImage(result, originalExtent: checkerboardImage.extent)
        }
        
        // Test Case 3: Compare with ZoomEffect
        print("\n=== Test Case 3: Compare with ZoomEffect ===")
        let zoomEffect = ZoomEffect(zoomFactor: 0.5) // Zoom out
        let zoomResult = try await zoomEffect.apply(
            to: checkerboardImage,
            at: CMTime.zero,
            renderContext: context
        )
        
        print("ZoomEffect (zoom out):")
        analyzeImage(zoomResult, originalExtent: checkerboardImage.extent)
    }
    
    @Test("Test KenBurnsEffect transform calculation")
    func testTransformCalculation() async throws {
        // Analyze the transform calculation in KenBurnsEffect
        
        let imageExtent = CGRect(x: 0, y: 0, width: 200, height: 200)
        
        // Case 1: Full image to half size (zoom out)
        let startRect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let endRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        // At end time (progress = 1.0), we should be at endRect
        let currentRect = endRect
        
        // Convert from normalized to actual coordinates
        let actualRect = CGRect(
            x: currentRect.origin.x * imageExtent.width,
            y: currentRect.origin.y * imageExtent.height,
            width: currentRect.width * imageExtent.width,
            height: currentRect.height * imageExtent.height
        )
        
        print("Current rect (normalized): \(currentRect)")
        print("Actual rect: \(actualRect)")
        
        // Calculate scale
        let scaleX = imageExtent.width / actualRect.width
        let scaleY = imageExtent.height / actualRect.height
        let scale = min(scaleX, scaleY)
        
        print("Scale X: \(scaleX), Scale Y: \(scaleY), Final scale: \(scale)")
        
        // Create transform
        let transform = CGAffineTransform(translationX: -actualRect.origin.x, y: -actualRect.origin.y)
            .scaledBy(x: scale, y: scale)
        
        print("Transform: \(transform)")
        
        // The issue: when scale < 1, the image doesn't fill the original extent
        // This causes CIAffineClamp to stretch the edges
        
        #expect(scale == 1.0) // This will fail when zooming out
    }
    
    @Test("Test alternative implementation approach")
    func testAlternativeApproach() async throws {
        // Test an alternative approach that might fix the edge stretching
        
        let size = CGSize(width: 200, height: 200)
        let checkerboardImage = createCheckerboardImage(size: size)
        let context = MockRenderContext(size: size, frameRate: 30)
        
        // Alternative implementation that crops first, then scales
        let alternativeKenBurns = AlternativeKenBurnsEffect(
            startRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            endRect: CGRect(x: 0, y: 0, width: 1, height: 1),
            duration: CMTime(seconds: 2, preferredTimescale: 30)
        )
        
        let result = try await alternativeKenBurns.apply(
            to: checkerboardImage,
            at: CMTime(seconds: 2, preferredTimescale: 30),
            renderContext: context
        )
        
        print("Alternative implementation result:")
        analyzeImage(result, originalExtent: checkerboardImage.extent)
    }
    
    // Helper functions
    
    private func createCheckerboardImage(size: CGSize) -> CIImage {
        let checkerFilter = CIFilter(name: "CICheckerboardGenerator")!
        checkerFilter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        checkerFilter.setValue(CIColor.white, forKey: "inputColor0")
        checkerFilter.setValue(CIColor.black, forKey: "inputColor1")
        checkerFilter.setValue(20.0, forKey: "inputWidth")
        checkerFilter.setValue(1.0, forKey: "inputSharpness")
        
        let checkerboard = checkerFilter.outputImage!
        return checkerboard.cropped(to: CGRect(origin: .zero, size: size))
    }
    
    private func analyzeImage(_ image: CIImage, originalExtent: CGRect) {
        print("  Image extent: \(image.extent)")
        print("  Original extent: \(originalExtent)")
        print("  Extent matches: \(image.extent == originalExtent)")
        
        // Check if the image has been transformed
        let transform = image.transform
        print("  Transform: \(transform)")
        print("  Is identity: \(transform.isIdentity)")
    }
}

// Alternative implementation for testing
struct AlternativeKenBurnsEffect: Effect {
    let id = UUID()
    var parameters = EffectParameters()
    let startRect: CGRect
    let endRect: CGRect
    let duration: CMTime
    
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        let progress = Float(CMTimeGetSeconds(time) / CMTimeGetSeconds(duration))
        let clampedProgress = max(0, min(1, progress))
        
        // Interpolate between rectangles
        let currentRect = CGRect(
            x: startRect.origin.x + (endRect.origin.x - startRect.origin.x) * CGFloat(clampedProgress),
            y: startRect.origin.y + (endRect.origin.y - startRect.origin.y) * CGFloat(clampedProgress),
            width: startRect.width + (endRect.width - startRect.width) * CGFloat(clampedProgress),
            height: startRect.height + (endRect.height - startRect.height) * CGFloat(clampedProgress)
        )
        
        let imageExtent = image.extent
        
        // Convert to actual coordinates
        let actualRect = CGRect(
            x: currentRect.origin.x * imageExtent.width,
            y: currentRect.origin.y * imageExtent.height,
            width: currentRect.width * imageExtent.width,
            height: currentRect.height * imageExtent.height
        )
        
        // Alternative approach: Use CICrop filter instead of transform + clamp
        if actualRect.width >= imageExtent.width && actualRect.height >= imageExtent.height {
            // Zooming in - use the original approach
            let scale = imageExtent.width / actualRect.width
            let transform = CGAffineTransform(translationX: -actualRect.origin.x, y: -actualRect.origin.y)
                .scaledBy(x: scale, y: scale)
            
            let transformedImage = image.transformed(by: transform)
            
            let clampFilter = CIFilter(name: "CIAffineClamp")!
            clampFilter.setValue(transformedImage, forKey: kCIInputImageKey)
            clampFilter.setValue(CGAffineTransform.identity, forKey: "inputTransform")
            
            return clampFilter.outputImage!.cropped(to: imageExtent)
        } else {
            // Zooming out - use a different approach
            // First, crop the source region
            let croppedImage = image.cropped(to: actualRect)
            
            // Then scale it to fit the output size
            let scaleX = imageExtent.width / actualRect.width
            let scaleY = imageExtent.height / actualRect.height
            
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            let scaledImage = croppedImage.transformed(by: transform)
            
            // Use CIAffineClamp after scaling
            let clampFilter = CIFilter(name: "CIAffineClamp")!
            clampFilter.setValue(scaledImage, forKey: kCIInputImageKey)
            clampFilter.setValue(CGAffineTransform.identity, forKey: "inputTransform")
            
            return clampFilter.outputImage!.cropped(to: imageExtent)
        }
    }
}

// Mock render context
private struct MockRenderContext: RenderContext {
    let size: CGSize
    let time: CMTime = .zero
    let frameRate: Int
    
    func image(for mediaItem: any MediaItem) async throws -> CIImage {
        return CIImage(color: CIColor.gray).cropped(to: CGRect(origin: .zero, size: size))
    }
}