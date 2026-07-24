import SwiftUI

// MARK: - Docker Compact View (pill)
//
// 200×36pt — single row: whale icon + running count.

struct DockerCompactView: View {
    @ObservedObject private var manager = DockerManager.shared

    var body: some View {
        if !manager.summary.isInstalled {
            Image(systemName: "shippingbox")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        } else if !manager.summary.isRunning {
            Image(systemName: "shippingbox")
                .font(.system(size: 11))
                .foregroundColor(.orange)
        } else if manager.summary.runningCount == 0 {
            Image(systemName: "shippingbox")
                .font(.system(size: 11))
                .foregroundColor(QuranDesign.textTertiary)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 10))
                    .foregroundColor(QuranDesign.accent)
                Text("\(manager.summary.runningCount)")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
            }
        }
    }
}

// MARK: - Docker Expanded View (drawer)
//
// 408×88pt — container list or setup prompt.

struct DockerExpandedView: View {
    @ObservedObject private var manager = DockerManager.shared

    var body: some View {
        if !manager.summary.isInstalled || !manager.summary.isRunning {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(QuranDesign.body(11))
                    .foregroundColor(QuranDesign.textSecondary)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        } else if manager.summary.containers.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 14))
                    .foregroundColor(QuranDesign.textTertiary)
                Text("لا توجد حاويات")
                    .font(QuranDesign.body(10))
                    .foregroundColor(QuranDesign.textSecondary)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.summary.containers.prefix(4))) { container in
                    containerRow(container)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func containerRow(_ container: DockerContainer) -> some View {
        Button(action: { manager.openContainer(container) }) {
            HStack(spacing: 6) {
                Circle().fill(container.isRunning ? Color.green : Color.gray).frame(width: 6, height: 6)
                Text(container.name)
                    .font(QuranDesign.body(10))
                    .foregroundColor(QuranDesign.textPrimary)
                    .lineLimit(1)
                if let port = container.firstHostPort {
                    Text(":\(port)")
                        .font(QuranDesign.mono(9))
                        .foregroundColor(QuranDesign.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Docker Full Expanded View (detail panel)
//
// 658×180pt — summary + scrollable container list.

struct DockerFullExpandedView: View {
    @ObservedObject private var manager = DockerManager.shared

    var body: some View {
        if !manager.summary.isInstalled || !manager.summary.isRunning {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20)).foregroundColor(.orange)
                Text(manager.summary.errorMessage ?? "غير جاهز")
                    .font(QuranDesign.body(12)).foregroundColor(QuranDesign.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
        } else {
            HStack(spacing: 0) {
                statsCard.frame(width: 170).frame(maxHeight: .infinity)
                Rectangle().fill(QuranDesign.surfaceStroke).frame(width: 0.5)
                containerList.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Docker")
                .font(QuranDesign.surahName(13))
                .foregroundColor(QuranDesign.textPrimary)
                .padding(.bottom, 2)
            bigStat(icon: "shippingbox.fill", count: manager.summary.runningCount,
                    label: "قيد التشغيل", color: .green)
            bigStat(icon: "pause.circle.fill", count: manager.summary.containers.filter { !$0.isRunning }.count,
                    label: "متوقفة", color: .gray)
            Spacer(minLength: 0)
        }
        .padding(10)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func bigStat(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text("\(count)").font(QuranDesign.surahName(14)).foregroundColor(QuranDesign.textPrimary)
            Text(label).font(QuranDesign.caption(8)).foregroundColor(QuranDesign.textTertiary)
        }
    }

    private var containerList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("الحاويات")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                Spacer()
                if manager.isLoading {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .environment(\.layoutDirection, .rightToLeft)

            Divider().background(QuranDesign.surfaceStroke)

            if manager.summary.containers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 20)).foregroundColor(QuranDesign.textTertiary)
                    Text("لا توجد حاويات")
                        .font(QuranDesign.body(11)).foregroundColor(QuranDesign.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.summary.containers) { container in
                            containerRow(container)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
    }

    private func containerRow(_ container: DockerContainer) -> some View {
        Button(action: { manager.openContainer(container) }) {
            HStack(spacing: 7) {
                Circle()
                    .fill(container.isRunning ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text(container.name)
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textPrimary).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(container.image)
                            .font(QuranDesign.caption(8))
                            .foregroundColor(QuranDesign.textTertiary)
                        Text(container.status)
                            .font(QuranDesign.caption(8))
                            .foregroundColor(container.isRunning ? .green : QuranDesign.textTertiary)
                        if let port = container.firstHostPort {
                            Text(":\(port)")
                                .font(QuranDesign.mono(8))
                                .foregroundColor(QuranDesign.accent)
                        }
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .quranSurface(radius: QuranDesign.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
