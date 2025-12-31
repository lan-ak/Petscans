import SwiftUI
import PhotosUI

/// View for capturing or selecting an image of ingredient labels
struct IngredientCameraView: View {
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            // Icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.brandPrimary)

            // Instructions
            VStack(spacing: SpacingTokens.xs) {
                Text("Scan Ingredient Label")
                    .displaySmall()

                Text("Take a clear photo of the ingredient list on the product label")
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Tips
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    TipRow(icon: "sun.max.fill", text: "Ensure good lighting")
                    TipRow(icon: "rectangle.center.inset.filled", text: "Keep label flat and in focus")
                    TipRow(icon: "sparkles", text: "Avoid glare and shadows")
                }
                .padding()
                .cardStyle(
                    backgroundColor: ColorTokens.info.opacity(0.1),
                    cornerRadius: SpacingTokens.radiusMedium
                )
                .padding(.horizontal)
            }

            // Action buttons
            VStack(spacing: SpacingTokens.xs) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        sourceType = .camera
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    .primaryButtonStyle()
                }

                Button {
                    sourceType = .photoLibrary
                    showImagePicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                .secondaryButtonStyle()

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
        .sheet(isPresented: $showCamera) {
            ImagePickerView(sourceType: .camera) { image in
                if let image = image {
                    onImageSelected(image)
                }
                showCamera = false
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
    }
}

// MARK: - Tip Row

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: icon)
                .foregroundColor(ColorTokens.info)
                .frame(width: 20)

            Text(text)
                .caption()
                .foregroundColor(ColorTokens.textPrimary)
        }
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
