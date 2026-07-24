import AppKit
import Combine
import Foundation

// MARK: - Docker Manager
//
// Native module that lists running Docker containers via the `docker` CLI.
// Detects whether Docker is installed and the daemon is running; gracefully
// shows a setup prompt when it isn't.

@MainActor
final class DockerManager: ObservableObject {
    static let shared = DockerManager()

    // MARK: - Published state

    @Published private(set) var summary: DockerSummary = .empty
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
            let result = await Self.fetchContainers()
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                self.summary = DockerSummary(
                    containers: result.containers.sorted(),
                    isInstalled: result.isInstalled,
                    isRunning: result.isRunning,
                    errorMessage: result.error
                )
            }
        }
    }

    /// Run `docker ps` and parse the containers. Off-main.
    nonisolated static func fetchContainers() async -> (containers: [DockerContainer],
                                                        isInstalled: Bool,
                                                        isRunning: Bool,
                                                        error: String?) {
        // Check installation first.
        guard GitHubManager.exec(command: "docker", args: ["--version"]) != nil else {
            return ([], false, false, "Docker غير مثبّت")
        }

        // `docker ps` fails if the daemon isn't running — detect that.
        // --format '{{json .}}' gives one JSON object per line.
        let output = GitHubManager.exec(command: "docker", args: [
            "ps", "--format", "{{json .}}"
        ])
        guard let output else {
            // docker exists but command failed → daemon likely not running.
            return ([], true, false, "Docker daemon غير مشتغل — شغّل Docker Desktop")
        }

        let containers = DockerContainerParser.parse(output)
        return (containers, true, true, nil)
    }

    // MARK: - Actions

    /// Open the container's first published port in the browser.
    func openContainer(_ container: DockerContainer) {
        if let port = container.firstHostPort {
            NSWorkspace.shared.open(URL(string: "http://localhost:\(port)")!)
        }
    }

    // MARK: - Refresh scheduling

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "docker.refresh",
            name: "Docker refresh",
            module: .builtIn(.docker),
            policy: .activeOnly(60, tolerance: 15),
            enabled: { AppState.shared.dockerEnabled }
        ) { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }
}
