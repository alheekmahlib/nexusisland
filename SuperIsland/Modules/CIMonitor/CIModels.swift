import Foundation

// MARK: - CI Run Models
//
// Models a single GitHub Actions run. Surfaced by CIMonitor across all of the
// user's repositories. Each run carries a conclusion (success/failure/etc.)
// that drives the badge color and alerts.

/// Final result of a CI run (when status == completed).
enum CIConclusion: String, Codable, Equatable {
    case success, failure, cancelled, skipped, actionRequired = "action_required"
    case neutral, stale, timedOut = "timed_out", startupFailure = "startup_failure"

    /// "Unknown" fallback for any conclusion string we don't map.
    static func from(_ raw: String?) -> CIConclusion? {
        guard let raw else { return nil }
        return CIConclusion(rawValue: raw)
    }

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure, .startupFailure, .timedOut: return "xmark.octagon.fill"
        case .cancelled: return "minus.circle.fill"
        case .skipped: return "forward.fill"
        case .actionRequired: return "exclamationmark.triangle.fill"
        case .neutral, .stale: return "minus.diamond.fill"
        }
    }

    /// Red-tinged conclusions demand attention.
    var isFailure: Bool {
        switch self {
        case .failure, .startupFailure, .timedOut: return true
        default: return false
        }
    }
}

/// Lifecycle status of a run (in-progress vs done).
enum CIStatus: String, Codable, Equatable {
    case queued, inProgress = "in_progress", completed, requested, waiting, pending

    static func from(_ raw: String?) -> CIStatus? {
        guard let raw else { return nil }
        return CIStatus(rawValue: raw)
    }

    var iconName: String {
        switch self {
        case .queued, .waiting, .requested, .pending: return "clock.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

/// One CI run, normalized for display.
struct CIRun: Identifiable, Equatable, Comparable {
    let id: Int                  // databaseId
    let repoName: String         // "owner/repo"
    let workflowName: String
    let displayTitle: String
    let status: CIStatus
    let conclusion: CIConclusion?
    let headBranch: String
    let event: String
    let url: URL
    let updatedAt: Date?

    /// Is this run in a state that needs the user's attention?
    var needsAttention: Bool {
        if status == .completed { return conclusion?.isFailure ?? false }
        return false // in-progress runs aren't alerts
    }

    /// Sort key: failures first, then most-recently-updated.
    static func < (lhs: CIRun, rhs: CIRun) -> Bool {
        if lhs.needsAttention != rhs.needsAttention {
            return lhs.needsAttention && !rhs.needsAttention
        }
        let lDate = lhs.updatedAt ?? .distantPast
        let rDate = rhs.updatedAt ?? .distantPast
        return lDate > rDate
    }
}

// MARK: - CI Summary (published by the manager)

struct CISummary: Equatable {
    var runs: [CIRun] = []
    var isReady: Bool = false
    var errorMessage: String?

    var failureCount: Int { runs.filter { $0.conclusion?.isFailure ?? false }.count }
    var inProgressCount: Int { runs.filter { $0.status == .inProgress }.count }
    var successCount: Int { runs.filter { $0.status == .completed && $0.conclusion == .success }.count }

    static let empty = CISummary()
}

// MARK: - JSON Decoding (matches `gh run list --json`)

private struct GHRunItem: Decodable {
    let databaseId: Int?
    let name: String?
    let workflowName: String?
    let displayTitle: String?
    let status: String?
    let conclusion: String?
    let headBranch: String?
    let event: String?
    let url: String?
    let updatedAt: String?
}

enum CIRunParser {
    /// Parse `gh run list --json` output into CIRuns, tagged with the repo name
    /// (which `gh run list` doesn't include — the caller knows it from --repo).
    static func parse(_ jsonData: Data, repoName: String) -> [CIRun] {
        guard let items = try? JSONDecoder().decode([GHRunItem].self, from: jsonData) else { return [] }
        return items.compactMap { item in
            guard let id = item.databaseId,
                  let status = CIStatus.from(item.status),
                  let urlString = item.url, let url = URL(string: urlString) else { return nil }
            return CIRun(
                id: id,
                repoName: repoName,
                workflowName: item.workflowName ?? item.name ?? "CI",
                displayTitle: item.displayTitle ?? item.name ?? "",
                status: status,
                conclusion: CIConclusion.from(item.conclusion),
                headBranch: item.headBranch ?? "",
                event: item.event ?? "",
                url: url,
                updatedAt: item.updatedAt.flatMap(GitHubItemParser.parseISODate)
            )
        }
    }
}
