import Foundation
import VideoGenerator
import CoreMedia
import CoreGraphics
import CoreImage

// MARK: - Example Effects

struct BlurEffect: Effect {
    let id = UUID()
    var parameters: EffectParameters
    
    init(radius: Float = 10.0) {
        self.parameters = EffectParameters([
            "radius": .float(radius)
        ])
    }
    
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Apply blur using Core Image filter
        let radius: Float = parameters["radius"] ?? 10.0
        print("Applying blur with radius: \(radius)")
        
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = image
        filter.radius = radius
        
        return filter.outputImage ?? image
    }
}

struct ColorGradingEffect: Effect {
    let id = UUID()
    var parameters: EffectParameters
    
    init(brightness: Float = 1.0, contrast: Float = 1.0, saturation: Float = 1.0) {
        self.parameters = EffectParameters([
            "brightness": .float(brightness),
            "contrast": .float(contrast),
            "saturation": .float(saturation)
        ])
    }
    
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Apply color grading using Core Image filters
        let brightness: Float = parameters["brightness"] ?? 1.0
        let contrast: Float = parameters["contrast"] ?? 1.0
        let saturation: Float = parameters["saturation"] ?? 1.0
        
        print("Applying color grading - brightness: \(brightness), contrast: \(contrast), saturation: \(saturation)")
        
        var result = image
        
        // Apply brightness
        if brightness != 1.0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.brightness = brightness - 1.0
            result = filter.outputImage ?? result
        }
        
        // Apply contrast
        if contrast != 1.0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.contrast = contrast
            result = filter.outputImage ?? result
        }
        
        // Apply saturation
        if saturation != 1.0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = result
            filter.saturation = saturation
            result = filter.outputImage ?? result
        }
        
        return result
    }
}

struct VignetteEffect: Effect {
    let id = UUID()
    var parameters: EffectParameters
    
    init(intensity: Float = 0.5, radius: Float = 0.8) {
        self.parameters = EffectParameters([
            "intensity": .float(intensity),
            "radius": .float(radius)
        ])
    }
    
    func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
        // Apply vignette using Core Image filter
        let intensity: Float = parameters["intensity"] ?? 0.5
        let radius: Float = parameters["radius"] ?? 0.8
        
        print("Applying vignette - intensity: \(intensity), radius: \(radius)")
        
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = intensity
        filter.radius = radius
        
        return filter.outputImage ?? image
    }
}

// MARK: - Composite Effect Examples

func compositeEffectExamples() async throws {
    // Example 1: Sequential effects (film look)
    let filmLookEffect = CompositeEffect.sequential([
        ColorGradingEffect(brightness: 0.9, contrast: 1.2, saturation: 0.8),
        VignetteEffect(intensity: 0.3, radius: 0.7),
        BlurEffect(radius: 2.0)
    ])
    
    // Example 2: Using the builder pattern
    let customEffect = await EffectChain()
        .add(BlurEffect(radius: 5.0))
        .add(ColorGradingEffect(brightness: 1.1, contrast: 1.0, saturation: 1.2))
        .add(VignetteEffect())
        .blendMode(.sequential)
        .build()
    
    // Example 3: Parallel effects with blending
    let parallelEffect = CompositeEffect.parallel([
        BlurEffect(radius: 10.0),
        ColorGradingEffect(brightness: 1.5, contrast: 0.8, saturation: 1.0)
    ], blend: BlendFunctions.screen)
    
    // Example 4: Using operator syntax
    let blur = BlurEffect(radius: 8.0)
    let colorGrading = ColorGradingEffect(brightness: 1.2, contrast: 1.1, saturation: 0.9)
    let combinedEffect = blur.then(colorGrading)
    
    // Example 5: Conditional and animated effects
    let timeBasedEffect = BlurEffect(radius: 5.0)
        .timeRange(CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 30), 
                              duration: CMTime(seconds: 3, preferredTimescale: 30)))
    
    let conditionalEffect = ColorGradingEffect()
        .when { time, context in
            // Apply effect only in the first half of the video
            time.seconds < 5.0
        }
    
    // Example 6: Complex composite with modifiers
    let complexEffect = await EffectChain()
        .add(BlurEffect().parameter("radius", value: .float(3.0)))
        .add(ColorGradingEffect()
            .parameter("brightness", value: .float(1.1))
            .parameter("contrast", value: .float(1.2)))
        .add(VignetteEffect()
            .timeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 30))))
        .build()
    
    // Example 7: Custom blend mode
    let customBlendEffect = CompositeEffect(
        effects: [
            BlurEffect(radius: 5.0),
            ColorGradingEffect(brightness: 1.3, contrast: 0.9, saturation: 1.1),
            VignetteEffect(intensity: 0.4, radius: 0.6)
        ],
        blendMode: .custom { image, effects, time, context in
            // Custom processing logic
            var result = image
            
            // Apply first two effects in parallel
            if effects.count >= 2 {
                async let blurred = effects[0].apply(to: image, at: time, renderContext: context)
                async let graded = effects[1].apply(to: image, at: time, renderContext: context)
                
                // Blend them together
                let blurredImage = try await blurred
                let gradedImage = try await graded
                result = try await BlendFunctions.average(blurredImage, gradedImage, context)
            }
            
            // Apply vignette on top
            if effects.count >= 3 {
                result = try await effects[2].apply(to: result, at: time, renderContext: context)
            }
            
            return result
        }
    )
    
    print("Composite effects created successfully!")
}

// MARK: - Usage in Timeline

func timelineWithCompositeEffects() async throws {
    // Create timeline
    let timeline = await Timeline(size: CGSize(width: 1920, height: 1080), frameRate: 30)
    
    // Create a video clip with composite effects
    let videoClip = Clip(
        mediaItem: .video(url: URL(fileURLWithPath: "/path/to/video.mp4")),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 30)),
        effects: [
            // Film noir effect
            CompositeEffect.sequential([
                ColorGradingEffect(brightness: 0.7, contrast: 1.5, saturation: 0.0), // Desaturate
                VignetteEffect(intensity: 0.6, radius: 0.5), // Heavy vignette
                BlurEffect(radius: 1.0) // Slight blur for vintage feel
            ])
        ]
    )
    
    // Create an overlay with animated effects
    let textClip = Clip(
        mediaItem: .text("DRAMATIC TITLE"),
        timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), 
                              duration: CMTime(seconds: 5, preferredTimescale: 30)),
        effects: [
            // Animated glow effect
            BlurEffect(radius: 20.0)
                .animated(with: EffectAnimation(
                    duration: CMTime(seconds: 5, preferredTimescale: 30),
                    keyframes: [
                        Keyframe(time: .zero, parameters: ["radius": .float(0.0)]),
                        Keyframe(time: CMTime(seconds: 2.5, preferredTimescale: 30), parameters: ["radius": .float(20.0)]),
                        Keyframe(time: CMTime(seconds: 5, preferredTimescale: 30), parameters: ["radius": .float(0.0)])
                    ],
                    interpolation: .easeInOut
                ))
        ]
    )
    
    // Add to timeline
    await timeline.tracks = [
        Track(id: UUID(), trackType: .video, clips: [videoClip], isEnabled: true),
        Track(id: UUID(), trackType: .overlay, clips: [textClip], isEnabled: true)
    ]
    
    print("Timeline with composite effects created!")
}