import Foundation

// MARK: - Git Repo Stats Models
//
// Represents the git status of a local repository, scanned from a parent
// directory (e.g. ~/Documents/GitHub). Each repo surfaces its branch, dirty
// file count, ahead/behind counts, and today's commit count.

/// One repo's git status snapshot.
struct GitRepoStat: Identifiable, Equatable, Comparable {
    let id: String               // absolute path (stable)
    let name: String             // folder name
    let path: String             // absolute path
    let branch: String           // current branch name
    let dirtyFileCount: Int      // uncommitted/unstaged files
    let aheadCount: Int          // commits ahead of upstream
    let behindCount: Int         // commits behind upstream
    let commitsToday: Int        // commits since midnight

    /// Does this repo need attention? (dirty files or out of sync with upstream)
    var needsAttention: Bool {
        dirtyFileCount > 0 || aheadCount > 0
    }

    var attentionBadge: String? {
        if dirtyFileCount > 0 { return "\(dirtyFileCount) متغير" }
        if aheadCount > 0 { return "\(aheadCount) للرفع" }
        return nil
    }

    /// Sort: repos needing attention first, then by name.
    static func < (lhs: GitRepoStat, rhs: GitRepoStat) -> Bool {
        if lhs.needsAttention != rhs.needsAttention {
            return lhs.needsAttention && !rhs.needsAttention
        }
        return lhs.name < rhs.name
    }
}

// MARK: - Summary (published by the manager)

struct GitStatsSummary: Equatable {
    var repos: [GitRepoStat] = []
    var scanPath: String = ""
    var totalDirtyFiles: Int { repos.reduce(0) { $0 + $1.dirtyFileCount } }
    var totalCommitsToday: Int { repos.reduce(0) { $0 + $1.commitsToday } }
    var reposNeedingAttention: Int { repos.filter(\.needsAttention).count }

    static let empty = GitStatsSummary()
}

// MARK: - Git status parsing
//
// Runs `git` commands in a repo directory and extracts the stats. Pure
// functions for testability — the I/O (Process) lives in the manager.

enum GitStatReader {
    /// Read all stats for a single repo at `path`. Returns nil if not a git repo.
    nonisolated static func readRepo(at path: String) -> GitRepoStat? {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent

        let branch = exec(at: path, args: ["rev-parse", "--abbrev-ref", "HEAD"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"

        let dirty = exec(at: path, args: ["status", "--porcelain"])
        let dirtyCount = dirty?.split(separator: "\n").filter { !$0.isEmpty }.count ?? 0

        let (ahead, behind) = parseAheadBehind(exec(at: path, args: [
            "rev-list", "--left-right", "--count", "@{u}...HEAD"
        ]))

        let commitsToday = parseCommitsToday(exec(at: path, args: [
            "log", "--oneline", "--since=00:00:00"
        ]))

        return GitRepoStat(
            id: path, name: name, path: path, branch: branch,
            dirtyFileCount: dirtyCount, aheadCount: ahead, behindCount: behind,
            commitsToday: commitsToday
        )
    }

    /// Execute a git command in `path` and return stdout (nil on failure).
    nonisolated static func exec(at path: String, args: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }

    /// Parse `rev-list --left-right --count @{u}...HEAD` output: "<behind>\t<ahead>".
    static func parseAheadBehind(_ output: String?) -> (ahead: Int, behind: Int) {
        guard let output else { return (0, 0) }
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\t")
        guard parts.count == 2 else { return (0, 0) }
        let behind = Int(parts[0]) ?? 0
        let ahead = Int(parts[1]) ?? 0
        return (ahead, behind)
    }

    /// Count commits since midnight from `log --oneline --since=00:00:00`.
    static func parseCommitsToday(_ output: String?) -> Int {
        guard let output else { return 0 }
        return output.split(separator: "\n").filter { !$0.isEmpty }.count
    }
}
