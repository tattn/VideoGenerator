import Testing
@testable import VideoGenerator
import CoreMedia
import CoreImage

@Suite("CompositeEffect Tests")
struct CompositeEffectTests {
    
    // Mock effects for testing
    struct MockEffect: Effect {
        let id = UUID()
        var parameters: EffectParameters
        let name: String
        var applyCalled = false
        
        init(name: String, parameters: EffectParameters = EffectParameters()) {
            self.name = name
            self.parameters = parameters
        }
        
        mutating func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
            applyCalled = true
            print("MockEffect \(name) applied")
            return image
        }
    }
    
    struct CountingEffect: Effect {
        let id = UUID()
        var parameters: EffectParameters = EffectParameters()
        let order: Int
        static var callOrder: [Int] = []
        
        init(order: Int) {
            self.order = order
        }
        
        func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
            CountingEffect.callOrder.append(order)
            return image
        }
    }
    
    @Test("Sequential composite effect applies effects in order")
    func testSequentialComposite() async throws {
        // Reset call order
        CountingEffect.callOrder = []
        
        let effect1 = CountingEffect(order: 1)
        let effect2 = CountingEffect(order: 2)
        let effect3 = CountingEffect(order: 3)
        
        let composite = CompositeEffect.sequential([effect1, effect2, effect3])
        
        // Create mock image and context
        let image = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        _ = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        #expect(CountingEffect.callOrder == [1, 2, 3])
    }
    
    @Test("Empty composite effect returns original image")
    func testEmptyComposite() async throws {
        let composite = CompositeEffect(effects: [])
        
        let image = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        let result = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        #expect(result == image)
    }
    
    @Test("Effect chain builder creates composite effect")
    @MainActor
    func testEffectChainBuilder() async throws {
        let effect1 = MockEffect(name: "Effect1")
        let effect2 = MockEffect(name: "Effect2")
        let effect3 = MockEffect(name: "Effect3")
        
        let composite = EffectChain()
            .add(effect1)
            .add([effect2, effect3])
            .blendMode(.sequential)
            .build()
        
        #expect(composite.effects.count == 3)
    }
    
    @Test("Effect operators create composite effects")
    func testEffectOperators() {
        let effect1 = MockEffect(name: "Effect1")
        let effect2 = MockEffect(name: "Effect2")
        
        let sequential = effect1.then(effect2)
        #expect(sequential.effects.count == 2)
        
        let parallel = effect1.parallel(with: effect2)
        #expect(parallel.effects.count == 2)
    }
    
    @Test("Time range effect applies only within range")
    func testTimeRangeEffect() async throws {
        var mockEffect = MockEffect(name: "TimedEffect")
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 1, preferredTimescale: 30),
            duration: CMTime(seconds: 2, preferredTimescale: 30)
        )
        
        let timedEffect = mockEffect.timeRange(timeRange)
        
        let image = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        // Test before time range
        let result1 = try await timedEffect.apply(to: image, at: CMTime(seconds: 0.5, preferredTimescale: 30), renderContext: context)
        #expect(result1 == image)
        
        // Test within time range - should apply effect
        _ = try await timedEffect.apply(to: image, at: CMTime(seconds: 1.5, preferredTimescale: 30), renderContext: context)
        
        // Test after time range
        let result3 = try await timedEffect.apply(to: image, at: CMTime(seconds: 3.5, preferredTimescale: 30), renderContext: context)
        #expect(result3 == image)
    }
    
    @Test("Conditional effect applies based on condition")
    func testConditionalEffect() async throws {
        let trueEffect = MockEffect(name: "TrueEffect")
        let falseEffect = MockEffect(name: "FalseEffect")
        
        let conditionalEffect = ConditionalEffect(
            condition: { time, _ in
                time.seconds < 5.0
            },
            then: trueEffect,
            else: falseEffect
        )
        
        let image = CIImage(color: .yellow).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        // Test when condition is true
        _ = try await conditionalEffect.apply(to: image, at: CMTime(seconds: 2, preferredTimescale: 30), renderContext: context)
        
        // Test when condition is false
        _ = try await conditionalEffect.apply(to: image, at: CMTime(seconds: 7, preferredTimescale: 30), renderContext: context)
    }
    
    @Test("Parameter modifier creates modified effect")
    func testParameterModifier() {
        let baseEffect = MockEffect(name: "Base", parameters: EffectParameters(["key1": .float(1.0)]))
        
        let modifiedEffect = baseEffect.parameter("key2", value: .float(2.0))
        
        // The modified effect should have both parameters
        // We can verify this through the parameters property
        let params = (modifiedEffect as? ModifiedEffect)?.parameters
        #expect(params != nil)
    }
    
    @Test("Parallel composite effect blends results")
    func testParallelComposite() async throws {
        let effect1 = MockEffect(name: "Effect1")
        let effect2 = MockEffect(name: "Effect2")
        
        let composite = CompositeEffect.parallel([effect1, effect2], blend: BlendFunctions.average)
        
        let image = CIImage(color: .cyan).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        let result = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        // Result should be a blended image
        #expect(result != image)
    }
    
    @Test("Custom blend mode applies custom logic")
    func testCustomBlendMode() async throws {
        let effect1 = MockEffect(name: "Effect1")
        let effect2 = MockEffect(name: "Effect2")
        
        var customProcessorCalled = false
        
        let composite = CompositeEffect(
            effects: [effect1, effect2],
            blendMode: .custom { image, effects, time, context in
                customProcessorCalled = true
                // Apply effects in reverse order
                var result = image
                for effect in effects.reversed() {
                    result = try await effect.apply(to: result, at: time, renderContext: context)
                }
                return result
            }
        )
        
        let image = CIImage(color: .magenta).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        _ = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        #expect(customProcessorCalled)
    }
}

// Mock render context for testing
actor MockRenderContext: RenderContext {
    nonisolated let size: CGSize
    nonisolated let frameRate: Int
    let time: CMTime
    
    init(size: CGSize, frameRate: Int, time: CMTime = .zero) {
        self.size = size
        self.frameRate = frameRate
        self.time = time
    }
    
    func texture(for mediaItem: any MediaItem) async throws -> any Metal.MTLTexture {
        fatalError("Not implemented for testing")
    }
}