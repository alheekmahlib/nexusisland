import SwiftUI

// MARK: - NexusDesign: Gradients
//
// The signature visual element. The purple→magenta→orange gradient is applied
// to the island surface (expanded/fullExpanded) and to accents (progress bars,
// medallions, active tabs). All gradients are computed properties so they can
// never go stale if a palette token changes.

enum NexusGradient {
    /// Primary purple→magenta→orange, diagonal. The signature fill.
    static var primary: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.gradientStart, NexusPalette.gradientMid, NexusPalette.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Higher-saturation variant for accents that need to pop off the surface.
    static var vibrant: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.neonPurple, NexusPalette.gradientMid, NexusPalette.neonOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Central radial glow for the expanded island background.
    static var backgroundRadial: RadialGradient {
        RadialGradient(
            colors: [NexusPalette.backgroundGlow, NexusPalette.background],
            center: .center,
            startRadius: 0,
            endRadius: 400
        )
    }

    /// Soft gold gradient for premium accents.
    static var accentGold: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.accentGold, NexusPalette.accentGold.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Progress fill that shifts toward orange as it nears completion.
    /// Pass a 0...1 progress value.
    static func progress(at value: Double) -> LinearGradient {
        let clamped = min(max(value, 0), 1)
        if clamped < 0.5 {
            return LinearGradient(colors: [NexusPalette.gradientStart, NexusPalette.gradientMid],
                                  startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [NexusPalette.gradientMid, NexusPalette.gradientEnd],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }
}
