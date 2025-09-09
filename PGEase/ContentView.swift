import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var faceDetectionManager = FaceDetectionManager()
    @StateObject private var scanResultManager = ScanResultManager()
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager

    @State private var scannedCode: String?
    @State private var isScanning = true
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showingResult = false

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
                            isVisible: Binding(
                                get: { pipVisible },
                                set: { pipVisible = $0 }
                            ),
                            position: Binding(
                                get: { pipPosition },
                                set: { pipPosition = $0 }
                            ),
                            size: Binding(
                                get: { pipSize },
                                set: { pipSize = $0 }
                            ),
                            opacity: Binding(
                                get: { pipOpacity },
                                set: { pipOpacity = $0 }
                            )
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
            ScanHistoryView(scanResultManager: scanResultManager)
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
                if cameraManager.isQRScanningMode {
                    if cameraManager.isQRScanningEnabled {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(.green)
                        Text("QR Scanning Mode")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "qrcode.viewfinder.slash")
                            .foregroundColor(.orange)
                        Text("QR Scanning Disabled")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                    Text("Photo Capture Mode")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Spacer()

                if !cameraManager.isQRScanningMode {
                    Text("10s Timeout")
                        .font(.caption2)
                        .foregroundColor(.red)
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

            // Scan QR Code button (only show when QR scanning is disabled)
            if !cameraManager.isQRScanningEnabled {
                Button(action: {
                    print("🔍 Manual scan button tapped!")
                    cameraManager.enableQRScanning()
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 45, height: 45)
                        .background(Color.green)
                        .clipShape(Circle())
                }
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
            // Logout button
            Button(action: logout) {
               Image(systemName: "rectangle.portrait.and.arrow.right")
                   .font(.title2)
                   .foregroundColor(.white)
                   .frame(width: 45, height: 45)
                   .background(.ultraThinMaterial)
                   .clipShape(Circle())
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

            // Auto-capture photo when face is detected in photo capture mode
            if !cameraManager.isQRScanningMode && detected && confidence > 0.7 {
                print("✅ Face detected with confidence \(confidence) - capturing photo")
                cameraManager.capturePhoto()
            }
        }

        // Debug camera sessions and ensure they start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            cameraManager.debugSessionStatus()

            // Force start session if it's not running
            if !cameraManager.isSessionRunning {
                print("🔄 Session not running, forcing start...")
                cameraManager.startSession()
            }
        }
    }

    private func handleQRCodeDetected(_ code: String) {
        guard autoCaptureEnabled else {
            scannedCode = code
            showingResult = true
            return
        }

        // QR code detected - app will automatically switch to photo capture mode
        scannedCode = code
        print("🎯 QR Code detected: \(code) - Switching to photo capture mode")

        // The camera manager will handle the session switching automatically
        // We just need to show the result
        showingResult = true
    }

    private func handlePhotoCaptured(_ photo: UIImage) {
        // Create scan result
        if let code = scannedCode {
            let result = ScanResult(
                qrCodeData: code,
                photoData: photo.jpegData(compressionQuality: 0.8),
                faceDetected: faceDetectionManager.isFaceDetected,
                scanDuration: 1.0 // This would be calculated from actual scan time
            )

            // Save using ScanResultManager
            scanResultManager.saveScanResult(result)
            print("💾 Photo captured and scan result saved")
        }
    }

    private func handleFaceDetection(_ detected: Bool) {
        print("🎭 Face detection triggered: \(detected)")

        // Update UI based on face detection status
        if detected && faceDetectionManager.faceCount > 1 {
            // Show warning for multiple faces
            print("⚠️ Multiple faces detected")
        }
    }

    private func manualCapture() {
        cameraManager.capturePhoto()
    }

    // Scan result saving is now handled by ScanResultManager

    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    private func logout() {
        biometricAuthManager.logout()
    }
}

#Preview {
    ContentView()
}
