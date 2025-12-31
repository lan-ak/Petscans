import SwiftUI

/// Reusable view for displaying errors with retry and alternative actions
struct NetworkErrorView: View {
    let title: String
    let message: String
    let canRetry: Bool
    let onRetry: (() -> Void)?
    let onAlternative: (() -> Void)?
    let alternativeLabel: String?

    init(
        title: String,
        message: String,
        canRetry: Bool = true,
        onRetry: (() -> Void)? = nil,
        onAlternative: (() -> Void)? = nil,
        alternativeLabel: String? = nil
    ) {
        self.title = title
        self.message = message
        self.canRetry = canRetry
        self.onRetry = onRetry
        self.onAlternative = onAlternative
        self.alternativeLabel = alternativeLabel
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

            VStack(spacing: SpacingTokens.xs) {
                if canRetry, let retry = onRetry {
                    Button {
                        retry()
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .primaryButtonStyle()
                }

                if let alternative = onAlternative, let label = alternativeLabel {
                    Button {
                        alternative()
                    } label: {
                        Text(label)
                    }
                    .secondaryButtonStyle()
                }
            }
            .padding(.horizontal)

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
        onRetry: {},
        onAlternative: {},
        alternativeLabel: "Enter Manually"
    )
}

#Preview("Product Not Found") {
    NetworkErrorView(
        title: "Product Not Found",
        message: "This product wasn't found in our database.",
        canRetry: false,
        onAlternative: {},
        alternativeLabel: "Enter Manually"
    )
}
