import Foundation
import UIKit

struct ScanResult: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let qrCodeData: String
    let photoData: Data?
    let faceDetected: Bool
    let scanDuration: TimeInterval
    
    init(qrCodeData: String, photoData: Data? = nil, faceDetected: Bool, scanDuration: TimeInterval) {
        self.timestamp = Date()
        self.qrCodeData = qrCodeData
        self.photoData = photoData
        self.faceDetected = faceDetected
        self.scanDuration = scanDuration
    }
    
    var photo: UIImage? {
        guard let photoData = photoData else { return nil }
        return UIImage(data: photoData)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var qrCodePreview: String {
        if qrCodeData.count > 50 {
            return String(qrCodeData.prefix(50)) + "..."
        }
        return qrCodeData
    }
} 