import XCTest
@testable import SuperIsland

/// Tests for the `ModuleType`, `IslandState`, and `ActiveModule` value types
/// that form the backbone of routing and module identity across the app.
@MainActor
final class AppStateCoreTests: XCTestCase {

    // MARK: - ModuleType enumeration integrity

    func testModuleTypeIsCaseIterableAndIdentifiable() {
        // Every case must round-trip through its rawValue (the @AppStorage key
        // contract and the ModuleType switch routing depend on this).
        for module in ModuleType.allCases {
            XCTAssertEqual(ModuleType(rawValue: module.rawValue), module)
            XCTAssertEqual(module.id, module.rawValue)
        }

        // Sanity: the current built-in module set.
        let ids = ModuleType.allCases.map(\.rawValue).sorted()
        XCTAssertEqual(ids, [
            "battery",
            "calendar",
            "ciMonitor",
            "connectivity",
            "devServers",
            "docker",
            "gitHub",
            "gitStats",
            "nowPlaying",
            "notifications",
            "prayerTimes",
            "quran",
            "shelf",
            "teleprompter",
            "volumeHUD",
            "weather"
        ].sorted())
    }

    func testEveryModuleTypeHasDisplayNameAndIcon() {
        for module in ModuleType.allCases {
            XCTAssertFalse(module.displayName.isEmpty, "\(module) needs a display name")
            XCTAssertFalse(module.iconName.isEmpty, "\(module) needs an SF Symbol name")
        }
    }

    // MARK: - IslandState transitions

    func testIslandStateEquality() {
        XCTAssertEqual(IslandState.compact, .compact)
        XCTAssertEqual(IslandState.expanded, .expanded)
        XCTAssertEqual(IslandState.fullExpanded, .fullExpanded)
        XCTAssertNotEqual(IslandState.compact, .expanded)
        XCTAssertNotEqual(IslandState.expanded, .fullExpanded)
    }

    // MARK: - ActiveModule tagging

    func testActiveModuleBuiltInEquality() {
        XCTAssertEqual(ActiveModule.builtIn(.battery), .builtIn(.battery))
        XCTAssertNotEqual(ActiveModule.builtIn(.battery), .builtIn(.weather))
    }

    func testActiveModuleExtensionEquality() {
        XCTAssertEqual(ActiveModule.extension_("superisland.pomodoro"),
                       .extension_("superisland.pomodoro"))
        XCTAssertNotEqual(ActiveModule.extension_("superisland.pomodoro"),
                          .extension_("superisland.ai-usage"))
    }

    func testActiveModuleBuiltInVsExtensionNeverEqual() {
        XCTAssertNotEqual(ActiveModule.builtIn(.battery), .extension_("battery"))
    }

    // MARK: - AppState didChangeState hook

    func testAppStateFiresDidChangeStateOnTransition() {
        // The window controller relies on this closure firing synchronously
        // inside the animation block. Lock down the contract.
        let state = AppState.shared
        state.currentState = .compact // ensure a known starting point

        var observed: [(IslandState, IslandState)] = []
        state.didChangeState = { from, to in observed.append((from, to)) }

        state.currentState = .expanded
        state.currentState = .fullExpanded
        state.currentState = .compact

        state.didChangeState = nil

        XCTAssertEqual(observed.count, 3)
        XCTAssertEqual(observed[0].0, .compact)
        XCTAssertEqual(observed[0].1, .expanded)
        XCTAssertEqual(observed[1].0, .expanded)
        XCTAssertEqual(observed[1].1, .fullExpanded)
        XCTAssertEqual(observed[2].0, .fullExpanded)
        XCTAssertEqual(observed[2].1, .compact)
    }

    func testAppStateDoesNotFireDidChangeStateWhenUnchanged() {
        let state = AppState.shared
        state.currentState = .expanded

        var fired = false
        state.didChangeState = { _, _ in fired = true }

        state.currentState = .expanded // same value

        state.didChangeState = nil

        XCTAssertFalse(fired, "didChangeState must be suppressed when the value does not change")
    }
}
