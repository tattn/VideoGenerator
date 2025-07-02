// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoGenerator",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VideoGenerator",
            targets: ["VideoGenerator"]),
        .library(
            name: "VideoGeneratorOpenAI",
            targets: ["VideoGeneratorOpenAI"]),
    ],
    targets: [
        .target(
            name: "VideoGenerator",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VideoGeneratorTests",
            dependencies: ["VideoGenerator"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "VideoGeneratorOpenAI",
            dependencies: ["VideoGenerator"],
            exclude: ["README.md"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VideoGeneratorOpenAITests",
            dependencies: ["VideoGeneratorOpenAI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)