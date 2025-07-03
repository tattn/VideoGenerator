import Foundation
import CoreImage
import CoreMedia

/// Preset effects for creating engaging vlog-style animations from photos
public struct EffectPresets {
    
    // MARK: - Ken Burns Variations
    
    /// Classic Ken Burns effect with slow zoom and pan
    public static func kenBurnsClassic(
        duration: TimeInterval = 5.0,
        startScale: CGFloat = 1.0,
        endScale: CGFloat = 1.3,
        startPoint: CGPoint = CGPoint(x: 0.3, y: 0.3),
        endPoint: CGPoint = CGPoint(x: 0.7, y: 0.7)
    ) -> CompositeEffect {
        // Calculate rectangles for Ken Burns effect
        let startRect = CGRect(
            x: startPoint.x - 0.5 / startScale,
            y: startPoint.y - 0.5 / startScale,
            width: 1.0 / startScale,
            height: 1.0 / startScale
        )
        let endRect = CGRect(
            x: endPoint.x - 0.5 / endScale,
            y: endPoint.y - 0.5 / endScale,
            width: 1.0 / endScale,
            height: 1.0 / endScale
        )
        
        return CompositeEffect(
            effects: [
                KenBurnsEffect(
                    startRect: startRect,
                    endRect: endRect,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Dramatic Ken Burns with faster movement and higher zoom
    public static func kenBurnsDramatic(
        duration: TimeInterval = 3.0,
        startScale: CGFloat = 0.8,
        endScale: CGFloat = 1.8
    ) -> CompositeEffect {
        let startRect = CGRect(
            x: 0.2 - 0.5 / startScale,
            y: 0.2 - 0.5 / startScale,
            width: 1.0 / startScale,
            height: 1.0 / startScale
        )
        let endRect = CGRect(
            x: 0.8 - 0.5 / endScale,
            y: 0.8 - 0.5 / endScale,
            width: 1.0 / endScale,
            height: 1.0 / endScale
        )
        
        return CompositeEffect(
            effects: [
                KenBurnsEffect(
                    startRect: startRect,
                    endRect: endRect,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Subtle Ken Burns for minimal movement
    public static func kenBurnsSubtle(
        duration: TimeInterval = 8.0
    ) -> CompositeEffect {
        let startScale: CGFloat = 1.0
        let endScale: CGFloat = 1.1
        let startRect = CGRect(
            x: 0.45 - 0.5 / startScale,
            y: 0.45 - 0.5 / startScale,
            width: 1.0 / startScale,
            height: 1.0 / startScale
        )
        let endRect = CGRect(
            x: 0.55 - 0.5 / endScale,
            y: 0.55 - 0.5 / endScale,
            width: 1.0 / endScale,
            height: 1.0 / endScale
        )
        
        return CompositeEffect(
            effects: [
                KenBurnsEffect(
                    startRect: startRect,
                    endRect: endRect,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    // MARK: - Zoom and Rotate Effects
    
    /// Spinning zoom in effect
    public static func spinZoomIn(
        duration: TimeInterval = 3.0,
        rotations: CGFloat = 1.0
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                AnimatedZoomEffect(
                    startZoom: 1.0,
                    endZoom: 1.5,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                ),
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let progress = Float(time.seconds / duration)
                        let angle = progress * Float(.pi * 2 * rotations)
                        let rotationEffect = RotationEffect(angle: angle)
                        return try await rotationEffect.apply(to: image, at: time, renderContext: renderContext)
                    }
                )
            ],
            blendMode: .parallel { image1, image2, renderContext in
                // Blend the two effects
                let filter = CIFilter(name: "CISourceOverCompositing")
                filter?.setValue(image2, forKey: kCIInputImageKey)
                filter?.setValue(image1, forKey: kCIInputBackgroundImageKey)
                return filter?.outputImage ?? image1
            }
        )
    }
    
    /// Pulse zoom effect with rhythm
    public static func pulseZoom(
        duration: TimeInterval = 4.0,
        pulseCount: Int = 4
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let progress = Float(time.seconds / duration)
                        let pulse = sin(progress * .pi * 2 * Float(pulseCount))
                        let zoomFactor = 1.0 + pulse * 0.1
                        
                        let zoomEffect = ZoomEffect(zoomFactor: zoomFactor)
                        return try await zoomEffect.apply(to: image, at: time, renderContext: renderContext)
                    }
                ),
                CameraShakeEffect.subtle.animated(
                    with: EffectAnimation(
                        duration: CMTime(seconds: duration, preferredTimescale: 600),
                        keyframes: [
                            Keyframe(time: CMTime.zero, parameters: ["intensity": .float(0)]),
                            Keyframe(time: CMTime(seconds: duration * 0.5, preferredTimescale: 600), parameters: ["intensity": .float(3.0)]),
                            Keyframe(time: CMTime(seconds: duration, preferredTimescale: 600), parameters: ["intensity": .float(0)])
                        ],
                        interpolation: .easeInOut
                    )
                )
            ],
            blendMode: .parallel { image1, image2, renderContext in
                // Apply both effects
                return image2
            }
        )
    }
    
    // MARK: - Cinematic Effects
    
    /// Letterbox zoom with cinematic feel
    public static func letterboxZoom(
        duration: TimeInterval = 5.0,
        aspectRatio: CGFloat = 2.35
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                // Slow zoom
                AnimatedZoomEffect(
                    startZoom: 1.0,
                    endZoom: 1.3,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                ),
                // Add letterbox overlay (implemented as a vignette-like effect)
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(
                        ["aspectRatio": .double(Double(aspectRatio))]
                    ),
                    apply: { image, time, renderContext in
                        // This would need custom CIFilter implementation
                        // For now, using vignette as placeholder
                        let filter = CIFilter(name: "CIVignette")
                        filter?.setValue(image, forKey: kCIInputImageKey)
                        filter?.setValue(2.0, forKey: "inputRadius")
                        filter?.setValue(1.0, forKey: "inputIntensity")
                        return filter?.outputImage ?? image
                    }
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Parallax zoom effect
    public static func parallaxZoom(
        duration: TimeInterval = 4.0,
        layers: Int = 3
    ) -> CompositeEffect {
        let effects: [any Effect] = (0..<layers).map { layer in
            let scale = 1.0 + CGFloat(layer) * 0.1
            let speed = 1.0 - CGFloat(layer) * 0.2
            
            return BaseEffect(
                id: UUID(),
                parameters: EffectParameters(),
                apply: { image, time, renderContext in
                    let progress = Float(time.seconds / duration)
                    let zoomFactor = Float(scale + CGFloat(progress) * 0.3 * speed)
                    let zoomEffect = ZoomEffect(zoomFactor: zoomFactor)
                    return try await zoomEffect.apply(to: image, at: time, renderContext: renderContext)
                }
            )
        }
        
        return CompositeEffect(
            effects: effects,
            blendMode: .custom { image, effects, time, renderContext in
                // Apply each layer effect and blend them
                var images: [CIImage] = []
                for effect in effects {
                    let layerImage = try await effect.apply(to: image, at: time, renderContext: renderContext)
                    images.append(layerImage)
                }
                
                // Blend layers with transparency
                guard let first = images.first else { return image }
                return images.dropFirst().reduce(first) { result, layerImage in
                    let filter = CIFilter(name: "CISourceOverCompositing")
                    filter?.setValue(layerImage, forKey: kCIInputImageKey)
                    filter?.setValue(result, forKey: kCIInputBackgroundImageKey)
                    return filter?.outputImage ?? result
                }
            }
        )
    }
    
    // MARK: - Trendy Effects
    
    /// Glitch zoom effect
    public static func glitchZoom(
        duration: TimeInterval = 2.0,
        glitchIntensity: CGFloat = 0.2
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                // Base zoom
                AnimatedZoomEffect(
                    startZoom: 1.0,
                    endZoom: 1.4,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                ),
                // Glitch displacement
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(
                        ["intensity": .double(Double(glitchIntensity))]
                    ),
                    apply: { image, time, renderContext in
                        let progress = Float(time.seconds / duration)
                        
                        // Determine if glitch should be active
                        let glitchActive = (progress < 0.2 && progress > 0.1) || 
                                         (progress < 0.9 && progress > 0.8)
                        
                        guard glitchActive else { return image }
                        
                        let filter = CIFilter(name: "CIColorMonochrome")
                        filter?.setValue(image, forKey: kCIInputImageKey)
                        filter?.setValue(CIColor(red: 1, green: 0, blue: 0), forKey: "inputColor")
                        filter?.setValue(1.0, forKey: "inputIntensity")
                        
                        // Add chromatic aberration effect
                        let transform = CGAffineTransform(translationX: 5, y: 0)
                        let transformed = filter?.outputImage?.transformed(by: transform)
                        
                        // Use CIAffineClamp to prevent edge stretching
                        let clampFilter = CIFilter(name: "CIAffineClamp")
                        clampFilter?.setValue(transformed, forKey: kCIInputImageKey)
                        clampFilter?.setValue(CGAffineTransform.identity, forKey: "inputTransform")
                        let clamped = clampFilter?.outputImage
                        
                        let composite = CIFilter(name: "CISourceOverCompositing")
                        composite?.setValue(clamped, forKey: kCIInputImageKey)
                        composite?.setValue(image, forKey: kCIInputBackgroundImageKey)
                        
                        return composite?.outputImage ?? image
                    }
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Shake and zoom effect
    public static func shakeAndZoom(
        duration: TimeInterval = 3.0,
        shakeIntensity: Float = 10.0
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                // Zoom with bounce
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let progress = Float(time.seconds / duration)
                        let bounce = sin(progress * .pi) * 0.1
                        let zoomFactor = 1.0 + progress * 0.4 + bounce
                        
                        let zoomEffect = ZoomEffect(zoomFactor: zoomFactor)
                        return try await zoomEffect.apply(to: image, at: time, renderContext: renderContext)
                    }
                ),
                // Camera shake with time-based intensity
                CameraShakeEffect(intensity: shakeIntensity).animated(
                    with: EffectAnimation(
                        duration: CMTime(seconds: duration, preferredTimescale: 600),
                        keyframes: [
                            Keyframe(time: CMTime.zero, parameters: ["intensity": .float(0)]),
                            Keyframe(time: CMTime(seconds: duration * 0.2, preferredTimescale: 600), parameters: ["intensity": .float(shakeIntensity)]),
                            Keyframe(time: CMTime(seconds: duration * 0.8, preferredTimescale: 600), parameters: ["intensity": .float(shakeIntensity)]),
                            Keyframe(time: CMTime(seconds: duration, preferredTimescale: 600), parameters: ["intensity": .float(0)])
                        ],
                        interpolation: .easeInOut
                    )
                )
            ],
            blendMode: .parallel { image1, image2, renderContext in
                // Apply shake to zoomed image
                return image2
            }
        )
    }
    
    // MARK: - Saliency Zoom Presets
    
    /// Attention-based saliency zoom (focuses on faces and people)
    public static func saliencyAttention(
        duration: TimeInterval = 4.0,
        zoomFactor: Float = 2.0
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaliencyZoomEffect.attentionBased(
                    zoomFactor: zoomFactor,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Object-based saliency zoom (focuses on general objects)
    public static func saliencyObject(
        duration: TimeInterval = 3.0,
        zoomFactor: Float = 1.5
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaliencyZoomEffect.objectBased(
                    zoomFactor: zoomFactor,
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Subtle saliency zoom with minimal movement
    public static func saliencySubtle(
        duration: TimeInterval = 5.0
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaliencyZoomEffect.subtle(
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Dramatic saliency zoom with fast movement
    public static func saliencyDramatic(
        duration: TimeInterval = 2.0
    ) -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaliencyZoomEffect.dramatic(
                    duration: CMTime(seconds: duration, preferredTimescale: 600)
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Saliency zoom combined with color grading
    public static func saliencyWithGrade(
        duration: TimeInterval = 4.0,
        colorGrade: ColorGradeStyle = .vintage,
        saliencyMode: SaliencyMode = .attention
    ) -> CompositeEffect {
        let saliencyEffect: SaliencyZoomEffect
        switch saliencyMode {
        case .attention:
            saliencyEffect = SaliencyZoomEffect.attentionBased(
                zoomFactor: 1.8,
                duration: CMTime(seconds: duration, preferredTimescale: 600)
            )
        case .object:
            saliencyEffect = SaliencyZoomEffect.objectBased(
                zoomFactor: 1.5,
                duration: CMTime(seconds: duration, preferredTimescale: 600)
            )
        }
        
        let gradeEffect: CompositeEffect
        switch colorGrade {
        case .vintage:
            gradeEffect = vintageGrade()
        case .moody:
            gradeEffect = moodyGrade()
        case .bright:
            gradeEffect = brightGrade()
        case .none:
            return CompositeEffect(effects: [saliencyEffect], blendMode: .sequential)
        }
        
        return CompositeEffect(
            effects: [saliencyEffect, gradeEffect],
            blendMode: .sequential
        )
    }
    
    // MARK: - Color Grading Presets
    
    /// Vintage color grading
    public static func vintageGrade() -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaturationEffect(saturation: 0.8),
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let filter = CIFilter(name: "CISepiaTone")
                        filter?.setValue(image, forKey: kCIInputImageKey)
                        filter?.setValue(0.3, forKey: "inputIntensity")
                        return filter?.outputImage ?? image
                    }
                ),
                ContrastEffect(contrast: 1.2),
                BrightnessEffect(brightness: -0.1)
            ],
            blendMode: .sequential
        )
    }
    
    /// Moody color grading
    public static func moodyGrade() -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaturationEffect(saturation: 0.6),
                ContrastEffect(contrast: 1.4),
                BrightnessEffect(brightness: -0.2),
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let filter = CIFilter(name: "CIColorMonochrome")
                        filter?.setValue(image, forKey: kCIInputImageKey)
                        filter?.setValue(CIColor(red: 0.2, green: 0.3, blue: 0.5), forKey: "inputColor")
                        filter?.setValue(0.2, forKey: "inputIntensity")
                        return filter?.outputImage ?? image
                    }
                )
            ],
            blendMode: .sequential
        )
    }
    
    /// Bright and vibrant color grading
    public static func brightGrade() -> CompositeEffect {
        return CompositeEffect(
            effects: [
                SaturationEffect(saturation: 1.3),
                ContrastEffect(contrast: 1.1),
                BrightnessEffect(brightness: 0.1),
                BaseEffect(
                    id: UUID(),
                    parameters: EffectParameters(),
                    apply: { image, time, renderContext in
                        let filter = CIFilter(name: "CIVibrance")
                        filter?.setValue(image, forKey: kCIInputImageKey)
                        filter?.setValue(0.5, forKey: "inputAmount")
                        return filter?.outputImage ?? image
                    }
                )
            ],
            blendMode: .sequential
        )
    }
    
    // MARK: - Combined Presets
    
    /// Cinematic Ken Burns with color grading
    public static func cinematicStory(
        colorGrade: ColorGradeStyle = .vintage,
        duration: TimeInterval = 5.0
    ) -> CompositeEffect {
        let kenBurns = kenBurnsClassic(duration: duration)
        let grading: CompositeEffect
        
        switch colorGrade {
        case .vintage:
            grading = vintageGrade()
        case .moody:
            grading = moodyGrade()
        case .bright:
            grading = brightGrade()
        case .none:
            grading = CompositeEffect(effects: [], blendMode: .sequential)
        }
        
        return CompositeEffect(
            effects: [kenBurns, grading],
            blendMode: .sequential
        )
    }
    
    /// Dynamic intro effect
    public static func dynamicIntro(
        style: IntroStyle = .zoomSpin,
        duration: TimeInterval = 3.0
    ) -> CompositeEffect {
        switch style {
        case .zoomSpin:
            return spinZoomIn(duration: duration)
        case .glitch:
            return glitchZoom(duration: duration)
        case .shake:
            return shakeAndZoom(duration: duration)
        case .pulse:
            return pulseZoom(duration: duration)
        }
    }
    
    // MARK: - Helper Types
    
    public enum ColorGradeStyle {
        case vintage
        case moody
        case bright
        case none
    }
    
    public enum IntroStyle {
        case zoomSpin
        case glitch
        case shake
        case pulse
    }
    
    public enum SaliencyMode {
        case attention
        case object
    }
}

// MARK: - Convenience Extensions

extension CompositeEffect {
    /// Apply a preset effect with custom duration
    public static func preset(
        _ preset: EffectPresets.PresetType,
        duration: TimeInterval? = nil
    ) -> CompositeEffect {
        switch preset {
        case .kenBurnsClassic:
            return EffectPresets.kenBurnsClassic(duration: duration ?? 5.0)
        case .kenBurnsDramatic:
            return EffectPresets.kenBurnsDramatic(duration: duration ?? 3.0)
        case .kenBurnsSubtle:
            return EffectPresets.kenBurnsSubtle(duration: duration ?? 8.0)
        case .spinZoomIn:
            return EffectPresets.spinZoomIn(duration: duration ?? 3.0)
        case .pulseZoom:
            return EffectPresets.pulseZoom(duration: duration ?? 4.0)
        case .letterboxZoom:
            return EffectPresets.letterboxZoom(duration: duration ?? 5.0)
        case .parallaxZoom:
            return EffectPresets.parallaxZoom(duration: duration ?? 4.0)
        case .glitchZoom:
            return EffectPresets.glitchZoom(duration: duration ?? 2.0)
        case .shakeAndZoom:
            return EffectPresets.shakeAndZoom(duration: duration ?? 3.0)
        case .vintageGrade:
            return EffectPresets.vintageGrade()
        case .moodyGrade:
            return EffectPresets.moodyGrade()
        case .brightGrade:
            return EffectPresets.brightGrade()
        case .saliencyAttention:
            return EffectPresets.saliencyAttention(duration: duration ?? 4.0)
        case .saliencyObject:
            return EffectPresets.saliencyObject(duration: duration ?? 3.0)
        case .saliencySubtle:
            return EffectPresets.saliencySubtle(duration: duration ?? 5.0)
        case .saliencyDramatic:
            return EffectPresets.saliencyDramatic(duration: duration ?? 2.0)
        }
    }
}

extension EffectPresets {
    public enum PresetType: String, CaseIterable {
        case kenBurnsClassic
        case kenBurnsDramatic
        case kenBurnsSubtle
        case spinZoomIn
        case pulseZoom
        case letterboxZoom
        case parallaxZoom
        case glitchZoom
        case shakeAndZoom
        case vintageGrade
        case moodyGrade
        case brightGrade
        case saliencyAttention
        case saliencyObject
        case saliencySubtle
        case saliencyDramatic
    }
}