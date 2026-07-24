import Foundation
import os

/// Launch-time signposts, so "the app takes a while to open" can be answered with
/// numbers instead of guesses.
///
/// Marks land in two places: Instruments' Points of Interest track (record a cold
/// launch with the App Launch template), and Console/Xcode via `os_log`, where each
/// line carries milliseconds since the first mark of the process.
///
/// Signposts are cheap enough to leave in release builds, and that is the point — an
/// Instruments trace of the shipping binary is the only measurement that reflects
/// what users actually wait through.
enum LaunchMetrics {
    private static let log = OSLog(subsystem: "com.petscans.app", category: .pointsOfInterest)
    private static let signposter = OSSignposter(logHandle: log)

    /// Initialized on first access, which by construction is the first `mark` of the
    /// process — `PetScansApp.init`. Every later reading is therefore "milliseconds
    /// since the app struct began initializing", slightly after true process start:
    /// dyld and framework loading come first, and Instruments' App Launch track
    /// covers that stretch separately.
    ///
    /// A `let` rather than a lock: Swift guarantees a static's initializer runs
    /// exactly once, so this is both race-free and cheaper than guarding a `var`.
    private static let start = ContinuousClock.now

    /// Records a named instant. The call sites are the launch critical path —
    /// `appInitStart` → `appInitEnd` → `didFinishLaunching` → `firstFrame` — plus
    /// `ingredientDBLoaded`, which lands whenever the background decode finishes.
    static func mark(_ name: StaticString) {
        let elapsed = start.duration(to: .now)

        signposter.emitEvent(name)
        os_log("%{public}s at %{public}.1fms", log: log, type: .info,
               String(describing: name), elapsed.milliseconds)
    }

    /// `mark`, but only the first time for a given name. For call sites that run
    /// repeatedly and where only the first is a launch measurement — a SwiftUI
    /// `body`, which is re-evaluated on every state change.
    static func markOnce(_ name: StaticString) {
        let isFirst = seen.withLock { $0.insert(String(describing: name)).inserted }
        guard isFirst else { return }
        mark(name)
    }

    private static let seen = OSAllocatedUnfairLock(initialState: Set<String>())
}

private extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000 + Double(attoseconds) / 1_000_000_000_000_000
    }
}
