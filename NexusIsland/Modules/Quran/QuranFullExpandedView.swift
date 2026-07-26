import SwiftUI

// MARK: - Quran Full Expanded View (detail panel)
//
// Premium Apple-Music-inspired audio player within the 658×180pt surface.
// Two-column split: a hero now-playing panel on the left and a scrollable
// surah list on the right (248pt). The hero panel leads with a large
// Quran-logo artwork (the module's visual anchor), then a strong title,
// reciter, transport, and an elegant progress bar — generous whitespace,
// clear hierarchy, subtle hover/scale interactions.
//
// Purple NexusDesign palette for consistency with the rest of the app.

struct QuranFullExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            nowPlayingPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
            sidebar
                .frame(width: 248)
        }
    }

    // MARK: - Hero now-playing panel
    //
    // Centered layout: surah name as the visual anchor (instead of an artwork
    // medallion), with reciter + progress + transport stacked beneath it.

    private var nowPlayingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Header: surah name (hero title) + reciter/revelation row ──
            VStack(alignment: .leading, spacing: 6) {
                Text(manager.currentSurah.arabicName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)

                HStack(spacing: 8) {
                    reciterPicker
                    revelationChip
                }
            }

            // ── Progress bar + time codes ──
            QuranProgressBar(
                progress: manager.progress,
                trackHeight: 6,
                knobSize: 14,
                onSeek: { fraction in manager.seek(toFraction: fraction) },
                isRTL: false
            )
            .frame(height: 16)

            HStack(spacing: 0) {
                Text(QuranDesign.formatTime(manager.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(NexusPalette.textTertiary)
                Spacer()
                Text(manager.duration > 0 ? QuranDesign.formatTime(manager.duration) : "--:--:--")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(NexusPalette.textTertiary)
            }

            // ── Transport controls row + auto-advance ──
            HStack(spacing: 12) {
                navButton(icon: "backward.fill",
                          action: manager.previousSurah,
                          disabled: manager.currentSurah.number <= 1)
                primaryPlay
                navButton(icon: "forward.fill",
                          action: manager.nextSurah,
                          disabled: manager.currentSurah.number >= QuranSurahs.all.count)
                Spacer(minLength: 12)
                autoAdvanceToggle
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Reciter picker

    private var reciterPicker: some View {
        Menu {
            ForEach(QuranReciters.all) { reciter in
                Button {
                    manager.selectReciter(reciter)
                } label: {
                    if reciter.id == manager.currentReciter.id {
                        Label(reciter.displayName, systemImage: "checkmark")
                    } else {
                        Text(reciter.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 10))
                    .foregroundColor(NexusPalette.electricViolet)
                Text(manager.currentReciter.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NexusPalette.textPrimary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .rightToLeft)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NexusPalette.deepPurple.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(NexusPalette.glassTint.opacity(0.14), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Revelation chip (Meccan/Medinan)

    private var revelationChip: some View {
        HStack(spacing: 4) {
            Image(systemName: manager.currentSurah.isMeccan ? "moon.stars.fill" : "building.2.fill")
                .font(.system(size: 9))
                .foregroundColor(NexusPalette.textTertiary)
            Text(manager.currentSurah.revelationTypeArabic)
                .font(.system(size: 11))
                .foregroundColor(NexusPalette.textSecondary)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: - Transport controls

    private var primaryPlay: some View {
        NeonButton(
            systemName: manager.isLoading
                ? "circle.dashed"
                : (manager.isPlaying ? "pause.fill" : "play.fill"),
            size: 40,
            gradient: NexusGradient.purple
        ) {
            manager.togglePlayPause()
        }
        .disabled(manager.isLoading)
        .opacity(manager.isLoading ? 0.5 : 1)
    }

    private func navButton(icon: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(disabled ? NexusPalette.textTertiary : NexusPalette.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(disabled ? Color.clear : NexusPalette.deepPurple.opacity(0.40))
                )
                .overlay(
                    Circle()
                        .strokeBorder(disabled ? Color.clear : NexusPalette.glassTint.opacity(0.12),
                                      lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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
            Text(NSLocalizedString("Auto", comment: "Quran auto-advance toggle"))
                .font(.system(size: 8))
                .foregroundColor(NexusPalette.textTertiary)
        }
    }

    // MARK: - Sidebar (surah list)

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
            surahScrollList
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(NSLocalizedString("Surahs", comment: "Quran sidebar title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(NexusPalette.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                Spacer()
                Text("\(QuranSurahs.all.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(NexusPalette.textTertiary)
            }
            searchBar
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(NexusPalette.textTertiary)
            TextField(NSLocalizedString("Search…", comment: "Quran search placeholder"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(NexusPalette.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NexusPalette.deepPurple.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(NexusPalette.glassTint.opacity(0.10), lineWidth: 0.5)
        )
    }

    private var filteredSurahs: [Surah] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return QuranSurahs.all }
        return QuranSurahs.all.filter { surah in
            surah.arabicName.contains(trimmed)
                || surah.latinName.lowercased().contains(trimmed.lowercased())
                || String(surah.number) == trimmed
                || surah.arabicNumber == trimmed
        }
    }

    private var surahScrollList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredSurahs) { surah in
                    sidebarRow(surah)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }

    private func sidebarRow(_ surah: Surah) -> some View {
        let isSelected = surah.number == manager.currentSurah.number
        let isPlaying = isSelected && manager.isPlaying
        return Button(action: { manager.selectSurah(number: surah.number) }) {
            HStack(spacing: 8) {
                // Number badge — gradient disc when selected.
                Text(surah.arabicNumber)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? NexusPalette.textPrimary : NexusPalette.textTertiary)
                    .frame(width: 22, height: 22)
                    .background {
                        if isSelected {
                            Circle().fill(NexusGradient.purple)
                                .shadow(color: NexusPalette.electricViolet.opacity(0.45), radius: 3, y: 1)
                        } else {
                            Circle().fill(Color.white.opacity(0.05))
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft)

                // Arabic name + Latin subtitle.
                VStack(alignment: .leading, spacing: 0) {
                    Text(surah.arabicName)
                        .font(.system(size: isSelected ? 13 : 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? NexusPalette.textPrimary : NexusPalette.textSecondary)
                        .lineLimit(1)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(surah.latinName)
                        .font(.system(size: 8))
                        .foregroundColor(NexusPalette.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Now-playing waveform indicator.
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundColor(NexusPalette.electricViolet)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? NexusPalette.royalPurple.opacity(0.22) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(colors: [NexusPalette.electricViolet.opacity(0.45), .clear],
                                             startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
