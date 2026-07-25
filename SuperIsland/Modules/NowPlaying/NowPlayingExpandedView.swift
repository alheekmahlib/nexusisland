import SwiftUI

struct NowPlayingExpandedView: View {
    @ObservedObject private var manager = NowPlayingManager.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.currentState == .fullExpanded {
                fullView
            } else {
                compactExpandedView
            }
        }
    }

    // MARK: - Compact Expanded (360x80)

    private var compactExpandedView: some View {
        HStack(spacing: 12) {
            // Album art
            AlbumArtView(image: manager.albumArt, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(manager.title)
                    .font(NexusTypography.title)
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)

                Text(manager.artist)
                    .font(.system(size: 11))
                    .foregroundColor(NexusPalette.textSecondary)
                    .lineLimit(1)

                // Progress bar
                ProgressBar(
                    progress: manager.progress,
                    trackHeight: 3,
                    knobSize: 8
                ) { newProgress in
                    manager.seek(to: manager.duration * newProgress)
                }
            }

            // Play/Pause button
            NeonButton(
                systemName: manager.isPlaying ? "pause.fill" : "play.fill",
                size: 34
            ) {
                manager.togglePlayPause()
            }
        }
    }

    // MARK: - Full Expanded (400x200+)

    private var fullView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                AlbumArtView(image: manager.albumArt, size: 90)

                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.title)
                        .font(NexusTypography.subtitle)
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(2)

                    Text(manager.artist)
                        .font(NexusTypography.body)
                        .foregroundColor(NexusPalette.textSecondary)
                        .lineLimit(1)

                    Text(manager.album)
                        .font(NexusTypography.caption)
                        .foregroundColor(NexusPalette.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Progress bar with times
            VStack(spacing: 4) {
                ProgressBar(
                    progress: manager.progress,
                    trackHeight: 4,
                    knobSize: 12
                ) { newProgress in
                    manager.seek(to: manager.duration * newProgress)
                }

                HStack {
                    Text(manager.formattedElapsedTime)
                        .font(NexusTypography.mono)
                        .foregroundColor(NexusPalette.textTertiary)
                    Spacer()
                    Text(manager.formattedDuration)
                        .font(NexusTypography.mono)
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }

            // Playback controls
            HStack(spacing: 24) {
                NeonButton(systemName: "backward.fill", size: 30) { manager.previousTrack() }
                NeonButton(systemName: manager.isPlaying ? "pause.fill" : "play.fill", size: 44) {
                    manager.togglePlayPause()
                }
                NeonButton(systemName: "forward.fill", size: 30) { manager.nextTrack() }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    var trackHeight: CGFloat = 4
    var knobSize: CGFloat = 10
    var onSeek: ((Double) -> Void)? = nil

    @State private var dragProgress: Double?
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let displayedProgress = min(max(dragProgress ?? progress, 0), 1)
            let knobCenterX = min(
                max(CGFloat(displayedProgress) * geometry.size.width, knobSize / 2),
                max(knobSize / 2, geometry.size.width - (knobSize / 2))
            )
            let knobVisible = onSeek != nil && (isHovering || dragProgress != nil)
            let knobScale = (isHovering || dragProgress != nil) ? 1.08 : 1

            ZStack {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(NexusGradient.progress(at: displayedProgress))
                        .frame(width: max(0, geometry.size.width * CGFloat(displayedProgress)), height: trackHeight)
                        .shadow(color: NexusPalette.gradientMid.opacity(0.5), radius: 2, y: 1)
                        .animation(Constants.progressBar, value: displayedProgress)

                    Circle()
                        .fill(NexusPalette.accentGold)
                        .frame(width: knobSize, height: knobSize)
                        .scaleEffect(knobScale)
                        .shadow(color: NexusPalette.accentGold.opacity(0.6), radius: 3, y: 1)
                        .offset(x: knobCenterX - (knobSize / 2))
                        .opacity(knobVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.14), value: knobVisible)
                        .animation(.easeOut(duration: 0.14), value: knobScale)
                }
                .frame(height: knobSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard onSeek != nil, geometry.size.width > 0 else { return }
                        let nextProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = nextProgress
                    }
                    .onEnded { value in
                        guard let onSeek, geometry.size.width > 0 else { return }
                        let nextProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = nil
                        onSeek(nextProgress)
                    }
            )
        }
        .frame(height: max(knobSize, 16))
    }
}
