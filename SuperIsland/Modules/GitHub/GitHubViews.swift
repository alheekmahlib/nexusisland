import SwiftUI

// MARK: - GitHub Compact View (pill)
//
// 200×36pt — single row: icon + actionable count badge.

struct GitHubCompactView: View {
    @ObservedObject private var manager = GitHubManager.shared

    var body: some View {
        if !manager.isInstalled {
            compactIcon(color: .gray, count: nil)
        } else if !manager.isAuthenticated {
            compactIcon(color: .orange, count: nil)
        } else if manager.summary.actionableCount > 0 {
            HStack(spacing: 6) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(QuranDesign.accent)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(QuranDesign.accentSoft))
                Text("\(manager.summary.actionableCount)")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
            }
        } else {
            compactIcon(color: .green, count: nil)
        }
    }

    private func compactIcon(color: Color, count: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "curlybraces")
                .font(.system(size: 11))
                .foregroundColor(color)
            if let count { Text("\(count)").font(QuranDesign.mono(10)) }
        }
    }
}

// MARK: - GitHub Expanded View (drawer)
//
// 408×88pt — summary counts + top items.

struct GitHubExpandedView: View {
    @ObservedObject private var manager = GitHubManager.shared

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            setupPrompt
        } else {
            HStack(spacing: 12) {
                statsColumn
                Divider().background(QuranDesign.surfaceStroke).frame(maxHeight: 60)
                topItems
            }
        }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)
            Text(manager.summary.errorMessage ?? "غير جاهز")
                .font(QuranDesign.body(11))
                .foregroundColor(QuranDesign.textSecondary)
        }
    }

    private var statsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow(icon: "arrow.triangle.pull", count: manager.summary.reviewRequestedCount,
                    label: "مراجعات")
            statRow(icon: "at", count: manager.summary.mentionCount,
                    label: "إشارات")
            statRow(icon: "smallcircle.filled", count: manager.summary.assignedCount,
                    label: "مهام")
        }
        .frame(width: 90)
    }

    private func statRow(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(QuranDesign.textTertiary)
            Text("\(count)").font(QuranDesign.mono(11)).foregroundColor(count > 0 ? QuranDesign.accent : QuranDesign.textSecondary)
            Text(label).font(QuranDesign.caption(9)).foregroundColor(QuranDesign.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var topItems: some View {
        VStack(alignment: .leading, spacing: 3) {
            let top = Array(manager.summary.items.prefix(2))
            if top.isEmpty {
                Text("كل شيء واضح ✓")
                    .font(QuranDesign.body(11))
                    .foregroundColor(.green)
            } else {
                ForEach(top) { item in
                    Button(action: { manager.openItem(item) }) {
                        HStack(spacing: 5) {
                            Image(systemName: item.kind.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(reasonColor(item.reason))
                            Text(item.title)
                                .font(QuranDesign.body(10))
                                .foregroundColor(QuranDesign.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reasonColor(_ reason: GitHubItemReason) -> Color {
        switch reason {
        case .reviewRequested: return QuranDesign.accent
        case .mentioned: return .orange
        case .assigned: return .blue
        case .authored: return QuranDesign.textTertiary
        }
    }
}

// MARK: - GitHub Full Expanded View (detail panel)
//
// 658×180pt — two columns: stats summary + scrollable item list.

struct GitHubFullExpandedView: View {
    @ObservedObject private var manager = GitHubManager.shared

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(QuranDesign.body(13))
                    .foregroundColor(QuranDesign.textSecondary)
            }
            .padding()
        } else {
            HStack(spacing: 0) {
                statsCard
                    .frame(width: 200)
                Rectangle().fill(QuranDesign.surfaceStroke).frame(width: 0.5)
                itemsList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GitHub")
                .font(QuranDesign.surahName(14))
                .foregroundColor(QuranDesign.textPrimary)
            bigStat(icon: "arrow.triangle.pull", count: manager.summary.reviewRequestedCount,
                    label: "مراجعات مستحقة", color: QuranDesign.accent)
            bigStat(icon: "at", count: manager.summary.mentionCount,
                    label: "إشارات إليك", color: .orange)
            bigStat(icon: "smallcircle.filled", count: manager.summary.assignedCount,
                    label: "مهام مسندة", color: .blue)
            bigStat(icon: "arrow.triangle.pull", count: manager.summary.authoredCount,
                    label: "PRs مفتوحة لك", color: QuranDesign.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private func bigStat(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            Text("\(count)").font(QuranDesign.surahName(16)).foregroundColor(QuranDesign.textPrimary)
            Text(label).font(QuranDesign.caption(9)).foregroundColor(QuranDesign.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("النشاط")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                Spacer()
                if manager.isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)

            Divider().background(QuranDesign.surfaceStroke)

            if manager.summary.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    Text("كل شيء واضح")
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.summary.items) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
    }

    private func itemRow(_ item: GitHubItem) -> some View {
        Button(action: { manager.openItem(item) }) {
            HStack(spacing: 8) {
                Image(systemName: item.kind.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(reasonColor(item.reason))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(reasonColor(item.reason).opacity(0.15)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.repoName)
                            .font(QuranDesign.caption(8))
                            .foregroundColor(QuranDesign.textTertiary)
                        if item.number > 0 {
                            Text("#\(item.number)")
                                .font(QuranDesign.mono(8))
                                .foregroundColor(QuranDesign.textTertiary)
                        }
                        Text(reasonLabel(item.reason))
                            .font(QuranDesign.caption(8))
                            .foregroundColor(reasonColor(item.reason))
                    }
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 8))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .quranSurface(radius: QuranDesign.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reasonColor(_ reason: GitHubItemReason) -> Color {
        switch reason {
        case .reviewRequested: return QuranDesign.accent
        case .mentioned: return .orange
        case .assigned: return .blue
        case .authored: return QuranDesign.textTertiary
        }
    }

    private func reasonLabel(_ reason: GitHubItemReason) -> String {
        switch reason {
        case .reviewRequested: return "مراجعة"
        case .mentioned: return "إشارة"
        case .assigned: return "مسند"
        case .authored: return "لك"
        }
    }
}
