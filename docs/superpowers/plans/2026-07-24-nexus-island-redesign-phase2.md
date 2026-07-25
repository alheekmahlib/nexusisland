# Nexus Island Redesign — Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the remaining 18 modules to the NexusDesign system (palette, gradients, glass surfaces, typography, shared components) so the whole app shares one visual language.

**Architecture:** A size-parameterized extension to `NexusTypography` preserves exact current font sizes (no layout drift). Then each module swaps `QuranDesign.*` tokens and raw `.white.opacity(...)` literals for `NexusPalette`/`NexusGradient`/`.nexusSurface(.glass)`/`NexusTypography`, keeping semantic colors (status green/red, per-calendar colors) mapped to palette tokens.

**Tech Stack:** SwiftUI (macOS 14+). No new dependencies (Pow/Lottie/Charts already added in Phase 1).

## Global Constraints

- macOS deployment target: **14.0**
- XcodeGen project; regenerate after `project.yml` edits (no project.yml changes this phase)
- Dark mode only
- **Preserve exact current font sizes** — use the new parameterized `NexusTypography.*(_ size:)` helpers, never the fixed-scale tokens, in migrated modules
- **Semantic colors preserved but remapped**: `.green`→`NexusPalette.success`, `.red`→`.danger`, `.orange`→`.warning`, `.gray`→`.textTertiary`. Per-calendar `cgColor` stays as-is (user data).
- `.quranSurface(...)` → `.nexusSurface(variant: .glass, ...)`. Always pass `radius: NexusMetrics.cornerRadiusS` on list rows.
- `QuranDesign.accent` (gold) → `NexusPalette.electricViolet` (or `NexusGradient.purple` for filled icon backgrounds)
- Compact island surface stays BLACK; gradient only on expanded/fullExpanded (no change — Phase 1)
- Build must pass after every task: `xcodebuild -project NexusIsland.xcodeproj -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build`

---

## Task 0: Parameterized NexusTypography helpers

**Files:**
- Modify: `SuperIsland/Utilities/NexusDesign/NexusTypography.swift`

**Goal:** Add size-parameterized variants so migrated modules keep their exact pt sizes. The existing fixed-scale tokens stay for new code.

- [ ] **Step 1: Add parameterized helpers**

Append to `NexusTypography`:

```swift
    // MARK: - Size-parameterized variants (for migrated modules that need
    // exact pt sizes on the tight Dynamic Island surfaces). Prefer the fixed
    // tokens above in new code; use these only when preserving a prior size.

    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat, _ weight: Font.Weight) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
```

- [ ] **Step 2: Build + commit**

```bash
xcodebuild -project NexusIsland.xcodeproj -scheme NexusIsland -configuration Debug -destination 'platform=macOS' build 2>&1 | grep "BUILD"
git add SuperIsland/Utilities/NexusDesign/NexusTypography.swift
git commit -m "NexusDesign: add size-parameterized typography helpers (Phase 2)"
```

---

## Task 1: System/Info modules batch (Weather, Connectivity, Calendar, Notifications, Shelf, SystemHUD)

These use raw `.white.opacity()` and `.system(size:)` — migrate to NexusDesign raw-token adoption.

**Files:** (per the Phase-2 exploration report)
- `SuperIsland/Modules/Weather/WeatherCompactView.swift` (27L), `WeatherExpandedView.swift` (148L)
- `SuperIsland/Modules/Connectivity/ConnectivityCompactView.swift` (42L), `ConnectivityExpandedView.swift` (127L)
- `SuperIsland/Modules/Calendar/CalendarCompactView.swift` (24L), `CalendarExpandedView.swift` (550L)
- `SuperIsland/Modules/Notifications/NotificationCompactView.swift` (110L), `NotificationExpandedView.swift` (491L)
- `SuperIsland/Modules/Shelf/ShelfViews.swift` (595L)
- `SuperIsland/Modules/SystemHUD/SystemHUDCompactView.swift` (54L), `SystemHUDExpandedView.swift` (242L)

**Per-file restyle targets (summary — see exploration report for line numbers):**

For each file: `.font(.system(size:N))` → `NexusTypography.caption/body/mono/numeric(N)` (matching size); `.foregroundColor(.white)` → `NexusPalette.textPrimary`; `.white.opacity(0.6-0.7)` → `.textSecondary`; `.white.opacity(0.35-0.5)` → `.textTertiary`. Hand-built card chrome (`RoundedRectangle.fill(.white.opacity(...))`) → `.nexusSurface(.glass)` or `GlassCard`. Circular icon badges → `GradientMedallion(gradient: .purple)`.

Special handling:
- **Connectivity**: keep green/red status semantics → `success`/`danger`; Wi-Fi `.blue` → `electricViolet`.
- **Calendar**: keep per-event `cgColor` (user data); `Color.blue.opacity(0.4)` selected-day → `NexusGradient.purple`; Join button → `NeonButton`.
- **Notifications**: `backgroundView` card chrome (L403-416) → `GlassCard(variant:.glass, isActive:featured)`.
- **Shelf**: `TrayDropPane`/`ExpandedShelfChip` panels → `GlassCard`; `Color.black.opacity(0.28)` badges → `.nexusSurface(.glass)`; `AirDropDropPane` icon → `GradientMedallion`.
- **SystemHUD**: `SliderBar` is **interactive** (drag gesture) — keep it but recolor: track→`Color.white.opacity(0.12)`, fill→`NexusGradient.primary`. Do NOT replace with display-only `GradientProgressBar`. Compact slim bar → `GradientProgressBar(style:.hairline)`.

- [ ] **Step 1: Restyle Weather + Connectivity + SystemHUD** (smaller files first)
- [ ] **Step 2: Restyle Calendar** (largest — careful with the 550L file; keep cgColor bars)
- [ ] **Step 3: Restyle Notifications + Shelf**
- [ ] **Step 4: Build + commit after each sub-batch**

---

## Task 2: Dev modules batch (GitHub, CIMonitor, DevServers, GitStats, Docker)

These all use `QuranDesign.*` tokens (289 call sites across 5 files). Mechanical migration.

**Files:**
- `SuperIsland/Modules/GitHub/GitHubViews.swift` (357L)
- `SuperIsland/Modules/CIMonitor/CIViews.swift` (313L)
- `SuperIsland/Modules/DevServers/DevServerViews.swift` (168L)
- `SuperIsland/Modules/GitStats/GitStatsViews.swift` (253L)
- `SuperIsland/Modules/Docker/DockerViews.swift` (215L)

**Migration map (applies uniformly):**
- `QuranDesign.accent` → `NexusPalette.electricViolet`
- `QuranDesign.accentSoft` → `NexusPalette.electricViolet.opacity(0.18)`
- `QuranDesign.textPrimary/Secondary/Tertiary` → `NexusPalette.*`
- `QuranDesign.surfaceStroke` (in Dividers) → `NexusPalette.glassTint.opacity(0.10)`
- `QuranDesign.surfaceFillActive` → `NexusPalette.electricViolet.opacity(0.14)`
- `QuranDesign.cornerRadiusS/M/L` → `NexusMetrics.cornerRadiusS/M/L`
- `QuranDesign.surahName(N)` → `NexusTypography.title(N)`
- `QuranDesign.body(N)` → `NexusTypography.body(N)`
- `QuranDesign.caption(N)` → `NexusTypography.caption(N)`
- `QuranDesign.mono(N)` → `NexusTypography.mono(N)`
- `.quranSurface(isActive:radius:)` → `.nexusSurface(variant:.glass, isActive:radius:)`

Semantic: `.green`→`success`, `.red`→`danger`, `.orange`→`warning`, `.gray`→`textTertiary`, `.blue`/`.purple` (GitHub categorical) → `royalPurple`/`electricViolet`.

- [ ] **Step 1: Restyle GitHub + CIMonitor** (have tab bars)
- [ ] **Step 2: Restyle DevServers + GitStats + Docker**
- [ ] **Step 3: Build + commit after each sub-batch**

---

## Task 3: Daily-Use modules batch (WorldClock, Currency, Countdown, Stocks, Reminders, Clipboard)

Single-file modules using `QuranDesign.*`. Same migration map as Task 2.

**Files:**
- `SuperIsland/Modules/WorldClock/WorldClockModule.swift` (197L)
- `SuperIsland/Modules/Currency/CurrencyModule.swift` (173L)
- `SuperIsland/Modules/Countdown/CountdownModule.swift` (187L)
- `SuperIsland/Modules/Stocks/StocksModule.swift` (166L)
- `SuperIsland/Modules/Reminders/RemindersModule.swift` (209L)
- `SuperIsland/Modules/Clipboard/ClipboardModule.swift` (177L)

Special handling:
- **WorldClock**: day/night `.yellow`→`amber`, `.indigo`→`electricViolet`.
- **Stocks**: price `.green`/`.red`→`success`/`danger`. Display numerals → `NexusTypography.numeric(N)`.
- **Reminders**: overdue `.red`→`danger`; checkbox `accent`→`electricViolet`; all-done `.green`→`success`.
- **Clipboard**: Clear-All `.red`→`danger`.

- [ ] **Step 1: Restyle all 6 modules**
- [ ] **Step 2: Build + commit**

---

## Task 4: Teleprompter module

**Files:**
- `SuperIsland/Modules/Teleprompter/TeleprompterCompactView.swift` (51L)
- `SuperIsland/Modules/Teleprompter/TeleprompterExpandedView.swift` (529L)
- `SuperIsland/Modules/Teleprompter/TeleprompterWordTrackingView.swift` (398L)

Raw `.white.opacity()` adoption. Keep the user-controlled script font size (dynamic `manager.fontSize`). Status pill bg → `.nexusSurface(.glass)`. Bold play/pause `iconButton` → consider `NeonButton`. Speech status `.orange`→`warning`.

- [ ] **Step 1: Restyle 3 files**
- [ ] **Step 2: Build + commit**

---

## Task 5: Final verification + commit

- [ ] **Step 1: Verify no QuranDesign references remain outside the Quran module**

```bash
grep -rln "QuranDesign" SuperIsland/Modules/ --include="*.swift" | grep -v "/Quran/" | wc -l
```
Expected: `0`

- [ ] **Step 2: Clean build**

```bash
xcodebuild -project NexusIsland.xcodeproj -scheme NexusIsland -configuration Debug -destination 'platform=macOS' clean build 2>&1 | grep "BUILD"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Launch + visual verification**

- [ ] **Step 4: Final commit if cleanup needed**

```bash
git add -A && git commit -m "Nexus Island Phase 2: migrate all 18 modules to NexusDesign" || echo "nothing to commit"
```

---

## Self-Review Notes

- **Spec coverage:** Phase-1 spec §9 "scope — what this phase won't do" (the 18 modules) is now covered by Tasks 1-4. ✓
- **Typography:** Task 0 adds parameterized helpers BEFORE any module migration — sizes preserved. ✓
- **Semantic colors:** explicitly mapped, not lost (connectivity, calendar, docker status, stock prices, reminders). ✓
- **Interactive components preserved:** SystemHUD `SliderBar` (drag) and Calendar action buttons handled specially — not blindly replaced with display-only components. ✓
- **`QuranDesign` file itself stays** — the Quran module still uses its `formatTime` helper; only the *other* 11 modules migrate off it. ✓
