import SwiftUI

/// A larger scanning reticle view for OCR ingredient label scanning
/// Similar to ScanningReticleView but with a bigger frame (320x400 pt) and no scanning line
struct OCRScanningReticleView: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Larger frame for ingredient labels
    var frameWidth: CGFloat = 320
    var frameHeight: CGFloat = 400
    var cornerLength: CGFloat = 50
    var lineWidth: CGFloat = 3

    private var pulseAnimation: Animation? {
        AnimationTokens.respecting(AnimationTokens.pulse, reduceMotion: reduceMotion)
    }

    var body: some View {
        ZStack {
            // Corner brackets with pulse animation
            cornerBrackets
                .scaleEffect(isAnimating ? 1.0 : 0.97)

            // Instructional text below the frame
            VStack {
                Spacer()
                    .frame(height: frameHeight / 2 + 30)

                Text("Position ingredient label within frame")
                    .caption()
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, SpacingTokens.sm)
                    .padding(.vertical, SpacingTokens.xxs)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .cornerRadius(SpacingTokens.radiusSmall)
            }
        }
        .frame(width: frameWidth, height: frameHeight + 60)
        .allowsHitTesting(false)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        Canvas { context, size in
            let cornerColor = Color.white.opacity(0.9)

            // Calculate offset to center the frame
            let offsetX = (size.width - frameWidth) / 2
            let offsetY = (size.height - frameHeight - 60) / 2

            // Top Left Corner
            var topLeft = Path()
            topLeft.move(to: CGPoint(x: offsetX, y: offsetY + cornerLength))
            topLeft.addLine(to: CGPoint(x: offsetX, y: offsetY))
            topLeft.addLine(to: CGPoint(x: offsetX + cornerLength, y: offsetY))
            context.stroke(topLeft, with: .color(cornerColor), lineWidth: lineWidth)

            // Top Right Corner
            var topRight = Path()
            topRight.move(to: CGPoint(x: offsetX + frameWidth - cornerLength, y: offsetY))
            topRight.addLine(to: CGPoint(x: offsetX + frameWidth, y: offsetY))
            topRight.addLine(to: CGPoint(x: offsetX + frameWidth, y: offsetY + cornerLength))
            context.stroke(topRight, with: .color(cornerColor), lineWidth: lineWidth)

            // Bottom Left Corner
            var bottomLeft = Path()
            bottomLeft.move(to: CGPoint(x: offsetX, y: offsetY + frameHeight - cornerLength))
            bottomLeft.addLine(to: CGPoint(x: offsetX, y: offsetY + frameHeight))
            bottomLeft.addLine(to: CGPoint(x: offsetX + cornerLength, y: offsetY + frameHeight))
            context.stroke(bottomLeft, with: .color(cornerColor), lineWidth: lineWidth)

            // Bottom Right Corner
            var bottomRight = Path()
            bottomRight.move(to: CGPoint(x: offsetX + frameWidth - cornerLength, y: offsetY + frameHeight))
            bottomRight.addLine(to: CGPoint(x: offsetX + frameWidth, y: offsetY + frameHeight))
            bottomRight.addLine(to: CGPoint(x: offsetX + frameWidth, y: offsetY + frameHeight - cornerLength))
            context.stroke(bottomRight, with: .color(cornerColor), lineWidth: lineWidth)
        }
        .frame(width: frameWidth, height: frameHeight + 60)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Corner pulse animation
        if let animation = pulseAnimation {
            withAnimation(animation) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        OCRScanningReticleView()
    }
}
