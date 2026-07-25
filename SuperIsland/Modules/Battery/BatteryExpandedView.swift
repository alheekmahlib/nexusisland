import SwiftUI

// MARK: - Battery Expanded / FullExpanded Views
//
// Redesigned with NexusDesign: GlassCard surfaces, a gradient progress bar
// that warms toward orange as the level rises, and Swift Charts sparkline
// (SparklineChart) replacing the hand-rolled BatteryHistorySparkline Path.

struct BatteryExpandedView: View {
    @ObservedObject private var manager = BatteryManager.shared
    @EnvironmentObject var appState: AppState

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        Group {
            if appState.currentState == .fullExpanded {
                fullExpandedView
            } else {
                defaultExpandedView
            }
        }
        .opacity(manager.isLowBattery ? pulseOpacity : 1.0)
        .onAppear {
            if manager.isLowBattery {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.6
                }
            }
        }
    }

    private var defaultExpandedView: some View {
        HStack(spacing: 16) {
            ZStack {
                Image(systemName: manager.batteryIconName)
                    .font(.system(size: 32))
                    .foregroundColor(batteryColor)
                    .symbolEffect(.bounce, value: manager.isCharging)

                if manager.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(NexusPalette.warning)
                        .offset(y: -1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(manager.batteryLevel)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(NexusPalette.textPrimary)

                    Spacer()

                    Text(manager.powerSource)
                        .font(NexusTypography.caption)
                        .foregroundColor(NexusPalette.textTertiary)
                }

                GradientProgressBar(
                    progress: Double(manager.batteryLevel) / 100,
                    style: .thick,
                    height: 6,
                    gradient: NexusGradient.progress(at: Double(manager.batteryLevel) / 100)
                )

                if !manager.timeRemaining.isEmpty {
                    Text(manager.timeRemaining)
                        .font(NexusTypography.caption)
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }
        }
    }

    private var fullExpandedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Image(systemName: manager.batteryIconName)
                        .font(.system(size: 24))
                        .foregroundColor(batteryColor)
                        .symbolEffect(.bounce, value: manager.isCharging)

                    if manager.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(NexusPalette.warning)
                    }
                }

                Text("\(manager.batteryLevel)%")
                    .font(NexusTypography.numeric(28))
                    .foregroundColor(NexusPalette.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(manager.powerSource)
                        .font(NexusTypography.caption)
                        .foregroundColor(NexusPalette.textSecondary)
                    if !manager.timeRemaining.isEmpty {
                        Text(manager.timeRemaining)
                            .font(NexusTypography.caption)
                            .foregroundColor(NexusPalette.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            GradientProgressBar(
                progress: Double(manager.batteryLevel) / 100,
                style: .thick,
                height: 8,
                gradient: NexusGradient.progress(at: Double(manager.batteryLevel) / 100)
            )

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("Battery Trend", comment: "Battery trend sparkline title"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(NexusPalette.textSecondary)

                batteryTrendChart
                    .frame(height: 52)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Swift Charts sparkline when we have enough samples; empty-state otherwise.
    @ViewBuilder
    private var batteryTrendChart: some View {
        let samples = manager.batteryHistory
        if samples.count >= 2 {
            ZStack {
                RoundedRectangle(cornerRadius: NexusMetrics.cornerRadiusS)
                    .fill(Color.white.opacity(0.08))
                SparklineChart(values: samples.map { Double($0.level) })
                    .padding(4)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: NexusMetrics.cornerRadiusS)
                    .fill(Color.white.opacity(0.08))
                Text(NSLocalizedString("Need more samples", comment: "Battery sparkline empty state"))
                    .font(.system(size: 9))
                    .foregroundColor(NexusPalette.textTertiary)
            }
        }
    }

    private var batteryColor: Color {
        if manager.isCharging { return NexusPalette.success }
        if manager.batteryLevel <= 10 { return NexusPalette.danger }
        if manager.batteryLevel <= 20 { return NexusPalette.warning }
        return NexusPalette.textPrimary
    }
}
