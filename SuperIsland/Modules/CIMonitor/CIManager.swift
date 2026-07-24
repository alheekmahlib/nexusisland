import AppKit
import Combine
import Foundation

// MARK: - CI Monitor Manager
//
// Native module that surfaces GitHub Actions CI status across all of the
// user's repositories by shelling out to the authenticated `gh` CLI. Reuses
// `gh auth login` like the GitHub module — no token management.
//
// Strategy: list the user's repos, then `gh run list` the most recent run
// from each. Aggregates failures and in-progress runs for the badge + alerts.

@MainActor
final class CIManager: ObservableObject {
    static let shared = CIManager()

    // MARK: - Published state

    @Published private(set) var summary: CISummary = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isInstalled = false
    @Published private(set) var isAuthenticated = false

    private var refreshToken: ModuleRefreshToken?

    /// Max number of repos to scan (caps total gh calls + latency).
    private let maxRepos = 15

    // MARK: - Init

    private init() {
        Task { @MainActor in
            self.checkInstallation()
            if self.isInstalled {
                self.refresh()
            }
            self.registerRefresh()
        }
    }

    // MARK: - Installation / auth detection

    func checkInstallation() {
        isInstalled = (GitHubManager.exec(command: "gh", args: ["--version"]) != nil)
        guard isInstalled else {
            isAuthenticated = false
            summary = CISummary(isReady: false,
                                errorMessage: "gh CLI غير مثبّت")
            return
        }
        let status = GitHubManager.exec(command: "gh", args: ["auth", "status"])
        isAuthenticated = (status != nil)
        if !isAuthenticated {
            summary = CISummary(isReady: false,
                                errorMessage: "gh غير مُصادَق — شغّل gh auth login")
        }
    }

    // MARK: - Refresh

    func refresh() {
        guard !isLoading else { return }
        checkInstallation()
        guard isInstalled, isAuthenticated else { return }

        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = await Self.fetchAllRuns(maxRepos: self?.maxRepos ?? 15)
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                var runs = result.runs
                runs.sort()
                self.summary = CISummary(runs: runs, isReady: true, errorMessage: result.error)
            }
        }
    }

    // MARK: - gh execution (off-main)

    /// Fetch the latest CI runs across the user's repos.
    nonisolated static func fetchAllRuns(maxRepos: Int) async -> (runs: [CIRun], error: String?) {
        // 1. List the user's repos.
        guard let reposJSON = GitHubManager.exec(command: "gh", args: [
            "repo", "list", "--json", "nameWithOwner", "--limit", "\(maxRepos)"
        ]), let data = reposJSON.data(using: .utf8) else {
            return ([], "تعذّر جلب قائمة المستودعات")
        }

        let repoNames = parseRepoNames(data)
        guard !repoNames.isEmpty else { return ([], nil) }

        // 2. For each repo, fetch the latest few runs (1 each to keep it fast).
        var allRuns: [CIRun] = []
        for repo in repoNames {
            if let out = GitHubManager.exec(command: "gh", args: [
                "run", "list", "--repo", repo, "--limit", "3",
                "--json", "databaseId,name,workflowName,displayTitle,status,conclusion,headBranch,event,url,updatedAt"
            ]), let runData = out.data(using: .utf8) {
                allRuns.append(contentsOf: CIRunParser.parse(runData, repoName: repo))
            }
        }
        return (allRuns, nil)
    }

    /// Extract nameWithOwner strings from `gh repo list --json nameWithOwner`.
    nonisolated static func parseRepoNames(_ jsonData: Data) -> [String] {
        guard let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { $0["nameWithOwner"] as? String }
    }

    // MARK: - Refresh scheduling

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "ci.refresh",
            name: "CI monitor refresh",
            module: .builtIn(.ciMonitor),
            policy: .activeOnly(300, tolerance: 60), // every 5 min when active
            enabled: { AppState.shared.ciMonitorEnabled }
        ) { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }

    // MARK: - Actions

    func openRun(_ run: CIRun) {
        NSWorkspace.shared.open(run.url)
    }
}
