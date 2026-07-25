import Combine
import EventKit
import SwiftUI

// MARK: - Reminders Module
//
// Shows Apple Reminders (due today + overdue) using EventKit. Mirrors the
// Calendar module's permission + store pattern.

struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: Int   // 0=none, 1=high, 5=medium, 9=low
    let listName: String

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    var isDueToday: Bool {
        guard let due = dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }
}

@MainActor
final class RemindersManager: ObservableObject {
    static let shared = RemindersManager()

    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var hasAccess = false
    @Published private(set) var isLoading = false

    private let store = EKEventStore()
    private var refreshToken: ModuleRefreshToken?

    private init() {
        checkAccess()
        registerRefresh()
    }

    func checkAccess() {
        store.requestFullAccessToReminders { [weak self] granted, _ in
            Task { @MainActor in
                self?.hasAccess = granted
                if granted { self?.fetchReminders() }
            }
        }
    }

    func fetchReminders() {
        guard hasAccess else { return }
        isLoading = true
        let calendars = store.calendars(for: .reminder)
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil,
                                                               ending: Date().addingTimeInterval(86400 * 7),
                                                               calendars: calendars)
        store.fetchReminders(matching: predicate) { [weak self] ekReminders in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                guard let ekReminders else { return }
                self.reminders = ekReminders.map { r in
                    ReminderItem(
                        id: r.calendarItemIdentifier,
                        title: r.title ?? "بدون عنوان",
                        isCompleted: r.isCompleted,
                        dueDate: r.dueDateComponents?.date,
                        priority: r.priority,
                        listName: r.calendar.title
                    )
                }.sorted { lhs, rhs in
                    if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
                    return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
                }
            }
        }
    }

    func toggleComplete(_ item: ReminderItem) {
        guard let ek = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        ek.isCompleted.toggle()
        try? store.save(ek, commit: true)
        fetchReminders()
    }

    var overdueCount: Int { reminders.filter(\.isOverdue).count }
    var dueTodayCount: Int { reminders.filter(\.isDueToday).count }

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "reminders.refresh", name: "Reminders refresh",
            module: .builtIn(.reminders),
            policy: .activeOnly(300, tolerance: 60),
            enabled: { AppState.shared.remindersEnabled }
        ) { [weak self] in self?.fetchReminders() }
    }

    deinit { let t = refreshToken; Task { @MainActor in ModuleRefreshScheduler.shared.unregister(t) } }
}

// MARK: - Views

struct RemindersCompactView: View {
    @ObservedObject private var manager = RemindersManager.shared

    var body: some View {
        if !manager.hasAccess {
            Image(systemName: "list.bullet.clipboard").font(.system(size: 11)).foregroundColor(NexusPalette.textTertiary)
        } else if let next = manager.reminders.first {
            HStack(spacing: 5) {
                Image(systemName: next.isOverdue ? "exclamationmark.circle.fill" : "checklist")
                    .font(.system(size: 10)).foregroundColor(next.isOverdue ? NexusPalette.danger : NexusPalette.electricViolet)
                Text(next.title).font(NexusTypography.body(10)).foregroundColor(NexusPalette.textPrimary).lineLimit(1)
            }
        } else {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 10)).foregroundColor(NexusPalette.success)
        }
    }
}

struct RemindersExpandedView: View {
    @ObservedObject private var manager = RemindersManager.shared

    var body: some View {
        if !manager.hasAccess {
            Text("امنح صلاحية التذكيرات").font(NexusTypography.body(10)).foregroundColor(NexusPalette.textSecondary)
        } else if manager.reminders.isEmpty {
            Text("لا توجد تذكيرات ✓").font(NexusTypography.body(10)).foregroundColor(NexusPalette.success)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.reminders.prefix(4))) { item in
                    Button(action: { manager.toggleComplete(item) }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 9)).foregroundColor(item.isOverdue ? NexusPalette.danger : NexusPalette.electricViolet)
                            Text(item.title).font(NexusTypography.body(10)).foregroundColor(NexusPalette.textPrimary).lineLimit(1)
                            if item.isOverdue {
                                Text("متأخر").font(NexusTypography.caption(8)).foregroundColor(NexusPalette.danger)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct RemindersFullExpandedView: View {
    @ObservedObject private var manager = RemindersManager.shared

    var body: some View {
        if !manager.hasAccess {
            VStack(spacing: 8) {
                Image(systemName: "list.bullet.clipboard").font(.system(size: 20)).foregroundColor(NexusPalette.textTertiary)
                Text("امنح صلاحية التذكيرات من إعدادات النظام").font(NexusTypography.body(11)).foregroundColor(NexusPalette.textSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).environment(\.layoutDirection, .rightToLeft)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("التذكيرات").font(NexusTypography.title(12)).foregroundColor(NexusPalette.textPrimary)
                    Spacer()
                    if manager.overdueCount > 0 {
                        Text("\(manager.overdueCount) متأخر").font(NexusTypography.caption(9)).foregroundColor(NexusPalette.danger)
                    }
                }.padding(.horizontal, 10).padding(.vertical, 7).environment(\.layoutDirection, .rightToLeft)
                Divider().background(NexusPalette.glassTint.opacity(0.10))

                if manager.reminders.isEmpty {
                    Text("لا توجد تذكيرات معلقة ✓").font(NexusTypography.body(11)).foregroundColor(NexusPalette.success)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(manager.reminders) { item in
                                Button(action: { manager.toggleComplete(item) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(item.isOverdue ? NexusPalette.danger : NexusPalette.electricViolet)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title).font(NexusTypography.body(11)).foregroundColor(NexusPalette.textPrimary).lineLimit(1)
                                            HStack(spacing: 4) {
                                                Text(item.listName).font(NexusTypography.caption(8)).foregroundColor(NexusPalette.textTertiary)
                                                if let due = item.dueDate {
                                                    Text(due.formatted(date: .abbreviated, time: .shortened))
                                                        .font(NexusTypography.caption(8))
                                                        .foregroundColor(item.isOverdue ? NexusPalette.danger : NexusPalette.textTertiary)
                                                }
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .nexusSurface(variant: .glass, isActive: item.isOverdue, radius: NexusMetrics.cornerRadiusS)
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 5).padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
