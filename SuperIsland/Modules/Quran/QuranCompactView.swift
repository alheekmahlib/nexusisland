import SwiftUI

// MARK: - Quran Compact View (pill)

struct QuranCompactView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 8) {
            reciterGlyph
            surahLabel
            Spacer(minLength: 0)
            playbackButton
        }
    }

    /// Small circular badge with the Quran icon. Tinted while playing.
    private var reciterGlyph: some View {
        Image(systemName: "book.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(manager.isPlaying ? 1 : 0.85))
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(.white.opacity(manager.isPlaying ? 0.18 : 0.08))
            )
            .scaleEffect(manager.isPlaying ? 1.0 : 0.95)
            .animation(.easeOut(duration: 0.2), value: manager.isPlaying)
    }

    /// Surah name (Arabic) with a thin progress underline.
    private var surahLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(manager.currentSurah.arabicName)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .environment(\.layoutDirection, .rightToLeft)

            ProgressView(value: manager.progress)
                .progressViewStyle(.linear)
                .tint(.white.opacity(0.7))
                .frame(width: 48, height: 2)
        }
    }

    private var playbackButton: some View {
        Button(action: { manager.togglePlayPause() }) {
            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
        .opacity(manager.isLoading ? 0.5 : 1)
        .help(manager.isPlaying ? "Pause" : "Play")
    }
}
