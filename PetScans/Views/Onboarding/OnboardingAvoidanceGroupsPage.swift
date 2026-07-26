import SwiftUI

/// Onboarding page dedicated to the avoidance groups. Split off the pet-setup
/// page so the name/species/ingredients form has room and the categories get a
/// screen of their own. Collected only — see `AvoidanceGroup`.
struct OnboardingAvoidanceGroupsPage: View {
    @Binding var selectedGroups: Set<AvoidanceGroup>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text("What should we watch out for?")
                        .font(TypographyTokens.displayMedium)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("It helps us improve what we focus on for your pet.")
                        .font(TypographyTokens.bodyLarge)
                        .foregroundColor(ColorTokens.textSecondary)
                }

                // The page title above already frames the question, so the
                // picker's own header would just repeat it.
                AvoidanceGroupPicker(selected: $selectedGroups, showHeader: false)
            }
            .padding(.horizontal, SpacingTokens.screenPadding)
            .padding(.top, SpacingTokens.md)
        }
        .accessibilityIdentifier("onboarding-avoidance-groups")
    }
}

#Preview {
    OnboardingAvoidanceGroupsPage(selectedGroups: .constant([]))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.backgroundPrimary)
}

#Preview("With Selections") {
    OnboardingAvoidanceGroupsPage(
        selectedGroups: .constant([.artificialColours, .grainFillers, .addedSugars])
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}
