import SwiftUI

struct ConnectivityExpandedView: View {
    @ObservedObject private var bluetooth = BluetoothManager.shared
    @ObservedObject private var wifi = WiFiManager.shared

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            primaryStatus

            // Connected devices list (full expanded)
            if appState.currentState == .fullExpanded && (!bluetooth.connectedDevices.isEmpty || wifi.isConnected) {
                Divider().background(NexusPalette.glassTint.opacity(0.2))

                ForEach(bluetooth.connectedDevices) { device in
                    HStack(spacing: 8) {
                        Image(systemName: device.deviceType.iconName)
                            .font(NexusTypography.body(14))
                            .foregroundColor(NexusPalette.textSecondary)
                            .frame(width: 20)

                        Text(device.name)
                            .font(NexusTypography.body(12))
                            .foregroundColor(NexusPalette.textPrimary)

                        Spacer()

                        Circle()
                            .fill(NexusPalette.success)
                            .frame(width: 6, height: 6)
                    }
                }

                // WiFi info
                if wifi.isConnected, let ssid = wifi.ssid {
                    HStack(spacing: 8) {
                        Image(systemName: wifi.signalIconName)
                            .font(NexusTypography.body(14))
                            .foregroundColor(NexusPalette.electricViolet)
                            .frame(width: 20)

                        Text(ssid)
                            .font(NexusTypography.body(12))
                            .foregroundColor(NexusPalette.textPrimary)

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: appState.currentState == .fullExpanded ? .topLeading : .center)
    }

    @ViewBuilder
    private var primaryStatus: some View {
        if let device = bluetooth.lastConnectedDevice {
            statusRow(
                icon: device.deviceType.iconName,
                status: NSLocalizedString("Connected", comment: "Connectivity status"),
                statusColor: NexusPalette.success,
                isActive: true,
                title: device.name,
                detail: device.batteryLevel.map { "Battery \($0)%" }
            )
        } else if let disconnectedName = bluetooth.lastDisconnectedDeviceName {
            statusRow(
                icon: "link.badge.plus",
                status: NSLocalizedString("Disconnected", comment: "Connectivity status"),
                statusColor: NexusPalette.danger,
                isActive: false,
                title: disconnectedName,
                detail: "Bluetooth device"
            )
        } else if wifi.isConnected, let ssid = wifi.ssid {
            statusRow(
                icon: wifi.signalIconName,
                status: NSLocalizedString("Wi-Fi Connected", comment: "Connectivity status"),
                statusColor: NexusPalette.electricViolet,
                isActive: true,
                title: ssid,
                detail: wifi.signalDescription
            )
        } else {
            statusRow(
                icon: "wifi.slash",
                status: NSLocalizedString("Offline", comment: "Connectivity status"),
                statusColor: NexusPalette.textTertiary,
                isActive: false,
                title: NSLocalizedString("No active connection", comment: "Connectivity offline title"),
                detail: bluetooth.connectedDevices.isEmpty ? NSLocalizedString("Wi-Fi and Bluetooth are idle", comment: "Connectivity offline detail") : "\(bluetooth.connectedDevices.count) Bluetooth device\(bluetooth.connectedDevices.count == 1 ? "" : "s") connected"
            )
        }
    }

    private func statusRow(
        icon: String,
        status: String,
        statusColor: Color,
        isActive: Bool = false,
        title: String,
        detail: String?
    ) -> some View {
        HStack(spacing: 12) {
            GradientMedallion(systemName: icon, size: 38, gradient: NexusGradient.purple, isActive: isActive)

            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(NexusTypography.mono(10))
                    .foregroundColor(statusColor)

                Text(title)
                    .font(NexusTypography.title(14))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(NexusTypography.caption(11))
                        .foregroundColor(NexusPalette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
}
