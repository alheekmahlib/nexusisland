import XCTest
@testable import NexusIsland

/// Tests for DevServerParser — the lsof output parsing logic. The manager
/// shells out to lsof (I/O), so we test the pure parser instead.
final class DevServerParserTests: XCTestCase {

    // MARK: - Port extraction

    func testExtractPortFromLocalhostAddress() {
        XCTAssertEqual(DevServerParser.extractPort(from: "127.0.0.1:3000"), 3000)
        XCTAssertEqual(DevServerParser.extractPort(from: "127.0.0.1:8080"), 8080)
        XCTAssertEqual(DevServerParser.extractPort(from: "127.0.0.1:7823"), 7823)
    }

    func testExtractPortFromWildcard() {
        XCTAssertEqual(DevServerParser.extractPort(from: "*:5000"), 5000)
    }

    func testExtractPortRejectsGarbage() {
        XCTAssertNil(DevServerParser.extractPort(from: "no-port"))
        XCTAssertNil(DevServerParser.extractPort(from: ""))
    }

    // MARK: - lsof parsing

    func testParseRealisticLsofOutput() {
        let lsof = #"""
        COMMAND    PID   USER   FD  TYPE DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x123  0t0  TCP 127.0.0.1:3000 (LISTEN)
        python    5678  user   3u  IPv4 0x456  0t0  TCP 127.0.0.1:8000 (LISTEN)
        """#
        let servers = DevServerParser.parse(lsof)
        XCTAssertEqual(servers.count, 2)
        XCTAssertTrue(servers.contains { $0.port == 3000 })
        XCTAssertTrue(servers.contains { $0.port == 8000 })
    }

    func testParseSkipsNonListenConnections() {
        let lsof = #"""
        COMMAND    PID   USER   FD  TYPE DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x123  0t0  TCP 127.0.0.1:3000->1.2.3.4:443 (ESTABLISHED)
        python    5678  user   3u  IPv4 0x456  0t0  TCP 127.0.0.1:8000 (LISTEN)
        """#
        let servers = DevServerParser.parse(lsof)
        XCTAssertEqual(servers.count, 1) // only the LISTEN one
        XCTAssertEqual(servers[0].port, 8000)
    }

    func testParseSkipsNonLocalhostBindings() {
        let lsof = #"""
        COMMAND    PID   USER   FD  TYPE DEVICE SIZE/OFF NODE NAME
        node      1234  user   20u  IPv4 0x123  0t0  TCP *:3000 (LISTEN)
        python    5678  user   3u  IPv4 0x456  0t0  TCP 127.0.0.1:8000 (LISTEN)
        """#
        let servers = DevServerParser.parse(lsof)
        XCTAssertEqual(servers.count, 1) // the *:3000 binding isn't 127.0.0.1
        XCTAssertEqual(servers[0].port, 8000)
    }

    func testParseDeduplicatesSamePort() {
        // IPv4 and IPv6 bindings of the same port appear as two lines.
        let lsof = #"""
        node      1234  user   20u  IPv4 0x1  0t0  TCP 127.0.0.1:3000 (LISTEN)
        node      1234  user   21u  IPv6 0x2  0t0  TCP 127.0.0.1:3000 (LISTEN)
        """#
        let servers = DevServerParser.parse(lsof)
        XCTAssertEqual(servers.count, 1, "duplicate port should collapse")
    }

    // MARK: - Framework hints

    func testFrameworkHintForKnownPorts() {
        XCTAssertEqual(DevServerFrameworks.hint(for: 3000, process: "node"), "React / Node")
        XCTAssertEqual(DevServerFrameworks.hint(for: 8000, process: "python"), "Django / Python")
        XCTAssertEqual(DevServerFrameworks.hint(for: 5173, process: "node"), "Vite")
    }

    func testFrameworkHintNilForUnknownEphemeralPort() {
        XCTAssertNil(DevServerFrameworks.hint(for: 50000, process: "figma_agent"))
    }

    // MARK: - DevServer model

    func testDevServerDisplayLabelPrefersHint() {
        let server = DevServer(id: 3000, port: 3000, processName: "node", frameworkHint: "React / Node")
        XCTAssertEqual(server.displayLabel, "React / Node")
    }

    func testDevServerDisplayLabelFallsBackToProcessName() {
        let server = DevServer(id: 12345, port: 12345, processName: "python", frameworkHint: nil)
        XCTAssertEqual(server.displayLabel, "python")
    }

    func testDevServerComparableKnownPortsFirst() {
        let known = DevServer(id: 3000, port: 3000, processName: "node", frameworkHint: "React")
        let unknown = DevServer(id: 55000, port: 55000, processName: "figma", frameworkHint: nil)
        XCTAssertTrue(known < unknown, "known frameworks should sort first")
    }

    func testDevServerURL() {
        let server = DevServer(id: 8080, port: 8080, processName: "node", frameworkHint: nil)
        XCTAssertEqual(server.url.absoluteString, "http://localhost:8080")
    }

    // MARK: - ModuleType registration

    func testDevServersRegisteredInModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "devServers"))
        XCTAssertEqual(ModuleType.devServers.rawValue, "devServers")
        XCTAssertEqual(ModuleType.devServers.iconName, "server.rack")
        XCTAssertFalse(ModuleType.devServers.displayName.isEmpty)
    }
}
