import SwiftUI

struct ScanHistoryView: View {
    @State private var scanResults: [ScanResult] = []
    @State private var searchText = ""
    @State private var showingDetail = false
    @State private var selectedResult: ScanResult?
    
    @Environment(\.dismiss) private var dismiss
    
    var filteredResults: [ScanResult] {
        if searchText.isEmpty {
            return scanResults
        } else {
            return scanResults.filter { result in
                result.qrCodeData.localizedCaseInsensitiveContains(searchText) ||
                result.formattedTimestamp.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if scanResults.isEmpty {
                    emptyStateView
                } else {
                    scanResultsList
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search QR codes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export All", action: exportAllData)
                        Button("Clear History", action: clearHistory)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadScanResults()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Scan History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your scanned QR codes and captured photos will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var scanResultsList: some View {
        List {
            ForEach(filteredResults) { result in
                ScanResultRow(result: result) {
                    selectedResult = result
                    showingDetail = true
                }
            }
            .onDelete(perform: deleteResults)
        }
        .sheet(isPresented: $showingDetail) {
            if let result = selectedResult {
                ScanResultDetailView(result: result)
            }
        }
    }
    
    private func loadScanResults() {
        // Load scan results from local storage
        // This would typically use UserDefaults, Core Data, or FileManager
        // For now, we'll create some sample data
        scanResults = [
            ScanResult(
                qrCodeData: "https://example.com/qr1",
                photoData: nil,
                faceDetected: true,
                scanDuration: 1.2
            ),
            ScanResult(
                qrCodeData: "WiFi:T:WPA;S:MyNetwork;P:password123;;",
                photoData: nil,
                faceDetected: true,
                scanDuration: 0.8
            ),
            ScanResult(
                qrCodeData: "BEGIN:VCARD\nVERSION:3.0\nFN:John Doe\nTEL:+1234567890\nEND:VCARD",
                photoData: nil,
                faceDetected: false,
                scanDuration: 2.1
            )
        ]
    }
    
    private func deleteResults(offsets: IndexSet) {
        scanResults.remove(atOffsets: offsets)
        // Save updated results to storage
    }
    
    private func exportAllData() {
        // Export all scan results and photos
        // Implementation would depend on your export requirements
    }
    
    private func clearHistory() {
        scanResults.removeAll()
        // Clear from storage
    }
}

// MARK: - Scan Result Row
struct ScanResultRow: View {
    let result: ScanResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // QR Code Icon or Photo
                if let photo = result.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "qrcode")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.qrCodePreview)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(result.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Face detection indicator
                        if result.faceDetected {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scan Result Detail View
struct ScanResultDetailView: View {
    let result: ScanResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo Section
                    if let photo = result.photo {
                        VStack {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Text("Captured Photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // QR Code Data Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QR Code Data")
                            .font(.headline)
                        
                        Text(result.qrCodeData)
                            .font(.body)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                    
                    // Metadata Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Details")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            DetailRow(title: "Timestamp", value: result.formattedTimestamp)
                            DetailRow(title: "Scan Duration", value: String(format: "%.1f seconds", result.scanDuration))
                            DetailRow(title: "Face Detected", value: result.faceDetected ? "Yes" : "No")
                            DetailRow(title: "Photo Captured", value: result.photo != nil ? "Yes" : "No")
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button("Copy Data") {
                            UIPasteboard.general.string = result.qrCodeData
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Share") {
                            shareResult()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareResult() {
        var items: [Any] = [result.qrCodeData]
        
        if let photo = result.photo {
            items.append(photo)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ScanHistoryView()
} 