import Foundation
import VideoGenerator
import CoreImage
import CoreText
import AVFoundation

// Test script to verify text alignment for .wrap and .autoScale behaviors
func testTextAlignment() async throws {
    print("🎬 Testing Text Alignment for .wrap and .autoScale behaviors")
    
    // Create timeline
    let timeline = await Timeline(
        size: CGSize(width: 1920, height: 1080),
        frameRate: 30,
        backgroundColor: CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
    )
    
    // Create overlay track for text
    var overlayTrack = Track(trackType: .overlay, isEnabled: true)
    
    // Test 1: .wrap behavior with center alignment (default)
    let wrapTextClip = Clip(
        mediaItem: .text(
            "This is a wrapped text that should be centered horizontally within its frame",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            behavior: .wrap,
            alignment: .center
        ),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 400, y: 100, width: 1120, height: 200)
    )
    overlayTrack.clips.append(wrapTextClip)
    
    // Test 2: .autoScale behavior with center alignment (default)
    let autoScaleTextClip = Clip(
        mediaItem: .text(
            "AUTO-SCALED TEXT THAT SHOULD BE CENTERED",
            font: CTFont(.system, size: 120),
            color: CGColor(red: 1, green: 0.8, blue: 0.2, alpha: 1),
            behavior: .autoScale,
            alignment: .center
        ),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 400, y: 400, width: 1120, height: 150)
    )
    overlayTrack.clips.append(autoScaleTextClip)
    
    // Test 3: .wrap with left alignment for comparison
    let leftAlignedClip = Clip(
        mediaItem: .text(
            "Left aligned wrapped text for comparison",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 0.8, green: 0.8, blue: 1, alpha: 1),
            behavior: .wrap,
            alignment: .left
        ),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 400, y: 700, width: 1120, height: 100)
    )
    overlayTrack.clips.append(leftAlignedClip)
    
    // Test 4: .wrap with right alignment for comparison
    let rightAlignedClip = Clip(
        mediaItem: .text(
            "Right aligned wrapped text for comparison",
            font: CTFont(.system, size: 48),
            color: CGColor(red: 1, green: 0.8, blue: 0.8, alpha: 1),
            behavior: .wrap,
            alignment: .right
        ),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 400, y: 850, width: 1120, height: 100)
    )
    overlayTrack.clips.append(rightAlignedClip)
    
    // Add visual guides - vertical lines to show frame boundaries
    let lineColor = CGColor(red: 0, green: 1, blue: 0, alpha: 0.5)
    let lineImage = createLineImage(width: 2, height: 1080, color: lineColor)
    
    // Left boundary line
    let leftLineClip = Clip(
        mediaItem: .image(lineImage, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 399, y: 0, width: 2, height: 1080)
    )
    overlayTrack.clips.append(leftLineClip)
    
    // Right boundary line
    let rightLineClip = Clip(
        mediaItem: .image(lineImage, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 1520, y: 0, width: 2, height: 1080)
    )
    overlayTrack.clips.append(rightLineClip)
    
    // Center line (red) to verify center alignment
    let centerLineImage = createLineImage(width: 2, height: 1080, color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
    let centerLineClip = Clip(
        mediaItem: .image(centerLineImage, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30)),
        frame: CGRect(x: 959, y: 0, width: 2, height: 1080)
    )
    overlayTrack.clips.append(centerLineClip)
    
    // Add track to timeline
    await timeline.addTrack(overlayTrack)
    
    // Export a single frame for testing
    let compositor = try await VideoCompositor()
    let testTime = CMTime(seconds: 1, preferredTimescale: 30)
    let pixelBuffer = try await compositor.compose(timeline: timeline, at: testTime)
    
    // Convert to image and save
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    
    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        // Save as PNG
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("text_alignment_test.png")
        
        if let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypePNG, 1, nil) {
            CGImageDestinationAddImage(destination, cgImage, nil)
            CGImageDestinationFinalize(destination)
            print("✅ Test image saved to: \(outputURL.path)")
            print("   Please check the image to verify:")
            print("   - Wrapped text (white) should be centered between green lines")
            print("   - Auto-scaled text (yellow) should be centered between green lines")
            print("   - Left aligned text (blue) should align to left green line")
            print("   - Right aligned text (pink) should align to right green line")
            print("   - Red line shows the center point")
        }
    }
}

// Helper function to create a vertical line image
func createLineImage(width: Int, height: Int, color: CGColor) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    
    return context.makeImage()!
}

// Run the test
Task {
    do {
        try await testTextAlignment()
    } catch {
        print("❌ Test failed: \(error)")
    }
}

// Keep the script running
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))