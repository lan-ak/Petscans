import SwiftUI
import AVFoundation
import UIKit

struct BarcodeScannerView: UIViewRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    static var isSupported: Bool {
        return true // AVFoundation is available on all iOS devices with cameras
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let previewView = CameraPreviewView()
        context.coordinator.setupCamera(previewView: previewView)
        return previewView
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onError: onError)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        let onError: (String) -> Void
        var hasScanned = false

        private var captureSession: AVCaptureSession?
        private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

        init(onScan: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onScan = onScan
            self.onError = onError
            super.init()
            hapticFeedback.prepare()
        }

        func setupCamera(previewView: CameraPreviewView) {
            let session = AVCaptureSession()
            session.beginConfiguration()

            // Set up camera input
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
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

            // Set up metadata output for barcode scanning
            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

                // Support all common barcode types
                metadataOutput.metadataObjectTypes = [
                    .ean8, .ean13, .upce, .code39, .code39Mod43,
                    .code93, .code128, .pdf417, .qr, .aztec,
                    .interleaved2of5, .itf14, .dataMatrix
                ]
            } else {
                onError("Unable to add metadata output")
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

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasScanned else { return }

            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let stringValue = metadataObject.stringValue {
                hasScanned = true

                // Stop scanning
                captureSession?.stopRunning()

                // Provide haptic feedback
                hapticFeedback.impactOccurred()

                // Call the onScan callback
                onScan(stringValue)
            }
        }

        deinit {
            captureSession?.stopRunning()
        }
    }
}

// Custom UIView for camera preview
class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

// Fallback view when scanner is not supported
struct ScannerUnavailableView: View {
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Camera Not Available")
                .font(.title2.bold())

            Text("Barcode scanning requires a device with a camera.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enter Manually") {
                onManualEntry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ScannerUnavailableView(onManualEntry: {})
}
