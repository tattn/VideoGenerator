//
//  ContentView.swift
//  VideoGeneratorSample
//
//  Created by Tatsuya Tanaka on 2022/08/03.
//

import SwiftUI
import VideoGenerator

struct ContentView: View {
    @State var videoGenerator = VideoGenerator()
    @State var isGenerating = false
    @State var errorOccurred = false

    var sampleImages: [UIImage] {
        let urls = [
            URL(string: "https://images.pexels.com/photos/2802547/pexels-photo-2802547.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2")!,
            URL(string: "https://images.pexels.com/photos/1170986/pexels-photo-1170986.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2")!,
        ]
        return urls.map {
            UIImage(data: try! Data(contentsOf: $0))!
        }
    }

    var body: some View {
        if errorOccurred {
            Image(systemName: "exclamationmark.triangle")
        }
        if isGenerating {
            ProgressView()
                .progressViewStyle(.circular)
        } else {
            Button("Generate") {
                isGenerating = true
                Task {
                    do {
                        try await generate()
                    } catch {
                        errorOccurred = true
                    }
                    isGenerating = false
                }
            }
        }
    }

    func generate() async throws {
        try await videoGenerator.generate([
            Clip(
                video: CompositeClip([
                    ImageClip(sampleImages[0], scalingMode: .aspectFill, duration: 2, effects: [
                        PerlinNoiseEffect()
                    ]),
                    TextClip("こんにちは", duration: 1, effects: [
                        RotateEffect(),
                    ]),
                ], duration: 2).fade(duration: 0.5),
                audio: SpeechClip("こんにちは")
            ),
            Clip(
                video: CompositeClip([
                    ImageClip(sampleImages[1], scalingMode: .aspectFill, duration: 1, effects: [
                        PerlinNoiseEffect(),
                    ]),
                    TextClip("にゃ〜", duration: 1, effects: [
                        RotateEffect(speed: .pi * 2, direction: .left),
                        TransformEffect(matrix: .init(translationX: -200, y: -100))
                    ]),
                ], duration: 1),
                audio: SpeechClip("猫だよー")
            ),
        ])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
