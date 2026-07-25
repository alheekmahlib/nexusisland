import SwiftUI

// MARK: - Quran Compact View (pill)
//
// Redesigned with NexusDesign tokens. The compact surface is only 200×36pt,
// so the row must fit on a single line: [play] [surah name] [gradient hairline].

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
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background {
                    if manager.isPlaying {
                        Circle().fill(NexusGradient.purple)
                    } else {
                        Circle().fill(Color.white.opacity(0.14))
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
