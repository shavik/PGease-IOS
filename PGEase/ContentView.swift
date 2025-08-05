import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var faceDetectionManager = FaceDetectionManager()

    @State private var scannedCode: String?
    @State private var isScanning = true
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showingResult = false
    @State private var capturedPhoto: UIImage?
    @State private var scanResults: [ScanResult] = []

    // PiP Settings
    @AppStorage("pipPosition") private var pipPosition: PiPPosition = .topRight
    @AppStorage("pipSize") private var pipSize: PiPSize = .medium
    @AppStorage("pipOpacity") private var pipOpacity: Double = 0.8
    @AppStorage("pipVisible") private var pipVisible: Bool = true
    @AppStorage("faceDetectionEnabled") private var faceDetectionEnabled: Bool = true
    @AppStorage("autoCaptureEnabled") private var autoCaptureEnabled: Bool = true

    var body: some View {
        ZStack {
            // Main scanning interface
            mainScanningView

            // Status indicators
            VStack {
                statusIndicators
                Spacer()
                controlButtons
            }
            .padding()
            .zIndex(500) // Ensure controls are above camera but below PiP

            // Picture-in-Picture view - positioned as overlay
            if pipVisible {
                VStack {
                    HStack {
                        Spacer()
                        PiPView(
                            cameraManager: cameraManager,
                            faceDetectionManager: faceDetectionManager,
                            isVisible: $pipVisible,
                            position: $pipPosition,
                            size: $pipSize,
                            opacity: $pipOpacity
                        ) { faceDetected in
                            handleFaceDetection(faceDetected)
                        }
                        .frame(width: 120, height: 90) // Fixed small size
                        .allowsHitTesting(true)
                        .zIndex(1000) // Ensure it's on top
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                    Spacer()
                }
            }
        }
        .onAppear {
            setupApp()
        }

        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHistory) {
            ScanHistoryView()
        }
        .alert("QR Code Detected", isPresented: $showingResult) {
            Button("OK") {
                showingResult = false
                scannedCode = nil
            }
        } message: {
            if let code = scannedCode {
                Text("Scanned: \(code)")
            }
        }
        .alert("Camera Access Required", isPresented: .constant(cameraManager.error != nil)) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let error = cameraManager.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var mainScanningView: some View {
        ZStack {
            // Camera preview
            QRCodeScannerView(
                cameraManager: cameraManager,
                faceDetectionManager: faceDetectionManager,
                scannedCode: $scannedCode,
                isScanning: $isScanning
            ) { code in
                handleQRCodeDetected(code)
            }

            // Scanning overlay
            if isScanning {
                scanningOverlay
            }
        }
    }

    private var scanningOverlay: some View {
        VStack {
            // Top status bar
            HStack {
                // Face detection status
                HStack(spacing: 4) {
                    Image(systemName: faceDetectionManager.isFaceDetected ? "face.smiling.fill" : "face.smiling")
                        .foregroundColor(faceDetectionManager.isFaceDetected ? .green : .red)
                    Text(faceDetectionManager.isFaceDetected ? "Face Detected" : "No Face")
                        .font(.caption)
                        .foregroundColor(faceDetectionManager.isFaceDetected ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

                Spacer()

                // Scanning status
                HStack(spacing: 4) {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.green)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 60)

            Spacer()
        }
    }

    private var statusIndicators: some View {
        VStack(spacing: 8) {
            // Mode indicator
            HStack {
                Image(systemName: cameraManager.isQRScanningMode ? "qrcode.viewfinder" : "face.smiling")
                    .foregroundColor(cameraManager.isQRScanningMode ? .green : .blue)
                Text(cameraManager.isQRScanningMode ? "QR Scanning Mode" : "Face Detection Mode")
                    .font(.caption)
                    .foregroundColor(cameraManager.isQRScanningMode ? .green : .blue)

                Spacer()

                if !cameraManager.isDualSessionMode {
                    Text("Single Session")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            // Face detection confidence
            if faceDetectionEnabled && faceDetectionManager.isFaceDetected {
                HStack {
                    Text("Confidence: \(Int(faceDetectionManager.faceConfidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.green)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            // Face count indicator
            if faceDetectionManager.faceCount > 1 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Multiple faces detected")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.top, 120)
    }

    private var controlButtons: some View {
        VStack(spacing: 10) {
            // Main control row
            HStack(spacing: 15) {
                // Settings button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Manual capture button
                Button(action: manualCapture) {
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Mode switch button (for single session devices)
                if !cameraManager.isDualSessionMode {
                    Button(action: {
                        if cameraManager.isQRScanningMode {
                            cameraManager.switchToFaceDetectionMode()
                        } else {
                            cameraManager.switchToQRScanningMode()
                        }
                    }) {
                        Image(systemName: cameraManager.isQRScanningMode ? "face.smiling" : "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                } else {
                    // Restart back camera button (for debugging dual session mode)
                    Button(action: { cameraManager.restartBackCamera() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                // History button
                Button(action: { showingHistory = true }) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            // Debug control row
            HStack(spacing: 15) {
                // Force reset button (for debugging)
                Button(action: { cameraManager.forceCameraReset() }) {
                    Image(systemName: "power")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Force single session mode button
                Button(action: { cameraManager.forceSingleSessionMode() }) {
                    Image(systemName: "1.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Test QR detection button
                Button(action: { testQRDetection() }) {
                    Image(systemName: "qrcode")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // Debug test button (more visible)
                Button(action: {
                    print("Debug button tapped!")
                    testQRDetection()
                }) {
                    Text("TEST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, 50)
    }

    private func setupApp() {
        // Setup camera manager callbacks
        cameraManager.onPhotoCaptured = { photo in
            handlePhotoCaptured(photo)
        }

        // Setup QR code detection callback
        cameraManager.onQRCodeDetected = { code in
            handleQRCodeDetected(code)
        }

        // Setup face detection manager callbacks
        faceDetectionManager.onFaceDetected = { detected, confidence in
            handleFaceDetection(detected)
        }

        // Debug camera sessions
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            cameraManager.debugSessionStatus()
        }
    }

    private func handleQRCodeDetected(_ code: String) {
        guard autoCaptureEnabled else {
            scannedCode = code
            showingResult = true
            return
        }

        // Check if face is detected before processing
        if faceDetectionEnabled && !faceDetectionManager.isFaceQualityAcceptable() {
            // Show face detection requirement
            return
        }

        // Process QR code and capture photo
        scannedCode = code
        cameraManager.capturePhoto()

        // Show result
        showingResult = true
    }

    private func handlePhotoCaptured(_ photo: UIImage) {
        capturedPhoto = photo

        // Create scan result
        if let code = scannedCode {
            let result = ScanResult(
                qrCodeData: code,
                photoData: photo.jpegData(compressionQuality: 0.8),
                faceDetected: faceDetectionManager.isFaceDetected,
                scanDuration: 1.0 // This would be calculated from actual scan time
            )

            scanResults.append(result)
            saveScanResult(result)
        }
    }

    private func handleFaceDetection(_ detected: Bool) {
        // Update UI based on face detection status
        if detected && faceDetectionManager.faceCount > 1 {
            // Show warning for multiple faces
        }
    }

    private func manualCapture() {
        if let code = scannedCode {
            cameraManager.capturePhoto()
        } else {
            // Just capture photo without QR code
            cameraManager.capturePhoto()
        }
    }

    private func saveScanResult(_ result: ScanResult) {
        // Save scan result to local storage
        // This would typically use UserDefaults, Core Data, or FileManager
    }

    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func testQRDetection() {
        print("Testing QR detection...")
        print("Camera manager status:")
        cameraManager.debugSessionStatus()
        print("Face detection manager status:")
        print("Face detected: \(faceDetectionManager.isFaceDetected)")
        print("Face confidence: \(faceDetectionManager.faceConfidence)")
        print("Face count: \(faceDetectionManager.faceCount)")

        // Test Vision framework
        cameraManager.testQRDetection()

        // Test manual QR detection
        cameraManager.testManualQRDetection()

        // Test video data output delegate
        cameraManager.testVideoDataOutputDelegate()

        // Test video data output
        cameraManager.testVideoDataOutput()
    }
}

#Preview {
    ContentView()
} 
