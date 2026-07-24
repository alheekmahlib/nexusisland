import AppKit
import SwiftUI

private struct MascotGridPicker: View {
    @ObservedObject private var manager = MascotManager.shared
    @State private var downloadingSlug: String?

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(manager.availableMascots) { entry in
                mascotCell(entry)
            }
        }
    }

    private func mascotCell(_ entry: MascotCatalogEntry) -> some View {
        let isSelected = manager.selectedSlug == entry.slug
        let isDownloaded = manager.isMascotDownloaded(entry.slug)
        let isDownloading = downloadingSlug == entry.slug

        return Button {
            guard !isDownloading else { return }
            if isDownloaded {
                manager.selectMascot(entry.slug)
            } else {
                downloadingSlug = entry.slug
                Task {
                    let didDownload = await manager.downloadMascot(entry.slug)
                    downloadingSlug = nil
                    if didDownload {
                        manager.selectMascot(entry.slug)
                    }
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                        .frame(height: 80)

                    AsyncImage(url: URL(string: entry.thumbnailURL)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().controlSize(.small)
                    }
                    .frame(width: 60, height: 60)

                    if !isDownloaded {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                if isDownloading {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .padding(4)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.accentColor)
                                        .padding(4)
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                }

                Text(entry.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                .frame(height: 80)
                .offset(y: -10)
        )
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var mascotManager = MascotManager.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var permissionStates: [PermissionType: Bool] = [:]
    private static let permissionRefreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Language
            SettingSectionLabel(title: NSLocalizedString("Language", comment: "Settings section"))
            SettingGroup {
                HStack {
                    Text(NSLocalizedString("App language", comment: "Settings label")).font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { appState.languageOverride },
                        set: { appState.languageOverride = $0 }
                    )) {
                        Text(NSLocalizedString("System", comment: "Picker option")).tag("system")
                        Text(NSLocalizedString("English", comment: "Picker option")).tag("en")
                        Text("العربية").tag("ar")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 140)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                SettingRowDivider()
                HStack {
                    Text(NSLocalizedString("Restart required to apply", comment: "Settings description")).font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            // Startup
            SettingSectionLabel(title: NSLocalizedString("Startup", comment: "Settings section"))
            SettingGroup {
                HStack {
                    Text(NSLocalizedString("Launch at login", comment: "Settings label")).font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            newValue ? LaunchAtLogin.enable() : LaunchAtLogin.disable()
                        }
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Show menu bar icon", comment: "Settings label"), isOn: $appState.showMenuBarIcon)
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Show in screen recordings", comment: "Settings label"), isOn: $appState.showInScreenRecordings)
            }

            // Display
            SettingSectionLabel(title: NSLocalizedString("Display", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Show on all Spaces", comment: "Settings label"), isOn: $appState.showOnAllSpaces)
                if appState.presentationHasNotch {
                    SettingRowDivider()
                    SettingToggleRow(title: NSLocalizedString("Hide side slots", comment: "Settings label"), isOn: $appState.hideSideSlots)
                }
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Hide on fullscreen", comment: "Settings label"), isOn: $appState.hideOnFullscreen)
                SettingRowDivider()
                HStack {
                    Text(NSLocalizedString("Animation Speed", comment: "Settings label")).font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $appState.animationSpeed) {
                        Text(NSLocalizedString("Normal", comment: "Picker option")).tag(1.0)
                        Text(NSLocalizedString("Reduced", comment: "Picker option")).tag(1.5)
                        Text(NSLocalizedString("Minimal", comment: "Picker option")).tag(2.0)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
            }

            // Power
            SettingSectionLabel(title: NSLocalizedString("Power", comment: "Settings section"))
            SettingGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Power mode", comment: "Settings label")).font(.system(size: 13))
                        Text(appState.energyMode.description)
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    Picker("", selection: energyModeBinding) {
                        ForEach(EnergyMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 132)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                SettingRowDivider()
                SettingToggleRow(
                    title: NSLocalizedString("Reduce animations", comment: "Settings label"),
                    description: NSLocalizedString("Use simpler motion for island transitions and visual effects.", comment: "Settings description"),
                    isOn: $appState.reduceAnimations
                )

                SettingRowDivider()
                SettingToggleRow(
                    title: NSLocalizedString("Pause background extension refresh", comment: "Settings label"),
                    description: NSLocalizedString("Keep inactive extensions quiet until they are visible or selected.", comment: "Settings description"),
                    isOn: $appState.disableBackgroundExtensionRefresh
                )

                SettingRowDivider()
                SettingToggleRow(
                    title: NSLocalizedString("Low Power suggestions", comment: "Settings label"),
                    description: NSLocalizedString("Offer Low Power mode when the Mac switches to battery or refresh work stays busy.", comment: "Settings description"),
                    isOn: lowPowerSuggestionBinding
                )
            }
            .onChange(of: appState.reduceAnimations) { _, _ in appState.refreshEnergyState() }
            .onChange(of: appState.disableBackgroundExtensionRefresh) { _, _ in appState.refreshEnergyState() }

            // Behavior
            SettingSectionLabel(title: NSLocalizedString("Behavior", comment: "Settings section"))
            SettingGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Expanded collapse delay", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("How long expanded content stays visible", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    StepperField(
                        value: $appState.expandedAutoDismissDelay,
                        step: 0.5,
                        range: 0.1...10.0
                    ) { "\(String(format: "%.1f", $0))s" }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                SettingRowDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Hover expand delay", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("How long to hover the notch before it peeks open", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    StepperField(
                        value: $appState.hoverExpandDelay,
                        step: 0.05,
                        range: 0.0...1.5
                    ) { "\(String(format: "%.2f", $0))s" }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }

            // Interaction
            SettingSectionLabel(title: NSLocalizedString("Interaction", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Island surface swipes", comment: "Settings label"), isOn: $appState.islandSurfaceSwipeEnabled)
                SettingRowDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Notch haptic intensity", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("Feedback strength when entering the notch", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    Picker("", selection: $appState.notchHapticIntensity) {
                        ForEach(NotchHapticIntensity.allCases) { intensity in
                            Text(intensity.title).tag(intensity.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                SettingRowDivider()
                SettingToggleRow(
                    title: NSLocalizedString("Allow Command+Q to quit", comment: "Settings label"),
                    description: NSLocalizedString("Turn this off to prevent accidental quits while interacting with the notch.", comment: "Settings description"),
                    isOn: $appState.allowQuitHotkey
                )
            }

            // Permissions
            SettingSectionLabel(title: NSLocalizedString("Permissions", comment: "Settings section"))
            SettingGroup {
                permissionRow(.accessibility,
                    title: NSLocalizedString("Accessibility", comment: "Settings label"), icon: "figure.stand",
                    description: NSLocalizedString("Gesture detection and system events", comment: "Settings description"))
                SettingRowDivider()
                permissionRow(.calendar,
                    title: NSLocalizedString("Calendar", comment: "Settings label"), icon: "calendar",
                    description: NSLocalizedString("Show upcoming events in the island", comment: "Settings description"))
                SettingRowDivider()
                permissionRow(.location,
                    title: NSLocalizedString("Location", comment: "Settings label"), icon: "location.fill",
                    description: NSLocalizedString("Weather information for your location", comment: "Settings description"))
                SettingRowDivider()
                permissionRow(.bluetooth,
                    title: NSLocalizedString("Bluetooth", comment: "Settings label"), icon: "wave.3.right.circle.fill",
                    description: NSLocalizedString("Connected device notifications", comment: "Settings description"))
            }

            // Mascot
            SettingSectionLabel(title: NSLocalizedString("Mascot", comment: "Settings section"))
            SettingGroup {
                MascotGridPicker()
                    .padding(14)

                if let loadError = mascotManager.loadError {
                    SettingRowDivider()
                    Text(loadError)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Show mascot in Pomodoro", comment: "Settings label"), isOn: $mascotManager.showInPomodoro)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { refreshPermissionStates() }
        .onReceive(Self.permissionRefreshTimer) { _ in refreshPermissionStates() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStates()
        }
    }

    @ViewBuilder
    private func permissionRow(
        _ permission: PermissionType,
        title: String, icon: String, description: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(permissionGranted(permission) ? .green : .secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(description).font(.system(size: 11)).foregroundColor(.secondary)
            }

            Spacer()

            if permissionGranted(permission) {
                Label(NSLocalizedString("Granted", comment: "Status label"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            } else {
                Button(NSLocalizedString("Grant Access", comment: "Button")) { requestPermission(permission) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func permissionGranted(_ permission: PermissionType) -> Bool {
        permissionStates[permission] ?? false
    }

    private var energyModeBinding: Binding<EnergyMode> {
        Binding(
            get: { appState.energyMode },
            set: { appState.energyMode = $0 }
        )
    }

    private var lowPowerSuggestionBinding: Binding<Bool> {
        Binding(
            get: { !appState.lowPowerSuggestionDoNotAskAgain },
            set: { appState.lowPowerSuggestionDoNotAskAgain = !$0 }
        )
    }

    private func refreshPermissionStates() {
        permissionStates[.accessibility] = PermissionsManager.shared.checkAccessibility()
        permissionStates[.calendar] = PermissionsManager.shared.checkCalendar()
        permissionStates[.location] = PermissionsManager.shared.checkLocation()
        permissionStates[.bluetooth] = PermissionsManager.shared.checkBluetooth()
    }

    private func requestPermission(_ permission: PermissionType) {
        PermissionsManager.shared.request(permission)
        refreshPermissionStates()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            refreshPermissionStates()
            try? await Task.sleep(nanoseconds: 900_000_000)
            refreshPermissionStates()
        }
    }
}
