import SwiftUI
import AppKit

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, islandDisplay, modules, appearance, extensions, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:       NSLocalizedString("General", comment: "Settings pane")
        case .islandDisplay: NSLocalizedString("Island Display", comment: "Settings pane")
        case .modules:       NSLocalizedString("Modules", comment: "Settings pane")
        case .appearance:    NSLocalizedString("Appearance", comment: "Settings pane")
        case .extensions:    NSLocalizedString("Extensions", comment: "Settings pane")
        case .advanced:      NSLocalizedString("Advanced", comment: "Settings pane")
        }
    }

    /// Longer subtitle shown beneath the large page title in the content area.
    var subtitle: String {
        switch self {
        case .general:       NSLocalizedString("Core preferences for the island.", comment: "Settings page subtitle")
        case .islandDisplay: NSLocalizedString("Arrange and toggle visible modules.", comment: "Settings page subtitle")
        case .modules:       NSLocalizedString("Configure each module's behaviour.", comment: "Settings page subtitle")
        case .appearance:    NSLocalizedString("Animation and compact sizing.", comment: "Settings page subtitle")
        case .extensions:    NSLocalizedString("Connect third-party services.", comment: "Settings page subtitle")
        case .advanced:      NSLocalizedString("Diagnostics, debug, and about.", comment: "Settings page subtitle")
        }
    }

    var icon: String {
        switch self {
        case .general:       "gear"
        case .islandDisplay: "rectangle.split.3x1"
        case .modules:       "square.grid.2x2"
        case .appearance:    "paintbrush"
        case .extensions:    "puzzlepiece.extension"
        case .advanced:      "wrench.and.screwdriver"
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
        // vibrant purple gradient backdrop + a radial glow so the floating
        // cards sit over a rich base.
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
    // A semi-solid translucent panel on the left — kept just faintly
    // translucent so it reads as a distinct layer from the floating content
    // cards. The active row gets a clean purple gradient capsule; inactive
    // rows get a soft hover fill. Separation comes from spacing/transparency,
    // not a hard divider.

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Brand mark at the top — a small gradient pill so the window has an
            // identity anchor above the traffic-light buttons.
            brandMark
                .padding(.horizontal, 14)
                .padding(.top, 40) // clears the transparent title bar
                .padding(.bottom, 22)

            ForEach(SettingsPane.allCases) { pane in
                sidebarRow(pane)
            }
            Spacer(minLength: 12)
            quitRow
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .frame(width: 244)
        // Semi-solid sidebar fill — translucent (not frosted) so it sits as a
        // distinct layer beneath the floating content cards.
        .background(
            NexusPalette.background.opacity(0.55)
        )
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
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .shadow(color: NexusPalette.electricViolet.opacity(0.40), radius: 4, y: 1)
            Text("Nexus Island")
                .font(.system(size: 14, weight: .semibold))
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
            HStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundColor(SettingsGlass.idleIcon)
                    .frame(width: 20, alignment: .center)
                Text(NSLocalizedString("Quit", comment: "Settings label"))
                    .font(.system(size: 13))
                    .foregroundColor(SettingsGlass.idleText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area
    //
    // Every pane scrolls inside a uniformly padded container (32pt horizontal,
    // 32pt top / 28pt bottom) and is preceded by a large page title + subtitle
    // so the window reads as a premium dashboard. Extensions and Island
    // Display panes embed their own scroll handling.

    private var contentArea: some View {
        ScrollView {
            detailContent
                .padding(.horizontal, 32)
                .padding(.top, 34) // clears the transparent title bar
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var detailContent: some View {
        // Wrapped so we can apply a transition + id across the switched view.
        VStack(alignment: .leading, spacing: 24, content: {
            // Large page header — title + subtitle — matches the premium
            // dashboard look in the reference design.
            SettingsPageHeader(pane: selectedPane)

            Group {
                switch selectedPane {
                case .general:       GeneralSettingsView()
                case .islandDisplay: IslandDisplaySettingsView()
                case .modules:       ModuleSettingsView()
                case .appearance:    AppearanceSettingsView()
                case .extensions:    ExtensionsSettingsView()
                case .advanced:      AdvancedSettingsView()
                }
            }
            // Gentle fade + scale when switching panes.
            .transition(
                appState.shouldReduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.985))
            )
        })
        .animation(.easeInOut(duration: 0.2), value: selectedPane)
        .id(selectedPane) // force re-render so the transition fires
    }
}

// MARK: - Large page header (title + subtitle)

private struct SettingsPageHeader: View {
    let pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pane.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(NexusPalette.textPrimary)
            Text(pane.subtitle)
                .font(.system(size: 13))
                .foregroundColor(NexusPalette.textSecondary)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Sidebar Row Label (extracted for hover state)

private struct SidebarRowLabel: View {
    let icon: String
    let title: String
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? SettingsGlass.activeIcon : SettingsGlass.idleIcon)
                .frame(width: 20, alignment: .center)
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? SettingsGlass.activeText : SettingsGlass.idleText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? AnyShapeStyle(SettingsGlass.activeCapsule)
                        : AnyShapeStyle(isHovering ? SettingsGlass.hoverCapsule : Color.clear)
                )
        )
        // Active row gets a subtle inner gradient ring.
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(colors: [NexusPalette.electricViolet.opacity(0.40), .clear],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        )
        .shadow(color: isSelected ? NexusPalette.royalPurple.opacity(0.25) : .clear, radius: 8, y: 2)
        .scaleEffect(isHovering && !isSelected ? 1.005 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovering = hovering }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared Components (floating-card redesign)
//
// These cascade to General, Modules, Appearance, Advanced, and (after its
// rebuild) Extensions panes. Generous padding, rounded corners, and the
// `.settingsGlassSurface()` floating treatment.

struct SettingSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(NexusPalette.electricViolet.opacity(0.80))
            .tracking(0.4)
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
            .padding(.leading, 24)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
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
                .frame(minWidth: 48, alignment: .center)

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
                .frame(width: 32, height: 30)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Rectangle()
                .fill(SettingsGlass.divider)
                .frame(height: 0.5)

            content
                .padding(16)
        }
        .settingsGlassSurface()
    }
}
