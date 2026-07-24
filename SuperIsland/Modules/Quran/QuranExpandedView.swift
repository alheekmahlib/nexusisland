import SwiftUI

// MARK: - Quran Expanded View (drawer)

struct QuranExpandedView: View {
    @ObservedObject private var manager = QuranManager.shared
    @State private var showReciterPicker = false
    @State private var showSurahPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            progressRow
            controlsRow
            if showReciterPicker { reciterPicker }
            if showSurahPicker { surahPicker }
        }
        .padding(.vertical, 4)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 1) {
                Text(manager.currentSurah.displayLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(manager.currentReciter.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text(timeBadge)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var timeBadge: String {
        let elapsed = format(manager.currentTime)
        let total = manager.duration > 0 ? format(manager.duration) : "--:--"
        return "\(elapsed) / \(total)"
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Progress

    private var progressRow: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: 4)
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: proxy.size.width * manager.progress, height: 4)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(1, max(0, value.location.x / proxy.size.width))
                        manager.seek(toFraction: fraction)
                    }
            )
        }
        .frame(height: 4)
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 14) {
            controlButton(icon: "backward.fill") { manager.previousSurah() }
                .disabled(manager.currentSurah.number <= 1)

            primaryPlayButton

            controlButton(icon: "forward.fill") { manager.nextSurah() }
                .disabled(manager.currentSurah.number >= QuranSurahs.all.count)

            Spacer()

            toggleButton(icon: "person.wave.2", isOn: showReciterPicker) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showSurahPicker = false
                    showReciterPicker.toggle()
                }
            }
            toggleButton(icon: "list.bullet", isOn: showSurahPicker) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showReciterPicker = false
                    showSurahPicker.toggle()
                }
            }
        }
    }

    private var primaryPlayButton: some View {
        Button(action: { manager.togglePlayPause() }) {
            Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .disabled(manager.isLoading)
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func toggleButton(icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isOn ? .white : .white.opacity(0.5))
                .frame(width: 26, height: 26)
                .background(Circle().fill(isOn ? .white.opacity(0.15) : .clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reciter picker

    private var reciterPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(QuranReciters.all) { reciter in
                pickerRow(
                    title: reciter.displayName,
                    subtitle: reciter.latinName,
                    isSelected: reciter.id == manager.currentReciter.id
                ) {
                    manager.selectReciter(reciter)
                    withAnimation(.easeOut(duration: 0.2)) { showReciterPicker = false }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Surah picker (compact: first 30 + jump)

    private var surahPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Show a curated subset for the drawer; the full list lives in the
            // full-expanded panel. First 30 surahs cover the most-played range.
            ForEach(Array(QuranSurahs.all.prefix(30))) { surah in
                pickerRow(
                    title: surah.displayLabel,
                    subtitle: "\(surah.revelationTypeArabic) • \(surah.ayahCount) آية",
                    isSelected: surah.number == manager.currentSurah.number
                ) {
                    manager.selectSurah(number: surah.number)
                    withAnimation(.easeOut(duration: 0.2)) { showSurahPicker = false }
                }
            }
        }
        .padding(.top, 4)
    }

    private func pickerRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.white.opacity(isSelected ? 1 : 0.85))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.vertical, 3)
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
