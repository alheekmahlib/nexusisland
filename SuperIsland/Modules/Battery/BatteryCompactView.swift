import SwiftUI

// MARK: - Battery Compact View (pill)
//
// Redesigned with NexusDesign tokens. The compact row sits on the black notch
// surface, so it stays legible and restrained: a status-tinted icon + the
// percentage in the mono typeface.

struct BatteryCompactView: View {
    @ObservedObject private var manager = BatteryManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: manager.batteryIconName)
                .font(.system(size: 14))
                .foregroundColor(batteryColor)
                .symbolEffect(.pulse, isActive: manager.isLowBattery)

            Text("\(manager.batteryLevel)%")
                .font(NexusTypography.mono)
                .foregroundColor(NexusPalette.textPrimary)
        }
    }

    private var batteryColor: Color {
        if manager.isCharging { return NexusPalette.success }
        if manager.batteryLevel <= 10 { return NexusPalette.danger }
        if manager.batteryLevel <= 20 { return NexusPalette.warning }
        return NexusPalette.textPrimary
    }
}
