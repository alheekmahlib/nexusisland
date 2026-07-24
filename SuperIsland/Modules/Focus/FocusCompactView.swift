import SwiftUI

struct FocusCompactView: View {
    @ObservedObject private var manager = FocusManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: manager.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(manager.isActive ? .purple : .white.opacity(0.5))

            if manager.isActive {
                Text(manager.focusName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } else {
                Text(NSLocalizedString("Focus Off", comment: "Focus compact inactive label"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}
