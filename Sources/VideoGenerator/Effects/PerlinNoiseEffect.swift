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
    let contentMode: VideoContentMode
    let widthPixels: Int32 = 200

    public init(power: CGFloat = 24, contentMode: VideoContentMode = .aspectFill) {
        self.offsets = Self.perlinNoise(widthPixels: widthPixels, power: power)
        self.contentMode = contentMode
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

    public func apply(_ image: UIImage, configuration: VideoConfiguration, numberOfFrames: Int, currentFrame: Int) -> UIImage {
        let size = configuration.size.applying(.init(scaleX: 1 / image.scale, y: 1 / image.scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let index = Int(Double(widthPixels) * (Double(currentFrame) / Double(numberOfFrames)))
            let offset = offsets[index]
            context.cgContext.translateBy(x: offset.x, y: offset.y)

            let aspectRatio = VideoContentMode.aspectFill.aspectRatio(between: size, and: image.size)

            let aspectRect = CGRect(x: (size.width - image.size.width * aspectRatio) / 2.0,
                                    y: (size.height - image.size.height * aspectRatio) / 2.0,
                                    width: image.size.width * aspectRatio,
                                    height: image.size.height * aspectRatio)
            image.draw(in: aspectRect)
        }
    }
}

