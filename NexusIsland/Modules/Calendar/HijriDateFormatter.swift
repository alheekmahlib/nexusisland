import Foundation

// MARK: - Hijri (Umm al-Qura) Date Formatting
//
// Wraps Foundation's built-in Islamic Umm al-Qura calendar so the rest of the
// app can render Hijri dates without an external API. Used by the Calendar
// module to show the Hijri date beside the Gregorian one.
//
// Foundation provides the arithmetic; the Arabic month names below are
// overridden because the system locale's month labels vary across macOS
// versions and we want consistent, recognizable names.

enum HijriDateFormatter {
    /// Arabic month names in canonical Hijri order (Muharram → Dhu al-Hijjah).
    static let arabicMonthNames = [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر",
        "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
        "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
    ]

    /// The Umm al-Qura calendar, configured once and reused.
    private static let hijriCalendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar")
        return cal
    }()

    /// Returns a "d MMMM yyyy" Hijri string in Arabic, e.g. "15 محرم 1448".
    /// Falls back to the system formatter if components are out of range.
    static func string(from date: Date, format: String = "d MMMM yyyy") -> String {
        let comps = hijriCalendar.dateComponents([.day, .month, .year], from: date)
        guard let day = comps.day, let monthIndex = comps.month, let year = comps.year,
              (1...12).contains(monthIndex) else {
            // Fallback to Foundation's own rendering.
            let f = DateFormatter()
            f.calendar = hijriCalendar
            f.locale = Locale(identifier: "ar")
            f.dateFormat = format
            return f.string(from: date)
        }
        let monthName = arabicMonthNames[monthIndex - 1]
        return "\(day) \(monthName) \(year)"
    }

    /// Compact form: "15 محرم" (no year) for tight UI slots.
    static func shortString(from date: Date) -> String {
        let comps = hijriCalendar.dateComponents([.day, .month], from: date)
        guard let day = comps.day, let monthIndex = comps.month,
              (1...12).contains(monthIndex) else {
            return string(from: date)
        }
        return "\(day) \(arabicMonthNames[monthIndex - 1])"
    }

    /// Today's Hijri date in full Arabic form.
    static func today() -> String {
        string(from: Date())
    }
}
