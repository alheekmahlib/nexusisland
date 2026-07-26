import SwiftUI
import AppKit

// MARK: - IslandDisplaySettingsView
//
// Single flat, drag-to-reorder list of every island module (built-ins +
// installed extensions). Each row carries a drag handle (≡), an icon
// medallion, the module name, and a per-row toggle — on = shown in the island,
// off = hidden but retained in its slot.
//
// Ordering is persisted to `AppState.moduleOrder` and drives module cycling
// and the full-expanded tab strip. Built on the shared Settings glass kit so
// it reads as part of the same window.

struct IslandDisplaySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var extensionManager = ExtensionManager.shared

    /// Local source of truth, mirrored from `appState.moduleDisplayOrder` so
    /// `List.onMove` can mutate it optimistically before writing back.
    @State private var orderedModules: [ActiveModule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            SettingSectionLabel(title: NSLocalizedString("DISPLAY ORDER", comment: "Island display settings section"))

            SettingGroup {
                reorderableList
                    .frame(minHeight: 320)
            }

            footerHint
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { syncFromAppState() }
        .onChange(of: extensionManager.installed.count) { _ in syncFromAppState() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Island Display", comment: "Island display settings title"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(NexusPalette.textPrimary)
            Text(NSLocalizedString(
                "Drag to reorder. The first enabled module shows first when cycling the island.",
                comment: "Island display settings subtitle"
            ))
            .font(.system(size: 12))
            .foregroundColor(NexusPalette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `List` + `.onMove` gives us native macOS drag-to-reorder for free,
    /// including the open-hand cursor and lift preview. The list is rendered
    /// transparently so the parent glass card stays the visible surface.
    private var reorderableList: some View {
        List {
            ForEach(orderedModules, id: \.self) { module in
                IslandModuleRow(
                    module: module,
                    index: (orderedModules.firstIndex(of: module) ?? 0) + 1,
                    isActive: appState.isActiveModule(module),
                    onToggle: { handleToggle(module, isOn: $0) }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 44)
    }

    private var footerHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(NexusPalette.textTertiary)
            Text(NSLocalizedString(
                "Disabled modules stay in place but won’t appear in the island.",
                comment: "Island display settings hint"
            ))
            .font(.system(size: 11))
            .foregroundColor(NexusPalette.textTertiary)
        }
        .padding(.top, 2)
    }

    // MARK: - Actions

    private func syncFromAppState() {
        orderedModules = appState.moduleDisplayOrder
    }

    private func handleToggle(_ module: ActiveModule, isOn: Bool) {
        switch module {
        case .builtIn(let builtIn):
            setBuiltInEnabled(builtIn, isOn: isOn)
        case .extension_(let id):
            if isOn {
                extensionManager.activate(extensionID: id)
            } else {
                extensionManager.disableByUser(extensionID: id)
            }
        }
    }

    /// Standard `onMove` callback. Updates the local snapshot, then writes
    /// the new order back through `AppState` so the island follows suit.
    private func move(from source: IndexSet, to destination: Int) {
        orderedModules.move(fromOffsets: source, toOffset: destination)
        appState.moduleOrder = orderedModules.map { identifier(for: $0) }
    }

    private func identifier(for module: ActiveModule) -> String {
        switch module {
        case .builtIn(let builtIn): return builtIn.rawValue
        case .extension_(let id): return id
        }
    }

    private func setBuiltInEnabled(_ builtIn: ModuleType, isOn: Bool) {
        switch builtIn {
        case .nowPlaying:     appState.nowPlayingEnabled = isOn
        case .volumeHUD:      appState.volumeHUDEnabled = isOn
        case .battery:        appState.batteryEnabled = isOn
        case .shelf:          appState.shelfEnabled = isOn
        case .connectivity:   appState.connectivityEnabled = isOn
        case .calendar:       appState.calendarEnabled = isOn
        case .weather:        appState.weatherEnabled = isOn
        case .notifications:  appState.notificationsEnabled = isOn
        case .teleprompter:
            appState.teleprompterEnabled = isOn
            if isOn { PermissionsManager.shared.requestTeleprompterWordTrackingAccess() }
        case .quran:          appState.quranEnabled = isOn
        case .prayerTimes:
            appState.prayerTimesEnabled = isOn
            if isOn {
                _ = PrayerTimesManager.shared
                PrayerTimesManager.shared.settingsDidChange()
            }
        case .gitHub:         appState.gitHubEnabled = isOn
        case .ciMonitor:      appState.ciMonitorEnabled = isOn
        case .devServers:     appState.devServersEnabled = isOn
        case .gitStats:       appState.gitStatsEnabled = isOn
        case .docker:         appState.dockerEnabled = isOn
        case .worldClock:     appState.worldClockEnabled = isOn
        case .currency:       appState.currencyEnabled = isOn
        case .countdown:      appState.countdownEnabled = isOn
        case .stocks:         appState.stocksEnabled = isOn
        case .reminders:      appState.remindersEnabled = isOn
        case .clipboard:
            appState.clipboardEnabled = isOn
            if isOn { ClipboardManager.shared.startMonitoring() } else { ClipboardManager.shared.stopMonitoring() }
        }
    }
}

// MARK: - IslandModuleRow

private struct IslandModuleRow: View {
    let module: ActiveModule
    let index: Int
    let isActive: Bool
    let onToggle: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            dragHandle

            medallion

            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                Text("#\(index)")
                    .font(NexusTypography.mono)
                    .foregroundColor(NexusPalette.textTertiary)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: Binding(get: { isActive }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(SettingsGlass.toggleTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? AnyShapeStyle(NexusPalette.royalPurple.opacity(0.12)) : AnyShapeStyle(Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    // MARK: - Pieces

    /// Explicit grab handle. On macOS, dragging any part of a List row that
    /// is part of an `.onMove` will start a reorder; the handle acts as the
    /// discoverable affordance and intensifies on hover to invite the gesture.
    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isHovering ? NexusPalette.electricViolet : NexusPalette.textTertiary)
            .frame(width: 16)
            .opacity(isHovering ? 1.0 : 0.55)
            .help(NSLocalizedString("Drag to reorder", comment: "Island row help"))
    }

    @ViewBuilder
    private var medallion: some View {
        if let nsImage = module.iconImage {
            // Extensions ship their own icon art.
            ZStack {
                Circle()
                    .fill(NexusGradient.primary)
                    .frame(width: 28, height: 28)
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            }
        } else {
            GradientMedallion(
                systemName: module.iconName,
                size: 28,
                iconScale: 0.46,
                gradient: NexusGradient.primary,
                isActive: isActive
            )
        }
    }
}
