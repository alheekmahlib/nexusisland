import AppKit
import Combine
import Foundation

// MARK: - Dev Server Manager
//
// Native module that detects local TCP listeners (dev servers) via `lsof`
// and surfaces them for quick access. Refreshes on an active-only schedule so
// it doesn't spawn lsof while the island is collapsed.

@MainActor
final class DevServerManager: ObservableObject {
    static let shared = DevServerManager()

    // MARK: - Published state

    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var isLoading = false

    private var refreshToken: ModuleRefreshToken?

    // MARK: - Init

    private init() {
        Task { @MainActor in
            self.refresh()
            self.registerRefresh()
        }
    }

    // MARK: - Refresh

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let detected = await Self.detectServers()
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                self.servers = detected.sorted()
            }
        }
    }

    /// Run lsof and parse the listeners. Off-main.
    nonisolated static func detectServers() async -> [DevServer] {
        // lsof -iTCP@127.0.0.1 -sTCP:LISTEN -P -n
        //   @127.0.0.1  → only localhost bindings (not external *)
        //   -sTCP:LISTEN → only listening sockets
        //   -P -n       → numeric ports/hosts (fast, no DNS)
        let output = GitHubManager.exec(command: "lsof", args: [
            "-iTCP@127.0.0.1", "-sTCP:LISTEN", "-P", "-n"
        ])
        guard let output else { return [] }
        return DevServerParser.parse(output)
    }

    // MARK: - Actions

    /// Open a server's URL in the default browser.
    func openServer(_ server: DevServer) {
        NSWorkspace.shared.open(server.url)
    }

    /// Copy the server URL to the clipboard.
    func copyURL(_ server: DevServer) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.url.absoluteString, forType: .string)
    }

    // MARK: - Refresh scheduling

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "devservers.refresh",
            name: "Dev servers scan",
            module: .builtIn(.devServers),
            policy: .activeOnly(60, tolerance: 15), // every 60s when active
            enabled: { AppState.shared.devServersEnabled }
        ) { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }
}
