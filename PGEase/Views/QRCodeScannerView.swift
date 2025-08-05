import SwiftUI
import AVFoundation
import UIKit
import Vision

struct QRCodeScannerView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var faceDetectionManager: FaceDetectionManager
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool

    let onQRCodeDetected: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.currentQRSession)
        print("QR Scanner: Using \(cameraManager.currentCameraPosition == .back ? "back" : "front") camera session")
        print("QR Scanner: Session running: \(cameraManager.currentQRSession.isRunning)")
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        print("QR Scanner: Preview layer added with frame: \(previewLayer.frame)")

        // Store preview layer reference for QR detection
        context.coordinator.previewLayer = previewLayer

        // Add scanning overlay
        let overlayView = ScanningOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Start QR detection timer
        context.coordinator.startQRDetection()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            print("QR Scanner: Updated preview layer frame: \(previewLayer.frame)")
            print("QR Scanner: Session still running: \(previewLayer.session?.isRunning ?? false)")
        }
    }

    private func handleQRCodeDetected(_ code: String) {
        guard isScanning else { return }

        // Check if face is detected before processing QR code
        if faceDetectionManager.isFaceQualityAcceptable() {
            scannedCode = code
            onQRCodeDetected(code)

            // Capture photo when both QR code and face are detected
            cameraManager.capturePhoto()

            // Stop scanning temporarily
            isScanning = false

            // For single session mode, switch to face detection after QR scan
            if !cameraManager.isDualSessionMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cameraManager.switchToFaceDetectionMode()
                }
            }

            // Resume scanning after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isScanning = true

                // For single session mode, switch back to QR scanning
                if !cameraManager.isDualSessionMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        cameraManager.switchToQRScanningMode()
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: QRCodeScannerView
        var previewLayer: AVCaptureVideoPreviewLayer?
        var qrDetectionTimer: Timer?
        private var noFrameLogCount = 0 // Move static variable to instance property

        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }

        func startQRDetection() {
            // Stop existing timer
            qrDetectionTimer?.invalidate()

            print("🚀 QR Detection Started")

            // Start new timer to capture frames and detect QR codes
            qrDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.captureFrameAndDetectQR()
            }

            print("QR detection timer started")
        }

        func stopQRDetection() {
            qrDetectionTimer?.invalidate()
            qrDetectionTimer = nil
            print("QR detection timer stopped")
        }

        private func captureFrameAndDetectQR() {
            guard let previewLayer = previewLayer,
                  parent.isScanning else {
                return
            }

            // Check if CameraManager is receiving frames (log only occasionally to avoid spam)
            if let cameraManager = parent.cameraManager as? CameraManager {
                if cameraManager.frameCount == 0 {
                    // Only log every 10th check when no frames are received
                    noFrameLogCount += 1
                    if noFrameLogCount % 10 == 0 {
                        print("📊 No frames received yet - Frame count: \(cameraManager.frameCount)")
                    }
                } else if cameraManager.frameCount > 0 && cameraManager.frameCount <= 5 {
                    print("📊 Frames being received! - Frame count: \(cameraManager.frameCount)")
                }
            }
        }
    }
}

// MARK: - Scanning Overlay View
class ScanningOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .clear

        // Add scanning frame
        let scanningFrame = UIView()
        scanningFrame.backgroundColor = .clear
        scanningFrame.layer.borderColor = UIColor.white.cgColor
        scanningFrame.layer.borderWidth = 2
        scanningFrame.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scanningFrame)

        NSLayoutConstraint.activate([
            scanningFrame.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanningFrame.centerYAnchor.constraint(equalTo: centerYAnchor),
            scanningFrame.widthAnchor.constraint(equalToConstant: 250),
            scanningFrame.heightAnchor.constraint(equalToConstant: 250)
        ])
    }
}

 
