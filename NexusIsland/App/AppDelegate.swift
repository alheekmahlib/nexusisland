import AppKit
import AVFoundation
import SwiftUI
import Carbon.HIToolbox
import Combine
import Speech

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared accessor set in `applicationDidFinishLaunching`, so static
    /// helpers (e.g. `showSettingsWindow()`) can reach the instance-owned
    /// settings window controller without callers holding a delegate
    /// reference.
    static var shared: AppDelegate?
    private static let linearExtensionID = "nexus.linear-mentions"
    private static let linearOAuthStoreKey = "extensions.\(linearExtensionID).store.oauth"
    private static let lastFmExtensionID = "nexus.lastfm-scrobbler"
    private static let lastFmOAuthStoreKey = "extensions.\(lastFmExtensionID).store.oauth"
    private var islandWindowController: IslandWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var updateWindowController: UpdateWindowController?
    private var updateCancellable: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var menuBarDefaultsObserver: NSObjectProtocol?
    private var powerStateObserver: NSObjectProtocol?
    private var quitHotkeyMonitor: Any?
    private var didBootstrapApp = false
    // Instance-owned settings window controller. Previously this was a static
    // property with `isReleasedWhenClosed = false`, which meant the NSWindow
    // and its entire SwiftUI view tree lived for the whole process lifetime
    // and were rebuilt on top of the old state every time settings reopened.
    // As an instance property we can nil it out when the window closes
    // (`windowWillClose`) so the view tree is released between opens.
    private var fallbackSettingsWindowController: NSWindowController?
    // Debounce token for the expensive work triggered by
    // `UserDefaults.didChangeNotification`. Without this, a single settings
    // write fires `ModuleRefreshScheduler.refreshScheduling()` +
    // `ExtensionManager.syncRuntimeEnergyState()` on every keystroke that
    // touches a bound Toggle (a thundering herd of reconciliations).
    private var defaultsChangeDebounce: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        Analytics.start()
        Analytics.track("app_launched", properties: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])

        // Apply the user's language override before any UI is built so the
        // NSLocalizedString lookups resolve against the right locale.
        AppState.shared.applyLanguageOverride()

        registerURLHandler()
        installQuitHotkeyMonitor()

        // defaults write com.vexaltech.NexusIsland "debug.alwaysShowOnboarding" -bool true
        let shouldShowOnboarding = !AppState.shared.onboardingCompleted || AppState.shared.debugAlwaysShowOnboarding
        if shouldShowOnboarding {
            showOnboardingIfNeeded()
        } else {
            bootstrapApp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure the agents-status Python subprocess exits with us so port 7823
        // is released cleanly and no orphan is inherited by launchd.
        AgentsStatusBridge.shared.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.setAppActive(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        AppState.shared.setAppActive(false)
    }

    deinit {
        if let quitHotkeyMonitor {
            NSEvent.removeMonitor(quitHotkeyMonitor)
        }
        if let powerStateObserver {
            NotificationCenter.default.removeObserver(powerStateObserver)
        }
    }

    private func bootstrapApp() {
        guard !didBootstrapApp else { return }
        didBootstrapApp = true
        setupIslandWindow()
        applyMenuBarVisibility()
        observeMenuBarSetting()
        observePowerState()
        initializeManagers()
    }

    private func showOnboardingIfNeeded() {
        applyMenuBarVisibility()
        observeMenuBarSetting()

        // LSUIElement apps can't reliably bring windows to the front.
        // Temporarily become a regular app so the onboarding window appears.
        NSApp.setActivationPolicy(.regular)

        guard onboardingWindowController == nil else {
            onboardingWindowController?.show()
            return
        }

        onboardingWindowController = OnboardingWindowController { [weak self] in
            self?.completeOnboarding()
        } onOpenSettings: {
            Self.showSettingsWindow()
        }
        onboardingWindowController?.show()
    }

    private func completeOnboarding() {
        AppState.shared.onboardingCompleted = true
        onboardingWindowController?.close()
        onboardingWindowController = nil

        // Revert to agent app (no dock icon) now that onboarding is done.
        NSApp.setActivationPolicy(.accessory)
        bootstrapApp()
    }

    // MARK: - Manager Initialization

    private func initializeManagers() {
        let state = AppState.shared

        // Eagerly initialize all enabled managers so they start monitoring
        if state.nowPlayingEnabled { _ = NowPlayingManager.shared }
        if state.volumeHUDEnabled { _ = VolumeManager.shared }
        if state.batteryEnabled { _ = BatteryManager.shared }
        if state.connectivityEnabled {
            _ = WiFiManager.shared
            if PermissionsManager.shared.check(.bluetooth) {
                _ = BluetoothManager.shared
            }
        }
        if state.calendarEnabled, PermissionsManager.shared.check(.calendar) {
            _ = CalendarManager.shared
        }
        if state.weatherEnabled {
            _ = WeatherManager.shared
        }
        if state.notificationsEnabled {
            _ = NotificationManager.shared
        }
        if state.teleprompterEnabled {
            _ = TeleprompterManager.shared
            let permissions = PermissionsManager.shared
            if permissions.microphoneAuthorizationStatus() == .notDetermined ||
                permissions.speechRecognitionAuthorizationStatus() == .notDetermined {
                permissions.requestTeleprompterWordTrackingAccess()
            }
        }
        if state.quranEnabled { _ = QuranManager.shared }
        if state.prayerTimesEnabled { _ = PrayerTimesManager.shared }
        if state.gitHubEnabled { _ = GitHubManager.shared }
        if state.ciMonitorEnabled { _ = CIManager.shared }
        if state.devServersEnabled { _ = DevServerManager.shared }
        if state.gitStatsEnabled { _ = GitStatsManager.shared }
        if state.dockerEnabled { _ = DockerManager.shared }
        if state.worldClockEnabled { _ = WorldClockManager.shared }
        if state.currencyEnabled { _ = CurrencyManager.shared }
        if state.countdownEnabled { _ = CountdownManager.shared }
        if state.stocksEnabled { _ = StocksManager.shared }
        if state.remindersEnabled { _ = RemindersManager.shared }
        if state.clipboardEnabled { ClipboardManager.shared.startMonitoring() }

        let extensions = ExtensionManager.shared
        extensions.discoverExtensions()
        extensions.activateDiscoveredExtensions()
        rebuildStatusMenu()
        state.refreshEnergyState()

        UpdateChecker.shared.checkIfDue()
        observeUpdateState()
    }

    private func observeUpdateState() {
        updateCancellable = UpdateChecker.shared.$checkState
            .compactMap { state -> (String, [String], URL)? in
                if case .updateAvailable(let version, let releaseNotes, let downloadURL) = state {
                    return (version, releaseNotes, downloadURL)
                }
                return nil
            }
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] version, releaseNotes, downloadURL in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.showUpdateDialog(version: version, releaseNotes: releaseNotes, downloadURL: downloadURL)
                }
            }
    }

    private func showUpdateDialog(version: String, releaseNotes: [String], downloadURL: URL) {
        let controller = UpdateWindowController(version: version, releaseNotes: releaseNotes, downloadURL: downloadURL)
        updateWindowController = controller
        controller.show()
    }

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleIncomingURL(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    private func installQuitHotkeyMonitor() {
        guard quitHotkeyMonitor == nil else { return }

        quitHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            QuitHotkeyGuard.shouldBlock(event) ? nil : event
        }
    }

    @objc
    private func handleIncomingURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor?) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        handleOAuthCallback(url: url)
    }

    private func handleOAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "nexusisland",
              components.host?.lowercased() == "auth",
              components.path.lowercased() == "/callback" else {
            return
        }

        var queryItems: [String: String] = [:]
        for item in components.queryItems ?? [] {
            queryItems[item.name.lowercased()] = item.value ?? ""
        }

        let provider = queryItems["provider"]?.lowercased() ?? ""
        let routing: (extensionID: String, storeKey: String, label: String)?
        switch provider {
        case "linear":
            routing = (Self.linearExtensionID, Self.linearOAuthStoreKey, "Linear")
        case "lastfm":
            routing = (Self.lastFmExtensionID, Self.lastFmOAuthStoreKey, "Last.fm")
        default:
            routing = nil
        }
        guard let routing else {
            return
        }

        let accessToken = queryItems["access_token"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !accessToken.isEmpty else {
            ExtensionLogger.shared.log(routing.extensionID, .warning, "Received \(routing.label) OAuth callback without access token")
            return
        }

        let expiresIn = Int(queryItems["expires_in"] ?? "") ?? 0
        var payload: [String: Any] = [
            "provider": provider,
            "accessToken": accessToken,
            "access_token": accessToken,
            "tokenType": queryItems["token_type"] ?? "Bearer",
            "token_type": queryItems["token_type"] ?? "Bearer",
            "expiresIn": expiresIn,
            "expires_in": expiresIn,
            "scope": queryItems["scope"] ?? "",
            "receivedAt": Int(Date().timeIntervalSince1970),
            "callbackURL": url.absoluteString
        ]

        if let username = queryItems["username"], !username.isEmpty {
            payload["username"] = username
        }
        if let name = queryItems["name"], !name.isEmpty, payload["username"] == nil {
            payload["username"] = name
        }

        if provider == "lastfm" {
            if let apiKey = queryItems["api_key"], !apiKey.isEmpty {
                payload["apiKey"] = apiKey
                payload["api_key"] = apiKey
            }
            if let apiSecret = queryItems["api_secret"], !apiSecret.isEmpty {
                payload["apiSecret"] = apiSecret
                payload["api_secret"] = apiSecret
            }
        }

        // SECURITY: store the full OAuth payload (which contains accessToken,
        // api_key, api_secret) in the Keychain rather than UserDefaults. A
        // metadata-only projection is kept in UserDefaults for non-secret UI
        // fields. Extensions still read via `NexusIsland.store.get("oauth")`,
        // which is bridged to consult the Keychain (see `injectStore`).
        if let secretData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            KeychainStore.save(
                account: routing.extensionID,
                service: "nexus.oauth",
                data: secretData
            )
        }

        // Metadata-only mirror (no access tokens / API secrets) for any UI or
        // legacy code path that reads from UserDefaults directly.
        var metadata = payload
        for secretKey in ["accessToken", "access_token", "apiKey", "api_key", "apiSecret", "api_secret"] {
            metadata.removeValue(forKey: secretKey)
        }
        UserDefaults.standard.set(metadata as NSDictionary, forKey: routing.storeKey)

        let extensions = ExtensionManager.shared
        if extensions.runtimes[routing.extensionID] == nil {
            extensions.activate(extensionID: routing.extensionID)
        }
        extensions.scheduleImmediateRefresh(extensionID: routing.extensionID)
        ExtensionLogger.shared.log(routing.extensionID, .info, "Stored \(routing.label) OAuth token from callback")
    }

    // MARK: - Island Window

    private func setupIslandWindow() {
        islandWindowController = IslandWindowController()
        islandWindowController?.showIsland()
    }

    // MARK: - Menu Bar

    private func applyMenuBarVisibility() {
        if AppState.shared.showMenuBarIcon {
            installStatusItem()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(systemSymbolName: Constants.menuBarIconName, accessibilityDescription: "NexusIsland")
        }

        item.menu = buildStatusMenu()
        statusItem = item
    }

    private func rebuildStatusMenu() {
        guard let item = statusItem else { return }
        item.menu = buildStatusMenu()
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(makeMenuItem(title: NSLocalizedString("Now Playing", comment: "Menu item"), action: #selector(showNowPlaying)))
        menu.addItem(makeMenuItem(title: NSLocalizedString("Battery", comment: "Menu item"), action: #selector(showBattery)))
        menu.addItem(NSMenuItem.separator())
        // Module visibility & ordering now live exclusively in Settings → Island Display.
        menu.addItem(makeMenuItem(title: NSLocalizedString("Settings...", comment: "Menu item"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: NSLocalizedString("Quit NexusIsland", comment: "Menu item"), action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    private func observeMenuBarSetting() {
        guard menuBarDefaultsObserver == nil else { return }
        menuBarDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // applyMenuBarVisibility is cheap and gives immediate UI
                // feedback, so run it synchronously. The expensive downstream
                // refreshes are debounced so a burst of UserDefaults writes
                // (e.g. dragging a slider) collapses into a single reconcile.
                self.applyMenuBarVisibility()
                self.defaultsChangeDebounce?.cancel()
                let work = DispatchWorkItem {
                    ModuleRefreshScheduler.shared.refreshScheduling()
                    ExtensionManager.shared.syncRuntimeEnergyState()
                }
                self.defaultsChangeDebounce = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
        }
    }

    private func observePowerState() {
        guard powerStateObserver == nil else { return }
        powerStateObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppState.shared.refreshEnergyState()
            }
        }
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    // MARK: - Menu Actions

    @objc private func showNowPlaying() {
        AppState.shared.showHUD(module: .nowPlaying, autoDismiss: false)
    }

    @objc private func showBattery() {
        AppState.shared.showHUD(module: .battery, autoDismiss: false)
    }

    @objc private func openSettings() {
        // NSStatusItem menu actions run while the menu is still tracking.
        // Defer window presentation to the next runloop tick so it reliably appears.
        DispatchQueue.main.async {
            Self.showSettingsWindow()
        }
    }

    static func showSettingsWindow() {
        // Avoid opening the SwiftUI Settings scene via AppKit selectors in menu-bar mode.
        // macOS may reject those calls with a "use SettingsLink" warning.
        Self.shared?.showFallbackSettingsWindow()
    }

    private func showFallbackSettingsWindow() {
        if let window = fallbackSettingsWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView()
            .environmentObject(AppState.shared)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("NexusIsland Settings", comment: "Window title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // Transparent, edge-to-edge title bar so the vibrant glass backdrop
        // runs behind the traffic-light buttons (full-glass look).
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 960, height: 680))
        window.minSize = NSSize(width: 800, height: 560)
        // Allow the window (and its full SwiftUI view tree) to be released
        // when closed, instead of living for the whole process lifetime.
        window.isReleasedWhenClosed = true
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        fallbackSettingsWindowController = NSWindowController(window: window)
        fallbackSettingsWindowController?.showWindow(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Release the settings window controller + its SwiftUI view tree when
        // the user closes the window. Without this the NSWindow and the
        // hosted SettingsView hierarchy (which subscribes to AppState and
        // every per-module manager) were retained for the whole process
        // lifetime and rebuilt on top of stale state on every reopen.
        if (notification.object as? NSWindow) === fallbackSettingsWindowController?.window {
            fallbackSettingsWindowController = nil
        }
    }
}
