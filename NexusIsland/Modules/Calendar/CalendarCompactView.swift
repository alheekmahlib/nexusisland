import SwiftUI

struct CalendarCompactView: View {
    @ObservedObject private var manager = CalendarManager.shared

    var body: some View {
        HStack(spacing: 6) {
            if let event = manager.nextEvent, let countdown = manager.nextEventCountdown {
                Text(event.title ?? NSLocalizedString("Event", comment: "Calendar compact fallback title"))
                    .font(NexusTypography.caption(11, .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)

                Text(countdown)
                    .font(NexusTypography.mono(10))
                    .foregroundColor(NexusPalette.textSecondary)
            } else {
                Text(NSLocalizedString("No events", comment: "Calendar compact empty state"))
                    .font(NexusTypography.caption(11))
                    .foregroundColor(NexusPalette.textTertiary)
            }
        }
    }
}
