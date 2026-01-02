import SwiftUI

/// Reusable empty state view for displaying when lists are empty.
/// Used in HistoryView and PetListView.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: SpacingTokens.iconXLarge))
                .foregroundColor(ColorTokens.textSecondary)

            Text(title)
                .displaySmall()

            Text(subtitle)
                .bodySmall()
                .foregroundColor(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                }
                .primaryButtonStyle()
                .padding(.horizontal, SpacingTokens.xl)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview("With Action") {
    EmptyStateView(
        icon: "pawprint",
        title: "No Pets Yet",
        subtitle: "Add your pets to track their allergens",
        actionTitle: "Add Your First Pet",
        action: {}
    )
}

#Preview("Without Action") {
    EmptyStateView(
        icon: "clock",
        title: "No Scans Yet",
        subtitle: "Scan a product to see it here"
    )
}
