import SwiftUI

// MARK: - Quran Progress Bar (RTL-aware, draggable)
//
// A dedicated progress bar for the Quran module. The shared NowPlaying
// ProgressBar assumes LTR: dragging rightward raises progress. In our RTL
// layout the visual fill grows from the right, so we must invert the drag
// fraction (1 - x/width) for the gesture to feel correct — dragging toward
// the leading (right) edge seeks backward, toward the trailing (left) edge
// seeks forward.
//
// Design: a thin gold track with a gold fill, a knob that appears on hover /
// drag, and smooth state during active dragging so the UI tracks the finger.

struct QuranProgressBar: View {
    let progress: Double
    var trackHeight: CGFloat = 4
    var knobSize: CGFloat = 12
    var onSeek: ((Double) -> Void)? = nil
    var isRTL: Bool = true

    @State private var dragProgress: Double?
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let displayedProgress = min(max(dragProgress ?? progress, 0), 1)
            let width = geometry.size.width
            // In RTL, the visual fill grows from the right edge leftward, so the
            // knob's x offset is measured from the right.
            let rawX = CGFloat(displayedProgress) * width
            let knobCenterX = min(max(rawX, knobSize / 2), max(knobSize / 2, width - knobSize / 2))
            let knobVisible = onSeek != nil && (isHovering || dragProgress != nil)
            let knobScale = (isHovering || dragProgress != nil) ? 1.1 : 1

            ZStack {
                // Track (full width, subtle).
                Capsule()
                    .fill(QuranDesign.surfaceStroke)
                    .frame(height: trackHeight)

                // Fill — in RTL we anchor it to the trailing (right) edge.
                Capsule()
                    .fill(QuranDesign.accent.opacity(0.9))
                    .frame(width: max(0, rawX), height: trackHeight)
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .animation(Constants.progressBar, value: displayedProgress)

                // Knob.
                Circle()
                    .fill(QuranDesign.accent)
                    .frame(width: knobSize, height: knobSize)
                    .scaleEffect(knobScale)
                    .shadow(color: QuranDesign.accent.opacity(0.5), radius: 3, y: 1)
                    // Position the knob along the same axis as the fill edge.
                    .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                    .padding(.leading, isRTL ? 0 : max(0, knobCenterX - knobSize / 2))
                    .padding(.trailing, isRTL ? max(0, width - knobCenterX - knobSize / 2) : 0)
                    .opacity(knobVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.14), value: knobVisible)
                    .animation(.easeOut(duration: 0.14), value: knobScale)
            }
            .frame(height: max(knobSize, trackHeight + 8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard onSeek != nil, width > 0 else { return }
                        let physicalFraction = min(max(value.location.x / width, 0), 1)
                        // RTL inversion: a tap on the right (high x) should map
                        // to LOW progress because the fill starts on the right.
                        dragProgress = isRTL ? 1 - physicalFraction : physicalFraction
                    }
                    .onEnded { value in
                        guard let onSeek, width > 0 else { return }
                        let physicalFraction = min(max(value.location.x / width, 0), 1)
                        let resolved = isRTL ? 1 - physicalFraction : physicalFraction
                        dragProgress = nil
                        onSeek(resolved)
                    }
            )
        }
        .frame(height: max(knobSize, 16))
    }
}
