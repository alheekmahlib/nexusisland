import SwiftUI

// MARK: - Quran Expanded View (drawer)
//
// The expanded surface is 408×88pt — a short, wide rectangle. Layout mirrors
// Now Playing: a single horizontal row.
//
//   [medallion] [ surah name        | progress bar (draggable) ] [⏮ ⏯ ⏭]
//                [ reciter name      | 0:12 / 3:45               ]
//
// The three control buttons are the surah navigation the user asked for.
// Dragging the ProgressBar seeks within the surah.

struct QuranExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 12) {
            medallion

            // Center column: identity + draggable progress.
            // NOTE: this column stays LTR (the app's direction) so the progress
            // bar's physical coordinates match the rest of the app. Only the
            // Arabic text runs RTL — see the surah-name Text below.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(manager.currentSurah.arabicName)
                        .font(QuranDesign.surahName(14))
                        .foregroundColor(QuranDesign.textPrimary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft) // Arabic glyph shaping only
                    Text("·")
                        .font(QuranDesign.body(12))
                        .foregroundColor(QuranDesign.textTertiary)
                    Text(manager.currentReciter.latinName)
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textSecondary)
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
                        .font(QuranDesign.mono(9))
                        .foregroundColor(QuranDesign.textTertiary)
                    Spacer()
                    Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                        .font(QuranDesign.mono(9))
                        .foregroundColor(QuranDesign.textTertiary)
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

    // MARK: - Medallion (surah number in a gold ring)

    private var medallion: some View {
        ZStack {
            Circle()
                .strokeBorder(QuranDesign.accent.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(QuranDesign.accentSoft))
            Text(manager.currentSurah.arabicNumber)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(QuranDesign.accent)
        }
        .frame(width: 38, height: 38)
    }

    // MARK: - Controls

    private var primaryPlay: some View {
        Button(action: manager.togglePlayPause) {
            ZStack {
                Circle()
                    .fill(QuranDesign.accent)
                    .frame(width: 34, height: 34)
                    .shadow(color: QuranDesign.accent.opacity(0.4), radius: 5, y: 1)
                Image(systemName: manager.isLoading
                      ? "circle.dashed"
                      : (manager.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(Color(red: 0.10, green: 0.08, blue: 0.04))
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
                .foregroundColor(disabled ? QuranDesign.textTertiary : QuranDesign.textPrimary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
