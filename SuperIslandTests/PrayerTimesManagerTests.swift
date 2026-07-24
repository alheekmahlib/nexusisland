import XCTest
@testable import SuperIsland

/// Tests for PrayerTimesManager's pure logic (models + parsing + helpers).
/// The manager itself is a @MainActor singleton doing network I/O, so we test
/// the extracted, deterministic functions instead.
@MainActor
final class PrayerTimesManagerTests: XCTestCase {

    // MARK: - PrayerKind

    func testPrayerKindArabicNames() {
        XCTAssertEqual(PrayerKind.fajr.arabicName, "الفجر")
        XCTAssertEqual(PrayerKind.sunrise.arabicName, "الشروق")
        XCTAssertEqual(PrayerKind.dhuhr.arabicName, "الظهر")
        XCTAssertEqual(PrayerKind.asr.arabicName, "العصر")
        XCTAssertEqual(PrayerKind.maghrib.arabicName, "المغرب")
        XCTAssertEqual(PrayerKind.isha.arabicName, "العشاء")
    }

    func testPrayerKindHasIconForAll() {
        for kind in PrayerKind.allCases {
            XCTAssertFalse(kind.iconName.isEmpty, "\(kind) needs an icon")
        }
    }

    func testOnlyFiveAreObligatory() {
        let obligatory = PrayerKind.allCases.filter(\.isObligatory)
        XCTAssertEqual(obligatory.count, 5)
        XCTAssertFalse(PrayerKind.sunrise.isObligatory)
        XCTAssertTrue(PrayerKind.fajr.isObligatory)
    }

    // MARK: - Calculation method

    func testUmmAlQuraIsDefaultMethod() {
        XCTAssertEqual(PrayerTimesManager.shared.calculationMethod, .ummAlQura)
    }

    func testCalculationMethodDisplayNames() {
        XCTAssertEqual(PrayerCalculationMethod.ummAlQura.displayName, "Umm Al-Qura (Makkah)")
        XCTAssertEqual(PrayerCalculationMethod.isna.displayName, "ISNA (North America)")
    }

    // MARK: - Time parsing

    func testParseTimePlain() {
        let date = PrayerTimesManager.parseTime("05:12")
        XCTAssertNotNil(date)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(comps.hour, 5)
        XCTAssertEqual(comps.minute, 12)
    }

    func testParseTimeStripsTimezone() {
        // Aladhan returns "05:12 (AST)" — the suffix must be ignored.
        let date = PrayerTimesManager.parseTime("05:12 (AST)")
        XCTAssertNotNil(date)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(comps.hour, 5)
        XCTAssertEqual(comps.minute, 12)
    }

    func testParseTimeRejectsGarbage() {
        XCTAssertNil(PrayerTimesManager.parseTime("not-a-time"))
        XCTAssertNil(PrayerTimesManager.parseTime(""))
    }

    // MARK: - Payload parsing

    func testParsePayloadExtractsAllSixPrayers() {
        let payload: [String: Any] = [
            "timings": [
                "Fajr": "05:00", "Sunrise": "06:15", "Dhuhr": "12:00",
                "Asr": "15:30", "Maghrib": "18:45", "Isha": "20:00"
            ],
            "date": ["hijri": ["day": "15", "month": ["ar": "محرم"], "year": "1448"]]
        ]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "2026-07-23")

        XCTAssertEqual(schedule.times.count, 6)
        XCTAssertNotNil(schedule.times[.fajr])
        XCTAssertNotNil(schedule.times[.isha])
        XCTAssertEqual(schedule.hijriDate, "15 محرم 1448")
    }

    func testParsePayloadHandlesMissingFieldsGracefully() {
        let payload: [String: Any] = ["timings": ["Fajr": "05:00"]]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "2026-07-23")
        XCTAssertEqual(schedule.times.count, 1)
        XCTAssertNil(schedule.hijriDate)
    }

    // MARK: - nextPrayer

    func testNextPrayerFindsUpcomingSameDay() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let dhuhr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 8, minute: 0))!

        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .dhuhr: dhuhr],
                                      hijriDate: nil)
        let next = schedule.nextPrayer(now: now)
        XCTAssertEqual(next?.kind, .dhuhr)
    }

    func testNextPrayerWrapsToTomorrowWhenAllPassed() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let isha = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 20, minute: 0))!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 23, minute: 0))!

        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .isha: isha],
                                      hijriDate: nil)
        let next = schedule.nextPrayer(now: now)
        XCTAssertEqual(next?.kind, .fajr)
        XCTAssertGreaterThan(next!.date, now)
    }

    // MARK: - Countdown

    func testCountdownStringMinutesOnly() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 10, minute: 0))!
        let target = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 10, minute: 30))!
        let s = PrayerTimesManager.countdownString(from: now, to: target)
        XCTAssertEqual(s, "30 دقيقة")
    }

    func testCountdownStringWithHours() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 10, minute: 0))!
        let target = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 30))!
        let s = PrayerTimesManager.countdownString(from: now, to: target)
        XCTAssertEqual(s, "2 س 30 د")
    }

    func testCountdownStringPastTarget() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        let target = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 10, minute: 0))!
        let s = PrayerTimesManager.countdownString(from: now, to: target)
        XCTAssertEqual(s, "الآن")
    }

    // MARK: - ModuleType registration

    func testPrayerTimesRegisteredInModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "prayerTimes"))
        // displayName is locale-dependent (Arabic when the app runs in Arabic);
        // assert against rawValue + icon which are stable.
        XCTAssertEqual(ModuleType.prayerTimes.rawValue, "prayerTimes")
        XCTAssertEqual(ModuleType.prayerTimes.iconName, "moon.stars.fill")
        XCTAssertFalse(ModuleType.prayerTimes.displayName.isEmpty)
    }

    // MARK: - Date format (Aladhan expects DD-MM-YYYY)

    func testTodayKeyIsDayMonthYearFormat() {
        let key = PrayerTimesManager.todayKey()
        // DD-MM-YYYY: 10 chars, digits and hyphens, two hyphens.
        XCTAssertEqual(key.count, 10)
        XCTAssertEqual(key.filter { $0 == "-" }.count, 2)
        // Verify the ordering: day (1-31) comes first.
        let parts = key.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        let day = Int(parts[0]) ?? 0
        XCTAssertTrue((1...31).contains(day), "first segment should be the day, got \(key)")
    }

    // MARK: - Arabic diacritics stripping

    func testStripDiacriticsRemovesHarakat() {
        XCTAssertEqual(PrayerTimesManager.stripArabicDiacritics("مُحَرَّم"), "محرم")
        XCTAssertEqual(PrayerTimesManager.stripArabicDiacritics("صَفَر"), "صفر")
        XCTAssertEqual(PrayerTimesManager.stripArabicDiacritics("رَمَضَان"), "رمضان")
    }

    func testStripDiacriticsLeavesPlainTextIntact() {
        XCTAssertEqual(PrayerTimesManager.stripArabicDiacritics("محرم"), "محرم")
        XCTAssertEqual(PrayerTimesManager.stripArabicDiacritics(""), "")
    }

    func testParsePayloadStripsDiacriticsFromHijriMonth() {
        let payload: [String: Any] = [
            "timings": ["Fajr": "05:00"],
            "date": ["hijri": ["day": "9", "month": ["ar": "صَفَر"], "year": "1448"]]
        ]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "23-07-2026")
        XCTAssertEqual(schedule.hijriDate, "9 صفر 1448")
    }
}
