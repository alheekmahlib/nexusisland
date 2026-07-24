import SwiftUI

// MARK: - Quran Design System
//
// A focused palette for the Quran module: deep midnight surfaces with a warm
// gold accent, echoing traditional mushaf illumination. Tokens are kept here
// so all three Quran views share one source of truth and the look stays
// consistent as the island grows / shrinks.
//
// All surfaces assume the island's black pill backdrop, so "background" colors
// are translucent overlays (white @ low opacity) that let the pill's gradient
// show through — the "liquid glass" effect.

enum QuranDesign {
    // MARK: - Color tokens

    /// Warm gold accent for active states, play buttons, and highlights.
    /// Deliberately chosen to read as "premium" against the dark pill and to
    /// echo the gilded edges of a printed mushaf.
    static let accent = Color(red: 0.98, green: 0.62, blue: 0.27)        // #FBA046
    static let accentSoft = Color(red: 0.98, green: 0.62, blue: 0.27).opacity(0.18)
    static let accentDim = Color(red: 0.98, green: 0.62, blue: 0.27).opacity(0.35)

    /// Deep indigo secondary, used for the "now playing" ring and reciter chips.
    static let secondary = Color(red: 0.19, green: 0.18, blue: 0.51)     // #312E81

    /// Text hierarchy on the dark pill.
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    /// Translucent surfaces layered over the black pill.
    static let surfaceFill = Color.white.opacity(0.06)
    static let surfaceFillHover = Color.white.opacity(0.10)
    static let surfaceFillActive = Color.white.opacity(0.14)
    static let surfaceStroke = Color.white.opacity(0.10)
    static let surfaceStrokeActive = accent.opacity(0.45)

    // MARK: - Typography

    /// Arabic surah names — slightly larger and semibold for legibility.
    static func surahName(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Body text in Arabic.
    static func body(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Monospaced numerals for time codes (00:00 / 12:34).
    static func mono(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    /// Small captions (ayah count, revelation type).
    static func caption(_ size: CGFloat = 9) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // MARK: - Shape tokens

    static let cornerRadiusS: CGFloat = 6
    static let cornerRadiusM: CGFloat = 10
    static let cornerRadiusL: CGFloat = 14

    // MARK: - Time formatting
    //
    // Whole-surah MP3s can run well over an hour (e.g. Al-Baqarah ~3h for some
    // reciters), so always use hh:mm:ss — never mm:ss. A surah under an hour
    // still reads fine with a leading 00: (00:12:34).

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Reusable surface modifier

/// A frosted-card look: subtle fill + thin stroke + soft corner radius.
/// Applied consistently to cards, list rows, and chips across the Quran UI.
struct QuranSurface: ViewModifier {
    var isActive: Bool = false
    var radius: CGFloat = QuranDesign.cornerRadiusM
    var fillOpacity: Double? = nil

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(fillOpacity ?? (isActive ? 0.14 : 0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isActive ? QuranDesign.surfaceStrokeActive : QuranDesign.surfaceStroke,
                              lineWidth: isActive ? 1.2 : 0.5)
        )
    }
}

extension View {
    func quranSurface(isActive: Bool = false, radius: CGFloat = QuranDesign.cornerRadiusM,
                      fillOpacity: Double? = nil) -> some View {
        modifier(QuranSurface(isActive: isActive, radius: radius, fillOpacity: fillOpacity))
    }
}
