import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState

    // Canonical defaults — source of truth for the per-section Reset buttons
    // and for the @AppStorage initial values in AppState.
    private enum Defaults {
        static let bounceAmount: Double = 0.25
        static let animationLevel = AnimationLevel.full
        static let reduceMotion = false
        static let compactIslandWidth: Double = 200
        static let compactIslandHeight: Double = 36
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            section(
                title: NSLocalizedString("Animation", comment: "Settings section"),
                reset: {
                    appState.animationLevel = Defaults.animationLevel
                    appState.reduceMotion = Defaults.reduceMotion
                    appState.bounceAmount = Defaults.bounceAmount
                }
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Animation intensity", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("Controls island motion and transition strength", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    Picker("", selection: $appState.animationLevelRaw) {
                        ForEach(AnimationLevel.allCases) { level in
                            Text(level.title).tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                SettingRowDivider()
                SettingToggleRow(
                    title: NSLocalizedString("Reduce motion", comment: "Settings label"),
                    description: NSLocalizedString("Simplify island transitions and content swaps", comment: "Settings description"),
                    isOn: $appState.reduceMotion
                )

                SettingRowDivider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Bounce", comment: "Settings label")).font(.system(size: 13))
                        Text(NSLocalizedString("Spring bounce for compact ↔ expanded transitions", comment: "Settings description"))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    StepperField(
                        value: $appState.bounceAmount,
                        step: 0.05,
                        range: 0.0...0.5
                    ) { "\(Int(($0 * 100).rounded()))%" }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }

            section(
                title: NSLocalizedString("Compact Island Size", comment: "Settings section"),
                reset: {
                    appState.compactIslandWidth = Defaults.compactIslandWidth
                    appState.compactIslandHeight = Defaults.compactIslandHeight
                }
            ) {
                sizeRow(
                    title: NSLocalizedString("Width", comment: "Settings label"),
                    description: NSLocalizedString("Pill width on notched Macs", comment: "Settings description"),
                    value: $appState.compactIslandWidth,
                    step: 2,
                    range: 140...320,
                    unit: "pt"
                )
                SettingRowDivider()
                sizeRow(
                    title: NSLocalizedString("Height", comment: "Settings label"),
                    description: NSLocalizedString("Pill height on notched Macs", comment: "Settings description"),
                    value: $appState.compactIslandHeight,
                    step: 1,
                    range: 28...60,
                    unit: "pt"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        reset: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SettingSectionLabel(title: title)
            Button(NSLocalizedString("Reset", comment: "Button"), action: reset)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
        }
        SettingGroup {
            content()
        }
    }

    private func sizeRow(
        title: String,
        description: String,
        value: Binding<Double>,
        step: Double,
        range: ClosedRange<Double>,
        unit: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(description)
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            StepperField(
                value: value,
                step: step,
                range: range
            ) { "\(Int($0.rounded())) \(unit)" }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
