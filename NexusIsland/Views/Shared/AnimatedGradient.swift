import SwiftUI

struct AnimatedGradient: View {
    let colors: [Color]
    @EnvironmentObject private var appState: AppState
    @State private var start = UnitPoint(x: 0, y: 0)
    @State private var end = UnitPoint(x: 1, y: 1)

    var body: some View {
        LinearGradient(colors: colors, startPoint: start, endPoint: end)
            .onAppear { applyAnimation() }
            .onChange(of: appState.shouldReduceAnimations) { _, _ in applyAnimation() }
    }

    /// Starts or stops the looping gradient animation based on the user's
    /// accessibility / energy preference. When reduce-motion (or low-power)
    /// is active, the gradient is rendered as a static `LinearGradient`
    /// (its default points) instead of animating forever — a continuously
    /// re-rendered gradient is a non-trivial GPU cost that is wasted on
    /// users who have asked the system to reduce motion.
    private func applyAnimation() {
        if appState.shouldReduceAnimations {
            // Reset to a clean static state and cancel any pending animation.
            start = UnitPoint(x: 0, y: 0)
            end = UnitPoint(x: 1, y: 1)
        } else {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                start = UnitPoint(x: 1, y: 0)
                end = UnitPoint(x: 0, y: 1)
            }
        }
    }
}
