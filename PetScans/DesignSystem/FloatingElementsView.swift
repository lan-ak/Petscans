import SwiftUI

/// A reusable animated background view with floating SF Symbol elements.
/// Can be used for paw prints, stars, hearts, sparkles, etc.
///
/// Usage:
/// ```swift
/// FloatingElementsView.paws()
/// FloatingElementsView.stars(opacity: 0.3)
/// FloatingElementsView(symbol: "heart.fill", color: .pink)
/// ```
struct FloatingElementsView: View {

    // MARK: - Configuration

    let symbol: String
    let count: Int
    let color: Color
    let baseOpacity: Double
    let sizeRange: ClosedRange<CGFloat>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var elements: [FloatingElement] = []
    @State private var isAnimating = false

    // MARK: - Init

    init(
        symbol: String,
        count: Int = 10,
        color: Color = ColorTokens.brandPrimary,
        opacity: Double = 0.45,
        sizeRange: ClosedRange<CGFloat> = 20...36
    ) {
        self.symbol = symbol
        self.count = count
        self.color = color
        self.baseOpacity = opacity
        self.sizeRange = sizeRange
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(elements) { element in
                    FloatingSymbolView(
                        element: element,
                        symbol: symbol,
                        color: color,
                        isAnimating: isAnimating,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .onAppear {
                generateElements(in: geometry.size)
                // Small delay to let the view appear before animating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false) // Pass through touches
    }

    // MARK: - Element Generation

    private func generateElements(in size: CGSize) {
        elements = (0..<count).map { index in
            FloatingElement(
                id: index,
                startX: CGFloat.random(in: 0...size.width),
                size: CGFloat.random(in: sizeRange),
                opacity: baseOpacity * Double.random(in: 0.8...1.0),
                rotation: Double.random(in: -15...15),
                duration: Double.random(in: 8...15),
                delay: Double(index) * 0.5, // Stagger the starts
                screenHeight: size.height,
                driftAmount: CGFloat.random(in: -30...30)
            )
        }
    }
}

// MARK: - Floating Element Model

private struct FloatingElement: Identifiable {
    let id: Int
    let startX: CGFloat
    let size: CGFloat
    let opacity: Double
    let rotation: Double
    let duration: Double
    let delay: Double
    let screenHeight: CGFloat
    let driftAmount: CGFloat

    var startY: CGFloat { screenHeight + size + 20 }
    var endY: CGFloat { -size - 20 }
}

// MARK: - Floating Symbol View

private struct FloatingSymbolView: View {
    let element: FloatingElement
    let symbol: String
    let color: Color
    let isAnimating: Bool
    let reduceMotion: Bool

    @State private var yOffset: CGFloat = 0
    @State private var xDrift: CGFloat = 0
    @State private var currentRotation: Double = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: element.size))
            .foregroundColor(color.opacity(element.opacity))
            .rotationEffect(.degrees(currentRotation))
            .position(
                x: element.startX + xDrift,
                y: element.startY + yOffset
            )
            .onAppear {
                guard !reduceMotion else { return }
                startAnimations()
            }
    }

    private func startAnimations() {
        // Main float animation (upward movement)
        withAnimation(
            Animation.linear(duration: element.duration)
                .repeatForever(autoreverses: false)
                .delay(element.delay)
        ) {
            yOffset = element.endY - element.startY
        }

        // Subtle horizontal drift
        withAnimation(
            AnimationTokens.driftGentle
                .delay(element.delay)
        ) {
            xDrift = element.driftAmount
        }

        // Gentle rotation wobble
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
                .delay(element.delay)
        ) {
            currentRotation = element.rotation
        }
    }
}

// MARK: - Convenience Factory Methods

extension FloatingElementsView {

    /// Floating paw prints - perfect for search/loading states
    static func paws(
        count: Int = 10,
        opacity: Double = 0.45
    ) -> FloatingElementsView {
        FloatingElementsView(
            symbol: "pawprint.fill",
            count: count,
            color: ColorTokens.brandPrimary,
            opacity: opacity,
            sizeRange: 20...36
        )
    }

    /// Floating stars - great for success/celebration states
    static func stars(
        count: Int = 12,
        opacity: Double = 0.3
    ) -> FloatingElementsView {
        FloatingElementsView(
            symbol: "star.fill",
            count: count,
            color: ColorTokens.favorite,
            opacity: opacity,
            sizeRange: 12...24
        )
    }

    /// Floating sparkles - subtle accent for premium features
    static func sparkles(
        count: Int = 15,
        opacity: Double = 0.4
    ) -> FloatingElementsView {
        FloatingElementsView(
            symbol: "sparkle",
            count: count,
            color: ColorTokens.brandPrimary,
            opacity: opacity,
            sizeRange: 10...20
        )
    }

    /// Floating hearts - for favorites or love-related features
    static func hearts(
        count: Int = 8,
        opacity: Double = 0.35
    ) -> FloatingElementsView {
        FloatingElementsView(
            symbol: "heart.fill",
            count: count,
            color: ColorTokens.error,
            opacity: opacity,
            sizeRange: 16...28
        )
    }
}

// MARK: - Preview

#Preview("Floating Paws") {
    ZStack {
        ColorTokens.backgroundPrimary
            .ignoresSafeArea()
        FloatingElementsView.paws()
    }
}

#Preview("Floating Stars") {
    ZStack {
        ColorTokens.backgroundPrimary
            .ignoresSafeArea()
        FloatingElementsView.stars()
    }
}

#Preview("Floating Sparkles") {
    ZStack {
        ColorTokens.backgroundPrimary
            .ignoresSafeArea()
        FloatingElementsView.sparkles()
    }
}
