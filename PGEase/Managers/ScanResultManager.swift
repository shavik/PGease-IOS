import Foundation
import UIKit

class ScanResultManager: ObservableObject {
    @Published var scanResults: [ScanResult] = []
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let scanResultsFileName = "scan_results.json"
    
    init() {
        loadScanResults()
    }
    
    // MARK: - Save Scan Result
    
    func saveScanResult(_ result: ScanResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Add to memory
            DispatchQueue.main.async {
                self.scanResults.append(result)
            }
            
            // Save to disk
            self.saveToDisk()
            
            print("💾 Scan result saved: \(result.qrCodePreview)")
        }
    }
    
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(scanResults)
            let fileURL = documentsPath.appendingPathComponent(scanResultsFileName)
            try data.write(to: fileURL)
            print("💾 Scan results saved to disk: \(fileURL.path)")
        } catch {
            print("❌ Failed to save scan results: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Scan Results
    
    private func loadScanResults() {
        let fileURL = documentsPath.appendingPathComponent(scanResultsFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📁 No existing scan results file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let results = try decoder.decode([ScanResult].self, from: data)
            
            DispatchQueue.main.async {
                self.scanResults = results
            }
            
            print("📁 Loaded \(results.count) scan results from disk")
        } catch {
            print("❌ Failed to load scan results: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Scan Result
    
    func deleteScanResult(_ result: ScanResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Remove from memory
            DispatchQueue.main.async {
                self.scanResults.removeAll { $0.id == result.id }
            }
            
            // Save to disk
            self.saveToDisk()
            
            print("🗑️ Scan result deleted: \(result.qrCodePreview)")
        }
    }
    
    // MARK: - Clear All Results
    
    func clearAllResults() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Clear memory
            DispatchQueue.main.async {
                self.scanResults.removeAll()
            }
            
            // Clear disk
            let fileURL = documentsPath.appendingPathComponent(scanResultsFileName)
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ All scan results cleared from disk")
            } catch {
                print("❌ Failed to clear scan results: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Export Results
    
    func exportResults() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(scanResults)
            
            let exportURL = documentsPath.appendingPathComponent("scan_results_export_\(Date().timeIntervalSince1970).json")
            try data.write(to: exportURL)
            
            print("📤 Scan results exported to: \(exportURL.path)")
            return exportURL
        } catch {
            print("❌ Failed to export scan results: \(error.localizedDescription)")
            return nil
        }
    }
} 