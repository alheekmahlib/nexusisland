import SwiftUI
import AppKit

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, modules, appearance, extensions, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    NSLocalizedString("General", comment: "Settings pane")
        case .modules:    NSLocalizedString("Modules", comment: "Settings pane")
        case .appearance: NSLocalizedString("Appearance", comment: "Settings pane")
        case .extensions: NSLocalizedString("Extensions", comment: "Settings pane")
        case .advanced:   NSLocalizedString("Advanced", comment: "Settings pane")
        }
    }

    var icon: String {
        switch self {
        case .general:    "gear"
        case .modules:    "square.grid.2x2"
        case .appearance: "paintbrush"
        case .extensions: "puzzlepiece.extension"
        case .advanced:   "wrench.and.screwdriver"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentArea
        }
        // Frame is applied by the hosting NSWindow; here we just paint the
        // vibrant purple gradient backdrop + a radial glow so the glass cards
        // float over a rich base.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                SettingsGlass.windowBackground
                SettingsGlass.windowGlow
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar
    //
    // Translucent material panel on the left. The active row gets a purple
    // gradient capsule + glowing icon; inactive rows get a soft hover fill.
    // Separation from content comes from spacing/transparency, not a divider.

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Brand mark at the top — a small gradient pill so the window has an
            // identity anchor above the traffic-light buttons.
            brandMark
                .padding(.horizontal, 12)
                .padding(.top, 36) // clears the transparent title bar
                .padding(.bottom, 18)

            ForEach(SettingsPane.allCases) { pane in
                sidebarRow(pane)
            }
            Spacer(minLength: 12)
            quitRow
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(width: 220)
        .background(.ultraThinMaterial)
        // Soft right-edge fade so the sidebar melts into the content backdrop.
        .overlay(
            LinearGradient(
                colors: [.clear, NexusPalette.background.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 1),
            alignment: .trailing
        )
    }

    private var brandMark: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(NexusGradient.purple)
                    .frame(width: 24, height: 24)
                    .shadow(color: NexusPalette.electricViolet.opacity(0.5), radius: 4, y: 1)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Nexus Island")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(NexusPalette.textPrimary)
        }
    }

    private func sidebarRow(_ pane: SettingsPane) -> some View {
        let isSelected = selectedPane == pane
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                selectedPane = pane
            }
        } label: {
            SidebarRowLabel(icon: pane.icon, title: pane.title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var quitRow: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(SettingsGlass.idleIcon)
                    .frame(width: 18, alignment: .center)
                Text(NSLocalizedString("Quit", comment: "Settings label"))
                    .font(.system(size: 13))
                    .foregroundColor(SettingsGlass.idleText)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        Group {
            if selectedPane == .extensions {
                detailContent
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    detailContent
                        .padding(.horizontal, 28)
                        .padding(.top, 36) // clears transparent title bar
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        // Wrapped so we can apply a transition + id across the switched view.
        Group {
            switch selectedPane {
            case .general:    GeneralSettingsView()
            case .modules:    ModuleSettingsView()
            case .appearance: AppearanceSettingsView()
            case .extensions: ExtensionsSettingsView()
            case .advanced:   AdvancedSettingsView()
            }
        }
        // Gentle fade + scale when switching panes.
        .transition(
            appState.shouldReduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.985))
        )
        .id(selectedPane) // force re-render so the transition fires
    }
}

// MARK: - Sidebar Row Label (extracted for hover state)

private struct SidebarRowLabel: View {
    let icon: String
    let title: String
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? SettingsGlass.activeIcon : SettingsGlass.idleIcon)
                .frame(width: 18, alignment: .center)
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? SettingsGlass.activeText : SettingsGlass.idleText)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(SettingsGlass.activeCapsule)
                        : AnyShapeStyle(isHovering ? SettingsGlass.hoverCapsule : Color.clear)
                )
        )
        // Active row gets a subtle inner glow ring.
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(colors: [NexusPalette.electricViolet.opacity(0.5), .clear],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
        .shadow(color: isSelected ? NexusPalette.royalPurple.opacity(0.35) : .clear, radius: 6, y: 2)
        .scaleEffect(isHovering && !isSelected ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared Components (glassmorphism redesign)
//
// These cascade to General, Modules, Appearance, and Advanced panes (~85% of
// the surface). The Extensions pane uses SettingsCard (below) + its own
// panelBackground, which is harmonized separately.

struct SettingSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(NexusPalette.electricViolet.opacity(0.75))
            .tracking(0.3)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .settingsGlassSurface()
    }
}

struct SettingRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsGlass.divider)
            .frame(height: 0.5)
            .padding(.leading, 20)
    }
}

struct SettingToggleRow: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: description != nil ? .top : .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(NexusPalette.textPrimary)
                if let desc = description {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SettingsGlass.toggleTint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

struct StepperField: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let label: (Double) -> String

    var body: some View {
        HStack(spacing: 0) {
            stepperButton(icon: "minus", disabled: value <= range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text(label(value))
                .font(NexusTypography.mono)
                .foregroundColor(NexusPalette.textPrimary)
                .frame(minWidth: 44, alignment: .center)

            stepperButton(icon: "plus", disabled: value >= range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .settingsGlassSurface(elevatesOnHover: false)
    }

    @ViewBuilder
    private func stepperButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(disabled ? NexusPalette.textTertiary : NexusPalette.electricViolet)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// Backward-compat wrapper used by ExtensionsSettingsView
struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(SettingsGlass.divider)
                .frame(height: 0.5)

            content
                .padding(14)
        }
        .settingsGlassSurface()
    }
}
