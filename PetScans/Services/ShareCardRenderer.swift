import SwiftUI
import UIKit

/// Turns a `ShareCardView` into an image `ShareLink` can hand to the share sheet.
@MainActor
enum ShareCardRenderer {

    /// Rendered at 2x the 1080pt canvas. Big enough that Instagram Stories and
    /// iMessage don't resample it into mush, small enough that the PNG stays
    /// well under a megabyte.
    private static let scale: CGFloat = 2

    static func render(
        productName: String,
        brand: String?,
        breakdown: ScoreBreakdown,
        petName: String?
    ) -> UIImage? {
        let card = ShareCardView(
            productName: productName,
            brand: brand,
            breakdown: breakdown,
            petName: petName
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        // The card declares its own frame; without this the renderer proposes
        // the container size and the fixed layout gets clipped.
        renderer.proposedSize = ProposedViewSize(
            width: ShareCardView.canvas,
            height: ShareCardView.canvas
        )

        return renderer.uiImage
    }
}

/// `ShareLink` needs a `Transferable`. This exports a single thing — the PNG —
/// on purpose.
///
/// An earlier version also carried a `ProxyRepresentation(\.text)` so a text
/// target could fall back to the plain summary. In practice the text proxy won
/// the share sheet's preview: the header rendered the text block with a text
/// glyph instead of the card thumbnail, and image targets are the whole point.
/// One representation, no ambiguity — the card image is what every target gets.
struct ShareCard: Transferable {
    let image: UIImage
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            guard let data = card.image.pngData() else {
                throw ShareCardError.encodingFailed
            }
            return data
        }
        .suggestedFileName("petscans-score.png")
    }
}

enum ShareCardError: Error {
    case encodingFailed
}
