import SwiftUI

/// Reusable view for displaying errors with a retry action.
struct NetworkErrorView: View {
    let title: String
    let message: String
    let canRetry: Bool
    let onRetry: (() -> Void)?

    init(
        title: String,
        message: String,
        canRetry: Bool = true,
        onRetry: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.canRetry = canRetry
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: SpacingTokens.lg) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.error.opacity(0.8))

            VStack(spacing: SpacingTokens.xxs) {
                Text(title)
                    .displaySmall()

                Text(message)
                    .bodySmall()
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if canRetry, let retry = onRetry {
                Button {
                    retry()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .primaryButtonStyle()
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview("Network Error") {
    NetworkErrorView(
        title: "Network Error",
        message: "Please check your internet connection and try again.",
        canRetry: true,
        onRetry: {}
    )
}
