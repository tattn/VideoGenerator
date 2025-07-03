import SwiftUI
import VideoGenerator
import AVFoundation

struct EffectPresetsExample: View {
    @State private var selectedPreset: EffectPresets.PresetType = .kenBurnsClassic
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportedURL: URL?
    
    let imageURL = Bundle.main.url(forResource: "sample", withExtension: "jpg")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Effect Presets Example")
                .font(.largeTitle)
                .padding()
            
            // Preset selector
            Picker("Select Preset", selection: $selectedPreset) {
                Group {
                    Text("Ken Burns Classic").tag(EffectPresets.PresetType.kenBurnsClassic)
                    Text("Ken Burns Dramatic").tag(EffectPresets.PresetType.kenBurnsDramatic)
                    Text("Ken Burns Subtle").tag(EffectPresets.PresetType.kenBurnsSubtle)
                    Text("Spin Zoom In").tag(EffectPresets.PresetType.spinZoomIn)
                    Text("Pulse Zoom").tag(EffectPresets.PresetType.pulseZoom)
                    Text("Letterbox Zoom").tag(EffectPresets.PresetType.letterboxZoom)
                }
                
                Group {
                    Text("Parallax Zoom").tag(EffectPresets.PresetType.parallaxZoom)
                    Text("Glitch Zoom").tag(EffectPresets.PresetType.glitchZoom)
                    Text("Shake and Zoom").tag(EffectPresets.PresetType.shakeAndZoom)
                    Text("Vintage Grade").tag(EffectPresets.PresetType.vintageGrade)
                    Text("Moody Grade").tag(EffectPresets.PresetType.moodyGrade)
                    Text("Bright Grade").tag(EffectPresets.PresetType.brightGrade)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            
            // Export buttons
            HStack(spacing: 20) {
                Button("Create Simple Animation") {
                    Task {
                        await createSimpleAnimation()
                    }
                }
                .disabled(isExporting)
                
                Button("Create Story Video") {
                    Task {
                        await createStoryVideo()
                    }
                }
                .disabled(isExporting)
                
                Button("Create Dynamic Intro") {
                    Task {
                        await createDynamicIntro()
                    }
                }
                .disabled(isExporting)
            }
            .padding()
            
            if isExporting {
                ProgressView(value: exportProgress) {
                    Text("Exporting: \(Int(exportProgress * 100))%")
                }
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
            }
            
            if let url = exportedURL {
                VStack {
                    Text("Export Complete!")
                        .foregroundColor(.green)
                    Text(url.lastPathComponent)
                        .font(.caption)
                    
                    Button("Play Video") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .frame(width: 600, height: 500)
        .padding()
    }
    
    func createSimpleAnimation() async {
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        
        do {
            // Create timeline with single photo and selected preset effect
            let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
            
            // Create media item from image URL
            let mediaItem = VideoMediaItem(
                url: imageURL,
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
            
            // Apply the selected preset
            let effect = CompositeEffect.preset(selectedPreset, duration: 5.0)
            
            // Create clip with effect
            let clip = Clip(
                mediaItem: mediaItem,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
                effects: [effect]
            )
            
            let track = Track(trackType: .video, clips: [clip])
            timeline.tracks.append(track)
            
            // Export
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("preset_\(Date().timeIntervalSince1970).mp4")
            
            let exporter = try await VideoExporter()
            
            _ = try await exporter.export(
                timeline: timeline,
                settings: ExportSettings(
                    outputURL: outputURL,
                    resolution: CGSize(width: 1920, height: 1080)
                )
            )
            
            await MainActor.run {
                exportedURL = outputURL
                isExporting = false
            }
            
        } catch {
            print("Export failed: \(error)")
            await MainActor.run {
                isExporting = false
            }
        }
    }
    
    func createStoryVideo() async {
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        
        do {
            // Create timeline with multiple effects combined
            let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
            
            // First clip: Dramatic intro
            let introMediaItem = VideoMediaItem(
                url: imageURL,
                duration: CMTime(seconds: 3, preferredTimescale: 600)
            )
            let introClip = Clip(
                mediaItem: introMediaItem,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
                effects: [EffectPresets.dynamicIntro(style: .zoomSpin, duration: 3.0)]
            )
            
            // Second clip: Cinematic story with vintage grade
            let storyMediaItem = VideoMediaItem(
                url: imageURL,
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
            let storyClip = Clip(
                mediaItem: storyMediaItem,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: 3, preferredTimescale: 600),
                    duration: CMTime(seconds: 5, preferredTimescale: 600)
                ),
                effects: [EffectPresets.cinematicStory(colorGrade: .vintage, duration: 5.0)]
            )
            
            // Third clip: Outro with pulse effect
            let outroMediaItem = VideoMediaItem(
                url: imageURL,
                duration: CMTime(seconds: 2, preferredTimescale: 600)
            )
            let outroClip = Clip(
                mediaItem: outroMediaItem,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: 8, preferredTimescale: 600),
                    duration: CMTime(seconds: 2, preferredTimescale: 600)
                ),
                effects: [
                    EffectPresets.pulseZoom(duration: 2.0, pulseCount: 2)
                        .then(EffectPresets.moodyGrade())
                ]
            )
            
            let track = Track(trackType: .video, clips: [introClip, storyClip, outroClip])
            timeline.tracks.append(track)
            
            // Export
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("story_\(Date().timeIntervalSince1970).mp4")
            
            let exporter = try await VideoExporter()
            
            _ = try await exporter.export(
                timeline: timeline,
                settings: ExportSettings(
                    outputURL: outputURL,
                    resolution: CGSize(width: 1920, height: 1080)
                )
            )
            
            await MainActor.run {
                exportedURL = outputURL
                isExporting = false
            }
            
        } catch {
            print("Export failed: \(error)")
            await MainActor.run {
                isExporting = false
            }
        }
    }
    
    func createDynamicIntro() async {
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        
        do {
            // Create timeline with dynamic intro combining multiple presets
            let timeline = Timeline(size: CGSize(width: 1080, height: 1920)) // Vertical for shorts
            
            let mediaItem = VideoMediaItem(
                url: imageURL,
                duration: CMTime(seconds: 4, preferredTimescale: 600)
            )
            
            // Combine glitch intro with bright color grading
            let combinedEffect = EffectPresets.glitchZoom(duration: 2.0)
                .then(EffectPresets.brightGrade())
                .parallel(with: CameraShakeEffect.action)
            
            let clip = Clip(
                mediaItem: mediaItem,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4, preferredTimescale: 600)),
                effects: [combinedEffect]
            )
            
            let track = Track(trackType: .video, clips: [clip])
            timeline.tracks.append(track)
            
            // Export
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("intro_\(Date().timeIntervalSince1970).mp4")
            
            let exporter = try await VideoExporter()
            
            _ = try await exporter.export(
                timeline: timeline,
                settings: ExportSettings(
                    outputURL: outputURL,
                    resolution: CGSize(width: 1080, height: 1920)
                )
            )
            
            await MainActor.run {
                exportedURL = outputURL
                isExporting = false
            }
            
        } catch {
            print("Export failed: \(error)")
            await MainActor.run {
                isExporting = false
            }
        }
    }
}

// MARK: - Advanced Usage Examples

extension EffectPresetsExample {
    
    /// Example of creating custom preset combinations
    static func customPresetExample() {
        // Combine multiple presets for unique effects
        let customEffect = EffectPresets.kenBurnsClassic()
            .then(EffectPresets.vintageGrade())
            .parallel(with: EffectPresets.pulseZoom(pulseCount: 2))
        
        // Use with time modifiers
        let _ = customEffect.timeRange(
            CMTimeRange(
                start: CMTime(seconds: 1.0, preferredTimescale: 600),
                end: CMTime(seconds: 4.0, preferredTimescale: 600)
            )
        )
        
        // Chain multiple presets sequentially
        let _ = EffectChain()
            .add(EffectPresets.spinZoomIn(duration: 2.0))
            .add(EffectPresets.letterboxZoom(duration: 3.0))
            .add(EffectPresets.moodyGrade())
            .build()
    }
    
    /// Example of using presets with transitions
    static func transitionExample() {
        let timeline = Timeline(size: CGSize(width: 1920, height: 1080))
        
        // Photo 1 with Ken Burns
        let mediaItem1 = VideoMediaItem(
            url: URL(string: "photo1.jpg")!,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        let clip1 = Clip(
            mediaItem: mediaItem1,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            effects: [EffectPresets.kenBurnsClassic()]
        )
        
        // Photo 2 with Parallax
        let mediaItem2 = VideoMediaItem(
            url: URL(string: "photo2.jpg")!,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        let clip2 = Clip(
            mediaItem: mediaItem2,
            timeRange: CMTimeRange(start: CMTime(seconds: 2.5, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600)),
            effects: [EffectPresets.parallaxZoom()]
        )
        
        let track = Track(trackType: .video, clips: [clip1, clip2])
        timeline.tracks.append(track)
    }
}

#Preview {
    EffectPresetsExample()
}