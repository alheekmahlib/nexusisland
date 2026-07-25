# Nexus Island Redesign — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a centralized `NexusDesign` system and apply the vibrant purple→magenta→orange glassmorphism theme to the island surface and 4 pilot modules.

**Architecture:** New `Utilities/NexusDesign/` module holds all visual tokens (colors, gradients, typography, metrics) and reusable components (`GlassCard`, `GradientProgressBar`, `GradientMedallion`, `NeonButton`, `SparklineChart`, `GradientTab`). The island surface switches to a gradient fill in expanded/fullExpanded states (compact stays black). Pilot modules are restyled in place using the new tokens, keeping existing router wiring.

**Tech Stack:** SwiftUI (macOS 14+), Pow (SPM), Lottie (SPM), Swift Charts (built-in). XcodeGen-managed project.

## Global Constraints

- macOS deployment target: **14.0** (from `project.yml:5,14`)
- Swift 5.9; XcodeGen project; regenerate with `xcodegen generate` after `project.yml` edits
- Dark mode only (no light-mode tokens needed)
- **Compact island surface stays BLACK** (`Color.black 0.98→0.94`) — only expanded/fullExpanded get the gradient
- Respect reduce-motion: `appState.shouldReduceMotion` / `shouldReduceAnimations` (fall back to `.easeOut(duration: 0.12-0.14)`)
- Preserve RTL: Arabic `Text` uses `.environment(\.layoutDirection, .rightToLeft)` only on the text, not surrounding layout
- Do not delete old module view files during pilot — restyle in place
- Build must pass after every task: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build`

---

## File Structure

**New files (all under `SuperIsland/Utilities/NexusDesign/`):**
- `Color+Hex.swift` — `Color(hex:)` initializer
- `NexusPalette.swift` — color tokens
- `NexusGradient.swift` — gradient tokens
- `NexusTypography.swift` — font scale
- `NexusMetrics.swift` — corner radii / spacing / blur
- `NexusSurface.swift` — `nexusSurface()` modifier + `GlassCard` wrapper
- `GradientProgressBar.swift` — horizontal/circular gradient progress
- `GradientMedallion.swift` — icon medallion with glow
- `NeonButton.swift` — gradient button with press animation
- `SparklineChart.swift` — Swift Charts sparkline with glowing endpoint

**Modified files:**
- `project.yml` — add Pow + Lottie SPM packages
- `SuperIsland/Views/IslandContainerView.swift:40-53` — gradient surface in expanded/fullExpanded
- `SuperIsland/Modules/Battery/BatteryCompactView.swift` — restyle
- `SuperIsland/Modules/Battery/BatteryExpandedView.swift` — restyle + SparklineChart
- `SuperIsland/Modules/Quran/QuranCompactView.swift` — restyle
- `SuperIsland/Modules/Quran/QuranExpandedView.swift` — restyle
- `SuperIsland/Modules/Quran/QuranFullExpandedView.swift` — restyle
- `SuperIsland/Modules/PrayerTimes/PrayerTimesViews.swift` — restyle
- `SuperIsland/Modules/NowPlaying/NowPlayingExpandedView.swift` — restyle

---

## Task 1: Color(hex:) initializer

**Files:**
- Create: `SuperIsland/Utilities/NexusDesign/Color+Hex.swift`

**Produces:** `Color(hex:)` used by all subsequent tasks.

- [ ] **Step 1: Create the initializer**

```swift
import SwiftUI

extension Color {
    /// Initialize from a hex string. Accepts `#RRGGBB`, `#RGB`, `#RRGGBBAA`,
    /// and the same forms without `#`. Falls back to clear on invalid input.
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r, g, b, a: Double
        switch sanitized.count {
        case 3: // #RGB
            (r, g, b, a) = (Double((rgb >> 8) & 0xF) / 15,
                            Double((rgb >> 4) & 0xF) / 15,
                            Double(rgb & 0xF) / 15, 1)
        case 6: // #RRGGBB
            (r, g, b, a) = (Double((rgb >> 16) & 0xFF) / 255,
                            Double((rgb >> 8) & 0xFF) / 255,
                            Double(rgb & 0xFF) / 255, 1)
        case 8: // #RRGGBBAA
            (r, g, b, a) = (Double((rgb >> 24) & 0xFF) / 255,
                            Double((rgb >> 16) & 0xFF) / 255,
                            Double((rgb >> 8) & 0xFF) / 255,
                            Double(rgb & 0xFF) / 255)
        default:
            (r, g, b, a) = (0, 0, 0, 0)
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add SuperIsland/Utilities/NexusDesign/Color+Hex.swift
git commit -m "NexusDesign: Color(hex:) initializer"
```

---

## Task 2: NexusPalette + NexusGradient + NexusTypography + NexusMetrics

**Files:**
- Create: `SuperIsland/Utilities/NexusDesign/NexusPalette.swift`
- Create: `SuperIsland/Utilities/NexusDesign/NexusGradient.swift`
- Create: `SuperIsland/Utilities/NexusDesign/NexusTypography.swift`
- Create: `SuperIsland/Utilities/NexusDesign/NexusMetrics.swift`

**Consumes:** `Color(hex:)` from Task 1.

- [ ] **Step 1: NexusPalette.swift**

```swift
import SwiftUI

enum NexusPalette {
    // Background (from the app icon)
    static let background     = Color(hex: "#1A0B2E")
    static let backgroundGlow = Color(hex: "#2D1B4E")

    // Primary vibrant gradient (from design doc)
    static let gradientStart  = Color(hex: "#6A0DAD") // deep purple
    static let gradientMid    = Color(hex: "#E91E63") // vibrant magenta
    static let gradientEnd    = Color(hex: "#FFC107") // bright orange/yellow

    // Accents
    static let accentGold     = Color(hex: "#FBA046")
    static let neonPurple     = Color(hex: "#B833FF")
    static let neonOrange     = Color(hex: "#FF6B35")

    // Text
    static let textPrimary    = Color(hex: "#FFFFFF")
    static let textSecondary  = Color(hex: "#CCCCCC")
    static let textTertiary   = Color.white.opacity(0.55)

    // Status
    static let success        = Color(hex: "#4CAF50")
    static let warning        = Color(hex: "#FFC107")
    static let danger         = Color(hex: "#F44336")
}
```

- [ ] **Step 2: NexusGradient.swift**

```swift
import SwiftUI

enum NexusGradient {
    /// Primary purple→magenta→orange, diagonal.
    static var primary: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.gradientStart, NexusPalette.gradientMid, NexusPalette.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Higher-saturation variant for accents.
    static var vibrant: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.neonPurple, NexusPalette.gradientMid, NexusPalette.neonOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Central radial glow for the island background.
    static var backgroundRadial: RadialGradient {
        RadialGradient(
            colors: [NexusPalette.backgroundGlow, NexusPalette.background],
            center: .center,
            startRadius: 0,
            endRadius: 400
        )
    }

    /// Soft gold gradient.
    static var accentGold: LinearGradient {
        LinearGradient(
            colors: [NexusPalette.accentGold, NexusPalette.accentGold.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Progress fill that shifts toward orange as it nears completion.
    static func progress(at value: Double) -> LinearGradient {
        let clamped = min(max(value, 0), 1)
        if clamped < 0.5 {
            return LinearGradient(colors: [NexusPalette.gradientStart, NexusPalette.gradientMid],
                                  startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [NexusPalette.gradientMid, NexusPalette.gradientEnd],
                                  startPoint: .leading, endPoint: .trailing)
        }
    }
}
```

- [ ] **Step 3: NexusTypography.swift**

```swift
import SwiftUI

enum NexusTypography {
    static let hero     = Font.system(size: 24, weight: .bold)
    static let subtitle = Font.system(size: 18, weight: .semibold)
    static let title    = Font.system(size: 15, weight: .semibold)
    static let body     = Font.system(size: 14, weight: .regular)
    static let caption  = Font.system(size: 11, weight: .medium)
    static func numeric(_ size: CGFloat = 36) -> Font { .system(size: size, weight: .bold) }
    static let mono     = Font.system(size: 10, weight: .regular, design: .monospaced)
}
```

- [ ] **Step 4: NexusMetrics.swift**

```swift
import SwiftUI

enum NexusMetrics {
    static let cornerRadiusS: CGFloat = 10
    static let cornerRadiusM: CGFloat = 16
    static let cornerRadiusL: CGFloat = 24
    static let blurStandard: CGFloat  = 20
    static let strokeHairline: CGFloat = 0.5
    static let spacingUnit: CGFloat = 8
}
```

- [ ] **Step 5: Commit**

```bash
git add SuperIsland/Utilities/NexusDesign/NexusPalette.swift SuperIsland/Utilities/NexusDesign/NexusGradient.swift SuperIsland/Utilities/NexusDesign/NexusTypography.swift SuperIsland/Utilities/NexusDesign/NexusMetrics.swift
git commit -m "NexusDesign: palette, gradients, typography, metrics tokens"
```

---

## Task 3: NexusSurface modifier + GlassCard

**Files:**
- Create: `SuperIsland/Utilities/NexusDesign/NexusSurface.swift`

**Consumes:** `NexusPalette`, `NexusGradient`, `NexusMetrics`.

- [ ] **Step 1: Create the modifier + wrapper**

```swift
import SwiftUI

/// Glassmorphism surface: optional Material + gradient wash + hairline stroke + soft shadow.
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
                    if variant == .filled { Material.ultraThin }
                    if let gradient { gradient.opacity(0.30) }
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
        content().modifier(NexusSurface(variant: variant, isActive: isActive, radius: radius, gradient: gradient))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add SuperIsland/Utilities/NexusDesign/NexusSurface.swift
git commit -m "NexusDesign: nexusSurface() modifier + GlassCard"
```

---

## Task 4: GradientProgressBar, GradientMedallion, NeonButton, SparklineChart

**Files:**
- Create: `SuperIsland/Utilities/NexusDesign/GradientProgressBar.swift`
- Create: `SuperIsland/Utilities/NexusDesign/GradientMedallion.swift`
- Create: `SuperIsland/Utilities/NexusDesign/NeonButton.swift`
- Create: `SuperIsland/Utilities/NexusDesign/SparklineChart.swift`

- [ ] **Step 1: GradientProgressBar.swift**

```swift
import SwiftUI

/// Horizontal or circular gradient progress bar with a soft glow.
struct GradientProgressBar: View {
    enum Style { case hairline, thick, circular }

    var progress: Double
    var style: Style = .thick
    var height: CGFloat = 6
    var gradient: LinearGradient = NexusGradient.primary
    var animated: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        switch style {
        case .hairline: hairline
        case .thick:    thick
        case .circular: circular
        }
    }

    private var hairline: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(gradient)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: NexusPalette.gradientMid.opacity(0.6), radius: 2)
            }
        }
        .frame(height: 2)
    }

    private var thick: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height/2).fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: height/2)
                    .fill(gradient)
                    .frame(width: proxy.size.width * clamped)
                    .shadow(color: NexusPalette.gradientMid.opacity(0.5), radius: 3)
            }
        }
        .frame(height: height)
        .animation(animated ? .easeInOut(duration: 0.3) : nil, value: clamped)
    }

    private var circular: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: height)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(gradient, style: StrokeStyle(lineWidth: height, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: NexusPalette.gradientMid.opacity(0.5), radius: 3)
        }
        .animation(animated ? .easeInOut(duration: 0.3) : nil, value: clamped)
    }
}
```

- [ ] **Step 2: GradientMedallion.swift**

```swift
import SwiftUI

/// Circular icon medallion with a gradient fill and outer glow.
struct GradientMedallion: View {
    var systemName: String
    var size: CGFloat = 38
    var iconScale: CGFloat = 0.5
    var gradient: LinearGradient = NexusGradient.primary
    var isActive: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .shadow(color: NexusPalette.gradientMid.opacity(isActive ? 0.7 : 0.4), radius: isActive ? 8 : 4)
            Image(systemName: systemName)
                .font(.system(size: size * iconScale, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
```

- [ ] **Step 3: NeonButton.swift**

```swift
import SwiftUI

/// Gradient button with a press scale + glow.
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
                .shadow(color: NexusPalette.gradientMid.opacity(pressed ? 0.3 : 0.6), radius: pressed ? 3 : 6)
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
```

- [ ] **Step 4: SparklineChart.swift** (uses Swift Charts, built into macOS 13+)

```swift
import SwiftUI
import Charts

/// Sparkline using Swift Charts with a gradient line + glowing endpoint dot.
struct SparklineChart: View {
    var values: [Double]
    var gradient: LinearGradient = NexusGradient.primary
    var lineColor: Color = NexusPalette.gradientMid
    var endpointColor: Color = NexusPalette.gradientEnd

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("i", index),
                    y: .value("v", value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))

                if index == values.count - 1 {
                    PointMark(
                        x: .value("i", index),
                        y: .value("v", value)
                    )
                    .foregroundStyle(endpointColor)
                    .symbolSize(18)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.background(.clear) }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add SuperIsland/Utilities/NexusDesign/GradientProgressBar.swift SuperIsland/Utilities/NexusDesign/GradientMedallion.swift SuperIsland/Utilities/NexusDesign/NeonButton.swift SuperIsland/Utilities/NexusDesign/SparklineChart.swift
git commit -m "NexusDesign: GradientProgressBar, GradientMedallion, NeonButton, SparklineChart"
```

---

## Task 5: Add Pow + Lottie SPM dependencies

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add packages + dependencies to project.yml**

Add to the `packages:` section (after Aptabase, around line 19):

```yaml
  Pow:
    url: https://github.com/EmergeTools/Pow
    from: "1.0.0"
  Lottie:
    url: https://github.com/airbnb/lottie-ios
    from: "4.4.0"
```

Add to the NexusIsland target `dependencies:` (after `- package: Aptabase`, around line 33):

```yaml
      - package: Pow
      - package: Lottie
```

- [ ] **Step 2: Regenerate the Xcode project**

Run: `xcodegen generate`
Expected: `⚙  Generating plists ... ⚙  Generating project ... Created ./NexusIsland.xcodeproj` (or similar success)

- [ ] **Step 3: Resolve packages + build**

Run: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' -resolvePackageDependencies`
Then: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add project.yml NexusIsland.xcodeproj
git commit -m "Build: add Pow + Lottie SPM dependencies"
```

---

## Task 6: Gradient island surface (expanded/fullExpanded)

**Files:**
- Modify: `SuperIsland/Views/IslandContainerView.swift` (the `islandShape.fill(...)` at lines 44-53)

**Goal:** Compact stays black; expanded/fullExpanded get the vibrant gradient + radial glow.

- [ ] **Step 1: Replace the fill with a state-aware gradient**

In `IslandContainerView.swift`, replace the `islandShape.fill(LinearGradient(...))` block (lines 43-53):

```swift
            islandShape
                .fill(islandSurfaceFill)
```

Add a computed property near the other appearance helpers (e.g. after `compactContentOpacity`):

```swift
    /// Black in compact (blends with the real notch), vibrant gradient when expanded.
    private var islandSurfaceFill: AnyShapeStyle {
        if appState.currentState == .compact {
            return AnyShapeStyle(
                LinearGradient(colors: [Color.black.opacity(0.98), Color.black.opacity(0.94)],
                               startPoint: .top, endPoint: .bottom)
            )
        } else {
            // Layer: radial glow base, then the vibrant gradient on top.
            return AnyShapeStyle(
                ZStack {
                    NexusGradient.backgroundRadial
                    NexusGradient.primary
                }
            )
        }
    }
```

> Note: `.fill()` accepts `AnyShapeStyle`. If the ZStack layering causes a type issue, fall back to `.background { ZStack { islandShape.fill(...); islandShape.fill(...) } }`. Verify build in Step 2.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`. If the `AnyShapeStyle(ZStack...)` fails to compile, switch to the background-layering fallback and rebuild.

- [ ] **Step 3: Commit**

```bash
git add SuperIsland/Views/IslandContainerView.swift
git commit -m "UI: vibrant gradient island surface in expanded/fullExpanded (compact stays black)"
```

---

## Task 7: Restyle Battery module (compact + expanded + fullExpanded)

**Files:**
- Modify: `SuperIsland/Modules/Battery/BatteryCompactView.swift`
- Modify: `SuperIsland/Modules/Battery/BatteryExpandedView.swift`

**Goal:** Wrap expanded views in `GlassCard`, swap the inline sparkline for `SparklineChart`, use `NexusPalette` status colors + gradient on the battery bar.

- [ ] **Step 1: Restyle BatteryCompactView** — replace `batteryColor` with a gradient-aware variant, keep layout. Change the percentage text to use `NexusTypography.mono`.

- [ ] **Step 2: Restyle BatteryExpandedView** —
  - `defaultExpandedView`: wrap the right-hand `VStack` content; replace the `batteryBar` fill with `GradientProgressBar(progress: Double(manager.batteryLevel)/100, style: .thick, gradient: NexusGradient.progress(at: Double(manager.batteryLevel)/100))`.
  - `fullExpandedView`: wrap in `GlassCard`; replace `BatteryHistorySparkline` with `SparklineChart(values: manager.batteryHistory.map { Double($0.level) })`.
  - Keep `batteryColor` semantics for the icon.

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SuperIsland/Modules/Battery/
git commit -m "UI: restyle Battery module with NexusDesign (GlassCard, gradient bar, SparklineChart)"
```

---

## Task 8: Restyle Quran module (compact + expanded + fullExpanded)

**Files:**
- Modify: `SuperIsland/Modules/Quran/QuranCompactView.swift`
- Modify: `SuperIsland/Modules/Quran/QuranExpandedView.swift`
- Modify: `SuperIsland/Modules/Quran/QuranFullExpandedView.swift`

**Goal:** Swap `QuranDesign.accent` gold → `NexusGradient.primary` for active/progress, use `GradientProgressBar` for hairline, `GradientMedallion` for play icon, `GlassCard` for expanded cards. Keep RTL on Arabic text. Leave `QuranDesign` file in place (other modules still use it) — just override per-view.

- [ ] **Step 1: Restyle QuranCompactView** — replace `QuranHairlineProgress` with `GradientProgressBar(progress: manager.progress, style: .hairline)`; play toggle background uses `NexusGradient.primary` when playing.

- [ ] **Step 2: Restyle QuranExpandedView** — medallion → `GradientMedallion`; progress → `GradientProgressBar`; wrap identity column in `GlassCard`.

- [ ] **Step 3: Restyle QuranFullExpandedView** — now-playing card → `GlassCard`; sidebar rows use `nexusSurface(isActive:)`.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SuperIsland/Modules/Quran/
git commit -m "UI: restyle Quran module with NexusDesign (gradient progress, medallion, GlassCard)"
```

---

## Task 9: Restyle PrayerTimes module

**Files:**
- Modify: `SuperIsland/Modules/PrayerTimes/PrayerTimesViews.swift`

**Goal:** Use `GradientProgressBar` for the prayer progress (shifting color via `NexusGradient.progress(at:)`), `GradientMedallion` for the prayer icon, `GlassCard` for the hero card and list rows. Keep RTL.

- [ ] **Step 1:** Replace `PrayerProgressBar` / `PrayerProgressHairline` usage with `GradientProgressBar`, wrapped where appropriate.
- [ ] **Step 2:** Hero medallion → `GradientMedallion(systemName: nextPrayer.iconName)`.
- [ ] **Step 3:** Build + commit.

```bash
git add SuperIsland/Modules/PrayerTimes/PrayerTimesViews.swift
git commit -m "UI: restyle PrayerTimes module with NexusDesign (gradient progress, medallion, GlassCard)"
```

---

## Task 10: Restyle NowPlaying module

**Files:**
- Modify: `SuperIsland/Modules/NowPlaying/NowPlayingExpandedView.swift`

**Goal:** Swap the local `ProgressBar` for `GradientProgressBar`, transport buttons → `NeonButton`, wrap sections in `GlassCard`.

- [ ] **Step 1:** `compactExpandedView` progress → `GradientProgressBar`; play button → `NeonButton`.
- [ ] **Step 2:** `fullView` transport controls → `NeonButton`; wrap identity in `GlassCard`.
- [ ] **Step 3:** Build + commit.

```bash
git add SuperIsland/Modules/NowPlaying/NowPlayingExpandedView.swift
git commit -m "UI: restyle NowPlaying module with NexusDesign (gradient progress, NeonButton, GlassCard)"
```

---

## Task 11: Final full build + verification

- [ ] **Step 1: Clean build**

Run: `xcodebuild -scheme NexusIsland -configuration Debug -destination 'platform=macOS' clean build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Verify no reduce-motion regressions** — grep that new animations check `shouldReduceMotion` where appropriate (the shared components already animate with `.easeInOut`; large state transitions still use `appState.notchAnimation`).

- [ ] **Step 3: Final commit if any cleanup**

```bash
git add -A
git commit -m "Nexus Island Phase 1 redesign: design system + 4 pilot modules" || echo "nothing to commit"
```

---

## Self-Review Notes

- **Spec coverage:** §4.1–4.7 → Tasks 1–4; §5 → Task 6; §6.1–6.3 → Tasks 7–10; §7 → Task 5; §8 → build gates in every task. ✓
- **Type consistency:** `NexusGradient.primary`, `NexusPalette.gradientMid`, `GradientProgressBar(progress:style:gradient:)`, `GradientMedallion(systemName:size:)`, `NeonButton(systemName:size:action:)`, `GlassCard { ... }`, `.nexusSurface(isActive:)` — names match across tasks. ✓
- **Rive deferred** per spec — Swift Charts `SparklineChart` + `Canvas`-based gradient progress serve as the baseline; no `rive-apple` dependency added. ✓
- **Compact stays black** — Task 6 explicitly preserves the black compact fill. ✓
