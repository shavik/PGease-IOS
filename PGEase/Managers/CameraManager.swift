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
    @Published var isQRScanningMode = true

    var frameCount = 0

    private let sessionQueue = DispatchQueue(label: "session.queue")
    private let videoDataOutputQueue = DispatchQueue(label: "video.data.output.queue", qos: .userInitiated)

    private let session = AVCaptureSession()
    private var cameraInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    var cameraSession: AVCaptureSession { return session }

    var onQRCodeDetected: ((String) -> Void)?

    enum CameraError: Error, LocalizedError {
        case notAuthorized
        case deviceNotFound
        case sessionConfigurationFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Camera access is required."
            case .deviceNotFound:
                return "Camera device not found."
            case .sessionConfigurationFailed:
                return "Failed to configure camera session."
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
        default:
            self.error = .notAuthorized
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.error = .deviceNotFound }
                return
            }
            self.session.addInput(input)
            self.cameraInput = input
            print("✅ Back camera input added")

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = false
            output.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)

            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
                self.videoDataOutput = output
                print("✅ Video data output added")
            }

            if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                connection.isEnabled = true
                print("✅ Connection enabled and orientation set")
            }

            self.session.commitConfiguration()
            self.startSession()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    print("📷 Camera session started")
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    print("🛑 Camera session stopped")
                }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("🎯 Frame received from back camera")

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer")
            return
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            if let error = error {
                print("QR detection error: \(error)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation], let firstResult = results.first,
                  let payload = firstResult.payloadStringValue else {
                return
            }

            print("✅ QR Code detected: \(payload)")
            DispatchQueue.main.async {
                self?.onQRCodeDetected?(payload)
            }
        }

        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Vision error: \(error)")
        }
    }
}
