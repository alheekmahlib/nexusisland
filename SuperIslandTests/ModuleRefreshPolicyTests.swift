import XCTest
@testable import SuperIsland

/// Tests for the pure value types that back the energy/refresh subsystem.
///
/// These don't touch the scheduler's RunLoop or the shared singleton, so they
/// run fast and deterministically. They lock down the policy labels and
/// activity-state equality that the scheduler's diagnostics rely on.
@MainActor
final class ModuleRefreshPolicyTests: XCTestCase {

    // MARK: - Policy labels

    func testEventDrivenLabel() {
        XCTAssertEqual(ModuleRefreshPolicy.eventDriven.label, "Event driven")
    }

    func testManualLabel() {
        XCTAssertEqual(ModuleRefreshPolicy.manual.label, "Manual")
    }

    func testIntervalLabelFormatsSeconds() {
        XCTAssertEqual(ModuleRefreshPolicy.interval(0.5, tolerance: 0.1).label, "Every 0.5s")
    }

    func testIntervalLabelFormatsMinutes() {
        XCTAssertEqual(ModuleRefreshPolicy.interval(300, tolerance: 30).label, "Every 5m")
    }

    func testActiveOnlyLabel() {
        XCTAssertEqual(ModuleRefreshPolicy.activeOnly(60, tolerance: 5).label, "Active every 1m")
    }

    func testVisibleOnlyLabel() {
        XCTAssertEqual(ModuleRefreshPolicy.visibleOnly(180, tolerance: 30).label, "Visible every 3m")
    }

    // MARK: - Policy equality

    func testPolicyEqualityComparesAssociatedValues() {
        XCTAssertEqual(ModuleRefreshPolicy.interval(10, tolerance: 1), .interval(10, tolerance: 1))
        XCTAssertNotEqual(ModuleRefreshPolicy.interval(10, tolerance: 1), .interval(11, tolerance: 1))
        XCTAssertNotEqual(ModuleRefreshPolicy.interval(10, tolerance: 1), .interval(10, tolerance: 2))
        XCTAssertNotEqual(ModuleRefreshPolicy.eventDriven, .manual)
    }

    // MARK: - EnergyMode

    func testEnergyModeTitles() {
        XCTAssertEqual(EnergyMode.normal.title, "Normal")
        XCTAssertEqual(EnergyMode.smart.title, "Smart")
        XCTAssertEqual(EnergyMode.lowPower.title, "Low Power")
    }

    func testEnergyModeHasDescription() {
        for mode in EnergyMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode) should have a description")
        }
    }

    func testEnergyModeIdentifiableUsesRawValue() {
        XCTAssertEqual(EnergyMode.normal.id, "normal")
        XCTAssertEqual(EnergyMode.smart.id, "smart")
        XCTAssertEqual(EnergyMode.lowPower.id, "lowPower")
    }

    // MARK: - IslandActivityState equality

    func testIslandActivityStateEquality() {
        let lhs = IslandActivityState(
            islandState: .compact,
            activeModule: .builtIn(.battery),
            fullExpandedTab: .home,
            isHovering: false,
            isAppActive: true
        )
        let rhs = IslandActivityState(
            islandState: .compact,
            activeModule: .builtIn(.battery),
            fullExpandedTab: .home,
            isHovering: false,
            isAppActive: true
        )

        XCTAssertEqual(lhs, rhs)
    }

    func testIslandActivityStateInequalityOnEachField() {
        let base = IslandActivityState(
            islandState: .compact,
            activeModule: nil,
            fullExpandedTab: .home,
            isHovering: false,
            isAppActive: true
        )

        XCTAssertNotEqual(base, IslandActivityState(
            islandState: .expanded, activeModule: nil,
            fullExpandedTab: .home, isHovering: false, isAppActive: true
        ))
        XCTAssertNotEqual(base, IslandActivityState(
            islandState: .compact, activeModule: .builtIn(.battery),
            fullExpandedTab: .home, isHovering: false, isAppActive: true
        ))
        XCTAssertNotEqual(base, IslandActivityState(
            islandState: .compact, activeModule: nil,
            fullExpandedTab: .home, isHovering: true, isAppActive: true
        ))
        XCTAssertNotEqual(base, IslandActivityState(
            islandState: .compact, activeModule: nil,
            fullExpandedTab: .home, isHovering: false, isAppActive: false
        ))
    }

    // MARK: - EnergyDiagnosticsSnapshot equality

    func testEnergyDiagnosticsSnapshotEquality() {
        let lhs = EnergyDiagnosticsSnapshot(
            id: "job.1", name: "Job", moduleName: "Battery",
            policy: "Every 1m", status: "Scheduled",
            nextFireDate: Date(timeIntervalSince1970: 1000),
            lastRunDate: nil, lastRunDuration: nil, lastError: nil
        )
        let rhs = EnergyDiagnosticsSnapshot(
            id: "job.1", name: "Job", moduleName: "Battery",
            policy: "Every 1m", status: "Scheduled",
            nextFireDate: Date(timeIntervalSince1970: 1000),
            lastRunDate: nil, lastRunDuration: nil, lastError: nil
        )

        XCTAssertEqual(lhs, rhs)
    }
}
