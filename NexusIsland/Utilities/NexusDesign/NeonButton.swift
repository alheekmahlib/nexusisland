import SwiftUI

// MARK: - NexusDesign: NeonButton
//
// A circular gradient button with a press-down scale + a glow that softens on
// touch. Used for transport controls (play/pause/skip) and primary actions.
// Honors a plain button style so no system chrome bleeds through.

struct NeonButton: View {
    var systemName: String
    var size: CGFloat = 36
    var gradient: LinearGradient = NexusGradient.primary
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(gradient))
                .shadow(color: NexusPalette.gradientMid.opacity(pressed ? 0.3 : 0.6),
                        radius: pressed ? 3 : 6)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.9 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}
