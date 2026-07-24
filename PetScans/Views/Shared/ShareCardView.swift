import SwiftUI

/// The square card rendered into a shareable image.
///
/// Sharing used to hand over `ScoreBreakdown.generateShareText` — a block of
/// box-drawing characters and colon-separated numbers. It reads as a debug dump
/// and nobody posts it. A scored card with the product named on it is the same
/// information in a form that survives being pasted into a group chat.
///
/// Laid out at a fixed 1080pt square and scaled by `ImageRenderer`, so the
/// output is identical regardless of the device that produced it. Nothing here
/// uses `@Environment` for that reason — an off-screen render gets default
/// values, and a card that changes with the sharer's Dynamic Type setting is
/// not a shareable asset.
struct ShareCardView: View {
    let productName: String
    let brand: String?
    let breakdown: ScoreBreakdown
    let petName: String?

    /// Design canvas. `ImageRenderer` scales the whole thing, so every constant
    /// below is relative to this and the card resizes as one piece.
    static let canvas: CGFloat = 1080

    private var unit: CGFloat { Self.canvas / 1080 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 0)

            scoreBlock

            Spacer(minLength: 0)

            if !headlineFlags.isEmpty {
                flagList
                Spacer(minLength: 0)
            }

            footer
        }
        .padding(72 * unit)
        .frame(width: Self.canvas, height: Self.canvas)
        .background(ColorTokens.backgroundPrimary)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12 * unit) {
            if let brand, !brand.isEmpty {
                Text(brand.uppercased())
                    .font(.system(size: 30 * unit, weight: .semibold, design: .rounded))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
            }

            Text(productName)
                .font(.system(size: 54 * unit, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scoreBlock: some View {
        HStack(spacing: 40 * unit) {
            ScoreCircleView(score: breakdown.total, size: 260 * unit)

            VStack(alignment: .leading, spacing: 16 * unit) {
                Text(breakdown.ratingLabel.rawValue)
                    .font(.system(size: 68 * unit, weight: .bold, design: .rounded))
                    .foregroundStyle(breakdown.ratingLabel.color)

                // The per-pet verdict is the thing PetScans has that a generic
                // ingredient lookup doesn't, so it goes on the card by name.
                if let petName, !petName.isEmpty {
                    Text(petVerdict(for: petName))
                        .font(.system(size: 32 * unit, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var flagList: some View {
        VStack(alignment: .leading, spacing: 18 * unit) {
            ForEach(headlineFlags) { flag in
                HStack(alignment: .top, spacing: 18 * unit) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30 * unit))
                        .foregroundStyle(flag.severity.color)

                    Text(flag.title)
                        .font(.system(size: 32 * unit, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 16 * unit) {
            PetScansLogo(size: .small, showText: true)

            Spacer(minLength: 0)

            Text("petscans.app")
                .font(.system(size: 28 * unit, weight: .medium, design: .rounded))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }

    // MARK: - Content

    /// Allergen conflicts first — they are the pet-specific finding and the
    /// reason someone shares a card at all. Capped at three so the card stays
    /// legible at thumbnail size in a chat list.
    private var headlineFlags: [WarningFlag] {
        Array((breakdown.allergenFlags + breakdown.otherFlags).prefix(3))
    }

    private func petVerdict(for petName: String) -> String {
        breakdown.allergenFlags.isEmpty
            ? "No conflicts with \(petName)'s profile"
            : "Contains ingredients \(petName) should avoid"
    }
}

#Preview {
    ShareCardView(
        productName: "Life Protection Formula Adult Chicken & Brown Rice",
        brand: "Blue Buffalo",
        breakdown: .empty,
        petName: "Luna"
    )
    .scaleEffect(0.3)
}
