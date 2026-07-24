import SwiftUI

// MARK: - Dev Servers Compact View (pill)
//
// 200×36pt — single row: server icon + count.

struct DevServersCompactView: View {
    @ObservedObject private var manager = DevServerManager.shared

    var body: some View {
        if manager.servers.isEmpty {
            Image(systemName: "server.rack")
                .font(.system(size: 11))
                .foregroundColor(QuranDesign.textTertiary)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "server.rack")
                    .font(.system(size: 10))
                    .foregroundColor(QuranDesign.accent)
                Text("\(manager.servers.count)")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
            }
        }
    }
}

// MARK: - Dev Servers Expanded View (drawer)
//
// 408×88pt — top servers list with click-to-open.

struct DevServersExpandedView: View {
    @ObservedObject private var manager = DevServerManager.shared

    var body: some View {
        if manager.servers.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 14))
                    .foregroundColor(QuranDesign.textTertiary)
                Text("لا توجد خدمات محلية")
                    .font(QuranDesign.body(10))
                    .foregroundColor(QuranDesign.textSecondary)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.servers.prefix(4))) { server in
                    serverRow(server)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func serverRow(_ server: DevServer) -> some View {
        Button(action: { manager.openServer(server) }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(":\(server.port)")
                    .font(QuranDesign.mono(10))
                    .foregroundColor(QuranDesign.textPrimary)
                Text(server.displayLabel)
                    .font(QuranDesign.caption(9))
                    .foregroundColor(QuranDesign.textTertiary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dev Servers Full Expanded View (detail panel)
//
// 658×180pt — header + scrollable server list with framework hints.

struct DevServersFullExpandedView: View {
    @ObservedObject private var manager = DevServerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(QuranDesign.surfaceStroke)

            if manager.servers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 22))
                        .foregroundColor(QuranDesign.textTertiary)
                    Text("لا توجد خدمات محلية تعمل")
                        .font(QuranDesign.body(12))
                        .foregroundColor(QuranDesign.textSecondary)
                    Text("شغّل خادم تطوير (npm run dev, python -m http.server, إلخ)")
                        .font(QuranDesign.caption(9))
                        .foregroundColor(QuranDesign.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.layoutDirection, .rightToLeft)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.servers) { server in
                            serverRow(server)
                        }
                    }
                    .padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        HStack {
            Text("الخدمات المحلية")
                .font(QuranDesign.surahName(12))
                .foregroundColor(QuranDesign.textPrimary)
            Spacer()
            Text("\(manager.servers.count) نشط")
                .font(QuranDesign.caption(9))
                .foregroundColor(QuranDesign.accent)
            if manager.isLoading {
                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12).padding(.leading, 4)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }

    private func serverRow(_ server: DevServer) -> some View {
        Button(action: { manager.openServer(server) }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("localhost:\(server.port)")
                        .font(QuranDesign.body(12))
                        .foregroundColor(QuranDesign.textPrimary)
                    HStack(spacing: 6) {
                        Text(server.displayLabel)
                            .font(QuranDesign.caption(9))
                            .foregroundColor(server.frameworkHint != nil ? QuranDesign.accent : QuranDesign.textTertiary)
                        Text(server.processName)
                            .font(QuranDesign.caption(8))
                            .foregroundColor(QuranDesign.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .quranSurface(radius: QuranDesign.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(NSLocalizedString("Copy URL", comment: "Menu")) {
                manager.copyURL(server)
            }
        }
    }
}
