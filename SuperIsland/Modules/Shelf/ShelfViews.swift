import AppKit
import QuickLookThumbnailing
import SwiftUI

struct ShelfCompactView: View {
    @ObservedObject private var shelf = ShelfStore.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: shelf.items.isEmpty ? "tray" : "tray.full.fill")
                .font(NexusTypography.title(13))
                .foregroundStyle(NexusPalette.textPrimary)

            if let latest = latestItem {
                Text(latest.displayName)
                    .font(NexusTypography.title(12))
                    .foregroundStyle(NexusPalette.textPrimary)
                    .lineLimit(1)
            } else {
                Text("Shelf")
                    .font(NexusTypography.title(12))
                    .foregroundStyle(NexusPalette.textSecondary)
            }

            if !shelf.items.isEmpty {
                Text("\(shelf.items.count)")
                    .font(NexusTypography.numeric(10))
                    .foregroundStyle(NexusPalette.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NexusPalette.glassTint.opacity(0.15))
                    )
            }
        }
    }

    private var latestItem: ShelfItem? {
        shelf.items.sorted { $0.addedAt > $1.addedAt }.first
    }
}

struct ShelfExpandedView: View {
    @ObservedObject private var shelf = ShelfStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Shelf", systemImage: "tray.full.fill")
                    .font(NexusTypography.title(13))
                    .foregroundStyle(NexusPalette.textPrimary)

                Text(shelf.items.isEmpty ? "Drop files, links, images, or text" : "\(shelf.items.count) saved")
                    .font(NexusTypography.caption(11, .medium))
                    .foregroundStyle(NexusPalette.textSecondary)
            }

            if shelf.items.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(NexusPalette.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drop onto the island")
                            .font(NexusTypography.title(14))
                            .foregroundStyle(NexusPalette.textPrimary)
                        Text("Items stay here until you remove them.")
                            .font(NexusTypography.caption(11))
                            .foregroundStyle(NexusPalette.textSecondary)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(previewItems) { item in
                            ExpandedShelfChip(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var previewItems: [ShelfItem] {
        Array(shelf.items.sorted { $0.addedAt > $1.addedAt }.prefix(4))
    }
}

struct ShelfFullExpandedView: View {
    @ObservedObject private var shelf = ShelfStore.shared
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 12) {
            AirDropDropPane()
                .frame(width: 142)

            TrayDropPane(
                items: filteredItems,
                totalCount: orderedItems.count,
                isFiltering: !trimmedSearchText.isEmpty,
                searchText: $searchText
            )
                .environmentObject(appState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var orderedItems: [ShelfItem] {
        shelf.items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.addedAt > rhs.addedAt
        }
    }

    private var filteredItems: [ShelfItem] {
        let query = trimmedSearchText.lowercased()
        guard !query.isEmpty else { return orderedItems }
        return orderedItems.filter { item in
            item.displayName.localizedCaseInsensitiveContains(query)
                || item.subtitle.localizedCaseInsensitiveContains(query)
                || (item.previewText?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AirDropDropPane: View {
    @ObservedObject private var shelf = ShelfStore.shared
    @State private var isTargeted = false

    var body: some View {
        Button {
            shelf.openAirDropPicker()
        } label: {
            VStack(spacing: 10) {
                GradientMedallion(systemName: "airplayaudio", size: 54, gradient: NexusGradient.purple, isActive: isTargeted)

                Text("AirDrop")
                    .font(NexusTypography.title(13))
                    .foregroundStyle(NexusPalette.textPrimary)

                Text("Drop to share")
                    .font(NexusTypography.caption(9, .medium))
                    .foregroundStyle(NexusPalette.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusL)
            .overlay(panelStroke)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onDrop(of: ShelfStore.acceptedDropTypes, isTargeted: $isTargeted) { providers in
            shelf.handleAirDropDrop(providers: providers)
        }
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                isTargeted ? NexusPalette.neonPink.opacity(0.92) : Color.clear,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8])
            )
    }
}

private struct TrayDropPane: View {
    let items: [ShelfItem]
    let totalCount: Int
    let isFiltering: Bool
    @Binding var searchText: String

    @ObservedObject private var shelf = ShelfStore.shared
    @EnvironmentObject private var appState: AppState
    @State private var isTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusL)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            isTargeted ? NexusPalette.neonPink.opacity(0.92) : Color.clear,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8])
                        )
                )

            if totalCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(NexusTypography.title(20))
                        .foregroundStyle(NexusPalette.textSecondary)

                    Text("Drop files here")
                        .font(NexusTypography.title(13))
                        .foregroundStyle(NexusPalette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Shelf")
                            .font(NexusTypography.title(12))
                            .foregroundStyle(NexusPalette.textSecondary)

                        Text(totalCount == 1 ? "1 item" : "\(totalCount) items")
                            .font(NexusTypography.caption(10, .medium))
                            .foregroundStyle(NexusPalette.textTertiary)

                        Spacer(minLength: 8)

                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(NexusTypography.caption(11, .medium))
                            .foregroundStyle(NexusPalette.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(width: 150)
                            .nexusSurface(variant: .outlined, radius: NexusMetrics.cornerRadiusS)

                        Menu("Clear") {
                            Button("Clear Unpinned") {
                                shelf.clearUnpinned()
                            }
                            .disabled(!shelf.items.contains { !$0.isPinned })

                            Button("Clear All") {
                                shelf.clear()
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .font(NexusTypography.caption(11, .semibold))
                        .foregroundStyle(NexusPalette.textSecondary)
                        .hoverPointer()
                    }

                    if items.isEmpty && isFiltering {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(NexusTypography.title(17))
                                .foregroundStyle(NexusPalette.textTertiary)
                            Text("No matches")
                                .font(NexusTypography.title(12))
                                .foregroundStyle(NexusPalette.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(items) { item in
                                        TrayItemTile(item: item)
                                            .id(item.id)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(maxHeight: .infinity)
                            .onAppear {
                                scrollToLatest(using: proxy, animated: false)
                            }
                            .onChange(of: items.count) { _, _ in
                                scrollToLatest(using: proxy, animated: true)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onDrop(of: ShelfStore.acceptedDropTypes, isTargeted: $isTargeted) { providers in
            shelf.handleDrop(providers: providers) { addedCount in
                guard addedCount > 0 else { return }
                appState.presentShelfAfterDrop()
            }
        }
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = items.first?.id else { return }
        if animated {
            withAnimation(.smooth(duration: 0.22)) {
                proxy.scrollTo(lastID, anchor: .leading)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .leading)
        }
    }
}

private struct ExpandedShelfChip: View {
    let item: ShelfItem
    @ObservedObject private var shelf = ShelfStore.shared

    var body: some View {
        Button {
            shelf.open(item)
        } label: {
            HStack(spacing: 8) {
                ShelfItemArtworkView(item: item, size: 24, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName)
                        .font(NexusTypography.title(11))
                        .foregroundStyle(NexusPalette.textPrimary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(NexusTypography.caption(9, .medium))
                        .foregroundStyle(NexusPalette.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 164, alignment: .leading)
            .nexusSurface(variant: .glass, radius: 14, gradient: NexusGradient.purple)
        }
        .buttonStyle(.plain)
        .hoverPointer()
        .onDrag {
            shelf.dragProvider(for: item)
        }
        .contextMenu {
            ShelfItemActionsMenu(item: item)
        }
    }
}

private struct TrayItemTile: View {
    let item: ShelfItem
    @ObservedObject private var shelf = ShelfStore.shared
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ShelfItemArtworkView(item: item, size: 42, cornerRadius: 9)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(NexusTypography.numeric(8))
                        .foregroundStyle(NexusPalette.textPrimary)
                        .frame(width: 15, height: 15)
                        .nexusSurface(variant: .glass, radius: 8)
                        .offset(x: -34, y: -4)
                }

                if item.isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(NexusTypography.numeric(8))
                        .foregroundStyle(NexusPalette.warning)
                        .frame(width: 15, height: 15)
                        .nexusSurface(variant: .glass, radius: 8)
                        .offset(x: -17, y: -4)
                }

                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(NexusTypography.numeric(7))
                        .foregroundStyle(NexusPalette.textPrimary)
                        .frame(width: 15, height: 15)
                        .nexusSurface(variant: .glass, radius: 8)
                        .shadow(color: NexusPalette.glassTint.opacity(0.08), radius: 6)
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .opacity(isHovering ? 1 : 0.82)
            }

            VStack(spacing: 2) {
                Text(item.displayName)
                    .font(NexusTypography.title(11))
                    .foregroundStyle(NexusPalette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 104)

                Text(item.subtitle)
                    .font(NexusTypography.caption(9, .medium))
                    .foregroundStyle(NexusPalette.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 104)
            }
        }
        .frame(width: 116, height: 82, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            shelf.open(item)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onDrag {
            shelf.dragProvider(for: item)
        }
        .contextMenu {
            ShelfItemActionsMenu(item: item)
        }
    }
}

private struct ShelfItemActionsMenu: View {
    let item: ShelfItem
    @ObservedObject private var shelf = ShelfStore.shared

    var body: some View {
        Button(item.isPinned ? "Unpin" : "Pin") {
            shelf.togglePinned(item)
        }

        if !item.isMissing {
            Button("Open") {
                shelf.open(item)
            }
        }

        if item.canQuickLook {
            Button("Quick Look") {
                shelf.quickLook(item)
            }
        }

        if item.isFileBacked && !item.isMissing {
            Button("Show in Finder") {
                shelf.reveal(item)
            }
        }

        Divider()

        if !item.isMissing || !item.isFileBacked {
            Button(copyTitle) {
                shelf.copy(item)
            }
        }

        if item.isFileBacked {
            Button("Copy Path") {
                shelf.copyPath(item)
            }
        }

        if !item.isMissing || !item.isFileBacked {
            Divider()

            Button("Share...") {
                shelf.share(items: [item])
            }

            Button("Share via AirDrop") {
                shelf.shareViaAirDrop(items: [item])
            }
        }

        Divider()

        Button("Remove") {
            shelf.remove(item)
        }
    }

    private var copyTitle: String {
        switch item.kind {
        case .link: return "Copy Link"
        case .text: return "Copy Text"
        default: return "Copy Item"
        }
    }
}

private struct ShelfItemArtworkView: View {
    let item: ShelfItem
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var previewImage: NSImage?

    var body: some View {
        Group {
            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(item.isFileBacked ? 0 : 2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: item.id) {
            previewImage = await ShelfThumbnailLoader.thumbnail(for: item, size: size)
        }
    }
}

@MainActor
private enum ShelfThumbnailLoader {
    static func thumbnail(for item: ShelfItem, size: CGFloat) async -> NSImage? {
        guard item.isFileBacked, !item.isMissing, let url = item.resolvedFileURL else {
            return nil
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size * 2, height: size * 2),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: [.thumbnail, .lowQualityThumbnail]
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }
}
