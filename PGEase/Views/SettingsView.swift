import SwiftUI

struct SettingsView: View {
    @AppStorage("pipPosition") private var pipPosition: PiPPosition = .topRight
    @AppStorage("pipSize") private var pipSize: PiPSize = .medium
    @AppStorage("pipOpacity") private var pipOpacity: Double = 0.8
    @AppStorage("pipVisible") private var pipVisible: Bool = true
    @AppStorage("faceDetectionEnabled") private var faceDetectionEnabled: Bool = true
    @AppStorage("autoCaptureEnabled") private var autoCaptureEnabled: Bool = true
    @AppStorage("photoQuality") private var photoQuality: PhotoQuality = .high
    @AppStorage("scanHistoryEnabled") private var scanHistoryEnabled: Bool = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Picture-in-Picture Settings") {
                    Toggle("Show PiP Window", isOn: $pipVisible)
                    
                    if pipVisible {
                        Picker("Position", selection: $pipPosition) {
                            ForEach(PiPPosition.allCases, id: \.self) { position in
                                Text(position.rawValue).tag(position)
                            }
                        }
                        
                        Picker("Size", selection: $pipSize) {
                            ForEach(PiPSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Opacity")
                            Slider(value: $pipOpacity, in: 0.25...1.0, step: 0.05) {
                                Text("Opacity")
                            } minimumValueLabel: {
                                Text("25%")
                            } maximumValueLabel: {
                                Text("100%")
                            }
                            Text("\(Int(pipOpacity * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Face Detection") {
                    Toggle("Enable Face Detection", isOn: $faceDetectionEnabled)
                    
                    if faceDetectionEnabled {
                        Text("Face detection ensures that a valid face is visible before capturing photos.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Photo Capture") {
                    Toggle("Auto Capture", isOn: $autoCaptureEnabled)
                    
                    if autoCaptureEnabled {
                        Text("Automatically capture photos when QR code is scanned and face is detected.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Photo Quality", selection: $photoQuality) {
                        ForEach(PhotoQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                }
                
                Section("Data & Privacy") {
                    Toggle("Save Scan History", isOn: $scanHistoryEnabled)
                    
                    if scanHistoryEnabled {
                        Text("Store QR code scan history and captured photos locally.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearAllData() {
        // This would clear all stored scan results and photos
        // Implementation would depend on your data storage mechanism
    }
}

// MARK: - Supporting Types
enum PhotoQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low (Smaller files)"
        case .medium:
            return "Medium (Balanced)"
        case .high:
            return "High (Best quality)"
        }
    }
}

// MARK: - Extensions
extension PiPSize {
    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }
}

#Preview {
    SettingsView()
} 
