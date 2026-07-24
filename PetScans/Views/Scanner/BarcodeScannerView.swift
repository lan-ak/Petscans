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

            // Smart camera selection for close-up scanning:
            // - iPhone 13 Pro+: Ultra-wide has autofocus (macro mode) - use it for 2cm focus
            // - iPhone 12 Pro: Ultra-wide has fixed focus - use wide-angle instead
            // - Non-Pro models: No ultra-wide - use wide-angle
            let videoCaptureDevice: AVCaptureDevice
            if let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back),
               ultraWide.isFocusModeSupported(.continuousAutoFocus) {
                // Ultra-wide supports autofocus (iPhone 13 Pro+) - use for macro
                videoCaptureDevice = ultraWide
            } else if let wideAngle = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // Fall back to wide-angle camera
                videoCaptureDevice = wideAngle
            } else if let defaultCamera = AVCaptureDevice.default(for: .video) {
                // Last resort: any available camera
                videoCaptureDevice = defaultCamera
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.onError("No camera available")
                }
                return
            }

            let videoInput: AVCaptureDeviceInput
            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Unable to access camera: \(error.localizedDescription)")
                }
                return
            }

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Unable to add camera input")
                }
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

            // Set up metadata output for barcode scanning
            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

                // Retail product symbologies only. A GTIN can only arrive as one of these;
                // QR, PDF417, Aztec, Code39/93/128 and DataMatrix are never retail barcodes
                // and only slow detection and cause mis-triggers on packaging graphics.
                metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .itf14]
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.onError("Unable to add metadata output")
                }
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
                DispatchQueue.main.async { [weak self] in
                    self?.onScan(stringValue)
                }
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
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.textSecondary)

            Text("Camera Not Available")
                .displaySmall()

            Text("Barcode scanning requires a device with a camera.")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enter Manually") {
                onManualEntry()
            }
            .primaryButtonStyle()
        }
        .padding(SpacingTokens.sm)
    }
}

/// Shown before the system camera prompt. iOS asks once per install, so the
/// explanation has to come first — an unprimed prompt arriving seconds after a
/// paywall gets declined a lot, and a decline is not recoverable in-app.
struct CameraPrimingView: View {
    let onEnable: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            Text("Scan a label")
                .displaySmall()

            Text("PetScans reads barcodes and ingredient labels through your camera. Photos stay on your device.")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: SpacingTokens.xs) {
                Button("Enable Camera") {
                    onEnable()
                }
                .primaryButtonStyle()

                Button("Enter Manually") {
                    onManualEntry()
                }
                .font(TypographyTokens.labelLarge)
                .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.horizontal)
        }
        .padding(SpacingTokens.sm)
        .accessibilityIdentifier("camera-priming")
    }
}

/// Shown when camera access was denied or is restricted. Replaces what used to
/// be a black capture preview with no explanation.
struct CameraDeniedView: View {
    let onOpenSettings: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.textSecondary)

            Text("Camera Access Off")
                .displaySmall()

            Text("Scanning needs camera access. Turn it on in Settings → PetScans → Camera, or enter ingredients by hand.")
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: SpacingTokens.xs) {
                Button("Open Settings") {
                    onOpenSettings()
                }
                .primaryButtonStyle()

                Button("Enter Manually") {
                    onManualEntry()
                }
                .font(TypographyTokens.labelLarge)
                .foregroundColor(ColorTokens.textSecondary)
            }
            .padding(.horizontal)
        }
        .padding(SpacingTokens.sm)
        .accessibilityIdentifier("camera-denied")
    }
}

// Mock scanner view for App Store screenshots
struct MockScannerPreviewView: View {
    var body: some View {
        ZStack {
            // Simulated camera background (dark gradient)
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Simulated product/barcode area
            VStack {
                Spacer()

                RoundedRectangle(cornerRadius: SpacingTokens.radiusMedium)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 120)
                    .overlay(
                        VStack(spacing: SpacingTokens.xs) {
                            Image(systemName: "barcode")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Position barcode here")
                                .caption()
                                .foregroundColor(.white.opacity(0.6))
                        }
                    )

                Spacer()
                Spacer()
            }
        }
    }
}

#Preview("Camera Priming") {
    CameraPrimingView(onEnable: {}, onManualEntry: {})
}

#Preview("Camera Denied") {
    CameraDeniedView(onOpenSettings: {}, onManualEntry: {})
}

#Preview("Scanner Unavailable") {
    ScannerUnavailableView(onManualEntry: {})
}

#Preview("Mock Scanner") {
    ZStack {
        MockScannerPreviewView()
        ScanningReticleView()
    }
}
