import XCTest
@testable import SuperIsland

/// Tests for the Quran module's value types and URL construction.
///
/// `QuranManager` is a `@MainActor` singleton that owns an AVPlayer, so it
/// isn't unit-testable in isolation. The pure logic — the reciter catalog,
/// surah catalog, Arabic numeral conversion, and audio URL contract — is
/// extracted into testable value types and is covered here.
@MainActor
final class QuranModuleTests: XCTestCase {

    // MARK: - Reciter catalog

    func testReciterCatalogHasNineReciters() {
        XCTAssertEqual(QuranReciters.all.count, 9, "exactly nine reciters (no Sudais)")
    }

    func testReciterCatalogExcludesSudais() {
        // Project requirement: Sudais must not appear in the catalog.
        let ids = QuranReciters.all.map { $0.id.lowercased() }
        let names = QuranReciters.all.map { $0.arabicName }
        XCTAssertFalse(ids.contains { $0.contains("sudais") }, "no Sudais id allowed")
        XCTAssertFalse(names.contains { $0.contains("السديس") }, "no Sudais Arabic name allowed")
        XCTAssertFalse(names.contains { $0.contains("سديس") }, "no Sudais substring allowed")
    }

    func testEveryReciterHasArabicNameLatinNameAndEdition() {
        for reciter in QuranReciters.all {
            XCTAssertFalse(reciter.arabicName.isEmpty, "\(reciter.id) needs an Arabic name")
            XCTAssertFalse(reciter.latinName.isEmpty, "\(reciter.id) needs a Latin name")
            XCTAssertFalse(reciter.edition.isEmpty, "\(reciter.id) needs an AlQuran Cloud edition id")
            XCTAssertTrue(reciter.edition.hasPrefix("ar."), "\(reciter.id) edition must be an Arabic audio edition")
        }
    }

    func testReciterIDsAreUnique() {
        let ids = QuranReciters.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "reciter ids must be unique")
    }

    func testReciterEditionsAreUnique() {
        let editions = QuranReciters.all.map(\.edition)
        XCTAssertEqual(editions.count, Set(editions).count, "reciter editions must be unique")
    }

    func testReciterResolutionFallsBackToDefault() {
        let resolved = QuranReciters.reciter(forID: "does-not-exist")
        XCTAssertEqual(resolved.id, QuranReciters.defaultReciter.id)
    }

    func testReciterResolutionByID() {
        for reciter in QuranReciters.all {
            XCTAssertEqual(QuranReciters.reciter(forID: reciter.id).id, reciter.id)
        }
    }

    // MARK: - Surah catalog

    func testSurahCatalogHas114Surahs() {
        XCTAssertEqual(QuranSurahs.all.count, 114, "the mushaf has exactly 114 surahs")
    }

    func testSurahNumbersAreContiguous1to114() {
        let numbers = QuranSurahs.all.map(\.number)
        XCTAssertEqual(numbers, Array(1...114), "surah numbers must be 1...114 in order")
    }

    func testFirstSurahIsAlFatihah() {
        XCTAssertEqual(QuranSurahs.first.number, 1)
        XCTAssertEqual(QuranSurahs.first.arabicName, "الفاتحة")
        XCTAssertEqual(QuranSurahs.first.latinName, "Al-Fatihah")
    }

    func testLastSurahIsAnNas() {
        let last = QuranSurahs.all.last
        XCTAssertEqual(last?.number, 114)
        XCTAssertEqual(last?.arabicName, "الناس")
    }

    func testAlBaqarahHas286Ayahs() {
        let baqarah = QuranSurahs.surah(forNumber: 2)
        XCTAssertEqual(baqarah.ayahCount, 286)
        XCTAssertEqual(baqarah.arabicName, "البقرة")
        XCTAssertFalse(baqarah.isMeccan, "Al-Baqarah is Medinan")
    }

    func testAlKahfIsMeccan() {
        let kahf = QuranSurahs.surah(forNumber: 18)
        XCTAssertTrue(kahf.isMeccan)
        XCTAssertEqual(kahf.arabicName, "الكهف")
    }

    func testSurahResolutionClampsOutOfRange() {
        XCTAssertEqual(QuranSurahs.surah(forNumber: 0).number, 1, "0 clamps to 1")
        XCTAssertEqual(QuranSurahs.surah(forNumber: 999).number, 114, "999 clamps to 114")
        XCTAssertEqual(QuranSurahs.surah(forNumber: -5).number, 1, "-5 clamps to 1")
    }

    func testAfterReturnsNextSurah() {
        let fatihah = QuranSurahs.surah(forNumber: 1)
        XCTAssertEqual(QuranSurahs.after(fatihah)?.number, 2)

        let nas = QuranSurahs.surah(forNumber: 114)
        XCTAssertNil(QuranSurahs.after(nas), "nothing after An-Nas")
    }

    // MARK: - Arabic numerals

    func testArabicNumberConversion() {
        XCTAssertEqual(Surah.toArabicNumber(0), "٠")
        XCTAssertEqual(Surah.toArabicNumber(1), "١")
        XCTAssertEqual(Surah.toArabicNumber(2), "٢")
        XCTAssertEqual(Surah.toArabicNumber(9), "٩")
        XCTAssertEqual(Surah.toArabicNumber(10), "١٠")
        XCTAssertEqual(Surah.toArabicNumber(18), "١٨")
        XCTAssertEqual(Surah.toArabicNumber(114), "١١٤")
    }

    func testSurahDisplayLabelUsesArabicNumber() {
        let fatihah = QuranSurahs.surah(forNumber: 1)
        XCTAssertEqual(fatihah.displayLabel, "١ الفاتحة")

        let nas = QuranSurahs.surah(forNumber: 114)
        XCTAssertEqual(nas.displayLabel, "١١٤ الناس")
    }

    func testRevelationTypeArabic() {
        XCTAssertTrue(QuranSurahs.surah(forNumber: 1).isMeccan)
        XCTAssertEqual(QuranSurahs.surah(forNumber: 1).revelationTypeArabic, "مكية")
        XCTAssertFalse(QuranSurahs.surah(forNumber: 2).isMeccan)
        XCTAssertEqual(QuranSurahs.surah(forNumber: 2).revelationTypeArabic, "مدنية")
    }

    // MARK: - Audio URL contract

    /// Whole-surah MP3s come from the AlQuran Cloud CDN. The URL format is the
    /// load-bearing contract between QuranPlayer and the CDN — pin it.
    func testAudioURLForFirstSurahAndDefaultReciter() {
        let reciter = QuranReciters.defaultReciter
        let surah = QuranSurahs.first
        let url = QuranPlayer.audioURL(for: reciter, surah: surah)

        XCTAssertEqual(url?.absoluteString,
                       "https://cdn.islamic.network/quran/audio-surah/128/ar.abdulbasitmurattal/1.mp3")
    }

    func testAudioURLForLastSurah() {
        let reciter = QuranReciters.reciter(forID: "husary")
        let surah = QuranSurahs.surah(forNumber: 114)
        let url = QuranPlayer.audioURL(for: reciter, surah: surah)

        XCTAssertEqual(url?.absoluteString,
                       "https://cdn.islamic.network/quran/audio-surah/128/ar.husary/114.mp3")
    }

    func testEveryReciterSurahPairProducesValidURL() {
        // Spot-check that every reciter × a sample of surahs yields a well-formed URL.
        let sampleSurahs = [1, 2, 18, 36, 55, 67, 112, 114]
        for reciter in QuranReciters.all {
            for number in sampleSurahs {
                let surah = QuranSurahs.surah(forNumber: number)
                let url = QuranPlayer.audioURL(for: reciter, surah: surah)
                XCTAssertNotNil(url, "\(reciter.id) surah \(number) should produce a URL")
                XCTAssertTrue(url?.scheme == "https", "URL must be https")
                XCTAssertTrue(url?.path.hasSuffix(".mp3") ?? false, "URL must point to an mp3")
            }
        }
    }

    // MARK: - ModuleType registration

    func testQuranIsRegisteredAsModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "quran"))
        // displayName is locale-dependent; assert against stable rawValue + icon.
        XCTAssertEqual(ModuleType.quran.rawValue, "quran")
        XCTAssertEqual(ModuleType.quran.iconName, "book.fill")
        XCTAssertFalse(ModuleType.quran.displayName.isEmpty)
    }

    func testQuranIsInAllCases() {
        // Forces us to remember the routing switches when the enum changes.
        XCTAssertTrue(ModuleType.allCases.contains(.quran))
    }

    // MARK: - Date rollover helper

    func testTodayDateStringIsISOFormat() {
        let date = QuranManager.todayDateString()
        // yyyy-MM-dd — 10 chars, digits and hyphens only.
        XCTAssertEqual(date.count, 10)
        XCTAssertEqual(date.filter { $0 == "-" }.count, 2)
        XCTAssertEqual(date.filter { $0.isNumber }.count, 8)
    }
}
