import AVFoundation
import Combine
import Foundation
import MediaPlayer

// MARK: - Quran Manager

/// Owns Quran playback state and bridges it to the rest of the app.
///
/// Responsibilities:
///   - Hold the current reciter + surah selection (persisted in @AppStorage).
///   - Drive the `QuranPlayer` (load / play / pause / seek).
///   - Persist the resume offset so listening survives restarts.
///   - Auto-advance to the next surah when one ends (toggleable).
///   - Track daily completion stats.
///
/// Follows the project's manager-singleton pattern: `@MainActor
/// ObservableObject` with `static let shared`, reading its settings via
/// @AppStorage like every other built-in module.
@MainActor
final class QuranManager: ObservableObject {
    static let shared = QuranManager()

    // MARK: - Published state

    @Published private(set) var currentSurah: Surah
    @Published private(set) var currentReciter: QuranReciter
    @Published private(set) var playbackState: QuranPlayer.PlaybackState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    /// Set true while the manager is fetching fresh audio so the UI can show a
    /// spinner that is distinct from AVPlayer's own loading state.
    @Published private(set) var isPreparingSurah = false

    // MARK: - Persisted selection (UserDefaults via the shared defaults suite)

    /// Reciter id (stable across catalog reordering). Mirrored to @AppStorage
    /// manually because the value is a Surah/QuranReciter struct.
    private let reciterIDKey = "module.quran.reciterID"
    private let surahNumberKey = "module.quran.surahNumber"
    private let resumeOffsetKey = "module.quran.resumeOffset"
    private let autoAdvanceKey = "module.quran.autoAdvance"
    private let completionsKey = "module.quran.completions"
    private let completionsDateKey = "module.quran.completionsDate"

    /// Whether the manager should auto-play the next surah when one ends.
    @Published var autoAdvance: Bool {
        didSet { defaults.set(autoAdvance, forKey: autoAdvanceKey) }
    }

    /// Number of surahs completed today (resets at midnight).
    @Published private(set) var completionsToday: Int

    private let defaults = UserDefaults.standard
    private let player = QuranPlayer()
    private var cancellables = Set<AnyCancellable>()
    /// Guards against re-entrancy when auto-advancing fires onTrackEnded.
    private var isAdvancing = false

    // MARK: - Init

    private init() {
        let savedReciterID = UserDefaults.standard.string(forKey: "module.quran.reciterID")
            ?? QuranReciters.defaultReciter.id
        let savedSurah = UserDefaults.standard.integer(forKey: "module.quran.surahNumber")
        let surah = savedSurah > 0 ? QuranSurahs.surah(forNumber: savedSurah) : QuranSurahs.first

        currentReciter = QuranReciters.reciter(forID: savedReciterID)
        currentSurah = surah
        autoAdvance = (UserDefaults.standard.object(forKey: "module.quran.autoAdvance") as? Bool) ?? true
        completionsToday = QuranManager.loadTodayCompletions(defaults: UserDefaults.standard)

        wirePlayer()
    }

    // MARK: - Player wiring

    private func wirePlayer() {
        player.onPlaybackEnded = { [weak self] in self?.onTrackEnded() }
        player.onItemReady = { [weak self] in self?.onItemReady() }

        player.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.playbackState = state
                self?.notifyNowPlayingOfStateChange()
            }
            .store(in: &cancellables)

        player.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                self?.currentTime = time
                self?.persistResumeOffset(time)
            }
            .store(in: &cancellables)

        player.$duration
            .receive(on: RunLoop.main)
            .sink { [weak self] duration in
                self?.duration = duration
                self?.notifyNowPlayingOfStateChange()
            }
            .store(in: &cancellables)
    }

    /// Tell the Now Playing module to re-evaluate its source. Called whenever
    /// Quran playback state / duration changes so Now Playing picks up (or
    /// releases) the Quran snapshot promptly. Throttled to avoid flooding.
    private var lastNowPlayingNotify = Date.distantPast
    private func notifyNowPlayingOfStateChange() {
        let now = Date()
        guard now.timeIntervalSince(lastNowPlayingNotify) > 0.25 else { return }
        lastNowPlayingNotify = now
        publishSystemNowPlayingInfo()
        Task { @MainActor in
            NowPlayingManager.shared.refreshPreferredSource()
        }
    }

    // MARK: - System media session (media keys / Control Center)
    //
    // Publishing Quran to MPNowPlayingInfoCenter lets macOS route the keyboard
    // transport keys (F7/F8/F9) and the Control Center media widget directly to
    // this app — no Accessibility permission needed, unlike a CGEventTap. The
    // remote-command handlers below are the receiving end: when the user hits a
    // media key, the system invokes them.

    private var remoteCommandsRegistered = false

    private func registerRemoteCommands() {
        guard !remoteCommandsRegistered else { return }
        remoteCommandsRegistered = true

        let cc = MPRemoteCommandCenter.shared()
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        cc.playCommand.addTarget { [weak self] _ in
            if self?.playbackState != .playing { self?.play() }
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            if self?.playbackState == .playing { self?.pause() }
            return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextSurah()
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousSurah()
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            guard self.duration > 0 else { return .commandFailed }
            self.seek(toFraction: event.positionTime / self.duration)
            return .success
        }
        // Enable the commands so the system knows this app accepts them.
        cc.togglePlayPauseCommand.isEnabled = true
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.nextTrackCommand.isEnabled = true
        cc.previousTrackCommand.isEnabled = true
        cc.changePlaybackPositionCommand.isEnabled = true
    }

    /// Push the current Quran state to the system Now Playing info center.
    /// Called from `notifyNowPlayingOfStateChange()` (throttled). Keeping the
    /// info fresh is what makes macOS treat this app as the active media owner
    /// and route media keys to it instead of Music.app / the browser.
    private func publishSystemNowPlayingInfo() {
        guard playbackState != .idle else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        registerRemoteCommands()

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = currentSurah.arabicName
        info[MPMediaItemPropertyArtist] = currentReciter.displayName
        info[MPMediaItemPropertyAlbumTitle] = "Quran"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func onItemReady() {
        // If the user hit play while the item was still loading, start now.
        if playbackState == .loading {
            player.play()
        }
    }

    // MARK: - Public playback API

    /// True when audio is actively playing (loading doesn't count).
    var isPlaying: Bool { playbackState == .playing }
    var isLoading: Bool { playbackState == .loading || isPreparingSurah }

    /// Fraction of the current surah completed (0...1).
    var progress: Double { player.progress }

    /// Begin playing the current selection from its resume offset (or start).
    func play() {
        // If nothing is loaded yet, load the current selection first.
        if playbackState == .idle || playbackState == .ended {
            loadCurrent(resume: playbackState == .ended ? 0 : nil, thenPlay: true)
            return
        }
        player.play()
    }

    /// Pause playback.
    func pause() {
        player.pause()
    }

    /// Toggle play/pause.
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Stop and release the current item.
    func stop() {
        player.stop()
        // Release the system media session immediately so media keys go back
        // to the previous owner (browser / Spotify) without waiting for the
        // throttled notifier.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Seek to a fraction of the surah.
    func seek(toFraction fraction: Double) {
        player.seek(toFraction: fraction)
    }

    // MARK: - Selection

    /// Select a reciter. If audio is loaded, reload the current surah for the
    /// new reciter (re-resuming from the saved offset when possible).
    func selectReciter(_ reciter: QuranReciter) {
        guard reciter.id != currentReciter.id else { return }
        currentReciter = reciter
        defaults.set(reciter.id, forKey: reciterIDKey)

        let wasPlaying = isPlaying
        let offset = wasPlaying ? currentTime : savedResumeOffset()
        loadCurrent(resume: offset, thenPlay: wasPlaying)
    }

    /// Select a surah by number, loading it immediately.
    func selectSurah(number: Int) {
        let surah = QuranSurahs.surah(forNumber: number)
        selectSurah(surah, play: true)
    }

    /// Select a surah and optionally start playback.
    func selectSurah(_ surah: Surah, play: Bool) {
        guard surah.number != currentSurah.number || playbackState == .idle else {
            // Same surah already loaded: just (re)play.
            if play { self.play() }
            return
        }
        currentSurah = surah
        defaults.set(surah.number, forKey: surahNumberKey)
        // Each surah starts fresh (resume offset is per-surah; we only persist
        // the most recent, keyed by the current surah number).
        loadCurrent(resume: play ? 0 : nil, thenPlay: play)
    }

    /// Jump to the previous surah in canonical order (clamped at Al-Fatihah).
    func previousSurah() {
        guard currentSurah.number > 1 else { return }
        selectSurah(number: currentSurah.number - 1)
    }

    /// Jump to the next surah in canonical order (clamped at An-Nas).
    func nextSurah() {
        guard currentSurah.number < QuranSurahs.all.count else { return }
        selectSurah(number: currentSurah.number + 1)
    }

    // MARK: - Resume offset persistence

    /// Resume offset, in seconds, stored for the current surah.
    func savedResumeOffset() -> Double {
        let key = resumeOffsetKey(for: currentSurah.number)
        return defaults.double(forKey: key)
    }

    private func persistResumeOffset(_ time: Double) {
        let key = resumeOffsetKey(for: currentSurah.number)
        defaults.set(time, forKey: key)
    }

    private func resumeOffsetKey(for surahNumber: Int) -> String {
        "\(resumeOffsetKey).\(surahNumber)"
    }

    // MARK: - Completions

    /// Bump the daily completion counter and rotate the date if needed.
    func recordCompletion() {
        rolloverCompletionsIfNeeded()
        completionsToday += 1
        defaults.set(completionsToday, forKey: completionsKey)
        defaults.set(Self.todayDateString(), forKey: completionsDateKey)
    }

    private func rolloverCompletionsIfNeeded() {
        let storedDate = defaults.string(forKey: completionsDateKey) ?? ""
        if storedDate != Self.todayDateString() {
            completionsToday = 0
            defaults.set(0, forKey: completionsKey)
        }
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private static func loadTodayCompletions(defaults: UserDefaults) -> Int {
        let storedDate = defaults.string(forKey: "module.quran.completionsDate") ?? ""
        if storedDate != todayDateString() { return 0 }
        return defaults.integer(forKey: "module.quran.completions")
    }

    // MARK: - Internal driver

    /// Load the current (reciter, surah) pair into the player.
    /// - Parameters:
    ///   - resume: Offset to seek to once ready. nil = use the saved offset.
    ///   - thenPlay: Begin playback as soon as the item is ready.
    private func loadCurrent(resume: Double?, thenPlay: Bool) {
        let offset = resume ?? savedResumeOffset()
        isPreparingSurah = true
        player.load(reciter: currentReciter, surah: currentSurah, resumeAt: offset)

        if thenPlay {
            // Start playback now. AVPlayer buffers and begins as soon as the
            // item is ready; calling play() during .loading is the documented
            // way to auto-start once media is available.
            player.play()
        }
        isPreparingSurah = false
    }

    /// Called by the player when a surah reaches its natural end.
    private func onTrackEnded() {
        guard !isAdvancing else { return }
        recordCompletion()

        guard autoAdvance, let next = QuranSurahs.after(currentSurah) else { return }
        isAdvancing = true
        selectSurah(next, play: true)
        // Reset after the new load kicks off.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isAdvancing = false
        }
    }
}
