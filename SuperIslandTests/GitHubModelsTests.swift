import XCTest
@testable import SuperIsland

/// Tests for GitHubModels — parsing and the priority/sort logic that drives
/// the watcher's display order. The manager shells out to `gh` (I/O), so we
/// test the pure parsing + model logic instead.
final class GitHubModelsTests: XCTestCase {

    // MARK: - PR parsing

    func testParsePRsFromRealisticGhJSON() {
        // Shape matches `gh search prs --json number,title,url,updatedAt,repository`.
        let json = #"""
        [{"number":42,"title":"Fix race condition","state":"open",
          "url":"https://github.com/owner/repo/pull/42",
          "updatedAt":"2026-07-23T10:00:00Z",
          "repository":{"nameWithOwner":"owner/repo"}}]
        """#.data(using: .utf8)!

        let items = GitHubItemParser.parsePRs(json, reason: .reviewRequested)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].number, 42)
        XCTAssertEqual(items[0].title, "Fix race condition")
        XCTAssertEqual(items[0].repoName, "owner/repo")
        XCTAssertEqual(items[0].kind, .pullRequest)
        XCTAssertEqual(items[0].reason, .reviewRequested)
        XCTAssertEqual(items[0].id, "owner/repo#42")
        XCTAssertNotNil(items[0].updatedAt)
    }

    func testParsePRsSkipsItemsWithMissingFields() {
        let json = #"""
        [{"number":1,"title":"ok","url":"https://github.com/o/r/pull/1"},
         {"number":2,"title":"no url"},
         {"title":"no number"}]
        """#.data(using: .utf8)!

        let items = GitHubItemParser.parsePRs(json, reason: .authored)
        XCTAssertEqual(items.count, 1) // only the first is complete
    }

    // MARK: - Issue parsing

    func testParseIssuesFromGhJSON() {
        let json = #"""
        [{"number":7,"title":"Bug: crash on launch","url":"https://github.com/owner/repo/issues/7","repository":"owner/repo"}]
        """#.data(using: .utf8)!

        let items = GitHubItemParser.parseIssues(json, reason: .assigned)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .issue)
        XCTAssertEqual(items[0].reason, .assigned)
        XCTAssertEqual(items[0].repoName, "owner/repo")
    }

    // MARK: - Sort order

    func testReviewRequestedRanksAboveAuthored() {
        let review = GitHubItem(id: "a#1", kind: .pullRequest, reason: .reviewRequested,
                                number: 1, title: "R", repoName: "a",
                                url: URL(string: "https://x.com")!, updatedAt: Date.distantPast)
        let authored = GitHubItem(id: "b#2", kind: .pullRequest, reason: .authored,
                                  number: 2, title: "A", repoName: "b",
                                  url: URL(string: "https://x.com")!, updatedAt: Date())
        XCTAssertTrue(review < authored, "reviewRequested should rank before authored")
    }

    func testSameReasonSortsByMostRecentUpdate() {
        let older = GitHubItem(id: "a#1", kind: .pullRequest, reason: .reviewRequested,
                               number: 1, title: "old", repoName: "a",
                               url: URL(string: "https://x.com")!,
                               updatedAt: Date(timeIntervalSince1970: 1000))
        let newer = GitHubItem(id: "b#2", kind: .pullRequest, reason: .reviewRequested,
                               number: 2, title: "new", repoName: "b",
                               url: URL(string: "https://x.com")!,
                               updatedAt: Date(timeIntervalSince1970: 2000))
        XCTAssertTrue(newer < older, "more recent should rank first")
    }

    // MARK: - Summary counts

    func testSummaryActionableCountExcludesAuthored() {
        let items = [
            GitHubItem(id: "1", kind: .pullRequest, reason: .reviewRequested, number: 1, title: "", repoName: "", url: URL(string: "https://x.com")!, updatedAt: nil),
            GitHubItem(id: "2", kind: .pullRequest, reason: .authored, number: 2, title: "", repoName: "", url: URL(string: "https://x.com")!, updatedAt: nil),
            GitHubItem(id: "3", kind: .issue, reason: .mentioned, number: 3, title: "", repoName: "", url: URL(string: "https://x.com")!, updatedAt: nil)
        ]
        let summary = GitHubSummary(items: items, isReady: true)
        XCTAssertEqual(summary.actionableCount, 2) // reviewRequested + mentioned, not authored
        XCTAssertEqual(summary.reviewRequestedCount, 1)
        XCTAssertEqual(summary.mentionCount, 1)
        XCTAssertEqual(summary.authoredCount, 1)
    }

    // MARK: - ModuleType registration

    func testGitHubRegisteredInModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "gitHub"))
        XCTAssertEqual(ModuleType.gitHub.rawValue, "gitHub")
        XCTAssertEqual(ModuleType.gitHub.iconName, "curlybraces")
        XCTAssertFalse(ModuleType.gitHub.displayName.isEmpty)
    }
}
