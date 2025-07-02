# VideoGeneratorOpenAI

A Swift package extension that adds AI-powered Timeline generation capabilities to VideoGenerator using OpenAI's API with Structured Output.

## Features

- Generate Timeline instances from text prompts using OpenAI's GPT models
- Structured Output ensures generated timelines conform to the VideoGenerator schema
- Support for custom OpenAI-compatible endpoints (Azure OpenAI, local LLMs, etc.)
- Seamless integration with VideoGenerator's export functionality

## Installation

Add VideoGeneratorOpenAI as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/VideoGenerator.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "VideoGeneratorOpenAI", package: "VideoGenerator")
        ]
    )
]
```

## Usage

### Basic Timeline Generation

```swift
import VideoGeneratorOpenAI
import VideoGenerator

// Generate a timeline from a prompt
let generator = TimelineGenerator(apiKey: "your-openai-api-key")
let timeline = try await generator.generateTimeline(
    from: "Create a 10-second video with a blue background and white text saying 'Hello World' in the center"
)

// Export the timeline to video using VideoGenerator
let exporter = try await VideoExporter()
let settings = ExportSettings(
    outputURL: URL(fileURLWithPath: "/path/to/output.mp4"),
    videoCodec: .h264,
    audioCodec: .aac,
    resolution: timeline.size,
    bitrate: 8_000_000,
    frameRate: timeline.frameRate,
    preset: .high
)
let videoURL = try await exporter.export(timeline: timeline, settings: settings)
```

### Custom Endpoint Configuration

```swift
let configuration = OpenAIClient.Configuration(
    apiKey: "your-api-key",
    baseURL: URL(string: "https://your-custom-endpoint.com/v1")!,
    model: "gpt-4.1"
)
let generator = TimelineGenerator(configuration: configuration)
let timeline = try await generator.generateTimeline(from: "Create a video presentation")
```

## Schema

The AI generates timelines conforming to the VideoGenerator Timeline JSON Schema located at `Resources/timeline.schema.json`. This ensures all generated content is valid and can be properly rendered.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0
- OpenAI API key or compatible endpoint
