import SwiftUI
import UIKit

/// The species control, as the two animals themselves.
///
/// This replaces a segmented `Picker` that defaulted to `.dog`. Nobody experienced
/// that as a decision — a dog owner never noticed it and a cat owner corrected it —
/// so the species the whole demo was scored against was an assumption rather than an
/// answer. Nothing is preselected here.
///
/// Choosing is two beats rather than one. The unchosen animal dims **in place and
/// stays tappable**, so a mis-tap is recoverable inside the same gesture; it is the
/// screen transition that takes it away, not the tap. The escape hatch matters: the
/// choice drives scoring for every scan afterwards.
struct CompanionSpeciesPicker: View {
    @Binding var selection: Species?
    var onPick: ((Species) -> Void)? = nil

    @State private var perkDog = 0
    @State private var perkCat = 0

    private let rigHeight = CompanionSize.standard.points

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            card(for: .dog)
            card(for: .cat)
        }
        .accessibilityElement(children: .contain)
    }

    private func card(for species: Species) -> some View {
        let isChosen = selection == species
        let isDimmed = selection != nil && !isChosen

        return Button {
            let alreadyChosen = selection == species
            // A choice this consequential should be felt, not only seen. Selection
            // feedback rather than an impact: this is a picker, not a button press.
            UISelectionFeedbackGenerator().selectionChanged()
            selection = species
            if species == .dog { perkDog += 1 } else { perkCat += 1 }
            if !alreadyChosen { onPick?(species) }
        } label: {
            VStack(spacing: SpacingTokens.xxxs) {
                CompanionView(
                    species: species,
                    perkToken: species == .dog ? perkDog : perkCat,
                    height: rigHeight,
                    // Two animals arriving on the same frame read as one image.
                    entranceDelay: species == .dog ? 0.05 : 0.17
                )
                Text(species.displayName)
                    .font(TypographyTokens.labelLarge)
                    .foregroundColor(isChosen ? ColorTokens.textPrimary : ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.xxs)
            // A resting card from the first frame. An unselected animal sitting on the
            // page ground with a caption under it is art, not a control.
            .raisedSurface(
                cornerRadius: SpacingTokens.radiusXLarge,
                glow: isChosen ? ColorTokens.brandPrimary.opacity(0.22) : nil
            )
            // Selection is carried by a tinted wash *and* a ring. A bare 2pt stroke on
            // its own reads as a focus rectangle, not as a choice.
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.radiusXLarge, style: .continuous)
                    .fill(ColorTokens.brandPrimary.opacity(isChosen ? 0.07 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SpacingTokens.radiusXLarge, style: .continuous)
                    .strokeBorder(isChosen ? ColorTokens.brandPrimary : ColorTokens.border,
                                  lineWidth: isChosen ? 2 : 1)
            )
            // Dimmed enough to be unmistakably unselected, but not so far that it reads as
            // disabled: this animal is still a live target, and a mis-tap has to be
            // recoverable in the same gesture. Desaturating does more of that work than
            // opacity alone, which just makes it look switched off.
            .opacity(isDimmed ? 0.62 : 1)
            // 0.4 was asymmetric: the tan dog still read as a dog, the already-grey cat
            // went dead. Dim enough to be unmistakably unselected, not so far that one of
            // the two animals loses its identity.
            .saturation(isDimmed ? 0.7 : 1)
            .scaleEffect(isChosen ? 1.035 : (isDimmed ? 0.97 : 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: selection)
        .accessibilityIdentifier("companion-pick-\(species.rawValue)")
        .accessibilityLabel(species.displayName)
        .accessibilityHint("Shows \(species.displayName.lowercased()) food brands")
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Hero pair

/// The welcome screen's pair. Not a control — it carries the promise while the
/// headline names the outcome, and it is the first thing that says this app is
/// about an animal rather than a database.
struct CompanionPair: View {
    var height: CGFloat = CompanionSize.hero.points
    @State private var perk = 0

    var body: some View {
        HStack(spacing: -height * 0.08) {
            CompanionView(species: .dog, perkToken: perk, height: height, entranceDelay: 0.08)
            CompanionView(species: .cat, perkToken: perk, height: height * 0.9, entranceDelay: 0.22)
                .offset(y: height * 0.075)
        }
        // Tapping the welcome pair must never fork the flow — the species question is
        // asked once, on the search screen, and only there.
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            perk += 1
        }
        .accessibilityHidden(true)
    }
}

#Preview("Picker") {
    VStack(spacing: 40) {
        CompanionSpeciesPicker(selection: .constant(nil))
        CompanionSpeciesPicker(selection: .constant(.cat))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ColorTokens.backgroundPrimary)
}

#Preview("Hero pair") {
    CompanionPair()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.backgroundPrimary)
}
