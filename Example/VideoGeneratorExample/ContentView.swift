import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var exportedFileURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Video Generator Example")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Click the button below to generate a sample video")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if isExporting {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Generating video...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: generateVideo) {
                    Label("Generate Example Video", systemImage: "play.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if !exportMessage.isEmpty {
                VStack(spacing: 5) {
                    Text(exportMessage)
                        .font(.caption)
                        .foregroundColor(exportMessage.contains("Error") ? .red : .green)
                        .multilineTextAlignment(.center)
                    
                    #if os(macOS)
                    if let fileURL = exportedFileURL {
                        Button(action: {
                            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
                        }) {
                            HStack {
                                Image(systemName: "folder.open")
                                Text(fileURL.lastPathComponent)
                                    .underline()
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    #endif
                }
                .padding(.top)
            }
        }
        .padding()
    }
    
    private func generateVideo() {
        isExporting = true
        exportMessage = ""
        
        Task {
            do {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let outputURL = documentsDirectory.appendingPathComponent("example_video_\(Date().timeIntervalSince1970).mp4")
                
                try await createExampleVideo(to: outputURL)
                
                await MainActor.run {
                    isExporting = false
                    exportMessage = "Video exported successfully!"
                    exportedFileURL = outputURL
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportMessage = "Error: \(error.localizedDescription)"
                    exportedFileURL = nil
                }
                print("Export error: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
