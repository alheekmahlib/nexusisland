import Combine
import CoreLocation
import Foundation
import SwiftUI

// MARK: - Prayer Times Models

/// One of the daily prayer times. Matches Aladhan's `data.timings` keys.
/// Order matters — it's the canonical daily sequence used by nextPrayer().
enum PrayerKind: String, CaseIterable, Identifiable {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    var id: String { rawValue }

    /// Arabic display name.
    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    /// Short Arabic label for tight progress-bar endpoints (without the "ال").
    var arabicShortName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    /// SF Symbol representing the time of day.
    var iconName: String {
        switch self {
        case .fajr: return "sun.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.max.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    /// True for the five obligatory prayers (Sunrise is informational only).
    var isObligatory: Bool { self != .sunrise }
}

/// All six timings for a single day, keyed by PrayerKind.
struct PrayerSchedule: Equatable {
    let dateKey: String           // "dd-MM-yyyy" (matches Aladhan's path format)
    let times: [PrayerKind: Date] // today's Date for each prayer
    let hijriDate: String?        // "15 محرم 1448"
    /// The timezone the API returned the times in (from `data.meta.timezone`).
    /// The Date values in `times` are unambiguous instants constructed in THIS
    /// timezone — never the device's. Traveling users (device tz ≠ location tz)
    /// used to see every prayer shifted by the tz delta because the device tz
    /// was used to interpret the wall-clock string. May be nil on legacy cache.
    /// Default of `.current` keeps direct-construction call sites simple when the
    /// timezone isn't relevant (e.g. ordering/progress unit tests).
    var timeZone: TimeZone? = TimeZone.current

    /// Resolve the next upcoming prayer relative to `now`, plus the current
    /// one if we're inside its window. Returns nil if no data is loaded.
    func nextPrayer(now: Date) -> (kind: PrayerKind, date: Date)? {
        let ordered: [PrayerKind] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        for kind in ordered {
            if let time = times[kind], time > now {
                return (kind, time)
            }
        }
        // All of today's prayers passed → next is tomorrow's Fajr (approx).
        if let fajr = times[.fajr],
           let tomorrowFajr = Calendar.current.date(byAdding: .day, value: 1, to: fajr) {
            return (kind: .fajr, date: tomorrowFajr)
        }
        return nil
    }

    /// The most recent prayer that has already started, relative to `now`.
    /// Used to compute the inter-prayer progress fraction. Returns nil if we
    /// are before the first prayer of the day.
    func previousPrayer(now: Date) -> (kind: PrayerKind, date: Date)? {
        let ordered: [PrayerKind] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        var last: (PrayerKind, Date)?
        for kind in ordered {
            // Use strict < so that at the exact instant of a prayer, that
            // prayer becomes "next" (not previous) — keeps the interval logic
            // consistent at boundaries.
            if let time = times[kind], time < now {
                last = (kind, time)
            }
        }
        // If none today, we're before Fajr → previous is yesterday's Isha.
        if last == nil, let isha = times[.isha],
           let yesterdayIsha = Calendar.current.date(byAdding: .day, value: -1, to: isha) {
            return (kind: .isha, date: yesterdayIsha)
        }
        return last.map { (kind: $0.0, date: $0.1) }
    }

    /// Fraction of the current inter-prayer interval that has elapsed,
    /// 0...1. Drives the progress bar between the previous and next prayer.
    /// Returns nil if either boundary is unknown.
    func intervalProgress(now: Date) -> Double? {
        guard let next = nextPrayer(now: now),
              let prev = previousPrayer(now: now) else { return nil }
        let total = next.date.timeIntervalSince(prev.date)
        guard total > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(prev.date)
        return min(1, max(0, elapsed / total))
    }

    static let empty = PrayerSchedule(dateKey: "", times: [:], hijriDate: nil, timeZone: nil)
}

// MARK: - Calculation Method

/// Aladhan calculation method ids (the `method` query param).
enum PrayerCalculationMethod: String, CaseIterable, Identifiable {
    case muslimWorldLeague = "3"
    case ummAlQura = "4"
    case egyptian = "5"
    case gulf = "8"
    case karachi = "1"
    case isna = "2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .ummAlQura: return "Umm Al-Qura (Makkah)"
        case .egyptian: return "Egyptian Authority"
        case .gulf: return "Gulf Region"
        case .karachi: return "Karachi"
        case .isna: return "ISNA (North America)"
        }
    }
}

// MARK: - Prayer Times Manager

/// Native module that fetches and displays daily prayer times. Mirrors the
/// prayer-times extension's settings (same UserDefaults keys) so the native
/// module and the notification-feed extension share one configuration.
///
/// Location: by default uses the device's GPS (CoreLocation, like Weather) so
/// the user never has to enter coordinates. A manual override is supported for
/// cases where location permission is denied or the user wants a fixed city.
///
/// Follows the project manager-singleton convention: @MainActor ObservableObject
/// with static let shared, registered in ModuleType.
@MainActor
final class PrayerTimesManager: NSObject, ObservableObject {
    static let shared = PrayerTimesManager()

    // MARK: - Published state

    @Published private(set) var schedule: PrayerSchedule = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    /// Human-readable city name from reverse-geocoding the resolved location.
    @Published private(set) var locationName: String = ""

    // MARK: - Settings (shared with the extension via UserDefaults)

    /// When true (default), use CoreLocation to determine coordinates automatically.
    /// When false, fall back to the manual latitude/longitude fields.
    @AppStorage("prayerTimes.useAutoLocation") var useAutoLocation: Bool = true
    /// Manual override latitude. Default: Riyadh.
    @AppStorage("prayerTimes.manualLatitude") var manualLatitude: Double = 24.7136
    /// Manual override longitude. Default: Riyadh.
    @AppStorage("prayerTimes.manualLongitude") var manualLongitude: Double = 46.6753
    /// Calculation method id (matches PrayerCalculationMethod).
    @AppStorage("calcMethod") private var calcMethodRaw: String = PrayerCalculationMethod.ummAlQura.rawValue

    var calculationMethod: PrayerCalculationMethod {
        PrayerCalculationMethod(rawValue: calcMethodRaw) ?? .ummAlQura
    }

    /// Update the calculation method and reload timings.
    func setCalculationMethod(_ method: PrayerCalculationMethod) {
        calcMethodRaw = method.rawValue
        schedule = .empty
        fetchTimings()
    }

    /// The coordinates currently in effect, prioritizing a fresh fix when
    /// auto-location is enabled. Published so the UI can show which location
    /// the times are computed for.
    @Published private(set) var resolvedLatitude: Double = 24.7136
    @Published private(set) var resolvedLongitude: Double = 46.6753
    /// True when CoreLocation has provided a real fix (not the default Riyadh).
    @Published private(set) var hasLocationFix = false

    private let locationManager = CLLocationManager()
    private var lastLocationFix: Date?
    private var hasFetchedFromLocation = false
    private var refreshToken: ModuleRefreshToken?
    private let defaults = UserDefaults.standard
    /// Coordinates the currently-cached schedule was fetched for. Used by
    /// `shouldRefetch` to detect when a fresh GPS fix points to a different
    /// city than the one we already have timings for.
    private var lastFetchedLatitude: Double?
    private var lastFetchedLongitude: Double?

    // MARK: - Init

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        // Seed with manual coords so we can fetch immediately even before the
        // first GPS fix arrives.
        resolvedLatitude = manualLatitude
        resolvedLongitude = manualLongitude

        requestLocationAndFetch()
        registerRefresh()
    }

    // MARK: - Settings changes

    /// Call when the user changes location/method settings to reload immediately.
    /// When auto-location is turned off, the manual coordinates take effect.
    func settingsDidChange() {
        schedule = .empty
        // Clear cached coords so shouldRefetch() returns true for the new value
        // (otherwise the same-day guard would suppress the reload).
        lastFetchedLatitude = nil
        lastFetchedLongitude = nil
        hasFetchedFromLocation = false
        if useAutoLocation {
            requestLocationAndFetch()
        } else {
            resolvedLatitude = manualLatitude
            resolvedLongitude = manualLongitude
            fetchTimings()
        }
    }

    // MARK: - Location (CoreLocation, mirrors WeatherManager)

    /// Request a fresh location fix and fetch timings once we have one.
    func requestLocationAndFetch() {
        guard useAutoLocation else {
            resolvedLatitude = manualLatitude
            resolvedLongitude = manualLongitude
            fetchTimings()
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .authorized:
            locationManager.startUpdatingLocation()
            // Fetch immediately with current/default coords so the UI isn't
            // empty while waiting for the GPS fix. Updates when fix arrives.
            fetchTimings()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // CRITICAL: fetch with default coords NOW so the UI isn't blank
            // while waiting for the permission dialog. locationManagerDidChangeAuthorization
            // will re-fetch with real coords once granted.
            fetchTimings()
        default:
            // Denied/restricted — fall back to manual coords and fetch anyway.
            resolvedLatitude = manualLatitude
            resolvedLongitude = manualLongitude
            fetchTimings()
        }
    }

    // MARK: - Fetching (Aladhan API)

    /// Decide whether a new fetch is needed given the currently-cached state
    /// and the coordinates we're about to fetch for. Pure (testable).
    ///
    /// The historical bug: `fetchTimings()` only checked `schedule.dateKey ==
    /// today`, so once the seeded Riyadh default filled the cache, a later GPS
    /// fix for a *different* city was silently ignored for the rest of the day.
    /// Users outside Riyadh with auto-location enabled permanently saw Riyadh's
    /// times. We now also refetch whenever the new coordinates differ from the
    /// cached ones by more than a small jitter threshold (~100m).
    static func shouldRefetch(
        currentDateKey: String,
        lastLatitude: Double?,
        lastLongitude: Double?,
        newLatitude: Double,
        newLongitude: Double,
        todayKey: String
    ) -> Bool {
        // No data yet, or a new day → always refetch.
        if currentDateKey != todayKey { return true }

        // Same day — only refetch if the location actually moved enough to
        // change the prayer times. <0.01° is roughly 1 km; we treat anything
        // under 0.001° (~100 m) as GPS jitter to avoid a refetch storm.
        guard let lat = lastLatitude, let lng = lastLongitude else { return true }
        let delta = max(abs(newLatitude - lat), abs(newLongitude - lng))
        return delta > 0.001
    }

    func fetchTimings() {
        guard !isLoading else { return }
        let key = Self.todayKey()
        // Refetch on a new day OR when the resolved coordinates have moved
        // enough to change the times (e.g. the first real GPS fix after the
        // Riyadh default). This is the fix for users outside Riyadh.
        guard Self.shouldRefetch(
            currentDateKey: schedule.dateKey,
            lastLatitude: lastFetchedLatitude,
            lastLongitude: lastFetchedLongitude,
            newLatitude: resolvedLatitude,
            newLongitude: resolvedLongitude,
            todayKey: key
        ) else { return }

        isLoading = true
        lastError = nil

        // NOTE on timezone: Aladhan returns times in the *location's* local
        // timezone regardless of this query param (verified against the live
        // API — it ignores `timezone=`). We still send it for forward-
        // compatibility, but the authoritative source of truth for which tz
        // the wall-clock strings are in is `data.meta.timezone`, read back in
        // `parse(payload:)` and applied in `parseTime(_:timeZone:)`. Never
        // assume the device tz matches the prayer location.
        let tzIdentifier = TimeZone.current.identifier
        let urlString = "https://api.aladhan.com/v1/timings/\(key)?latitude=\(resolvedLatitude)&longitude=\(resolvedLongitude)&method=\(calcMethodRaw)&timezone=\(tzIdentifier)"
        guard let url = URL(string: urlString) else {
            isLoading = false
            lastError = "Invalid URL"
            return
        }

        let fetchedLat = resolvedLatitude
        let fetchedLng = resolvedLongitude
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isLoading = false }

                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let payload = json["data"] as? [String: Any] else {
                    self.lastError = "Bad response"
                    return
                }
                self.schedule = Self.parse(payload: payload, dateKey: key)
                // Record which coordinates this schedule is valid for so a
                // later coordinate change can be detected and force a refetch.
                self.lastFetchedLatitude = fetchedLat
                self.lastFetchedLongitude = fetchedLng
            }
        }.resume()
    }

    // MARK: - Parsing (pure, testable)

    /// Parse the Aladhan `data` object into a PrayerSchedule. Extracted so it
    /// can be unit-tested with fixture JSON.
    static func parse(payload: [String: Any], dateKey: String) -> PrayerSchedule {
        // Resolve the timezone the API computed the times in. Aladhan always
        // returns times in the *location's* local timezone (it ignores the
        // `timezone=` query param we send — see CORRECTNESS note in fetchTimings).
        // We must interpret the wall-clock strings in THAT timezone, otherwise a
        // user whose device tz differs from the prayer location (e.g. a Riyadh
        // user whose Mac is on Europe/London) sees every prayer shifted by the
        // tz delta. Falling back to the device tz keeps legacy behavior intact.
        var resolvedTZ: TimeZone = TimeZone.current
        if let meta = payload["meta"] as? [String: Any],
           let tzID = meta["timezone"] as? String,
           let parsed = TimeZone(identifier: tzID) {
            resolvedTZ = parsed
        }

        let timings = payload["timings"] as? [String: Any] ?? [:]
        var times: [PrayerKind: Date] = [:]
        for kind in PrayerKind.allCases {
            if let raw = timings[kind.rawValue] as? String,
               let date = Self.parseTime(raw, timeZone: resolvedTZ) {
                times[kind] = date
            }
        }

        var hijri: String?
        if let date = payload["date"] as? [String: Any],
           let hijriDict = date["hijri"] as? [String: Any] {
            let day = hijriDict["day"] as? String ?? ""
            // Aladhan returns Arabic month names WITH harakat (e.g. "مُحَرَّم");
            // strip the diacritics for a cleaner display matching HijriDateFormatter.
            let rawMonth = (hijriDict["month"] as? [String: Any])?["ar"] as? String ?? ""
            let month = Self.stripArabicDiacritics(rawMonth)
            let year = hijriDict["year"] as? String ?? ""
            let composed = "\(day) \(month) \(year)".trimmingCharacters(in: .whitespaces)
            hijri = composed.isEmpty ? nil : composed
        }

        return PrayerSchedule(dateKey: dateKey, times: times, hijriDate: hijri, timeZone: resolvedTZ)
    }

    /// Remove Arabic harakat/diacritics from a string for cleaner display.
    static func stripArabicDiacritics(_ string: String) -> String {
        // Unicode range U+064B–U+0652 covers the common harakat (fatha, kasra,
        // damma, shadda, sukun, tanwin). U+0670 is superscript alef.
        let diacritics = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}")
            .union(CharacterSet(charactersIn: "\u{0670}"..."\u{0670}"))
            .union(CharacterSet(charactersIn: "\u{0640}"..."\u{0640}")) // tatweel
        return string.components(separatedBy: diacritics).joined()
    }

    /// Convert Aladhan's "HH:MM (TZ)" or "HH:MM" to today's Date, interpreted
    /// in the timezone the API returned the time in (NOT the device timezone).
    ///
    /// The API returns wall-clock strings for the prayer's *location* (e.g.
    /// "05:12" means 05:12 in Asia/Riyadh for a Riyadh request). To turn that
    /// into an unambiguous instant we MUST build the DateComponents in that same
    /// timezone; otherwise a user whose device is on a different tz would have
    /// the string reinterpreted in their local tz, shifting every prayer.
    static func parseTime(_ raw: String, timeZone: TimeZone) -> Date? {
        // Aladhan returns times like "05:12 (AST)" — strip the timezone suffix.
        let cleaned = raw.split(separator: " ").first.map(String.init) ?? raw
        let parts = cleaned.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        // Use a UTC-based calendar to derive today's y/m/d so the *date* portion
        // is deterministic and not itself subject to device-tz boundary effects;
        // the wall-clock HH:MM is then anchored to `timeZone`.
        var dayCal = Calendar(identifier: .gregorian)
        dayCal.timeZone = timeZone
        var comps = dayCal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        comps.second = 0
        comps.timeZone = timeZone
        return dayCal.date(from: comps)
    }

    // MARK: - Helpers

    static func todayKey() -> String {
        // Aladhan's timings endpoint expects DD-MM-YYYY in the path. Sending
        // YYYY-MM-DD silently returns a default/old date, so the format MUST
        // be dd-MM-yyyy.
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    /// Human-readable countdown like "2h 12m" or "12m" or "الآن".
    static func countdownString(from now: Date, to target: Date) -> String {
        let ms = target.timeIntervalSince(now)
        guard ms > 0 else { return "الآن" }
        let totalMin = Int(ms / 60)
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 { return "\(h) س \(m) د" }
        return "\(m) دقيقة"
    }

    /// The next prayer and its countdown, computed live.
    var nextPrayerInfo: (kind: PrayerKind, date: Date, countdown: String)? {
        guard let next = schedule.nextPrayer(now: Date()) else { return nil }
        return (next.kind, next.date, Self.countdownString(from: Date(), to: next.date))
    }

    /// The previous prayer (the one we're currently inside the interval of).
    var previousPrayerInfo: (kind: PrayerKind, date: Date)? {
        guard let prev = schedule.previousPrayer(now: Date()) else { return nil }
        return (prev.kind, prev.date)
    }

    /// Fraction (0...1) of the current inter-prayer interval elapsed — drives
    /// the progress bar. nil if not yet computable.
    var progressFraction: Double? {
        schedule.intervalProgress(now: Date())
    }

    // MARK: - Refresh

    private func registerRefresh() {
        Task { @MainActor [weak self] in
            self?.refreshToken = ModuleRefreshScheduler.shared.register(
                id: "prayer-times.refresh",
                name: "Prayer times refresh",
                module: .builtIn(.prayerTimes),
                policy: .visibleOnly(3600, tolerance: 300),
                enabled: { AppState.shared.prayerTimesEnabled }
            ) { [weak self] in
                self?.fetchTimings()
            }
        }
    }

    deinit {
        let token = refreshToken
        Task { @MainActor in ModuleRefreshScheduler.shared.unregister(token) }
    }
}

// MARK: - CLLocationManagerDelegate

extension PrayerTimesManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse, .authorized:
                manager.startUpdatingLocation()
            default:
                // Permission denied — fall back to manual coordinates.
                resolvedLatitude = manualLatitude
                resolvedLongitude = manualLongitude
                fetchTimings()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            // Stop as soon as we have a usable fix — prayer times only need km accuracy.
            manager.stopUpdatingLocation()
            resolvedLatitude = location.coordinate.latitude
            resolvedLongitude = location.coordinate.longitude
            lastLocationFix = Date()
            hasLocationFix = true

            // Reverse-geocode for a friendly city name (best-effort, non-blocking).
            CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
                Task { @MainActor in
                    if let city = placemarks?.first?.locality {
                        self?.locationName = city
                    }
                }
            }

            // Always attempt a fetch on a fresh fix; `fetchTimings()` itself
            // decides via `shouldRefetch` whether the new coordinates differ
            // enough from the cached ones to warrant a network request. This
            // is what makes auto-location actually switch the displayed times
            // away from the seeded Riyadh default once the real fix arrives.
            fetchTimings()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Fall back to manual coordinates on failure.
            resolvedLatitude = manualLatitude
            resolvedLongitude = manualLongitude
            if !hasFetchedFromLocation {
                hasFetchedFromLocation = true
                fetchTimings()
            }
        }
    }
}
