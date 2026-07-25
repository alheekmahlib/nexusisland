import SwiftUI

// MARK: - NexusDesign: GradientMedallion
//
// A circular icon badge with the vibrant gradient fill and an outer glow.
// Replaces the per-module medallions (Quran/PrayerTimes/Battery) that each
// built their own circle + shadow. `isActive` intensifies the glow.

struct GradientMedallion: View {
    var systemName: String
    var size: CGFloat = 38
    /// Icon font size as a fraction of the medallion diameter.
    var iconScale: CGFloat = 0.5
    var gradient: LinearGradient = NexusGradient.primary
    var isActive: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .shadow(color: NexusPalette.gradientMid.opacity(isActive ? 0.7 : 0.4),
                        radius: isActive ? 8 : 4)
            Image(systemName: systemName)
                .font(.system(size: size * iconScale, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
