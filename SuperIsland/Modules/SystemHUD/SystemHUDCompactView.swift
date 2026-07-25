import SwiftUI

struct SystemHUDCompactView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var volumeManager = VolumeManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(NexusTypography.caption(12, .semibold))
                .foregroundColor(NexusPalette.textPrimary)

            // Slim progress bar
            GradientProgressBar(progress: Double(currentValue), style: .hairline, gradient: NexusGradient.primary)
                .frame(maxWidth: 80, maxHeight: 4)

            Text("\(currentPercentage)%")
                .font(NexusTypography.mono(10))
                .foregroundColor(NexusPalette.textSecondary)
        }
    }

    private var iconName: String {
        switch appState.activeBuiltInModule {
        case .volumeHUD:
            return volumeManager.volumeIconName
        default:
            return "speaker.wave.2.fill"
        }
    }

    private var currentValue: Float {
        switch appState.activeBuiltInModule {
        case .volumeHUD:
            return volumeManager.volume
        default:
            return 0
        }
    }

    private var currentPercentage: Int {
        Int(currentValue * 100)
    }
}
