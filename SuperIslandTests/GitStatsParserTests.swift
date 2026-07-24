import XCTest
@testable import NexusIsland

/// Tests for GitStatReader's pure parsing functions.
final class GitStatsParserTests: XCTestCase {

    // MARK: - ahead/behind parsing

    func testParseAheadBehindNormalOutput() {
        // `git rev-list --left-right --count @{u}...HEAD` → "<behind>\t<ahead>"
        let result = GitStatReader.parseAheadBehind("2\t5\n")
        XCTAssertEqual(result.behind, 2)
        XCTAssertEqual(result.ahead, 5)
    }

    func testParseAheadBehindZero() {
        let result = GitStatReader.parseAheadBehind("0\t0\n")
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    func testParseAheadBehindNil() {
        let result = GitStatReader.parseAheadBehind(nil)
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    func testParseAheadBehindGarbage() {
        let result = GitStatReader.parseAheadBehind("not a number")
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    // MARK: - commits today parsing

    func testParseCommitsToday() {
        let output = "abc1234 Commit one\ndef5678 Commit two\n"
        XCTAssertEqual(GitStatReader.parseCommitsToday(output), 2)
    }

    func testParseCommitsTodayEmpty() {
        XCTAssertEqual(GitStatReader.parseCommitsToday(""), 0)
        XCTAssertEqual(GitStatReader.parseCommitsToday(nil), 0)
    }

    func testParseCommitsTodayMany() {
        let output = (1...10).map { "hash\($0) Commit \($0)" }.joined(separator: "\n")
        XCTAssertEqual(GitStatReader.parseCommitsToday(output), 10)
    }

    // MARK: - GitRepoStat model

    func testNeedsAttentionTrueWhenDirty() {
        let repo = GitRepoStat(id: "/x", name: "x", path: "/x", branch: "main",
                               dirtyFileCount: 3, aheadCount: 0, behindCount: 0, commitsToday: 0)
        XCTAssertTrue(repo.needsAttention)
    }

    func testNeedsAttentionTrueWhenAhead() {
        let repo = GitRepoStat(id: "/x", name: "x", path: "/x", branch: "main",
                               dirtyFileCount: 0, aheadCount: 2, behindCount: 0, commitsToday: 0)
        XCTAssertTrue(repo.needsAttention)
    }

    func testNeedsAttentionFalseWhenClean() {
        let repo = GitRepoStat(id: "/x", name: "x", path: "/x", branch: "main",
                               dirtyFileCount: 0, aheadCount: 0, behindCount: 0, commitsToday: 5)
        XCTAssertFalse(repo.needsAttention)
    }

    func testAttentionBadgeShowsDirtyFirst() {
        let repo = GitRepoStat(id: "/x", name: "x", path: "/x", branch: "main",
                               dirtyFileCount: 4, aheadCount: 1, behindCount: 0, commitsToday: 0)
        XCTAssertEqual(repo.attentionBadge, "4 متغير")
    }

    func testAttentionBadgeShowsAheadWhenClean() {
        let repo = GitRepoStat(id: "/x", name: "x", path: "/x", branch: "main",
                               dirtyFileCount: 0, aheadCount: 3, behindCount: 0, commitsToday: 0)
        XCTAssertEqual(repo.attentionBadge, "3 للرفع")
    }

    func testComparableNeedyFirst() {
        let needy = GitRepoStat(id: "/a", name: "a", path: "/a", branch: "main",
                                dirtyFileCount: 1, aheadCount: 0, behindCount: 0, commitsToday: 0)
        let clean = GitRepoStat(id: "/b", name: "b", path: "/b", branch: "main",
                                dirtyFileCount: 0, aheadCount: 0, behindCount: 0, commitsToday: 0)
        XCTAssertTrue(needy < clean)
    }

    // MARK: - ModuleType registration

    func testGitStatsRegisteredInModuleType() {
        XCTAssertNotNil(ModuleType(rawValue: "gitStats"))
        XCTAssertEqual(ModuleType.gitStats.rawValue, "gitStats")
        XCTAssertEqual(ModuleType.gitStats.iconName, "arrow.triangle.branch")
        XCTAssertFalse(ModuleType.gitStats.displayName.isEmpty)
    }
}
