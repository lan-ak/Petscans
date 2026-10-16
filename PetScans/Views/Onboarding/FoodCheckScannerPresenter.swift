import SwiftUI
import UIKit

/// Presents the barcode scanner *over* the onboarding food-check surface and
/// awaits a read.
///
/// The surface is a full-screen paywall view controller the SDK owns, so the
/// scanner cannot be a SwiftUI sheet inside the onboarding hierarchy — there
/// is no SwiftUI in front at that moment. It is presented on the topmost
/// controller instead and bridged back through a continuation.
@MainActor
enum FoodCheckScannerPresenter {
    /// Resolves with the raw barcode string, or nil when the user backed out
    /// or the camera failed. Nil is an ordinary outcome: the surface keeps the
    /// user where they were, with all three paths still on offer.
    static func presentAndScan() async -> String? {
        guard let host = topViewController() else { return nil }

        return await withCheckedContinuation { continuation in
            // The continuation must resume exactly once. The scanner can
            // report a read, an error and a dismissal in quick succession
            // (a scan fires, then the sheet's dismissal handler runs), so
            // every path funnels through this one latch.
            var finished = false
            weak var presented: UIViewController?

            @MainActor
            func finish(_ barcode: String?) {
                guard !finished else { return }
                finished = true
                presented?.dismiss(animated: true)
                continuation.resume(returning: barcode)
            }

            let controller = UIHostingController(
                rootView: FoodCheckScannerSheet(
                    onScan: { finish($0) },
                    onCancel: { finish(nil) }
                )
            )
            controller.modalPresentationStyle = .fullScreen
            presented = controller
            host.present(controller, animated: true)
        }
    }

    /// Walks presented controllers from the key window's root. The paywall is
    /// itself a presented controller, so the scanner has to go on top of it
    /// rather than on the root.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        guard var top = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController else {
            return nil
        }
        while let next = top.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }
}

/// The scanner chrome. Deliberately minimal — it is a camera, and the
/// onboarding copy around it already explained what to point it at.
///
/// Internal rather than private: both callers present it — the surface
/// through `FoodCheckScannerPresenter` (which has to reach over a paywall
/// view controller the SDK owns) and the native fallback as an ordinary
/// `fullScreenCover`. One scanner, two hosts.
struct FoodCheckScannerSheet: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    @State private var failure: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let failure {
                VStack(spacing: SpacingTokens.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: SpacingTokens.iconLarge))
                        .foregroundColor(.white.opacity(0.7))
                    Text(failure)
                        .font(TypographyTokens.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpacingTokens.xl)
                    Button("Go back", action: onCancel)
                        .font(TypographyTokens.labelLarge)
                        .foregroundColor(ColorTokens.brandPrimary)
                        .padding(.top, SpacingTokens.xs)
                }
            } else {
                BarcodeScannerView(
                    onScan: onScan,
                    // A camera that cannot start is shown, not swallowed —
                    // silently returning nil would drop the user back on the
                    // surface with no explanation for why nothing happened.
                    onError: { failure = $0 }
                )
                .ignoresSafeArea()

                ScanningReticleView()

                VStack {
                    Spacer()
                    Text("Line up the barcode on the bag")
                        .font(TypographyTokens.body)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, SpacingTokens.xxxl)
                }
            }

            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(TypographyTokens.heading2)
                            .foregroundColor(.white)
                            .frame(
                                width: SpacingTokens.minTouchTarget,
                                height: SpacingTokens.minTouchTarget
                            )
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("food-check-scanner-close")
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.screenPadding)
                Spacer()
            }
        }
    }
}
