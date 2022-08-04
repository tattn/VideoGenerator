//
//  PerlinNoiseEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import CoreGraphics
import GameKit

public struct PerlinNoiseEffect: VideoEffect {
    let offsets: [CGPoint]
    let widthPixels: Int32 = 200

    public init(power: CGFloat = 24) {
        self.offsets = Self.perlinNoise(widthPixels: widthPixels, power: power)
    }

    static func perlinNoise(widthPixels: Int32, power: CGFloat) -> [CGPoint] {
        let heightPixels: Int32 = 2

        let source = GKPerlinNoiseSource(frequency: 0.5, octaveCount: 8, persistence: 0.1, lacunarity: 5.221, seed: .random(in: 1...100))
        let noise = GKNoise(source)
        let map = GKNoiseMap(
            noise,
            size: vector_double2(3.0, 3.0), origin: vector_double2(0, 0),
            sampleCount: vector_int2(widthPixels, heightPixels),
            seamless: false
        )

        return (0..<widthPixels).map {
            let x = map.value(at: .init(Int32($0), 0))
            let y = map.value(at: .init(Int32($0), 1))
            return CGPoint(x: CGFloat(x) * power, y: CGFloat(y) * power)
        }
    }

    public func apply(_ image: CIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> CIImage {
        let index = Int(Double(widthPixels) * (Double(currentFrame) / Double(numberOfFrames)))
        let offset = offsets[index]
        return image.clampedToExtent().transformed(by: .init(translationX: offset.x, y: offset.y))
    }
}
