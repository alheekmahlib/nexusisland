import SwiftUI

struct WeatherCompactView: View {
    @ObservedObject private var manager = WeatherManager.shared
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: manager.weather.conditionIcon)
                .font(NexusTypography.caption(12, .medium))
                .foregroundColor(NexusPalette.textPrimary)

            Text(formattedTemp(manager.weather.temperature))
                .font(NexusTypography.caption(12, .medium))
                .foregroundColor(NexusPalette.textPrimary)
        }
    }

    private func formattedTemp(_ celsius: Double) -> String {
        switch appState.temperatureUnit {
        case .celsius:
            return "\(Int(celsius.rounded()))°C"
        case .fahrenheit:
            return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }
}
