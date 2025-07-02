# VideoGenerator

A Swift Package for video generation on iOS and macOS platforms. Create videos by composing images, videos, audio, text, and effects using a timeline-based system with iOS-style frame layouts.

## Features

- 🎬 Timeline-based video composition
- 🖼️ Support for images, videos, audio, and text
- 📐 iOS-style frame-based layout (top-left origin)
- ✨ Built-in effects and transitions
- 🎵 Audio mixing capabilities
- 📱 iOS 17+ and macOS 14+ support
- 🚀 Swift 6 with Strict Concurrency
- 🧪 Swift Testing framework

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/VideoGenerator.git", from: "1.0.0")
]
```

## Usage

### Basic Example

```swift
import VideoGenerator

@MainActor
func createVideo() async throws {
    // Create timeline
    let timeline = Timeline(
        size: CGSize(width: 1920, height: 1080),
        frameRate: 30
    )
    
    // Create video track
    var videoTrack = Track(trackType: .video)
    
    // Add video clip
    let videoClip = Clip(
        mediaItem: .video(url: videoURL),
        timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 30)),
        frame: CGRect(origin: .zero, size: timeline.size)
    )
    videoTrack.clips.append(videoClip)
    
    // Create overlay track
    var overlayTrack = Track(trackType: .overlay)
    
    // Add text
    let textClip = Clip(
        mediaItem: .text("Hello World", font: CTFont(.system, size: 72)),
        timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 30), duration: CMTime(seconds: 5, preferredTimescale: 30)),
        frame: CGRect(x: 100, y: 100, width: 1720, height: 200)
    )
    overlayTrack.clips.append(textClip)
    
    // Add tracks to timeline
    timeline.tracks = [videoTrack, overlayTrack]
    
    // Export
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.mp4")
    let exportedURL = try await timeline.export(to: outputURL)
}
```

### Creating a Slideshow

```swift
let slideshow = VideoGenerator.createSlideshow(
    images: images,
    duration: 3.0,
    transitionDuration: 1.0,
    transition: Transitions.fade()
)

let exportedURL = try await slideshow.export(to: outputURL)
```

### Adding Effects

```swift
let clip = Clip(
    mediaItem: imageItem,
    timeRange: timeRange,
    frame: frame,
    effects: [
        Effects.blur(radius: 10),
        Effects.brightness(0.2),
        Effects.opacity(0.8)
    ]
)
```

### Frame-based Layout

Unlike traditional video editing software, VideoGenerator uses iOS-style frame layouts with top-left origin:

```swift
// Position elements using CGRect
let clip = Clip(
    mediaItem: mediaItem,
    timeRange: timeRange,
    frame: CGRect(x: 100, y: 200, width: 640, height: 480)
)

// Use layout helpers
clip.setPosition(CGPoint(x: 50, y: 50))
clip.setSize(CGSize(width: 800, height: 600))
clip.center(in: timeline.size)
```

## Architecture

- **Timeline**: Main container holding all tracks
- **Track**: Container for clips of a specific type (video, audio, overlay)
- **Clip**: Single media element with position, timing, and effects
- **MediaItem**: Protocol for different media types (video, image, audio, text)
- **Effect**: Protocol for visual effects
- **Transition**: Protocol for transitions between clips

## License

MIT License