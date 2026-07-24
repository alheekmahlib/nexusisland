import AppKit
import Combine
import Foundation

// MARK: - GitHub Manager
//
// Native module that surfaces GitHub activity (review requests, assigned issues,
// authored PRs, mentions) by shelling out to the authenticated `gh` CLI. This
// avoids managing tokens/OAuth — the user's existing `gh auth login` is reused.
//
// Follows the project manager-singleton convention: @MainActor ObservableObject
// with static let shared, registered in ModuleType.

@MainActor
final class GitHubManager: ObservableObject {
    static let shared = GitHubManager()

    // MARK: - Published state

    @Published private(set) var summary: GitHubSummary = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isInstalled = false
    @Published private(set) var isAuthenticated = false

    private var refreshToken: ModuleRefreshToken?

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

    /// Detect whether `gh` is on PATH and authenticated. Updates isInstalled
    /// and isAuthenticated; if gh is missing, the module stays inert.
    func checkInstallation() {
        isInstalled = (Self.exec(command: "gh", args: ["--version"]) != nil)
        guard isInstalled else {
            isAuthenticated = false
            summary = GitHubSummary(items: [], isReady: false,
                                    errorMessage: "gh CLI غير مثبّت — ثبّته من brew install gh")
            return
        }
        // `gh auth status` exits 0 when authenticated, non-zero otherwise.
        let status = Self.exec(command: "gh", args: ["auth", "status"])
        isAuthenticated = (status != nil)
        if !isAuthenticated {
            summary = GitHubSummary(items: [], isReady: false,
                                    errorMessage: "gh غير مُصادَق — شغّل gh auth login")
        }
    }

    // MARK: - Refresh

    func refresh() {
        guard !isLoading else { return }
        checkInstallation()
        guard isInstalled, isAuthenticated else { return }

        isLoading = true
        // Run the gh commands off the main thread to avoid blocking the UI.
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = await Self.fetchAllItems()
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                var merged = result.items
                // De-dup by id (an item could surface via multiple queries).
                var seen = Set<String>()
                merged = merged.filter { seen.insert($0.id).inserted }
                merged.sort()
                self.summary = GitHubSummary(items: merged, isReady: true,
                                             errorMessage: result.error)
            }
        }
    }

    // MARK: - gh command execution

    /// Run a command synchronously and return its stdout (nil on failure).
    /// Called from a background context.
    nonisolated static func exec(command: String, args: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + args
        process.standardOutput = pipe
        process.standardError = Pipe() // silence stderr
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Fetch all item categories from gh. Runs entirely off-main.
    nonisolated static func fetchAllItems() async -> (items: [GitHubItem], error: String?) {
        var items: [GitHubItem] = []
        var error: String?

        // 1. PRs requesting your review (highest priority).
        if let out = exec(command: "gh", args: [
            "search", "prs", "--review-requested=@me", "--state=open",
            "--json", "number,title,url,updatedAt,repository", "--limit", "20"
        ]), let data = out.data(using: .utf8) {
            items.append(contentsOf: GitHubItemParser.parsePRs(data, reason: .reviewRequested))
        }

        // 2. Your open PRs.
        if let out = exec(command: "gh", args: [
            "search", "prs", "--author=@me", "--state=open",
            "--json", "number,title,url,updatedAt,repository", "--limit", "20"
        ]), let data = out.data(using: .utf8) {
            items.append(contentsOf: GitHubItemParser.parsePRs(data, reason: .authored))
        }

        // 3. Issues assigned to you (search across all repos — `gh issue list`
        // only works inside a single repo context and returns empty otherwise).
        if let out = exec(command: "gh", args: [
            "search", "issues", "--assignee=@me", "--state=open",
            "--json", "number,title,url,repository", "--limit", "20"
        ]), let data = out.data(using: .utf8) {
            items.append(contentsOf: GitHubItemParser.parseIssues(data, reason: .assigned))
        }

        // 3b. Issues you opened (authored) — surfaces your own open issues.
        // NOTE: `gh search issues` searches issues only (PRs use `search prs`);
        // there is no --type flag (it errors). Same JSON shape as PRs.
        if let out = exec(command: "gh", args: [
            "search", "issues", "--author=@me", "--state=open",
            "--json", "number,title,url,repository", "--limit", "20"
        ]), let data = out.data(using: .utf8) {
            items.append(contentsOf: GitHubItemParser.parseIssues(data, reason: .authored))
        }

        // 4. Mentions — best-effort via notifications API.
        if let out = exec(command: "gh", args: [
            "api", "notifications", "--jq", ".[].subject.title"
        ]) {
            // Notifications need a richer parse; for now we count them as
            // mention items with a synthetic id.
            let titles = out.split(separator: "\n").prefix(10)
            for title in titles {
                items.append(GitHubItem(
                    id: "mention:\(title)",
                    kind: .mention, reason: .mentioned, number: 0,
                    title: String(title), repoName: "",
                    url: URL(string: "https://github.com/notifications")!,
                    updatedAt: Date()
                ))
            }
        }

        if items.isEmpty && error == nil {
            // No error, just empty — leave error nil so the UI shows "all clear".
        }

        return (items, error)
    }

    // MARK: - Refresh scheduling

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "github.refresh",
            name: "GitHub refresh",
            module: .builtIn(.gitHub),
            policy: .activeOnly(300, tolerance: 60), // every 5 min when active
            enabled: { AppState.shared.gitHubEnabled }
        ) { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }

    // MARK: - Actions

    /// Open an item's URL in the default browser.
    func openItem(_ item: GitHubItem) {
        NSWorkspace.shared.open(item.url)
    }
}
