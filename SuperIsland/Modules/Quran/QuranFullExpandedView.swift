import SwiftUI

// MARK: - Quran Full Expanded View (detail panel)

struct QuranFullExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nowPlayingCard
            statsRow
            Divider().background(.white.opacity(0.1))
            surahList
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Now-playing card

    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.currentSurah.displayLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(manager.currentReciter.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Button(action: { manager.togglePlayPause() }) {
                Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(manager.isLoading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
    }

    // MARK: - Stats + auto-advance

    private var statsRow: some View {
        HStack(spacing: 16) {
            statChip(icon: "checkmark.seal", value: "\(manager.completionsToday)", label: "سور اليوم")
            statChip(icon: "text.book.closed",
                     value: "\(manager.currentSurah.number)/114",
                     label: "الموضع الحالي")
            Spacer()
            Toggle(isOn: Binding(
                get: { manager.autoAdvance },
                set: { manager.autoAdvance = $0 }
            )) {
                Text("تلقائي بعد السورة")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Searchable surah list (all 114)

    private var filteredSurahs: [Surah] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return QuranSurahs.all }
        // Match by Arabic name, Latin name, or number.
        return QuranSurahs.all.filter { surah in
            surah.arabicName.contains(trimmed)
                || surah.latinName.lowercased().contains(trimmed.lowercased())
                || String(surah.number) == trimmed
        }
    }

    private var surahList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                TextField("ابحث عن سورة…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredSurahs) { surah in
                        surahRow(surah)
                    }
                }
            }
        }
    }

    private func surahRow(_ surah: Surah) -> some View {
        let isSelected = surah.number == manager.currentSurah.number
        return Button(action: { manager.selectSurah(number: surah.number) }) {
            HStack(spacing: 10) {
                Text(surah.arabicNumber)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.08)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(surah.arabicName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(.white.opacity(isSelected ? 1 : 0.85))
                    Text("\(surah.revelationTypeArabic) • \(surah.ayahCount) آية • \(surah.latinName)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                if isSelected, manager.isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? .white.opacity(0.1) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
