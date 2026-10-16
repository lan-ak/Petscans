import SwiftUI

/// Spacing tokens for the PetScans design system
/// Provides consistent padding, margins, and gaps using a 4pt grid system
struct SpacingTokens {

    // MARK: - Core Spacing Scale (4pt grid)

    /// 4pt - Minimal spacing
    static let xxxs: CGFloat = 4

    /// 8pt - Small spacing, tight groups
    static let xxs: CGFloat = 8

    /// 12pt - Standard compact spacing
    static let xs: CGFloat = 12

    /// 16pt - Standard spacing (most common)
    static let sm: CGFloat = 16

    /// 20pt - Medium spacing
    static let md: CGFloat = 20

    /// 24pt - Large spacing
    static let lg: CGFloat = 24

    /// 32pt - Extra large spacing
    static let xl: CGFloat = 32

    /// 40pt - Section dividers
    static let xxl: CGFloat = 40

    /// 48pt - Major section breaks
    static let xxxl: CGFloat = 48

    // MARK: - Semantic Spacing

    /// Padding inside cards
    static let cardPadding: CGFloat = sm

    /// Padding for screen edges
    static let screenPadding: CGFloat = sm

    /// Gap between cards in a list
    static let cardGap: CGFloat = xs

    /// Gap between sections
    static let sectionGap: CGFloat = lg

    /// Gap between elements in a group
    static let groupGap: CGFloat = xxs

    // MARK: - Corner Radius

    /// Small radius - chips, badges
    static let radiusSmall: CGFloat = 8

    /// Medium radius - buttons, inputs
    static let radiusMedium: CGFloat = 12

    /// Large radius - cards
    static let radiusLarge: CGFloat = 16

    /// Extra large radius - prominent elements
    static let radiusXLarge: CGFloat = 20

    /// Circular - pills, circular buttons
    static let radiusCircular: CGFloat = 999

    // MARK: - Icon Sizes

    /// Page indicator dot (onboarding). A size, not a gap — kept distinct from
    /// the spacing scale so changing spacing does not resize the dots.
    static let indicatorDot: CGFloat = 8

    /// Small icon
    static let iconSmall: CGFloat = 16

    /// Standard icon
    static let iconMedium: CGFloat = 24

    /// Settings row icon alignment
    static let iconSettingsRow: CGFloat = 28

    /// Large icon
    static let iconLarge: CGFloat = 32

    /// Small score circles (history list)
    /// A product thumbnail in a list row. Between `iconLarge` and
    /// `iconScoreSmall`, which is why call sites were writing a bare 48.
    static let iconThumbnail: CGFloat = 48

    static let iconScoreSmall: CGFloat = 50

    /// Camera capture button inner
    static let captureButtonInner: CGFloat = 58

    /// Extra large icon (empty states)
    static let iconXLarge: CGFloat = 60

    /// Camera capture button outer
    static let captureButtonOuter: CGFloat = 70

    /// Extra extra large icon (onboarding, hero elements)
    static let iconXXLarge: CGFloat = 80

    /// Hero icon (splash screen)
    static let iconHero: CGFloat = 100

    /// Onboarding/product images
    static let iconOnboarding: CGFloat = 120

    // MARK: - Minimum Touch Target

    /// Minimum touch target size (44x44 per Apple HIG)
    /// The gap below a primary CTA pinned to the bottom of a full screen.
    ///
    /// One value, because the CTA must not move as the user walks the flow.
    /// This was hardcoded per screen and drifted to four different values —
    /// `OnboardingFoodResultView` still carries the comment from the last
    /// time someone chased it ("at md the CTA sat 20pt lower than on every
    /// other page, so the primary button visibly jumped"). The safe-area
    /// inset sits underneath this, so it is a gap above the home indicator,
    /// not the whole distance to the screen edge.
    static let ctaBottomInset: CGFloat = lg

    static let minTouchTarget: CGFloat = 44
}

