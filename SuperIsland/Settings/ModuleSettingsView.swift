import AppKit
import AVFoundation
import EventKit
import Speech
import SwiftUI
import UserNotifications

struct ModuleSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var calendarManager = CalendarManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var nowPlayingManager = NowPlayingManager.shared
    @ObservedObject private var shelf = ShelfStore.shared
    @ObservedObject private var teleprompter = TeleprompterManager.shared
    @State private var teleprompterPermissionRefresh = 0
    @State private var didAutoRequestTeleprompterPermissions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SettingSectionLabel(title: NSLocalizedString("Media & HUD", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Now Playing", comment: "Settings label"), isOn: $appState.nowPlayingEnabled)
                if appState.nowPlayingEnabled {
                    SettingRowDivider()
                    SettingToggleRow(
                        title: NSLocalizedString("Browser media detection", comment: "Settings label"),
                        description: NSLocalizedString("Use macOS automation to detect media in allowed browsers.", comment: "Settings description"),
                        isOn: $nowPlayingManager.browserDetectionEnabled
                    )
                    if nowPlayingManager.browserDetectionEnabled {
                        browserMediaRows
                    }
                }
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Volume HUD", comment: "Settings label"), isOn: $appState.volumeHUDEnabled)
            }

            SettingSectionLabel(title: NSLocalizedString("Home", comment: "Settings section"))
            SettingGroup {
                homeSlotRow(title: NSLocalizedString("Left slot", comment: "Settings label"), selection: $appState.homeLeadingPanelRaw)
                SettingRowDivider()
                homeSlotRow(title: NSLocalizedString("Center slot", comment: "Settings label"), selection: $appState.homeCenterPanelRaw)
                SettingRowDivider()
                homeSlotRow(title: NSLocalizedString("Right slot", comment: "Settings label"), selection: $appState.homeTrailingPanelRaw)
            }

            SettingSectionLabel(title: NSLocalizedString("System", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Battery", comment: "Settings label"), isOn: $appState.batteryEnabled)
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Shelf", comment: "Settings label"), isOn: $appState.shelfEnabled)
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Auto-open Shelf on Drop", comment: "Settings label"), isOn: $appState.shelfAutoOpenOnDrop)
                SettingRowDivider()
                shelfRetentionRow
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Connectivity", comment: "Settings label"), isOn: $appState.connectivityEnabled)
            }

            SettingSectionLabel(title: NSLocalizedString("Information", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Calendar", comment: "Settings label"), isOn: calendarEnabledBinding)
                if appState.calendarEnabled {
                    SettingRowDivider()
                    calendarPermissionRow
                    if calendarManager.hasAccess {
                        SettingRowDivider()
                        SettingToggleRow(
                            title: NSLocalizedString("Collapse duplicate events", comment: "Settings label"),
                            description: NSLocalizedString("Hide repeated holidays or birthdays with the same title and time.", comment: "Settings description"),
                            isOn: $calendarManager.collapseDuplicates
                        )
                        SettingRowDivider()
                        SettingToggleRow(
                            title: NSLocalizedString("Hide holidays", comment: "Settings label"),
                            isOn: $calendarManager.hideHolidays
                        )
                        SettingRowDivider()
                        SettingToggleRow(
                            title: NSLocalizedString("Hide birthdays", comment: "Settings label"),
                            isOn: $calendarManager.hideBirthdays
                        )
                        SettingRowDivider()
                        calendarLookaheadRow
                        calendarSourceRows
                    }
                }
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Weather", comment: "Settings label"), isOn: $appState.weatherEnabled)
                SettingRowDivider()
                HStack {
                    Text(NSLocalizedString("Temperature Unit", comment: "Settings label"))
                        .font(.system(size: 13))
                    Spacer(minLength: 8)
                    Picker("", selection: $appState.temperatureUnit) {
                        Text("°C").tag(TemperatureUnit.celsius)
                        Text("°F").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 90)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                SettingRowDivider()
                SettingToggleRow(title: NSLocalizedString("Notifications", comment: "Settings label"), isOn: notificationsEnabledBinding)
                if appState.notificationsEnabled {
                    SettingRowDivider()
                    notificationPermissionRow
                    SettingRowDivider()
                    SettingToggleRow(
                        title: NSLocalizedString("Show previews", comment: "Settings label"),
                        description: NSLocalizedString("Display sender and message text when available.", comment: "Settings description"),
                        isOn: notificationPreviewsBinding
                    )
                    SettingRowDivider()
                    notificationRetentionRow
                    ForEach(NotificationFeedSource.allCases) { source in
                        SettingRowDivider()
                        SettingToggleRow(
                            title: source.title,
                            description: source.description,
                            isOn: notificationSourceBinding(for: source)
                        )
                    }
                }
            }

            SettingSectionLabel(title: NSLocalizedString("Productivity", comment: "Settings section"))
            SettingGroup {
                SettingToggleRow(title: NSLocalizedString("Teleprompter", comment: "Settings label"), isOn: teleprompterEnabledBinding)
                    .dataAnnotationID("teleprompter-module-toggle")
                if appState.teleprompterEnabled {
                    SettingRowDivider()
                    teleprompterPermissionRow
                    SettingRowDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Mode", comment: "Settings label"))
                                .font(.system(size: 13))
                            Text(teleprompter.listeningMode.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 12)
                        Picker("", selection: $teleprompter.listeningMode) {
                            ForEach(TeleprompterListeningMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 190)
                        .dataAnnotationID("teleprompter-listening-mode-control")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    SettingRowDivider()
                    HStack {
                        Text(NSLocalizedString("Script", comment: "Settings label"))
                            .font(.system(size: 13))
                        Spacer(minLength: 8)
                        Button(NSLocalizedString("Edit Script…", comment: "Button")) {
                            TeleprompterScriptEditorWindowController.show()
                        }
                        .font(.system(size: 12))
                        .dataAnnotationID("teleprompter-edit-script-button")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            notificationManager.checkPermission()
            calendarManager.refreshAccessStatus()
            refreshTeleprompterPermissionState()
            autoRequestTeleprompterPermissionsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            notificationManager.checkPermission()
            calendarManager.refreshAccessStatus()
            refreshTeleprompterPermissionState()
        }
        .onChange(of: teleprompter.listeningMode) { _, mode in
            refreshTeleprompterPermissionState()
            if mode == .wordTracking {
                autoRequestTeleprompterPermissionsIfNeeded()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                refreshTeleprompterPermissionState()
            }
        }
        .onChange(of: appState.teleprompterEnabled) { _, enabled in
            if enabled {
                autoRequestTeleprompterPermissionsIfNeeded()
            }
        }
    }

    private var teleprompterPermissionRow: some View {
        let _ = teleprompterPermissionRefresh
        let ready = PermissionsManager.shared.checkMicrophone()
            && PermissionsManager.shared.checkSpeechRecognition()

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Word Tracking permissions", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(teleprompterPermissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if ready {
                Label(NSLocalizedString("Ready", comment: "Status label"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            } else {
                Button(teleprompterPermissionButtonTitle) {
                    requestTeleprompterPermissions()
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .dataAnnotationID("teleprompter-speech-status")
    }

    private var teleprompterPermissionDescription: String {
        let microphoneStatus = PermissionsManager.shared.microphoneAuthorizationStatus()
        let speechStatus = PermissionsManager.shared.speechRecognitionAuthorizationStatus()
        let microphone = microphoneStatus == .authorized
        let speech = speechStatus == .authorized

        if microphoneStatus == .denied || microphoneStatus == .restricted ||
            speechStatus == .denied || speechStatus == .restricted {
            return NSLocalizedString("Access was denied or restricted. Open System Settings to enable Word Tracking.", comment: "Settings description")
        }

        switch (microphone, speech) {
        case (true, true):
            return NSLocalizedString("Microphone and Speech Recognition are ready for Word Tracking.", comment: "Settings description")
        case (false, true):
            return NSLocalizedString("Microphone access will be requested when Word Tracking is enabled.", comment: "Settings description")
        case (true, false):
            return NSLocalizedString("Speech Recognition access will be requested when Word Tracking is enabled.", comment: "Settings description")
        case (false, false):
            return NSLocalizedString("Microphone and Speech Recognition access are requested when Teleprompter is enabled.", comment: "Settings description")
        }
    }

    private var teleprompterPermissionButtonTitle: String {
        let microphone = PermissionsManager.shared.microphoneAuthorizationStatus()
        let speech = PermissionsManager.shared.speechRecognitionAuthorizationStatus()
        if microphone == .denied || microphone == .restricted ||
            speech == .denied || speech == .restricted {
            return NSLocalizedString("Open Settings", comment: "Button")
        }
        return NSLocalizedString("Grant Access", comment: "Button")
    }

    private var calendarPermissionRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Calendar access", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(calendarPermissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(calendarPermissionButtonTitle) {
                handleCalendarPermissionAction()
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var notificationPermissionRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Permission", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(notificationPermissionDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(notificationPermissionButtonTitle) {
                handleNotificationPermissionAction()
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var teleprompterEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.teleprompterEnabled },
            set: { enabled in
                appState.teleprompterEnabled = enabled
                if enabled {
                    requestTeleprompterPermissions()
                } else {
                    teleprompter.pause()
                }
            }
        )
    }

    private func requestTeleprompterPermissions() {
        didAutoRequestTeleprompterPermissions = true
        PermissionsManager.shared.requestTeleprompterWordTrackingAccess { _ in
            refreshTeleprompterPermissionState()
        }
        refreshTeleprompterPermissionState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            refreshTeleprompterPermissionState()
        }
    }

    private func autoRequestTeleprompterPermissionsIfNeeded() {
        guard appState.teleprompterEnabled else { return }
        guard !didAutoRequestTeleprompterPermissions else { return }

        let permissions = PermissionsManager.shared
        let microphone = permissions.microphoneAuthorizationStatus()
        let speech = permissions.speechRecognitionAuthorizationStatus()
        guard microphone == .notDetermined || speech == .notDetermined else {
            refreshTeleprompterPermissionState()
            return
        }

        requestTeleprompterPermissions()
    }

    private func refreshTeleprompterPermissionState() {
        teleprompterPermissionRefresh += 1
    }

    private var calendarLookaheadRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Upcoming range", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(NSLocalizedString("How many days appear in the Upcoming column.", comment: "Settings description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            StepperField(
                value: calendarLookaheadBinding,
                step: 1,
                range: 1...30
            ) { "\(Int($0))d" }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var notificationRetentionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Retained items", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(NSLocalizedString("How many feed items stay available in the island.", comment: "Settings description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            StepperField(
                value: notificationMaxRetainedBinding,
                step: 1,
                range: 1...50
            ) { "\(Int($0))" }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var calendarSourceRows: some View {
        if calendarManager.calendarSourceGroups.isEmpty {
            SettingRowDivider()
            Text(NSLocalizedString("No calendars available", comment: "Settings description"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        } else {
            ForEach(calendarManager.calendarSourceGroups) { group in
                SettingRowDivider()
                Text(group.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ForEach(group.calendars) { calendar in
                    calendarSourceRow(calendar)
                    if calendar.id != group.calendars.last?.id {
                        SettingRowDivider()
                    }
                }
            }
        }
    }

    private func calendarSourceRow(_ calendar: CalendarDisplayOption) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(cgColor: calendar.color))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .font(.system(size: 13))
                Text(calendarTypeLabel(calendar.type))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: calendarEnabledBinding(for: calendar.id))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var calendarEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.calendarEnabled },
            set: { newValue in
                appState.calendarEnabled = newValue
                if newValue {
                    calendarManager.refreshAccessStatus()
                    if calendarManager.authorizationStatus == .notDetermined {
                        calendarManager.requestAccess()
                    }
                }
            }
        )
    }

    private var calendarLookaheadBinding: Binding<Double> {
        Binding(
            get: { Double(calendarManager.lookaheadDays) },
            set: { calendarManager.lookaheadDays = Int($0) }
        )
    }

    private func calendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: { calendarManager.isCalendarEnabled(calendarID) },
            set: { calendarManager.setCalendar(calendarID, enabled: $0) }
        )
    }

    private var notificationPreviewsBinding: Binding<Bool> {
        Binding(
            get: { appState.notificationPreviewsEnabled },
            set: { newValue in
                appState.notificationPreviewsEnabled = newValue
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var notificationMaxRetainedBinding: Binding<Double> {
        Binding(
            get: { appState.notificationMaxRetainedItems },
            set: { newValue in
                appState.notificationMaxRetainedItems = newValue
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.notificationsEnabled },
            set: { newValue in
                appState.notificationsEnabled = newValue
                guard newValue else {
                    NotificationManager.shared.clearAll()
                    return
                }

                NotificationManager.shared.checkPermission()
                if NotificationManager.shared.authorizationStatus == .notDetermined {
                    NotificationManager.shared.requestPermission()
                }
            }
        )
    }

    private func notificationSourceBinding(for source: NotificationFeedSource) -> Binding<Bool> {
        Binding(
            get: { appState.isNotificationSourceEnabled(source) },
            set: { newValue in
                appState.setNotificationSource(source, enabled: newValue)
                NotificationManager.shared.applyFeedPreferences()
            }
        )
    }

    private var calendarPermissionDescription: String {
        switch calendarManager.authorizationStatus {
        case .fullAccess, .authorized:
            return NSLocalizedString("Allowed. Choose which calendars appear in SuperIsland.", comment: "Settings description")
        case .notDetermined:
            return NSLocalizedString("Not requested. Allow access to show upcoming events.", comment: "Settings description")
        case .denied:
            return NSLocalizedString("Denied. Open System Settings to allow Calendar access.", comment: "Settings description")
        case .restricted:
            return NSLocalizedString("Restricted by macOS settings.", comment: "Settings description")
        case .writeOnly:
            return NSLocalizedString("Write-only access is not enough to display events.", comment: "Settings description")
        @unknown default:
            return NSLocalizedString("Unknown. Check macOS Calendar privacy settings.", comment: "Settings description")
        }
    }

    private var notificationPermissionDescription: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return NSLocalizedString("Allowed. SuperIsland can send its own notifications and extension alerts.", comment: "Settings description")
        case .denied:
            return NSLocalizedString("Denied. Open System Settings to allow SuperIsland notifications.", comment: "Settings description")
        case .notDetermined:
            return NSLocalizedString("Not requested. Allow this when you want SuperIsland or extensions to send macOS notifications.", comment: "Settings description")
        case .provisional, .ephemeral:
            return NSLocalizedString("Allowed with limited delivery.", comment: "Settings description")
        @unknown default:
            return NSLocalizedString("Unknown. Check macOS notification settings.", comment: "Settings description")
        }
    }

    private var calendarPermissionButtonTitle: String {
        switch calendarManager.authorizationStatus {
        case .notDetermined:
            return NSLocalizedString("Request", comment: "Button")
        default:
            return NSLocalizedString("Open Settings", comment: "Button")
        }
    }

    private var notificationPermissionButtonTitle: String {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            return NSLocalizedString("Request", comment: "Button")
        default:
            return NSLocalizedString("Open Settings", comment: "Button")
        }
    }

    private func handleCalendarPermissionAction() {
        switch calendarManager.authorizationStatus {
        case .notDetermined:
            calendarManager.requestAccess()
        default:
            calendarManager.openCalendarSettings()
        }
    }

    private func handleNotificationPermissionAction() {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            notificationManager.requestPermission()
        default:
            notificationManager.openNotificationSettings()
        }
    }

    private func calendarTypeLabel(_ type: EKCalendarType) -> String {
        switch type {
        case .local:
            return NSLocalizedString("Local", comment: "Calendar type")
        case .calDAV:
            return NSLocalizedString("CalDAV", comment: "Calendar type")
        case .exchange:
            return NSLocalizedString("Exchange", comment: "Calendar type")
        case .subscription:
            return NSLocalizedString("Subscription", comment: "Calendar type")
        case .birthday:
            return NSLocalizedString("Birthdays", comment: "Calendar type")
        @unknown default:
            return NSLocalizedString("Calendar", comment: "Calendar type")
        }
    }

    private var shelfRetentionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Shelf retention", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(NSLocalizedString("Pinned items are kept", comment: "Settings description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Picker("", selection: $shelf.retentionDays) {
                ForEach(ShelfRetentionOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func homeSlotRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer(minLength: 12)
            Picker("", selection: selection) {
                ForEach(HomePanel.allCases) { panel in
                    Label(panel.title, systemImage: panel.iconName)
                        .tag(panel.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var browserMediaRows: some View {
        ForEach(nowPlayingManager.browserTargets) { browser in
            SettingRowDivider()
            browserToggleRow(browser)
        }
        SettingRowDivider()
        browserDetectionTestRow
    }

    private func browserToggleRow(_ browser: NowPlayingBrowserTarget) -> some View {
        SettingToggleRow(
            title: browser.displayName,
            description: NSLocalizedString("Allow SuperIsland to look for media in this browser.", comment: "Settings description"),
            isOn: browserBinding(for: browser.id)
        )
    }

    private var browserDetectionTestRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("Detection test", comment: "Settings label"))
                    .font(.system(size: 13))
                Text(browserDetectionMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                Button(NSLocalizedString("Test", comment: "Button")) {
                    nowPlayingManager.testBrowserDetection()
                }
                .font(.system(size: 12))
                Button(NSLocalizedString("Open Settings", comment: "Button")) {
                    nowPlayingManager.openAutomationSettings()
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func browserBinding(for browserID: String) -> Binding<Bool> {
        Binding(
            get: { nowPlayingManager.isBrowserAllowed(browserID) },
            set: { nowPlayingManager.setBrowser(browserID, allowed: $0) }
        )
    }

    private var browserDetectionMessage: String {
        if !nowPlayingManager.browserDetectionTestMessage.isEmpty {
            return nowPlayingManager.browserDetectionTestMessage
        }
        return NSLocalizedString("Requires Automation permission and JavaScript from Apple Events in the browser.", comment: "Settings description")
    }
}
