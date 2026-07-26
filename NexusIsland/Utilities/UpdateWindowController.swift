import AppKit
import SwiftUI

@MainActor
final class UpdateWindowController {
    private let window: NSWindow

    /// `downloadURL` is the direct link to the signed DMG on R2. It is also
    /// used as the browser fallback if the in-app installer fails.
    init(version: String, releaseNotes: [String], downloadURL: URL) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 210),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = true
        window.backgroundColor = NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.minSize = CGSize(width: 300, height: 210)
        window.maxSize = CGSize(width: 300, height: 210)
        // Keep the update dialog ABOVE every other window — including the
        // Settings window the user just clicked "Update" from. Without an
        // explicit level the dialog opens at .normal and is occluded by the
        // Settings window, which makes the "Update" button look dead (the
        // dialog is actually shown but hidden behind Settings).
        window.level = .floating
        // The dialog should still appear during Spaces/fullscreen transitions
        // so the user doesn't miss an update that was triggered just before
        // they swapped spaces.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Hide the standard traffic-light buttons — the dialog uses its own
        // Later/Update actions and shouldn't be closable from the title bar.
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let rootView = UpdateDialogView(
            version: version,
            releaseNotes: releaseNotes,
            downloadURL: downloadURL,
            onDismiss: { [weak self] in self?.close() }
        )
        window.contentViewController = NSHostingController(rootView: rootView)
    }

    func show() {
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let origin = NSPoint(
                x: sf.midX - window.frame.width / 2,
                y: sf.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }
        // Activate the app first so the window is allowed to take focus, then
        // order the dialog front and make it the key window. `activate()` is
        // the macOS 14+ replacement for the deprecated
        // `NSApp.activate(ignoringOtherApps:)`. Combined with `.floating`
        // level (set in init) this guarantees the dialog is visible above the
        // Settings window the user just acted on.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // Re-assert the level after ordering front — some macOS versions reset
        // the level when a window becomes key, which would push it back behind
        // the Settings window.
        window.level = .floating
    }

    func close() {
        window.orderOut(nil)
    }
}
