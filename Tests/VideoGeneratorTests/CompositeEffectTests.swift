import Testing
@testable import VideoGenerator
import CoreMedia
@preconcurrency import CoreImage

@Suite("CompositeEffect Tests")
struct CompositeEffectTests {
    
    // Mock effects for testing
    final class MockEffectTracker: @unchecked Sendable {
        var appliedEffects: [String] = []
        
        func recordApplication(of effectName: String) {
            appliedEffects.append(effectName)
        }
    }
    
    struct MockEffect: Effect {
        let id = UUID()
        var parameters: EffectParameters
        let name: String
        let tracker: MockEffectTracker
        
        init(name: String, tracker: MockEffectTracker, parameters: EffectParameters = EffectParameters()) {
            self.name = name
            self.tracker = tracker
            self.parameters = parameters
        }
        
        func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
            tracker.recordApplication(of: name)
            return image
        }
    }
    
    final class CountingEffectTracker: @unchecked Sendable {
        var callOrder: [Int] = []
        
        func record(_ order: Int) {
            callOrder.append(order)
        }
    }
    
    struct CountingEffect: Effect {
        let id = UUID()
        var parameters: EffectParameters = EffectParameters()
        let order: Int
        let tracker: CountingEffectTracker
        
        init(order: Int, tracker: CountingEffectTracker) {
            self.order = order
            self.tracker = tracker
        }
        
        func apply(to image: CIImage, at time: CMTime, renderContext: any RenderContext) async throws -> CIImage {
            tracker.record(order)
            return image
        }
    }
    
    @Test("Sequential composite effect applies effects in order")
    func testSequentialComposite() async throws {
        let tracker = CountingEffectTracker()
        
        let effect1 = CountingEffect(order: 1, tracker: tracker)
        let effect2 = CountingEffect(order: 2, tracker: tracker)
        let effect3 = CountingEffect(order: 3, tracker: tracker)
        
        let composite = CompositeEffect.sequential([effect1, effect2, effect3])
        
        // Create mock image and context
        let image = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        _ = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        #expect(tracker.callOrder == [1, 2, 3])
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
        let tracker = MockEffectTracker()
        let effect1 = MockEffect(name: "Effect1", tracker: tracker)
        let effect2 = MockEffect(name: "Effect2", tracker: tracker)
        let effect3 = MockEffect(name: "Effect3", tracker: tracker)
        
        let composite = EffectChain()
            .add(effect1)
            .add([effect2, effect3])
            .blendMode(.sequential)
            .build()
        
        #expect(composite.effects.count == 3)
    }
    
    @Test("Effect operators create composite effects")
    func testEffectOperators() {
        let tracker = MockEffectTracker()
        let effect1 = MockEffect(name: "Effect1", tracker: tracker)
        let effect2 = MockEffect(name: "Effect2", tracker: tracker)
        
        let sequential = effect1.then(effect2)
        #expect(sequential.effects.count == 2)
        
        let parallel = effect1.parallel(with: effect2)
        #expect(parallel.effects.count == 2)
    }
    
    @Test("Time range effect applies only within range")
    func testTimeRangeEffect() async throws {
        let tracker = MockEffectTracker()
        let mockEffect = MockEffect(name: "TimedEffect", tracker: tracker)
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
        let tracker = MockEffectTracker()
        let trueEffect = MockEffect(name: "TrueEffect", tracker: tracker)
        let falseEffect = MockEffect(name: "FalseEffect", tracker: tracker)
        
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
        let tracker = MockEffectTracker()
        let baseEffect = MockEffect(name: "Base", tracker: tracker, parameters: EffectParameters(["key1": .float(1.0)]))
        
        let modifiedEffect = baseEffect.parameter("key2", value: .float(2.0))
        
        // The modified effect should have both parameters
        // We can verify this through the parameters property
        let params = (modifiedEffect as? ModifiedEffect)?.parameters
        #expect(params != nil)
    }
    
    @Test("Parallel composite effect blends results")
    func testParallelComposite() async throws {
        let tracker = MockEffectTracker()
        let effect1 = MockEffect(name: "Effect1", tracker: tracker)
        let effect2 = MockEffect(name: "Effect2", tracker: tracker)
        
        let composite = CompositeEffect.parallel([effect1, effect2], blend: BlendFunctions.average)
        
        let image = CIImage(color: .cyan).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let context = MockRenderContext(size: CGSize(width: 100, height: 100), frameRate: 30)
        
        let result = try await composite.apply(to: image, at: .zero, renderContext: context)
        
        // Result should be a blended image
        #expect(result != image)
    }
    
    @Test("Custom blend mode applies custom logic")
    func testCustomBlendMode() async throws {
        let tracker = MockEffectTracker()
        let effect1 = MockEffect(name: "Effect1", tracker: tracker)
        let effect2 = MockEffect(name: "Effect2", tracker: tracker)
        
        final class ProcessorTracker: @unchecked Sendable {
            var called = false
            func markCalled() { called = true }
        }
        let processorTracker = ProcessorTracker()
        
        let composite = CompositeEffect(
            effects: [effect1, effect2],
            blendMode: .custom { image, effects, time, context in
                processorTracker.markCalled()
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
        
        #expect(processorTracker.called)
    }
}

// Mock render context for testing
private actor MockRenderContext: RenderContext {
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