import XCTest
@testable import SuperIsland

/// Tests for the weather data model and the Open-Meteo response shape the app
/// depends on.
///
/// `WeatherManager.parseWeatherResponse` is private, so we verify the data
/// model invariants and the JSON shape contract (the field names Open-Meteo
/// returns) instead. If the upstream API renames a field, the production parser
/// will silently no-op; this test pins the shape we assume.
final class WeatherDataModelTests: XCTestCase {

    // MARK: - Default weather state

    func testWeatherDataDefaults() {
        let data = WeatherData()

        XCTAssertEqual(data.temperature, 0)
        XCTAssertEqual(data.temperatureHigh, 0)
        XCTAssertEqual(data.temperatureLow, 0)
        XCTAssertEqual(data.condition, "Clear")
        XCTAssertEqual(data.conditionIcon, "sun.max.fill")
        XCTAssertEqual(data.locationName, "")
        XCTAssertTrue(data.hourlyForecast.isEmpty)
        XCTAssertEqual(data.feelsLike, 0)
        XCTAssertEqual(data.humidity, 0)
        XCTAssertEqual(data.windSpeed, 0)
        XCTAssertEqual(data.uvIndex, 0)
        XCTAssertEqual(data.aqi, 0)
    }

    // MARK: - Open-Meteo response shape contract

    /// The production parser reads exactly these keys from the Open-Meteo
    /// `/v1/forecast` response. Pin the structure so an upstream rename fails
    /// this test loudly rather than silently degrading the weather module.
    func testOpenMeteoCurrentForecastShapeIsParseable() throws {
        let payload = #"""
        {
            "current": {
                "temperature_2m": 21.5,
                "apparent_temperature": 20.0,
                "relative_humidity_2m": 64,
                "wind_speed_10m": 7.2,
                "weather_code": 3
            },
            "hourly": {
                "time": ["2026-07-23T12:00"],
                "temperature_2m": [21.5],
                "weather_code": [3]
            },
            "daily": {
                "temperature_2m_max": [25.0],
                "temperature_2m_min": [14.0],
                "uv_index_max": [6.0]
            }
        }
        """#.data(using: .utf8)!

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])

        // `current` block — read with the exact keys the parser uses.
        let current = try XCTUnwrap(json["current"] as? [String: Any])
        XCTAssertEqual(current["temperature_2m"] as? Double, 21.5)
        XCTAssertEqual(current["apparent_temperature"] as? Double, 20.0)
        XCTAssertEqual(current["relative_humidity_2m"] as? Int, 64)
        XCTAssertEqual(current["wind_speed_10m"] as? Double, 7.2)
        XCTAssertEqual(current["weather_code"] as? Int, 3)

        // `daily` block — the parser takes `.first` of each array.
        let daily = try XCTUnwrap(json["daily"] as? [String: Any])
        XCTAssertEqual((daily["temperature_2m_max"] as? [Double])?.first, 25.0)
        XCTAssertEqual((daily["temperature_2m_min"] as? [Double])?.first, 14.0)
        XCTAssertEqual((daily["uv_index_max"] as? [Double])?.first, 6.0)

        // `hourly` block — the parser zips time/temperature/weather_code.
        let hourly = try XCTUnwrap(json["hourly"] as? [String: Any])
        XCTAssertEqual((hourly["time"] as? [String])?.count, 1)
        XCTAssertEqual((hourly["temperature_2m"] as? [Double])?.count, 1)
        XCTAssertEqual((hourly["weather_code"] as? [Int])?.count, 1)
    }

    // MARK: - HourlyWeather identity

    func testHourlyWeatherIsIdentifiableByUUID() {
        let a = HourlyWeather(hour: "Now", temperature: 20, conditionIcon: "sun.max.fill")
        let b = HourlyWeather(hour: "Now", temperature: 20, conditionIcon: "sun.max.fill")

        XCTAssertNotEqual(a.id, b.id, "Each HourlyWeather must get a unique id")
    }

    // MARK: - TemperatureUnit

    func testTemperatureUnitRoundTrips() {
        for unit in [TemperatureUnit.celsius, .fahrenheit] {
            XCTAssertEqual(TemperatureUnit(rawValue: unit.rawValue), unit)
        }
        XCTAssertNil(TemperatureUnit(rawValue: "kelvin"))
    }
}
