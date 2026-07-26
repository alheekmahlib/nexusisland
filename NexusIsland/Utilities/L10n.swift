import Foundation

// MARK: - Runtime Language Override
//
// On macOS, Bundle.main.preferredLocalizations is resolved very early from
// the user's AppleLanguages defaults, before most app code runs. Setting
// AppleLanguages at runtime therefore doesn't reliably flip NSLocalizedString
// lookups in the current process — the bundle has already chosen its language.
//
// The standard, reliable workaround is to swizzle Bundle.main's
// localizedString(forKey:value:table:) so it prefers our overridden language
// .lproj. We swap the bundle's method on a swizzled subclass and replace
// Bundle.main once, at launch, before any UI is built.
//
// Usage: call L10n.applyOverride() at the very start of
// applicationDidFinishLaunching (before AppState is first read) and again
// whenever the user changes the language. A restart prompt is still shown
// for the few strings cached by SwiftUI.

enum L10n {
    /// The active language code ("en", "ar"), or nil to follow the system.
    static var preferredLanguage: String? {
        get { UserDefaults.standard.string(forKey: "general.language").flatMap { $0 == "system" ? nil : $0 } }
        set { UserDefaults.standard.set(newValue ?? "system", forKey: "general.language") }
    }

    /// Apply the override by swapping Bundle.main for a language-aware proxy.
    /// Safe to call multiple times.
    static func applyOverride() {
        let lang = preferredLanguage
        guard let lang else {
            // Reset to the system bundle if previously overridden.
            resetBundleIfNeeded()
            return
        }

        // Build a bundle that loads the specific language's .lproj on top of
        // the main bundle's resources.
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            object_setClass(Bundle.main, LanguageOverrideBundle.self)
            LanguageOverrideBundle.overrideBundle = langBundle
        }
    }

    /// Restore Bundle.main to its original class so it follows the system again.
    private static func resetBundleIfNeeded() {
        if object_getClass(Bundle.main) == LanguageOverrideBundle.self {
            object_setClass(Bundle.main, Bundle.self)
            LanguageOverrideBundle.overrideBundle = nil
        }
    }
}

// MARK: - Language-aware Bundle subclass
//
// Swizzled onto Bundle.main so NSLocalizedString(_:comment:) — which calls
// Bundle.main.localizedString(forKey:value:table:) — resolves through the
// overridden language bundle first, falling back to the main bundle.

private final class LanguageOverrideBundle: Bundle {
    static var overrideBundle: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Try the override language bundle first.
        if let override = Self.overrideBundle,
           override !== self {
            let resolved = override.localizedString(forKey: key, value: nil, table: tableName)
            // Bundle returns the key itself when no translation exists; only
            // accept a real (different) result.
            if resolved != key {
                return resolved
            }
        }
        // Fall back to the normal lookup.
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}
