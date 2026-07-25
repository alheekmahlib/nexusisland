import SwiftUI

// MARK: - NexusDesign: Gradients
//
// The signature visual element, built on the exact icon palette. The purple
// ramp drives the surface; the neon pink→magenta→orange drives accents.

enum NexusGradient {
    /// Primary Royal Purple → Neon Pink → Vibrant Orange, diagonal.
    static var primary: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.royalPurple, NexusPalette.neonPink, NexusPalette.vibrantOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Purple ramp only (Electric Violet → Royal Purple → Deep Purple).
    /// Used for icon medallions and prayer icon backgrounds.
    static var purple: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.electricViolet, NexusPalette.royalPurple, NexusPalette.deepPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Higher-saturation neon variant for accents that need to pop.
    static var vibrant: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.electricViolet, NexusPalette.magenta, NexusPalette.neonPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Central radial glow for the expanded island background.
    static var backgroundRadial: RadialGradient {
        RadialGradient(
            colors: [NexusPalette.deepPurple, NexusPalette.background],
            center: .center,
            startRadius: 0,
            endRadius: 400
        )
    }

    /// Diagonal dark-purple gradient mirroring the app icon's backdrop:
    /// `background` (Midnight Blue, edges) → `deepPurple` (center).
    /// The signature surface fill for the expanded island.
    static var backgroundLinear: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.background, NexusPalette.deepPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Amber gradient (replaces the former accentGold gradient).
    static var amber: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.amber, NexusPalette.vibrantOrange],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Progress fill that warms toward orange as it nears completion.
    /// Pass a 0...1 progress value.
    static func progress(at value: Double) -> LinearGradient {
        let clamped = min(max(value, 0), 1)
        if clamped < 0.5 {
            return LinearGradient(colors: [NexusPalette.royalPurple, NexusPalette.neonPink],
                                  startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [NexusPalette.neonPink, NexusPalette.vibrantOrange],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }
}
