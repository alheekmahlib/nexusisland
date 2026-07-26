import SwiftUI
import AppKit

private let linearMentionsExtensionID = "nexus.linear-mentions"
private let lastFmScrobblerExtensionID = "nexus.lastfm-scrobbler"

private enum ExtensionListFilter: String, CaseIterable, Identifiable {
    case all
    case active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return NSLocalizedString("All", comment: "Extension filter")
        case .active: return NSLocalizedString("Active", comment: "Extension filter")
        }
    }
}

struct ExtensionsSettingsView: View {
    @ObservedObject private var manager = ExtensionManager.shared
    @ObservedObject private var logger = ExtensionLogger.shared
    @State private var selectedExtensionID: String?
    @State private var listFilter: ExtensionListFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            filterBar

            HStack(alignment: .top, spacing: 16) {
                leftPane
                    .frame(width: 300)

                rightPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            manager.discoverExtensions()
            preserveSelection()
        }
        .onChange(of: manager.installed.map(\.id)) { _, _ in
            preserveSelection()
        }
        .onChange(of: activeExtensionIDs) { _, _ in
            preserveSelection()
        }
        .onChange(of: listFilter) { _, _ in
            preserveSelection()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("Filter", comment: "Settings label"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(NexusPalette.textPrimary)

            Picker("", selection: $listFilter) {
                ForEach(ExtensionListFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer(minLength: 0)

            Text("\(filteredManifests.count) " + NSLocalizedString("shown", comment: "Extension count"))
                .font(.system(size: 11))
                .foregroundColor(NexusPalette.textSecondary)

            Button {
                manager.discoverExtensions()
                preserveSelection()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingSectionLabel(title: NSLocalizedString("Extensions", comment: "Settings section"))

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredManifests, id: \.id) { manifest in
                        let isSelected = selectedExtensionID == manifest.id
                        Button {
                            selectedExtensionID = manifest.id
                        } label: {
                            extensionListRow(for: manifest, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .settingsGlassSurface(elevatesOnHover: false)
    }

    @ViewBuilder
    private var rightPane: some View {
        if let manifest = selectedManifest {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    extensionHeaderCard(for: manifest)

                    if manifest.id == "nexus.whatsapp-web" {
                        SettingsCard(title: NSLocalizedString("WhatsApp Web Login", comment: "Card title")) {
                            WhatsAppWebBridgeSettingsView()
                        }
                    }

                    if manifest.id == linearMentionsExtensionID {
                        SettingsCard(title: NSLocalizedString("Linear Login", comment: "Card title")) {
                            LinearOAuthSettingsView()
                        }
                    }

                    if manifest.id == lastFmScrobblerExtensionID {
                        SettingsCard(title: NSLocalizedString("Last.fm Login", comment: "Card title")) {
                            LastFmOAuthSettingsView()
                        }
                    }

                    SettingsCard(title: NSLocalizedString("Details", comment: "Card title")) {
                        if let author = manifest.author?.name {
                            metadataRow(label: NSLocalizedString("Author", comment: "Metadata label"), value: author)
                        }
                        if manifest.id != linearMentionsExtensionID {
                            metadataRow(label: NSLocalizedString("Refresh", comment: "Metadata label"), value: "\(String(format: "%.1f", manifest.refreshInterval))s")
                        }
                        metadataRow(label: NSLocalizedString("Triggers", comment: "Metadata label"), value: manifest.activationTriggers.joined(separator: ", "))

                        if !manifest.permissions.isEmpty {
                            metadataRow(label: NSLocalizedString("Permissions", comment: "Metadata label"), value: manifest.permissions.joined(separator: ", "))
                        }
                    }

                    if let schema = manager.settingsSchemas[manifest.id] {
                        SettingsCard(title: NSLocalizedString("Settings", comment: "Card title")) {
                            ExtensionSettingsRenderer(extensionID: manifest.id, schema: schema)
                        }
                    }

                    let logEntries = logger.entries(for: manifest.id)
                    if !logEntries.isEmpty {
                        SettingsCard(title: NSLocalizedString("Recent Logs", comment: "Card title")) {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(logEntries.suffix(8)) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(NexusPalette.textTertiary)
                                            .frame(width: 72, alignment: .leading)

                                        Text("[\(entry.level.rawValue.uppercased())] \(entry.message)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(entry.level == .error ? NexusPalette.danger : NexusPalette.textSecondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 28))
                    .foregroundColor(NexusPalette.textTertiary)
                Text(NSLocalizedString("Select an extension", comment: "Settings label"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                Text(NSLocalizedString("Choose an extension from the left panel.", comment: "Settings description"))
                    .font(.system(size: 12))
                    .foregroundColor(NexusPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .settingsGlassSurface(elevatesOnHover: false)
        }
    }

    private func extensionHeaderCard(for manifest: ExtensionManifest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 12) {
                    extensionIcon(for: manifest, size: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(manifest.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(NexusPalette.textPrimary)
                        Text("\(manifest.id) • v\(manifest.version)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(NexusPalette.textSecondary)
                    }
                }

                Spacer()

                statusBadge(isActive: manager.runtimes[manifest.id] != nil)
            }

            Text(manifest.description)
                .font(.system(size: 13))
                .foregroundColor(NexusPalette.textSecondary)

            HStack(spacing: 10) {
                Button(manager.runtimes[manifest.id] == nil ? NSLocalizedString("Activate", comment: "Button") : NSLocalizedString("Reload", comment: "Button")) {
                    if manager.runtimes[manifest.id] == nil {
                        manager.activate(extensionID: manifest.id)
                    } else {
                        manager.reload(extensionID: manifest.id)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(SettingsGlass.toggleTint)

                if manager.runtimes[manifest.id] != nil {
                    Button(NSLocalizedString("Deactivate", comment: "Button")) {
                        manager.disableByUser(extensionID: manifest.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .settingsGlassSurface(elevatesOnHover: false)
    }

    private func statusBadge(isActive: Bool) -> some View {
        Text(isActive
             ? NSLocalizedString("Active", comment: "Status label")
             : NSLocalizedString("Inactive", comment: "Status label"))
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive
                          ? NexusPalette.success.opacity(0.18)
                          : NexusPalette.deepPurple.opacity(0.30))
            )
            .foregroundColor(isActive ? NexusPalette.success : NexusPalette.textSecondary)
    }

    private func extensionListRow(for manifest: ExtensionManifest, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            extensionIcon(for: manifest, size: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(manifest.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    sourceBadge(for: manifest)
                }

                Text(manifest.id)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? NexusPalette.textPrimary : NexusPalette.textTertiary)
            }

            Spacer(minLength: 6)

            Circle()
                .fill(manager.runtimes[manifest.id] == nil
                      ? NexusPalette.textTertiary.opacity(isSelected ? 0.80 : 0.45)
                      : NexusPalette.success)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isSelected
                    ? selectedRowFillColor
                    : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(colors: [NexusPalette.electricViolet.opacity(0.40), .clear],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func sourceBadge(for manifest: ExtensionManifest) -> some View {
        let source = extensionSource(for: manifest)
        Text(source.label)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(source.color.opacity(0.18))
            )
            .foregroundColor(source.color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func extensionIcon(for manifest: ExtensionManifest, size: CGFloat) -> some View {
        let radius = max(6, size * 0.24)
        if let image = extensionIconImage(for: manifest) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(NexusPalette.glassTint.opacity(0.18), lineWidth: 0.5)
                )
        } else {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundColor(NexusPalette.electricViolet)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(NexusPalette.royalPurple.opacity(0.18))
                )
        }
    }

    private func extensionIconImage(for manifest: ExtensionManifest) -> NSImage? {
        guard let iconURL = manifest.iconURL else { return nil }

        if let image = NSImage(contentsOf: iconURL) {
            return image
        }

        if let data = try? Data(contentsOf: iconURL), let image = NSImage(data: data) {
            return image
        }

        return nil
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(NexusPalette.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(NexusPalette.textPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private var selectedManifest: ExtensionManifest? {
        guard let selectedExtensionID else { return nil }
        return filteredManifests.first(where: { $0.id == selectedExtensionID })
            ?? manager.installed.first(where: { $0.id == selectedExtensionID })
    }

    private var filteredManifests: [ExtensionManifest] {
        switch listFilter {
        case .all:
            return manager.installed
        case .active:
            return manager.installed.filter { manager.runtimes[$0.id] != nil }
        }
    }

    private var activeExtensionIDs: [String] {
        manager.runtimes.keys.sorted()
    }

    private func extensionSource(for manifest: ExtensionManifest) -> (label: String, color: Color) {
        if isInstalledExtension(manifest) {
            return (NSLocalizedString("Installed", comment: "Extension source badge"), NexusPalette.electricViolet)
        }
        return (NSLocalizedString("Bundled", comment: "Extension source badge"), NexusPalette.textSecondary)
    }

    private func isInstalledExtension(_ manifest: ExtensionManifest) -> Bool {
        let installedPath = manager.installedExtensionsDirectory.standardizedFileURL.path
        let bundlePath = manifest.bundleURL.standardizedFileURL.path
        return bundlePath == installedPath || bundlePath.hasPrefix(installedPath + "/")
    }

    private func preserveSelection() {
        guard !filteredManifests.isEmpty else {
            selectedExtensionID = nil
            return
        }

        if let selectedExtensionID,
           filteredManifests.contains(where: { $0.id == selectedExtensionID }) {
            return
        }

        selectedExtensionID = filteredManifests.first?.id
    }

    private var selectedRowFillColor: Color {
        // Dark-only (window forces dark); brand the selection with the purple ramp.
        NexusPalette.royalPurple.opacity(0.28)
    }
}

private struct LinearOAuthSettingsView: View {
    private static let authorizeURLString = "https://api.supercmd.sh/auth/linear/authorize?app=nexusisland"
    private static let oauthStoreKey = "extensions.\(linearMentionsExtensionID).store.oauth"

    @ObservedObject private var manager = ExtensionManager.shared
    @State private var session: LinearOAuthSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                Text(statusTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                Spacer()
            }

            Text(statusMessage)
                .font(.system(size: 12))
                .foregroundColor(NexusPalette.textSecondary)

            HStack(spacing: 8) {
                Button(primaryButtonTitle) {
                    openAuthorizeURL()
                }
                .buttonStyle(.borderedProminent)
                .tint(SettingsGlass.toggleTint)

                if session != nil {
                    Button(NSLocalizedString("Disconnect", comment: "Button")) {
                        disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(NexusPalette.danger)
                }
            }

            if let session {
                VStack(alignment: .leading, spacing: 4) {
                    if !session.scope.isEmpty {
                        Text("Scope: \(session.scope)")
                            .font(.system(size: 11))
                            .foregroundColor(NexusPalette.textSecondary)
                    }

                    if let expiresAt = session.expiresAt {
                        Text(expirationLabel(expiresAt: expiresAt, isExpired: session.isExpired))
                            .font(.system(size: 11))
                            .foregroundColor(session.isExpired ? NexusPalette.danger : NexusPalette.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            reloadSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reloadSession()
        }
    }

    private var statusTitle: String {
        if let session {
            return session.isExpired ? NSLocalizedString("Expired", comment: "Status label") : NSLocalizedString("Logged in", comment: "Status label")
        }
        return NSLocalizedString("Not logged in", comment: "Status label")
    }

    private var statusColor: Color {
        if let session {
            return session.isExpired ? NexusPalette.warning : NexusPalette.success
        }
        return NexusPalette.textTertiary
    }

    private var statusMessage: String {
        if let session {
            if session.isExpired {
                return NSLocalizedString("Your Linear session has expired. Authenticate again to resume mention syncing.", comment: "Settings description")
            }
            return NSLocalizedString("Linear is authenticated. New mentions will appear in the Nexus Island.", comment: "Settings description")
        }
        return NSLocalizedString("Authenticate with Linear to start mention notifications and inline replies.", comment: "Settings description")
    }

    private var primaryButtonTitle: String {
        if let session {
            return session.isExpired ? NSLocalizedString("Log In Again", comment: "Button") : NSLocalizedString("Reconnect", comment: "Button")
        }
        return NSLocalizedString("Log In to Linear", comment: "Button")
    }

    private func reloadSession() {
        session = LinearOAuthSession.load()
    }

    private func openAuthorizeURL() {
        guard let url = URL(string: Self.authorizeURLString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.oauthStoreKey)
        // SECURITY: also purge the Keychain entry so the secret is fully gone,
        // not just the metadata mirror in UserDefaults.
        KeychainStore.delete(account: linearMentionsExtensionID, service: "nexus.oauth")

        if manager.runtimes[linearMentionsExtensionID] == nil {
            manager.activate(extensionID: linearMentionsExtensionID)
        }
        manager.scheduleImmediateRefresh(extensionID: linearMentionsExtensionID)
        reloadSession()
    }

    private func expirationLabel(expiresAt: Date, isExpired: Bool) -> String {
        let formatted = expiresAt.formatted(date: .abbreviated, time: .shortened)
        return isExpired ? "Expired at \(formatted)" : "Expires at \(formatted)"
    }
}

private struct LinearOAuthSession {
    private static let oauthStoreKey = "extensions.\(linearMentionsExtensionID).store.oauth"

    let accessToken: String
    let tokenType: String
    let scope: String
    let receivedAt: Date?
    let expiresAt: Date?
    let isExpired: Bool

    static func load(defaults: UserDefaults = .standard) -> LinearOAuthSession? {
        guard let dictionary = defaults.dictionary(forKey: oauthStoreKey) else {
            return nil
        }

        let accessToken = normalizedText(dictionary["accessToken"] ?? dictionary["access_token"])
        guard !accessToken.isEmpty else {
            return nil
        }

        let tokenType = normalizedText(dictionary["tokenType"] ?? dictionary["token_type"])
        let scope = normalizedText(dictionary["scope"])
        let receivedAtSeconds = numericValue(dictionary["receivedAt"])
        let expiresInSeconds = numericValue(dictionary["expiresIn"] ?? dictionary["expires_in"])

        let receivedAt = receivedAtSeconds.flatMap { Date(timeIntervalSince1970: TimeInterval($0)) }
        let expiresAt: Date? = {
            guard let receivedAt, let expiresInSeconds, expiresInSeconds > 0 else { return nil }
            return receivedAt.addingTimeInterval(TimeInterval(expiresInSeconds))
        }()
        let isExpired = expiresAt.map { $0 <= Date().addingTimeInterval(60) } ?? false

        return LinearOAuthSession(
            accessToken: accessToken,
            tokenType: tokenType.isEmpty ? "Bearer" : tokenType,
            scope: scope,
            receivedAt: receivedAt,
            expiresAt: expiresAt,
            isExpired: isExpired
        )
    }

    private static func normalizedText(_ value: Any?) -> String {
        guard let string = value as? String else { return "" }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    private static func numericValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String, let number = Int(string) {
            return number
        }
        return nil
    }
}

private struct LastFmOAuthSettingsView: View {
    private static let authorizeURLString = "https://api.supercmd.sh/auth/lastfm/authorize?app=nexusisland"
    private static let oauthStoreKey = "extensions.\(lastFmScrobblerExtensionID).store.oauth"

    @ObservedObject private var manager = ExtensionManager.shared
    @State private var session: LastFmOAuthSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                Text(statusTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                Spacer()
            }

            Text(statusMessage)
                .font(.system(size: 12))
                .foregroundColor(NexusPalette.textSecondary)

            HStack(spacing: 8) {
                Button(primaryButtonTitle) {
                    openAuthorizeURL()
                }
                .buttonStyle(.borderedProminent)
                .tint(SettingsGlass.toggleTint)

                if session != nil {
                    Button(NSLocalizedString("Disconnect", comment: "Button")) {
                        disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(NexusPalette.danger)
                }
            }

            if let session {
                VStack(alignment: .leading, spacing: 4) {
                    if !session.username.isEmpty {
                        Text("Account: \(session.username)")
                            .font(.system(size: 11))
                            .foregroundColor(NexusPalette.textSecondary)
                    }

                    if !session.scope.isEmpty {
                        Text("Scope: \(session.scope)")
                            .font(.system(size: 11))
                            .foregroundColor(NexusPalette.textSecondary)
                    }

                    if let expiresAt = session.expiresAt {
                        Text(expirationLabel(expiresAt: expiresAt, isExpired: session.isExpired))
                            .font(.system(size: 11))
                            .foregroundColor(session.isExpired ? NexusPalette.danger : NexusPalette.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            reloadSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reloadSession()
        }
    }

    private var statusTitle: String {
        if let session {
            return session.isExpired ? NSLocalizedString("Expired", comment: "Status label") : NSLocalizedString("Logged in", comment: "Status label")
        }
        return NSLocalizedString("Not logged in", comment: "Status label")
    }

    private var statusColor: Color {
        if let session {
            return session.isExpired ? NexusPalette.warning : NexusPalette.success
        }
        return NexusPalette.textTertiary
    }

    private var statusMessage: String {
        if let session {
            if session.isExpired {
                return NSLocalizedString("Your Last.fm session has expired. Authenticate again to resume scrobbling.", comment: "Settings description")
            }
            if !session.username.isEmpty {
                return "Last.fm is connected as \(session.username). New plays will scrobble automatically."
            }
            return NSLocalizedString("Last.fm is connected. New plays will scrobble automatically.", comment: "Settings description")
        }
        return NSLocalizedString("Authenticate with Last.fm to start scrobbling your listening history.", comment: "Settings description")
    }

    private var primaryButtonTitle: String {
        if let session {
            return session.isExpired ? NSLocalizedString("Log In Again", comment: "Button") : NSLocalizedString("Reconnect", comment: "Button")
        }
        return NSLocalizedString("Log In to Last.fm", comment: "Button")
    }

    private func reloadSession() {
        session = LastFmOAuthSession.load()
    }

    private func openAuthorizeURL() {
        guard let url = URL(string: Self.authorizeURLString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func disconnect() {
        UserDefaults.standard.removeObject(forKey: Self.oauthStoreKey)
        // SECURITY: also purge the Keychain entry so the secret is fully gone,
        // not just the metadata mirror in UserDefaults.
        KeychainStore.delete(account: lastFmScrobblerExtensionID, service: "nexus.oauth")

        if manager.runtimes[lastFmScrobblerExtensionID] == nil {
            manager.activate(extensionID: lastFmScrobblerExtensionID)
        }
        manager.scheduleImmediateRefresh(extensionID: lastFmScrobblerExtensionID)
        reloadSession()
    }

    private func expirationLabel(expiresAt: Date, isExpired: Bool) -> String {
        let formatted = expiresAt.formatted(date: .abbreviated, time: .shortened)
        return isExpired ? "Expired at \(formatted)" : "Expires at \(formatted)"
    }
}

private struct LastFmOAuthSession {
    private static let oauthStoreKey = "extensions.\(lastFmScrobblerExtensionID).store.oauth"

    let accessToken: String
    let tokenType: String
    let scope: String
    let username: String
    let receivedAt: Date?
    let expiresAt: Date?
    let isExpired: Bool

    static func load(defaults: UserDefaults = .standard) -> LastFmOAuthSession? {
        guard let dictionary = defaults.dictionary(forKey: oauthStoreKey) else {
            return nil
        }

        let accessToken = normalizedText(dictionary["accessToken"] ?? dictionary["access_token"])
        guard !accessToken.isEmpty else {
            return nil
        }

        let tokenType = normalizedText(dictionary["tokenType"] ?? dictionary["token_type"])
        let scope = normalizedText(dictionary["scope"])
        let username = normalizedText(dictionary["username"] ?? dictionary["name"])
        let receivedAtSeconds = numericValue(dictionary["receivedAt"])
        let expiresInSeconds = numericValue(dictionary["expiresIn"] ?? dictionary["expires_in"])

        let receivedAt = receivedAtSeconds.flatMap { Date(timeIntervalSince1970: TimeInterval($0)) }
        let expiresAt: Date? = {
            guard let receivedAt, let expiresInSeconds, expiresInSeconds > 0 else { return nil }
            return receivedAt.addingTimeInterval(TimeInterval(expiresInSeconds))
        }()
        let isExpired = expiresAt.map { $0 <= Date().addingTimeInterval(60) } ?? false

        return LastFmOAuthSession(
            accessToken: accessToken,
            tokenType: tokenType.isEmpty ? "Bearer" : tokenType,
            scope: scope,
            username: username,
            receivedAt: receivedAt,
            expiresAt: expiresAt,
            isExpired: isExpired
        )
    }

    private static func normalizedText(_ value: Any?) -> String {
        guard let string = value as? String else { return "" }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    private static func numericValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String, let number = Int(string) {
            return number
        }
        return nil
    }
}

private struct WhatsAppWebBridgeSettingsView: View {
    @ObservedObject private var bridge = WhatsAppWebBridge.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 9, height: 9)
                Text(stateTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                Spacer()
            }

            Text(bridge.statusText)
                .font(.system(size: 12))
                .foregroundColor(NexusPalette.textSecondary)

            HStack(spacing: 8) {
                if bridge.connectionState == .loggedIn {
                    Button(NSLocalizedString("Log Out", comment: "Button")) {
                        bridge.logout()
                    }
                    .buttonStyle(.bordered)
                    .tint(NexusPalette.danger)
                } else {
                    Button(NSLocalizedString("Start Login", comment: "Button")) {
                        bridge.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SettingsGlass.toggleTint)

                    Button(NSLocalizedString("Refresh QR", comment: "Button")) {
                        bridge.refreshQRCode()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if bridge.connectionState == .loggedIn {
                Text(NSLocalizedString("Connected. New messages will be synced from this login.", comment: "Settings description"))
                    .font(.system(size: 11))
                    .foregroundColor(NexusPalette.textSecondary)
            } else if let image = qrImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Scan this QR with WhatsApp on your phone", comment: "Settings label"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(NexusPalette.textSecondary)

                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(NSLocalizedString("Preparing secure login session...", comment: "Settings description"))
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                }
            }

            if let error = bridge.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(NexusPalette.danger)
            }
        }
        .onAppear {
            bridge.start()
        }
    }

    private var stateTitle: String {
        switch bridge.connectionState {
        case .idle:
            return NSLocalizedString("Idle", comment: "Status label")
        case .loading:
            return NSLocalizedString("Loading", comment: "Status label")
        case .qrReady:
            return NSLocalizedString("QR Ready", comment: "Status label")
        case .loggedIn:
            return NSLocalizedString("Connected", comment: "Status label")
        case .error:
            return NSLocalizedString("Error", comment: "Status label")
        }
    }

    private var stateColor: Color {
        switch bridge.connectionState {
        case .idle:
            return NexusPalette.textTertiary
        case .loading:
            return NexusPalette.warning
        case .qrReady:
            return NexusPalette.electricViolet
        case .loggedIn:
            return NexusPalette.success
        case .error:
            return NexusPalette.danger
        }
    }

    private var qrImage: NSImage? {
        guard let dataURL = bridge.qrCodeDataURL else { return nil }
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let encoded = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return NSImage(data: data)
    }
}
