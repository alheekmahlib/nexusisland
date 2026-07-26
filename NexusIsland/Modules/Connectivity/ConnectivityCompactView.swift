import SwiftUI

struct ConnectivityCompactView: View {
    @ObservedObject private var bluetooth = BluetoothManager.shared
    @ObservedObject private var wifi = WiFiManager.shared

    var body: some View {
        HStack(spacing: 6) {
            if let device = bluetooth.lastConnectedDevice {
                Image(systemName: device.deviceType.iconName)
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textPrimary)

                Text(device.name)
                    .font(NexusTypography.caption(11, .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)
            } else if let disconnectedName = bluetooth.lastDisconnectedDeviceName {
                Image(systemName: "link.badge.plus")
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textTertiary)

                Text(disconnectedName)
                    .font(NexusTypography.caption(11))
                    .foregroundColor(NexusPalette.textTertiary)
                    .lineLimit(1)
                    .strikethrough()
            } else {
                Image(systemName: wifi.signalIconName)
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textPrimary)

                if let ssid = wifi.ssid {
                    Text(ssid)
                        .font(NexusTypography.caption(11, .medium))
                        .foregroundColor(NexusPalette.textPrimary)
                        .lineLimit(1)
                }
            }
        }
    }
}
