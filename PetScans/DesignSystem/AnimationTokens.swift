import SwiftUI

/// Centralized animation tokens for consistent, snappy animations across the app.
/// Uses spring animations with slight overshoot for a modern, organic feel.
struct AnimationTokens {

    // MARK: - Spring Configurations

    /// Ultra-fast micro-interactions (button taps, toggles)
    /// Response: 0.15s, slight bounce
    static let springSnappy = Animation.spring(
        response: 0.15,
        dampingFraction: 0.7,
        blendDuration: 0
    )

    /// Standard interactions (cards, expansion)
    /// Response: 0.2s, balanced feel
    static let springStandard = Animation.spring(
        response: 0.2,
        dampingFraction: 0.75,
        blendDuration: 0
    )

    /// Emphasized transitions (modals, navigation)
    /// Response: 0.3s, smooth with subtle bounce
    static let springEmphasized = Animation.spring(
        response: 0.3,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    // MARK: - Semantic Aliases

    static let buttonTap = springSnappy

    // MARK: - Continuous Animations

    /// Pulsing effect for scanner reticles
    static let pulse = Animation.easeInOut(duration: 1.5)
        .repeatForever(autoreverses: true)

    /// Linear scan line movement
    static let scanLine = Animation.linear(duration: 2.0)
        .repeatForever(autoreverses: false)

    /// Gentle floating animation for background elements (8-15s)
    static let floatSlow = Animation.linear(duration: 12.0)
        .repeatForever(autoreverses: false)

    /// Drift animation with slight horizontal sway
    static let driftGentle = Animation.easeInOut(duration: 3.0)
        .repeatForever(autoreverses: true)

    /// Sparkle/twinkle effect for highlights
    static let sparkle = Animation.easeInOut(duration: 0.6)
        .repeatForever(autoreverses: true)

    /// Celebration bounce for success states (more pronounced)
    static let celebrationBounce = Animation.spring(
        response: 0.4,
        dampingFraction: 0.5,
        blendDuration: 0
    )

    // MARK: - Duration Helpers

    /// Create a float animation with custom duration
    static func float(duration: Double) -> Animation {
        Animation.linear(duration: duration)
            .repeatForever(autoreverses: false)
    }

    // MARK: - Accessibility

    /// Returns the animation only if reduce motion is disabled
    static func respecting(
        _ animation: Animation,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : animation
    }

}

// MARK: - View Extensions

extension View {
    /// Apply snappy spring animation (0.15s) for micro-interactions
    func animateSnappy<V: Equatable>(value: V) -> some View {
        self.animation(AnimationTokens.springSnappy, value: value)
    }

    /// Apply standard spring animation (0.2s) for typical interactions
    func animateStandard<V: Equatable>(value: V) -> some View {
        self.animation(AnimationTokens.springStandard, value: value)
    }

    /// Apply emphasized spring animation (0.3s) for important transitions
    func animateEmphasized<V: Equatable>(value: V) -> some View {
        self.animation(AnimationTokens.springEmphasized, value: value)
    }
}

// MARK: - withAnimation Helpers

/// Perform action with snappy spring animation
func withSnappyAnimation(_ action: @escaping () -> Void) {
    withAnimation(AnimationTokens.springSnappy, action)
}

/// Perform action with standard spring animation
func withStandardAnimation(_ action: @escaping () -> Void) {
    withAnimation(AnimationTokens.springStandard, action)
}

