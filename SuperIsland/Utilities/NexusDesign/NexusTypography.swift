import SwiftUI

// MARK: - NexusDesign: Typography
//
// A single SF Pro scale replacing the ~150 inline `.font(.system(size:weight:))`
// call sites across the app. Sizes are tuned for the tight Dynamic Island
// surface (compact 200×36 / expanded 408×88 / fullExpanded 658×180).

enum NexusTypography {
    /// Large headlines (24pt, Bold).
    static let hero = Font.system(size: 24, weight: .bold)
    /// Section subtitles (18pt, Semibold).
    static let subtitle = Font.system(size: 18, weight: .semibold)
    /// Card/row titles (15pt, Semibold).
    static let title = Font.system(size: 15, weight: .semibold)
    /// Default body copy (14pt, Regular).
    static let body = Font.system(size: 14, weight: .regular)
    /// Captions and metadata (11pt, Medium).
    static let caption = Font.system(size: 11, weight: .medium)
    /// Large display numerals — optionally gradient-tinted by the caller.
    static func numeric(_ size: CGFloat = 36) -> Font { .system(size: size, weight: .bold) }
    /// Monospaced numerics for time codes / percentages (10pt).
    static let mono = Font.system(size: 10, weight: .regular, design: .monospaced)

    // MARK: - Size-parameterized variants
    //
    // For migrated modules that need exact pt sizes on the tight Dynamic Island
    // surfaces (preserving prior layout). Prefer the fixed tokens above in new
    // code; use these only when a module's existing size must be kept.

    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat, _ weight: Font.Weight) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
}
