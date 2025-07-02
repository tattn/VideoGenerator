# VideoGeneratorOpenAI

A Swift package that integrates OpenAI's API with VideoGenerator to automatically generate video timelines from text prompts.

## Features

- Generate video timelines using OpenAI's structured output
- Automatic image generation using DALL-E
- Strict JSON schema validation
- Thread-safe actor-based architecture
- Swift 6 concurrency support

## Installation

Add VideoGeneratorOpenAI to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/VideoGenerator.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["VideoGeneratorOpenAI"]
    )
]
```

## Usage

### Basic Timeline Generation

```swift
import VideoGeneratorOpenAI

// Create a timeline generator
let generator = TimelineGenerator(apiKey: "your-openai-api-key")

// Generate a timeline from a prompt
let timeline = try await generator.generateTimeline(
    from: "Create a 30-second video with animated text saying 'Hello World' over a blue background"
)
```

### Image Generation Options

VideoGeneratorOpenAI supports automatic image generation using OpenAI's DALL-E API. You can control image generation behavior using `ImageGenerationOptions`:

```swift
// Enable image generation with custom settings
let imageOptions = ImageGenerationOptions(
    maxImages: 3,        // Maximum number of images to generate (default: 0 = disabled)
    model: "dall-e-3",   // Image generation model (default: "dall-e-3")
    size: "1024x1024",   // Image size (default: "1024x1024")
    quality: "standard"  // Image quality: "standard" or "hd" (default: "standard")
)

let generator = TimelineGenerator(
    apiKey: "your-openai-api-key",
    imageGenerationOptions: imageOptions
)

// When generating timelines, the AI can now create images
let timeline = try await generator.generateTimeline(
    from: "Create a video with a beautiful sunset image followed by text overlay"
)
```

#### Image Generation Parameters

- **`maxImages`**: Controls the maximum number of images that can be generated per timeline
  - `0` (default): Image generation is disabled
  - `> 0`: Image generation is enabled with the specified limit
  
- **`model`**: The DALL-E model to use
  - `"dall-e-3"` (default): Latest DALL-E model with better quality
  - `"dall-e-2"`: Previous generation model
  
- **`size`**: The size of generated images
  - `"1024x1024"` (default): Square HD images
  - `"1024x1792"`: Portrait HD images (DALL-E 3 only)
  - `"1792x1024"`: Landscape HD images (DALL-E 3 only)
  - `"512x512"`: Smaller square images
  
- **`quality`**: The quality of generated images
  - `"standard"` (default): Standard quality
  - `"hd"`: Higher quality (DALL-E 3 only)

### Advanced Configuration

```swift
// Custom configuration with all options
let config = OpenAIClient.Configuration(
    apiKey: "your-openai-api-key",
    baseURL: URL(string: "https://api.openai.com/v1")!,
    model: "gpt-4-turbo-preview",
    imageGenerationOptions: ImageGenerationOptions(
        maxImages: 5,
        model: "dall-e-3",
        size: "1792x1024",
        quality: "hd"
    )
)

let generator = TimelineGenerator(configuration: config)
```

## How It Works

1. **Prompt Processing**: Your text prompt is sent to OpenAI's chat completion API
2. **Structured Output**: The AI generates a timeline following a strict JSON schema
3. **Image Generation**: If enabled, the AI marks images with `GENERATE_IMAGE:` prefix
4. **Image Creation**: Marked images are automatically generated using DALL-E
5. **Timeline Assembly**: The final timeline with all media items is returned

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- OpenAI API key

## License

See the main VideoGenerator package license.