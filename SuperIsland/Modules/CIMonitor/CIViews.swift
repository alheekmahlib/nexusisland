import SwiftUI

// MARK: - CI Monitor Compact View (pill)
//
// 200×36pt — single row: status icon + counts (failures in red).

struct CIMonitorCompactView: View {
    @ObservedObject private var manager = CIManager.shared

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            Image(systemName: "checkmark.gearshape")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        } else if manager.summary.failureCount > 0 {
            HStack(spacing: 5) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("\(manager.summary.failureCount)")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(.red)
            }
        } else if manager.summary.inProgressCount > 0 {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(QuranDesign.accent)
                Text("\(manager.summary.inProgressCount)")
                    .font(QuranDesign.mono(10))
                    .foregroundColor(QuranDesign.accent)
            }
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))
                .foregroundColor(.green)
        }
    }
}

// MARK: - CI Monitor Expanded View (drawer)
//
// 408×88pt — summary counts + failing runs.

struct CIMonitorExpandedView: View {
    @ObservedObject private var manager = CIManager.shared

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(QuranDesign.body(11))
                    .foregroundColor(QuranDesign.textSecondary)
            }
        } else {
            HStack(spacing: 12) {
                statusMedallion
                countsColumn
                Divider().background(QuranDesign.surfaceStroke).frame(maxHeight: 50)
                failingList
            }
        }
    }

    private var statusMedallion: some View {
        ZStack {
            Circle()
                .strokeBorder(statusColor.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(statusColor.opacity(0.15)))
            Image(systemName: statusIcon)
                .font(.system(size: 15))
                .foregroundColor(statusColor)
        }
        .frame(width: 38, height: 38)
    }

    private var statusColor: Color {
        if manager.summary.failureCount > 0 { return .red }
        if manager.summary.inProgressCount > 0 { return QuranDesign.accent }
        return .green
    }

    private var statusIcon: String {
        if manager.summary.failureCount > 0 { return "xmark.octagon.fill" }
        if manager.summary.inProgressCount > 0 { return "arrow.triangle.2.circlepath" }
        return "checkmark.seal.fill"
    }

    private var countsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.summary.failureCount > 0 {
                countRow(icon: "xmark.octagon.fill", count: manager.summary.failureCount,
                         label: "فشل", color: .red)
            }
            if manager.summary.inProgressCount > 0 {
                countRow(icon: "arrow.triangle.2.circlepath", count: manager.summary.inProgressCount,
                         label: "قيد التشغيل", color: QuranDesign.accent)
            }
            countRow(icon: "checkmark.circle.fill", count: manager.summary.successCount,
                     label: "نجاح", color: .green)
        }
        .frame(width: 95)
    }

    private func countRow(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9)).foregroundColor(color)
            Text("\(count)").font(QuranDesign.mono(11)).foregroundColor(color)
            Text(label).font(QuranDesign.caption(9)).foregroundColor(QuranDesign.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var failingList: some View {
        let failures = manager.summary.runs.filter { $0.needsAttention }.prefix(2)
        return VStack(alignment: .leading, spacing: 3) {
            if failures.isEmpty {
                Text("كل البناءات ناجحة ✓")
                    .font(QuranDesign.body(10))
                    .foregroundColor(.green)
            } else {
                ForEach(Array(failures), id: \.id) { run in
                    Button(action: { manager.openRun(run) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                            Text(run.workflowName)
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
}

// MARK: - CI Monitor Full Expanded View (detail panel)
//
// 658×180pt — two columns: summary + scrollable run list with filters.

struct CIMonitorFullExpandedView: View {
    @ObservedObject private var manager = CIManager.shared
    @State private var selectedTab: CITab = .all

    enum CITab: String, CaseIterable {
        case all, failing, running, passed
        var label: String {
            switch self {
            case .all: return "الكل"
            case .failing: return "فاشلة"
            case .running: return "قيد التشغيل"
            case .passed: return "ناجحة"
            }
        }
    }

    var body: some View {
        if !manager.isInstalled || !manager.isAuthenticated {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(QuranDesign.body(13)).foregroundColor(QuranDesign.textSecondary)
            }
            .padding()
        } else {
            HStack(spacing: 0) {
                statsCard.frame(width: 170).frame(maxHeight: .infinity)
                Rectangle().fill(QuranDesign.surfaceStroke).frame(width: 0.5)
                runsList.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CI Monitor")
                .font(QuranDesign.surahName(13))
                .foregroundColor(QuranDesign.textPrimary)
                .padding(.bottom, 2)
            bigStat(icon: "xmark.octagon.fill", count: manager.summary.failureCount,
                    label: "فشل البناء", color: .red)
            bigStat(icon: "arrow.triangle.2.circlepath", count: manager.summary.inProgressCount,
                    label: "قيد التشغيل", color: QuranDesign.accent)
            bigStat(icon: "checkmark.circle.fill", count: manager.summary.successCount,
                    label: "ناجحة", color: .green)
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func bigStat(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text("\(count)").font(QuranDesign.surahName(14)).foregroundColor(QuranDesign.textPrimary)
            Text(label).font(QuranDesign.caption(8)).foregroundColor(QuranDesign.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var filteredRuns: [CIRun] {
        switch selectedTab {
        case .all: return manager.summary.runs
        case .failing: return manager.summary.runs.filter { $0.needsAttention }
        case .running: return manager.summary.runs.filter { $0.status == .inProgress }
        case .passed: return manager.summary.runs.filter { $0.status == .completed && $0.conclusion == .success }
        }
    }

    private var runsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar
            Divider().background(QuranDesign.surfaceStroke)

            if filteredRuns.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20)).foregroundColor(.green)
                    Text("لا توجد runs")
                        .font(QuranDesign.body(11)).foregroundColor(QuranDesign.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredRuns) { run in
                            runRow(run)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(CITab.allCases, id: \.self) { tab in
                let count = tabItemCount(tab)
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 3) {
                        Text(tab.label).font(QuranDesign.caption(9))
                        if count > 0 {
                            Text("\(count)").font(QuranDesign.mono(8))
                                .foregroundColor(QuranDesign.textTertiary)
                        }
                    }
                    .foregroundColor(selectedTab == tab ? QuranDesign.textPrimary : QuranDesign.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selectedTab == tab ? QuranDesign.surfaceFillActive : Color.clear)
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

    private func tabItemCount(_ tab: CITab) -> Int {
        switch tab {
        case .all: return manager.summary.runs.count
        case .failing: return manager.summary.failureCount
        case .running: return manager.summary.inProgressCount
        case .passed: return manager.summary.successCount
        }
    }

    private func runRow(_ run: CIRun) -> some View {
        let color = conclusionColor(run)
        return Button(action: { manager.openRun(run) }) {
            HStack(spacing: 7) {
                Image(systemName: run.status == .inProgress ? run.status.iconName : (run.conclusion?.iconName ?? "questionmark.circle"))
                    .font(.system(size: 10)).foregroundColor(color)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(run.workflowName)
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textPrimary).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(run.repoName).font(QuranDesign.caption(8)).foregroundColor(QuranDesign.textTertiary)
                        Text(run.headBranch).font(QuranDesign.mono(8)).foregroundColor(QuranDesign.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 8)).foregroundColor(QuranDesign.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .quranSurface(isActive: run.needsAttention, radius: QuranDesign.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func conclusionColor(_ run: CIRun) -> Color {
        if run.status == .inProgress { return QuranDesign.accent }
        if run.conclusion?.isFailure ?? false { return .red }
        if run.conclusion == .success { return .green }
        return QuranDesign.textTertiary
    }
}
