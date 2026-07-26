import Foundation

// MARK: - Quran Reciter

/// A Quran reciter backed by the AlQuran Cloud audio edition API.
///
/// Each edition identifier (`ar.<key>`) resolves to a full-surah MP3 at:
///   https://cdn.islamic.network/quran/audio-surah/128/<edition>/<surahNumber>.mp3
/// so playback is one audio file per surah — no per-ayah bookkeeping.
struct QuranReciter: Identifiable, Hashable {
    /// Stable identifier used in @AppStorage (never localize).
    let id: String
    /// Arabic display name.
    let arabicName: String
    /// Transliterated name for compact spaces where Arabic is too wide.
    let latinName: String
    /// AlQuran Cloud audio edition identifier (e.g. "ar.husary").
    let edition: String

    var displayName: String { arabicName }
}

// MARK: - Quran Reciters Catalog

enum QuranReciters {
    /// Curated reciter list. Deliberately omits certain reciters per project
    /// requirements (no Sudais). Order is the user-facing default order.
    static let all: [QuranReciter] = [
        QuranReciter(id: "abdulbasit", arabicName: "عبد الباسط عبد الصمد",
                     latinName: "Abdul Basit", edition: "ar.abdulbasitmurattal"),
        QuranReciter(id: "husary", arabicName: "محمود الحصري",
                     latinName: "Al-Husary", edition: "ar.husary"),
        QuranReciter(id: "minshawi", arabicName: "محمد صديق المنشاوي",
                     latinName: "Al-Minshawi", edition: "ar.minshawi"),
        QuranReciter(id: "alafasy", arabicName: "مشاري راشد العفاسي",
                     latinName: "Alafasy", edition: "ar.alafasy"),
        QuranReciter(id: "maher", arabicName: "ماهر المعيقلي",
                     latinName: "Al-Muaiqly", edition: "ar.mahermuaiqly"),
        QuranReciter(id: "basfar", arabicName: "عبد الله بصفر",
                     latinName: "Basfar", edition: "ar.abdullahbasfar"),
        QuranReciter(id: "shuraym", arabicName: "سعود الشريم",
                     latinName: "Al-Shuraim", edition: "ar.saoodshuraym"),
        QuranReciter(id: "hudhaify", arabicName: "علي الحذيفي",
                     latinName: "Al-Hudhaify", edition: "ar.hudhaify"),
        QuranReciter(id: "ajamy", arabicName: "أحمد بن علي العجمي",
                     latinName: "Al-Ajamy", edition: "ar.ahmedajamy")
    ]

    /// Default reciter used on first launch and when a stored id is unknown.
    static let defaultReciter: QuranReciter = all[0]

    /// Resolve a reciter by its stable id, falling back to the default.
    static func reciter(forID id: String) -> QuranReciter {
        all.first { $0.id == id } ?? defaultReciter
    }
}

// MARK: - Surah

/// A chapter of the Quran. Numbering follows the standard mushaf order
/// (1 = Al-Fatihah, 114 = An-Nas) and matches AlQuran Cloud's surah indices.
struct Surah: Identifiable, Hashable {
    /// Surah number (1...114). Also used as the stable id.
    let number: Int
    /// Arabic name without the "سورة" prefix (e.g. "البقرة").
    let arabicName: String
    /// Transliterated name (e.g. "Al-Baqarah").
    let latinName: String
    /// Number of ayahs — informational; playback is whole-surah.
    let ayahCount: Int
    /// Revelation type: Meccan or Medinan.
    let isMeccan: Bool

    var id: Int { number }

    /// Compact label like "٢ البقرة" used in the player UI.
    var displayLabel: String { "\(arabicNumber) \(arabicName)" }

    /// Arabic-Indic numeral rendering of the surah number.
    var arabicNumber: String {
        Self.toArabicNumber(number)
    }

    /// Revelation type in Arabic.
    var revelationTypeArabic: String { isMeccan ? "مكية" : "مدنية" }

    /// Convert a western (ASCII) integer to Arabic-Indic digits.
    static func toArabicNumber(_ value: Int) -> String {
        let arabicDigits: [Character] = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        return String(value).map { char in
            if let digit = char.wholeNumberValue, (0...9).contains(digit) {
                return String(arabicDigits[digit])
            }
            return String(char)
        }.joined()
    }
}

// MARK: - Surah Catalog

enum QuranSurahs {
    /// The full 114-surah catalog in canonical order.
    /// Source: AlQuran Cloud metadata; ayah counts and revelation types are
    /// the universally agreed-upon values.
    static let all: [Surah] = [
        Surah(number: 1, arabicName: "الفاتحة", latinName: "Al-Fatihah", ayahCount: 7, isMeccan: true),
        Surah(number: 2, arabicName: "البقرة", latinName: "Al-Baqarah", ayahCount: 286, isMeccan: false),
        Surah(number: 3, arabicName: "آل عمران", latinName: "Aal-E-Imran", ayahCount: 200, isMeccan: false),
        Surah(number: 4, arabicName: "النساء", latinName: "An-Nisa", ayahCount: 176, isMeccan: false),
        Surah(number: 5, arabicName: "المائدة", latinName: "Al-Maidah", ayahCount: 120, isMeccan: false),
        Surah(number: 6, arabicName: "الأنعام", latinName: "Al-Anam", ayahCount: 165, isMeccan: true),
        Surah(number: 7, arabicName: "الأعراف", latinName: "Al-Araf", ayahCount: 206, isMeccan: true),
        Surah(number: 8, arabicName: "الأنفال", latinName: "Al-Anfal", ayahCount: 75, isMeccan: false),
        Surah(number: 9, arabicName: "التوبة", latinName: "At-Tawbah", ayahCount: 129, isMeccan: false),
        Surah(number: 10, arabicName: "يونس", latinName: "Yunus", ayahCount: 109, isMeccan: true),
        Surah(number: 11, arabicName: "هود", latinName: "Hud", ayahCount: 123, isMeccan: true),
        Surah(number: 12, arabicName: "يوسف", latinName: "Yusuf", ayahCount: 111, isMeccan: true),
        Surah(number: 13, arabicName: "الرعد", latinName: "Ar-Rad", ayahCount: 43, isMeccan: false),
        Surah(number: 14, arabicName: "إبراهيم", latinName: "Ibrahim", ayahCount: 52, isMeccan: true),
        Surah(number: 15, arabicName: "الحجر", latinName: "Al-Hijr", ayahCount: 99, isMeccan: true),
        Surah(number: 16, arabicName: "النحل", latinName: "An-Nahl", ayahCount: 128, isMeccan: true),
        Surah(number: 17, arabicName: "الإسراء", latinName: "Al-Isra", ayahCount: 111, isMeccan: true),
        Surah(number: 18, arabicName: "الكهف", latinName: "Al-Kahf", ayahCount: 110, isMeccan: true),
        Surah(number: 19, arabicName: "مريم", latinName: "Maryam", ayahCount: 98, isMeccan: true),
        Surah(number: 20, arabicName: "طه", latinName: "Ta-Ha", ayahCount: 135, isMeccan: true),
        Surah(number: 21, arabicName: "الأنبياء", latinName: "Al-Anbiya", ayahCount: 112, isMeccan: true),
        Surah(number: 22, arabicName: "الحج", latinName: "Al-Hajj", ayahCount: 78, isMeccan: false),
        Surah(number: 23, arabicName: "المؤمنون", latinName: "Al-Muminun", ayahCount: 118, isMeccan: true),
        Surah(number: 24, arabicName: "النور", latinName: "An-Nur", ayahCount: 64, isMeccan: false),
        Surah(number: 25, arabicName: "الفرقان", latinName: "Al-Furqan", ayahCount: 77, isMeccan: true),
        Surah(number: 26, arabicName: "الشعراء", latinName: "Ash-Shuara", ayahCount: 227, isMeccan: true),
        Surah(number: 27, arabicName: "النمل", latinName: "An-Naml", ayahCount: 93, isMeccan: true),
        Surah(number: 28, arabicName: "القصص", latinName: "Al-Qasas", ayahCount: 88, isMeccan: true),
        Surah(number: 29, arabicName: "العنكبوت", latinName: "Al-Ankabut", ayahCount: 69, isMeccan: true),
        Surah(number: 30, arabicName: "الروم", latinName: "Ar-Rum", ayahCount: 60, isMeccan: false),
        Surah(number: 31, arabicName: "لقمان", latinName: "Luqman", ayahCount: 34, isMeccan: true),
        Surah(number: 32, arabicName: "السجدة", latinName: "As-Sajdah", ayahCount: 30, isMeccan: true),
        Surah(number: 33, arabicName: "الأحزاب", latinName: "Al-Ahzab", ayahCount: 73, isMeccan: false),
        Surah(number: 34, arabicName: "سبأ", latinName: "Saba", ayahCount: 54, isMeccan: true),
        Surah(number: 35, arabicName: "فاطر", latinName: "Fatir", ayahCount: 45, isMeccan: true),
        Surah(number: 36, arabicName: "يس", latinName: "Ya-Sin", ayahCount: 83, isMeccan: true),
        Surah(number: 37, arabicName: "الصافات", latinName: "As-Saffat", ayahCount: 182, isMeccan: true),
        Surah(number: 38, arabicName: "ص", latinName: "Sad", ayahCount: 88, isMeccan: true),
        Surah(number: 39, arabicName: "الزمر", latinName: "Az-Zumar", ayahCount: 75, isMeccan: true),
        Surah(number: 40, arabicName: "غافر", latinName: "Ghafir", ayahCount: 85, isMeccan: true),
        Surah(number: 41, arabicName: "فصلت", latinName: "Fussilat", ayahCount: 54, isMeccan: true),
        Surah(number: 42, arabicName: "الشورى", latinName: "Ash-Shura", ayahCount: 53, isMeccan: true),
        Surah(number: 43, arabicName: "الزخرف", latinName: "Az-Zukhruf", ayahCount: 89, isMeccan: true),
        Surah(number: 44, arabicName: "الدخان", latinName: "Ad-Dukhan", ayahCount: 59, isMeccan: true),
        Surah(number: 45, arabicName: "الجاثية", latinName: "Al-Jathiyah", ayahCount: 37, isMeccan: true),
        Surah(number: 46, arabicName: "الأحقاف", latinName: "Al-Ahqaf", ayahCount: 35, isMeccan: true),
        Surah(number: 47, arabicName: "محمد", latinName: "Muhammad", ayahCount: 38, isMeccan: false),
        Surah(number: 48, arabicName: "الفتح", latinName: "Al-Fath", ayahCount: 29, isMeccan: false),
        Surah(number: 49, arabicName: "الحجرات", latinName: "Al-Hujurat", ayahCount: 18, isMeccan: false),
        Surah(number: 50, arabicName: "ق", latinName: "Qaf", ayahCount: 45, isMeccan: true),
        Surah(number: 51, arabicName: "الذاريات", latinName: "Adh-Dhariyat", ayahCount: 60, isMeccan: true),
        Surah(number: 52, arabicName: "الطور", latinName: "At-Tur", ayahCount: 49, isMeccan: true),
        Surah(number: 53, arabicName: "النجم", latinName: "An-Najm", ayahCount: 62, isMeccan: true),
        Surah(number: 54, arabicName: "القمر", latinName: "Al-Qamar", ayahCount: 55, isMeccan: true),
        Surah(number: 55, arabicName: "الرحمن", latinName: "Ar-Rahman", ayahCount: 78, isMeccan: false),
        Surah(number: 56, arabicName: "الواقعة", latinName: "Al-Waqiah", ayahCount: 96, isMeccan: true),
        Surah(number: 57, arabicName: "الحديد", latinName: "Al-Hadid", ayahCount: 29, isMeccan: false),
        Surah(number: 58, arabicName: "المجادلة", latinName: "Al-Mujadila", ayahCount: 22, isMeccan: false),
        Surah(number: 59, arabicName: "الحشر", latinName: "Al-Hashr", ayahCount: 24, isMeccan: false),
        Surah(number: 60, arabicName: "الممتحنة", latinName: "Al-Mumtahanah", ayahCount: 13, isMeccan: false),
        Surah(number: 61, arabicName: "الصف", latinName: "As-Saff", ayahCount: 14, isMeccan: false),
        Surah(number: 62, arabicName: "الجمعة", latinName: "Al-Jumuah", ayahCount: 11, isMeccan: false),
        Surah(number: 63, arabicName: "المنافقون", latinName: "Al-Munafiqun", ayahCount: 11, isMeccan: false),
        Surah(number: 64, arabicName: "التغابن", latinName: "At-Taghabun", ayahCount: 18, isMeccan: false),
        Surah(number: 65, arabicName: "الطلاق", latinName: "At-Talaq", ayahCount: 12, isMeccan: false),
        Surah(number: 66, arabicName: "التحريم", latinName: "At-Tahrim", ayahCount: 12, isMeccan: false),
        Surah(number: 67, arabicName: "الملك", latinName: "Al-Mulk", ayahCount: 30, isMeccan: true),
        Surah(number: 68, arabicName: "القلم", latinName: "Al-Qalam", ayahCount: 52, isMeccan: true),
        Surah(number: 69, arabicName: "الحاقة", latinName: "Al-Haqqah", ayahCount: 52, isMeccan: true),
        Surah(number: 70, arabicName: "المعارج", latinName: "Al-Maarij", ayahCount: 44, isMeccan: true),
        Surah(number: 71, arabicName: "نوح", latinName: "Nuh", ayahCount: 28, isMeccan: true),
        Surah(number: 72, arabicName: "الجن", latinName: "Al-Jinn", ayahCount: 28, isMeccan: true),
        Surah(number: 73, arabicName: "المزمل", latinName: "Al-Muzzammil", ayahCount: 20, isMeccan: true),
        Surah(number: 74, arabicName: "المدثر", latinName: "Al-Muddaththir", ayahCount: 56, isMeccan: true),
        Surah(number: 75, arabicName: "القيامة", latinName: "Al-Qiyamah", ayahCount: 40, isMeccan: true),
        Surah(number: 76, arabicName: "الإنسان", latinName: "Al-Insan", ayahCount: 31, isMeccan: false),
        Surah(number: 77, arabicName: "المرسلات", latinName: "Al-Mursalat", ayahCount: 50, isMeccan: true),
        Surah(number: 78, arabicName: "النبأ", latinName: "An-Naba", ayahCount: 40, isMeccan: true),
        Surah(number: 79, arabicName: "النازعات", latinName: "An-Naziat", ayahCount: 46, isMeccan: true),
        Surah(number: 80, arabicName: "عبس", latinName: "Abasa", ayahCount: 42, isMeccan: true),
        Surah(number: 81, arabicName: "التكوير", latinName: "At-Takwir", ayahCount: 29, isMeccan: true),
        Surah(number: 82, arabicName: "الانفطار", latinName: "Al-Infitar", ayahCount: 19, isMeccan: true),
        Surah(number: 83, arabicName: "المطففين", latinName: "Al-Mutaffifin", ayahCount: 36, isMeccan: true),
        Surah(number: 84, arabicName: "الانشقاق", latinName: "Al-Inshiqaq", ayahCount: 25, isMeccan: true),
        Surah(number: 85, arabicName: "البروج", latinName: "Al-Buruj", ayahCount: 22, isMeccan: true),
        Surah(number: 86, arabicName: "الطارق", latinName: "At-Tariq", ayahCount: 17, isMeccan: true),
        Surah(number: 87, arabicName: "الأعلى", latinName: "Al-Ala", ayahCount: 19, isMeccan: true),
        Surah(number: 88, arabicName: "الغاشية", latinName: "Al-Ghashiyah", ayahCount: 26, isMeccan: true),
        Surah(number: 89, arabicName: "الفجر", latinName: "Al-Fajr", ayahCount: 30, isMeccan: true),
        Surah(number: 90, arabicName: "البلد", latinName: "Al-Balad", ayahCount: 20, isMeccan: true),
        Surah(number: 91, arabicName: "الشمس", latinName: "Ash-Shams", ayahCount: 15, isMeccan: true),
        Surah(number: 92, arabicName: "الليل", latinName: "Al-Lail", ayahCount: 21, isMeccan: true),
        Surah(number: 93, arabicName: "الضحى", latinName: "Ad-Duha", ayahCount: 11, isMeccan: true),
        Surah(number: 94, arabicName: "الشرح", latinName: "Ash-Sharh", ayahCount: 8, isMeccan: true),
        Surah(number: 95, arabicName: "التين", latinName: "At-Tin", ayahCount: 8, isMeccan: true),
        Surah(number: 96, arabicName: "العلق", latinName: "Al-Alaq", ayahCount: 19, isMeccan: true),
        Surah(number: 97, arabicName: "القدر", latinName: "Al-Qadr", ayahCount: 5, isMeccan: true),
        Surah(number: 98, arabicName: "البينة", latinName: "Al-Bayyinah", ayahCount: 8, isMeccan: false),
        Surah(number: 99, arabicName: "الزلزلة", latinName: "Az-Zalzalah", ayahCount: 8, isMeccan: false),
        Surah(number: 100, arabicName: "العاديات", latinName: "Al-Adiyat", ayahCount: 11, isMeccan: true),
        Surah(number: 101, arabicName: "القارعة", latinName: "Al-Qariah", ayahCount: 11, isMeccan: true),
        Surah(number: 102, arabicName: "التكاثر", latinName: "At-Takathur", ayahCount: 8, isMeccan: true),
        Surah(number: 103, arabicName: "العصر", latinName: "Al-Asr", ayahCount: 3, isMeccan: true),
        Surah(number: 104, arabicName: "الهمزة", latinName: "Al-Humazah", ayahCount: 9, isMeccan: true),
        Surah(number: 105, arabicName: "الفيل", latinName: "Al-Fil", ayahCount: 5, isMeccan: true),
        Surah(number: 106, arabicName: "قريش", latinName: "Quraysh", ayahCount: 4, isMeccan: true),
        Surah(number: 107, arabicName: "الماعون", latinName: "Al-Maun", ayahCount: 7, isMeccan: true),
        Surah(number: 108, arabicName: "الكوثر", latinName: "Al-Kawthar", ayahCount: 3, isMeccan: true),
        Surah(number: 109, arabicName: "الكافرون", latinName: "Al-Kafirun", ayahCount: 6, isMeccan: true),
        Surah(number: 110, arabicName: "النصر", latinName: "An-Nasr", ayahCount: 3, isMeccan: false),
        Surah(number: 111, arabicName: "المسد", latinName: "Al-Masad", ayahCount: 5, isMeccan: true),
        Surah(number: 112, arabicName: "الإخلاص", latinName: "Al-Ikhlas", ayahCount: 4, isMeccan: true),
        Surah(number: 113, arabicName: "الفلق", latinName: "Al-Falaq", ayahCount: 5, isMeccan: true),
        Surah(number: 114, arabicName: "الناس", latinName: "An-Nas", ayahCount: 6, isMeccan: true)
    ]

    /// Convenience: the first surah (Al-Fatihah), used as the default selection.
    static let first: Surah = all[0]

    /// Resolve a surah by number (1...114), clamping out-of-range values.
    static func surah(forNumber number: Int) -> Surah {
        let clamped = min(max(1, number), all.count)
        return all[clamped - 1]
    }

    /// Surah immediately following the given one, or nil after An-Nas (114).
    static func after(_ surah: Surah) -> Surah? {
        guard surah.number < all.count else { return nil }
        return all[surah.number] // number is 1-based; index is number (next).
    }
}
