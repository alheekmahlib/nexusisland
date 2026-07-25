import SwiftUI

// MARK: - NexusDesign: Floating surface
//
// A premium macOS-inspired floating-card aesthetic. Instead of frosted glass,
// cards are semi-solid translucent surfaces built from the purple palette:
// a tinted fill (deep-purple wash + optional gradient wash) + a hairline
// gradient border + soft layered shadows. Colors stay purple; only the heavy
// frosted blur and glossy specular sheen are gone, replaced by depth via
// elevation and generous spacing.
// Use `.nexusSurface()` inline or the `GlassCard { ... }` wrapper.

struct NexusSurface: ViewModifier {
    enum Variant { case filled, outlined, glass }
    var variant: Variant = .filled
    var isActive: Bool = false
    var radius: CGFloat = NexusMetrics.cornerRadiusM
    var gradient: LinearGradient? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Semi-solid tinted base — a translucent purple fill instead
                    // of frosted material. Keeps a faint translucency cue without
                    // the heavy background blur.
                    if variant != .outlined {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        NexusPalette.deepPurple.opacity(isActive ? 0.55 : 0.42),
                                        NexusPalette.background.opacity(isActive ? 0.65 : 0.55)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        // Subtle top royal-purple lift for a hint of color depth.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(NexusPalette.royalPurple.opacity(0.12))
                    }
                    // Translucent gradient wash over the base for color depth.
                    if let gradient {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(gradient.opacity(0.18))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                // Hairline border — bright top edge fading to a dim bottom edge.
                // The only "glass" cue left: a 1px translucent gradient stroke.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.30 : 0.16), // bright top edge
                                Color.white.opacity(0.05)                     // dim bottom edge
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isActive ? 1.0 : NexusMetrics.strokeHairline
                    )
            )
            // Two soft shadows: a large ambient lift + a faint violet key.
            // Wide blur radius + low opacity = "floating" depth, never harsh.
            .shadow(color: .black.opacity(0.30), radius: 18, y: 8)
            .shadow(color: NexusPalette.electricViolet.opacity(isActive ? 0.14 : 0.07), radius: 12, y: 3)
    }
}

extension View {
    /// Apply the Nexus floating surface.
    func nexusSurface(variant: NexusSurface.Variant = .filled,
                      isActive: Bool = false,
                      radius: CGFloat = NexusMetrics.cornerRadiusM,
                      gradient: LinearGradient? = nil) -> some View {
        modifier(NexusSurface(variant: variant, isActive: isActive, radius: radius, gradient: gradient))
    }
}

/// Convenience floating-card wrapper. Defaults to the full `.glass` variant so a
/// bare `GlassCard { ... }` gets the premium tinted + bordered treatment.
struct GlassCard<Content: View>: View {
    var variant: NexusSurface.Variant = .glass
    var isActive: Bool = false
    var radius: CGFloat = NexusMetrics.cornerRadiusM
    var gradient: LinearGradient? = NexusGradient.purple
    @ViewBuilder var content: () -> Content

    var body: some View {
        content().modifier(
            NexusSurface(variant: variant, isActive: isActive, radius: radius, gradient: gradient)
        )
    }
}
