import Combine
import AppKit
import SwiftUI

// MARK: - Clipboard History Module
//
// Captures pasteboard changes and keeps a rolling history. Click an item to
// re-copy it. Pure AppKit — no permissions needed.

struct ClipboardEntry: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let kind: Kind

    enum Kind: String { case text, url, code

        var iconName: String {
            switch self {
            case .text: return "text.alignleft"
            case .url: return "link"
            case .code: return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 60 { return String(trimmed.prefix(60)) + "…" }
        return trimmed
    }
}

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var history: [ClipboardEntry] = []
    @Published private(set) var isEnabled = false

    private var timer: Timer?
    private let maxItems = 50
    private var lastChangeCount: Int = 0

    private init() {}

    func startMonitoring() {
        guard !isEnabled else { return }
        isEnabled = true
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPasteboard() }
        }
    }

    func stopMonitoring() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Only capture string content.
        guard let content = pb.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Deduplicate: skip if identical to the most recent entry.
        if history.first?.content == content { return }

        let kind = detectKind(content)
        let entry = ClipboardEntry(content: content, timestamp: Date(), kind: kind)
        history.insert(entry, at: 0)
        if history.count > maxItems { history.removeLast() }
    }

    /// Re-copy an entry to the pasteboard.
    func copyAgain(_ entry: ClipboardEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.content, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func clearHistory() {
        history.removeAll()
    }

    private func detectKind(_ content: String) -> ClipboardEntry.Kind {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return .url }
        if trimmed.contains("{") && trimmed.contains("}") || trimmed.contains("func ") || trimmed.contains("import ") { return .code }
        return .text
    }
}

// MARK: - Views

struct ClipboardCompactView: View {
    @ObservedObject private var manager = ClipboardManager.shared

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 10)).foregroundColor(QuranDesign.accent)
            if let last = manager.history.first {
                Text(last.preview).font(QuranDesign.caption(9)).foregroundColor(QuranDesign.textPrimary).lineLimit(1)
            }
        }
    }
}

struct ClipboardExpandedView: View {
    @ObservedObject private var manager = ClipboardManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(manager.history.prefix(4))) { entry in
                Button(action: { manager.copyAgain(entry) }) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.kind.iconName).font(.system(size: 8)).foregroundColor(QuranDesign.accent)
                        Text(entry.preview).font(QuranDesign.body(10)).foregroundColor(QuranDesign.textPrimary).lineLimit(1)
                    }
                }.buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct ClipboardFullExpandedView: View {
    @ObservedObject private var manager = ClipboardManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("سجل الحافظة").font(QuranDesign.surahName(12)).foregroundColor(QuranDesign.textPrimary)
                Spacer()
                Text("\(manager.history.count)").font(QuranDesign.mono(9)).foregroundColor(QuranDesign.textTertiary)
                if !manager.history.isEmpty {
                    Button(NSLocalizedString("Clear All", comment: "Button")) { manager.clearHistory() }
                        .font(.system(size: 9)).foregroundColor(.red)
                }
            }.padding(.horizontal, 10).padding(.vertical, 7).environment(\.layoutDirection, .rightToLeft)
            Divider().background(QuranDesign.surfaceStroke)

            if manager.history.isEmpty {
                Text("لا يوجد سجل بعد").font(QuranDesign.body(11)).foregroundColor(QuranDesign.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.history) { entry in
                            Button(action: { manager.copyAgain(entry) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: entry.kind.iconName).font(.system(size: 9)).foregroundColor(QuranDesign.accent)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.preview).font(QuranDesign.body(11)).foregroundColor(QuranDesign.textPrimary).lineLimit(2)
                                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(QuranDesign.caption(7)).foregroundColor(QuranDesign.textTertiary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .quranSurface(radius: QuranDesign.cornerRadiusS)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 5).padding(.vertical, 4)
                }
            }
        }
    }
}
