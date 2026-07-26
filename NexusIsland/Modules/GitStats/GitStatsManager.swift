import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - Git Stats Manager
//
// Native module that scans a directory for git repositories and surfaces
// their branch/dirty/ahead-behind status. The scan directory defaults to
// ~/Documents/GitHub and is user-configurable in settings.

@MainActor
final class GitStatsManager: ObservableObject {
    static let shared = GitStatsManager()

    // MARK: - Published state

    @Published private(set) var summary: GitStatsSummary = .empty
    @Published private(set) var isLoading = false

    /// Directory containing repos to scan. Defaults to ~/Documents/GitHub.
    @AppStorage("gitStats.scanPath") var scanPath: String = GitStatsManager.defaultScanPath {
        didSet { refresh() }
    }

    private var refreshToken: ModuleRefreshToken?

    static var defaultScanPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Documents/GitHub"
    }

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
        let path = scanPath
        guard FileManager.default.fileExists(atPath: path) else {
            summary = GitStatsSummary(repos: [], scanPath: path)
            return
        }

        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let repos = await Self.scanRepos(at: path)
            await MainActor.run {
                guard let self else { return }
                self.isLoading = false
                self.summary = GitStatsSummary(repos: repos.sorted(), scanPath: path)
            }
        }
    }

    /// Scan `path` for git repos and read each one's status. Off-main.
    nonisolated static func scanRepos(at path: String) async -> [GitRepoStat] {
        let fm = FileManager.default
        // Find immediate subdirectories containing a .git folder.
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var repos: [GitRepoStat] = []
        for entry in entries.sorted() {
            // Skip hidden directories.
            guard !entry.hasPrefix(".") else { continue }
            let repoPath = "\(path)/\(entry)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: repoPath, isDirectory: &isDir), isDir.boolValue else { continue }
            // Must contain a .git subfolder.
            guard fm.fileExists(atPath: "\(repoPath)/.git") else { continue }
            if let stat = GitStatReader.readRepo(at: repoPath) {
                repos.append(stat)
            }
        }
        return repos
    }

    // MARK: - Actions

    /// Reveal the repo in Finder.
    func revealInFinder(_ repo: GitRepoStat) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repo.path)
    }

    /// Open the repo in the default git GUI / Terminal.
    func openInTerminal(_ repo: GitRepoStat) {
        NSWorkspace.shared.openFile(repo.path, withApplication: "Terminal")
    }

    // MARK: - Refresh scheduling

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "gitstats.refresh",
            name: "Git stats refresh",
            module: .builtIn(.gitStats),
            policy: .activeOnly(120, tolerance: 30), // every 2 min when active
            enabled: { AppState.shared.gitStatsEnabled }
        ) { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }
}
