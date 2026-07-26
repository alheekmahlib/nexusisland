import Combine
import Foundation
import SwiftUI

// MARK: - Countdown / Days-until Module
//
// Tracks countdowns to user-defined events (e.g. "رمضان", "العطلة"). Pure
// local — no network, no permissions. Events persist in UserDefaults.

struct CountdownEvent: Identifiable, Codable, Equatable {
    var id: String { name + dateKey }
    let name: String
    let date: Date          // target date
    let dateKey: String     // ISO string for id stability

    /// Days remaining (rounded). Negative = past event.
    var daysRemaining: Int {
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: now, to: target).day ?? 0
    }

    var isPast: Bool { daysRemaining < 0 }
}

@MainActor
final class CountdownManager: ObservableObject {
    static let shared = CountdownManager()

    @Published private(set) var events: [CountdownEvent] = []
    @Published var tickTrigger: Int = 0

    private let storageKey = "countdown.events"
    private var timer: Timer?

    private init() {
        loadEvents()
        seedDefaultsIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickTrigger += 1 }
        }
    }

    deinit { timer?.invalidate() }

    // MARK: - Event management

    func addEvent(name: String, date: Date) {
        let f = ISO8601DateFormatter()
        let event = CountdownEvent(name: name, date: date, dateKey: f.string(from: date))
        events.append(event)
        events.sort { $0.daysRemaining < $1.daysRemaining }
        saveEvents()
    }

    func removeEvent(_ event: CountdownEvent) {
        events.removeAll { $0.id == event.id }
        saveEvents()
    }

    /// Next upcoming event (smallest positive daysRemaining).
    var nextEvent: CountdownEvent? {
        events.filter { !$0.isPast }.min(by: { $0.daysRemaining < $1.daysRemaining })
    }

    // MARK: - Persistence

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: data) else { return }
        events = decoded.sorted { $0.daysRemaining < $1.daysRemaining }
    }

    private func saveEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Seed sensible defaults on first launch (so the module isn't empty).
    private func seedDefaultsIfNeeded() {
        guard events.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let f = ISO8601DateFormatter()

        // Approximate Islamic dates for the current year (shift each year).
        let year = cal.component(.year, from: now)
        let ramadan = cal.date(from: DateComponents(year: year + (now > f.date(from: "\(year)-02-28T00:00:00Z")! ? 1 : 0), month: 2, day: 28))!
        let newYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))!

        events = [
            CountdownEvent(name: "رمضان", date: ramadan, dateKey: f.string(from: ramadan)),
            CountdownEvent(name: "رأس السنة", date: newYear, dateKey: f.string(from: newYear))
        ]
        saveEvents()
    }
}

// MARK: - Views

struct CountdownCompactView: View {
    @ObservedObject private var manager = CountdownManager.shared

    var body: some View {
        if let next = manager.nextEvent {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10)).foregroundColor(NexusPalette.electricViolet)
                Text("\(next.daysRemaining)")
                    .font(NexusTypography.title(12)).foregroundColor(NexusPalette.textPrimary)
                Text("يوم")
                    .font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
            }
            .environment(\.layoutDirection, .rightToLeft)
        } else {
            Image(systemName: "calendar.badge.clock").font(.system(size: 11)).foregroundColor(NexusPalette.textTertiary)
        }
    }
}

struct CountdownExpandedView: View {
    @ObservedObject private var manager = CountdownManager.shared

    var body: some View {
        if manager.events.isEmpty {
            Text("لا توجد أحداث").font(NexusTypography.body(10)).foregroundColor(NexusPalette.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.events.prefix(4))) { event in
                    HStack(spacing: 6) {
                        Text(event.name).font(NexusTypography.body(10)).foregroundColor(NexusPalette.textPrimary)
                        Spacer()
                        Text("\(event.daysRemaining)").font(NexusTypography.mono(11))
                            .foregroundColor(event.isPast ? NexusPalette.textTertiary : NexusPalette.electricViolet)
                        Text("يوم").font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
                    }.frame(width: 120)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct CountdownFullExpandedView: View {
    @ObservedObject private var manager = CountdownManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("العد التنازلي").font(NexusTypography.title(12)).foregroundColor(NexusPalette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .environment(\.layoutDirection, .rightToLeft)
            Divider().background(NexusPalette.glassTint.opacity(0.10))

            if manager.events.isEmpty {
                Text("أضف حدثاً من الإعدادات").font(NexusTypography.body(11)).foregroundColor(NexusPalette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(manager.events) { event in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.name).font(NexusTypography.body(12)).foregroundColor(NexusPalette.textPrimary)
                                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
                                }
                                Spacer()
                                Text("\(event.daysRemaining)").font(NexusTypography.title(16))
                                    .foregroundColor(event.isPast ? NexusPalette.textTertiary : NexusPalette.electricViolet)
                                Text("يوم").font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .nexusSurface(variant: .glass, isActive: !event.isPast && manager.nextEvent?.id == event.id, radius: NexusMetrics.cornerRadiusS)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
