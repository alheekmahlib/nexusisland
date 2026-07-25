import SwiftUI
import AppKit

struct SystemHUDExpandedView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var volumeManager = VolumeManager.shared

    @State private var overshootScale: CGFloat = 1.0

    var body: some View {
        Group {
            if appState.activeBuiltInModule == .volumeHUD && appState.currentState == .fullExpanded {
                fullExpandedVolumeView
            } else {
                defaultHUDView
            }
        }
        .onChange(of: currentValue) { _, newValue in
            if newValue <= 0 || newValue >= 1.0 {
                triggerOvershoot()
            }
        }
    }

    private var defaultHUDView: some View {
        HStack(spacing: 16) {
            GradientMedallion(systemName: iconName, size: 38, gradient: NexusGradient.purple)
                .scaleEffect(overshootScale)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(NexusTypography.title(13))
                        .foregroundColor(NexusPalette.textPrimary)

                    Spacer()

                    Text("\(currentPercentage)%")
                        .font(NexusTypography.mono(13))
                        .foregroundColor(NexusPalette.textSecondary)
                }

                SliderBar(value: currentBinding)
                    .frame(height: 6)

                if appState.activeBuiltInModule == .volumeHUD {
                    Text(volumeManager.outputDeviceName)
                        .font(NexusTypography.mono(10))
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }
        }
    }

    private var fullExpandedVolumeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: volumeManager.volumeIconName)
                    .font(NexusTypography.title(18))
                    .foregroundColor(NexusPalette.textPrimary)
                    .scaleEffect(overshootScale)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(NSLocalizedString("System Volume", comment: "System HUD volume header"))
                            .font(NexusTypography.title(12))
                            .foregroundColor(NexusPalette.textPrimary)
                        Spacer()
                        Text("\(volumeManager.volumePercentage)%")
                            .font(NexusTypography.mono(12))
                            .foregroundColor(NexusPalette.textSecondary)
                    }
                    SliderBar(value: currentBinding)
                        .frame(height: 6)
                }
            }

            Text(volumeManager.outputDeviceName)
                .font(NexusTypography.mono(10))
                .foregroundColor(NexusPalette.textTertiary)

            Divider()
                .overlay(NexusPalette.glassTint.opacity(0.15))

            Text(NSLocalizedString("Media Apps", comment: "System HUD media apps header"))
                .font(NexusTypography.caption(11, .semibold))
                .foregroundColor(NexusPalette.textPrimary)

            if volumeManager.mediaAppVolumes.isEmpty {
                Text(NSLocalizedString("No supported media apps are currently playing.", comment: "System HUD empty media apps state"))
                    .font(NexusTypography.caption(11))
                    .foregroundColor(NexusPalette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(volumeManager.mediaAppVolumes.prefix(5)) { app in
                            MediaAppVolumeRow(app: app) { newValue in
                                volumeManager.setMediaAppVolume(appID: app.id, volume: newValue)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 106)
            }
        }
        .onAppear {
            volumeManager.refreshMediaAppVolumes()
        }
    }

    private var iconName: String {
        switch appState.activeBuiltInModule {
        case .volumeHUD: return volumeManager.volumeIconName
        default: return "speaker.wave.2.fill"
        }
    }

    private var label: String {
        switch appState.activeBuiltInModule {
        case .volumeHUD: return "Volume"
        default: return ""
        }
    }

    private var currentValue: Float {
        switch appState.activeBuiltInModule {
        case .volumeHUD: return volumeManager.volume
        default: return 0
        }
    }

    private var currentPercentage: Int {
        Int(currentValue * 100)
    }

    private var currentBinding: Binding<Float> {
        switch appState.activeBuiltInModule {
        case .volumeHUD:
            return Binding(
                get: { volumeManager.volume },
                set: { volumeManager.setVolume($0) }
            )
        default:
            return .constant(0)
        }
    }

    private func triggerOvershoot() {
        withAnimation(Constants.overshootBounce) {
            overshootScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Constants.overshootBounce) {
                overshootScale = 1.0
            }
        }
    }
}

private struct MediaAppVolumeRow: View {
    let app: MediaAppVolume
    let onChange: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let appIcon = appIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: app.iconName)
                        .font(NexusTypography.caption(10, .semibold))
                        .foregroundColor(NexusPalette.textSecondary)
                        .frame(width: 14)
                }

                Text(app.appName)
                    .font(NexusTypography.caption(11, .medium))
                    .foregroundColor(NexusPalette.textPrimary)

                Spacer()

                Text(app.statusText)
                    .font(NexusTypography.mono(10))
                    .foregroundColor(app.isPlaying ? NexusPalette.success : NexusPalette.textSecondary)

                Text("\(Int(app.volume * 100))%")
                    .font(NexusTypography.mono(10))
                    .foregroundColor(NexusPalette.textSecondary)
            }

            SliderBar(
                value: Binding(
                    get: { app.volume },
                    set: { onChange($0) }
                )
            )
            .frame(height: 5)
        }
    }

    private var appIconImage: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

// MARK: - Slider Bar

struct SliderBar: View {
    @Binding var value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.12))

                RoundedRectangle(cornerRadius: 3)
                    .fill(NexusGradient.primary)
                    .frame(width: max(0, geometry.size.width * CGFloat(min(value, 1.0))))
                    .animation(Constants.progressBar, value: value)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Float(drag.location.x / geometry.size.width)
                        value = max(0, min(1, newValue))
                    }
            )
        }
    }
}
