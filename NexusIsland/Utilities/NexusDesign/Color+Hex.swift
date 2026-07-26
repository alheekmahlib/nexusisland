import SwiftUI

// MARK: - NexusDesign: Color(hex:)
//
// The single source of truth for converting hex strings to SwiftUI `Color`.
// Used by every `NexusPalette` token so the design system stays in hex —
// matching the app icon and the design doc — instead of scattered RGB tuples.

extension Color {
    /// Initialize from a hex string. Accepts `#RRGGBB`, `#RGB`, `#RRGGBBAA`,
    /// and the same forms without `#`. Falls back to clear on invalid input.
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch sanitized.count {
        case 3: // RGB (each nibble repeated, e.g. #F0A → #FF00AA)
            (r, g, b, a) = (Double((rgb >> 8) & 0xF) / 15,
                            Double((rgb >> 4) & 0xF) / 15,
                            Double(rgb & 0xF) / 15, 1)
        case 6: // RRGGBB
            (r, g, b, a) = (Double((rgb >> 16) & 0xFF) / 255,
                            Double((rgb >> 8) & 0xFF) / 255,
                            Double(rgb & 0xFF) / 255, 1)
        case 8: // RRGGBBAA
            (r, g, b, a) = (Double((rgb >> 24) & 0xFF) / 255,
                            Double((rgb >> 16) & 0xFF) / 255,
                            Double((rgb >> 8) & 0xFF) / 255,
                            Double(rgb & 0xFF) / 255)
        default:
            (r, g, b, a) = (0, 0, 0, 0)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
