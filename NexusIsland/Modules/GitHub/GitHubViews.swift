import SwiftUI

// MARK: - GitHub Compact View (pill)
//
// 200×36pt — single row: icon + actionable count badge.

struct GitHubCompactView: View {
    @ObservedObject private var manager = GitHubManager.shared

    var body: some View {
        if !manager.isInstalled {
            compactIcon(color: NexusPalette.textTertiary, count: nil)
        } else if !manager.isAuthenticated {
            compactIcon(color: NexusPalette.warning, count: nil)
        } else if manager.summary.actionableCount > 0 {
            HStack(spacing: 6) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(NexusPalette.electricViolet)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(NexusPalette.electricViolet.opacity(0.18)))
                Text("\(manager.summary.actionableCount)")
                    .font(NexusTypography.title(12))
                    .foregroundColor(NexusPalette.textPrimary)
            }
        } else {
            compactIcon(color: NexusPalette.success, count: nil)
        }
    }

    private func compactIcon(color: Color, count: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "curlybraces")
                .font(.system(size: 11))
                .foregroundColor(color)
            if let count { Text("\(count)").font(NexusTypography.mono(10)) }
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
                Divider().background(NexusPalette.glassTint.opacity(0.10)).frame(maxHeight: 60)
                topItems
            }
        }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(NexusPalette.warning)
            Text(manager.summary.errorMessage ?? "غير جاهز")
                .font(NexusTypography.body(11))
                .foregroundColor(NexusPalette.textSecondary)
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
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(NexusPalette.textTertiary)
            Text("\(count)").font(NexusTypography.mono(11)).foregroundColor(count > 0 ? NexusPalette.electricViolet : NexusPalette.textSecondary)
            Text(label).font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var topItems: some View {
        VStack(alignment: .leading, spacing: 3) {
            let top = Array(manager.summary.items.prefix(2))
            if top.isEmpty {
                Text("كل شيء واضح ✓")
                    .font(NexusTypography.body(11))
                    .foregroundColor(NexusPalette.success)
            } else {
                ForEach(top) { item in
                    Button(action: { manager.openItem(item) }) {
                        HStack(spacing: 5) {
                            Image(systemName: item.kind.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(reasonColor(item.reason))
                            Text(item.title)
                                .font(NexusTypography.body(10))
                                .foregroundColor(NexusPalette.textPrimary)
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
        case .reviewRequested: return NexusPalette.electricViolet
        case .mentioned: return NexusPalette.warning
        case .assigned: return NexusPalette.royalPurple
        case .ownedRepo: return NexusPalette.electricViolet
        case .authored: return NexusPalette.textTertiary
        }
    }
}

// MARK: - GitHub Full Expanded View (detail panel)
//
// 658×180pt — two columns: stats summary + scrollable item list.

struct GitHubFullExpandedView: View {
    @ObservedObject private var manager = GitHubManager.shared
    @State private var selectedTab: GitHubTab = .all

    enum GitHubTab: String, CaseIterable {
        case all, reviews, issues, pulls, owned
        var label: String {
            switch self {
            case .all: return "الكل"
            case .reviews: return "مراجعات"
            case .issues: return "Issues"
            case .pulls: return "PRs"
            case .owned: return "مستودعاتي"
            }
        }
    }

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(NexusPalette.warning)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(NexusTypography.body(13))
                    .foregroundColor(NexusPalette.textSecondary)
            }
            .padding()
        } else {
            HStack(spacing: 0) {
                statsCard
                    .frame(width: 200)
                    .frame(maxHeight: .infinity)
                Rectangle().fill(NexusPalette.glassTint.opacity(0.10)).frame(width: 0.5)
                itemsList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("GitHub")
                .font(NexusTypography.title(13))
                .foregroundColor(NexusPalette.textPrimary)
                .padding(.bottom, 2)
            bigStat(icon: "arrow.triangle.pull", count: manager.summary.reviewRequestedCount,
                    label: "مراجعات مستحقة", color: NexusPalette.electricViolet)
            bigStat(icon: "exclamationmark.bubble.fill", count: manager.summary.unansweredCount,
                    label: "بانتظار ردك", color: NexusPalette.warning)
            bigStat(icon: "smallcircle.filled", count: manager.summary.assignedCount,
                    label: "مهام مسندة", color: NexusPalette.royalPurple)
            bigStat(icon: "building.2.fill", count: manager.summary.ownedRepoCount,
                    label: "في مستودعاتي", color: NexusPalette.electricViolet)
            bigStat(icon: "arrow.triangle.pull", count: manager.summary.authoredCount,
                    label: "PRs مفتوحة لك", color: NexusPalette.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func bigStat(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text("\(count)").font(NexusTypography.title(14)).foregroundColor(NexusPalette.textPrimary)
            Text(label).font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// Items filtered by the selected tab.
    private var filteredItems: [GitHubItem] {
        switch selectedTab {
        case .all: return manager.summary.items
        case .reviews: return manager.summary.items.filter { $0.reason == .reviewRequested }
        case .issues: return manager.summary.items.filter { $0.kind == .issue }
        case .pulls: return manager.summary.items.filter { $0.kind == .pullRequest }
        case .owned: return manager.summary.items.filter { $0.reason == .ownedRepo }
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar — switch between All / Reviews / Issues / PRs / Owned.
            tabBar

            Divider().background(NexusPalette.glassTint.opacity(0.10))

            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(NexusPalette.success)
                    Text("كل شيء واضح")
                        .font(NexusTypography.body(11))
                        .foregroundColor(NexusPalette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(GitHubTab.allCases, id: \.self) { tab in
                let count = tabItemCount(tab)
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 3) {
                        Text(tab.label)
                            .font(NexusTypography.caption(9))
                        if count > 0 {
                            Text("\(count)")
                                .font(NexusTypography.mono(8))
                                .foregroundColor(NexusPalette.textTertiary)
                        }
                    }
                    .foregroundColor(selectedTab == tab ? NexusPalette.textPrimary : NexusPalette.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selectedTab == tab ? NexusPalette.electricViolet.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if manager.isLoading {
                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 5)
    }

    private func tabItemCount(_ tab: GitHubTab) -> Int {
        switch tab {
        case .all: return manager.summary.items.count
        case .reviews: return manager.summary.reviewRequestedCount
        case .issues: return manager.summary.items.filter { $0.kind == .issue }.count
        case .pulls: return manager.summary.items.filter { $0.kind == .pullRequest }.count
        case .owned: return manager.summary.ownedRepoCount
        }
    }

    private func itemRow(_ item: GitHubItem) -> some View {
        // Highlight unanswered items with a gold left bar; answered ones stay neutral.
        let accentColor = item.isAnswered ? NexusPalette.textTertiary : NexusPalette.electricViolet
        return Button(action: { manager.openItem(item) }) {
            HStack(spacing: 8) {
                // Unanswered indicator: a gold dot for unanswered, gray for answered.
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                    .opacity(item.isAnswered ? 0.3 : 1)

                Image(systemName: item.kind.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(reasonColor(item.reason))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(reasonColor(item.reason).opacity(0.15)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(NexusTypography.body(11))
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.repoName)
                            .font(NexusTypography.caption(8))
                            .foregroundColor(NexusPalette.textTertiary)
                        if item.number > 0 {
                            Text("#\(item.number)")
                                .font(NexusTypography.mono(8))
                                .foregroundColor(NexusPalette.textTertiary)
                        }
                        Text(reasonLabel(item.reason))
                            .font(NexusTypography.caption(8))
                            .foregroundColor(reasonColor(item.reason))
                        if !item.isAnswered {
                            Text("بدون رد")
                                .font(NexusTypography.caption(8))
                                .foregroundColor(NexusPalette.electricViolet)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 8))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            // Unanswered rows get a subtle gold-tinted background.
            .nexusSurface(variant: .glass, isActive: !item.isAnswered, radius: NexusMetrics.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reasonColor(_ reason: GitHubItemReason) -> Color {
        switch reason {
        case .reviewRequested: return NexusPalette.electricViolet
        case .mentioned: return NexusPalette.warning
        case .assigned: return NexusPalette.royalPurple
        case .ownedRepo: return NexusPalette.electricViolet
        case .authored: return NexusPalette.textTertiary
        }
    }

    private func reasonLabel(_ reason: GitHubItemReason) -> String {
        switch reason {
        case .reviewRequested: return "مراجعة"
        case .mentioned: return "إشارة"
        case .assigned: return "مسند"
        case .ownedRepo: return "مستودعك"
        case .authored: return "لك"
        }
    }
}
