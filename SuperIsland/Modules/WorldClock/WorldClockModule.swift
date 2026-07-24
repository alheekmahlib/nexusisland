import Combine
import SwiftUI

// MARK: - World Clock Module
//
// Shows multiple time zones side-by-side. Pure Foundation — no network, no
// permissions. Timezones are user-configurable (defaults to a sensible set).

// MARK: - Model

struct WorldClock: Identifiable, Equatable {
    let id: String           // timezone identifier (e.g. "Asia/Riyadh")
    let label: String        // display label (e.g. "الرياض")
    let offsetHours: Double  // UTC offset for sorting

    /// Current time in this zone, formatted as "h:mm a" (12-hour).
    var currentTime: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: id)
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    /// Short day/night glyph.
    var dayNightIcon: String {
        let cal = Calendar(identifier: .gregorian)
        var components = cal.dateComponents([.hour], from: Date())
        components.timeZone = TimeZone(identifier: id)
        let hour = components.hour ?? 12
        return (6...18).contains(hour) ? "sun.max.fill" : "moon.fill"
    }

    /// Difference from the user's local zone, e.g. "+3h" or "-5h".
    func offsetFrom(local: TimeZone) -> String {
        let diff = offsetHours - Double(local.secondsFromGMT()) / 3600
        if diff == 0 { return "" }
        let sign = diff > 0 ? "+" : ""
        return "\(sign)\(String(format: "%g", diff))h"
    }
}

// MARK: - Default zones

enum WorldClockDefaults {
    static let zones: [WorldClock] = [
        WorldClock(id: "Asia/Riyadh", label: "الرياض", offsetHours: 3),
        WorldClock(id: "Asia/Dubai", label: "دبي", offsetHours: 4),
        WorldClock(id: "Asia/Cairo", label: "القاهرة", offsetHours: 2),
        WorldClock(id: "Europe/London", label: "لندن", offsetHours: 1),
        WorldClock(id: "America/New_York", label: "نيويورك", offsetHours: -4),
        WorldClock(id: "America/Los_Angeles", label: "لوس أنجلوس", offsetHours: -7),
        WorldClock(id: "Asia/Tokyo", label: "طوكيو", offsetHours: 9)
    ]
}

// MARK: - Manager

@MainActor
final class WorldClockManager: ObservableObject {
    static let shared = WorldClockManager()

    @Published private(set) var zones: [WorldClock] = WorldClockDefaults.zones
    @Published var tickTrigger: Int = 0  // bumps every minute to force refresh

    private var timer: Timer?

    private init() {
        startTicking()
    }

    private func startTicking() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickTrigger += 1 }
        }
    }

    deinit { timer?.invalidate() }
}

// MARK: - Views

struct WorldClockCompactView: View {
    @ObservedObject private var manager = WorldClockManager.shared

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundColor(QuranDesign.accent)
            // Show the first 2 zones' times in the tight pill.
            ForEach(Array(manager.zones.prefix(2))) { zone in
                Text(zone.currentTime)
                    .font(QuranDesign.mono(10))
                    .foregroundColor(QuranDesign.textPrimary)
            }
        }
    }
}

struct WorldClockExpandedView: View {
    @ObservedObject private var manager = WorldClockManager.shared
    private let localZone = TimeZone.current

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(manager.zones.prefix(5))) { zone in
                zoneRow(zone)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func zoneRow(_ zone: WorldClock) -> some View {
        HStack(spacing: 8) {
            Image(systemName: zone.dayNightIcon)
                .font(.system(size: 9))
                .foregroundColor(zone.dayNightIcon == "sun.max.fill" ? .yellow : .indigo)
            Text(zone.label)
                .font(QuranDesign.body(10))
                .foregroundColor(QuranDesign.textSecondary)
            Spacer()
            Text(zone.currentTime)
                .font(QuranDesign.mono(11))
                .foregroundColor(QuranDesign.textPrimary)
            let offset = zone.offsetFrom(local: localZone)
            if !offset.isEmpty {
                Text(offset)
                    .font(QuranDesign.caption(8))
                    .foregroundColor(QuranDesign.textTertiary)
            }
        }
    }
}

struct WorldClockFullExpandedView: View {
    @ObservedObject private var manager = WorldClockManager.shared
    private let localZone = TimeZone.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("الساعات العالمية")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                Spacer()
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)

            Divider().background(QuranDesign.surfaceStroke)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(manager.zones) { zone in
                        zoneRow(zone)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 5)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func zoneRow(_ zone: WorldClock) -> some View {
        HStack(spacing: 10) {
            Image(systemName: zone.dayNightIcon)
                .font(.system(size: 11))
                .foregroundColor(zone.dayNightIcon == "sun.max.fill" ? .yellow : .indigo)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(zone.label)
                    .font(QuranDesign.body(11))
                    .foregroundColor(QuranDesign.textPrimary)
                Text(zone.id.replacingOccurrences(of: "_", with: " "))
                    .font(QuranDesign.caption(8))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            Spacer()
            Text(zone.currentTime)
                .font(QuranDesign.surahName(13))
                .foregroundColor(QuranDesign.textPrimary)
            let offset = zone.offsetFrom(local: localZone)
            if !offset.isEmpty {
                Text(offset)
                    .font(QuranDesign.caption(8))
                    .foregroundColor(QuranDesign.textTertiary)
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .quranSurface(radius: QuranDesign.cornerRadiusS)
    }
}
