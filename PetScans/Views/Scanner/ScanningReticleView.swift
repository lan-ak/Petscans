import SwiftUI

struct ScanningReticleView: View {
    @State private var isAnimating = false
    @State private var scanLineOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Configurable properties
    var frameWidth: CGFloat = 280
    var frameHeight: CGFloat = 180
    var cornerLength: CGFloat = 40
    var lineWidth: CGFloat = 3
    var showScanningLine: Bool = true
    var instructionText: String? = nil

    private var pulseAnimation: Animation? {
        AnimationTokens.respecting(AnimationTokens.pulse, reduceMotion: reduceMotion)
    }

    private var scanLineAnimation: Animation? {
        AnimationTokens.respecting(AnimationTokens.scanLine, reduceMotion: reduceMotion)
    }

    private var totalHeight: CGFloat {
        instructionText != nil ? frameHeight + 60 : frameHeight
    }

    var body: some View {
        ZStack {
            // Corner brackets
            cornerBrackets
                .scaleEffect(isAnimating ? 1.0 : (instructionText != nil ? 0.97 : 0.95))

            // Scanning line
            if showScanningLine && !reduceMotion {
                scanningLine
            }

            // Instructional text (for OCR mode)
            if let text = instructionText {
                VStack {
                    Spacer()
                        .frame(height: frameHeight / 2 + 30)

                    Text(text)
                        .caption()
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, SpacingTokens.xxs)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .cornerRadius(SpacingTokens.radiusSmall)
                }
            }
        }
        .frame(width: frameWidth, height: totalHeight)
        .allowsHitTesting(false)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        Canvas { context, size in
            let cornerColor = Color.white.opacity(0.9)

            // Calculate offset to center the frame when instruction text is present
            let offsetX = (size.width - frameWidth) / 2
            let offsetY = instructionText != nil ? (size.height - frameHeight - 60) / 2 : 0

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
        .frame(width: frameWidth, height: instructionText != nil ? frameHeight + 60 : frameHeight)
    }

    // MARK: - Scanning Line

    private var scanningLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.5),
                        .white.opacity(0.8),
                        .white.opacity(0.5),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: frameWidth - (cornerLength * 2), height: 2)
            .offset(y: scanLineOffset - frameHeight / 2)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Corner pulse animation
        if let animation = pulseAnimation {
            withAnimation(animation) {
                isAnimating = true
            }
        }

        // Scanning line animation
        if let animation = scanLineAnimation {
            withAnimation(animation) {
                scanLineOffset = frameHeight
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        ScanningReticleView()
    }
}
