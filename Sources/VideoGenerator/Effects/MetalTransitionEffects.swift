import Metal
import MetalKit
import CoreImage
import AVFoundation

/// Protocol for Metal-based transition effects
public protocol MetalTransitionEffect: Sendable {
    func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) throws -> CIImage
}

/// Metal transition effect processor
public actor MetalTransitionProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VideoGeneratorError.metalNotAvailable
        }
        
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            throw VideoGeneratorError.metalResourceCreationFailed
        }
        
        self.commandQueue = commandQueue
        
        // Create library from source
        let source = metalShaderSource
        
        do {
            self.library = try device.makeLibrary(source: source, options: nil)
        } catch {
            throw VideoGeneratorError.metalResourceCreationFailed
        }
        
        // Pipeline states will be created lazily when needed
    }
    
    private func createPipelineStates() throws {
        let shaderNames = [
            "waveTransition",
            "twistTransition",
            "zoomBlurTransition",
            "morphTransition",
            "displaceTransition",
            "liquidTransition"
        ]
        
        for shaderName in shaderNames {
            guard let function = library.makeFunction(name: shaderName) else {
                continue
            }
            
            let pipelineState = try device.makeComputePipelineState(function: function)
            computePipelineStates[shaderName] = pipelineState
        }
    }
    
    public func applyTransition(
        type: TransitionType,
        inputImage: CIImage,
        outputImage: CIImage,
        progress: Float,
        parameters: TransitionParameters
    ) throws -> CIImage {
        
        // Create pipeline states if not already created
        if computePipelineStates.isEmpty {
            try createPipelineStates()
        }
        
        let shaderName: String
        switch type {
        case .metalWave:
            shaderName = "waveTransition"
        case .metalTwist:
            shaderName = "twistTransition"
        case .metalZoom:
            shaderName = "zoomBlurTransition"
        case .metalMorph:
            shaderName = "morphTransition"
        case .metalDisplace:
            shaderName = "displaceTransition"
        case .metalLiquid:
            shaderName = "liquidTransition"
        default:
            // Return input image for non-metal transitions
            return inputImage
        }
        
        guard let pipelineState = computePipelineStates[shaderName] else {
            return inputImage
        }
        
        // Create textures from CIImages
        let context = CIContext(mtlDevice: device)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(inputImage.extent.width),
            height: Int(inputImage.extent.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let inputTexture = device.makeTexture(descriptor: textureDescriptor),
              let outputTexture = device.makeTexture(descriptor: textureDescriptor),
              let resultTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw VideoGeneratorError.textureCreationFailed
        }
        
        // Render CIImages to textures
        context.render(inputImage, to: inputTexture, commandBuffer: nil, bounds: inputImage.extent, colorSpace: colorSpace)
        context.render(outputImage, to: outputTexture, commandBuffer: nil, bounds: outputImage.extent, colorSpace: colorSpace)
        
        // Create command buffer and encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw VideoGeneratorError.metalResourceCreationFailed
        }
        
        // Set up compute encoder
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)
        computeEncoder.setTexture(resultTexture, index: 2)
        
        // Set parameters
        var params = TransitionUniforms(
            progress: progress,
            intensity: Float(parameters.intensity),
            angle: Float(parameters.angle * .pi / 180),
            segments: Float(parameters.segments),
            distortion: Float(parameters.distortionAmount)
        )
        
        computeEncoder.setBytes(&params, length: MemoryLayout<TransitionUniforms>.size, index: 0)
        
        // Calculate thread groups
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Convert result texture back to CIImage
        return CIImage(mtlTexture: resultTexture, options: [.colorSpace: colorSpace])!
    }
}

// MARK: - Shader Uniforms

private struct TransitionUniforms {
    let progress: Float
    let intensity: Float
    let angle: Float
    let segments: Float
    let distortion: Float
}

// MARK: - Metal Shader Source

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct TransitionUniforms {
    float progress;
    float intensity;
    float angle;
    float segments;
    float distortion;
};

// Wave transition
kernel void waveTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    
    float wave = sin(uv.y * 20.0 + uniforms.progress * 10.0) * 0.05 * uniforms.intensity;
    float threshold = uniforms.progress + wave;
    
    float4 color1 = inputTexture.read(gid);
    float4 color2 = outputTexture.read(gid);
    
    float4 result = mix(color1, color2, smoothstep(threshold - 0.05, threshold + 0.05, uv.x));
    resultTexture.write(result, gid);
}

// Twist transition
kernel void twistTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    float2 center = float2(0.5, 0.5);
    
    float2 offset = uv - center;
    float distance = length(offset);
    float angle = uniforms.progress * 6.28318 * uniforms.intensity;
    
    float cosA = cos(angle * distance);
    float sinA = sin(angle * distance);
    
    float2 twisted = float2(
        offset.x * cosA - offset.y * sinA,
        offset.x * sinA + offset.y * cosA
    ) + center;
    
    uint2 twistedCoord = uint2(twisted * size);
    twistedCoord = clamp(twistedCoord, uint2(0), uint2(size) - 1);
    
    float4 color1 = inputTexture.read(twistedCoord);
    float4 color2 = outputTexture.read(gid);
    
    float4 result = mix(color1, color2, uniforms.progress);
    resultTexture.write(result, gid);
}

// Zoom blur transition
kernel void zoomBlurTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    float2 center = float2(0.5, 0.5);
    
    float4 color1 = float4(0.0);
    float4 color2 = float4(0.0);
    
    int samples = 10;
    float scale = uniforms.progress * uniforms.intensity * 0.1;
    
    for (int i = 0; i < samples; i++) {
        float factor = float(i) / float(samples - 1);
        float2 offset = (uv - center) * factor * scale;
        float2 sampleUV = uv - offset;
        
        uint2 sampleCoord = uint2(sampleUV * size);
        sampleCoord = clamp(sampleCoord, uint2(0), uint2(size) - 1);
        
        color1 += inputTexture.read(sampleCoord);
        color2 += outputTexture.read(sampleCoord);
    }
    
    color1 /= float(samples);
    color2 /= float(samples);
    
    float4 result = mix(color1, color2, uniforms.progress);
    resultTexture.write(result, gid);
}

// Morph transition
kernel void morphTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    
    float morphAmount = uniforms.progress;
    float2 morphed = uv;
    
    // Create interesting morph pattern
    morphed.x += sin(uv.y * 10.0 + morphAmount * 5.0) * 0.1 * uniforms.intensity * (1.0 - morphAmount);
    morphed.y += cos(uv.x * 10.0 + morphAmount * 5.0) * 0.1 * uniforms.intensity * (1.0 - morphAmount);
    
    uint2 morphedCoord = uint2(morphed * size);
    morphedCoord = clamp(morphedCoord, uint2(0), uint2(size) - 1);
    
    float4 color1 = inputTexture.read(morphedCoord);
    float4 color2 = outputTexture.read(gid);
    
    float4 result = mix(color1, color2, smoothstep(0.0, 1.0, morphAmount));
    resultTexture.write(result, gid);
}

// Displace transition
kernel void displaceTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    
    // Create displacement map based on progress
    float displaceX = sin(uv.y * 20.0) * uniforms.distortion * 0.1;
    float displaceY = cos(uv.x * 20.0) * uniforms.distortion * 0.1;
    
    float2 displacedUV1 = uv + float2(displaceX, displaceY) * (1.0 - uniforms.progress);
    float2 displacedUV2 = uv - float2(displaceX, displaceY) * uniforms.progress;
    
    uint2 coord1 = uint2(displacedUV1 * size);
    uint2 coord2 = uint2(displacedUV2 * size);
    
    coord1 = clamp(coord1, uint2(0), uint2(size) - 1);
    coord2 = clamp(coord2, uint2(0), uint2(size) - 1);
    
    float4 color1 = inputTexture.read(coord1);
    float4 color2 = outputTexture.read(coord2);
    
    float4 result = mix(color1, color2, uniforms.progress);
    resultTexture.write(result, gid);
}

// Liquid transition
kernel void liquidTransition(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> outputTexture [[texture(1)]],
    texture2d<float, access::write> resultTexture [[texture(2)]],
    constant TransitionUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 uv = float2(gid) / size;
    
    // Create liquid-like distortion
    float time = uniforms.progress * 3.14159;
    float2 distortion;
    distortion.x = sin(time + uv.y * 10.0) * 0.05 * uniforms.intensity;
    distortion.y = cos(time + uv.x * 10.0) * 0.05 * uniforms.intensity;
    
    float2 distortedUV = uv + distortion * (1.0 - abs(uniforms.progress - 0.5) * 2.0);
    
    uint2 distortedCoord = uint2(distortedUV * size);
    distortedCoord = clamp(distortedCoord, uint2(0), uint2(size) - 1);
    
    float4 color1 = inputTexture.read(gid);
    float4 color2 = outputTexture.read(gid);
    
    // Liquid threshold
    float threshold = uniforms.progress + sin(uv.x * 20.0 + time) * 0.1;
    float blend = smoothstep(threshold - 0.1, threshold + 0.1, uv.y + distortion.y);
    
    float4 result = mix(color1, color2, blend);
    resultTexture.write(result, gid);
}
"""

// MARK: - Standard Transition Effects

/// Fade transition effect implementation
public struct FadeTransitionEffect: MetalTransitionEffect {
    public init() {}
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) throws -> CIImage {
        let filter = CIFilter(name: "CIDissolveTransition")!
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(progress, forKey: kCIInputTimeKey)
        return filter.outputImage!
    }
}

/// Wipe transition effect implementation
public struct WipeTransitionEffect: MetalTransitionEffect {
    public enum Direction: Sendable {
        case left, right, up, down
    }
    
    private let direction: Direction
    
    public init(direction: Direction) {
        self.direction = direction
    }
    
    public func apply(inputImage: CIImage, outputImage: CIImage, progress: Float, parameters: TransitionParameters) throws -> CIImage {
        let extent = inputImage.extent
        
        var angle: CGFloat
        var width: CGFloat
        var center: CIVector
        
        switch direction {
        case .left:
            angle = 0
            width = extent.width
            center = CIVector(x: extent.minX + width * CGFloat(progress), y: extent.midY)
        case .right:
            angle = .pi
            width = extent.width
            center = CIVector(x: extent.maxX - width * CGFloat(progress), y: extent.midY)
        case .up:
            angle = .pi / 2
            width = extent.height
            center = CIVector(x: extent.midX, y: extent.minY + width * CGFloat(progress))
        case .down:
            angle = -.pi / 2
            width = extent.height
            center = CIVector(x: extent.midX, y: extent.maxY - width * CGFloat(progress))
        }
        
        let filter = CIFilter(name: "CICopyMachineTransition")!
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(outputImage, forKey: kCIInputTargetImageKey)
        filter.setValue(center, forKey: kCIInputCenterKey)
        filter.setValue(CIVector(x: width, y: 0), forKey: kCIInputExtentKey)
        filter.setValue(NSNumber(value: angle), forKey: kCIInputAngleKey)
        filter.setValue(progress, forKey: kCIInputTimeKey)
        filter.setValue(1.0, forKey: kCIInputWidthKey)
        filter.setValue(0.0, forKey: "inputOpacity")
        
        return filter.outputImage!
    }
}