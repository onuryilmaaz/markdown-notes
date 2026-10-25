import SwiftUI
import PlainDomain
import PlainDesignSystem

struct NoteListView: View {
    let scope: ListScope

    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    @State private var isCompact = false
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var confirmingDelete = false

    private var folderID: UUID? {
        if case .folder(let id) = scope { return id }
        return nil
    }

    private var notes: [Note] {
        switch scope {
        case .folder(let id): store.notes(in: id, sort: settings.noteSort)
        case .tag(let tag): store.notes(in: nil, sort: settings.noteSort).filter { $0.tags.contains(tag) }
        }
    }

    private var title: String {
        switch scope {
        case .folder(let id): store.folderName(id)
        case .tag(let tag): "#" + tag
        }
    }

    var body: some View {
        PlainScreen {
            VStack(spacing: 0) {
                header

                if notes.isEmpty {
                    emptyState
                } else {
                    list
                    bottomBar
                }
            }
        }
        .confirmationDialog("Delete ^[\(selection.count) note](inflect: true)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Move to trash", role: .destructive) {
                store.delete(noteIDs: selection)
                selection.removeAll()
                isSelecting = false
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 2) {
            ZStack {
                Menu {
                    Button("All Notes") { router.path = [.list(.folder(nil))] }
                    ForEach(store.folders) { folder in
                        Button(folder.name) { router.path = [.list(.folder(folder.id))] }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(PlainFont.headline)
                            .foregroundStyle(PlainPalette.ink)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PlainPalette.inkSecondary)
                    }
                }

                HStack {
                    CircleIconButton("chevron.left", label: "Back", size: 38) { router.pop() }
                    Spacer()
                    Menu {
                        Button(isCompact ? "Roomy list" : "Index list") { isCompact.toggle() }
                        Picker("Sort by", selection: Bindable(settings).noteSort) {
                            ForEach(NoteSort.allCases) { option in
                                Text(LocalizedStringKey(option.label)).tag(option)
                            }
                        }
                        if let folderID {
                            Button("Rename folder") { router.present(.renameFolder(folderID)) }
                            Button("Delete folder", role: .destructive) {
                                store.deleteFolder(folderID)
                                router.popToRoot()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PlainPalette.ink)
                            .frame(width: 38, height: 38)
                            .background(PlainPalette.surface, in: .circle)
                    }
                    .accessibilityLabel("List options")
                }
            }
            Text(subtitle)
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.vertical, 10)
    }

    private var subtitle: LocalizedStringKey {
        isSelecting
            ? "\(selection.count) selected"
            : "^[\(notes.count) note](inflect: true) · \(sortCaption)"
    }

    /// Localised before it is interpolated: a string spliced into a
    /// LocalizedStringKey travels as data and would never be translated.
    private var sortCaption: String {
        String(localized: String.LocalizationValue(settings.noteSort.caption))
    }

    // MARK: Content

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: isCompact ? 0 : 10) {
                if isCompact {
                    VStack(spacing: 0) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                            CompactNoteRow(note: note) { open(note) }
                            if index < notes.count - 1 { PlainDivider(inset: 62) }
                        }
                    }
                    .plainCard()
                } else {
                    ForEach(notes) { note in
                        NoteCard(
                            note: note,
                            folderName: folderID == nil ? store.folderName(note.folderID) : nil,
                            isSelected: selection.contains(note.id),
                            showsSelection: isSelecting
                        ) {
                            open(note)
                        }
                        .contextMenu {
                            Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") {
                                store.setPinned(!note.isPinned, for: note.id)
                            }
                            Menu("Move to") {
                                Button("All Notes") { store.move(noteID: note.id, to: nil) }
                                ForEach(store.folders) { folder in
                                    Button(folder.name) { store.move(noteID: note.id, to: folder.id) }
                                }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(noteIDs: [note.id]) }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.Space.gutter)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(
                isCompact ? "rectangle.grid.1x2" : "list.bullet",
                label: isCompact ? "Roomy list" : "Index list"
            ) {
                withAnimation(.snappy) { isCompact.toggle() }
            }
            PillButton(isSelecting ? "Delete" : "Write", systemImage: isSelecting ? "trash" : "plus") {
                if isSelecting {
                    guard !selection.isEmpty else { return }
                    confirmingDelete = true
                } else {
                    compose()
                }
            }
            .frame(width: 150)
            .contextMenu {
                if !isSelecting {
                    ForEach(NoteTemplate.allCases) { template in
                        Button(LocalizedStringKey(template.label), systemImage: template.icon) { compose(template) }
                    }
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            CircleIconButton(
                isSelecting ? "xmark" : "trash",
                label: isSelecting ? "Stop selecting" : "Select notes"
            ) {
                withAnimation(.snappy) {
                    isSelecting.toggle()
                    selection.removeAll()
                }
            }
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            EmptyStateCard(
                glyph: "#",
                title: "Nothing here yet",
                message: "Start with a heading. Markdown works as you type."
            )
            PillButton("Write the first note") { compose() }
            .padding(.horizontal, 14)
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.bottom, 10)
    }

    private func compose(_ template: NoteTemplate = .blank) {
        router.push(.editor(store.createNote(in: folderID, template: template).id))
    }

    private func open(_ note: Note) {
        if isSelecting {
            if selection.contains(note.id) { selection.remove(note.id) } else { selection.insert(note.id) }
        } else {
            router.push(.note(note.id))
        }
    }
}

/// One line per note — the index density from the reference set.
private struct CompactNoteRow: View {
    let note: Note
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(PlainDate.short(note.updatedAt))
                    .font(PlainFont.meta)
                    .foregroundStyle(PlainPalette.inkTertiary)
                    .frame(width: 38, alignment: .leading)
                Text(note.title)
                    .font(PlainFont.sans(13.5, .medium))
                    .foregroundStyle(PlainPalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let tag = note.tags.first {
                    Text("#" + tag)
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
            }
            .padding(.horizontal, Metrics.Space.card)
            .frame(height: 42)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
