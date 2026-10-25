import SwiftUI
import PlainDomain
import PlainDesignSystem

struct NoteDetailView: View {
    let noteID: UUID

    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(LiveActivityController.self) private var liveActivities
    @Environment(LockSession.self) private var locks
    @Environment(PurchaseStore.self) private var purchases

    @State private var confirmingDelete = false
    @State private var exportedFile: ExportedFile?
    @State private var exportFailed = false
    @State private var isFinding = false
    @State private var term = ""
    @State private var openedPhoto: NotePhoto?
    @FocusState private var findFocused: Bool

    private var note: Note? { store.note(noteID) }

    var body: some View {
        PlainScreen {
            if let note {
                VStack(spacing: 0) {
                    header(for: note)

                    if isFinding, !isHidden(note) { findBar(in: note) }

                    if isHidden(note) {
                        lockedGate(note)
                    } else {
                    ScrollView {
                        VStack(spacing: 14) {
                        if !note.unplacedPhotos.isEmpty {
                            NotePhotoGallery(photos: note.unplacedPhotos)
                        }
                        MarkdownRenderedView(
                            document: MarkdownDocument(parsing: searchFiltered(note.body)),
                            bodySize: settings.textSize - 1,
                            onToggleTask: { line in
                                let sourceLine: Int
                                let needle = term.trimmingCharacters(in: .whitespacesAndNewlines)
                                if isFinding, !needle.isEmpty {
                                    // The filtered document joins matches with
                                    // one blank line. Translate its task index
                                    // back to the original note before editing.
                                    let matches = note.body.components(separatedBy: "\n").enumerated()
                                        .filter { $0.element.localizedCaseInsensitiveContains(needle) }
                                    guard line.isMultiple(of: 2), matches.indices.contains(line / 2) else { return }
                                    sourceLine = matches[line / 2].offset
                                } else {
                                    sourceLine = line
                                }
                                store.toggleTask(atLine: sourceLine, in: note.id)
                            },
                            photos: note.photos,
                            photoData: store.photoData,
                            onOpenPhoto: { openedPhoto = $0 }
                        )
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .plainCard()
                        .contentShape(.rect)
                        .onTapGesture { router.push(.editor(note.id)) }

                        backlinks(for: note)
                        }
                        .padding(.horizontal, Metrics.Space.gutter)
                        .padding(.bottom, 16)
                    }
                    .scrollIndicators(.hidden)
                    .environment(\.openURL, OpenURLAction { url in
                        guard let target = WikiLink.target(from: url) else { return .systemAction }
                        open(linkTo: target, from: note)
                        return .handled
                    })
                    }

                    bottomBar(for: note)
                }
            }
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Move to trash", role: .destructive) {
                liveActivities.end(noteID: noteID)
                store.delete(noteIDs: [noteID])
                router.pop()
            }
        } message: {
            Text("You can restore it from Recently deleted for 30 days.")
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(item: $openedPhoto) { photo in
            PhotoViewer(photos: note?.photos ?? [photo], selectedID: photo.id)
        }
        .alert("Could not export that note", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private func isHidden(_ note: Note) -> Bool {
        note.isLocked && !locks.isUnlocked(note.id)
    }

    /// What a locked note shows instead of itself.
    private func lockedGate(_ note: Note) -> some View {
        VStack(spacing: 16) {
            EmptyStateCard(
                glyph: "🔒",
                title: "This note is locked",
                message: "It opens with Face ID and locks itself again when you leave Plain."
            )
            PillButton("Unlock") {
                Task { await locks.unlock(note.id) }
            }
            .padding(.horizontal, 14)
            if let message = locks.errorMessage {
                Text(LocalizedStringKey(message)).font(PlainFont.callout)
                    .foregroundStyle(PlainPalette.inkSecondary)
            }
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity)
    }

    /// Find in note: the reading view redraws with only the matching lines, so
    /// a long note collapses to what was asked for.
    private func searchFiltered(_ body: String) -> String {
        let needle = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFinding, !needle.isEmpty else { return body }
        let lines = body.components(separatedBy: "\n")
        let matches = lines.filter { $0.localizedCaseInsensitiveContains(needle) }
        guard !matches.isEmpty else {
            return String(localized: "_No match for “\(needle)”._")
        }
        return matches.joined(separator: "\n\n")
    }

    private func findBar(in note: Note) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PlainPalette.inkTertiary)
            TextField("Find in note", text: $term)
                .font(PlainFont.body)
                .foregroundStyle(PlainPalette.ink)
                .autocorrectionDisabled()
                .focused($findFocused)
            Button("Done") {
                withAnimation(.snappy) { isFinding = false }
                term = ""
            }
            .font(PlainFont.sans(13, .semibold))
            .foregroundStyle(PlainPalette.inkSecondary)
        }
        .padding(.horizontal, Metrics.Space.card)
        .frame(height: 44)
        .plainCard(radius: Metrics.Radius.inner)
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.bottom, 8)
    }

    /// Notes that point here. The other half of a `[[wiki link]]`.
    @ViewBuilder
    private func backlinks(for note: Note) -> some View {
        let linking = store.backlinks(to: note)
        if !linking.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Linked from")
                    .font(PlainFont.sans(12, .semibold))
                    .foregroundStyle(PlainPalette.inkTertiary)
                    .padding(.horizontal, Metrics.Space.card)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                ForEach(Array(linking.enumerated()), id: \.element.id) { index, source in
                    Button {
                        router.push(.note(source.id))
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.turn.up.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PlainPalette.inkTertiary)
                            Text(source.title)
                                .font(PlainFont.body)
                                .foregroundStyle(PlainPalette.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Metrics.Space.card)
                        .frame(height: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < linking.count - 1 { PlainDivider(inset: 46) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plainCard()
        }
    }

    /// A link to a note that does not exist yet writes it — the same move as
    /// following a red link in a wiki.
    private func open(linkTo target: String, from note: Note) {
        if let existing = store.note(titled: target) {
            router.push(.note(existing.id))
        } else {
            let created = store.createNote(titled: target, in: note.folderID)
            router.push(.editor(created.id))
        }
    }

    private func exportMarkdown(_ note: Note) {
        do { exportedFile = ExportedFile(url: try LibraryExchange.markdownFile(for: note, photoData: store.photoData)) } catch { exportFailed = true }
    }

    private func exportPDF(_ note: Note) {
        guard purchases.hasPro else {
            router.present(.pro(.pdf))
            return
        }
        do { exportedFile = ExportedFile(url: try NotePDF.file(for: note, bodySize: settings.textSize - 1, photoData: store.photoData)) } catch { exportFailed = true }
    }

    private func header(for note: Note) -> some View {
        ScreenHeader(
            verbatimTitle: store.folderName(note.folderID),
            verbatimCaption: PlainDate.relative(note.updatedAt),
            onBack: { router.pop() }
        ) {
            Menu {
                if NoteAssistant.isAvailable {
                    Menu("Assist", systemImage: "sparkles") {
                        ForEach(NoteAssistant.Job.allCases) { job in
                            Button(LocalizedStringKey(job.label), systemImage: job.icon) {
                                if purchases.hasPro {
                                    router.present(.assist(note.id, NoteAssistantJob(kind: job)))
                                } else {
                                    router.present(.pro(.assistant))
                                }
                            }
                        }
                    }
                }
                Button("History", systemImage: "clock.arrow.circlepath") {
                    if purchases.hasPro { router.push(.history(note.id)) }
                    else { router.present(.pro(.history)) }
                }
                Button(
                    note.isLocked ? "Remove lock" : "Lock note",
                    systemImage: note.isLocked ? "lock.open" : "lock"
                ) {
                    if !note.isLocked {
                        liveActivities.end(noteID: note.id)
                        store.endLive(noteID: note.id)
                    }
                    store.setLocked(!note.isLocked, for: note.id)
                    if note.isLocked { locks.forget(note.id) }
                }
                Button("Find in note", systemImage: "magnifyingglass") {
                    withAnimation(.snappy) { isFinding = true }
                    findFocused = true
                }
                Button(note.photos.isEmpty ? "Export markdown" : "Export Markdown + photos", systemImage: "doc.text") { exportMarkdown(note) }
                Button("Export PDF", systemImage: "doc.richtext") { exportPDF(note) }
                Menu("Move to") {
                    Button("All Notes") { store.move(noteID: note.id, to: nil) }
                    ForEach(store.folders) { folder in
                        Button(folder.name) { store.move(noteID: note.id, to: folder.id) }
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PlainPalette.ink)
                    .frame(width: 38, height: 38)
                    .background(PlainPalette.surface, in: .circle)
            }
            .disabled(isHidden(note))
            .accessibilityLabel("Note options")
        }
    }

    private func bottomBar(for note: Note) -> some View {
        HStack(spacing: 12) {
            PillButton(
                note.isLive() ? "Live now" : "Go Live",
                systemImage: note.isLive() ? "circle.fill" : "circle",
                style: .plain
            ) {
                if note.isLive() {
                    router.push(.live(note.id))
                } else if let session = store.startLive(noteID: note.id, duration: .eightHours) {
                    if settings.liveActivityByDefault, let updated = store.note(note.id) {
                        liveActivities.start(note: updated, session: session)
                    }
                    router.push(.live(note.id))
                }
            }
            .disabled(isHidden(note))
            CircleIconButton("trash", label: "Delete note") { confirmingDelete = true }
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.bottom, 8)
    }
}
