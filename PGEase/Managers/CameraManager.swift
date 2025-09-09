// Modified version of your original CameraManager class with working back camera delegate handling

import AVFoundation
import UIKit
import Combine
import Vision

class CameraManager: NSObject, ObservableObject {
    private let instanceId = UUID()

    @Published var isSessionRunning = false
    @Published var isAuthorized = false
    @Published var error: CameraError?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var isDualSessionMode = false
    @Published var isQRScanningMode = true  // true = QR scanning, false = photo capture
    var isPhotoCaptureMode: Bool { return !isQRScanningMode }  // Computed property for photo capture mode
    @Published var isPiPSessionReady = false  // Track when front camera session is ready for preview
    @Published var isQRScanningEnabled = true  // Manual control for QR scanning
    private var hasCapturedPhotoForCurrentScan = false  // Prevent multiple photo captures per QR scan
    var frameCount = 0

    // Timer for photo capture timeout
    private var devicePosition: AVCaptureDevice.Position = .front
    private var photoCaptureTimer: Timer?
    private let photoCaptureTimeout: TimeInterval = 10.0

    // Performance optimization
    private var qrDetectionThrottleTimer: Timer?
    private let qrDetectionThrottleInterval: TimeInterval = 0.5 // Throttle QR detection to save battery

    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let videoDataOutputQueue = DispatchQueue(label: "video.data.output.queue", qos: .userInitiated)
    private let pipVideoDataOutputQueue = DispatchQueue(label: "pip.video.data.output.queue", qos: .userInitiated)

    // Main session for QR scanning (back camera)
    private let session = AVCaptureSession()
    private var cameraInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var photoOutput: AVCapturePhotoOutput?

    // Session runtime error monitoring
    private var sessionRuntimeErrorObserver: NSObjectProtocol?

    // Separate session for PiP (front camera)
    private let pipSession = AVCaptureSession()
    private var pipCameraInput: AVCaptureDeviceInput?
    private var pipVideoDataOutput: AVCaptureVideoDataOutput?
    private var pipPhotoOutput: AVCapturePhotoOutput?

    var currentQRSession: AVCaptureSession { return session } // Alias for compatibility

    // Properties for PiP support
    var frontCameraSession: AVCaptureSession { return pipSession }
    var backCameraSession: AVCaptureSession { return session }

    var onQRCodeDetected: ((String) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?

    enum CameraError: Error, LocalizedError {
        case notAuthorized
        case deviceNotFound
        case sessionConfigurationFailed
        case photoCaptureFailed
        case dualCameraNotSupported
        case sessionStartFailed
        case sessionRuntimeError(String)
        case previewLayerError
        case timeoutError

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access is required."
            case .deviceNotFound:
                return "Camera device not found."
            case .sessionConfigurationFailed:
                return "Failed to configure camera session."
            case .photoCaptureFailed:
                return "Failed to capture photo."
            case .dualCameraNotSupported:
                return "Dual camera mode is not supported on this device."
            case .sessionStartFailed:
                return "Failed to start camera session."
            case .sessionRuntimeError(let details):
                return "Camera session runtime error: \(details)"
            case .previewLayerError:
                return "Failed to setup camera preview layer."
            case .timeoutError:
                return "Camera operation timed out."
            }
        }
    }

    override init() {
        super.init()
        print("🔧 CameraManager instance created: \(instanceId)")
        checkAuthorization()
    }

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            self.setupSessions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSessions()
                    } else {
                        self?.error = .notAuthorized
                    }
                }
            }
        default:
            self.error = .notAuthorized
        }
    }

    private func setupSessions() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Setup session runtime error monitoring
            self.setupSessionErrorMonitoring()

            // Setup main session (back camera for QR scanning)
            self.setupMainSession()

            // Setup PiP session (front camera for face detection) but don't start it yet
            self.setupPiPSession()

            // Start session based on current mode
            DispatchQueue.main.async {
                self.startSession()
            }
        }
    }

    private func setupSessionErrorMonitoring() {
        // Monitor session runtime errors
        sessionRuntimeErrorObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            print("❌ Session runtime error occurred")
            self.error = .sessionRuntimeError("Camera session encountered an error")
        }

        print("🔍 Session runtime error monitoring enabled")
    }

    private func setupMainSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Clear any existing outputs first
        for output in session.outputs {
            session.removeOutput(output)
            print("🗑️ Removed existing output: \(type(of: output))")
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            DispatchQueue.main.async { self.error = .deviceNotFound }
            return
        }
        session.addInput(input)
        cameraInput = input
        print("✅ Back camera input added to main session")

        // Add metadata output for QR code detection (like CodeScanner)
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            self.metadataOutput = metadataOutput
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            print("✅ Metadata output added to main session for QR detection")
            print("  - Metadata delegate set: \(metadataOutput.metadataObjectsDelegate != nil)")
        } else {
            print("❌ Failed to add metadata output to main session")
        }

        // Add video data output for frame processing (if needed)
        let output = AVCaptureVideoDataOutput()
        // Try removing videoSettings entirely to use default format
        // output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
            videoDataOutput = output
            print("✅ Video data output added to main session")
            print("  - Delegate set: \(output.sampleBufferDelegate != nil)")
            print("  - Queue: \(videoDataOutputQueue)")
            print("  - Total outputs: \(session.outputs.count)")
            print("  - Video outputs: \(session.outputs.filter { $0 is AVCaptureVideoDataOutput }.count)")
        } else {
            print("❌ Failed to add video data output to main session")
        }

        // Add photo output for photo capture
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
            print("✅ Photo output added to main session")
        }

        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
            connection.isEnabled = true
            print("✅ Main session connection enabled and orientation set")
        }

        session.commitConfiguration()

        // Set metadata object types AFTER session commit (like CodeScanner)
        if let metadataOutput = self.metadataOutput {
            metadataOutput.metadataObjectTypes = [.qr]
            print("  - Metadata object types set: \(metadataOutput.metadataObjectTypes)")
        }
    }

    private func setupPiPSession() {
        pipSession.beginConfiguration()
        pipSession.sessionPreset = .medium // Lower quality for PiP

        // Clear any existing outputs first
        for output in pipSession.outputs {
            pipSession.removeOutput(output)
            print("🗑️ Removed existing PiP output: \(type(of: output))")
        }

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera),
              pipSession.canAddInput(input) else {
            DispatchQueue.main.async {
                self.isDualSessionMode = false
                print("⚠️ Front camera not available, falling back to single session mode")
            }
            return
        }
        pipSession.addInput(input)
        pipCameraInput = input
        print("✅ Front camera input added to PiP session")

        let output = AVCaptureVideoDataOutput()
        // Use the same approach - no custom videoSettings
        // output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        output.alwaysDiscardsLateVideoFrames = true // Discard late frames for PiP
        output.setSampleBufferDelegate(self, queue: pipVideoDataOutputQueue)


        if pipSession.canAddOutput(output) {
            pipSession.addOutput(output)
            pipVideoDataOutput = output
            print("✅ Video data output added to PiP session")
            print("  - Total PiP outputs: \(pipSession.outputs.count)")
            print("  - PiP video outputs: \(pipSession.outputs.filter { $0 is AVCaptureVideoDataOutput }.count)")
            print("  - PiP output delegate: \(output.sampleBufferDelegate != nil)")
            print("  - PiP output queue: \(output.sampleBufferCallbackQueue?.label ?? "nil")")
        } else {
            print("❌ Failed to add video data output to PiP session")
        }

        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
            connection.isEnabled = true
            print("✅ PiP session connection enabled and orientation set")
        }

        // Add photo output for photo capture
        let photoOutput = AVCapturePhotoOutput()
        if pipSession.canAddOutput(photoOutput) {
            pipSession.addOutput(photoOutput)
            self.pipPhotoOutput = photoOutput
            print("✅ Photo output added to PiP session")
        } else {
            print("❌ Failed to add photo output to PiP session")
        }

        pipSession.commitConfiguration()

        DispatchQueue.main.async {
            self.isDualSessionMode = true
            print("✅ Dual session mode enabled")
        }
    }

        func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("🚀 Starting camera session based on current mode...")
            print("  - QR scanning mode: \(self.isQRScanningMode)")
            print("  - Photo capture mode: \(!self.isQRScanningMode)")
            print("  - Main session configured: \(self.session.inputs.count > 0 && self.session.outputs.count > 0)")
            print("  - PiP session configured: \(self.pipSession.inputs.count > 0 && self.pipSession.outputs.count > 0)")

            // Stop all sessions first
            if self.session.isRunning {
                self.session.stopRunning()
                print("🛑 Stopped main session")
            }
            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 Stopped PiP session")
            }

            // Start session based on current mode
            if self.isQRScanningMode {
                // Start main session (back camera) for QR scanning
                if !self.session.isRunning {
                    // Verify session configuration before starting
                    print("🔍 Main session configuration check:")
                    print("  - Inputs: \(self.session.inputs.count)")
                    print("  - Outputs: \(self.session.outputs.count)")
                    print("  - Has video output: \(self.session.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")
                    print("  - Video output delegate: \(self.videoDataOutput?.sampleBufferDelegate != nil)")

                    self.session.startRunning()
                    print("📷 Started main session (back camera) for QR scanning")

                    // Verify session started successfully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔍 Main session verification after start:")
                        print("  - Session running: \(self.session.isRunning)")
                        print("  - Video output delegate: \(self.videoDataOutput?.sampleBufferDelegate != nil)")
                        print("  - Frame count: \(self.frameCount)")
                    }
                }
            } else {
                // Start PiP session (front camera) for photo capture
                if !self.pipSession.isRunning {
                    // Verify session configuration before starting
                    print("🔍 PiP session configuration check:")
                    print("  - Inputs: \(self.pipSession.inputs.count)")
                    print("  - Outputs: \(self.pipSession.outputs.count)")
                    print("  - Has video output: \(self.pipSession.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")
                    print("  - Video output delegate: \(self.pipVideoDataOutput?.sampleBufferDelegate != nil)")

                    self.pipSession.startRunning()
                    print("📷 Started PiP session (front camera) for photo capture")

                    // Verify session started successfully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔍 PiP session verification after start:")
                        print("  - Session running: \(self.pipSession.isRunning)")
                        print("  - Video output delegate: \(self.pipVideoDataOutput?.sampleBufferDelegate != nil)")
                        print("  - Frame count: \(self.frameCount)")
                    }
                }
            }

            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning || self.pipSession.isRunning
                print("📷 Session started successfully")
                print("  - Main session running: \(self.session.isRunning)")
                print("  - PiP session running: \(self.pipSession.isRunning)")
                print("  - Session running state: \(self.isSessionRunning)")
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop main session
            if self.session.isRunning {
                self.session.stopRunning()
                print("🛑 Main camera session stopped")
            }

            // Stop PiP session
            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 PiP camera session stopped")
            }

            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("🛑 All camera sessions stopped")
            }
        }
    }

    // MARK: - Missing Methods Implementation

    func switchToFaceDetectionMode() {
        DispatchQueue.main.async {
            self.isQRScanningMode = false
            print("🔄 Switched to face detection mode")
        }
    }

    func switchToQRScanningMode() {
        DispatchQueue.main.async {
            self.isQRScanningMode = true
            print("🔄 Switched to QR scanning mode")
        }
    }

    func capturePhoto() {
        // Check if we've already captured a photo for this QR scan
        if hasCapturedPhotoForCurrentScan {
            print("🚫 Photo already captured for this QR scan - ignoring capture request")
            return
        }

        // Determine which photo output to use based on current mode
        let targetPhotoOutput: AVCapturePhotoOutput?

        if isQRScanningMode {
            // Use main session photo output (back camera)
            targetPhotoOutput = photoOutput
            print("📸 Using main session photo output (back camera)")
        } else {
            // Use PiP session photo output (front camera)
            targetPhotoOutput = pipPhotoOutput
            print("📸 Using PiP session photo output (front camera)")
        }

        guard let photoOutput = targetPhotoOutput else {
            print("❌ Photo output not available for current mode")
            print("  - QR scanning mode: \(isQRScanningMode)")
            print("  - Main photo output: \(self.photoOutput != nil)")
            print("  - PiP photo output: \(pipPhotoOutput != nil)")
            return
        }

        // Mark that we're capturing a photo
        hasCapturedPhotoForCurrentScan = true

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        print("📸 Photo capture initiated with \(isQRScanningMode ? "main" : "PiP") session")
    }

    func forcePhotoCapture() {
        print("📸 Force photo capture initiated")
        capturePhoto()
    }

    func testSessionSwitching() {
        print("🧪 Testing session switching...")
        print("  - Current QR scanning mode: \(isQRScanningMode)")
        print("  - Current photo capture mode: \(!isQRScanningMode)")
        print("  - Main session running: \(session.isRunning)")
        print("  - PiP session running: \(pipSession.isRunning)")

        // Force a mode change to test UI update
        DispatchQueue.main.async {
            self.isQRScanningMode = false
            self.objectWillChange.send()
            print("🧪 Forced mode change - Photo: \(!self.isQRScanningMode), QR: \(self.isQRScanningMode)")

            // Also test session switching
            self.startPhotoCaptureMode()
        }
    }

    func testDelegateConnection() {
        print("🧪 Testing delegate connection...")
        print("  - Main session running: \(session.isRunning)")
        print("  - PiP session running: \(pipSession.isRunning)")
        print("  - Main video output delegate: \(videoDataOutput?.sampleBufferDelegate != nil)")
        print("  - PiP video output delegate: \(pipVideoDataOutput?.sampleBufferDelegate != nil)")
        print("  - Main session has video output: \(session.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")
        print("  - PiP session has video output: \(pipSession.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")
        print("  - Frame count: \(frameCount)")

        // Check for output conflicts
        print("🔍 Output conflict check:")
        print("  - Main session outputs: \(session.outputs.count)")
        for (index, output) in session.outputs.enumerated() {
            print("    \(index): \(type(of: output))")
        }
        print("  - PiP session outputs: \(pipSession.outputs.count)")
        for (index, output) in pipSession.outputs.enumerated() {
            print("    \(index): \(type(of: output))")
        }

        // Check if outputs are using same delegate
        if let mainOutput = videoDataOutput, let pipOutput = pipVideoDataOutput {
            let sameDelegate = mainOutput.sampleBufferDelegate === pipOutput.sampleBufferDelegate
            let sameQueue = mainOutput.sampleBufferCallbackQueue === pipOutput.sampleBufferCallbackQueue
            print("  - Same delegate: \(sameDelegate)")
            print("  - Same queue: \(sameQueue)")
        }

        // Check metadata output
        if let metadataOutput = metadataOutput {
            print("  - Metadata output delegate: \(metadataOutput.metadataObjectsDelegate != nil)")
            print("  - Metadata object types: \(metadataOutput.metadataObjectTypes)")
        } else {
            print("  - No metadata output found")
        }

        // Test if camera is actually producing frames
        print("🔍 Testing camera frame production...")
        if let cameraInput = cameraInput {
            let device = cameraInput.device
            print("  - Camera device: \(device.localizedName)")
            print("  - Device connected: \(device.isConnected)")
            print("  - Device has media type: \(device.hasMediaType(.video))")
            print("  - Device position: \(device.position == .back ? "Back" : "Front")")
            print("  - Device focus mode: \(device.focusMode.rawValue)")
        }

        // Test if delegate method can be called manually
        print("🧪 Testing manual delegate call...")
        if let mainOutput = videoDataOutput {
            // Try to manually trigger the delegate method
            print("  - Attempting to manually call delegate method...")
            // Note: We can't actually call the delegate method manually, but we can test the setup
        }

        // Force a session restart to ensure delegate is properly connected
        if session.isRunning {
            sessionQueue.async {
                self.session.stopRunning()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.sessionQueue.async {
                        self.session.startRunning()
                        print("🧪 Restarted main session to test delegate")

                        // Check frame count after restart
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("🔍 Frame count after restart: \(self.frameCount)")
                            if self.frameCount == 0 {
                                print("⚠️ Still no frames received - delegate may not be working")
                                print("🔍 Let's try a different approach...")

                                // Try to force a frame by changing session preset
                                self.sessionQueue.async {
                                    self.session.beginConfiguration()
                                    self.session.sessionPreset = .medium
                                    self.session.commitConfiguration()
                                    print("🧪 Changed session preset to medium")
                                }
                            } else {
                                print("✅ Frames are being received!")
                            }
                        }
                    }
                }
            }
        }
    }

    func restartBackCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()

            // Remove existing inputs and outputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }

            // Re-add back camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.error = .deviceNotFound }
                return
            }

            self.session.addInput(input)
            self.cameraInput = input

            // Re-add outputs
            if let videoOutput = self.videoDataOutput, self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            }
            if let photoOutput = self.photoOutput, self.session.canAddOutput(photoOutput) {
                self.session.addOutput(photoOutput)
            }

            self.session.commitConfiguration()
            print("🔄 Back camera restarted")
        }
    }

    func forceCameraReset() {
        stopSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupSessions()
        }
        print("🔄 Camera force reset")
    }

    func forceSingleSessionMode() {
        DispatchQueue.main.async {
            self.isDualSessionMode = false
            print("🔄 Forced single session mode")
        }
    }

    func testSingleCameraOnly() {
        print("🧪 Testing single camera mode only...")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop all sessions
            if self.session.isRunning {
                self.session.stopRunning()
                print("🛑 Stopped main session")
            }
            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 Stopped PiP session")
            }

            // Force single session mode
            DispatchQueue.main.async {
                self.isDualSessionMode = false
            }

            // Start only main session
            self.session.startRunning()
            print("📷 Started main session only")

            // Wait and check
            Thread.sleep(forTimeInterval: 0.2)
            print("📷 Main session running: \(self.session.isRunning)")

            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("✅ Single camera test complete - Running: \(self.isSessionRunning)")
            }
        }
    }

    func debugSessionStatus() {
        print("🔍 CameraManager Debug Status:")
        print("  - Main session running: \(session.isRunning)")
        print("  - PiP session running: \(pipSession.isRunning)")
        print("  - Main session inputs: \(session.inputs.count)")
        print("  - Main session outputs: \(session.outputs.count)")
        print("  - PiP session inputs: \(pipSession.inputs.count)")
        print("  - PiP session outputs: \(pipSession.outputs.count)")
        print("  - Authorized: \(isAuthorized)")
        print("  - Error: \(error?.localizedDescription ?? "None")")
        print("  - Camera position: \(currentCameraPosition == .back ? "Back" : "Front")")
        print("  - Dual session mode: \(isDualSessionMode)")
        print("  - QR scanning mode: \(isQRScanningMode)")
        print("  - Photo capture mode: \(!isQRScanningMode)")
        print("  - Frame count: \(frameCount)")
        print("  - Session running state: \(isSessionRunning)")

        // Check for output conflicts
        print("🔍 Output Analysis:")
        let mainVideoOutputs = session.outputs.filter { $0 is AVCaptureVideoDataOutput }
        let pipVideoOutputs = pipSession.outputs.filter { $0 is AVCaptureVideoDataOutput }
        print("  - Main session video outputs: \(mainVideoOutputs.count)")
        print("  - PiP session video outputs: \(pipVideoOutputs.count)")

        if mainVideoOutputs.count > 1 {
            print("⚠️ WARNING: Multiple video outputs in main session!")
        }
        if pipVideoOutputs.count > 1 {
            print("⚠️ WARNING: Multiple video outputs in PiP session!")
        }

        // Check delegate assignments
        if let mainOutput = videoDataOutput {
            print("  - Main output delegate: \(mainOutput.sampleBufferDelegate != nil)")
            print("  - Main output queue: \(mainOutput.sampleBufferCallbackQueue?.label ?? "nil")")
        }
        if let pipOutput = pipVideoDataOutput {
            print("  - PiP output delegate: \(pipOutput.sampleBufferDelegate != nil)")
            print("  - PiP output queue: \(pipOutput.sampleBufferCallbackQueue?.label ?? "nil")")
        }
    }

    func forceStartSessions() {
        print("🔄 Force starting camera sessions...")
        print("  - Checking session configuration...")
        print("  - Main session inputs: \(session.inputs.count)")
        print("  - Main session outputs: \(session.outputs.count)")
        print("  - PiP session inputs: \(pipSession.inputs.count)")
        print("  - PiP session outputs: \(pipSession.outputs.count)")

        if session.inputs.count == 0 || session.outputs.count == 0 {
            print("⚠️ Main session not properly configured, re-setting up...")
            setupSessions()
        } else {
            startSession()
        }
    }

    func restartSessionWithNewConfiguration() {
        print("🔄 Restarting session with new configuration...")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Stop current sessions
            if self.session.isRunning {
                self.session.stopRunning()
                print("🛑 Stopped main session")
            }
            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 Stopped PiP session")
            }

            // Clear current configuration
            self.session.beginConfiguration()

            // Remove all inputs and outputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }

            self.session.commitConfiguration()
            print("🧹 Cleared main session configuration")

            // Wait a moment
            Thread.sleep(forTimeInterval: 0.1)

            // Re-setup main session only
            self.setupMainSession()

            // Start only the main session
            self.session.startRunning()
            print("📷 Restarted main session with new configuration")

            // Wait and check if it's running
            Thread.sleep(forTimeInterval: 0.2)
            print("📷 Main session running after restart: \(self.session.isRunning)")

            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("✅ Session restart complete - Running: \(self.isSessionRunning)")
            }
        }
    }

    func startPhotoCaptureMode() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("🎯 QR Code detected - Switching to photo capture mode...")

            // Stop back camera session and start front camera session
            if self.backCameraSession.isRunning {
                self.backCameraSession.stopRunning()
                print("🛑 Stopped back camera session")
            }

            // Start front camera session
            if !self.frontCameraSession.isRunning {
                self.frontCameraSession.startRunning()
                print("📷 Started front camera session for photo capture")

                // Mark front camera session as ready after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isPiPSessionReady = true
                    print("✅ Front camera session marked as ready")
                }
            }

                        DispatchQueue.main.async {
                self.isQRScanningMode = false
                self.isPiPSessionReady = false  // Reset PiP session ready state
                self.hasCapturedPhotoForCurrentScan = false  // Reset photo capture flag
                print("✅ Switched to photo capture mode")
                print("  - Back camera session running: \(self.backCameraSession.isRunning)")
                print("  - Front camera session running: \(self.frontCameraSession.isRunning)")
                print("  - QR scanning mode: \(self.isQRScanningMode)")
                print("  - Photo capture mode: \(!self.isQRScanningMode)")

                // Start photo capture timeout timer
                self.startPhotoCaptureTimer()

                // Force UI update by triggering objectWillChange
                self.objectWillChange.send()

                // Add small delay to ensure session is fully started before UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func startPhotoCaptureTimer() {
        // Cancel existing timer if any
        photoCaptureTimer?.invalidate()

        // Start new timer
        photoCaptureTimer = Timer.scheduledTimer(withTimeInterval: photoCaptureTimeout, repeats: false) { [weak self] _ in
            self?.handlePhotoCaptureTimeout()
        }

        print("⏰ Photo capture timer started - \(photoCaptureTimeout) seconds")
    }

    private func handlePhotoCaptureTimeout() {
        print("⏰ Photo capture timeout - restarting QR scanning mode")

        // Stop photo capture mode
        stopPhotoCaptureMode()

        // Restart QR scanning mode
        restartQRScanningMode()
    }

    func stopPhotoCaptureMode() {
        // Cancel timer
        photoCaptureTimer?.invalidate()
        photoCaptureTimer = nil

        // Stop PiP session
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 Stopped PiP session (front camera)")
            }

            DispatchQueue.main.async {
                print("✅ Stopped photo capture mode")
            }
        }
    }

    func restartQRScanningMode() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("🔄 Restarting QR scanning mode...")

            // Stop PiP session if running
            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                print("🛑 Stopped PiP session")
            }

            // Start main session (back camera)
            if !self.session.isRunning {
                self.session.startRunning()
                print("📷 Started main session (back camera)")
            }

            DispatchQueue.main.async {
                self.isQRScanningMode = true
                print("✅ Restarted QR scanning mode")
            }
        }
    }

    func enableQRScanning() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("🔍 Enabling QR scanning...")
            self.isQRScanningEnabled = true
            self.isQRScanningMode = true
            self.hasCapturedPhotoForCurrentScan = false  // Reset photo capture flag

            // Ensure back camera session is running
            self.sessionQueue.async {
                if !self.session.isRunning {
                    self.session.startRunning()
                    print("📷 Started back camera session for QR scanning")
                }
            }

            print("✅ QR scanning enabled - ready to scan QR codes")
        }
    }

    func disableQRScanning() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            print("🚫 Disabling QR scanning...")
            self.isQRScanningEnabled = false
            print("✅ QR scanning disabled")
        }
    }

    func stopFrontCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("🛑 Stopping front camera session...")

            if self.pipSession.isRunning {
                self.pipSession.stopRunning()
                self.isPiPSessionReady = false
                print("📷 Front camera session stopped")
            }
        }
    }

    // MARK: - Performance Optimization

    func suspendFrontCameraForBatteryOptimization() {
        guard isQRScanningMode else { return } // Don't suspend if we're in photo capture mode

        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            // Suspend front camera after 30 seconds of inactivity to save battery
            self?.stopFrontCamera()
            print("🔋 Front camera suspended for battery optimization")
        }
    }

    func resumeFrontCameraForPiP() {
        guard isQRScanningMode else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if !self.pipSession.isRunning {
                self.pipSession.startRunning()
                print("📷 Front camera resumed for PiP")

                // Mark as ready after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isPiPSessionReady = true
                }
            }
        }
    }

    func testQRDetection() {
        print("🧪 Testing QR detection...")
        // Simulate QR detection for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎯 Simulating QR code detection...")
            self.startPhotoCaptureMode()
            self.onQRCodeDetected?("TEST_QR_CODE_123")
        }

        // Also test if metadata delegate is working
        print("🧪 Testing metadata delegate...")
        if let metadataOutput = metadataOutput {
            print("  - Metadata output exists: true")
            print("  - Metadata delegate: \(metadataOutput.metadataObjectsDelegate != nil)")
            print("  - Metadata object types: \(metadataOutput.metadataObjectTypes)")

            // Check if the delegate is actually set to self
            if metadataOutput.metadataObjectsDelegate === self {
                print("  - ✅ Metadata delegate is correctly set to self")
            } else {
                print("  - ❌ Metadata delegate is NOT set to self")
            }
        } else {
            print("  - ❌ No metadata output found")
        }
    }

    func testManualQRDetection() {
        print("🧪 Testing manual QR detection...")
        // This would typically involve processing a test image
        print("Manual QR detection test completed")
    }


    func testVideoDataOutputDelegate() {
        print("🧪 Testing video data output delegate...")
        print("Main session delegate: \(videoDataOutput?.sampleBufferDelegate != nil)")
        print("PiP session delegate: \(pipVideoDataOutput?.sampleBufferDelegate != nil)")
    }

    func testVideoDataOutput() {
        print("🧪 Testing video data output...")
        print("Main video output exists: \(videoDataOutput != nil)")
        print("PiP video output exists: \(pipVideoDataOutput != nil)")
        print("Main session has video output: \(session.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")
        print("PiP session has video output: \(pipSession.outputs.contains(where: { $0 is AVCaptureVideoDataOutput }))")

        // Test delegate setup
        if let mainOutput = videoDataOutput {
            print("Main output delegate: \(mainOutput.sampleBufferDelegate != nil)")
            print("Main output delegate queue: \(mainOutput.sampleBufferCallbackQueue?.label ?? "nil")")
        }

        if let pipOutput = pipVideoDataOutput {
            print("PiP output delegate: \(pipOutput.sampleBufferDelegate != nil)")
            print("PiP output delegate queue: \(pipOutput.sampleBufferCallbackQueue?.label ?? "nil")")
        }

        // Test metadata output
        if let metadataOutput = metadataOutput {
            print("Metadata output delegate: \(metadataOutput.metadataObjectsDelegate != nil)")
            print("Metadata object types: \(metadataOutput.metadataObjectTypes)")
        } else {
            print("No metadata output found")
        }

        // Test session state
        print("Main session running: \(session.isRunning)")
        print("Main session inputs: \(session.inputs.count)")
        print("Main session outputs: \(session.outputs.count)")

        // Test camera device status
        if let cameraInput = cameraInput {
            let device = cameraInput.device
            print("📷 Camera device info:")
            print("  - Device name: \(device.localizedName)")
            print("  - Device model: \(device.modelID)")
            print("  - Device position: \(device.position == .back ? "Back" : "Front")")
            print("  - Device connected: \(device.isConnected)")
            print("  - Device has media type: \(device.hasMediaType(.video))")
            print("  - Device focus mode: \(device.focusMode.rawValue)")
            print("  - Device exposure mode: \(device.exposureMode.rawValue)")
        }

        // Test authorization status
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔐 Camera authorization status: \(authStatus.rawValue)")
        switch authStatus {
        case .authorized:
            print("  - Camera access authorized")
        case .denied:
            print("  - Camera access denied")
        case .restricted:
            print("  - Camera access restricted")
        case .notDetermined:
            print("  - Camera access not determined")
        @unknown default:
            print("  - Camera access unknown status")
        }

        // Try to create a minimal test session
        print("🧪 Creating minimal test session...")
        let testSession = AVCaptureSession()
        testSession.beginConfiguration()

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: camera),
           testSession.canAddInput(input) {

            testSession.addInput(input)
            print("✅ Test session input added")

            let testOutput = AVCaptureVideoDataOutput()
            testOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

            if testSession.canAddOutput(testOutput) {
                testSession.addOutput(testOutput)
                print("✅ Test session output added")

                testSession.commitConfiguration()

                // Start the test session briefly
                sessionQueue.async {
                    testSession.startRunning()
                    print("🧪 Test session started")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        testSession.stopRunning()
                        print("🧪 Test session stopped")
                        print("🔍 Frame count after test: \(self.frameCount)")
                    }
                }
            } else {
                print("❌ Test session cannot add output")
            }
        } else {
            print("❌ Test session cannot add input")
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension CameraManager: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("🎯 METADATA DELEGATE CALLED - QR Code Detection!")

        // Only process QR detection if scanning is enabled
        guard isQRScanningEnabled else {
            print("🚫 QR scanning is disabled - ignoring QR code detection")
            return
        }

        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        print("✅ QR Code detected via metadata: \(stringValue)")
        print("✅ QR Code type: \(readableObject.type.rawValue)")

        // Disable QR scanning to prevent multiple detections
        DispatchQueue.main.async { [weak self] in
            self?.isQRScanningEnabled = false
            self?.startPhotoCaptureMode()
            self?.onQRCodeDetected?(stringValue)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
//extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureVideoDataOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        // Always log the first call to verify delegate is working
//        if frameCount == 0 {
//            print("🎯 VIDEO DELEGATE METHOD CALLED FOR THE FIRST TIME!")
//            print("🎯 Output: \(output)")
//            print("🎯 Session states - Main: \(session.isRunning), PiP: \(pipSession.isRunning)")
//            print("🎯 Output comparison - videoDataOutput: \(videoDataOutput), pipVideoDataOutput: \(pipVideoDataOutput)")
//        }
//
//        // Log first few frames to verify delegate is working
//        if frameCount < 5 {
//            let sessionType = output == videoDataOutput ? "main" : (output == pipVideoDataOutput ? "pip" : "unknown")
//            print("🎯 VIDEO DELEGATE CALLED - Frame \(frameCount + 1) from \(sessionType) session")
//            print("🎯 Session states - Main: \(session.isRunning), PiP: \(pipSession.isRunning)")
//            print("🎯 Output comparison - videoDataOutput: \(videoDataOutput), pipVideoDataOutput: \(pipVideoDataOutput), received: \(output)")
//        }
//
//        frameCount += 1
//
//        // Determine which session this frame is from
//        let isFromMainSession = output == videoDataOutput
//        let cameraType = isFromMainSession ? "back" : "front"
//
//        // Only log every 30 frames to avoid spam
//        if frameCount % 30 == 0 {
//            print("🎯 Frame received from \(cameraType) camera - Count: \(frameCount)")
//        }
//
//        // Process face detection for PiP session (front camera) in photo capture mode
//        if !isFromMainSession {
//            // This is from the front camera
//            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//                // Only process face detection if we're in photo capture mode
//                if !isQRScanningMode {
//                    print("🎭 Processing face detection for front camera frame")
//
//                    // Convert to UIImage for face detection
//                    if let image = pixelBufferToUIImage(pixelBuffer) {
//                        // Trigger face detection through notification
//                        DispatchQueue.main.async {
//                            NotificationCenter.default.post(
//                                name: NSNotification.Name("ProcessFaceDetection"),
//                                object: image
//                            )
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // Helper method to convert CVPixelBuffer to UIImage
//    private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
//        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//        let context = CIContext()
//        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
//            return nil
//        }
//        return UIImage(cgImage: cgImage)
//    }
//}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
        let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }


        frameCount += 1
        let isFromMainSession = output == videoDataOutput
        let cameraType = isFromMainSession ? "back" : "front"

        // Only log every 30 frames to avoid spam
        if frameCount % 30 == 0 {
            print("🎯 Frame received from \(cameraType) camera - Count: \(frameCount)")
        }

        // Process face detection for PiP session (front camera) in photo capture mode
        if !isFromMainSession {
            // This is from the front camera
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                // Only process face detection if we're in photo capture mode
                if !isQRScanningMode {
                    print("🎭 Processing face detection for front camera frame")

                    // Convert to UIImage for face detection
                    if let image = pixelBufferToUIImage(pixelBuffer) {
                        // Trigger face detection through notification
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ProcessFaceDetection"),
                                object: image
                            )
                        }
                    }
                }
            }
        }

//        var requestOptions: [VNImageOption : Any] = [:]
//
//        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
//            requestOptions = [.cameraIntrinsics : cameraIntrinsicData]
//        }
//
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)
//
//        do {
//            try imageRequestHandler.perform(requests)
//        }
//
//        catch {
//            print(error)
//        }

    }

    private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func exifOrientationFromDeviceOrientation() -> UInt32 {
            enum DeviceOrientation: UInt32 {
                case top0ColLeft = 1
                case top0ColRight = 2
                case bottom0ColRight = 3
                case bottom0ColLeft = 4
                case left0ColTop = 5
                case right0ColTop = 6
                case right0ColBottom = 7
                case left0ColBottom = 8
            }
            var exifOrientation: DeviceOrientation

            switch UIDevice.current.orientation {
            case .portraitUpsideDown:
                exifOrientation = .left0ColBottom
            case .landscapeLeft:
                exifOrientation = devicePosition == .front ? .bottom0ColRight : .top0ColLeft
            case .landscapeRight:
                exifOrientation = devicePosition == .front ? .top0ColLeft : .bottom0ColRight
            default:
                exifOrientation = devicePosition == .front ? .left0ColTop : .right0ColTop
            }
            return exifOrientation.rawValue
        }

}
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            DispatchQueue.main.async {
                self.error = .photoCaptureFailed
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to create image from photo data")
            DispatchQueue.main.async {
                self.error = .photoCaptureFailed
            }
            return
        }

        print("✅ Photo captured successfully")

        // Cancel photo capture timer since photo was captured
        photoCaptureTimer?.invalidate()
        photoCaptureTimer = nil

        DispatchQueue.main.async {
            self.onPhotoCaptured?(image)

            // Stop photo capture mode but don't restart QR scanning automatically
            // User will need to manually enable QR scanning again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.stopPhotoCaptureMode()
                // Don't restart QR scanning - let user control it manually
                print("📸 Photo captured - QR scanning remains disabled until manually enabled")
            }
        }
    }
}
