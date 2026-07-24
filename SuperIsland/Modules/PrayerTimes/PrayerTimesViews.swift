import SwiftUI

// MARK: - Prayer Times Compact View (pill)
//
// 200×36pt — single row: next-prayer icon + name + countdown.

struct PrayerTimesCompactView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        if let next = manager.nextPrayerInfo {
            HStack(spacing: 6) {
                Image(systemName: next.kind.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(QuranDesign.accent)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(QuranDesign.accentSoft))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(next.kind.arabicName)
                            .font(QuranDesign.surahName(11))
                            .foregroundColor(QuranDesign.textPrimary)
                            .lineLimit(1)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(next.countdown)
                            .font(QuranDesign.mono(9))
                            .foregroundColor(QuranDesign.textSecondary)
                    }
                    // Progress hairline: elapsed fraction of the current
                    // inter-prayer interval, gold fill.
                    if let fraction = manager.progressFraction {
                        PrayerProgressHairline(progress: fraction)
                            .frame(width: 60, height: 2)
                    }
                }
            }
        } else if manager.isLoading {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
                    .foregroundColor(QuranDesign.textSecondary)
                Text("…")
                    .font(QuranDesign.body(11))
                    .foregroundColor(QuranDesign.textSecondary)
            }
        } else {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 12))
                .foregroundColor(QuranDesign.textSecondary)
        }
    }
}

// MARK: - Prayer Times Expanded View (drawer)
//
// 408×88pt — HStack: next-prayer medallion + name/countdown + full day list.

struct PrayerTimesExpandedView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Location indicator — shows city or coordinates so the user
            // can verify the times are for the right place.
            locationBadge

            HStack(spacing: 12) {
                if let next = manager.nextPrayerInfo {
                    medallion(next.kind)
                    nextInfo(next)
                } else {
                    medallion(.isha)
                    loadingInfo
                }

                Divider().background(QuranDesign.surfaceStroke).frame(maxHeight: 60)

                // Compact list of the remaining prayers with their times.
                todayList
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var locationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill").font(.system(size: 8)).foregroundColor(QuranDesign.accent)
            if !manager.locationName.isEmpty {
                Text(manager.locationName)
                    .font(QuranDesign.caption(8))
                    .foregroundColor(QuranDesign.textTertiary)
            } else {
                // Show coordinates so the user sees which location is in use.
                Text(String(format: "%.2f, %.2f", manager.resolvedLatitude, manager.resolvedLongitude))
                    .font(QuranDesign.mono(8))
                    .foregroundColor(manager.hasLocationFix ? QuranDesign.accent : QuranDesign.textTertiary)
            }
            if !manager.hasLocationFix && manager.useAutoLocation {
                Text("(بانتظار الموقع)")
                    .font(QuranDesign.caption(7))
                    .foregroundColor(.orange)
            }
        }
    }

    private func medallion(_ kind: PrayerKind) -> some View {
        ZStack {
            Circle()
                .strokeBorder(QuranDesign.accent.opacity(0.5), lineWidth: 1)
                .background(Circle().fill(QuranDesign.accentSoft))
            Image(systemName: kind.iconName)
                .font(.system(size: 15))
                .foregroundColor(QuranDesign.accent)
        }
        .frame(width: 38, height: 38)
    }

    private func nextInfo(_ next: (kind: PrayerKind, date: Date, countdown: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(next.kind.arabicName + " · " + next.countdown)
                .font(QuranDesign.surahName(13))
                .foregroundColor(QuranDesign.textPrimary)
                .environment(\.layoutDirection, .rightToLeft)

            // The professional progress bar: shows elapsed fraction of the
            // current inter-prayer interval, with previous→next labels.
            if let fraction = manager.progressFraction,
               let prev = manager.previousPrayerInfo {
                PrayerProgressBar(
                    progress: max(0.04, fraction), // floor so the fill is always visible
                    leadingLabel: prev.kind.arabicShortName,
                    trailingLabel: next.kind.arabicShortName
                )
                .frame(height: 12)
            }
        }
    }

    private var loadingInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("جارٍ التحميل")
                .font(QuranDesign.body(12))
                .foregroundColor(QuranDesign.textSecondary)
        }
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach([PrayerKind.fajr, .dhuhr, .asr, .maghrib, .isha]) { kind in
                if let time = manager.schedule.times[kind] {
                    HStack(spacing: 6) {
                        Text(kind.arabicName)
                            .font(QuranDesign.body(10))
                            .foregroundColor(QuranDesign.textSecondary)
                        Spacer(minLength: 4)
                        Text(Self.timeFormatter.string(from: time))
                            .font(QuranDesign.mono(10))
                            .foregroundColor(QuranDesign.textPrimary)
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
// 658×180pt — two columns: next-prayer hero + all six prayers with Hijri date.

struct PrayerTimesFullExpandedView: View {
    @ObservedObject private var manager = PrayerTimesManager.shared

    var body: some View {
        HStack(spacing: 0) {
            heroCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle()
                .fill(QuranDesign.surfaceStroke)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            prayersList
                .frame(width: 240)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = manager.nextPrayerInfo {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(QuranDesign.accent.opacity(0.5), lineWidth: 1.2)
                            .background(Circle().fill(QuranDesign.accentSoft))
                        Image(systemName: next.kind.iconName)
                            .font(.system(size: 18))
                            .foregroundColor(QuranDesign.accent)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("الصلاة القادمة")
                            .font(QuranDesign.caption(10))
                            .foregroundColor(QuranDesign.textTertiary)
                        Text(next.kind.arabicName)
                            .font(QuranDesign.surahName(18))
                            .foregroundColor(QuranDesign.textPrimary)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text("بعد " + next.countdown)
                            .font(QuranDesign.body(12))
                            .foregroundColor(QuranDesign.accent)
                    }
                    Spacer()
                }
            } else {
                Text(manager.isLoading ? "جارٍ التحميل…" : "لا توجد بيانات")
                    .font(QuranDesign.body(13))
                    .foregroundColor(QuranDesign.textSecondary)
            }

            if let hijri = manager.schedule.hijriDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                        .foregroundColor(QuranDesign.accent)
                    Text(hijri + " هـ")
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textSecondary)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }

            // Location badge so the user can verify which city the times are for.
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundColor(manager.hasLocationFix ? QuranDesign.accent : .orange)
                if !manager.locationName.isEmpty {
                    Text(manager.locationName)
                        .font(QuranDesign.body(11))
                        .foregroundColor(QuranDesign.textSecondary)
                } else {
                    Text(String(format: "%.2f, %.2f", manager.resolvedLatitude, manager.resolvedLongitude))
                        .font(QuranDesign.mono(10))
                        .foregroundColor(QuranDesign.textTertiary)
                }
                if !manager.hasLocationFix && manager.useAutoLocation {
                    Text("— بانتظار الموقع")
                        .font(QuranDesign.caption(9))
                        .foregroundColor(.orange)
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
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(QuranDesign.surfaceStroke)

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
                .foregroundColor(isNext ? QuranDesign.accent : QuranDesign.textTertiary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(isNext ? QuranDesign.accentSoft : QuranDesign.surfaceFill))

            Text(kind.arabicName)
                .font(QuranDesign.body(isNext ? 12 : 11))
                .foregroundColor(isNext ? QuranDesign.textPrimary : QuranDesign.textSecondary)
                .environment(\.layoutDirection, .rightToLeft)

            Spacer()
            if let time = manager.schedule.times[kind] {
                Text(Self.timeFormatter.string(from: time))
                    .font(QuranDesign.mono(10))
                    .foregroundColor(isNext ? QuranDesign.accent : QuranDesign.textSecondary)
            } else if !hasTime {
                Text("--:--")
                    .font(QuranDesign.mono(10))
                    .foregroundColor(QuranDesign.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .quranSurface(isActive: isNext, radius: QuranDesign.cornerRadiusS)
        .contentShape(Rectangle())
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Prayer Progress Bar (professional inter-prayer interval indicator)
//
// Shows the elapsed fraction of the current interval between two prayers as
// a smooth gold gradient bar with a soft glowing knob, plus short endpoint
// labels for the previous and next prayer. The fill animates with a gentle
// ease so it feels alive as time passes.

struct PrayerProgressBar: View {
    let progress: Double                 // 0...1
    var leadingLabel: String             // previous prayer short name
    var trailingLabel: String            // next prayer short name

    var body: some View {
        VStack(spacing: 2) {
            // Track with fill percentage as relative width — no GeometryReader
            // (GeometryReader collapses to zero width inside tight HStack/VStack
            // layouts in the 88pt expanded surface).
            // Use the battle-tested QuranProgressBar which handles the
            // GeometryReader sizing correctly in the island's tight layout.
            QuranProgressBar(
                progress: max(0.04, progress),
                onSeek: nil,
                isRTL: false
            )
            .frame(height: 12)

            labels
        }
    }

    private var labels: some View {
        HStack(spacing: 0) {
            Text(leadingLabel)
                .font(QuranDesign.caption(8))
                .foregroundColor(QuranDesign.textTertiary)
            Spacer()
            Text(trailingLabel)
                .font(QuranDesign.caption(8))
                .foregroundColor(QuranDesign.textTertiary)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Prayer Progress Hairline (compact pill)
//
// A non-interactive 2pt hairline for the tight 200×36 compact row — just the
// fill, no knob or labels.

struct PrayerProgressHairline: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(QuranDesign.surfaceStroke)
                Capsule()
                    .fill(QuranDesign.accent.opacity(0.85))
                    .frame(width: proxy.size.width * progress)
                    .animation(.easeOut(duration: 0.4), value: progress)
            }
        }
    }
}
