import SwiftUI

// MARK: - Quran design helpers
//
// The Quran module now uses the shared NexusDesign tokens (NexusPalette,
// NexusGradient, NexusTypography, NexusMetrics, .nexusSurface) for full
// consistency with the rest of the app. Only the surah-aware time formatter
// remains here — surah MP3s can exceed one hour, so we always render hh:mm:ss.

enum QuranDesign {
    /// Formats a time interval as `hh:mm:ss`. Whole-surah recitations often
    /// exceed an hour (e.g. Al-Baqarah), so the hours field is always shown.
    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
