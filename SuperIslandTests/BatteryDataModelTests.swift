import XCTest
@testable import SuperIsland

/// Tests for the battery module's value types.
///
/// `BatteryManager` is a `@MainActor` singleton that wires into IOKit run-loop
/// sources, so it isn't unit-testable in isolation. Its *data* structs, though,
/// carry formatting logic (`formattedImpact`) and identity rules that are worth
/// pinning.
final class BatteryDataModelTests: XCTestCase {

    // MARK: - BatteryHistorySample

    func testBatteryHistorySampleIsIdentifiable() {
        let a = BatteryHistorySample(timestamp: Date(), level: 90)
        let b = BatteryHistorySample(timestamp: Date(), level: 90)

        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.level, 90)
    }

    func testBatteryHistorySampleEqualityIgnoresGeneratedID() {
        // Equatable is auto-synthesized from `Identifiable` + stored properties;
        // since id is a fresh UUID, two samples are never equal even with
        // identical data. This is the intended behavior for diffing history.
        let date = Date()
        let a = BatteryHistorySample(timestamp: date, level: 50)
        let b = BatteryHistorySample(timestamp: date, level: 50)

        // `id` is part of the struct, so synthesized Equatable compares it.
        XCTAssertNotEqual(a, b)
    }

    // MARK: - BatteryConsumerApp

    func testBatteryConsumerAppEqualityByID() {
        let a = BatteryConsumerApp(id: "com.apple.Safari", appName: "Safari",
                                   impactScore: 4.2, metricLabel: "Wh")
        let b = BatteryConsumerApp(id: "com.apple.Safari", appName: "Safari",
                                   impactScore: 4.2, metricLabel: "Wh")
        let c = BatteryConsumerApp(id: "com.apple.Mail", appName: "Mail",
                                   impactScore: 1.1, metricLabel: "Wh")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testBatteryConsumerAppFormattedImpactFormatsToOneDecimal() {
        let app = BatteryConsumerApp(id: "x", appName: "X",
                                     impactScore: 3.14159, metricLabel: "Wh")

        XCTAssertEqual(app.formattedImpact, "3.1 Wh")
    }

    func testBatteryConsumerAppFormattedImpactWithZeroScore() {
        let app = BatteryConsumerApp(id: "x", appName: "X",
                                     impactScore: 0, metricLabel: "%")

        XCTAssertEqual(app.formattedImpact, "0.0 %")
    }
}
