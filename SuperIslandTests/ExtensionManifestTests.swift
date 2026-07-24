import XCTest
@testable import NexusIsland

/// Tests for `ExtensionManifest` JSON decoding.
///
/// The manifest is the contract between every JS extension and the host, so its
/// parsing rules — required fields, defaults applied via `decodeIfPresent`,
/// refreshInterval clamping, capability defaults — are worth locking down.
final class ExtensionManifestTests: XCTestCase {

    // MARK: - Minimal valid manifest

    func testMinimalValidManifestDecodesWithDefaults() throws {
        let json = #"""
        {
            "id": "superisland.demo",
            "name": "Demo",
            "version": "1.0.0"
        }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertEqual(manifest.id, "superisland.demo")
        XCTAssertEqual(manifest.name, "Demo")
        XCTAssertEqual(manifest.version, "1.0.0")
        // Defaults
        XCTAssertEqual(manifest.main, "index.js")
        XCTAssertEqual(manifest.minAppVersion, "1.0.0")
        XCTAssertEqual(manifest.refreshInterval, 1.0, accuracy: 0.001)
        XCTAssertEqual(manifest.activationTriggers, ["manual"])
        XCTAssertTrue(manifest.defaultEnabled)
        XCTAssertEqual(manifest.permissions, [])
        XCTAssertEqual(manifest.categories, [])
        XCTAssertEqual(manifest.description, "")
    }

    // MARK: - Capability defaults

    func testCapabilitiesDefaultToStandardSurface() throws {
        // Omitting `capabilities` entirely should yield the same defaults as the
        // Capabilities() no-op initializer documented in ExtensionManifest.swift.
        let json = #"""
        { "id": "x", "name": "x", "version": "1.0.0" }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertTrue(manifest.capabilities.compact)
        XCTAssertTrue(manifest.capabilities.expanded)
        XCTAssertTrue(manifest.capabilities.fullExpanded)
        XCTAssertFalse(manifest.capabilities.minimalCompact)
        XCTAssertTrue(manifest.capabilities.backgroundRefresh)
        XCTAssertTrue(manifest.capabilities.settings)
        XCTAssertFalse(manifest.capabilities.notificationFeed)
    }

    func testCapabilitiesPartialOverrideKeepsDefaults() throws {
        // An extension that only opts into notificationFeed should keep the rest
        // of the capability defaults — exactly what Linear/WhatsApp do.
        let json = #"""
        {
            "id": "x",
            "name": "x",
            "version": "1.0.0",
            "capabilities": { "notificationFeed": true, "compact": false }
        }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertTrue(manifest.capabilities.notificationFeed)
        XCTAssertFalse(manifest.capabilities.compact)
        // Untouched keys fall back to defaults.
        XCTAssertTrue(manifest.capabilities.expanded)
        XCTAssertTrue(manifest.capabilities.fullExpanded)
        XCTAssertTrue(manifest.capabilities.backgroundRefresh)
    }

    // MARK: - refreshInterval clamping

    func testRefreshIntervalFloorIsAppliedToZero() throws {
        // refreshInterval is clamped to a minimum of 0.1s to avoid pathological
        // polling. A value of 0 must become 0.1.
        let json = #"""
        { "id": "x", "name": "x", "version": "1.0.0", "refreshInterval": 0 }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertEqual(manifest.refreshInterval, 0.1, accuracy: 0.001)
    }

    func testRefreshIntervalFloorIsAppliedToNegative() throws {
        let json = #"""
        { "id": "x", "name": "x", "version": "1.0.0", "refreshInterval": -5 }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertEqual(manifest.refreshInterval, 0.1, accuracy: 0.001)
    }

    func testRefreshIntervalAboveFloorIsPreserved() throws {
        let json = #"""
        { "id": "x", "name": "x", "version": "1.0.0", "refreshInterval": 2.5 }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: json)

        XCTAssertEqual(manifest.refreshInterval, 2.5, accuracy: 0.001)
    }

    // MARK: - Required fields

    func testMissingIDThrows() {
        let json = #"""
        { "name": "x", "version": "1.0.0" }
        """#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(ExtensionManifest.self, from: json))
    }

    func testMissingNameThrows() {
        let json = #"""
        { "id": "x", "version": "1.0.0" }
        """#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(ExtensionManifest.self, from: json))
    }

    func testMissingVersionThrows() {
        let json = #"""
        { "id": "x", "name": "x" }
        """#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(ExtensionManifest.self, from: json))
    }

    // MARK: - Round-trip encoding

    func testManifestRoundTripsThroughEncodeDecode() throws {
        let originalJSON = #"""
        {
            "id": "superisland.roundtrip",
            "name": "Round Trip",
            "version": "2.3.1",
            "minAppVersion": "1.0.5",
            "main": "main.js",
            "description": "A test extension",
            "categories": ["productivity", "fun"],
            "permissions": ["network", "storage"],
            "capabilities": { "minimalCompact": true, "notificationFeed": false },
            "refreshInterval": 0.5,
            "activationTriggers": ["timer"],
            "defaultEnabled": false
        }
        """#.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: originalJSON)

        let reencoded = try JSONEncoder().encode(manifest)
        let decodedAgain = try JSONDecoder().decode(ExtensionManifest.self, from: reencoded)

        XCTAssertEqual(decodedAgain.id, manifest.id)
        XCTAssertEqual(decodedAgain.name, manifest.name)
        XCTAssertEqual(decodedAgain.version, manifest.version)
        XCTAssertEqual(decodedAgain.main, "main.js")
        XCTAssertEqual(decodedAgain.permissions, ["network", "storage"])
        XCTAssertEqual(decodedAgain.refreshInterval, 0.5, accuracy: 0.001)
        XCTAssertEqual(decodedAgain.activationTriggers, ["timer"])
        XCTAssertFalse(decodedAgain.defaultEnabled)
        XCTAssertTrue(decodedAgain.capabilities.minimalCompact)
    }

    // MARK: - load(from:) filesystem contract

    func testLoadFromMissingDirectoryThrowsMissingManifest() {
        let nonexistent = URL(fileURLWithPath: "/tmp/superisland-manifest-test-\(UUID().uuidString)")

        XCTAssertThrowsError(try ExtensionManifest.load(from: nonexistent)) { error in
            guard case ExtensionManifest.ManifestError.missingManifest = error else {
                XCTFail("expected missingManifest, got \(error)")
                return
            }
        }
    }

    func testLoadFromDirectoryWithoutEntryFileThrowsMissingEntry() throws {
        // manifest.json present but no index.js → must surface a clear error.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("superisland-no-entry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let manifestJSON = #"""
        { "id": "x", "name": "x", "version": "1.0.0" }
        """#
        try manifestJSON.write(
            to: dir.appendingPathComponent("manifest.json"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertThrowsError(try ExtensionManifest.load(from: dir)) { error in
            guard case ExtensionManifest.ManifestError.missingEntry = error else {
                XCTFail("expected missingEntry, got \(error)")
                return
            }
        }
    }
}
