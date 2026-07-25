import SwiftUI

// MARK: - Settings Glass Kit
//
// Design tokens + reusable modifiers for the Settings window, built on the
// app's NexusDesign palette so the Settings feel like part of the same product.
// Kept separate from NexusDesign because Settings surfaces (cards, sidebar,
// rows) have different sizing needs than the Dynamic Island.
//
// Aesthetic: premium macOS SaaS dashboard — semi-solid translucent floating
// cards with thin gradient hairlines and soft, wide-blur shadows. NO frosted
// material blur and NO glossy specular sheen (the heavy glass look is gone);
// depth instead comes from elevation, generous spacing, and layering. The
// purple palette stays exactly as defined in NexusPalette.

enum SettingsGlass {
    // MARK: - Window backdrop (the rich base the cards float over)
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
            colors: [NexusPalette.deepPurple.opacity(0.40), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 460
        )
    }

    // MARK: - Sidebar
    /// Translucent capsule fill for the active sidebar row.
    static var activeCapsule: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.royalPurple.opacity(0.32), NexusPalette.electricViolet.opacity(0.22)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Hover fill for non-active sidebar rows.
    static var hoverCapsule: Color { Color.white.opacity(0.05) }

    static let activeIcon = NexusPalette.electricViolet
    static let idleIcon = NexusPalette.textTertiary
    static let activeText = NexusPalette.textPrimary
    static let idleText = NexusPalette.textSecondary

    // MARK: - Card chrome
    /// Semi-solid tinted card base — a translucent purple gradient instead of
    /// frosted material. Reads as a floating panel, not glass.
    static var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                NexusPalette.deepPurple.opacity(0.42),
                NexusPalette.background.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Hover variant — slightly brighter, lifts the card on hover.
    static var cardFillHover: LinearGradient {
        LinearGradient(
            colors: [
                NexusPalette.deepPurple.opacity(0.52),
                NexusPalette.background.opacity(0.60)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gradient hairline border — bright top edge, dim bottom (the only
    /// translucent-cue left, replacing the heavy glass sheen).
    static var cardStroke: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let divider = NexusPalette.glassTint.opacity(0.10)
    static let cornerRadius: CGFloat = 20

    // MARK: - Accents
    static let toggleTint = NexusPalette.royalPurple
}

// MARK: - Floating card modifier (the shared card treatment)

struct SettingsGlassSurface: ViewModifier {
    var isActive: Bool = false
    var radius: CGFloat = SettingsGlass.cornerRadius
    var elevatesOnHover: Bool = true

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Semi-solid tinted base (no frosted material / no blur).
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(isHovering ? SettingsGlass.cardFillHover : SettingsGlass.cardFill)
                    // Faint royal-purple lift at the top for a hint of color.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(NexusPalette.royalPurple.opacity(0.08))
                }
            )
            .overlay(
                // Thin gradient hairline border — the translucent depth cue.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SettingsGlass.cardStroke, lineWidth: 0.5)
            )
            // Two soft, wide-blur shadows: ambient lift + faint violet key.
            // Low opacity + large radius = "floating" depth, never harsh.
            .shadow(color: .black.opacity(isHovering ? 0.36 : 0.32), radius: 20, y: 8)
            .shadow(color: NexusPalette.royalPurple.opacity(isHovering ? 0.12 : 0.08), radius: 14, y: 3)
            .scaleEffect(isHovering && elevatesOnHover ? 1.006 : 1.0)
            .onHover { hovering in
                guard elevatesOnHover else { return }
                withAnimation(.easeOut(duration: 0.2)) { isHovering = hovering }
            }
            .animation(.easeOut(duration: 0.2), value: isHovering)
    }
}

extension View {
    /// Apply the Settings floating-card treatment (tinted fill + hairline border
    /// + soft layered shadows + optional hover elevation).
    func settingsGlassSurface(isActive: Bool = false,
                              radius: CGFloat = SettingsGlass.cornerRadius,
                              elevatesOnHover: Bool = true) -> some View {
        modifier(SettingsGlassSurface(isActive: isActive, radius: radius, elevatesOnHover: elevatesOnHover))
    }
}
