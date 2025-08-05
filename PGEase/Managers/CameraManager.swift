import AVFoundation
import UIKit
import Combine
import Vision

class CameraManager: NSObject, ObservableObject {
    // Add a unique identifier to track instances
    private let instanceId = UUID()

    @Published var isSessionRunning = false
    @Published var isAuthorized = false
    @Published var error: CameraError?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var isDualSessionMode = false
    @Published var isQRScanningMode = true // true = QR scanning, false = face detection

    // Debug counters
    var frameCount = 0 // Made public for debugging

    private let backSession = AVCaptureSession()
    private let frontSession = AVCaptureSession()
    private let qrDetectionSession = AVCaptureSession() // Separate session for QR detection
    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let videoDataOutputQueue = DispatchQueue(label: "video.data.output.queue", qos: .userInitiated)

    // Camera inputs and outputs
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var qrDetectionInput: AVCaptureDeviceInput?
    private var backVideoDataOutput: AVCaptureVideoDataOutput?
    private var frontVideoDataOutput: AVCaptureVideoDataOutput?
    var qrVideoDataOutput: AVCaptureVideoDataOutput? // Made public for debugging
    private var photoOutput: AVCapturePhotoOutput?

    // Public access to sessions for preview layers
    var backCameraSession: AVCaptureSession { return backSession }
    var frontCameraSession: AVCaptureSession { return frontSession }

    // Computed property to get the current QR scanning session
    var currentQRSession: AVCaptureSession {
        return currentCameraPosition == .back ? backSession : frontSession
    }

    // Check if device supports dual camera sessions
    private func checkDualSessionSupport() -> Bool {
        // Most devices have issues with dual camera sessions
        // Let's use single session mode by default
        return false
    }

    // Setup QR detection session
    private func setupQRDetectionSession() {
        print("Setting up QR detection session...")

        // Use the existing backVideoDataOutput for QR detection
        // No need to add a separate QR detection output - this avoids conflicts
        self.qrVideoDataOutput = self.backVideoDataOutput
        print("QR detection will use existing back camera video data output")

        // Ensure the delegate is set for QR detection
        if let backVideoOutput = self.backVideoDataOutput {
            // Don't set the delegate again if it's already set
            if backVideoOutput.sampleBufferDelegate == nil {
                backVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
                print("QR detection delegate set on back camera video data output - Instance: \(instanceId)")
            } else {
                print("QR detection delegate already set on back camera video data output - Instance: \(instanceId)")
            }

            if let connection = backVideoOutput.connection(with: .video) {
                connection.isEnabled = true
                print("QR detection video connection enabled")

                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                    print("QR detection video orientation set to portrait")
                }
            }
        }

        print("QR detection setup completed")

        // Verify the video data output is in the session
        if let backVideoOutput = self.backVideoDataOutput {
            let isInSession = self.backSession.outputs.contains(backVideoOutput)
            print("Video data output in session: \(isInSession)")
            print("Session outputs: \(self.backSession.outputs.count)")

            // Check if the output is actually configured for video data
            print("Video data output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            print("Video data output queue: \(backVideoOutput.sampleBufferCallbackQueue != nil ? "set" : "not set")")
            print("Video data output settings: \(backVideoOutput.videoSettings)")
        }
    }

    // Debug method to check session status
    func debugSessionStatus() {
        print("📊 Camera Status:")
        print("  Back session: \(backSession.isRunning ? "running" : "stopped")")
        print("  Front session: \(frontSession.isRunning ? "running" : "stopped")")
        print("  Current camera: \(currentCameraPosition == .back ? "back" : "front")")
        print("  Frame count: \(frameCount)")
        print("  QR video output: \(qrVideoDataOutput != nil ? "configured" : "not configured")")

        // Check video data output status
        if let backVideoOutput = backVideoDataOutput {
            print("Back video output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if let connection = backVideoOutput.connection(with: .video) {
                print("Back video connection enabled: \(connection.isEnabled)")
            }
        }

        if let qrVideoOutput = qrVideoDataOutput {
            print("QR detection video output delegate: \(qrVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if let connection = qrVideoOutput.connection(with: .video) {
                print("QR detection video connection enabled: \(connection.isEnabled)")
            }
        }
    }

    // Force camera reset
    func forceCameraReset() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Force resetting all camera sessions...")

            // Stop all sessions
            if self.backSession.isRunning {
                self.backSession.stopRunning()
            }
            if self.frontSession.isRunning {
                self.frontSession.stopRunning()
            }

            // Wait a bit
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sessionQueue.async {
                    // Force single session mode
                    DispatchQueue.main.async {
                        self.isDualSessionMode = false
                    }
                    self.startSingleSessionMode()
                    print("Camera sessions force reset to single mode")
                }
            }
        }
    }

    // Force single session mode
    func forceSingleSessionMode() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Forcing single session mode...")

            // Stop all sessions
            if self.backSession.isRunning {
                self.backSession.stopRunning()
            }
            if self.frontSession.isRunning {
                self.frontSession.stopRunning()
            }

            DispatchQueue.main.async {
                self.isDualSessionMode = false
                self.isQRScanningMode = true
            }

            // Reconfigure back session for QR scanning only
            self.backSession.beginConfiguration()

            // Remove all outputs first
            for output in self.backSession.outputs {
                self.backSession.removeOutput(output)
            }

            // Add only video data output for QR scanning
            if let backVideoOutput = self.backVideoDataOutput {
                if self.backSession.canAddOutput(backVideoOutput) {
                    self.backSession.addOutput(backVideoOutput)
                    print("Re-added back camera video data output")

                    if let connection = backVideoOutput.connection(with: .video) {
                        connection.isEnabled = true
                        print("Re-enabled back camera video connection")

                        // Set video orientation
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                            print("Video orientation set to portrait")
                        }
                    }
                }
            }

            self.backSession.commitConfiguration()

            // Start only back camera for QR scanning
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sessionQueue.async {
                    if !self.backSession.isRunning {
                        self.backSession.startRunning()
                        print("Single session mode: Back camera started for QR scanning")

                        // Reset frame counter
                        self.frameCount = 0
                        print("Frame counter reset for single session mode")

                        // Force video connection after session start
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let backVideoOutput = self.backVideoDataOutput,
                               let connection = backVideoOutput.connection(with: .video) {
                                connection.isEnabled = true
                                print("Forced video connection enabled after session start")
                            }
                        }
                    }
                }
            }
        }
    }

    // Callbacks
    var onQRCodeDetected: ((String) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?

    enum CameraError: Error, LocalizedError {
        case notAuthorized
        case deviceNotFound
        case sessionConfigurationFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access is required for QR scanning and face detection"
            case .deviceNotFound:
                return "Camera device not found"
            case .sessionConfigurationFailed:
                return "Failed to configure camera session"
            }
        }
    }

    override init() {
        super.init()
        print("🔧 CameraManager instance created: \(instanceId)")
        checkAuthorization()
    }

    deinit {
        print("🔧 CameraManager instance deallocated: \(instanceId)")
    }

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            self.setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.error = .notAuthorized
                    }
                }
            }
        case .denied, .restricted:
            self.error = .notAuthorized
        @unknown default:
            self.error = .notAuthorized
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Setup back camera session for QR scanning
            self.backSession.beginConfiguration()

            // Use a lower quality preset that's more likely to work with video data output
            if self.backSession.canSetSessionPreset(.medium) {
                self.backSession.sessionPreset = .medium
                print("Back session preset set to medium")
            } else if self.backSession.canSetSessionPreset(.high) {
                self.backSession.sessionPreset = .high
                print("Back session preset set to high")
            } else {
                print("Using default session preset")
            }

            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                do {
                    let backInput = try AVCaptureDeviceInput(device: backCamera)
                    if self.backSession.canAddInput(backInput) {
                        self.backSession.addInput(backInput)
                        self.backCameraInput = backInput
                        print("Back camera input added successfully")
                    } else {
                        print("Failed to add back camera input")
                    }
                } catch {
                    print("Back camera input error: \(error)")
                    DispatchQueue.main.async {
                        self.error = .deviceNotFound
                    }
                    return
                }
            } else {
                print("Back camera device not found")
            }

            // Setup video data output for back camera
            let backVideoOutput = AVCaptureVideoDataOutput()

            // Use delegate approach
            backVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            print("🔧 Setting delegate on video data output - Instance: \(instanceId)")
            // Force a specific pixel format that's known to work
            backVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            backVideoOutput.alwaysDiscardsLateVideoFrames = false // Changed to false to ensure we get frames

            // Store the output before adding to session
            self.backVideoDataOutput = backVideoOutput
            print("🔧 Video data output stored before adding to session")

            if self.backSession.canAddOutput(backVideoOutput) {
                self.backSession.addOutput(backVideoOutput)
                print("Back camera video data output added successfully")
                print("Back session outputs count: \(self.backSession.outputs.count)")

                // Verify the output is actually in the session
                let isInSession = self.backSession.outputs.contains(backVideoOutput)
                print("Video data output in session: \(isInSession)")

                // Enable video data output
                if let connection = backVideoOutput.connection(with: .video) {
                    connection.isEnabled = true
                    print("Back camera video connection enabled")

                    // Set video orientation
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                        print("Video orientation set to portrait")
                    }
                }
            } else {
                print("Failed to add back camera video data output")
            }

            // Try to force the session to start video data output
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let connection = backVideoOutput.connection(with: .video) {
                    connection.isEnabled = true
                    print("Forced back camera video connection enabled after setup")
                }

                // Test if delegate is working by checking if it's set
                if let delegate = backVideoOutput.sampleBufferDelegate {
                    print("✅ Delegate is set and accessible")
                    print("Delegate type: \(type(of: delegate))")
                } else {
                    print("❌ Delegate is not set")
                }

                // Test if session is configured properly
                print("Session inputs: \(self.backSession.inputs.count)")
                print("Session outputs: \(self.backSession.outputs.count)")
                print("Session preset: \(self.backSession.sessionPreset.rawValue)")

                // Test if video data output is properly configured
                if let backVideoOutput = self.backVideoDataOutput {
                    print("Video data output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
                    print("Video data output queue: \(backVideoOutput.sampleBufferCallbackQueue != nil ? "set" : "not set")")
                    print("Video data output settings: \(backVideoOutput.videoSettings)")

                    if let connection = backVideoOutput.connection(with: .video) {
                        print("Video connection enabled: \(connection.isEnabled)")
                        print("Video connection active: \(connection.isActive)")
                    }

                    // Test if the delegate is properly set
                    print("Testing delegate configuration...")
                    if let delegate = backVideoOutput.sampleBufferDelegate {
                        print("✅ Delegate is properly set and accessible")
                        print("Delegate type: \(type(of: delegate))")
                    } else {
                        print("❌ Delegate is not set")
                    }
                }

                // Force the session to reconfigure and restart video data output
                print("🔄 Forcing session reconfiguration...")
                self.backSession.beginConfiguration()
                self.backSession.commitConfiguration()
                print("🔄 Session reconfigured")

                // Force the video data output to start
                if let backVideoOutput = self.backVideoDataOutput {
                    if let connection = backVideoOutput.connection(with: .video) {
                        connection.isEnabled = true
                        print("🔄 Forced video connection enabled after reconfiguration")
                    }

                    // Test if the video data output is actually working
                    print("🔄 Testing video data output...")
                    print("Video data output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
                    print("Video data output queue: \(backVideoOutput.sampleBufferCallbackQueue != nil ? "set" : "not set")")
                    print("Video data output settings: \(backVideoOutput.videoSettings)")

                    // Force the session to start video data output
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🔄 Attempting to force video data output to start...")
                        if let connection = backVideoOutput.connection(with: .video) {
                            connection.isEnabled = true
                            print("🔄 Video connection force-enabled after delay")
                        }

                        // Test if the session is actually running
                        print("🔄 Session running status: \(self.backSession.isRunning)")
                        print("🔄 Session inputs count: \(self.backSession.inputs.count)")
                        print("🔄 Session outputs count: \(self.backSession.outputs.count)")

                        // Test if the video data output is actually in the session
                        if let backVideoOutput = self.backVideoDataOutput {
                            let isInSession = self.backSession.outputs.contains(backVideoOutput)
                            print("🔄 Video data output in session: \(isInSession)")
                        }
                    }
                }
            }

            // Temporarily disable photo output to focus on video data output
            /*
            let photoOutput = AVCapturePhotoOutput()
            if self.backSession.canAddOutput(photoOutput) {
                self.backSession.addOutput(photoOutput)
                self.photoOutput = photoOutput
                print("Back camera photo output added successfully for testing")
            } else {
                print("Failed to add back camera photo output")
            }
            */
            print("Photo output disabled to focus on video data output")

            // Temporarily enable QR detection setup to test if it helps
            self.setupQRDetectionSession()
            print("QR detection setup enabled for testing")

            self.backSession.commitConfiguration()
            print("Back session configuration completed")

            // Setup front camera session for face detection with lower quality
            self.frontSession.beginConfiguration()

            // Use lower quality preset to reduce resource usage
            if self.frontSession.canSetSessionPreset(.low) {
                self.frontSession.sessionPreset = .low
            }

            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                do {
                    let frontInput = try AVCaptureDeviceInput(device: frontCamera)
                    if self.frontSession.canAddInput(frontInput) {
                        self.frontSession.addInput(frontInput)
                        self.frontCameraInput = frontInput
                        print("Front camera input added successfully")
                    } else {
                        print("Cannot add front camera input to session")
                    }
                } catch {
                    print("Front camera not available: \(error)")
                }
            } else {
                print("Front camera device not found")
            }

            // Setup video data output for front camera with lower quality
            let frontVideoOutput = AVCaptureVideoDataOutput()
            frontVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            frontVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            if self.frontSession.canAddOutput(frontVideoOutput) {
                self.frontSession.addOutput(frontVideoOutput)
                self.frontVideoDataOutput = frontVideoOutput
                print("Front camera output added successfully")
            } else {
                print("Cannot add front camera output to session")
            }

            self.frontSession.commitConfiguration()
            print("Front session configuration completed")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startSession()
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Check device compatibility
            let supportsDualSessions = self.checkDualSessionSupport()

            DispatchQueue.main.async {
                self.isDualSessionMode = supportsDualSessions
            }

            if supportsDualSessions {
                // Dual session mode - try to run both simultaneously
                self.startDualSessionMode()
            } else {
                // Single session mode - start with back camera only
                self.startSingleSessionMode()
            }
        }
    }

    private func startDualSessionMode() {
        // Start back camera session first (primary for QR scanning)
        if !self.backSession.isRunning {
            self.backSession.startRunning()
            print("Dual mode: Back camera session started")

            // Force video data output to start receiving frames
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sessionQueue.async {
                    if let backVideoOutput = self.backVideoDataOutput,
                       let connection = backVideoOutput.connection(with: .video) {
                        connection.isEnabled = true
                        print("Back camera video connection re-enabled after session start")
                    }
                }
            }
        }

        // Add a delay before starting front camera to prevent conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sessionQueue.async {
                if !self.frontSession.isRunning {
                    self.frontSession.startRunning()
                    print("Dual mode: Front camera session started with delay")
                }
            }
        }

        DispatchQueue.main.async {
            self.isSessionRunning = true
            print("Dual session mode activated")
        }
    }

    private func startSingleSessionMode() {
        // Start only back camera session for QR scanning
        if !self.backSession.isRunning {
            self.backSession.startRunning()
            print("Single mode: Back camera session started")

            // Force video data output to start receiving frames
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sessionQueue.async {
                    if let backVideoOutput = self.backVideoDataOutput,
                       let connection = backVideoOutput.connection(with: .video) {
                        connection.isEnabled = true
                        print("Single mode: Back camera video connection re-enabled")
                    }

                    // Reset frame counter
                    self.frameCount = 0
                    print("Single mode: Frame counter reset")
                }
            }
        }

        DispatchQueue.main.async {
            self.isSessionRunning = true
            self.isQRScanningMode = true
            print("Single session mode activated - QR scanning mode")
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.backSession.isRunning {
                self.backSession.stopRunning()
            }
            if self.frontSession.isRunning {
                self.frontSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Toggle camera position
            let newPosition: AVCaptureDevice.Position = self.currentCameraPosition == .back ? .front : .back

            DispatchQueue.main.async {
                self.currentCameraPosition = newPosition
            }

            print("Switched to \(newPosition == .back ? "back" : "front") camera for QR scanning")
        }
    }

    func restartBackCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Restarting back camera session...")

            if self.backSession.isRunning {
                self.backSession.stopRunning()
                print("Back camera session stopped")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.sessionQueue.async {
                    if !self.backSession.isRunning {
                        self.backSession.startRunning()
                        print("Back camera session restarted")

                        // Force a session configuration update
                        self.backSession.beginConfiguration()
                        self.backSession.commitConfiguration()
                        print("Back camera session reconfigured")

                        // Reset frame counter
                        self.frameCount = 0
                        print("Frame counter reset")
                    }
                }
            }
        }
    }

    // Switch to face detection mode (for single session devices)
    func switchToFaceDetectionMode() {
        guard !isDualSessionMode else { return } // Only for single session mode

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Switching to face detection mode...")

            // Stop back camera session
            if self.backSession.isRunning {
                self.backSession.stopRunning()
                print("Back camera session stopped")
            }

            // Start front camera session
            if !self.frontSession.isRunning {
                self.frontSession.startRunning()
                print("Front camera session started for face detection")
            }

            DispatchQueue.main.async {
                self.isQRScanningMode = false
                print("Switched to face detection mode")
            }
        }
    }

    // Switch back to QR scanning mode (for single session devices)
    func switchToQRScanningMode() {
        guard !isDualSessionMode else { return } // Only for single session mode

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Switching to QR scanning mode...")

            // Stop front camera session
            if self.frontSession.isRunning {
                self.frontSession.stopRunning()
                print("Front camera session stopped")
            }

            // Start back camera session
            if !self.backSession.isRunning {
                self.backSession.startRunning()
                print("Back camera session started for QR scanning")
            }

            DispatchQueue.main.async {
                self.isQRScanningMode = true
                print("Switched to QR scanning mode")
            }
        }
    }

    // Test QR detection with a simple test
    func testQRDetection() {
        print("Testing QR detection with Vision framework...")

        // Create a simple test image (this is just to test if Vision framework works)
        let testImage = UIImage(systemName: "qrcode") ?? UIImage()

        guard let cgImage = testImage.cgImage else {
            print("Failed to create test image")
            return
        }

        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Vision framework test error: \(error)")
                return
            }

            print("Vision framework test completed successfully")
            if let results = request.results as? [VNBarcodeObservation] {
                print("Found \(results.count) barcode observations in test")
            }
        }

        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            print("Vision framework test request performed")
        } catch {
            print("Vision framework test failed: \(error)")
        }
    }

    // Manual QR detection test with a real QR code image
    func testManualQRDetection() {
        print("Testing manual QR detection...")

        // Create a simple colored rectangle as a test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = testImage?.cgImage else {
            print("Failed to create test image")
            return
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            if let error = error {
                print("Manual QR detection test error: \(error)")
                return
            }

            print("Manual QR detection test completed")
            if let results = request.results as? [VNBarcodeObservation] {
                print("Found \(results.count) barcode observations in manual test")

                if let firstResult = results.first,
                   let payload = firstResult.payloadStringValue {
                    print("Manual test QR code detected: \(payload)")

                    DispatchQueue.main.async {
                        self?.onQRCodeDetected?(payload)
                    }
                }
            } else {
                print("No QR codes found in manual test (expected for test image)")
            }
        }

        request.symbologies = [.qr, .code128, .code39, .ean13]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            print("Manual QR detection test request performed")
        } catch {
            print("Manual QR detection test failed: \(error)")
        }
    }

    // Test if video data output delegate is working
    func testVideoDataOutputDelegate() {
        print("Testing video data output delegate...")

        // Check if delegate is set
        if let backVideoOutput = backVideoDataOutput {
            print("Back video output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if backVideoOutput.sampleBufferDelegate == nil {
                print("Setting back video output delegate...")
                backVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            }
        }

        if let qrVideoOutput = qrVideoDataOutput {
            print("QR detection video output delegate: \(qrVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if qrVideoOutput.sampleBufferDelegate == nil {
                print("Setting QR detection video output delegate...")
                qrVideoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            }
        }

        // Force session restart to ensure delegate is working
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Testing delegate with session restart...")

            if self.backSession.isRunning {
                self.backSession.stopRunning()
                print("Session stopped for delegate test")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sessionQueue.async {
                    if !self.backSession.isRunning {
                        self.backSession.startRunning()
                        print("Session restarted for delegate test")

                        // Reset frame counter
                        self.frameCount = 0
                        print("Frame counter reset for delegate test")

                        // Wait a bit and then check if frames are coming
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            print("Frame count after 1 second: \(self.frameCount)")
                            if self.frameCount == 0 {
                                print("⚠️ WARNING: No frames received after 1 second!")
                                print("This indicates the video data output is not working")
                            } else {
                                print("✅ SUCCESS: Frames are being received!")
                            }
                        }
                    }
                }
            }
        }
    }

    // Test video data output
    func testVideoDataOutput() {
        print("Testing video data output...")
        print("Back session running: \(backSession.isRunning)")
        print("Back video data output: \(backVideoDataOutput != nil ? "configured" : "not configured")")
        print("QR detection video data output: \(qrVideoDataOutput != nil ? "configured" : "not configured")")

        if let backVideoOutput = backVideoDataOutput {
            print("Back video output delegate: \(backVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if let connection = backVideoOutput.connection(with: .video) {
                print("Back video connection enabled: \(connection.isEnabled)")
                print("Back video connection active: \(connection.isActive)")
            }
        }

        if let qrVideoOutput = qrVideoDataOutput {
            print("QR detection video output delegate: \(qrVideoOutput.sampleBufferDelegate != nil ? "set" : "not set")")
            if let connection = qrVideoOutput.connection(with: .video) {
                print("QR detection video connection enabled: \(connection.isEnabled)")
                print("QR detection video connection active: \(connection.isActive)")
            }
        }

        // Try to force enable the connections
        if let backVideoOutput = backVideoDataOutput,
           let connection = backVideoOutput.connection(with: .video) {
            connection.isEnabled = true
            print("Forced back video connection enabled")
        }

        if let qrVideoOutput = qrVideoDataOutput,
           let connection = qrVideoOutput.connection(with: .video) {
            connection.isEnabled = true
            print("Forced QR detection video connection enabled")
        }

        // Force a session restart to ensure video data output is working
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("Forcing session restart to test video data output...")

            if self.backSession.isRunning {
                self.backSession.stopRunning()
                print("Back session stopped for restart")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sessionQueue.async {
                    if !self.backSession.isRunning {
                        self.backSession.startRunning()
                        print("Back session restarted for video data output test")

                        // Reset frame counter
                        self.frameCount = 0
                        print("Frame counter reset for video data output test")

                        // Force video connections after restart
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let backVideoOutput = self.backVideoDataOutput,
                               let connection = backVideoOutput.connection(with: .video) {
                                connection.isEnabled = true
                                print("Forced back video connection enabled after restart")
                            }

                            if let qrVideoOutput = self.qrVideoDataOutput,
                               let connection = qrVideoOutput.connection(with: .video) {
                                connection.isEnabled = true
                                print("Forced QR detection video connection enabled after restart")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureVideoDataOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Simple test - just log that we're receiving frames
        print("🎯 FRAME RECEIVED! Instance: \(instanceId)")

        // Increment frame count
        frameCount += 1

        // Log first few frames
        if frameCount <= 5 {
            print("🎯 Frame #\(frameCount) received - Instance: \(instanceId)")
        }

        // Process QR codes from back camera when in QR scanning mode
        if output == backVideoDataOutput && currentCameraPosition == .back && isQRScanningMode {
            processQRCode(sampleBuffer: sampleBuffer)
        }
        // Process QR codes from front camera when in QR scanning mode
        else if output == frontVideoDataOutput && currentCameraPosition == .front && isQRScanningMode {
            processQRCode(sampleBuffer: sampleBuffer)
        }
    }

    private func captureOutput(_ output: AVCaptureVideoDataOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Log when frames are dropped
        print("❌ FRAME DROPPED! Instance: \(instanceId)")

        // Increment frame count even for dropped frames to track total frames
        frameCount += 1

        // Log first few dropped frames
        if frameCount <= 10 {
            print("❌ Dropped frame #\(frameCount) - Instance: \(instanceId)")
        }
    }

    private func processQRCode(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer from sample buffer")
            return
        }

        print("Processing QR code detection on frame...")

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            if let error = error {
                print("QR code detection error: \(error)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else {
                print("No QR code results found")
                return
            }

            print("Found \(results.count) barcode observations")

            guard let firstResult = results.first else {
                print("No first result in barcode observations")
                return
            }

            guard let payload = firstResult.payloadStringValue else {
                print("No payload string value in barcode observation")
                return
            }

            print("QR Code detected: \(payload)")

            DispatchQueue.main.async {
                self?.onQRCodeDetected?(payload)
            }
        }

        // Configure QR code detection
        request.symbologies = [.qr, .code128, .code39, .ean13]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
            print("QR code detection request performed successfully")
        } catch {
            print("Failed to perform QR code detection: \(error)")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from photo data")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(image)
        }
    }
}
