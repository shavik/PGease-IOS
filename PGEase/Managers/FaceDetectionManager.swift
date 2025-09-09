import Vision
import CoreML
import UIKit
import Combine

class FaceDetectionManager: NSObject, ObservableObject {
    @Published var isFaceDetected = false
    @Published var faceConfidence: Float = 0.0
    @Published var faceCount: Int = 0
    @Published var error: FaceDetectionError?

    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private let processingQueue = DispatchQueue(label: "face.detection.queue")

    // Face detection throttling
    private var faceDetectionFrameCount = 0

    // Callbacks
    var onFaceDetected: ((Bool, Float) -> Void)?
    var onFaceCountChanged: ((Int) -> Void)?

    enum FaceDetectionError: Error, LocalizedError {
        case visionRequestFailed
        case noFaceDetected
        case multipleFacesDetected
        case lowConfidence

        var errorDescription: String? {
            switch self {
            case .visionRequestFailed:
                return "Face detection request failed"
            case .noFaceDetected:
                return "No face detected in the camera view"
            case .multipleFacesDetected:
                return "Multiple faces detected. Please ensure only one face is visible"
            case .lowConfidence:
                return "Face detection confidence is too low"
            }
        }
    }

    override init() {
        super.init()
        setupFaceDetection()
        setupNotificationHandling()
    }

    private func setupFaceDetection() {
        // Configure face detection request
        // VNDetectFaceRectanglesRequest doesn't have configurable properties in newer iOS versions
        // The request will use default settings which work well for most cases

        // Configure face landmarks request - using the correct API for newer iOS versions
        // The faceLandmarks property is deprecated, so we'll use the default configuration
        // which automatically detects all available landmarks
    }

    private func setupNotificationHandling() {
        // Listen for face detection requests from CameraManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFaceDetectionRequest),
            name: NSNotification.Name("ProcessFaceDetection"),
            object: nil
        )
    }

    @objc private func handleFaceDetectionRequest(_ notification: Notification) {
        guard let image = notification.object as? UIImage else {
            print("❌ Face detection request received but no image provided")
            return
        }

        // Throttle face detection to avoid overwhelming the system
        // Only process every 10th frame (approximately 3 FPS)
        faceDetectionFrameCount += 1

        if faceDetectionFrameCount % 10 != 0 {
            return
        }

        print("🎭 Face detection request received for image (frame \(faceDetectionFrameCount))")
        let detected = detectFacesInImage(image)

        // Update face detection status
        DispatchQueue.main.async { [weak self] in
            self?.updateFaceDetectionStatus(detected: detected, confidence: detected ? 0.8 : 0.0, count: detected ? 1 : 0)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func detectFaces(in image: CVPixelBuffer) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try requestHandler.perform([self.faceDetectionRequest])
                self.processFaceDetectionResults()
            } catch {
                DispatchQueue.main.async {
                    self.error = .visionRequestFailed
                }
            }
        }
    }

    private func processFaceDetectionResults() {
        guard let results = faceDetectionRequest.results as? [VNFaceObservation] else {
            DispatchQueue.main.async { [weak self] in
                self?.updateFaceDetectionStatus(detected: false, confidence: 0.0, count: 0)
            }
            return
        }

        let faceCount = results.count
        let maxConfidence = results.map { $0.confidence }.max() ?? 0.0

        DispatchQueue.main.async { [weak self] in
            self?.updateFaceDetectionStatus(detected: faceCount > 0, confidence: maxConfidence, count: faceCount)
        }

        // Validate face detection
        validateFaceDetection(faceCount: faceCount, confidence: maxConfidence)
    }

    private func updateFaceDetectionStatus(detected: Bool, confidence: Float, count: Int) {
        isFaceDetected = detected
        faceConfidence = confidence
        faceCount = count

        onFaceDetected?(detected, confidence)
        onFaceCountChanged?(count)
    }

    private func validateFaceDetection(faceCount: Int, confidence: Float) {
        // Check for multiple faces
        if faceCount > 1 {
            error = .multipleFacesDetected
            return
        }

        // Check for no faces
        if faceCount == 0 {
            error = .noFaceDetected
            return
        }

        // Check confidence threshold (0.7 is a good threshold)
        if confidence < 0.7 {
            error = .lowConfidence
            return
        }

        // Clear any previous errors if detection is successful
        error = nil
    }

    func getFaceQualityScore() -> Float {
        // Calculate a quality score based on confidence and other factors
        let baseScore = faceConfidence

        // Additional quality factors could be added here:
        // - Face size in frame
        // - Face angle/pose
        // - Lighting conditions
        // - Blur detection

        return min(baseScore, 1.0)
    }

    func isFaceQualityAcceptable() -> Bool {
        return isFaceDetected && faceCount == 1 && faceConfidence >= 0.7
    }

    func resetDetection() {
        DispatchQueue.main.async { [weak self] in
            self?.isFaceDetected = false
            self?.faceConfidence = 0.0
            self?.faceCount = 0
            self?.error = nil
        }
    }
}

// MARK: - Face Detection Extensions
extension FaceDetectionManager {
    func detectFacesInImage(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

        var detected = false

        processingQueue.sync {
            do {
                try requestHandler.perform([faceDetectionRequest])
                if let results = faceDetectionRequest.results as? [VNFaceObservation], !results.isEmpty {
                    detected = true
                }
            } catch {
                print("Face detection in image failed: \(error)")
            }
        }

        return detected
    }
} 
