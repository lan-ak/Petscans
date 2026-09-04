import SwiftUI

/// Multi-select list of ingredient categories the owner would rather avoid.
///
/// Rows rather than chips: each group needs its example line to be meaningful,
/// which does not fit a chip. Layout follows `ScanTargetRow` so selection
/// styling stays consistent across the app.
struct AvoidanceGroupPicker: View {
    @Binding var selected: Set<AvoidanceGroup>
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if showHeader {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("Anything you'd rather avoid?")
                        .heading3()

                    Text("(optional)")
                        .caption()
                        .foregroundColor(ColorTokens.textTertiary)
                }
            }

            ForEach(AvoidanceGroup.allCases) { group in
                AvoidanceGroupRow(
                    group: group,
                    isSelected: selected.contains(group),
                    onToggle: { toggle(group) }
                )
            }
        }
        .accessibilityIdentifier("avoidance-group-picker")
    }

    private func toggle(_ group: AvoidanceGroup) {
        if selected.contains(group) {
            selected.remove(group)
        } else {
            selected.insert(group)
        }
    }
}

/// One selectable group. Mirrors `ScanTargetRow`'s layout and selection styling.
private struct AvoidanceGroupRow: View {
    let group: AvoidanceGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: group.icon)
                    .font(PetIconSize.small.font)
                    .foregroundColor(isSelected ? .white : ColorTokens.brandPrimary)
                    .frame(width: PetIconSize.small.frameSize, height: PetIconSize.small.frameSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .heading3()
                        .foregroundColor(isSelected ? .white : ColorTokens.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(group.examples)
                        .caption()
                        .foregroundColor(isSelected ? .white.opacity(0.8) : ColorTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(TypographyTokens.heading1)
                    .foregroundColor(isSelected ? .white : ColorTokens.textSecondary)
            }
            .padding(SpacingTokens.xs)
            // The same raised card every other tappable row in the flow uses. These were
            // flat inset panels, which put the one screen made entirely of choices into a
            // different visual language from every other screen of choices.
            .raisedSurface(
                cornerRadius: SpacingTokens.radiusMedium,
                fill: isSelected ? ColorTokens.brandPrimary : ColorTokens.surfacePrimary,
                glow: isSelected ? ColorTokens.brandPrimary.opacity(0.22) : nil
            )
        }
        .buttonStyle(.plain)
        .animateSnappy(value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ScrollView {
        AvoidanceGroupPicker(selected: .constant([.artificialColours]))
            .padding()
    }
    .background(ColorTokens.backgroundPrimary)
}
