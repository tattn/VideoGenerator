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
        if isGenerating {
            ProgressView()
                .progressViewStyle(.circular)
        } else {
            Button("Generate") {
                isGenerating = true
                Task {
                    try await generate()
                    isGenerating = false
                }
            }
        }
    }

    func generate() async throws {
        try await videoGenerator.generate([
            ImageClip(image: sampleImages[0], duration: 1, effects: [
                PerlinNoiseEffect(contentMode: .aspectFill)
            ]),
            ImageClip(image: sampleImages[1], duration: 1, effects: [
                PerlinNoiseEffect(contentMode: .aspectFill)
            ]),
        ])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
