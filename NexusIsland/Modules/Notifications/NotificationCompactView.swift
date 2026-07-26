import SwiftUI
import AppKit

struct NotificationCompactView: View {
    @ObservedObject private var manager = NotificationManager.shared

    var body: some View {
        HStack(spacing: 6) {
            if let latestNotification = manager.latestNotification {
                let notif = manager.displayNotification(latestNotification)
                notificationLeadingView(notif, size: 14)

                Text(headline(for: notif))
                    .font(NexusTypography.caption(11, .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if manager.recentNotifications.count > 1 {
                    Text("\(manager.recentNotifications.count)")
                        .font(NexusTypography.numeric(10))
                        .foregroundStyle(NexusPalette.textSecondary)
                }
            } else {
                Text(NSLocalizedString("No notifications", comment: "Notification compact empty state"))
                    .font(NexusTypography.caption(11))
                    .foregroundColor(NexusPalette.textTertiary)
            }
        }
    }

    private func headline(for notification: IslandNotification) -> String {
        if let sender = sanitized(notification.senderName) {
            return sender
        }

        if let title = sanitized(notification.title) {
            return title
        }

        return notification.appName
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered == "undefined" || lowered == "null" || lowered == "(null)" {
            return nil
        }
        return trimmed
    }

    @ViewBuilder
    private func notificationLeadingView(_ notification: IslandNotification, size: CGFloat) -> some View {
        if let avatar = image(from: notification.avatarURL) {
            Image(nsImage: avatar)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else if let iconImage = image(from: notification.appIconURL) {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else if let appIcon = appIcon(for: notification.bundleIdentifier, size: size) {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else {
            GradientMedallion(systemName: notification.appIcon, size: size, gradient: NexusGradient.purple)
        }
    }

    private func image(from urlString: String?) -> NSImage? {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty else {
            return nil
        }

        let url: URL?
        if urlString.hasPrefix("/") {
            url = URL(fileURLWithPath: urlString)
        } else {
            url = URL(string: urlString)
        }

        guard let url, url.isFileURL else { return nil }
        return NSImage(contentsOf: url)
    }

    private func appIcon(for bundleIdentifier: String?, size: CGFloat) -> NSImage? {
        guard let bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}
