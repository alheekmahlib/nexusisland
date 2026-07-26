import SwiftUI

struct WeatherExpandedView: View {
    @ObservedObject private var manager = WeatherManager.shared
    @EnvironmentObject var appState: AppState

    private func temp(_ celsius: Double) -> String {
        switch appState.temperatureUnit {
        case .celsius:    return "\(Int(celsius.rounded()))°C"
        case .fahrenheit: return "\(Int((celsius * 9 / 5 + 32).rounded()))°F"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current weather
            HStack(spacing: 12) {
                GradientMedallion(systemName: manager.weather.conditionIcon, size: 38, gradient: NexusGradient.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(temp(manager.weather.temperature))
                        .font(NexusTypography.numeric(22))
                        .foregroundColor(NexusPalette.textPrimary)

                    Text(manager.weather.condition)
                        .font(NexusTypography.body(12))
                        .foregroundColor(NexusPalette.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("H:\(temp(manager.weather.temperatureHigh))")
                        .font(NexusTypography.caption(11))
                        .foregroundColor(NexusPalette.textSecondary)
                    Text("L:\(temp(manager.weather.temperatureLow))")
                        .font(NexusTypography.caption(11))
                        .foregroundColor(NexusPalette.textSecondary)
                }
            }

            // Location
            if !manager.weather.locationName.isEmpty {
                Text(manager.weather.locationName)
                    .font(NexusTypography.mono(10))
                    .foregroundColor(NexusPalette.textTertiary)
            }

            if appState.currentState == .fullExpanded {
                Divider().background(NexusPalette.glassTint.opacity(0.2))

                // Hourly forecast + details side by side
                HStack(alignment: .top, spacing: 0) {
                    // Hourly forecast (left)
                    if !manager.weather.hourlyForecast.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(manager.weather.hourlyForecast) { hour in
                                    VStack(spacing: 4) {
                                        Text(hour.hour)
                                            .font(NexusTypography.mono(10))
                                            .foregroundColor(NexusPalette.textSecondary)

                                        Image(systemName: hour.conditionIcon)
                                            .font(NexusTypography.body(14))
                                            .foregroundColor(NexusPalette.textPrimary)

                                        Text(temp(hour.temperature))
                                            .font(NexusTypography.numeric(11))
                                            .foregroundColor(NexusPalette.textPrimary)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 16)

                    // Weather details grid (right)
                    weatherDetailsGrid
                }
            }
        }
    }

    private var weatherDetailsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                weatherDetailCell(icon: "thermometer.medium", title: NSLocalizedString("Feels Like", comment: "Weather detail label"), value: temp(manager.weather.feelsLike))
                weatherDetailCell(icon: "humidity.fill", title: NSLocalizedString("Humidity", comment: "Weather detail label"), value: "\(manager.weather.humidity)%")
                weatherDetailCell(icon: "aqi.medium", title: NSLocalizedString("AQI", comment: "Weather detail label"), value: aqiLabel)
            }
            HStack(spacing: 16) {
                weatherDetailCell(icon: "wind", title: NSLocalizedString("Wind", comment: "Weather detail label"), value: "\(Int(manager.weather.windSpeed)) mph")
                weatherDetailCell(icon: "sun.max.trianglebadge.exclamationmark.fill", title: NSLocalizedString("UV Index", comment: "Weather detail label"), value: uvLabel)
                Spacer()
            }
        }
    }

    private func weatherDetailCell(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(NexusTypography.caption(11, .medium))
                .foregroundColor(NexusPalette.textTertiary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(NexusTypography.caption(9, .medium))
                    .foregroundColor(NexusPalette.textTertiary)
                Text(value)
                    .font(NexusTypography.title(12))
                    .foregroundColor(NexusPalette.textSecondary)
            }
        }
    }

    private var uvLabel: String {
        let uv = manager.weather.uvIndex
        let level: String
        switch uv {
        case ..<3: level = "Low"
        case ..<6: level = "Mod"
        case ..<8: level = "High"
        case ..<11: level = "Very High"
        default: level = "Extreme"
        }
        return "\(Int(uv)) \(level)"
    }

    private var aqiLabel: String {
        let aqi = manager.weather.aqi
        if aqi == 0 { return "—" }
        let level: String
        switch aqi {
        case ..<51: level = "Good"
        case ..<101: level = "Moderate"
        case ..<151: level = "Unhealthy*"
        case ..<201: level = "Unhealthy"
        case ..<301: level = "Very Poor"
        default: level = "Hazardous"
        }
        return "\(aqi) \(level)"
    }
}
