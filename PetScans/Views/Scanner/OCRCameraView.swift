import SwiftUI
import AVFoundation
import UIKit

/// Custom camera view for OCR ingredient scanning with photo capture capability
struct OCRCameraView: UIViewRepresentable {
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void
    @Binding var shouldCapture: Bool

    static var isSupported: Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIView(context: Context) -> OCRCameraPreviewView {
        let previewView = OCRCameraPreviewView()
        context.coordinator.setupCamera(previewView: previewView)
        return previewView
    }

    func updateUIView(_ uiView: OCRCameraPreviewView, context: Context) {
        if shouldCapture {
            context.coordinator.capturePhoto()
            DispatchQueue.main.async {
                shouldCapture = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onError: onError)
    }

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let onCapture: (UIImage) -> Void
        let onError: (String) -> Void

        private var captureSession: AVCaptureSession?
        private var photoOutput: AVCapturePhotoOutput?
        private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

        init(onCapture: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
            self.onCapture = onCapture
            self.onError = onError
            super.init()
            hapticFeedback.prepare()
        }

        func setupCamera(previewView: OCRCameraPreviewView) {
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = .photo

            // Set up camera input - prefer ultra-wide for close-up focus
            guard let videoCaptureDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video) else {
                onError("No camera available")
                return
            }

            let videoInput: AVCaptureDeviceInput
            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                onError("Unable to access camera: \(error.localizedDescription)")
                return
            }

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                onError("Unable to add camera input")
                return
            }

            // Configure focus for close-up scanning
            do {
                try videoCaptureDevice.lockForConfiguration()
                if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
                    videoCaptureDevice.focusMode = .continuousAutoFocus
                }
                if videoCaptureDevice.isAutoFocusRangeRestrictionSupported {
                    videoCaptureDevice.autoFocusRangeRestriction = .near
                }
                videoCaptureDevice.unlockForConfiguration()
            } catch {
                // Continue without optimized focus if configuration fails
            }

            // Set up photo output for capturing images
            let photoOutput = AVCapturePhotoOutput()

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            } else {
                onError("Unable to add photo output")
                return
            }

            session.commitConfiguration()

            // Set up preview layer
            previewView.videoPreviewLayer.session = session
            previewView.videoPreviewLayer.videoGravity = .resizeAspectFill

            self.captureSession = session

            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        func capturePhoto() {
            guard let photoOutput = photoOutput else {
                onError("Camera not ready")
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto

            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // MARK: - AVCapturePhotoCaptureDelegate

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                onError("Failed to capture photo: \(error.localizedDescription)")
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) else {
                onError("Failed to process captured photo")
                return
            }

            // Provide haptic feedback
            hapticFeedback.impactOccurred()

            // Stop the session after capture
            captureSession?.stopRunning()

            // Return the captured image
            DispatchQueue.main.async {
                self.onCapture(image)
            }
        }

        deinit {
            captureSession?.stopRunning()
        }
    }
}

// Reuse CameraPreviewView from BarcodeScannerView if it's not already shared
// If CameraPreviewView is private to BarcodeScannerView, we need our own copy
class OCRCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
