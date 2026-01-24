import SwiftUI
import PhotosUI

/// View for capturing or selecting an image of ingredient labels
/// Features a live camera preview with a guiding box overlay
struct IngredientCameraView: View {
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var showImagePicker = false
    @State private var shouldCapture = false
    @State private var showCameraError = false
    @State private var cameraErrorMessage = ""

    var body: some View {
        ZStack {
            if OCRCameraView.isSupported {
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

                // Guiding box overlay
                ScanningReticleView(
                    frameWidth: 320,
                    frameHeight: 400,
                    cornerLength: 50,
                    showScanningLine: false,
                    instructionText: "Position ingredient label within frame"
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

                    // Choose from Library button
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .labelMedium()
                            .foregroundColor(.white)
                            .padding(.horizontal, SpacingTokens.md)
                            .padding(.vertical, SpacingTokens.xs)
                            .background(.ultraThinMaterial)
                            .cornerRadius(SpacingTokens.radiusMedium)
                    }

                    // Cancel button
                    Button("Cancel") {
                        onCancel()
                    }
                    .bodySmall()
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, SpacingTokens.xs)
                    .padding(.bottom, SpacingTokens.xl)
                }
            } else {
                // Fallback when camera is not available
                cameraUnavailableView
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: .photoLibrary) { image in
                if let image = image {
                    onImageSelected(image)
                }
                showImagePicker = false
            }
        }
        .alert("Camera Error", isPresented: $showCameraError) {
            Button("OK") {
                onCancel()
            }
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
                Text("Camera Not Available")
                    .displaySmall()

                Text("You can still select an image from your photo library")
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: SpacingTokens.xs) {
                Button {
                    showImagePicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                .primaryButtonStyle()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.textSecondary)
                .padding(.top, SpacingTokens.xs)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Image Picker

private struct ImagePickerView: UIViewControllerRepresentable {
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
    IngredientCameraView(
        onImageSelected: { _ in },
        onCancel: {}
    )
}
