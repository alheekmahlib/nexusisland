import Foundation

// MARK: - GitHub Item Types
//
// A unified model for PRs, Issues, and mentions surfaced by the watcher.
// All three come from `gh` as JSON and are normalized into GitHubItem so the
// UI can render them uniformly.

/// What kind of GitHub entity an item is.
enum GitHubItemKind: String, Codable {
    case pullRequest
    case issue
    case mention

    var iconName: String {
        switch self {
        case .pullRequest: return "arrow.triangle.pull"
        case .issue: return "smallcircle.filled"
        case .mention: return "at"
        }
    }
}

/// Why an item surfaced — drives priority and grouping.
enum GitHubItemReason: String, Codable {
    case reviewRequested   // a PR needs your review
    case authored          // your own open PR/issue
    case assigned          // an issue assigned to you
    case mentioned         // you were @mentioned

    /// Display priority (lower = more important). Review requests rank highest.
    var priority: Int {
        switch self {
        case .reviewRequested: return 0
        case .mentioned: return 1
        case .assigned: return 2
        case .authored: return 3
        }
    }
}

/// One normalized GitHub entity.
struct GitHubItem: Identifiable, Equatable, Comparable {
    let id: String              // stable: "owner/repo#number"
    let kind: GitHubItemKind
    let reason: GitHubItemReason
    let number: Int
    let title: String
    let repoName: String        // "owner/repo"
    let url: URL
    let updatedAt: Date?

    /// Sort key for display: reason priority, then most-recently-updated.
    static func < (lhs: GitHubItem, rhs: GitHubItem) -> Bool {
        if lhs.reason.priority != rhs.reason.priority {
            return lhs.reason.priority < rhs.reason.priority
        }
        let lDate = lhs.updatedAt ?? .distantPast
        let rDate = rhs.updatedAt ?? .distantPast
        return lDate > rDate
    }
}

// MARK: - CI Status

/// Aggregate CI/checks status for a PR.
enum GitHubCIState: String, Codable, Equatable {
    case success, failure, pending, neutral, unknown

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        case .neutral: return "minus.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Summary (published by the manager)

/// A snapshot of everything the watcher surfaced in one refresh.
struct GitHubSummary: Equatable {
    var items: [GitHubItem] = []
    /// True if `gh` is installed and authenticated; false otherwise.
    var isReady: Bool = false
    /// Non-fatal error message when a refresh fails (shown briefly, then clears).
    var errorMessage: String?

    /// Counts by reason, for the compact badge.
    var reviewRequestedCount: Int { items.filter { $0.reason == .reviewRequested }.count }
    var mentionCount: Int { items.filter { $0.reason == .mentioned }.count }
    var assignedCount: Int { items.filter { $0.reason == .assigned }.count }
    var authoredCount: Int { items.filter { $0.reason == .authored }.count }

    /// Total actionable items (excluding authored — those don't demand action).
    var actionableCount: Int { reviewRequestedCount + mentionCount + assignedCount }

    static let empty = GitHubSummary()
}

// MARK: - JSON Decoding (matches `gh ... --json` output)
//
// `gh search prs --json` returns an array; each object has repository, number,
// title, state, url, updatedAt. The repository field is itself an object with
// nameWithOwner. We decode defensively — fields may be missing.

private struct GHSearchItem: Decodable {
    let number: Int?
    let title: String?
    let url: String?
    let updatedAt: String?
    let repository: GHRepo?

    struct GHRepo: Decodable {
        let nameWithOwner: String?
    }
}

private struct GHIssueItem: Decodable {
    let number: Int?
    let title: String?
    let url: String?
    let repository: String?      // gh issue list returns repo as a string
}

enum GitHubItemParser {
    /// Parse `gh search prs --json` output into GitHubItems with the given reason.
    static func parsePRs(_ jsonData: Data, reason: GitHubItemReason) -> [GitHubItem] {
        guard let items = try? JSONDecoder().decode([GHSearchItem].self, from: jsonData) else { return [] }
        return items.compactMap { parse(searchItem: $0, kind: .pullRequest, reason: reason) }
    }

    /// Parse `gh issue list --json` output into GitHubItems (issues, assigned reason).
    static func parseIssues(_ jsonData: Data, reason: GitHubItemReason = .assigned) -> [GitHubItem] {
        guard let items = try? JSONDecoder().decode([GHIssueItem].self, from: jsonData) else { return [] }
        return items.compactMap { issue in
            guard let number = issue.number,
                  let title = issue.title,
                  let urlString = issue.url, let url = URL(string: urlString) else { return nil }
            let repo = issue.repository ?? url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            let updated = issue.url.flatMap { _ in Date() } // issues list lacks updatedAt in some gh versions
            return GitHubItem(
                id: "\(repo)#\(number)",
                kind: .issue,
                reason: reason,
                number: number,
                title: title,
                repoName: repo,
                url: url,
                updatedAt: updated
            )
        }
    }

    private static func parse(searchItem: GHSearchItem, kind: GitHubItemKind, reason: GitHubItemReason) -> GitHubItem? {
        guard let number = searchItem.number,
              let title = searchItem.title,
              let urlString = searchItem.url, let url = URL(string: urlString) else { return nil }
        let repo = searchItem.repository?.nameWithOwner ?? ""
        let updated = searchItem.updatedAt.flatMap(Self.parseISODate)
        return GitHubItem(
            id: "\(repo)#\(number)",
            kind: kind,
            reason: reason,
            number: number,
            title: title,
            repoName: repo,
            url: url,
            updatedAt: updated
        )
    }

    static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Retry without fractional seconds.
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
