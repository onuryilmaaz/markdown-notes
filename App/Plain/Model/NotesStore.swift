import Foundation
import Observation
import WidgetKit
import PlainDomain

/// Single source of truth for the UI. Views read the arrays, call the intents,
/// and never touch storage — the repository behind this is swappable.
@MainActor
@Observable
final class NotesStore {
    private let repository: NoteRepository

    private(set) var folders: [Folder] = []
    private(set) var notes: [Note] = []
    private(set) var deletedNotes: [Note] = []

    /// How long a deleted note waits in the trash before it is really gone.
    static let trashWindow: TimeInterval = 30 * 24 * 60 * 60

    init(repository: NoteRepository) {
        self.repository = repository
        try? repository.purgeDeleted(before: .now - Self.trashWindow)
        reload()
    }

    // MARK: Reading

    func reload() {
        folders = (try? repository.loadFolders()) ?? []
        notes = (try? repository.loadNotes()) ?? []
        deletedNotes = (try? repository.loadDeletedNotes()) ?? []
        publishSnapshot()
    }

    /// `nil` folder means the whole library.
    func notes(in folderID: UUID?, sort: NoteSort = .recentlyEdited) -> [Note] {
        let scoped = folderID.map { id in notes.filter { $0.folderID == id } } ?? notes
        return sort.apply(to: scoped)
    }

    func note(_ id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    /// Wiki links address notes by title, so this is how `[[…]]` resolves.
    func note(titled title: String) -> Note? {
        notes.first { WikiLink.matches($0.title, title) }
    }

    /// Notes that point at this one. The other half of a wiki link.
    func backlinks(to note: Note) -> [Note] {
        notes.filter { $0.id != note.id && $0.links(to: note.title) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func folder(_ id: UUID?) -> Folder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    func folderName(_ id: UUID?) -> String {
        folder(id)?.name ?? String(localized: "All Notes")
    }

    func count(in folder: Folder) -> Int {
        notes.count { $0.folderID == folder.id }
    }

    var statistics: LibraryStatistics {
        LibraryStatistics.make(from: notes)
    }

    var liveNotes: [Note] {
        notes.filter { $0.isLive() }
    }

    /// Tags ordered by use — drives the Tags screen and the Home chip row.
    var tagCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for note in notes {
            for tag in note.tags { counts[tag, default: 0] += 1 }
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }

    /// A locked note answers to its title only — its body must not leak
    /// through a search snippet.
    func hits(for term: String, scope: SearchScope) -> [SearchHit] {
        let searchable = notes.map { note -> Note in
            guard note.isLocked else { return note }
            var redacted = note
            redacted.body = ""
            return redacted
        }
        return SearchEngine.hits(for: term, in: searchable, scope: scope)
    }

    // MARK: Notes

    @discardableResult
    func createNote(in folderID: UUID?, template: NoteTemplate = .blank) -> Note {
        let note = Note(
            title: template.title,
            body: template.body(),
            folderID: folderID ?? folders.first?.id,
            tags: MarkdownText.tags(in: template.body())
        )
        write { try repository.save(note) }
        return note
    }

    /// Used when a wiki link points at a note that does not exist yet.
    @discardableResult
    func createNote(titled title: String, in folderID: UUID?) -> Note {
        let note = Note(title: title, body: "# \(title)\n\n", folderID: folderID)
        write { try repository.save(note) }
        return note
    }

    /// Saves a note, keeping the derived fields (title, tags, timestamp) honest.
    func update(_ note: Note, touch: Bool = true) {
        var updated = note
        updated.title = MarkdownText.firstHeading(in: note.body)
            ?? note.body.components(separatedBy: .newlines).first.map(MarkdownText.stripped)?.nilIfEmpty
            ?? note.title.nilIfEmpty
            ?? "Untitled"
        updated.tags = MarkdownText.tags(in: note.body)
        if touch { updated.updatedAt = .now }
        write { try repository.save(updated) }
    }

    func revisions(for noteID: UUID) -> [NoteRevision] {
        (try? repository.revisions(for: noteID)) ?? []
    }

    func addPhoto(_ photo: NotePhoto, jpegData: Data, to noteID: UUID) throws {
        try repository.addPhoto(photo, jpegData: jpegData, to: noteID)
        reload()
    }

    func photoData(_ id: UUID) -> Data? {
        try? repository.photoData(id: id)
    }

    /// Removes the photo and the line that placed it, so no empty spot is left
    /// behind in the text.
    func deletePhoto(_ id: UUID) {
        write {
            if var note = notes.first(where: { $0.photos.contains { $0.id == id } }) {
                let body = PhotoMarkdown.removing(id, from: note.body)
                if body != note.body {
                    note.body = body
                    try repository.save(note)
                }
            }
            try repository.deletePhoto(id: id)
        }
    }

    /// Puts an older body back, keeping the current one as its own revision.
    func restore(_ revision: NoteRevision) {
        guard var note = note(revision.noteID) else { return }
        note.body = revision.body
        update(note)
    }

    func setLocked(_ isLocked: Bool, for id: UUID) {
        guard var note = note(id) else { return }
        note.isLocked = isLocked
        write { try repository.save(note) }
    }

    func setPinned(_ isPinned: Bool, for id: UUID) {
        guard var note = note(id) else { return }
        note.isPinned = isPinned
        write { try repository.save(note) }
    }

    /// Moves notes to the trash. `purge` is the irreversible one.
    func delete(noteIDs: Set<UUID>) {
        write { try repository.delete(noteIDs: noteIDs) }
    }

    func restore(noteIDs: Set<UUID>) {
        write { try repository.restore(noteIDs: noteIDs) }
    }

    func purge(noteIDs: Set<UUID>) {
        write { try repository.purge(noteIDs: noteIDs) }
    }

    func emptyTrash() {
        write { try repository.purge(noteIDs: Set(deletedNotes.map(\.id))) }
    }

    /// Days left before the trash clears a note out by itself.
    func daysLeftInTrash(_ note: Note) -> Int {
        guard let deletedAt = note.deletedAt else { return 0 }
        let remaining = deletedAt.addingTimeInterval(Self.trashWindow).timeIntervalSinceNow
        return max(Int(ceil(remaining / 86_400)), 0)
    }

    /// Flips a `- [ ]` box straight from the reading view.
    func toggleTask(atLine line: Int, in noteID: UUID) {
        guard var note = note(noteID) else { return }
        note.body = MarkdownText.toggledTask(atLine: line, in: note.body)
        update(note)
    }

    /// Brings in notes from files, the clipboard or an extension. Returns how
    /// many landed. Tags are derived here so every way into the library ends up
    /// with the same note.
    @discardableResult
    func importNotes(_ incoming: [Note]) -> Int {
        guard !incoming.isEmpty else { return 0 }
        write {
            for note in incoming {
                var filed = note
                filed.tags = MarkdownText.tags(in: note.body)
                try repository.save(filed)
            }
        }
        return incoming.count
    }

    func move(noteID: UUID, to folderID: UUID?) {
        guard var note = note(noteID) else { return }
        note.folderID = folderID
        write { try repository.save(note) }
    }

    // MARK: Live sessions

    @discardableResult
    func startLive(noteID: UUID, duration: LiveDuration) -> LiveSession? {
        guard var note = note(noteID) else { return nil }
        let session = LiveSession(duration: duration.rawValue)
        note.live = session
        write { try repository.save(note) }
        return session
    }

    func endLive(noteID: UUID) {
        guard var note = note(noteID) else { return }
        note.live = nil
        write { try repository.save(note) }
    }

    // MARK: Folders

    @discardableResult
    func createFolder(named name: String) -> Folder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var created: Folder?
        write { created = try repository.createFolder(named: trimmed) }
        return created
    }

    func renameFolder(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        write { try repository.renameFolder(id: id, to: trimmed) }
    }

    func deleteFolder(_ id: UUID) {
        write { try repository.deleteFolder(id: id) }
    }

    // MARK: Library

    func deleteLibrary() {
        write { try repository.deleteEverything() }
    }

    var isEmpty: Bool { notes.isEmpty && folders.isEmpty }

    // MARK: Plumbing

    private func write(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            assertionFailure("Store write failed: \(error)")
        }
        reload()
        SpotlightIndexer.sync(notes: notes)
    }

    /// Keeps the home-screen widgets in step with the library.
    private func publishSnapshot() {
        let stats = LibraryStatistics.make(from: notes)
        let pinned = notes.first(where: \.isPinned)
        let photoNote = notes.first { !$0.isLocked && !$0.photos.isEmpty }
        let snapshot = WidgetSnapshot(
            date: .now,
            todayCount: stats.todayCount,
            pinnedTitle: pinned?.title,
            pinnedSubtitle: pinned.map { folderName($0.folderID) },
            recent: notes.sorted { $0.updatedAt > $1.updatedAt }.prefix(3).map {
                WidgetSnapshot.Item(
                    id: $0.id,
                    title: $0.title,
                    subtitle: PlainDate.short($0.updatedAt),
                    isLive: $0.isLive(),
                    preview: $0.isLocked ? nil : $0.preview,
                    thumbnail: $0.isLocked ? nil : $0.photos.first?.thumbnail
                )
            },
            pinnedID: pinned?.id,
            pinnedPreview: pinned.flatMap { $0.isLocked ? nil : $0.preview },
            pinnedThumbnail: pinned.flatMap { $0.isLocked ? nil : $0.photos.first?.thumbnail },
            activeDays: stats.recentDays.map(\.isActive),
            photoNoteID: photoNote?.id,
            photoTitle: photoNote?.title,
            photoThumbnail: photoNote?.photos.first?.thumbnail
        )
        SnapshotStore.shared.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
