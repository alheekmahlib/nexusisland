import SwiftUI

// MARK: - Quran Full Expanded View (detail panel)
//
// The full-expanded surface is 658×180pt — short and wide. A two-column
// horizontal split fits: a compact now-playing card on the left and a
// scrollable surah list on the right (the user asked for the list on the side).
//
// Both columns are height-constrained to ~180pt, so the list scrolls
// vertically and the now-playing card stays fixed.

struct QuranFullExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left: now-playing detail (fixed, fills remaining width).
            nowPlayingCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Divider
            Rectangle()
                .fill(QuranDesign.surfaceStroke)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            // Right: surah list sidebar (fixed width).
            sidebar
                .frame(width: 230)
        }
        // The whole panel stays LTR (the app's direction) so the progress bar
        // and list layout are consistent with every other module. Arabic text
        // runs RTL locally via .environment(\.layoutDirection, .rightToLeft)
        // applied to individual Text labels.
    }

    // MARK: - Now-playing card

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                medallion
                identity
                Spacer()
                primaryPlay
            }

            // LTR draggable progress with time codes — matches the app direction.
            QuranProgressBar(
                progress: manager.progress,
                trackHeight: 4,
                knobSize: 12,
                onSeek: { fraction in manager.seek(toFraction: fraction) },
                isRTL: false
            )
            .frame(height: 16)

            HStack {
                Text(QuranDesign.formatTime(manager.currentTime))
                    .font(QuranDesign.mono(9))
                    .foregroundColor(QuranDesign.textTertiary)
                Spacer()
                Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                    .font(QuranDesign.mono(9))
                    .foregroundColor(QuranDesign.textTertiary)
            }

            // Stat chips + auto-advance, in a tight row.
            HStack(spacing: 6) {
                statChip(icon: "checkmark.seal.fill",
                         value: "\(manager.completionsToday)", label: "اليوم")
                statChip(icon: manager.currentSurah.isMeccan ? "moon.stars.fill" : "building.2.fill",
                         value: manager.currentSurah.revelationTypeArabic, label: "النوع")
                Spacer()
                autoAdvanceToggle
            }
        }
        .padding(12)
    }

    private var medallion: some View {
        ZStack {
            Circle()
                .strokeBorder(QuranDesign.accent.opacity(0.5), lineWidth: 1.2)
                .background(Circle().fill(QuranDesign.accentSoft))
            Text(manager.currentSurah.arabicNumber)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(QuranDesign.accent)
        }
        .frame(width: 40, height: 40)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(manager.currentSurah.arabicName)
                .font(QuranDesign.surahName(15))
                .foregroundColor(QuranDesign.textPrimary)
                .lineLimit(1)
                .environment(\.layoutDirection, .rightToLeft) // Arabic shaping only
            Text(manager.currentReciter.displayName)
                .font(QuranDesign.body(10))
                .foregroundColor(QuranDesign.textSecondary)
                .lineLimit(1)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var primaryPlay: some View {
        Button(action: manager.togglePlayPause) {
            ZStack {
                Circle().fill(QuranDesign.accent).frame(width: 32, height: 32)
                    .shadow(color: QuranDesign.accent.opacity(0.4), radius: 5, y: 1)
                Image(systemName: manager.isLoading
                      ? "circle.dashed"
                      : (manager.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(Color(red: 0.10, green: 0.08, blue: 0.04))
                    .offset(x: manager.isPlaying ? 0 : 1)
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8)).foregroundColor(QuranDesign.accent)
            Text(value).font(QuranDesign.body(10)).foregroundColor(QuranDesign.textPrimary)
            Text(label).font(QuranDesign.caption(8)).foregroundColor(QuranDesign.textTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .quranSurface(radius: QuranDesign.cornerRadiusS)
    }

    private var autoAdvanceToggle: some View {
        HStack(spacing: 4) {
            Toggle("", isOn: Binding(
                get: { manager.autoAdvance },
                set: { manager.autoAdvance = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(QuranDesign.accent) // gold, matching the design system
            .labelsHidden()
            Text("تلقائي")
                .font(QuranDesign.caption(8))
                .foregroundColor(QuranDesign.textTertiary)
        }
    }

    // MARK: - Sidebar (surah list)

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().background(QuranDesign.surfaceStroke)
            surahScrollList
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("السور")
                    .font(QuranDesign.surahName(12))
                    .foregroundColor(QuranDesign.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                Text("\(QuranSurahs.all.count)")
                    .font(QuranDesign.mono(9))
                    .foregroundColor(QuranDesign.textTertiary)
            }
            searchBar
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var searchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9))
                .foregroundColor(QuranDesign.textTertiary)
            TextField("بحث…", text: $searchText)
                .textFieldStyle(.plain)
                .font(QuranDesign.body(10))
                .foregroundColor(QuranDesign.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .quranSurface(radius: QuranDesign.cornerRadiusS)
    }

    private var filteredSurahs: [Surah] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return QuranSurahs.all }
        return QuranSurahs.all.filter { surah in
            surah.arabicName.contains(trimmed)
                || surah.latinName.lowercased().contains(trimmed.lowercased())
                || String(surah.number) == trimmed
        }
    }

    private var surahScrollList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredSurahs) { surah in
                    sidebarRow(surah)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
        }
    }

    private func sidebarRow(_ surah: Surah) -> some View {
        let isSelected = surah.number == manager.currentSurah.number
        return Button(action: { manager.selectSurah(number: surah.number) }) {
            HStack(spacing: 6) {
                Text(surah.arabicNumber)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? QuranDesign.accent : QuranDesign.textTertiary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(isSelected ? QuranDesign.accentSoft : QuranDesign.surfaceFill))
                Text(surah.arabicName)
                    .font(QuranDesign.body(isSelected ? 12 : 11))
                    .foregroundColor(isSelected ? QuranDesign.textPrimary : QuranDesign.textSecondary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                if isSelected && manager.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 8))
                        .foregroundColor(QuranDesign.accent)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .quranSurface(isActive: isSelected, radius: QuranDesign.cornerRadiusS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
