import SwiftUI

// MARK: - Prayer Times Compact View (pill)
//
// Redesigned with NexusDesign. 200×36pt — single row: next-prayer icon +
// name + countdown, with a gradient hairline for the inter-prayer interval.

struct PrayerTimesCompactView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        if let next = manager.nextPrayerInfo {
            HStack(spacing: 6) {
                Image(systemName: next.kind.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(NexusGradient.primary))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(next.kind.arabicName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(NexusPalette.textPrimary)
                            .lineLimit(1)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(next.countdown)
                            .font(NexusTypography.mono)
                            .foregroundColor(NexusPalette.textSecondary)
                    }
                    // Progress hairline: elapsed fraction of the current
                    // inter-prayer interval, gradient fill.
                    if let fraction = manager.progressFraction {
                        GradientProgressBar(progress: fraction, style: .hairline, animated: false)
                            .frame(width: 60, height: 2)
                    }
                }
            }
        } else if manager.isLoading {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundColor(NexusPalette.textSecondary)
                Text("…")
                    .font(NexusTypography.body)
                    .foregroundColor(NexusPalette.textSecondary)
            }
        } else {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 12))
                .foregroundColor(NexusPalette.textSecondary)
        }
    }
}

// MARK: - Prayer Times Expanded View (drawer)
//
// Redesigned with NexusDesign. 408×88pt — HStack: gradient medallion +
// name/countdown + full day list.

struct PrayerTimesExpandedView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if let next = manager.nextPrayerInfo {
                medallion(next.kind)
                // Compact info: name + countdown only (the 88pt expanded height
                // can't fit the progress bar alongside the day list). The
                // progress bar lives in FullExpanded (180pt).
                VStack(alignment: .leading, spacing: 1) {
                    Text(next.kind.arabicName + " · " + next.countdown)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(NexusPalette.textPrimary)
                        .environment(\.layoutDirection, .rightToLeft)
                    locationBadge
                }
            } else {
                medallion(.isha)
                loadingInfo
            }

            Divider().background(Color.white.opacity(0.10)).frame(maxHeight: 60)

            // Compact list of the remaining prayers with their times.
            todayList
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var locationBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "location.fill").font(.system(size: 7)).foregroundColor(NexusPalette.accentGold)
            if !manager.locationName.isEmpty {
                Text(manager.locationName)
                    .font(.system(size: 7))
                    .foregroundColor(NexusPalette.textTertiary)
            } else {
                Text(String(format: "%.2f, %.2f", manager.resolvedLatitude, manager.resolvedLongitude))
                    .font(NexusTypography.mono)
                    .foregroundColor(manager.hasLocationFix ? NexusPalette.accentGold : NexusPalette.textTertiary)
            }
        }
    }

    private func medallion(_ kind: PrayerKind) -> some View {
        GradientMedallion(systemName: kind.iconName, size: 38, iconScale: 0.40)
    }

    private var loadingInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("جارٍ التحميل")
                .font(NexusTypography.body)
                .foregroundColor(NexusPalette.textSecondary)
        }
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach([PrayerKind.fajr, .dhuhr, .asr, .maghrib, .isha]) { kind in
                if let time = manager.schedule.times[kind] {
                    HStack(spacing: 6) {
                        Text(kind.arabicName)
                            .font(.system(size: 10))
                            .foregroundColor(NexusPalette.textSecondary)
                        Spacer(minLength: 4)
                        Text(Self.timeFormatter.string(from: time))
                            .font(NexusTypography.mono)
                            .foregroundColor(NexusPalette.textPrimary)
                    }
                    .frame(width: 90)
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Prayer Times Full Expanded View (detail panel)
//
// Redesigned with NexusDesign. 658×180pt — two columns: next-prayer hero
// (gradient medallion + gradient progress) + all six prayers list.

struct PrayerTimesFullExpandedView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        HStack(spacing: 0) {
            heroCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            prayersList
                .frame(width: 240)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let next = manager.nextPrayerInfo {
                HStack(spacing: 12) {
                    GradientMedallion(systemName: next.kind.iconName, size: 46, iconScale: 0.40, isActive: true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("الصلاة القادمة")
                            .font(NexusTypography.caption)
                            .foregroundColor(NexusPalette.textTertiary)
                        Text(next.kind.arabicName)
                            .font(NexusTypography.subtitle)
                            .foregroundColor(NexusPalette.textPrimary)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text("بعد " + next.countdown)
                            .font(NexusTypography.body)
                            .foregroundColor(NexusPalette.accentGold)
                    }
                    Spacer()
                }

                // Progress bar — gradient that warms toward orange near completion.
                let fraction = manager.progressFraction ?? 0
                let prevName = manager.previousPrayerInfo?.kind.arabicShortName ?? "—"
                VStack(spacing: 3) {
                    GradientProgressBar(
                        progress: max(0.05, fraction),
                        style: .thick,
                        height: 6,
                        gradient: NexusGradient.progress(at: fraction)
                    )
                    HStack {
                        Text(prevName).font(.system(size: 8)).foregroundColor(NexusPalette.textTertiary)
                        Spacer()
                        Text(next.kind.arabicShortName).font(.system(size: 8)).foregroundColor(NexusPalette.textTertiary)
                    }
                }
            } else {
                Text(manager.isLoading ? "جارٍ التحميل…" : "لا توجد بيانات")
                    .font(NexusTypography.body)
                    .foregroundColor(NexusPalette.textSecondary)
            }

            if let hijri = manager.schedule.hijriDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                        .foregroundColor(NexusPalette.accentGold)
                    Text(hijri + " هـ")
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }

            // Location badge so the user can verify which city the times are for.
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(manager.hasLocationFix ? NexusPalette.accentGold : NexusPalette.warning)
                if !manager.locationName.isEmpty {
                    Text(manager.locationName)
                        .font(.system(size: 11))
                        .foregroundColor(NexusPalette.textSecondary)
                } else {
                    Text(String(format: "%.2f, %.2f", manager.resolvedLatitude, manager.resolvedLongitude))
                        .font(NexusTypography.mono)
                        .foregroundColor(NexusPalette.textTertiary)
                }
                if !manager.hasLocationFix && manager.useAutoLocation {
                    Text("— بانتظار الموقع")
                        .font(.system(size: 9))
                        .foregroundColor(NexusPalette.warning)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)

            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var prayersList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("مواقيت اليوم")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.10))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(PrayerKind.allCases) { kind in
                        prayerRow(kind)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
    }

    private func prayerRow(_ kind: PrayerKind) -> some View {
        let isNext = manager.nextPrayerInfo?.kind == kind
        let hasTime = manager.schedule.times[kind] != nil
        return HStack(spacing: 8) {
            Image(systemName: kind.iconName)
                .font(.system(size: 10))
                .foregroundColor(isNext ? .white : NexusPalette.textTertiary)
                .frame(width: 18, height: 18)
                .background {
                    Circle().fill(isNext ? AnyShapeStyle(NexusGradient.primary) : AnyShapeStyle(Color.white.opacity(0.06)))
                }

            Text(kind.arabicName)
                .font(.system(size: isNext ? 12 : 11))
                .foregroundColor(isNext ? NexusPalette.textPrimary : NexusPalette.textSecondary)
                .environment(\.layoutDirection, .rightToLeft)

            Spacer()
            if let time = manager.schedule.times[kind] {
                Text(Self.timeFormatter.string(from: time))
                    .font(NexusTypography.mono)
                    .foregroundColor(isNext ? NexusPalette.accentGold : NexusPalette.textSecondary)
            } else if !hasTime {
                Text("--:--")
                    .font(NexusTypography.mono)
                    .foregroundColor(NexusPalette.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .nexusSurface(isActive: isNext, radius: NexusMetrics.cornerRadiusS)
        .contentShape(Rectangle())
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
