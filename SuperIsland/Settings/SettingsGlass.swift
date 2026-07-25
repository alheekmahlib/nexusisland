import SwiftUI

// MARK: - Settings Glass Kit
//
// Glassmorphism tokens + reusable modifiers for the Settings window, built on
// the app's NexusDesign palette so the Settings feel like part of the same
// product. Kept separate from NexusDesign because Settings surfaces (cards,
// sidebar, rows) have different sizing/material needs than the Dynamic Island.
//
// Aesthetic: macOS Sequoia + Glassmorphism + premium SaaS dashboard —
// translucent layered panels, subtle gradient borders, soft shadows, and a
// vibrant purple backdrop that makes the glass read as glass.

enum SettingsGlass {
    // MARK: - Window backdrop (the rich base the glass floats over)
    /// Diagonal dark-purple gradient mirroring the app icon's backdrop.
    static var windowBackground: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.background, NexusPalette.deepPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Central radial glow layered above windowBackground for depth.
    static var windowGlow: RadialGradient {
        RadialGradient(
            colors: [NexusPalette.deepPurple.opacity(0.55), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 460
        )
    }

    // MARK: - Sidebar
    /// Translucent capsule fill for the active sidebar row.
    static var activeCapsule: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.royalPurple.opacity(0.40), NexusPalette.electricViolet.opacity(0.28)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Hover fill for non-active sidebar rows.
    static var hoverCapsule: Color { Color.white.opacity(0.06) }

    static let activeIcon = NexusPalette.electricViolet
    static let idleIcon = NexusPalette.textTertiary
    static let activeText = NexusPalette.textPrimary
    static let idleText = NexusPalette.textSecondary

    // MARK: - Card chrome
    /// Subtle translucent fill layered over `.ultraThinMaterial`.
    static let cardFill = Color.white.opacity(0.06)
    static let cardFillHover = Color.white.opacity(0.10)

    /// Gradient hairline border — bright top edge, dim bottom (glass depth cue).
    static var cardStroke: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let divider = NexusPalette.glassTint.opacity(0.10)
    static let cornerRadius: CGFloat = 16

    // MARK: - Accents
    static let toggleTint = NexusPalette.royalPurple
}

// MARK: - Glass card modifier (the shared card treatment)

struct SettingsGlassSurface: ViewModifier {
    var isActive: Bool = false
    var radius: CGFloat = SettingsGlass.cornerRadius
    var elevatesOnHover: Bool = true

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(isHovering ? SettingsGlass.cardFillHover : SettingsGlass.cardFill)
                    // Top specular sheen — confined to the upper ~45% so the card
                    // reads as curved, frosted glass.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.03), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .scaleEffect(y: 0.45, anchor: .top)
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SettingsGlass.cardStroke, lineWidth: 1)
            )
            // Two soft shadows: ambient + a faint violet key for the premium glow.
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .shadow(color: NexusPalette.royalPurple.opacity(isHovering ? 0.16 : 0.08), radius: 10, y: 3)
            .scaleEffect(isHovering && elevatesOnHover ? 1.008 : 1.0)
            .onHover { hovering in
                guard elevatesOnHover else { return }
                withAnimation(.easeOut(duration: 0.2)) { isHovering = hovering }
            }
            .animation(.easeOut(duration: 0.2), value: isHovering)
    }
}

extension View {
    /// Apply the Settings glass-card treatment (material + sheen + gradient border + soft shadow + hover elevation).
    func settingsGlassSurface(isActive: Bool = false,
                              radius: CGFloat = SettingsGlass.cornerRadius,
                              elevatesOnHover: Bool = true) -> some View {
        modifier(SettingsGlassSurface(isActive: isActive, radius: radius, elevatesOnHover: elevatesOnHover))
    }
}
