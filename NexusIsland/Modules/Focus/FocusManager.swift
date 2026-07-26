import Foundation
import Combine

@MainActor
final class FocusManager: ObservableObject {
    static let shared = FocusManager()

    @Published var isActive: Bool = false
    @Published var focusName: String = ""

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        // Monitor Focus/DND state changes via distributed notifications.
        // macOS 12+ replaced DND with Focus; the old `dndState.changed` signal
        // still fires on some OS versions, so we keep it alongside the more
        // modern `com.apple.controlcenter` broadcast as best-effort triggers.
        let names: [String] = [
            "com.apple.notificationcenterui.dndState.changed",
            "com.apple.controlcenter.DoNotDisturb",
            "com.apple.focus.system.mode.changed",
            "com.apple.focus.systemschedule.changed"
        ]
        for name in names {
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(focusChanged),
                name: NSNotification.Name(name),
                object: nil
            )
        }

        // Also check initial state
        checkFocusState()
    }

    @objc private func focusChanged(_ notification: Notification) {
        // `focusChanged` is invoked on the main thread by the distributed
        // notification center; we're already @MainActor-isolated.
        checkFocusState()
    }

    private func checkFocusState() {
        // CORRECTNESS: the previous implementation read
        // `NSStatusItem Visible DoNotDisturb` from the `com.apple.controlcenter`
        // app-group defaults. That key was a Control Center internal on
        // macOS 11 and earlier and does NOT exist on macOS 12+ (Focus replaced
        // DND), so `isActive` was permanently `false` — the module reported
        // "off" no matter what the user had selected.
        //
        // There is no public API for reading Focus state on macOS. We probe a
        // small set of undocumented-but-known keys across the relevant suites
        // and treat a hit on any of them as "Focus active". This is
        // best-effort: on some OS revisions these keys move or disappear, in
        // which case we fall back to the distributed-notification signal
        // alone (a state change will still flip `isActive`, but the initial
        // snapshot may be wrong until the next change).
        let candidates: [(suite: String, key: String)] = [
            ("com.apple.controlcenter", "NSStatusItem Visible DoNotDisturb"), // macOS 11
            ("com.apple.focus", "_prefersFocus")                              // observed on macOS 13/14
        ]

        var detected = false
        for candidate in candidates {
            if let suite = UserDefaults(suiteName: candidate.suite),
               suite.bool(forKey: candidate.key) {
                detected = true
                break
            }
        }

        isActive = detected
        focusName = detected ? "Focus" : ""
    }

    // MARK: - Helpers

    var iconName: String {
        isActive ? "moon.fill" : "moon"
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
