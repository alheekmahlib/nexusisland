import SwiftUI

// MARK: - Quran Compact View (pill)
//
// The compact surface is only 200×36pt, so the row must fit on a single line:
// [play toggle] [surah name] [gradient hairline]. Purple NexusDesign tokens
// match the rest of the app.

struct QuranCompactView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 6) {
            playToggle
            surahName
            // Gradient hairline fills the remaining width.
            GradientProgressBar(progress: manager.progress, style: .hairline, animated: false)
                .frame(maxWidth: .infinity)
                .frame(height: 2)
        }
    }

    private var playToggle: some View {
        Button(action: manager.togglePlayPause) {
            Image(systemName: manager.isLoading
                  ? "circle.dashed"
                  : (manager.isPlaying ? "pause.fill" : "play.fill"))
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background {
                    if manager.isPlaying {
                        Circle()
                            .fill(NexusGradient.purple)
                            .shadow(color: NexusPalette.electricViolet.opacity(0.5), radius: 3, y: 1)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                Circle().strokeBorder(NexusPalette.glassTint.opacity(0.10), lineWidth: 0.5)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
    }

    private var surahName: some View {
        Text(manager.currentSurah.arabicName)
            .font(NexusTypography.body)
            .foregroundColor(NexusPalette.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .environment(\.layoutDirection, .rightToLeft)
    }
}
