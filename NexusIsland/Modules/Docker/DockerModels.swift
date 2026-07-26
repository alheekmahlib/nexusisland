import Foundation

// MARK: - Docker Container Models
//
// Represents a running Docker container, parsed from `docker ps`.

/// One running Docker container.
struct DockerContainer: Identifiable, Equatable, Comparable {
    let id: String               // container ID (short form)
    let name: String             // container name
    let image: String            // image name:tag
    let status: String           // e.g. "Up 2 hours", "Restarting"
    let ports: String            // published ports, e.g. "0.0.0.0:3000->3000/tcp"

    /// Is the container healthy/running? (status starts with "Up")
    var isRunning: Bool { status.hasPrefix("Up") }

    /// First published host port, if any — for quick access.
    var firstHostPort: Int? {
        // Parse "0.0.0.0:3000->3000/tcp" → 3000.
        guard let colonRange = ports.range(of: ":") else { return nil }
        let afterColon = ports[colonRange.upperBound...]
        let digits = afterColon.prefix { $0.isNumber }
        return Int(digits)
    }

    /// Sort: running containers first, then by name.
    static func < (lhs: DockerContainer, rhs: DockerContainer) -> Bool {
        if lhs.isRunning != rhs.isRunning {
            return lhs.isRunning && !rhs.isRunning
        }
        return lhs.name < rhs.name
    }
}

// MARK: - Summary

struct DockerSummary: Equatable {
    var containers: [DockerContainer] = []
    var isInstalled: Bool = false
    var isRunning: Bool = false   // Docker daemon running
    var errorMessage: String?

    var runningCount: Int { containers.filter(\.isRunning).count }
    var totalMemoryHint: String? { nil } // docker stats is heavy; omitted for now

    static let empty = DockerSummary()
}

// MARK: - JSON parsing (matches `docker ps --format '{{json .}}'`)

private struct DockerPSItem: Decodable {
    let ID: String?
    let Names: String?
    let Image: String?
    let Status: String?
    let Ports: String?
}

enum DockerContainerParser {
    /// Parse newline-delimited JSON from `docker ps --format '{{json .}}'`.
    /// Each line is a complete JSON object for one container.
    static func parse(_ rawOutput: String) -> [DockerContainer] {
        var containers: [DockerContainer] = []
        for line in rawOutput.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let item = try? JSONDecoder().decode(DockerPSItem.self, from: data) else { continue }
            guard let id = item.ID, let name = item.Names else { continue }
            containers.append(DockerContainer(
                id: id,
                name: name,
                image: item.Image ?? "unknown",
                status: item.Status ?? "Unknown",
                ports: item.Ports ?? ""
            ))
        }
        return containers
    }

    /// Extract the first host port from a Docker ports string like
    /// "0.0.0.0:3000->3000/tcp, :::5432->5432/tcp".
    static func extractHostPort(_ ports: String) -> Int? {
        // Find the first ":NNNN->" pattern.
        guard let arrowRange = ports.range(of: "->") else { return nil }
        let beforeArrow = ports[..<arrowRange.lowerBound]
        guard let colonRange = beforeArrow.range(of: ":") else { return nil }
        let digits = beforeArrow[colonRange.upperBound...]
        return Int(digits)
    }
}
