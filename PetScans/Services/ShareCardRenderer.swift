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

/// `ShareLink` needs a `Transferable`. Wrapping the image lets the same item
/// carry the text fallback, so a target that can't take an image (Notes, Mail
/// as plain text) still gets something useful instead of nothing.
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

        ProxyRepresentation(exporting: \.text)
    }
}

enum ShareCardError: Error {
    case encodingFailed
}
