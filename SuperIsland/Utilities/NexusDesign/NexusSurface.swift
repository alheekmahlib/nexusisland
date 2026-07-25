import SwiftUI

// MARK: - NexusDesign: Glass surface
//
// Glassmorphism is the core container treatment for expanded/fullExpanded
// cards. This generalizes the Quran module's `quranSurface()` modifier to the
// whole app: an optional `Material` base + a translucent gradient wash + a
// hairline white stroke + a soft drop shadow. Use `.nexusSurface()` inline or
// the `GlassCard { ... }` wrapper.

struct NexusSurface: ViewModifier {
    enum Variant { case filled, outlined }
    var variant: Variant = .filled
    var isActive: Bool = false
    var radius: CGFloat = NexusMetrics.cornerRadiusM
    var gradient: LinearGradient? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if variant == .filled {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    if let gradient {
                        gradient.opacity(0.30)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isActive ? 0.25 : 0.10),
                        lineWidth: isActive ? 1.2 : NexusMetrics.strokeHairline
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
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

/// Convenience glass card wrapper.
struct GlassCard<Content: View>: View {
    var variant: NexusSurface.Variant = .filled
    var isActive: Bool = false
    var radius: CGFloat = NexusMetrics.cornerRadiusM
    var gradient: LinearGradient? = NexusGradient.primary
    @ViewBuilder var content: () -> Content

    var body: some View {
        content().modifier(
            NexusSurface(variant: variant, isActive: isActive, radius: radius, gradient: gradient)
        )
    }
}
