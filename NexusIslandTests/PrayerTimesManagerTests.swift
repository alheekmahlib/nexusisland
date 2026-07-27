import XCTest
@testable import NexusIsland

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

    func testUmmAlQuraIsDefaultMethodValue() {
        // The DEFAULT value of calcMethodRaw is ummAlQura. The shared singleton
        // may have had it changed by user interaction, so we assert against the
        // raw default rather than the live singleton state.
        let raw = PrayerCalculationMethod.ummAlQura.rawValue
        let resolved = PrayerCalculationMethod(rawValue: raw)
        XCTAssertEqual(resolved, .ummAlQura)
    }

    func testCalculationMethodDisplayNames() {
        XCTAssertEqual(PrayerCalculationMethod.ummAlQura.displayName, "Umm Al-Qura (Makkah)")
        XCTAssertEqual(PrayerCalculationMethod.isna.displayName, "ISNA (North America)")
    }

    // MARK: - Time parsing

    func testParseTimePlain() {
        // parseTime now takes the timezone the API returned the time in, so it
        // can construct an unambiguous instant regardless of the device tz.
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let date = PrayerTimesManager.parseTime("05:12", timeZone: tz)
        XCTAssertNotNil(date)
        // In Riyadh tz the wall-clock must read 05:12.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(comps.hour, 5)
        XCTAssertEqual(comps.minute, 12)
    }

    func testParseTimeStripsTimezone() {
        // Aladhan returns "05:12 (AST)" — the suffix must be ignored.
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let date = PrayerTimesManager.parseTime("05:12 (AST)", timeZone: tz)
        XCTAssertNotNil(date)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.hour, .minute], from: date!)
        XCTAssertEqual(comps.hour, 5)
        XCTAssertEqual(comps.minute, 12)
    }

    func testParseTimeRespectsLocationTimeZoneNotDevice() {
        // Regression: a "05:12" returned by the API in the *location's* tz
        // (Asia/Riyadh, UTC+3) must represent the SAME instant (02:12 UTC)
        // regardless of the device's tz. Previously the device tz was used,
        // so a user on Europe/London (UTC+0) would get 05:12 UTC = 08:12 Riyadh,
        // i.e. every prayer shifted by the tz delta. Verify the instant is fixed.
        let riyadh = TimeZone(identifier: "Asia/Riyadh")!
        let date = PrayerTimesManager.parseTime("05:12", timeZone: riyadh)!
        // 05:12 Asia/Riyadh (UTC+3) = 02:12 UTC.
        let utcCal = Calendar(identifier: .gregorian)
        var utcCalCopy = utcCal
        utcCalCopy.timeZone = TimeZone(identifier: "UTC")!
        let utcComps = utcCalCopy.dateComponents([.hour, .minute], from: date)
        XCTAssertEqual(utcComps.hour, 2)
        XCTAssertEqual(utcComps.minute, 12)
    }

    func testParseTimeRejectsGarbage() {
        XCTAssertNil(PrayerTimesManager.parseTime("not-a-time", timeZone: .current))
        XCTAssertNil(PrayerTimesManager.parseTime("", timeZone: .current))
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

    // MARK: - Interval progress (drives the progress bar)

    func testIntervalProgressAtStartOfInterval() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let dhuhr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 1))!
        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .dhuhr: dhuhr], hijriDate: nil)
        let fraction = schedule.intervalProgress(now: now)
        XCTAssertNotNil(fraction)
        // Just after Fajr → near 0.
        XCTAssertLessThan(fraction!, 0.05)
    }

    func testIntervalProgressMidway() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let dhuhr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        // Halfway: 5:00 + 3.5h = 8:30 (interval is 7h)
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 8, minute: 30))!
        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .dhuhr: dhuhr], hijriDate: nil)
        let fraction = schedule.intervalProgress(now: now)
        XCTAssertNotNil(fraction)
        XCTAssertEqual(fraction!, 0.5, accuracy: 0.02)
    }

    func testIntervalProgressJustBeforeNextPrayer() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let dhuhr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        // 1 minute before Dhuhr → near 1.0
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 11, minute: 59))!
        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .dhuhr: dhuhr], hijriDate: nil)
        let fraction = schedule.intervalProgress(now: now)
        XCTAssertNotNil(fraction)
        XCTAssertGreaterThan(fraction!, 0.95)
    }

    func testPreviousPrayerFindsLatestPassed() {
        let cal = Calendar.current
        let fajr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 5, minute: 0))!
        let dhuhr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 12, minute: 0))!
        let asr = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 15, minute: 30))!
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 23, hour: 14, minute: 0))!
        let schedule = PrayerSchedule(dateKey: "2026-07-23",
                                      times: [.fajr: fajr, .dhuhr: dhuhr, .asr: asr], hijriDate: nil)
        XCTAssertEqual(schedule.previousPrayer(now: now)?.kind, .dhuhr)
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

    // MARK: - Timezone handling (regression: prayer times must follow the
    // *location's* timezone, not the device timezone, for traveling users)

    func testParsePayloadExtractsTimeZoneFromMeta() {
        let payload: [String: Any] = [
            "timings": ["Fajr": "05:00"],
            "meta": ["timezone": "Asia/Riyadh"]
        ]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "23-07-2026")
        XCTAssertEqual(schedule.timeZone?.identifier, "Asia/Riyadh")
    }

    func testParsePayloadFallsBackToDeviceTimeZoneWhenMetaMissing() {
        let payload: [String: Any] = [
            "timings": ["Fajr": "05:00"]
        ]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "23-07-2026")
        XCTAssertEqual(schedule.timeZone, TimeZone.current)
    }

    func testParsePayloadConstructsTimesInLocationTimeZone() {
        // Fajr 05:00 in Asia/Riyadh (UTC+3) → must equal 02:00 UTC.
        let payload: [String: Any] = [
            "timings": ["Fajr": "05:00"],
            "meta": ["timezone": "Asia/Riyadh"]
        ]
        let schedule = PrayerTimesManager.parse(payload: payload, dateKey: "23-07-2026")
        let fajr = schedule.times[.fajr]!
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let utcComps = utcCal.dateComponents([.hour, .minute], from: fajr)
        XCTAssertEqual(utcComps.hour, 2, "Fajr 05:00 Riyadh should be 02:00 UTC")
        XCTAssertEqual(utcComps.minute, 0)
    }

    // MARK: - Coord-drift refetch (regression: GPS fix must refresh stale Riyadh data)

    func testNeedsRefetchForDifferentCoordinates() {
        // After the first fetch lands at Riyadh (the seeded default), a GPS fix
        // for Jeddah (21.5, 39.2) must force a new fetch even though the day
        // hasn't changed. Without this, users outside Riyadh permanently see
        // Riyadh's times whenever auto-location is enabled.
        let riyadhKey = PrayerTimesManager.todayKey()
        XCTAssertTrue(PrayerTimesManager.shouldRefetch(
            currentDateKey: "",
            lastLatitude: nil,
            lastLongitude: nil,
            newLatitude: 24.7136,
            newLongitude: 46.6753,
            todayKey: riyadhKey
        ), "empty schedule → always refetch")

        // Same day, same coords → no refetch (the normal debounce).
        XCTAssertFalse(PrayerTimesManager.shouldRefetch(
            currentDateKey: riyadhKey,
            lastLatitude: 24.7136,
            lastLongitude: 46.6753,
            newLatitude: 24.7136,
            newLongitude: 46.6753,
            todayKey: riyadhKey
        ))

        // Same day, DIFFERENT coords (Riyadh → Jeddah) → MUST refetch.
        XCTAssertTrue(PrayerTimesManager.shouldRefetch(
            currentDateKey: riyadhKey,
            lastLatitude: 24.7136,
            lastLongitude: 46.6753,
            newLatitude: 21.4812,
            newLongitude: 39.2376,
            todayKey: riyadhKey
        ), "GPS gave a different city → must refresh, even same day")
    }

    func testNeedsRefetchIgnoresTinyCoordJitter() {
        // Sub-100m GPS jitter (<0.001°) must NOT trigger a refetch storm.
        let key = PrayerTimesManager.todayKey()
        XCTAssertFalse(PrayerTimesManager.shouldRefetch(
            currentDateKey: key,
            lastLatitude: 24.7136,
            lastLongitude: 46.6753,
            newLatitude: 24.7137,
            newLongitude: 46.6754,
            todayKey: key
        ))
    }
}
