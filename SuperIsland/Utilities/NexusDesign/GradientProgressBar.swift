import SwiftUI

// MARK: - NexusDesign: GradientProgressBar
//
// A single progress component for the whole app, replacing the four scattered
// ones (NowPlaying.ProgressBar, QuranProgressBar, QuranHairlineProgress,
// PrayerProgressBar, PrayerProgressHairline). Supports a hairline (compact
// pill), a thick bar (expanded), and a circular ring (fullExpanded gauges).
// All variants fill with the vibrant gradient and carry a soft glow.

struct GradientProgressBar: View {
    enum Style { case hairline, thick, circular }

    var progress: Double
    var style: Style = .thick
    var height: CGFloat = 6
    var gradient: LinearGradient = NexusGradient.primary
    var animated: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        switch style {
        case .hairline: hairline
        case .thick:    thick
        case .circular: circular
        }
    }

    private var hairline: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(gradient)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: NexusPalette.gradientMid.opacity(0.6), radius: 2)
            }
        }
        .frame(height: 2)
    }

    private var thick: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2).fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(gradient)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: NexusPalette.gradientMid.opacity(0.5), radius: 3)
            }
        }
        .frame(height: height)
        .animation(animated ? .easeInOut(duration: 0.3) : nil, value: clamped)
    }

    private var circular: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: height)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(gradient, style: StrokeStyle(lineWidth: height, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: NexusPalette.gradientMid.opacity(0.5), radius: 3)
        }
        .animation(animated ? .easeInOut(duration: 0.3) : nil, value: clamped)
    }
}
