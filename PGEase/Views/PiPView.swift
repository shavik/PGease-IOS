import SwiftUI
import AVFoundation
import UIKit

struct PiPView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var faceDetectionManager: FaceDetectionManager
    @Binding var isVisible: Bool
    @Binding var position: PiPPosition
    @Binding var size: PiPSize
    @Binding var opacity: Double

    let onFaceDetected: (Bool) -> Void

    // Make the view take minimal space in SwiftUI
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        print("PiP makeUIView called")
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.green.cgColor

        // Set initial frame for PiP positioning (will be updated in updateUIView)
        // Using a default size that will be overridden
        let defaultSize = CGSize(width: 100, height: 75)
        view.frame = CGRect(origin: CGPoint(x: 20, y: 60), size: defaultSize)
        print("PiP initial frame: \(view.frame)")

        // Create preview layer for the PiP session (front camera)
        // Only attach to session if we're in QR scanning mode
        let pipSession = cameraManager.frontCameraSession
        print("PiP View: Using front camera session")
        print("PiP session running: \(pipSession.isRunning)")
        let previewLayer = AVCaptureVideoPreviewLayer()

        // Only attach to session if we're NOT in QR scanning mode AND the session is running
        if !cameraManager.isQRScanningMode && pipSession.isRunning {
            previewLayer.session = pipSession
            print("PiP preview layer attached to session (photo capture mode)")
        } else {
            print("PiP preview layer created without session (QR scanning mode or session not running)")
        }
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        print("PiP preview layer added with frame: \(previewLayer.frame)")

        // Add face detection overlay
        let faceOverlayView = FaceDetectionOverlayView()
        faceOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(faceOverlayView)

        NSLayoutConstraint.activate([
            faceOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            faceOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            faceOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            faceOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Setup face detection
        setupFaceDetection()

        // Setup gesture recognizers
        let coordinator = makeCoordinator()
        setupGestureRecognizers(for: view, coordinator: coordinator)

        return view
    }

    func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        print("PiP dismantleUIView called - cleaning up session")
        // Properly detach the preview layer from the session
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.session = nil
            print("PiP preview layer session detached")
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        print("PiP updateUIView called - isVisible: \(isVisible), opacity: \(opacity)")

        // PiPView should be visible all the time, but only attach to front camera when NOT in QR scanning mode
        uiView.isHidden = !isVisible

        // Update preview layer frame and session
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            // Update preview layer frame to match view bounds
            previewLayer.frame = uiView.bounds
            print("PiP preview layer frame: \(previewLayer.frame)")

                                // PiPView should ONLY use front camera session when NOT in QR scanning mode
            if !cameraManager.isQRScanningMode {
                let frontCameraSession = cameraManager.frontCameraSession
                print("PiP: Photo capture mode - checking session management...")
                print("PiP: Current preview layer session: \(previewLayer.session == nil ? "nil" : "attached")")
                print("PiP: Target front camera session: \(frontCameraSession)")
                print("PiP: Front camera running: \(frontCameraSession.isRunning)")

                // Only attach if the session is running and not already attached
                if frontCameraSession.isRunning && previewLayer.session != frontCameraSession {
                    print("PiP: Conditions met, attaching to front camera...")
                    previewLayer.session = frontCameraSession
                    print("PiP: Successfully attached to front camera session")
                } else if !frontCameraSession.isRunning && previewLayer.session != nil {
                    // Detach if session is not running
                    print("PiP: Session not running, detaching...")
                    previewLayer.session = nil
                    print("PiP: Session detached (not running)")
                } else {
                    print("PiP: No session change needed")
                }
                print("PiP: Final preview layer session running: \(previewLayer.session?.isRunning ?? false)")
            } else {
                // In QR scanning mode, PiPView should have no session
                print("PiP: QR scanning mode - detaching session...")
                if previewLayer.session != nil {
                    previewLayer.session = nil
                    print("PiP: Session detached (QR scanning mode)")
                } else {
                    print("PiP: No session to detach")
                }
            }
        } else {
            print("PiP preview layer not found!")
        }

        // Update visibility
        uiView.isHidden = !isVisible
        print("PiP view hidden: \(uiView.isHidden)")

        // Update opacity
        uiView.alpha = opacity

        // Don't override the frame size - let SwiftUI handle it
        print("PiP view frame: \(uiView.frame)")

        // Update border color based on face detection
        updateBorderColor(for: uiView)
    }

    private func setupFaceDetection() {
        faceDetectionManager.onFaceDetected = { detected, confidence in
            DispatchQueue.main.async {
                self.onFaceDetected(detected)
            }
        }
    }

    private func setupGestureRecognizers(for view: UIView, coordinator: Coordinator) {
        // Pan gesture for dragging
        let panGesture = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        // Pinch gesture for resizing
        let pinchGesture = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Double tap to toggle visibility
        let doubleTapGesture = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)

        // Long press for settings
        let longPressGesture = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 1.0
        view.addGestureRecognizer(longPressGesture)
    }

    private func updatePositionAndSize(for view: UIView) {
        // Since we're controlling size through SwiftUI frame,
        // we only need to update position if needed
        // The size is now controlled by SwiftUI's .frame(width: 120, height: 90)

        // For now, let's just ensure the view is positioned correctly
        // The SwiftUI layout should handle the positioning
        print("PiP updatePositionAndSize called - current frame: \(view.frame)")
    }

    private func updateBorderColor(for view: UIView) {
        if faceDetectionManager.isFaceDetected {
            view.layer.borderColor = UIColor.green.cgColor
        } else {
            view.layer.borderColor = UIColor.red.cgColor
        }
    }

    class Coordinator: NSObject {
        var parent: PiPView
        var initialFrame: CGRect?

        init(_ parent: PiPView) {
            self.parent = parent
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            switch gesture.state {
            case .began:
                initialFrame = view.frame
            case .changed:
                guard let initialFrame = initialFrame else { return }
                let translation = gesture.translation(in: view.superview)
                view.frame = initialFrame.offsetBy(dx: translation.x, dy: translation.y)
            case .ended:
                // Snap to nearest position
                snapToNearestPosition(for: view)
                initialFrame = nil
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = gesture.view else { return }

            switch gesture.state {
            case .changed:
                let scale = gesture.scale
                let newSize = CGSize(
                    width: view.frame.width * scale,
                    height: view.frame.height * scale
                )

                // Constrain size
                let minSize: CGFloat = 100
                let maxSize: CGFloat = 200

                let constrainedSize = CGSize(
                    width: max(minSize, min(maxSize, newSize.width)),
                    height: max(minSize * 0.75, min(maxSize * 0.75, newSize.height))
                )

                view.frame.size = constrainedSize
                gesture.scale = 1.0
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            parent.isVisible.toggle()
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began {
                // Show settings menu
                showSettingsMenu()
            }
        }

        private func snapToNearestPosition(for view: UIView) {
            guard let superview = view.superview else { return }

            let center = view.center
            let positions: [PiPPosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

            var nearestPosition = positions[0]
            var minDistance = CGFloat.greatestFiniteMagnitude

            for position in positions {
                let positionCenter = getCenterForPosition(position, in: superview)
                let distance = center.distance(to: positionCenter)

                if distance < minDistance {
                    minDistance = distance
                    nearestPosition = position
                }
            }

            parent.position = nearestPosition
        }

        private func getCenterForPosition(_ position: PiPPosition, in superview: UIView) -> CGPoint {
            let size = parent.size.sizeValue
            let frameSize = CGSize(width: size, height: size * 0.75)

            switch position {
            case .topLeft:
                return CGPoint(x: 20 + frameSize.width / 2, y: 60 + frameSize.height / 2)
            case .topRight:
                return CGPoint(x: superview.bounds.width - 20 - frameSize.width / 2, y: 60 + frameSize.height / 2)
            case .bottomLeft:
                return CGPoint(x: 20 + frameSize.width / 2, y: superview.bounds.height - 100 - frameSize.height / 2)
            case .bottomRight:
                return CGPoint(x: superview.bounds.width - 20 - frameSize.width / 2, y: superview.bounds.height - 100 - frameSize.height / 2)
            }
        }

        private func showSettingsMenu() {
            // This would show a settings menu for PiP configuration
            // Implementation would depend on your app's navigation structure
        }
    }
}

// MARK: - Face Detection Overlay View
class FaceDetectionOverlayView: UIView {
    private var faceRectangles: [CGRect] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(2.0)

        for faceRect in faceRectangles {
            context.stroke(faceRect)
        }
    }

    func updateFaceRectangles(_ rectangles: [CGRect]) {
        faceRectangles = rectangles
        setNeedsDisplay()
    }
}

// MARK: - Supporting Types
enum PiPPosition: String, CaseIterable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
}

enum PiPSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var sizeValue: CGFloat {
        switch self {
        case .small:
            return 80  // Very small
        case .medium:
            return 120 // Small
        case .large:
            return 160 // Medium (still under 25% of typical screen width)
        }
    }
}

// MARK: - Extensions
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
} 
