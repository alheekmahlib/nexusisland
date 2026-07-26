import SwiftUI

// MARK: - Quran Expanded View (drawer)
//
// Mid-size player within 408×88pt. Three columns:
//   [artwork medallion] [ identity · progress · timecodes ] [⏮ ⏯ ⏭]
// The center column stays LTR so the progress bar's coordinates match the app;
// only Arabic text runs RTL locally.

struct QuranExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Identity row: surah name + reciter.
                HStack(spacing: 6) {
                    Text(manager.currentSurah.arabicName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text("·")
                        .font(NexusTypography.body)
                        .foregroundColor(NexusPalette.textTertiary)
                    Text(manager.currentReciter.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                // Draggable progress.
                QuranProgressBar(
                    progress: manager.progress,
                    trackHeight: 4,
                    knobSize: 10,
                    onSeek: { fraction in manager.seek(toFraction: fraction) },
                    isRTL: false
                )

                HStack(spacing: 0) {
                    Text(QuranDesign.formatTime(manager.currentTime))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(NexusPalette.textTertiary)
                    Spacer()
                    Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)

            // Transport: prev / play-pause / next.
            VStack(spacing: 6) {
                navButton(icon: "backward.fill", action: manager.previousSurah,
                          disabled: manager.currentSurah.number <= 1)
                primaryPlay
                navButton(icon: "forward.fill", action: manager.nextSurah,
                          disabled: manager.currentSurah.number >= QuranSurahs.all.count)
            }
        }
    }


    // MARK: - Controls

    private var primaryPlay: some View {
        NeonButton(
            systemName: manager.isLoading
                ? "circle.dashed"
                : (manager.isPlaying ? "pause.fill" : "play.fill"),
            size: 34,
            gradient: NexusGradient.purple
        ) {
            manager.togglePlayPause()
        }
        .disabled(manager.isLoading)
        .opacity(manager.isLoading ? 0.5 : 1)
    }

    private func navButton(icon: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(disabled ? NexusPalette.textTertiary : NexusPalette.textPrimary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
