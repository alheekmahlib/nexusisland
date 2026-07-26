import SwiftUI

// MARK: - NexusDesign: Palette
//
// Exact palette derived from the app icon. Deep purple + neon magenta +
// orange glow in the macOS Big Sur / Apple design idiom.
// NOTE: no gold — amber (#FFB347) replaces the former accentGold everywhere.

enum NexusPalette {
    // MARK: - Background (from the app icon)
    /// Midnight Blue — the dark background base.
    static let background     = Color(hex: "#0A0614")
    /// Deep Purple — darker gradient stop.
    static let deepPurple     = Color(hex: "#1A0F38")

    // MARK: - Purple ramp (primary brand colors)
    /// Royal Purple — the main purple.
    static let royalPurple    = Color(hex: "#6A3FD6")
    /// Electric Violet — lighter purple for highlights.
    static let electricViolet = Color(hex: "#9B6DFF")

    // MARK: - Neon accents (the vibrant glow)
    /// Neon Pink.
    static let neonPink       = Color(hex: "#FF2CCB")
    /// Magenta.
    static let magenta        = Color(hex: "#D13CFF")
    /// Vibrant Orange — glowing accent.
    static let vibrantOrange  = Color(hex: "#FF8A2A")
    /// Amber — warm orange-yellow (replaces former accentGold).
    static let amber          = Color(hex: "#FFB347")

    // MARK: - Text & glass
    /// Soft White for text and highlights.
    static let textPrimary    = Color(hex: "#F2F3FF")
    /// Secondary text (slightly dimmed primary).
    static let textSecondary  = Color(hex: "#D9D6FF").opacity(0.85)
    /// Tertiary text / metadata.
    static let textTertiary   = Color(hex: "#D9D6FF").opacity(0.50)
    /// Light Lavender — glass reflection tint.
    static let glassTint      = Color(hex: "#D9D6FF")

    // MARK: - Status
    static let success        = Color(hex: "#4CAF50")
    static let warning        = Color(hex: "#FFB347")
    static let danger         = Color(hex: "#F44336")

    // MARK: - Back-compat aliases (map old gradient-stop names onto the new
    // palette so glow/shadow call sites keep working). Prefer the named tokens
    // above in new code.
    /// Was the gradient's middle stop (magenta-pink) → now Neon Pink.
    static let gradientMid    = neonPink
    /// Was the gradient's end stop (orange/yellow) → now Vibrant Orange.
    static let gradientEnd    = vibrantOrange
}
