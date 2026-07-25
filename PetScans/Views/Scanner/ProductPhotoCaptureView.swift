import SwiftUI
import PhotosUI

/// View for capturing a photo of product packaging for identification
/// Uses camera to photograph the front of pet food packaging
struct ProductPhotoCaptureView: View {
    let onImageSelected: (UIImage) -> Void
    /// Back out of the photo flow to the scanner.
    let onCancel: () -> Void
    /// When the live camera isn't usable (permission denied / no camera), show the
    /// library-first layout instead of a black preview.
    var startInLibraryMode: Bool = false

    @State private var showImagePicker = false
    @State private var shouldCapture = false
    @State private var showCameraError = false
    @State private var cameraErrorMessage = ""

    /// True when we're showing the light library-first layout rather than the dark
    /// live-camera preview — drives adaptive control colors and header copy.
    private var showingLibraryLayout: Bool {
        !OCRCameraView.isSupported || startInLibraryMode
    }

    var body: some View {
        ZStack {
            if OCRCameraView.isSupported && !startInLibraryMode {
                // Live camera preview
                OCRCameraView(
                    onCapture: { image in
                        onImageSelected(image)
                    },
                    onError: { error in
                        cameraErrorMessage = error
                        showCameraError = true
                    },
                    shouldCapture: $shouldCapture
                )
                .ignoresSafeArea()

                // Product-focused overlay (matches OCRCameraView crop dimensions)
                ScanningReticleView(
                    frameWidth: 320,
                    frameHeight: 400,
                    cornerLength: 50,
                    showScanningLine: false,
                    instructionText: "Front of pack, good light"
                )

                // Bottom controls
                VStack {
                    Spacer()

                    // Capture button
                    Button {
                        shouldCapture = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: SpacingTokens.captureButtonOuter, height: SpacingTokens.captureButtonOuter)

                            Circle()
                                .fill(Color.white)
                                .frame(width: SpacingTokens.captureButtonInner, height: SpacingTokens.captureButtonInner)
                        }
                    }
                    .padding(.bottom, SpacingTokens.md)

                    // Choose from Library - text only
                    Button("Choose from Library") {
                        showImagePicker = true
                    }
                    .bodySmall()
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, SpacingTokens.xl)
                }
            } else {
                // Fallback when camera is not available
                cameraUnavailableView
            }

            // Always-available way back to the scanner.
            VStack {
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(showingLibraryLayout ? ColorTokens.textPrimary : .white)
                            .padding(SpacingTokens.sm)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Back to scanner")

                    Spacer()
                }
                Spacer()
            }
            .padding(SpacingTokens.md)
        }
        .sheet(isPresented: $showImagePicker) {
            ProductImagePickerView(sourceType: .photoLibrary) { image in
                if let image = image {
                    onImageSelected(image)
                }
                showImagePicker = false
            }
        }
        .alert("Camera Error", isPresented: $showCameraError) {
            Button("OK") { }
        } message: {
            Text(cameraErrorMessage)
        }
    }

    // MARK: - Camera Unavailable Fallback

    private var cameraUnavailableView: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            VStack(spacing: SpacingTokens.xs) {
                // Distinguish "no camera on this device" from "camera permission off".
                Text(OCRCameraView.isSupported ? "Camera Access Off" : "Camera Not Available")
                    .displaySmall()

                Text(OCRCameraView.isSupported
                     ? "Pick a photo from your library and we'll identify it."
                     : "You can still select an image from your photo library.")
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                showImagePicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            .primaryButtonStyle()
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Image Picker

private struct ProductImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
        }
    }
}

#Preview {
    ProductPhotoCaptureView(
        onImageSelected: { _ in },
        onCancel: {}
    )
}
