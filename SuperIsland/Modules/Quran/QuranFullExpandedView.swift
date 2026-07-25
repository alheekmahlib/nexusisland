import SwiftUI

// MARK: - Quran Full Expanded View (detail panel)
//
// Redesigned with NexusDesign tokens. The full-expanded surface (658×180pt)
// is a two-column split: a GlassCard now-playing detail on the left and a
// scrollable surah list on the right. RTL is applied to Arabic Text only.
// The draggable QuranProgressBar is kept (it carries seek + RTL logic).

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
                .fill(Color.white.opacity(0.10))
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
                    .font(NexusTypography.mono)
                    .foregroundColor(NexusPalette.textTertiary)
                Spacer()
                Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                    .font(NexusTypography.mono)
                    .foregroundColor(NexusPalette.textTertiary)
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
                .strokeBorder(NexusPalette.electricViolet.opacity(0.5), lineWidth: 1.2)
                .background(Circle().fill(NexusGradient.purple.opacity(0.30)))
            Text(manager.currentSurah.arabicNumber)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(NexusPalette.textPrimary)
        }
        .frame(width: 40, height: 40)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(manager.currentSurah.arabicName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(NexusPalette.textPrimary)
                .lineLimit(1)
                .environment(\.layoutDirection, .rightToLeft) // Arabic shaping only
            Text(manager.currentReciter.displayName)
                .font(.system(size: 10))
                .foregroundColor(NexusPalette.textSecondary)
                .lineLimit(1)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var primaryPlay: some View {
        NeonButton(
            systemName: manager.isLoading
                ? "circle.dashed"
                : (manager.isPlaying ? "pause.fill" : "play.fill"),
            size: 32,
            gradient: NexusGradient.purple
        ) {
            manager.togglePlayPause()
        }
        .disabled(manager.isLoading)
        .opacity(manager.isLoading ? 0.5 : 1)
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8)).foregroundColor(NexusPalette.electricViolet)
            Text(value).font(.system(size: 10)).foregroundColor(NexusPalette.textPrimary)
            Text(label).font(.system(size: 8)).foregroundColor(NexusPalette.textTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusS)
    }

    private var autoAdvanceToggle: some View {
        HStack(spacing: 4) {
            Toggle("", isOn: Binding(
                get: { manager.autoAdvance },
                set: { manager.autoAdvance = $0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(NexusPalette.royalPurple)
            .labelsHidden()
            Text("تلقائي")
                .font(.system(size: 8))
                .foregroundColor(NexusPalette.textTertiary)
        }
    }

    // MARK: - Sidebar (surah list)

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().background(Color.white.opacity(0.10))
            surahScrollList
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("السور")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                Text("\(QuranSurahs.all.count)")
                    .font(NexusTypography.mono)
                    .foregroundColor(NexusPalette.textTertiary)
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
                .foregroundColor(NexusPalette.textTertiary)
            TextField("بحث…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(NexusPalette.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusS)
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
                    .foregroundColor(isSelected ? NexusPalette.textPrimary : NexusPalette.textTertiary)
                    .frame(width: 18, height: 18)
                    .background {
                        Circle().fill(isSelected ? AnyShapeStyle(NexusGradient.purple) : AnyShapeStyle(Color.white.opacity(0.06)))
                    }
                Text(surah.arabicName)
                    .font(.system(size: isSelected ? 12 : 11))
                    .foregroundColor(isSelected ? NexusPalette.textPrimary : NexusPalette.textSecondary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                if isSelected && manager.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 8))
                        .foregroundColor(NexusPalette.electricViolet)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .nexusSurface(variant: .glass, isActive: isSelected, radius: NexusMetrics.cornerRadiusS,
                          gradient: isSelected ? NexusGradient.purple : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
