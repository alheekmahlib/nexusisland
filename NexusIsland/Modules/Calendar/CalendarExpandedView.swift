import SwiftUI
import EventKit

struct CalendarExpandedView: View {
    @ObservedObject private var manager = CalendarManager.shared
    @EnvironmentObject var appState: AppState

    private let calendar = Foundation.Calendar.current

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        Group {
            if appState.currentState == .fullExpanded {
                fullExpandedCalendar
            } else {
                mediumExpandedSummary
            }
        }
    }

    // MARK: - Medium Expanded (Previous Behavior)

    private var mediumExpandedSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(headerDate)
                    .font(NexusTypography.numeric(14))
                    .foregroundColor(NexusPalette.textPrimary)
                Spacer()
                Text("\(manager.todayEvents.count) events")
                    .font(NexusTypography.caption(11))
                    .foregroundColor(NexusPalette.textTertiary)
            }

            Group {
                if let event = manager.nextEvent {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 8, height: 8)

                        Text(event.title ?? "")
                            .font(NexusTypography.caption(12, .medium))
                            .foregroundColor(NexusPalette.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let countdown = manager.nextEventCountdown {
                            Text(countdown)
                                .font(NexusTypography.mono(11))
                                .foregroundColor(NexusPalette.textSecondary)
                        }

                        if let url = manager.joinURL(for: event) {
                            Button(action: { NSWorkspace.shared.open(url) }) {
                                Text(NSLocalizedString("Join", comment: "Calendar event join button"))
                                    .font(NexusTypography.caption(10, .semibold))
                                    .foregroundColor(NexusPalette.textPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .nexusSurface(variant: .filled, radius: 4, gradient: NexusGradient.purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text(NSLocalizedString("No more events today", comment: "Calendar medium empty state"))
                        .font(NexusTypography.body(12))
                        .foregroundColor(NexusPalette.textTertiary)
                }
            }
        }
    }

    // MARK: - Full Expanded (Calendar Grid + Events + Upcoming)

    private var fullExpandedCalendar: some View {
        HStack(alignment: .top, spacing: 0) {
            calendarGridPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)

            panelDivider

            eventsPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 12)

            panelDivider

            upcomingPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.leading, 12)
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(NexusPalette.glassTint.opacity(0.10))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    // MARK: - Calendar Grid (Left)

    private var calendarGridPanel: some View {
        GeometryReader { geometry in
            let metrics = calendarGridMetrics(for: geometry.size.height)

            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                HStack(spacing: 6) {
                    monthButton(icon: "chevron.left") {
                        manager.showPreviousMonth()
                    }

                    Text(monthTitle)
                        .font(NexusTypography.title(13))
                        .foregroundColor(NexusPalette.textPrimary)

                    Spacer(minLength: 4)

                    if !isCurrentMonthVisible {
                        Button(NSLocalizedString("Today", comment: "Calendar today button")) {
                            manager.resetDisplayedMonthToCurrent()
                            manager.selectDate(Date())
                        }
                        .buttonStyle(.plain)
                        .font(NexusTypography.caption(10, .medium))
                        .foregroundColor(NexusPalette.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(NexusPalette.glassTint.opacity(0.18))
                        .clipShape(Capsule())
                    }

                    monthButton(icon: "chevron.right") {
                        manager.showNextMonth()
                    }
                }
                .frame(height: metrics.headerHeight)

                LazyVGrid(columns: dayColumns, spacing: metrics.gridSpacing) {
                    ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(NexusTypography.caption(9, .medium))
                            .foregroundColor(NexusPalette.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: metrics.weekdayHeight)
                    }
                }

                LazyVGrid(columns: dayColumns, spacing: metrics.gridSpacing) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let date = day {
                            dayCell(for: date, height: metrics.dayCellHeight)
                        } else {
                            Color.clear
                                .frame(height: metrics.dayCellHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Events Panel (Right)

    private var eventsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(selectedDateTitle)
                    .font(NexusTypography.title(14))
                    .foregroundColor(NexusPalette.textPrimary)

                Spacer()

                Text(eventCountLabel)
                    .font(NexusTypography.caption(10, .medium))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .padding(.bottom, 8)

            if manager.selectedDateEvents.isEmpty {
                Spacer()
                Text(NSLocalizedString("No events", comment: "Calendar events panel empty state"))
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(manager.selectedDateEvents.enumerated()), id: \.offset) { _, event in
                            calendarEventRow(event)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Upcoming Panel (Right)

    private var upcomingPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("Upcoming", comment: "Calendar upcoming panel title"))
                .font(NexusTypography.title(14))
                .foregroundColor(NexusPalette.textPrimary)
                .padding(.bottom, 8)

            if manager.upcomingWeekEvents.isEmpty {
                Spacer()
                Text(NSLocalizedString("Nothing this week", comment: "Calendar upcoming empty state"))
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(manager.upcomingWeekEvents.enumerated()), id: \.offset) { _, group in
                            upcomingDaySection(date: group.date, events: group.events)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func upcomingDaySection(date: Date, events: [EKEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(upcomingDayLabel(for: date))
                .font(NexusTypography.caption(10, .semibold))
                .foregroundColor(NexusPalette.textTertiary)

            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(cgColor: event.calendar.cgColor))
                        .frame(width: 2, height: 14)

                    Text(event.title ?? NSLocalizedString("Untitled", comment: "Calendar untitled event fallback"))
                        .font(NexusTypography.caption(11, .medium))
                        .foregroundColor(NexusPalette.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if event.isAllDay {
                        Text(NSLocalizedString("All Day", comment: "Calendar all-day event label"))
                            .font(NexusTypography.caption(9, .medium))
                            .foregroundColor(NexusPalette.textTertiary)
                    } else {
                        Text(timeFormatter.string(from: event.startDate))
                            .font(NexusTypography.caption(9, .medium))
                            .foregroundColor(NexusPalette.textTertiary)
                    }
                }
            }

            if events.count > 3 {
                Text("+\(events.count - 3) more")
                    .font(NexusTypography.caption(9, .medium))
                    .foregroundColor(NexusPalette.textTertiary)
                    .padding(.leading, 8)
            }
        }
    }

    private func upcomingDayLabel(for date: Date) -> String {
        if calendar.isDateInTomorrow(date) {
            return NSLocalizedString("Tomorrow", comment: "Calendar relative date label")
        }
        return Self.upcomingDayFormatter.string(from: date)
    }

    private func calendarEventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3, height: 28)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(NexusTypography.caption(12, .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)

                if event.isAllDay {
                    Text("All Day")
                        .font(NexusTypography.caption(10, .medium))
                        .foregroundColor(NexusPalette.textTertiary)
                } else {
                    Text("\(timeFormatter.string(from: event.startDate)) – \(timeFormatter.string(from: event.endDate))")
                        .font(NexusTypography.caption(10, .medium))
                        .foregroundColor(NexusPalette.textTertiary)
                }

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(NexusTypography.body(10))
                        .foregroundColor(NexusPalette.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if let url = manager.joinURL(for: event) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        eventActionIcon("video.fill")
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("Open meeting link", comment: "Calendar event action help"))

                    Button { copy(url: url) } label: {
                        eventActionIcon("doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("Copy meeting link", comment: "Calendar event action help"))
                }

                Button { manager.hideCalendar(for: event) } label: {
                    eventActionIcon("eye.slash")
                }
                .buttonStyle(.plain)
                    .help(NSLocalizedString("Hide this calendar", comment: "Calendar event action help"))
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .nexusSurface(variant: .glass, isActive: isEventActive(event), radius: NexusMetrics.cornerRadiusS)
    }

    private func isEventActive(_ event: EKEvent) -> Bool {
        let now = Date()
        return !event.isAllDay && event.startDate <= now && event.endDate > now
    }

    private func eventActionIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(NexusTypography.caption(9, .bold))
            .foregroundColor(NexusPalette.textPrimary)
            .frame(width: 24, height: 24)
            .nexusSurface(variant: .filled, radius: NexusMetrics.cornerRadiusS)
    }

    private func copy(url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    // MARK: - Day Cell

    private func dayCell(for date: Date, height: CGFloat) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: manager.selectedDate)
        let isInDisplayedMonth = calendar.isDate(date, equalTo: manager.displayedMonthStart, toGranularity: .month)
        let hasEvents = manager.hasEvents(on: date)
        let indicatorSize = height >= 18 ? CGFloat(4) : CGFloat(3)
        let contentSpacing = height >= 18 ? CGFloat(2) : CGFloat(1)

        return Button {
            manager.selectDate(date)
        } label: {
            VStack(spacing: contentSpacing) {
                Text("\(dayNumber)")
                    .font(NexusTypography.caption(11, isToday || isSelected ? .semibold : .regular))
                    .foregroundColor(dayForeground(isInDisplayedMonth: isInDisplayedMonth, isToday: isToday, isSelected: isSelected))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Circle()
                    .fill(hasEvents && isInDisplayedMonth ? NexusPalette.neonPink : Color.clear)
                    .frame(width: indicatorSize, height: indicatorSize)
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(dayCellBackground(isToday: isToday, isSelected: isSelected))
            )
        }
        .buttonStyle(.plain)
    }

    private func dayForeground(isInDisplayedMonth: Bool, isToday: Bool, isSelected: Bool) -> Color {
        if !isInDisplayedMonth {
            return NexusPalette.textTertiary
        }
        if isSelected || isToday {
            return NexusPalette.textPrimary
        }
        return NexusPalette.textPrimary
    }

    private func dayCellBackground(isToday: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return NexusPalette.royalPurple.opacity(0.4)
        }
        if isToday {
            return NexusPalette.glassTint.opacity(0.18)
        }
        return .clear
    }

    private func monthButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(NexusTypography.caption(10, .bold))
                .foregroundColor(NexusPalette.textPrimary)
                .frame(width: 20, height: 20)
                .nexusSurface(variant: .filled, radius: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var selectedDateTitle: String {
        if calendar.isDateInToday(manager.selectedDate) {
            return NSLocalizedString("Today", comment: "Calendar relative date label")
        }
        if calendar.isDateInYesterday(manager.selectedDate) {
            return NSLocalizedString("Yesterday", comment: "Calendar relative date label")
        }
        if calendar.isDateInTomorrow(manager.selectedDate) {
            return NSLocalizedString("Tomorrow", comment: "Calendar relative date label")
        }
        return Self.selectedDateFormatter.string(from: manager.selectedDate)
    }

    private var eventCountLabel: String {
        let count = manager.selectedDateEvents.count
        if count == 0 { return "" }
        return count == 1 ? "1 event" : "\(count) events"
    }

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: manager.displayedMonthStart)
    }

    private var isCurrentMonthVisible: Bool {
        calendar.isDate(manager.displayedMonthStart, equalTo: Date(), toGranularity: .month)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var gridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: manager.displayedMonthStart),
              let dayCount = calendar.range(of: .day, in: .month, for: monthInterval.start)?.count else {
            return []
        }

        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthInterval.start)
        let leadingPadding = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)
        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: monthInterval.start) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var dayColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 3), count: 7)
    }

    private var calendarRowCount: Int {
        max(1, gridDays.count / 7)
    }

    private func calendarGridMetrics(for availableHeight: CGFloat) -> CalendarGridMetrics {
        let headerHeight: CGFloat = 22
        let weekdayHeight: CGFloat = 12
        let sectionSpacing: CGFloat = 5
        let gridSpacing: CGFloat = 3
        let verticalPadding: CGFloat = 2
        let rowCount = CGFloat(calendarRowCount)
        let totalSpacing = (sectionSpacing * 2) + (gridSpacing * max(0, rowCount - 1))
        let usableHeight = max(0, availableHeight - headerHeight - weekdayHeight - totalSpacing - verticalPadding)
        let dayCellHeight = max(14, floor(usableHeight / rowCount))

        return CalendarGridMetrics(
            headerHeight: headerHeight,
            weekdayHeight: weekdayHeight,
            sectionSpacing: sectionSpacing,
            gridSpacing: gridSpacing,
            dayCellHeight: dayCellHeight
        )
    }

    private var headerDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let selectedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter
    }()

    private static let upcomingDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        return formatter
    }()
}

private struct CalendarGridMetrics {
    let headerHeight: CGFloat
    let weekdayHeight: CGFloat
    let sectionSpacing: CGFloat
    let gridSpacing: CGFloat
    let dayCellHeight: CGFloat
}
