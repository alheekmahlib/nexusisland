import SwiftUI
import AppKit

// MARK: - IslandDisplaySettingsView
//
// Drag-to-reorder list of every island module (built-ins + installed
// extensions). Each row carries a custom grab handle, an icon medallion
// that dims when the module is hidden, the module name + a small type
// label (Built-in / Extension), and a per-row toggle — on = shown in the
// island, off = hidden but retained in its slot.
//
// A control bar above the list summarises how many modules are visible,
// offers instant Show/Hide-all actions, and a filter field that switches
// the list into browse-only mode (reorder is paused while filtering so the
// user never drags a filtered subset into a misleading position).
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

    /// Filter query for the search field. When non-empty the list switches
    /// to browse-only mode (no `.onMove`) so reordering can't collide with a
    /// filtered subset.
    @State private var searchText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controlBar

            SettingSectionLabel(title: NSLocalizedString(
                "Display Order", comment: "Island display settings section"
            ))

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

    // MARK: - Control bar
    //
    // A single inline toolbar: visible-count chip on the leading edge, a
    // filter field + bulk Show/Hide actions on the trailing edge. Kept inside
    // its own subtle surface so it reads as a distinct control layer above
    // the list card.

    private var controlBar: some View {
        HStack(spacing: 12) {
            enabledCountChip

            Spacer(minLength: 12)

            searchField

            bulkActionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: NexusMetrics.cornerRadiusS, style: .continuous)
                .fill(NexusPalette.background.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NexusMetrics.cornerRadiusS, style: .continuous)
                .strokeBorder(SettingsGlass.divider, lineWidth: NexusMetrics.strokeHairline)
        )
    }

    /// "8 of 22 shown" — surfaces the enabled/total ratio at a glance so the
    /// user always knows how many modules will actually cycle on the island.
    private var enabledCountChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(NexusPalette.electricViolet)
            Text("\(enabledCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(NexusPalette.electricViolet)
                .monospacedDigit()
            Text(NSLocalizedString(
                "of", comment: "Island display count separator, e.g. '8 of 22 shown'"
            ))
            .font(.system(size: 11))
            .foregroundColor(NexusPalette.textTertiary)
            Text("\(orderedModules.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(NexusPalette.textSecondary)
                .monospacedDigit()
            Text(NSLocalizedString(
                "shown", comment: "Island display count suffix, e.g. '8 of 22 shown'"
            ))
            .font(.system(size: 11))
            .foregroundColor(NexusPalette.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NexusPalette.royalPurple.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(NexusPalette.electricViolet.opacity(0.22), lineWidth: 0.5)
        )
    }

    /// Plain-text filter field in the glass style. The trailing clear button
    /// only appears once there's input, so the field stays uncluttered at rest.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(NexusPalette.textTertiary)
            TextField(
                NSLocalizedString("Filter modules…", comment: "Island display search placeholder"),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(NexusPalette.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(NexusPalette.textTertiary)
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Clear filter", comment: "Island display search clear"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NexusPalette.background.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(SettingsGlass.divider, lineWidth: 0.5)
        )
        .frame(maxWidth: 200)
    }

    /// Bulk Show/Hide affordances. Hidden when a filter is active so the
    /// action always applies to the full set, never a filtered subset.
    @ViewBuilder
    private var bulkActionButtons: some View {
        if searchText.isEmpty {
            HStack(spacing: 6) {
                Button(NSLocalizedString("Show All", comment: "Island display bulk action")) {
                    setAllEnabled(true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(enabledCount == orderedModules.count)

                Button(NSLocalizedString("Hide All", comment: "Island display bulk action")) {
                    setAllEnabled(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(enabledCount == 0)
            }
        }
    }

    // MARK: - List
    //
    // `List` + `.onMove` gives us native macOS drag-to-reorder for free,
    // including the open-hand cursor and lift preview. The list is rendered
    // transparently so the parent glass card stays the visible surface.
    //
    // While a search query is active the list renders a filtered snapshot
    // WITHOUT `.onMove` — browse-only — so reordering never silently drops a
    // row into a position the user can't see.

    private var reorderableList: some View {
        List {
            if isSearching {
                ForEach(filteredModules, id: \.self) { module in
                    row(for: module, orderIndex: nil)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(Array(orderedModules.enumerated()), id: \.element) { index, module in
                    row(for: module, orderIndex: index + 1)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: move)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 48)
    }

    private var footerHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(NexusPalette.textTertiary)
            Text(NSLocalizedString(
                "Drag to reorder. Toggle a module off to hide it without removing its slot.",
                comment: "Island display settings hint"
            ))
            .font(.system(size: 11))
            .foregroundColor(NexusPalette.textTertiary)
        }
        .padding(.top, 2)
    }

    // MARK: - Row factory

    @ViewBuilder
    private func row(for module: ActiveModule, orderIndex: Int?) -> some View {
        IslandModuleRow(
            module: module,
            orderIndex: orderIndex,
            isActive: appState.isActiveModule(module),
            onToggle: { handleToggle(module, isOn: $0) }
        )
    }

    // MARK: - Derived state

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Filtered view of `orderedModules` matching the current search query.
    /// `@MainActor` because `displayName` is main-actor-isolated; the body
    /// that consumes this property already runs on the main actor.
    @MainActor
    private var filteredModules: [ActiveModule] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return orderedModules }
        return orderedModules.filter { module in
            if module.displayName.lowercased().contains(query) { return true }
            switch module {
            case .builtIn:  return NSLocalizedString("Built-in", comment: "Module type label").lowercased().contains(query)
            case .extension_: return NSLocalizedString("Extension", comment: "Module type label").lowercased().contains(query)
            }
        }
    }

    private var enabledCount: Int {
        orderedModules.filter { appState.isActiveModule($0) }.count
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

    /// Toggle every module on/off in one pass. Used by the Show All / Hide
    /// All buttons. Runs the same per-module path as a single toggle so
    /// permissions and side effects fire exactly once per module.
    private func setAllEnabled(_ isOn: Bool) {
        for module in orderedModules {
            handleToggle(module, isOn: isOn)
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
        case .worldClock:
            appState.worldClockEnabled = isOn
            if isOn { WorldClockManager.shared.startTicking() } else { WorldClockManager.shared.stopTicking() }
        case .currency:       appState.currencyEnabled = isOn
        case .countdown:
            appState.countdownEnabled = isOn
            if isOn { CountdownManager.shared.startTicking() } else { CountdownManager.shared.stopTicking() }
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
    /// 1-based position within the full (unfiltered) order. `nil` while a
    /// search filter is active, since a filtered index would be misleading.
    let orderIndex: Int?
    let isActive: Bool
    let onToggle: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            dragHandle

            medallion

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(module.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(NexusPalette.textPrimary)
                    typeLabel
                }
                typeDescription
            }

            Spacer(minLength: 12)

            Toggle("", isOn: Binding(get: { isActive }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(SettingsGlass.toggleTint)
                .help(isActive
                      ? NSLocalizedString("Hide from island", comment: "Island row help")
                      : NSLocalizedString("Show on island", comment: "Island row help"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowFill)
        )
        .overlay(
            // Subtle left accent that only shows when active + hovered —
            // reinforces "this row is live and draggable" without competing
            // with the medallion at rest.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isHovering && isActive
                            ? [NexusPalette.electricViolet.opacity(0.35), .clear]
                            : [.clear, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.5
                )
        )
        .opacity(isActive ? 1.0 : 0.78)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private var rowFill: AnyShapeStyle {
        if isHovering && isActive {
            return AnyShapeStyle(NexusPalette.royalPurple.opacity(0.14))
        } else if isHovering {
            return AnyShapeStyle(NexusPalette.glassTint.opacity(0.06))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    // MARK: - Pieces

    /// Custom 6-dot grab handle (2 columns × 3 rows). Reads as the universal
    /// "drag" affordance used by Notion/Linear, and is more precise than an
    /// SF Symbol at this size. Intensifies on hover to invite the gesture.
    private var dragHandle: some View {
        IslandDragHandle()
            .foregroundStyle(isHovering ? NexusPalette.electricViolet : NexusPalette.textTertiary)
            .opacity(isHovering ? 1.0 : 0.55)
            .frame(width: 12, height: 16)
            .help(NSLocalizedString("Drag to reorder", comment: "Island row help"))
            // Hide the handle entirely while filtering — reorder is disabled
            // in browse mode, so showing the affordance would lie.
            .opacity(isSearchingContext ? 0 : 1)
    }

    /// `true` when this row is being rendered inside a filtered (browse-only)
    /// list, i.e. `orderIndex` is `nil`. Drives the drag-handle visibility.
    private var isSearchingContext: Bool { orderIndex == nil }

    @ViewBuilder
    private var medallion: some View {
        IslandModuleMedallion(
            iconName: module.iconName,
            iconImage: module.iconImage,
            size: 32,
            isActive: isActive
        )
        // Dim when hidden so the row's state is legible at a glance, even
        // before reading the toggle.
        .opacity(isActive ? 1.0 : 0.6)
    }

    /// Small uppercase type chip — Built-in vs Extension — so users can tell
    /// at a glance which rows come from the app and which from add-ons.
    @ViewBuilder
    private var typeLabel: some View {
        let kind = moduleKind
        Text(kind.label)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.3)
            .textCase(.uppercase)
            .foregroundColor(kind.color.opacity(0.9))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(kind.color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(kind.color.opacity(0.25), lineWidth: 0.5)
            )
    }

    /// Optional one-line context under the title. Shows the position number
    /// (e.g. "#3") when available — meaningful for the cycling order.
    @ViewBuilder
    private var typeDescription: some View {
        if let orderIndex {
            Text(String(format: NSLocalizedString(
                "#%d in cycle order", comment: "Island row position hint"
            ), orderIndex))
                .font(NexusTypography.mono)
                .foregroundColor(NexusPalette.textTertiary)
        }
    }

    private var moduleKind: ModuleKind {
        switch module {
        case .builtIn:     return .builtIn
        case .extension_:  return .extension_
        }
    }
}

private enum ModuleKind {
    case builtIn, extension_

    var label: String {
        switch self {
        case .builtIn:    return NSLocalizedString("Built-in", comment: "Module type label")
        case .extension_: return NSLocalizedString("Extension", comment: "Module type label")
        }
    }

    var color: Color {
        switch self {
        case .builtIn:    return NexusPalette.electricViolet
        case .extension_: return NexusPalette.neonPink
        }
    }
}

// MARK: - IslandModuleMedallion
//
// A local, minimal icon badge for the Island Display list — deliberately
// different from the shared `GradientMedallion` (which carries a saturated
// gradient + outer glow and is used in the live island). Here we want a calm,
// flat, list-friendly token: a translucent fill with a thin violet hairline
// border and NO shadow, so rows read as a quiet inventory rather than a row
// of glowing chips competing for attention.

private struct IslandModuleMedallion: View {
    var iconName: String
    var iconImage: NSImage?
    var size: CGFloat = 32
    var isActive: Bool = false

    var body: some View {
        ZStack {
            // Translucent violet wash — barely-there tint so the circle is
            // defined by its border, not its fill.
            Circle()
                .fill(NexusPalette.royalPurple.opacity(0.14))
                .frame(width: size, height: size)
            // Thin violet hairline — the defining edge. Brightens slightly
            // when the module is active to reinforce state.
            Circle()
                .strokeBorder(
                    NexusPalette.electricViolet.opacity(isActive ? 0.55 : 0.35),
                    lineWidth: 1
                )
                .frame(width: size, height: size)
            // Glyph: white icon for built-ins, or the extension's own art.
            icon
        }
        // Fixed frame so the circle never stretches with row height.
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var icon: some View {
        if let iconImage {
            Image(nsImage: iconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size * 0.58, height: size * 0.58)
        } else {
            Image(systemName: iconName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundColor(NexusPalette.textPrimary)
        }
    }
}

// MARK: - IslandDragHandle
//
// A compact 6-dot grip rendered as a 2×3 dot grid. Drawn manually instead of
// using an SF Symbol so it stays crisp and consistent at small sizes and
// matches the universal "drag handle" affordance found in modern apps.

private struct IslandDragHandle: View {
    var body: some View {
        VStack(spacing: 3.5) {
            dotRow
            dotRow
            dotRow
        }
    }

    private var dotRow: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .frame(width: 2.8, height: 2.8)
            }
        }
    }
}
