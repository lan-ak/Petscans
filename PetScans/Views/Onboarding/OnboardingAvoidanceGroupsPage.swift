import SwiftUI

/// Onboarding page dedicated to the avoidance groups. Split off the pet-setup
/// page so the name/species/ingredients form has room and the categories get a
/// screen of their own. These feed scoring on every scan — see `AvoidanceGroup`.
struct OnboardingAvoidanceGroupsPage: View {
    @Binding var selectedGroups: Set<AvoidanceGroup>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("What should we watch out for?")
                        .font(TypographyTokens.displayMedium)
                        .foregroundColor(ColorTokens.textPrimary)

                    Text("We'll warn you whenever a food contains these — pick as many or as few as you like.")
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
