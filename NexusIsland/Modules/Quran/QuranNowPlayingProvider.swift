import Foundation

// MARK: - QuranNowPlayingProvider
//
// Bridges Quran playback (AVPlayer-based, self-contained) into the Now Playing
// module so a playing surah appears in the island's Now Playing surface and can
// be controlled (play/pause/next/previous) from there — in-app only, never
// published to the macOS system media session.
//
// Registered by NowPlayingManager as the highest-priority provider whenever the
// Quran player is not idle.

@MainActor
struct QuranNowPlayingProvider: NowPlayingProvider {
    let id = "quran"
    let displayName = NSLocalizedString("Quran", comment: "Now Playing provider")
    let requiresPermission = false

    func currentSnapshot() async -> NowPlayingSnapshot? {
        let manager = QuranManager.shared
        // Hide from Now Playing entirely when nothing is loaded / idle, so the
        // system media (Spotify, etc.) can take over again.
        guard manager.playbackState != .idle else { return nil }

        let surah = manager.currentSurah
        let reciter = manager.currentReciter
        return NowPlayingSnapshot(
            providerID: id,
            title: surah.arabicName,
            artist: reciter.displayName,
            album: "Quran",
            duration: manager.duration,
            elapsedTime: manager.currentTime,
            playbackRate: manager.isPlaying ? 1.0 : 0.0,
            isPlaying: manager.isPlaying,
            sourceName: displayName,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "nexus.quran",
            albumArtist: reciter.displayName,
            artworkURL: nil,
            trackIdentifier: "surah.\(surah.number)",
            isLocalFile: false,
            browserTabURL: "",
            capturedAt: Date()
        )
    }

    func playPause() async throws {
        QuranManager.shared.togglePlayPause()
    }

    func nextTrack() async throws {
        QuranManager.shared.nextSurah()
    }

    func previousTrack() async throws {
        QuranManager.shared.previousSurah()
    }
}
