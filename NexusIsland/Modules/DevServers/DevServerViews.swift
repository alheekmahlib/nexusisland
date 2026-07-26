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
                .foregroundColor(NexusPalette.textTertiary)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "server.rack")
                    .font(.system(size: 10))
                    .foregroundColor(NexusPalette.electricViolet)
                Text("\(manager.servers.count)")
                    .font(NexusTypography.title(12))
                    .foregroundColor(NexusPalette.textPrimary)
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
                    .foregroundColor(NexusPalette.textTertiary)
                Text("لا توجد خدمات محلية")
                    .font(NexusTypography.body(10))
                    .foregroundColor(NexusPalette.textSecondary)
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
                    .fill(NexusPalette.success)
                    .frame(width: 6, height: 6)
                Text(":\(server.port)")
                    .font(NexusTypography.mono(10))
                    .foregroundColor(NexusPalette.textPrimary)
                Text(server.displayLabel)
                    .font(NexusTypography.caption(9))
                    .foregroundColor(NexusPalette.textTertiary)
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
            Divider().background(NexusPalette.glassTint.opacity(0.10))

            if manager.servers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 22))
                        .foregroundColor(NexusPalette.textTertiary)
                    Text("لا توجد خدمات محلية تعمل")
                        .font(NexusTypography.body(12))
                        .foregroundColor(NexusPalette.textSecondary)
                    Text("شغّل خادم تطوير (npm run dev, python -m http.server, إلخ)")
                        .font(NexusTypography.caption(9))
                        .foregroundColor(NexusPalette.textTertiary)
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
                .font(NexusTypography.title(12))
                .foregroundColor(NexusPalette.textPrimary)
            Spacer()
            Text("\(manager.servers.count) نشط")
                .font(NexusTypography.caption(9))
                .foregroundColor(NexusPalette.electricViolet)
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
                    .fill(NexusPalette.success)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text("localhost:\(server.port)")
                        .font(NexusTypography.body(12))
                        .foregroundColor(NexusPalette.textPrimary)
                    HStack(spacing: 6) {
                        Text(server.displayLabel)
                            .font(NexusTypography.caption(9))
                            .foregroundColor(server.frameworkHint != nil ? NexusPalette.electricViolet : NexusPalette.textTertiary)
                        Text(server.processName)
                            .font(NexusTypography.caption(8))
                            .foregroundColor(NexusPalette.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 9))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusS)
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
