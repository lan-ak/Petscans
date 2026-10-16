#if DEBUG
import SwiftUI
import UIKit

/// Renders the companion rigs to transparent PNGs so the Superwall onboarding
/// surface can ship the *same* artwork the native screens draw.
///
/// The companions are code-drawn (`CompanionCanvas` and friends), not image
/// assets, so there is no file to hand the webview. Re-drawing them in SVG
/// would be a second source of truth that drifts the first time the rig
/// changes; rendering the real views keeps one.
///
/// DEBUG-only and launch-argument gated, so it is never reachable in a
/// release build. Run with `-ExportCompanions`, then pull them out of the
/// app container:
///
///     xcrun simctl launch <sim> com.petscans.app -ExportCompanions
///     xcrun simctl get_app_container <sim> com.petscans.app data
///
/// Output lands in `Documents/companion-export/`.
@MainActor
enum CompanionExport {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-ExportCompanions")
    }

    /// 3x, matching the densest screen the surface runs on. The webview scales
    /// down cleanly; it cannot scale up.
    private static let scale: CGFloat = 3

    static func runIfRequested() {
        guard isRequested else { return }

        let dir = URL.documentsDirectory.appending(path: "companion-export")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Entrance animations start from a transformed state, and a render
        // taken on frame zero would catch the rig mid-arrival. `entranceDelay`
        // is the only knob that matters here; mood stays neutral because that
        // is what both onboarding screens show.
        write(CompanionView(species: .dog, height: 156 * 1.0), to: dir, name: "companion-dog")
        write(CompanionView(species: .cat, height: 156 * 0.9), to: dir, name: "companion-cat")
        write(CompanionPair(height: 156), to: dir, name: "companion-pair")

        NSLog("[CompanionExport] wrote PNGs to \(dir.path)")
    }

    private static func write<V: View>(_ view: V, to dir: URL, name: String) {
        // Fixed sizing so the renderer measures the rig and not the screen.
        let renderer = ImageRenderer(content: view.fixedSize())
        renderer.scale = scale
        // Transparent, so the art composites onto whichever ground the surface
        // is using — the page background differs between light and dark.
        renderer.isOpaque = false

        guard let image = renderer.uiImage, let data = image.pngData() else {
            NSLog("[CompanionExport] FAILED to render \(name)")
            return
        }
        try? data.write(to: dir.appending(path: "\(name)@3x.png"))
    }
}
#endif
