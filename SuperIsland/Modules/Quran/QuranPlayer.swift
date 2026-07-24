import AVFoundation
import Combine
import Foundation

// MARK: - Quran Player

/// Thin AVPlayer wrapper that plays one whole-surah audio file at a time.
///
/// Playback is surah-granular: every (reciter, surah) pair maps to a single
/// MP3 via the AlQuran Cloud CDN, so there's no per-ayah playlist to manage.
/// Resume position is reported back to the owner (`QuranManager`) so the last
/// listened offset survives app restarts.
///
/// The player is `@MainActor` and publishes its state for SwiftUI. All AVKit
/// calls that can block are kept off the main thread via the player's own
/// notification/time-observer callbacks, which dispatch to main for us.
@MainActor
final class QuranPlayer: NSObject, ObservableObject {
    /// Playback state surfaced to the UI.
    enum PlaybackState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case ended
        case failed(String)
    }

    @Published private(set) var state: PlaybackState = .idle
    /// Current offset within the loaded surah, in seconds.
    @Published private(set) var currentTime: Double = 0
    /// Total duration of the loaded surah, in seconds (0 until known).
    @Published private(set) var duration: Double = 0

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    /// Closures held while loading so we can complete a load request even if a
    /// newer one supersedes the AVPlayer item.
    private var pendingResumeOffset: Double?

    var isPlaying: Bool { state == .playing }
    var isLoading: Bool { state == .loading }

    /// Fraction of the surah completed, clamped to 0...1 (UI binding).
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    override init() {
        super.init()
    }

    deinit {
        // AVPlayer items and observers must be torn down; capture the heavy
        // references locally because deinit cannot touch @MainActor-isolated
        // state on a non-main thread.
        let player = self.player
        let timeToken = self.timeObserverToken
        let endObs = self.endObserver
        let failObs = self.failObserver
        let statusObs = self.statusObservation
        let durationObs = self.durationObservation
        DispatchQueue.main.async {
            if let token = timeToken { player?.removeTimeObserver(token) }
            if let endObs { NotificationCenter.default.removeObserver(endObs) }
            if let failObs { NotificationCenter.default.removeObserver(failObs) }
            statusObs?.invalidate()
            durationObs?.invalidate()
            player?.pause()
        }
    }

    // MARK: - Loading & playback

    /// Load a surah for the given reciter, optionally resuming at `offset`.
    /// Any previously loaded item is replaced.
    func load(reciter: QuranReciter, surah: Surah, resumeAt offset: Double = 0) {
        guard let url = Self.audioURL(for: reciter, surah: surah) else {
            state = .failed("Unable to build audio URL for \(surah.latinName).")
            return
        }

        tearDownItem()
        pendingResumeOffset = max(0, offset)

        let item = AVPlayerItem(url: url)
        observe(item: item)

        let avPlayer = AVPlayer(playerItem: item)
        // Quran audio should keep playing with the screen locked and mix with
        // (duck) other audio rather than interrupting it.
        avPlayer.actionAtItemEnd = .pause
        self.player = avPlayer

        state = .loading
        currentTime = max(0, offset)
        duration = 0
    }

    /// Begin playback. If the item is still loading, playback starts when ready.
    func play() {
        guard let player else { return }
        switch state {
        case .idle, .failed:
            return
        case .ended:
            // Restart from the beginning on replay after completion.
            player.seek(to: .zero)
            currentTime = 0
        default:
            break
        }
        player.play()
        state = .playing
    }

    /// Pause playback without unloading.
    func pause() {
        guard let player else { return }
        player.pause()
        if state == .playing {
            state = .paused
        }
    }

    /// Toggle between playing and paused.
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    /// Stop playback entirely and release the current item.
    func stop() {
        player?.pause()
        tearDownItem()
        player = nil
        state = .idle
        currentTime = 0
        duration = 0
    }

    /// Seek to an absolute position (seconds) within the loaded surah.
    func seek(to seconds: Double) {
        guard let player else { return }
        let target = min(max(0, seconds), max(0, duration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                     toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in self?.currentTime = target }
        }
    }

    /// Seek to a fraction (0...1) of the surah duration.
    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        seek(to: fraction * duration)
    }

    // MARK: - URL building

    /// Whole-surah MP3 URL on the AlQuran Cloud CDN.
    /// Format: https://cdn.islamic.network/quran/audio-surah/128/<edition>/<surah>.mp3
    static func audioURL(for reciter: QuranReciter, surah: Surah) -> URL? {
        var components = URLComponents(string: "https://cdn.islamic.network")
        components?.path = "/quran/audio-surah/128/\(reciter.edition)/\(surah.number).mp3"
        return components?.url
    }

    // MARK: - Observation wiring

    private func observe(item: AVPlayerItem) {
        // Track readiness and duration via KVO.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] obsItem, _ in
            Task { @MainActor in self?.handleItemStatusChange(obsItem) }
        }
        durationObservation = item.observe(\.duration, options: [.new]) { [weak self] obsItem, _ in
            Task { @MainActor in
                let secs = obsItem.duration.seconds
                guard secs.isFinite, secs > 0 else { return }
                self?.duration = secs
            }
        }

        // Periodic time updates feed the progress UI.
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                let secs = time.seconds
                guard secs.isFinite else { return }
                self?.currentTime = secs
            }
        }

        // Natural end → owner decides whether to advance.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.state = .ended
                self?.currentTime = self?.duration ?? 0
                self?.onPlaybackEnded?()
            }
        }

        // Playback stall / failure.
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let reason = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
                              as? Error)?.localizedDescription ?? "Playback failed."
                self?.state = .failed(reason)
            }
        }
    }

    private func handleItemStatusChange(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            // Honor any requested resume offset once the item is seekable.
            if let offset = pendingResumeOffset, offset > 0 {
                pendingResumeOffset = nil
                player?.seek(to: CMTime(seconds: offset, preferredTimescale: 600))
                currentTime = offset
            }
            // If the user pressed play while still loading, begin now.
            if state == .loading && player?.timeControlStatus == .paused {
                // Defer the actual play() to the caller via onItemReady.
                onItemReady?()
            }
            if state == .loading { state = .paused }
        case .failed:
            let reason = item.error?.localizedDescription ?? "Unable to load audio."
            state = .failed(reason)
        default:
            break
        }
    }

    private func tearDownItem() {
        if let token = timeObserverToken { player?.removeTimeObserver(token) }
        timeObserverToken = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        self.endObserver = nil
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        self.failObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        durationObservation?.invalidate()
        durationObservation = nil
        pendingResumeOffset = nil
    }

    // MARK: - Hooks (set by QuranManager)

    /// Fired when a surah finishes naturally. The owner decides whether to
    /// advance to the next surah or stop.
    var onPlaybackEnded: (() -> Void)?

    /// Fired when an item becomes ready after a load. Lets the owner start
    /// playback if the user requested play while still loading.
    var onItemReady: (() -> Void)?
}
