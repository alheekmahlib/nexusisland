import SwiftUI

// MARK: - Quran Compact View (pill)
//
// The compact surface is only 200×36pt — narrower than most app icons. The
// whole row must fit on a single line. Layout: [play] [surah name] [progress
// hairline]. No vertical stacking; nothing that can wrap.

struct QuranCompactView: View {
    @ObservedObject private var manager = QuranManager.shared

    var body: some View {
        HStack(spacing: 6) {
            playToggle
            surahName
            // Hairline progress fills the remaining width.
            QuranHairlineProgress(progress: manager.progress)
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
                .foregroundColor(manager.isPlaying ? QuranDesign.accent : QuranDesign.textPrimary)
                .frame(width: 20, height: 20)
                .background(
                    Circle().fill(manager.isPlaying ? QuranDesign.accentSoft : QuranDesign.surfaceFill)
                )
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
    }

    private var surahName: some View {
        Text(manager.currentSurah.arabicName)
            .font(QuranDesign.surahName(12))
            .foregroundColor(QuranDesign.textPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

/// A non-interactive hairline that just visualizes progress in the tight
/// compact row. Dragging lives in the expanded views where there's room.
struct QuranHairlineProgress: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(QuranDesign.surfaceStroke)
                Capsule()
                    .fill(QuranDesign.accent.opacity(0.85))
                    .frame(width: proxy.size.width * progress)
            }
        }
    }
}
