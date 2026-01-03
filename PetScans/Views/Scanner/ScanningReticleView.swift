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

    private var pulseAnimation: Animation? {
        AnimationTokens.respecting(AnimationTokens.pulse, reduceMotion: reduceMotion)
    }

    private var scanLineAnimation: Animation? {
        AnimationTokens.respecting(AnimationTokens.scanLine, reduceMotion: reduceMotion)
    }

    var body: some View {
        ZStack {
            // Corner brackets
            cornerBrackets
                .scaleEffect(isAnimating ? 1.0 : 0.95)

            // Scanning line
            if !reduceMotion {
                scanningLine
            }
        }
        .frame(width: frameWidth, height: frameHeight)
        .allowsHitTesting(false)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        Canvas { context, size in
            let cornerColor = Color.white.opacity(0.9)

            // Top Left Corner
            var topLeft = Path()
            topLeft.move(to: CGPoint(x: 0, y: cornerLength))
            topLeft.addLine(to: CGPoint(x: 0, y: 0))
            topLeft.addLine(to: CGPoint(x: cornerLength, y: 0))
            context.stroke(topLeft, with: .color(cornerColor), lineWidth: lineWidth)

            // Top Right Corner
            var topRight = Path()
            topRight.move(to: CGPoint(x: size.width - cornerLength, y: 0))
            topRight.addLine(to: CGPoint(x: size.width, y: 0))
            topRight.addLine(to: CGPoint(x: size.width, y: cornerLength))
            context.stroke(topRight, with: .color(cornerColor), lineWidth: lineWidth)

            // Bottom Left Corner
            var bottomLeft = Path()
            bottomLeft.move(to: CGPoint(x: 0, y: size.height - cornerLength))
            bottomLeft.addLine(to: CGPoint(x: 0, y: size.height))
            bottomLeft.addLine(to: CGPoint(x: cornerLength, y: size.height))
            context.stroke(bottomLeft, with: .color(cornerColor), lineWidth: lineWidth)

            // Bottom Right Corner
            var bottomRight = Path()
            bottomRight.move(to: CGPoint(x: size.width - cornerLength, y: size.height))
            bottomRight.addLine(to: CGPoint(x: size.width, y: size.height))
            bottomRight.addLine(to: CGPoint(x: size.width, y: size.height - cornerLength))
            context.stroke(bottomRight, with: .color(cornerColor), lineWidth: lineWidth)
        }
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
