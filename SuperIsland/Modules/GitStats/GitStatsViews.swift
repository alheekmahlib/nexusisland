import SwiftUI

// MARK: - Git Stats Compact View (pill)
//
// 200×36pt — single row: branch icon + dirty count.

struct GitStatsCompactView: View {
    @ObservedObject private var manager = GitStatsManager.shared

    var body: some View {
        if manager.summary.repos.isEmpty {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11))
                .foregroundColor(NexusPalette.textTertiary)
        } else if manager.summary.totalDirtyFiles > 0 {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(NexusPalette.warning)
                Text("\(manager.summary.totalDirtyFiles)")
                    .font(NexusTypography.title(12))
                    .foregroundColor(NexusPalette.warning)
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(NexusPalette.electricViolet)
                Text("\(manager.summary.totalCommitsToday)")
                    .font(NexusTypography.mono(10))
                    .foregroundColor(NexusPalette.textSecondary)
            }
        }
    }
}

// MARK: - Git Stats Expanded View (drawer)
//
// 408×88pt — summary + top repos needing attention.

struct GitStatsExpandedView: View {
    @ObservedObject private var manager = GitStatsManager.shared

    var body: some View {
        if manager.summary.repos.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 14))
                    .foregroundColor(NexusPalette.textTertiary)
                Text(manager.isLoading ? "جارٍ المسح…" : "لا توجد repos")
                    .font(NexusTypography.body(10))
                    .foregroundColor(NexusPalette.textSecondary)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        } else {
            HStack(spacing: 12) {
                summaryColumn
                Divider().background(NexusPalette.glassTint.opacity(0.10)).frame(maxHeight: 50)
                topRepos
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow(value: "\(manager.summary.repos.count)", label: "repos", color: NexusPalette.electricViolet)
            statRow(value: "\(manager.summary.totalDirtyFiles)", label: "متغير",
                    color: manager.summary.totalDirtyFiles > 0 ? NexusPalette.warning : NexusPalette.textSecondary)
            statRow(value: "\(manager.summary.totalCommitsToday)", label: "commit اليوم",
                    color: NexusPalette.textSecondary)
        }
        .frame(width: 95)
    }

    private func statRow(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(value).font(NexusTypography.mono(11)).foregroundColor(color)
            Text(label).font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
        }
    }

    private var topRepos: some View {
        let needy = manager.summary.repos.filter(\.needsAttention).prefix(2)
        return VStack(alignment: .leading, spacing: 3) {
            if needy.isEmpty {
                Text("كل repos نظيفة ✓")
                    .font(NexusTypography.body(10))
                    .foregroundColor(NexusPalette.success)
            } else {
                ForEach(Array(needy)) { repo in
                    repoRow(repo)
                }
            }
        }
    }

    private func repoRow(_ repo: GitRepoStat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8))
                .foregroundColor(NexusPalette.warning)
            Text(repo.name)
                .font(NexusTypography.body(10))
                .foregroundColor(NexusPalette.textPrimary)
                .lineLimit(1)
            if let badge = repo.attentionBadge {
                Text(badge)
                    .font(NexusTypography.caption(8))
                    .foregroundColor(NexusPalette.warning)
            }
        }
    }
}

// MARK: - Git Stats Full Expanded View (detail panel)
//
// 658×180pt — summary card + scrollable repo list.

struct GitStatsFullExpandedView: View {
    @ObservedObject private var manager = GitStatsManager.shared

    var body: some View {
        if manager.summary.repos.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 20))
                    .foregroundColor(NexusPalette.textTertiary)
                Text(manager.isLoading ? "جارٍ المسح…" : "لا توجد repos في المجلد")
                    .font(NexusTypography.body(11))
                    .foregroundColor(NexusPalette.textSecondary)
                Text(manager.scanPath)
                    .font(NexusTypography.caption(8))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
        } else {
            HStack(spacing: 0) {
                statsCard.frame(width: 170).frame(maxHeight: .infinity)
                Rectangle().fill(NexusPalette.glassTint.opacity(0.10)).frame(width: 0.5)
                repoList.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Git Repos")
                .font(NexusTypography.title(13))
                .foregroundColor(NexusPalette.textPrimary)
                .padding(.bottom, 2)
            bigStat(icon: "folder.fill", count: manager.summary.repos.count,
                    label: "repos", color: NexusPalette.electricViolet)
            bigStat(icon: "exclamationmark.triangle.fill", count: manager.summary.totalDirtyFiles,
                    label: "ملفات متغيرة", color: NexusPalette.warning)
            bigStat(icon: "arrow.triangle.branch", count: manager.summary.reposNeedingAttention,
                    label: "تحتاج إجراء", color: NexusPalette.danger)
            bigStat(icon: "checkmark.circle.fill", count: manager.summary.totalCommitsToday,
                    label: "commit اليوم", color: NexusPalette.success)
            Spacer(minLength: 0)
        }
        .padding(10)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func bigStat(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text("\(count)").font(NexusTypography.title(14)).foregroundColor(NexusPalette.textPrimary)
            Text(label).font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
        }
    }

    private var repoList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("المستودعات")
                    .font(NexusTypography.title(12))
                    .foregroundColor(NexusPalette.textPrimary)
                Spacer()
                if manager.isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .environment(\.layoutDirection, .rightToLeft)

            Divider().background(NexusPalette.glassTint.opacity(0.10))

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(manager.summary.repos) { repo in
                        repoRow(repo)
                    }
                }
                .padding(.horizontal, 5).padding(.vertical, 4)
            }
        }
    }

    private func repoRow(_ repo: GitRepoStat) -> some View {
        Button(action: { manager.revealInFinder(repo) }) {
            HStack(spacing: 7) {
                Circle()
                    .fill(repo.needsAttention ? NexusPalette.warning : NexusPalette.success)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(NexusTypography.body(11))
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 7))
                            .foregroundColor(NexusPalette.textTertiary)
                        Text(repo.branch)
                            .font(NexusTypography.mono(8))
                            .foregroundColor(NexusPalette.textTertiary)
                        if repo.dirtyFileCount > 0 {
                            Text("●\(repo.dirtyFileCount)")
                                .font(NexusTypography.mono(8))
                                .foregroundColor(NexusPalette.warning)
                        }
                        if repo.aheadCount > 0 {
                            Text("↑\(repo.aheadCount)")
                                .font(NexusTypography.mono(8))
                                .foregroundColor(NexusPalette.royalPurple)
                        }
                        if repo.commitsToday > 0 {
                            Text("\(repo.commitsToday) اليوم")
                                .font(NexusTypography.caption(7))
                                .foregroundColor(NexusPalette.success)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 8))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .nexusSurface(variant: .glass, isActive: repo.needsAttention, radius: NexusMetrics.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(NSLocalizedString("Reveal in Finder", comment: "Menu")) { manager.revealInFinder(repo) }
            Button(NSLocalizedString("Open in Terminal", comment: "Menu")) { manager.openInTerminal(repo) }
        }
    }
}
