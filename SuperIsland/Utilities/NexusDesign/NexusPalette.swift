import SwiftUI

// MARK: - NexusDesign: Palette
//
// One unified palette derived from the app icon (the dark purple radial
// backdrop + neon notch symbol) merged with the design doc's vibrant
// purple→magenta→orange gradient. Replaces the ad-hoc RGB literals that were
// scattered across ~40 view files.

enum NexusPalette {
    // MARK: - Background (from the app icon)
    /// Deep near-black purple — the island's expanded/fullExpanded base.
    static let background     = Color(hex: "#1A0B2E")
    /// Lighter purple used for the central radial glow.
    static let backgroundGlow = Color(hex: "#2D1B4E")

    // MARK: - Primary vibrant gradient (design doc)
    /// Deep purple — start of the signature gradient.
    static let gradientStart  = Color(hex: "#6A0DAD")
    /// Vibrant magenta — middle of the signature gradient.
    static let gradientMid    = Color(hex: "#E91E63")
    /// Bright orange/yellow — end of the signature gradient.
    static let gradientEnd    = Color(hex: "#FFC107")

    // MARK: - Accents
    /// Warm gold, used sparingly for important numerals/icons.
    static let accentGold     = Color(hex: "#FBA046")
    /// Neon purple from the icon symbol.
    static let neonPurple     = Color(hex: "#B833FF")
    /// Neon orange from the icon symbol.
    static let neonOrange     = Color(hex: "#FF6B35")

    // MARK: - Text
    static let textPrimary    = Color(hex: "#FFFFFF")
    static let textSecondary  = Color(hex: "#CCCCCC")
    static let textTertiary   = Color.white.opacity(0.55)

    // MARK: - Status
    static let success        = Color(hex: "#4CAF50")
    static let warning        = Color(hex: "#FFC107")
    static let danger         = Color(hex: "#F44336")
}
