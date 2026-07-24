import AVFoundation
import UIKit

/// Camera authorization state for the scanner.
///
/// Previously nothing in the app checked this: `BarcodeScannerView.isSupported`
/// is hardcoded `true`, so a user who denied camera access got a live capture
/// session that rendered nothing — a black screen with no explanation and no
/// route to Settings. That state is reached by first-time users, who meet the
/// system prompt on the very first screen after onboarding.
@MainActor
final class CameraPermission: ObservableObject {
    enum State {
        /// Not asked yet. Show a priming screen before triggering the system
        /// prompt: iOS only ever asks once, and an unprimed prompt is answered
        /// with "Don't Allow" far more often.
        case notDetermined
        case authorized
        /// Denied, or restricted by parental controls / MDM. Both are recovered
        /// the same way — through Settings.
        case denied
    }

    @Published private(set) var state: State

    init() {
        state = Self.currentState()
    }

    private static func currentState() -> State {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// Triggers the system prompt. Only meaningful while `.notDetermined` —
    /// afterwards iOS returns the stored answer without showing UI.
    func request() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        state = granted ? .authorized : .denied
    }

    /// Re-reads the status. Call on foreground: the user may have granted
    /// access in Settings, and returning to a still-broken scanner would read
    /// as the grant not having worked.
    func refresh() {
        state = Self.currentState()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
