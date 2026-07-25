import SwiftUI

// MARK: - NexusDesign: Glass surface
//
// The macOS "liquid glass" look: a frosted material base + a translucent
// gradient wash + a bright TOP specular sheen (the glossy reflection that
// makes glass read as glass) + an inner edge highlight + a soft drop shadow.
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
                    switch variant {
                    case .filled, .glass:
                        // Frosted material — the actual blur behind the card.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    case .outlined:
                        EmptyView()
                    }
                    // Translucent gradient wash over the frost for color depth.
                    if let gradient {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(gradient.opacity(0.28))
                    }
                    // The glossy top sheen — a bright-to-transparent gradient
                    // confined to the upper ~45% of the surface. This is the
                    // specular highlight that reads as curved glass.
                    if variant == .glass {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.white.opacity(0.06),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .mask(
                                // Clip the sheen to the top half so it doesn't
                                // wash out the whole card.
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .scaleEffect(y: 0.55, anchor: .top)
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                // Hairline border + inner edge highlight.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.45 : 0.25), // bright top edge
                                Color.white.opacity(0.06)                     // dim bottom edge
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isActive ? 1.2 : NexusMetrics.strokeHairline
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
            .shadow(color: NexusPalette.electricViolet.opacity(isActive ? 0.18 : 0.08), radius: 8, y: 2)
    }
}

extension View {
    /// Apply the Nexus glass surface.
    func nexusSurface(variant: NexusSurface.Variant = .filled,
                      isActive: Bool = false,
                      radius: CGFloat = NexusMetrics.cornerRadiusM,
                      gradient: LinearGradient? = nil) -> some View {
        modifier(NexusSurface(variant: variant, isActive: isActive, radius: radius, gradient: gradient))
    }
}

/// Convenience glass card wrapper. Defaults to the full `.glass` variant so a
/// bare `GlassCard { ... }` gets the premium frosted + sheen treatment.
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
