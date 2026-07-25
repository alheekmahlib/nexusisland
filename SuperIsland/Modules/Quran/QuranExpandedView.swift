import SwiftUI

// MARK: - Quran Expanded View (drawer)
//
// Redesigned with NexusDesign tokens while preserving the RTL-aware, draggable
// QuranProgressBar. Layout (408×88pt):
//   [medallion] [ surah name        | progress bar (draggable) ] [⏮ ⏯ ⏭]
//                [ reciter name      | 0:12 / 3:45               ]
// The center column stays LTR so the progress bar's physical coordinates
// match the app; only the Arabic text runs RTL.

struct QuranExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 12) {
            medallion

            // Center column: identity + draggable progress.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(manager.currentSurah.arabicName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft) // Arabic glyph shaping only
                    Text("·")
                        .font(NexusTypography.body)
                        .foregroundColor(NexusPalette.textTertiary)
                    Text(manager.currentReciter.latinName)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                        .lineLimit(1)
                }

                // LTR progress bar — fill grows left→right, matching the app.
                QuranProgressBar(
                    progress: manager.progress,
                    trackHeight: 3,
                    knobSize: 9,
                    onSeek: { fraction in manager.seek(toFraction: fraction) },
                    isRTL: false
                )

                HStack(spacing: 0) {
                    Text(QuranDesign.formatTime(manager.currentTime))
                        .font(NexusTypography.mono)
                        .foregroundColor(NexusPalette.textTertiary)
                    Spacer()
                    Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                        .font(NexusTypography.mono)
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)

            // Right stack: three controls, vertically centered.
            VStack(spacing: 6) {
                navButton(icon: "backward.fill", action: manager.previousSurah,
                          disabled: manager.currentSurah.number <= 1)
                primaryPlay
                navButton(icon: "forward.fill", action: manager.nextSurah,
                          disabled: manager.currentSurah.number >= QuranSurahs.all.count)
            }
        }
    }

    // MARK: - Medallion (surah number in a gradient ring)

    private var medallion: some View {
        ZStack {
            Circle()
                .strokeBorder(NexusPalette.accentGold.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(NexusGradient.accentGold.opacity(0.18)))
            Text(manager.currentSurah.arabicNumber)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(NexusPalette.accentGold)
        }
        .frame(width: 38, height: 38)
    }

    // MARK: - Controls

    private var primaryPlay: some View {
        Button(action: manager.togglePlayPause) {
            ZStack {
                Circle()
                    .fill(NexusGradient.primary)
                    .frame(width: 34, height: 34)
                    .shadow(color: NexusPalette.gradientMid.opacity(0.4), radius: 5, y: 1)
                Image(systemName: manager.isLoading
                      ? "circle.dashed"
                      : (manager.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.white)
                    .offset(x: manager.isPlaying ? 0 : 1)
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
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
