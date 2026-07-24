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

                Text(next.kind.arabicName)
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(next.countdown)
                    .font(QuranDesign.mono(10))
                    .foregroundColor(QuranDesign.textSecondary)
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
        HStack(spacing: 12) {
            if let next = manager.nextPrayerInfo {
                medallion(next.kind)
                nextInfo(next)
            } else {
                medallion(.isha)
                loadingInfo
            }

            Divider().background(QuranDesign.surfaceStroke).frame(maxHeight: 50)

            // Compact list of the remaining prayers with their times.
            todayList
        }
        .environment(\.layoutDirection, .rightToLeft)
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
        VStack(alignment: .leading, spacing: 2) {
            Text("القادمة")
                .font(QuranDesign.caption(9))
                .foregroundColor(QuranDesign.textTertiary)
            Text(next.kind.arabicName)
                .font(QuranDesign.surahName(14))
                .foregroundColor(QuranDesign.textPrimary)
            Text("بعد " + next.countdown)
                .font(QuranDesign.body(11))
                .foregroundColor(QuranDesign.accent)
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
