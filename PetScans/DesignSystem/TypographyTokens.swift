import SwiftUI
import UIKit
import CoreText

/// Typography tokens for the PetScans design system
/// Inspired by Yuka's clean, readable sans-serif approach using Quicksand font
struct TypographyTokens {

    // MARK: - Font Name Constants

    /// Quicksand variable font name (supports weights 300-700)
    private static let quicksandFont = "Quicksand"

    // MARK: - Navigation Bar

    /// Quicksand as a `UIFont` at a given weight. Quicksand ships as a *variable*
    /// font, and in UIKit the symbolic `.traits[.weight]` descriptor does NOT move a
    /// variable font's weight (SwiftUI's `.weight(_:)` does, UIKit doesn't) — the
    /// title would render at the font's default weight. So the weight is applied by
    /// driving the `wght` variation axis directly. `weight` is a raw axis value on
    /// Quicksand's 300–700 scale (e.g. 600 semibold, 700 bold). Falls back to the
    /// system font if the family isn't registered yet.
    private static func quicksandUIFont(size: CGFloat, weight: CGFloat) -> UIFont {
        guard let base = UIFont(name: quicksandFont, size: size) else {
            return UIFont.systemFont(ofSize: size, weight: .bold)
        }
        let wghtAxis = 0x77676874 // 'wght' four-char code
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Route `.navigationTitle(...)` bar titles through Quicksand so the top-of-screen
    /// header matches the in-content headings (which already resolve to Quicksand via
    /// the `heading*`/`display*` tokens). Only the title *fonts* are overridden — the
    /// bar backgrounds keep the system defaults (opaque/blurred when scrolled,
    /// transparent at the scroll edge), so large- and inline-title screens look
    /// unchanged apart from the typeface. Inline titles are 17 bold — a step heavier
    /// than the semibold `heading2` used for list-item titles, so the page header
    /// sits above the content. Large titles match `displayLarge` (34 bold).
    static func configureNavigationBarAppearance() {
        let inlineTitle: [NSAttributedString.Key: Any] = [
            .font: quicksandUIFont(size: 17, weight: 700)
        ]
        let largeTitle: [NSAttributedString.Key: Any] = [
            .font: quicksandUIFont(size: 34, weight: 700)
        ]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.titleTextAttributes = inlineTitle
        standard.largeTitleTextAttributes = largeTitle

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.titleTextAttributes = inlineTitle
        scrollEdge.largeTitleTextAttributes = largeTitle

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = standard
        navBar.compactAppearance = standard
        navBar.scrollEdgeAppearance = scrollEdge
        navBar.compactScrollEdgeAppearance = scrollEdge
    }

    // MARK: - Display Styles (Large, Prominent)

    /// Display Large - For major headings, hero content
    /// 34pt, Bold
    static let displayLarge: Font = Font.custom(quicksandFont, size: 34).weight(.bold)

    /// Display Medium - Section headers
    /// 28pt, Bold
    static let displayMedium: Font = Font.custom(quicksandFont, size: 28).weight(.bold)

    /// Display Small - Card headers
    /// 22pt, Bold
    static let displaySmall: Font = Font.custom(quicksandFont, size: 22).weight(.bold)

    // MARK: - Heading Styles

    /// Heading 1 - Primary headings
    /// 20pt, Semibold
    static let heading1: Font = Font.custom(quicksandFont, size: 20).weight(.semibold)

    /// Heading 2 - Secondary headings
    /// 17pt, Semibold
    static let heading2: Font = Font.custom(quicksandFont, size: 17).weight(.semibold)

    /// Heading 3 - Tertiary headings
    /// 15pt, Medium
    static let heading3: Font = Font.custom(quicksandFont, size: 15).weight(.medium)

    // MARK: - Body Styles

    /// Body Large - Emphasized body text
    /// 17pt, Regular
    static let bodyLarge: Font = Font.custom(quicksandFont, size: 17).weight(.regular)

    /// Body - Standard body text
    /// 15pt, Regular
    static let body: Font = Font.custom(quicksandFont, size: 15).weight(.regular)

    /// Body Small - De-emphasized body text
    /// 13pt, Regular
    static let bodySmall: Font = Font.custom(quicksandFont, size: 13).weight(.regular)

    // MARK: - Label Styles

    /// Label Large - Button text, tabs
    /// 17pt, Semibold
    static let labelLarge: Font = Font.custom(quicksandFont, size: 17).weight(.semibold)

    /// Label Medium - Secondary buttons, chips
    /// 15pt, Medium
    static let labelMedium: Font = Font.custom(quicksandFont, size: 15).weight(.medium)

    /// Label Small - Badges, tags
    /// 13pt, Medium
    static let labelSmall: Font = Font.custom(quicksandFont, size: 13).weight(.medium)

    // MARK: - Caption Styles

    /// Caption - Metadata, timestamps
    /// 12pt, Regular
    static let caption: Font = Font.custom(quicksandFont, size: 12).weight(.regular)

    /// Caption Emphasized - Important metadata
    /// 12pt, Medium
    static let captionEmphasis: Font = Font.custom(quicksandFont, size: 12).weight(.medium)

    // MARK: - Score Styles (Special)

    /// Score Display - Large circular scores
    /// Dynamic size based on container, Bold
    static func scoreDisplay(size: CGFloat) -> Font {
        let fontSize = size * 0.35
        return Font.custom(quicksandFont, size: fontSize).weight(.bold)
    }

    /// Score Value - Inline score numbers
    /// 17pt, Bold
    static let scoreValue: Font = Font.custom(quicksandFont, size: 17).weight(.bold)
}

// MARK: - View Extensions for Easy Application

extension View {
    /// Apply Display Large typography style
    func displayLarge() -> some View {
        self.font(TypographyTokens.displayLarge)
    }

    /// Apply Display Medium typography style
    func displayMedium() -> some View {
        self.font(TypographyTokens.displayMedium)
    }

    /// Apply Display Small typography style
    func displaySmall() -> some View {
        self.font(TypographyTokens.displaySmall)
    }

    /// Apply Heading 1 typography style
    func heading1() -> some View {
        self.font(TypographyTokens.heading1)
    }

    /// Apply Heading 2 typography style
    func heading2() -> some View {
        self.font(TypographyTokens.heading2)
    }

    /// Apply Heading 3 typography style
    func heading3() -> some View {
        self.font(TypographyTokens.heading3)
    }

    /// Apply Body typography style
    func bodyText() -> some View {
        self.font(TypographyTokens.body)
    }

    /// Apply Body Large typography style
    func bodyLarge() -> some View {
        self.font(TypographyTokens.bodyLarge)
    }

    /// Apply Body Small typography style
    func bodySmall() -> some View {
        self.font(TypographyTokens.bodySmall)
    }

    /// Apply Label Large typography style
    func labelLarge() -> some View {
        self.font(TypographyTokens.labelLarge)
    }

    /// Apply Label Medium typography style
    func labelMedium() -> some View {
        self.font(TypographyTokens.labelMedium)
    }

    /// Apply Label Small typography style
    func labelSmall() -> some View {
        self.font(TypographyTokens.labelSmall)
    }

    /// Apply Caption typography style
    func caption() -> some View {
        self.font(TypographyTokens.caption)
    }

    /// Apply Caption Emphasis typography style
    func captionEmphasis() -> some View {
        self.font(TypographyTokens.captionEmphasis)
    }
}
