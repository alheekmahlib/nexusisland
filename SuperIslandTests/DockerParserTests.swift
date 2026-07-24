import XCTest
@testable import SuperIsland

/// Tests for DockerContainerParser — parsing `docker ps --format '{{json .}}'`.
final class DockerParserTests: XCTestCase {

    // MARK: - JSON line parsing

    func testParseSingleContainer() {
        let json = #"{"ID":"abc123","Names":"/my-app","Image":"node:18","Status":"Up 2 hours","Ports":"0.0.0.0:3000->3000/tcp"}"#
        let containers = DockerContainerParser.parse(json)
        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers[0].name, "/my-app")
        XCTAssertEqual(containers[0].image, "node:18")
        XCTAssertEqual(containers[0].status, "Up 2 hours")
        XCTAssertTrue(containers[0].isRunning)
    }

    func testParseMultipleContainers() {
        let json = """
        {"ID":"a1","Names":"web","Image":"nginx","Status":"Up 1 hour","Ports":"0.0.0.0:80->80/tcp"}
        {"ID":"b2","Names":"db","Image":"postgres","Status":"Up 3 hours","Ports":"5432/tcp"}
        """
        let containers = DockerContainerParser.parse(json)
        XCTAssertEqual(containers.count, 2)
        XCTAssertEqual(containers[0].name, "web")
        XCTAssertEqual(containers[1].name, "db")
    }

    func testParseSkipsEmptyAndGarbageLines() {
        let json = """

        {"ID":"a1","Names":"web","Image":"nginx","Status":"Up","Ports":""}
        garbage line

        """
        let containers = DockerContainerParser.parse(json)
        XCTAssertEqual(containers.count, 1) // only the valid JSON line
    }

    // MARK: - Port extraction

    func testExtractHostPort() {
        XCTAssertEqual(DockerContainerParser.extractHostPort("0.0.0.0:3000->3000/tcp"), 3000)
        XCTAssertEqual(DockerContainerParser.extractHostPort("0.0.0.0:8080->8080/tcp, :::8080->8080/tcp"), 8080)
    }

    func testExtractHostPortReturnsNilWhenNoPublishedPort() {
        XCTAssertNil(DockerContainerParser.extractHostPort("5432/tcp"))
        XCTAssertNil(DockerContainerParser.extractHostPort(""))
    }

    // MARK: - Model

    func testIsRunningDetectsUpStatus() {
        let c = DockerContainer(id: "1", name: "x", image: "x", status: "Up 5 minutes", ports: "")
        XCTAssertTrue(c.isRunning)
    }

    func testIsRunningFalseForExited() {
        let c = DockerContainer(id: "1", name: "x", image: "x", status: "Exited (0) 2 hours ago", ports: "")
        XCTAssertFalse(c.isRunning)
    }

    func testComparableRunningFirst() {
        let running = DockerContainer(id: "1", name: "a", image: "x", status: "Up", ports: "")
        let stopped = DockerContainer(id: "2", name: "b", image: "x", status: "Exited", ports: "")
        XCTAssertTrue(running < stopped)
    }

    // MARK: - ModuleType registration

    func testDockerRegisteredInModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "docker"))
        XCTAssertEqual(ModuleType.docker.rawValue, "docker")
        XCTAssertEqual(ModuleType.docker.iconName, "shippingbox")
        XCTAssertFalse(ModuleType.docker.displayName.isEmpty)
    }
}
