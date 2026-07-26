import Foundation

// MARK: - Dev Server Models
//
// Represents a local TCP listener (a "dev server") discovered via `lsof`.
// Common dev ports get a friendly framework label; unknown ports show their
// process name.

/// One detected local dev server.
struct DevServer: Identifiable, Equatable, Comparable {
    let id: Int                  // the port number (stable, unique on localhost)
    let port: Int
    let processName: String      // e.g. "node", "python", "ruby"
    let frameworkHint: String?   // e.g. "React (Vite)" for known ports

    var displayLabel: String {
        if let hint = frameworkHint { return hint }
        return processName
    }

    var url: URL {
        URL(string: "http://localhost:\(port)")!
    }

    /// Sort: known frameworks first (by port), then unknown (by port).
    static func < (lhs: DevServer, rhs: DevServer) -> Bool {
        if (lhs.frameworkHint != nil) != (rhs.frameworkHint != nil) {
            return lhs.frameworkHint != nil
        }
        return lhs.port < rhs.port
    }
}

// MARK: - Known port → framework mapping
//
// Lets the UI show "React (Vite)" instead of just "node :3000". The map is
// curated for common web-dev defaults; unlisted ports fall back to process name.

enum DevServerFrameworks {
    static let knownPorts: [Int: String] = [
        3000: "React / Node",
        3001: "React (alt)",
        4000: "Jekyll / Phoenix",
        4200: "Angular",
        5000: "Flask / Flaskask",
        5173: "Vite",
        5174: "Vite (alt)",
        8000: "Django / Python",
        8080: "HTTP / Tomcat",
        8888: "Jupyter",
        9000: "PHP / PHP-FPM",
        9090: "Vite (preview)",
        4321: "Astro",
        8001: "Rails",
        3002: "Express",
        7823: "AgentsStatusBridge",
        5037: "ADB"
    ]

    /// Ports to hide — system daemons that aren't useful as "dev servers".
    static let hiddenPorts: Set<Int> = [
        // macOS ControlCenter (AirPlay)
        // We filter by 127.0.0.1 already, but these bind to * and clutter.
    ]

    /// High-numbered ephemeral ports from GUI apps (Figma, IDEs) — hide above
    /// this threshold unless the process looks like a dev server.
    static let ephemeralThreshold = 49152

    static func hint(for port: Int, process: String) -> String? {
        if let known = knownPorts[port] { return known }
        // Ephemeral ports from non-dev processes are noise.
        if port >= ephemeralThreshold { return nil }
        return nil
    }
}

// MARK: - lsof output parsing

enum DevServerParser {
    /// Parse `lsof -iTCP@127.0.0.1 -sTCP:LISTEN -P -n` output into DevServers.
    /// Each relevant line looks like:
    ///   COMMAND   PID USER   ...  TCP 127.0.0.1:3000 (LISTEN)
    /// We extract the port and the COMMAND column.
    static func parse(_ lsofOutput: String) -> [DevServer] {
        var seen = Set<Int>()
        var servers: [DevServer] = []

        for line in lsofOutput.split(separator: "\n") {
            // Skip the header row.
            if line.hasPrefix("COMMAND") { continue }
            // Must be a LISTEN on 127.0.0.1.
            guard line.contains("LISTEN"), line.contains("127.0.0.1") else { continue }

            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 2 else { continue }
            let processName = String(columns[0])

            // Find the port: the column containing "127.0.0.1:PORT".
            guard let addrColumn = columns.first(where: { $0.contains("127.0.0.1:") }),
                  let port = extractPort(from: String(addrColumn)) else { continue }

            if seen.insert(port).inserted {
                let hint = DevServerFrameworks.hint(for: port, process: processName)
                servers.append(DevServer(id: port, port: port,
                                         processName: processName, frameworkHint: hint))
            }
        }
        return servers
    }

    /// Extract the integer port from "127.0.0.1:3000" or "*:3000".
    static func extractPort(from address: String) -> Int? {
        guard let colonIndex = address.lastIndex(of: ":") else { return nil }
        let portString = address[address.index(after: colonIndex)...]
        return Int(portString)
    }
}
