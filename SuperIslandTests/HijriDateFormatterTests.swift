import XCTest
@testable import SuperIsland

/// Tests for the Hijri (Umm al-Qura) date formatter used by the Calendar module.
///
/// Foundation's islamicUmmAlQura calendar is the source of truth; these tests
/// lock in the month-name mapping and the output shape so the Arabic Hijri
/// date renders consistently across macOS versions.
final class HijriDateFormatterTests: XCTestCase {

    // MARK: - Month catalog

    func testArabicMonthNamesHasTwelveMonths() {
        XCTAssertEqual(HijriDateFormatter.arabicMonthNames.count, 12)
    }

    func testArabicMonthNamesAreNotEmpty() {
        for name in HijriDateFormatter.arabicMonthNames {
            XCTAssertFalse(name.isEmpty, "every Hijri month needs an Arabic name")
        }
    }

    func testKnownMonthNames() {
        // Pin a few canonical names so a catalog reordering fails loudly.
        XCTAssertEqual(HijriDateFormatter.arabicMonthNames[0], "محرم")
        XCTAssertEqual(HijriDateFormatter.arabicMonthNames[8], "رمضان")
        XCTAssertEqual(HijriDateFormatter.arabicMonthNames[11], "ذو الحجة")
    }

    // MARK: - Output shape

    func testStringOutputContainsDayMonthYear() {
        let s = HijriDateFormatter.string(from: Date())
        // Format is "d MMMM yyyy" — day and year are numbers, month is an
        // Arabic word from the catalog. Split on space and check shape.
        let parts = s.split(separator: " ")
        XCTAssertEqual(parts.count, 3, "expected 'd MMMM yyyy', got '\(s)'")
        XCTAssertNotNil(Int(parts[0]), "day should be numeric: \(s)")
        XCTAssertNotNil(Int(parts[2]), "year should be numeric: \(s)")
        XCTAssertTrue(HijriDateFormatter.arabicMonthNames.contains(String(parts[1])),
                      "month should be from the catalog: \(s)")
    }

    func testYearIsAround1448For2026() {
        // 2026-07-23 ≈ 1448 AH. Allow a year of slack for calendar drift,
        // but catch gross regressions (e.g. formatter returning Gregorian year).
        let date = DateComponents(calendar: Calendar(identifier: .gregorian),
                                  year: 2026, month: 7, day: 23).date!
        let s = HijriDateFormatter.string(from: date)
        let parts = s.split(separator: " ")
        let year = Int(parts[2]) ?? 0
        XCTAssertTrue((1447...1449).contains(year),
                      "2026 should map to ~1448 AH, got \(year) in '\(s)'")
    }

    // MARK: - Short form

    func testShortStringOmitsYear() {
        let s = HijriDateFormatter.shortString(from: Date())
        let parts = s.split(separator: " ")
        XCTAssertEqual(parts.count, 2, "short form is 'd MMMM', got '\(s)'")
        XCTAssertNotNil(Int(parts[0]))
    }

    // MARK: - Today

    func testTodayReturnsNonEmptyString() {
        let s = HijriDateFormatter.today()
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.split(separator: " ").count == 3)
    }
}
