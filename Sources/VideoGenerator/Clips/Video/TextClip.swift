//
//  TextClip.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

public struct TextClip: VideoClip, @unchecked Sendable {
    public init(
        _ text: String,
        font: UIFont = .systemFont(ofSize: 128, weight: .heavy),
        fontColor: UIColor = .white,
        duration: TimeInterval,
        effects: [VideoEffect] = []
    ) {
        self.text = text
        self.duration = duration
        self.effects = effects

        attributes = [
            .foregroundColor: fontColor,
            .font: font,
        ]
        let textSize = text.size(withAttributes: attributes)
        offset = .init(x: -textSize.width / 2, y: -textSize.height / 2)
    }

    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let offset: CGPoint
    var configuration: VideoConfiguration!
    
    public let duration: TimeInterval
    public let effects: [VideoEffect]

    public mutating func prepare(with configuration: VideoConfiguration) {
        self.configuration = configuration
    }

    public func image(elapsed: TimeInterval) async -> CIImage {
        let center = CGPoint(x: configuration.width / 2, y: configuration.height / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: configuration.size, format: format).image { context in
            text.draw(at: .init(x: center.x + offset.x, y: center.y + offset.y), withAttributes: attributes)
        }
        return CIImage(image: rendered) ?? .clear
    }
}
