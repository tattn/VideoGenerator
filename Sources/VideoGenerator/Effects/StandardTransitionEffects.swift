import CoreImage
import AVFoundation
import CoreGraphics

// MARK: - Transition Effect Protocol

public protocol TransitionEffect: Sendable {
    func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage
}

// MARK: - Basic Transitions

/// Dissolve transition
public struct DissolveTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let filter = CIFilter(name: "CIDissolveTransition") else {
            return inputImage
        }
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(applyEasing(progress, easing: parameters.easing), forKey: kCIInputTimeKey)
        
        return filter.outputImage ?? inputImage
    }
}

// MARK: - Geometric Transitions

/// Circle expand transition
public struct CircleExpandTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let centerX = extent.midX
        let centerY = extent.midY
        let maxRadius = sqrt(pow(extent.width / 2, 2) + pow(extent.height / 2, 2))
        let radius = maxRadius * CGFloat(easedProgress)
        
        guard let radialGradient = CIFilter(name: "CIRadialGradient") else {
            return inputImage
        }
        
        radialGradient.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
        radialGradient.setValue(radius - 1, forKey: "inputRadius0")
        radialGradient.setValue(radius + 1, forKey: "inputRadius1")
        radialGradient.setValue(CIColor.white, forKey: "inputColor0")
        radialGradient.setValue(CIColor.black, forKey: "inputColor1")
        
        guard let mask = radialGradient.outputImage?.cropped(to: extent) else {
            return inputImage
        }
        
        return outputImage.masked(by: mask).composited(over: inputImage)
    }
}

/// Rectangle expand transition
public struct RectangleExpandTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let centerX = extent.midX
        let centerY = extent.midY
        let width = extent.width * CGFloat(easedProgress)
        let height = extent.height * CGFloat(easedProgress)
        
        let maskRect = CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
        
        let mask = CIImage(color: .white).cropped(to: maskRect)
        
        return outputImage.masked(by: mask).composited(over: inputImage)
    }
}

/// Diamond expand transition
public struct DiamondExpandTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let centerX = extent.midX
        let centerY = extent.midY
        let size = max(extent.width, extent.height) * CGFloat(easedProgress)
        
        // Create diamond shape using affine transform
        let diamond = CIImage(color: .white)
            .cropped(to: CGRect(x: centerX - size/2, y: centerY - size/2, width: size, height: size))
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 4))
        
        let cropRect = CGRect(
            x: centerX - size / sqrt(2),
            y: centerY - size / sqrt(2),
            width: size * sqrt(2),
            height: size * sqrt(2)
        )
        
        let mask = diamond.cropped(to: cropRect).cropped(to: extent)
        
        return outputImage.masked(by: mask).composited(over: inputImage)
    }
}

// MARK: - Blinds Transitions

/// Horizontal blinds transition
public struct BlindsHorizontalTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let blindHeight = extent.height / CGFloat(parameters.segments)
        var result = inputImage
        
        for i in 0..<parameters.segments {
            let y = extent.minY + CGFloat(i) * blindHeight
            let blindProgress = min(1.0, easedProgress * 2.0 - Float(i) / Float(parameters.segments))
            
            if blindProgress > 0 {
                let blindRect = CGRect(x: extent.minX, y: y, width: extent.width, height: blindHeight * CGFloat(blindProgress))
                let mask = CIImage(color: .white).cropped(to: blindRect)
                
                let blindImage = outputImage.cropped(to: CGRect(x: extent.minX, y: y, width: extent.width, height: blindHeight))
                result = blindImage.masked(by: mask).composited(over: result)
            }
        }
        
        return result
    }
}

/// Vertical blinds transition
public struct BlindsVerticalTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let blindWidth = extent.width / CGFloat(parameters.segments)
        var result = inputImage
        
        for i in 0..<parameters.segments {
            let x = extent.minX + CGFloat(i) * blindWidth
            let blindProgress = min(1.0, easedProgress * 2.0 - Float(i) / Float(parameters.segments))
            
            if blindProgress > 0 {
                let blindRect = CGRect(x: x, y: extent.minY, width: blindWidth * CGFloat(blindProgress), height: extent.height)
                let mask = CIImage(color: .white).cropped(to: blindRect)
                
                let blindImage = outputImage.cropped(to: CGRect(x: x, y: extent.minY, width: blindWidth, height: extent.height))
                result = blindImage.masked(by: mask).composited(over: result)
            }
        }
        
        return result
    }
}

// MARK: - Advanced Effects

/// Ripple transition
public struct RippleTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let filter = CIFilter(name: "CIRippleTransition") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        let extent = inputImage.extent
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(easedProgress, forKey: kCIInputTimeKey)
        filter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)
        filter.setValue(extent.width / 2, forKey: kCIInputExtentKey)
        filter.setValue(parameters.intensity * 50, forKey: kCIInputScaleKey)
        filter.setValue(30.0, forKey: kCIInputWidthKey)
        
        return filter.outputImage ?? inputImage
    }
}

/// Swirl transition
public struct SwirlTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let swirlFilter = CIFilter(name: "CITwirlDistortion") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        let extent = inputImage.extent
        
        // Apply swirl to input image
        swirlFilter.setValue(inputImage, forKey: kCIInputImageKey)
        swirlFilter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)
        swirlFilter.setValue(min(extent.width, extent.height) / 2, forKey: kCIInputRadiusKey)
        swirlFilter.setValue(Float(easedProgress) * Float.pi * 2 * Float(parameters.intensity), forKey: kCIInputAngleKey)
        
        let swirlImage = swirlFilter.outputImage ?? inputImage
        
        // Blend with output image
        return swirlImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: outputImage,
            kCIInputTimeKey: easedProgress
        ])
    }
}

/// Pixelate transition
public struct PixelateTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let pixelateFilter = CIFilter(name: "CIPixellate") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        let maxScale = parameters.intensity * 50
        let scale = maxScale * Double(1 - abs(easedProgress - 0.5) * 2)
        
        // Apply pixelation
        pixelateFilter.setValue(inputImage, forKey: kCIInputImageKey)
        pixelateFilter.setValue(CIVector(x: inputImage.extent.midX, y: inputImage.extent.midY), forKey: kCIInputCenterKey)
        pixelateFilter.setValue(max(1, scale), forKey: kCIInputScaleKey)
        
        let pixelatedImage = pixelateFilter.outputImage ?? inputImage
        
        // Blend based on progress
        if easedProgress < 0.5 {
            return pixelatedImage
        } else {
            pixelateFilter.setValue(outputImage, forKey: kCIInputImageKey)
            pixelateFilter.setValue(max(1, scale), forKey: kCIInputScaleKey)
            return pixelateFilter.outputImage ?? outputImage
        }
    }
}

/// Mosaic transition
public struct MosaicTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let tileSize = min(extent.width, extent.height) / CGFloat(parameters.segments)
        var result = inputImage
        
        for row in 0..<parameters.segments {
            for col in 0..<parameters.segments {
                let tileProgress = Float(row * parameters.segments + col) / Float(parameters.segments * parameters.segments)
                
                if easedProgress > tileProgress {
                    let x = extent.minX + CGFloat(col) * tileSize
                    let y = extent.minY + CGFloat(row) * tileSize
                    let tileRect = CGRect(x: x, y: y, width: tileSize, height: tileSize)
                    
                    let tile = outputImage.cropped(to: tileRect)
                    result = tile.composited(over: result)
                }
            }
        }
        
        return result
    }
}

/// Kaleidoscope transition
public struct KaleidoscopeTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let kaleidoscopeFilter = CIFilter(name: "CIKaleidoscope") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        let extent = inputImage.extent
        
        // Apply kaleidoscope effect
        kaleidoscopeFilter.setValue(inputImage, forKey: kCIInputImageKey)
        kaleidoscopeFilter.setValue(CIVector(x: extent.midX, y: extent.midY), forKey: kCIInputCenterKey)
        kaleidoscopeFilter.setValue(6 + Int(parameters.intensity * 6), forKey: "inputCount")
        kaleidoscopeFilter.setValue(easedProgress * .pi * 2, forKey: kCIInputAngleKey)
        
        let kaleidoscopeImage = kaleidoscopeFilter.outputImage ?? inputImage
        
        // Blend with output
        return kaleidoscopeImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: outputImage,
            kCIInputTimeKey: easedProgress
        ])
    }
}

/// Glitch transition
public struct GlitchTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        var result = inputImage
        
        // Create glitch slices
        let sliceCount = Int(parameters.intensity * 20) + 5
        
        for _ in 0..<sliceCount {
            let randomOffset = CGFloat.random(in: -50...50) * CGFloat(1 - abs(easedProgress - 0.5) * 2)
            let sliceY = CGFloat.random(in: 0...1) * extent.height + extent.minY
            let sliceHeight = CGFloat.random(in: 5...50)
            
            let sliceRect = CGRect(x: extent.minX + randomOffset, y: sliceY, width: extent.width, height: sliceHeight)
            
            let sourceImage = easedProgress < 0.5 ? inputImage : outputImage
            let slice = sourceImage.cropped(to: sliceRect)
            
            result = slice.composited(over: result)
        }
        
        // Add color shift
        if let colorMatrixFilter = CIFilter(name: "CIColorMatrix") {
            let shift = CGFloat(1 - abs(easedProgress - 0.5) * 2) * 0.1
            
            colorMatrixFilter.setValue(result, forKey: kCIInputImageKey)
            colorMatrixFilter.setValue(CIVector(x: 1 + shift, y: 0, z: 0, w: 0), forKey: "inputRVector")
            colorMatrixFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 1 - shift, w: 0), forKey: "inputBVector")
            
            result = colorMatrixFilter.outputImage ?? result
        }
        
        // Final blend
        if easedProgress > 0.5 {
            return outputImage.applyingFilter("CIDissolveTransition", parameters: [
                kCIInputTargetImageKey: result,
                kCIInputTimeKey: (easedProgress - 0.5) * 2
            ])
        }
        
        return result
    }
}

// MARK: - Slide Transitions

/// Slide transition with push effect
public struct SlidePushTransitionEffect: TransitionEffect {
    public enum Direction: Sendable {
        case left, right, up, down
    }
    
    private let direction: Direction
    
    public init(direction: Direction) {
        self.direction = direction
    }
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        var inputTransform: CGAffineTransform
        var outputTransform: CGAffineTransform
        
        switch direction {
        case .left:
            let offset = extent.width * CGFloat(easedProgress)
            inputTransform = CGAffineTransform(translationX: -offset, y: 0)
            outputTransform = CGAffineTransform(translationX: extent.width - offset, y: 0)
        case .right:
            let offset = extent.width * CGFloat(easedProgress)
            inputTransform = CGAffineTransform(translationX: offset, y: 0)
            outputTransform = CGAffineTransform(translationX: -extent.width + offset, y: 0)
        case .up:
            let offset = extent.height * CGFloat(easedProgress)
            inputTransform = CGAffineTransform(translationX: 0, y: -offset)
            outputTransform = CGAffineTransform(translationX: 0, y: extent.height - offset)
        case .down:
            let offset = extent.height * CGFloat(easedProgress)
            inputTransform = CGAffineTransform(translationX: 0, y: offset)
            outputTransform = CGAffineTransform(translationX: 0, y: -extent.height + offset)
        }
        
        let transformedInput = inputImage.transformed(by: inputTransform).cropped(to: extent)
        let transformedOutput = outputImage.transformed(by: outputTransform).cropped(to: extent)
        
        return transformedOutput.composited(over: transformedInput)
    }
}

// MARK: - Special Effects

/// Burn transition effect
public struct BurnTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        // Create burn edge
        let burnWidth: CGFloat = 50
        let burnPosition = extent.width * CGFloat(easedProgress)
        
        // Create gradient for burn edge
        guard let gradientFilter = CIFilter(name: "CILinearGradient") else {
            return inputImage
        }
        
        gradientFilter.setValue(CIVector(x: burnPosition - burnWidth, y: extent.midY), forKey: "inputPoint0")
        gradientFilter.setValue(CIVector(x: burnPosition + burnWidth, y: extent.midY), forKey: "inputPoint1")
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor.white, forKey: "inputColor1")
        
        guard let burnMask = gradientFilter.outputImage?.cropped(to: extent) else {
            return inputImage
        }
        
        // Create orange burn edge
        let burnEdgeRect = CGRect(x: burnPosition - burnWidth/2, y: extent.minY, width: burnWidth, height: extent.height)
        let burnEdge = CIImage(color: CIColor(red: 1, green: 0.5, blue: 0, alpha: 1)).cropped(to: burnEdgeRect)
        
        // Composite everything
        let burnedInput = inputImage.masked(by: burnMask)
        let result = outputImage.composited(over: burnedInput)
        
        // Add burn edge effect when in transition
        if easedProgress > 0.1 && easedProgress < 0.9 {
            return burnEdge.composited(over: result)
        }
        
        return result
    }
}

/// Page flip transition
public struct PageFlipTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let filter = CIFilter(name: "CIPageCurlTransition") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        let extent = inputImage.extent
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(easedProgress, forKey: kCIInputTimeKey)
        filter.setValue(CIVector(x: extent.minX, y: extent.minY), forKey: "inputBottomLeft")
        filter.setValue(CIVector(x: extent.maxX, y: extent.minY), forKey: "inputBottomRight")
        filter.setValue(CIVector(x: extent.minX, y: extent.maxY), forKey: "inputTopLeft")
        filter.setValue(CIVector(x: extent.maxX, y: extent.maxY), forKey: "inputTopRight")
        filter.setValue(parameters.angle * .pi / 180, forKey: kCIInputAngleKey)
        
        return filter.outputImage ?? inputImage
    }
}

/// Radial wipe transition
public struct RadialWipeTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        guard let filter = CIFilter(name: "CISwipeTransition") else {
            return inputImage
        }
        
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(easedProgress, forKey: kCIInputTimeKey)
        filter.setValue(parameters.angle * .pi / 180, forKey: kCIInputAngleKey)
        filter.setValue(300.0, forKey: kCIInputWidthKey)
        filter.setValue(1.0, forKey: "inputOpacity")
        
        return filter.outputImage ?? inputImage
    }
}

/// Diagonal wipe transition
public struct DiagonalWipeTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        let angle = parameters.angle * .pi / 180
        let distance = (extent.width + extent.height) * CGFloat(easedProgress)
        
        guard let gradientFilter = CIFilter(name: "CILinearGradient") else {
            return inputImage
        }
        
        let point0 = CIVector(x: extent.minX - cos(angle) * distance, y: extent.minY - sin(angle) * distance)
        let point1 = CIVector(x: extent.minX - cos(angle) * distance + 100, y: extent.minY - sin(angle) * distance + 100)
        
        gradientFilter.setValue(point0, forKey: "inputPoint0")
        gradientFilter.setValue(point1, forKey: "inputPoint1")
        gradientFilter.setValue(CIColor.black, forKey: "inputColor0")
        gradientFilter.setValue(CIColor.white, forKey: "inputColor1")
        
        guard let mask = gradientFilter.outputImage?.cropped(to: extent) else {
            return inputImage
        }
        
        return outputImage.masked(by: mask).composited(over: inputImage)
    }
}

/// Shatter transition effect
public struct ShatterTransitionEffect: TransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) -> CIImage {
        let extent = inputImage.extent
        let easedProgress = applyEasing(progress, easing: parameters.easing)
        
        // Create shatter pieces
        let pieceSize = min(extent.width, extent.height) / CGFloat(parameters.segments)
        var result = outputImage
        
        for row in 0..<parameters.segments {
            for col in 0..<parameters.segments {
                let x = extent.minX + CGFloat(col) * pieceSize
                let y = extent.minY + CGFloat(row) * pieceSize
                let pieceRect = CGRect(x: x, y: y, width: pieceSize, height: pieceSize)
                
                // Calculate displacement for each piece
                let centerOffset = CGPoint(
                    x: (x + pieceSize/2) - extent.midX,
                    y: (y + pieceSize/2) - extent.midY
                )
                
                let distance = sqrt(centerOffset.x * centerOffset.x + centerOffset.y * centerOffset.y)
                let maxDistance = sqrt(pow(extent.width/2, 2) + pow(extent.height/2, 2))
                let normalizedDistance = distance / maxDistance
                
                // Pieces fall away based on distance from center
                let pieceProgress = max(0, easedProgress - Float(normalizedDistance) * 0.5)
                
                if pieceProgress < 1 {
                    let displacement = CGFloat(pieceProgress) * 500 * parameters.intensity
                    let rotation = CGFloat(pieceProgress) * .pi * 2
                    
                    let transform = CGAffineTransform(translationX: centerOffset.x * displacement / distance, y: centerOffset.y * displacement / distance + displacement)
                        .rotated(by: rotation)
                    
                    let piece = inputImage.cropped(to: pieceRect).transformed(by: transform)
                    result = piece.composited(over: result)
                }
            }
        }
        
        return result
    }
}

// MARK: - Helper Functions

private func applyEasing(_ progress: Float, easing: TransitionEasing) -> Float {
    switch easing {
    case .linear:
        return progress
    case .easeIn:
        return progress * progress
    case .easeOut:
        return progress * (2 - progress)
    case .easeInOut:
        return progress < 0.5 ? 2 * progress * progress : -1 + (4 - 2 * progress) * progress
    case .easeInQuad:
        return progress * progress
    case .easeOutQuad:
        return progress * (2 - progress)
    case .easeInOutQuad:
        return progress < 0.5 ? 2 * progress * progress : -1 + (4 - 2 * progress) * progress
    case .easeInCubic:
        return progress * progress * progress
    case .easeOutCubic:
        let p = progress - 1
        return p * p * p + 1
    case .easeInOutCubic:
        return progress < 0.5 ? 4 * progress * progress * progress : (progress - 1) * (2 * progress - 2) * (2 * progress - 2) + 1
    case .easeInQuart:
        return progress * progress * progress * progress
    case .easeOutQuart:
        let p = progress - 1
        return 1 - p * p * p * p
    case .easeInOutQuart:
        return progress < 0.5 ? 8 * progress * progress * progress * progress : 1 - pow(-2 * progress + 2, 4) / 2
    case .easeInExpo:
        return progress == 0 ? 0 : pow(2, 10 * progress - 10)
    case .easeOutExpo:
        return progress == 1 ? 1 : 1 - pow(2, -10 * progress)
    case .easeInOutExpo:
        if progress == 0 { return 0 }
        if progress == 1 { return 1 }
        return progress < 0.5 ? pow(2, 20 * progress - 10) / 2 : (2 - pow(2, -20 * progress + 10)) / 2
    case .easeInCirc:
        return 1 - sqrt(1 - progress * progress)
    case .easeOutCirc:
        return sqrt(1 - pow(progress - 1, 2))
    case .easeInOutCirc:
        return progress < 0.5 ? (1 - sqrt(1 - pow(2 * progress, 2))) / 2 : (sqrt(1 - pow(-2 * progress + 2, 2)) + 1) / 2
    case .easeInBack:
        let c1: Float = 1.70158
        let c3 = c1 + 1
        return c3 * progress * progress * progress - c1 * progress * progress
    case .easeOutBack:
        let c1: Float = 1.70158
        let c3 = c1 + 1
        let p = progress - 1
        return 1 + c3 * p * p * p + c1 * p * p
    case .easeInOutBack:
        let c1: Float = 1.70158
        let c2 = c1 * 1.525
        return progress < 0.5
            ? (pow(2 * progress, 2) * ((c2 + 1) * 2 * progress - c2)) / 2
            : (pow(2 * progress - 2, 2) * ((c2 + 1) * (progress * 2 - 2) + c2) + 2) / 2
    case .easeInElastic:
        if progress == 0 { return 0 }
        if progress == 1 { return 1 }
        let c4 = (2 * Float.pi) / 3
        return -pow(2, 10 * progress - 10) * sin((progress * 10 - 10.75) * c4)
    case .easeOutElastic:
        if progress == 0 { return 0 }
        if progress == 1 { return 1 }
        let c4 = (2 * Float.pi) / 3
        return pow(2, -10 * progress) * sin((progress * 10 - 0.75) * c4) + 1
    case .easeInOutElastic:
        if progress == 0 { return 0 }
        if progress == 1 { return 1 }
        let c5 = (2 * Float.pi) / 4.5
        return progress < 0.5
            ? -(pow(2, 20 * progress - 10) * sin((20 * progress - 11.125) * c5)) / 2
            : (pow(2, -20 * progress + 10) * sin((20 * progress - 11.125) * c5)) / 2 + 1
    case .bounce:
        return bounceEaseOut(progress)
    }
}

private func bounceEaseOut(_ t: Float) -> Float {
    let n1: Float = 7.5625
    let d1: Float = 2.75
    
    if t < 1 / d1 {
        return n1 * t * t
    } else if t < 2 / d1 {
        let t2 = t - 1.5 / d1
        return n1 * t2 * t2 + 0.75
    } else if t < 2.5 / d1 {
        let t2 = t - 2.25 / d1
        return n1 * t2 * t2 + 0.9375
    } else {
        let t2 = t - 2.625 / d1
        return n1 * t2 * t2 + 0.984375
    }
}

// MARK: - CIImage Extensions

extension CIImage {
    func masked(by mask: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIBlendWithMask") else {
            return self
        }
        
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(CIImage(color: .clear).cropped(to: extent), forKey: kCIInputBackgroundImageKey)
        filter.setValue(mask, forKey: kCIInputMaskImageKey)
        
        return filter.outputImage ?? self
    }
}