import AppKit
import SwiftUI

struct AdvancedSettingsView: View {
    @State private var showResetAlert = false
    @State private var screenOptions: [ScreenDetector.ScreenOption] = ScreenDetector.availableScreenOptions()
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var scheduler = ModuleRefreshScheduler.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Display ────────────────────────────────────────────────────
            SettingSectionLabel(title: NSLocalizedString("Display", comment: "Settings section"))
            SettingGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Show island on", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("Pick a specific display or let NexusIsland choose", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 8)
                    Picker("", selection: $appState.displayIdentifier) {
                        ForEach(screenOptions) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
            .onAppear { refreshScreenOptions() }
            .onReceive(NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification
            )) { _ in refreshScreenOptions() }

            SettingSectionLabel(title: NSLocalizedString("Energy Diagnostics", comment: "Settings section"))
            SettingGroup {
                if scheduler.diagnostics.isEmpty {
                    Text(NSLocalizedString("No scheduled refresh jobs", comment: "Settings description"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    ForEach(Array(scheduler.diagnostics.enumerated()), id: \.element.id) { index, job in
                        diagnosticRow(job)
                        if index < scheduler.diagnostics.count - 1 {
                            SettingRowDivider()
                        }
                    }
                }
            }

            SettingSectionLabel(title: NSLocalizedString("Debug", comment: "Settings section"))
            SettingGroup {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Reset All Settings", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("Restore all settings to their defaults", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(NSLocalizedString("Reset", comment: "Button")) {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .alert(NSLocalizedString("Reset Settings", comment: "Alert title"), isPresented: $showResetAlert) {
                        Button(NSLocalizedString("Cancel", comment: "Button"), role: .cancel) {}
                        Button(NSLocalizedString("Reset & Restart", comment: "Button"), role: .destructive) { resetAllSettings() }
                    } message: {
                        Text(NSLocalizedString("This will reset all NexusIsland settings to their defaults and restart the app. @AppStorage values are cached for the session, so a restart is required for the reset to take full effect.", comment: "Alert message"))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }

            SettingSectionLabel(title: NSLocalizedString("About", comment: "Settings section"))
            SettingGroup {
                HStack {
                    Text(NSLocalizedString("Version", comment: "Settings label")).font(.system(size: 13))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                SettingRowDivider()

                HStack {
                    Text(NSLocalizedString("Build", comment: "Settings label")).font(.system(size: 13))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                SettingRowDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Updates", comment: "Settings label")).font(.system(size: 13))
                        updateStatusText
                    }
                    Spacer()
                    updateButton
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var updateStatusText: some View {
        switch updateChecker.checkState {
        case .idle:
            EmptyView()
        case .checking:
            Text(NSLocalizedString("Checking...", comment: "Settings label")).font(.system(size: 11)).foregroundColor(.secondary)
        case .upToDate:
            Text(NSLocalizedString("You're up to date", comment: "Settings label")).font(.system(size: 11)).foregroundColor(.green)
        case .updateAvailable(let version, _, _):
            Text("Version \(version) available").font(.system(size: 11)).foregroundColor(.orange)
        case .failed(let message):
            Text(message).font(.system(size: 11)).foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var updateButton: some View {
        switch updateChecker.checkState {
        case .checking:
            ProgressView().controlSize(.small)
        case .updateAvailable(_, let releaseURL, let downloadURL):
            Button(NSLocalizedString("Update", comment: "Button")) {
                if let downloadURL {
                    AutoUpdater.shared.start(downloadURL: downloadURL, releaseURL: releaseURL)
                } else {
                    NSWorkspace.shared.open(releaseURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        default:
            Button(NSLocalizedString("Check for Updates", comment: "Button")) { updateChecker.checkNow() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    /// Performs the actual wipe. We do NOT call a hypothetical
    /// `AppState.resetToDefaults()` because `@AppStorage` caches its values
    /// in property storage on first access and will keep showing the stale
    /// pre-reset values for the rest of the session. The honest UX is to
    /// wipe UserDefaults and ask the user to restart, so `@AppStorage`
    /// re-reads from a clean plist on the next launch.
    private func resetAllSettings() {
        let domain = Bundle.main.bundleIdentifier ?? "com.vexaltech.NexusIsland"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        // Relaunch so @AppStorage re-hydrates from the now-empty defaults.
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        NSApp.terminate(nil)
    }

    private func diagnosticRow(_ job: EnergyDiagnosticsSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(job.name)
                    .font(.system(size: 13))
                Text("\(job.moduleName) · \(job.policy)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                if let lastError = job.lastError {
                    Text(lastError)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(job.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(job.status == "Scheduled" ? .green : .secondary)
                if let duration = job.lastRunDuration {
                    Text("\(String(format: "%.0f", duration * 1000)) ms")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                if let nextFireDate = job.nextFireDate {
                    Text("Next \(nextFireDate, style: .relative)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func refreshScreenOptions() {
        screenOptions = ScreenDetector.availableScreenOptions()
        // If the stored display identifier no longer matches a connected
        // screen (e.g. the user unplugged it), fall back to Automatic.
        let currentID = appState.displayIdentifier
        if !currentID.isEmpty, !screenOptions.contains(where: { $0.id == currentID }) {
            appState.displayIdentifier = ""
        }
    }
}
