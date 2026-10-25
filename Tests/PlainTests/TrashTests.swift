import Testing
import Foundation
import SwiftData
@testable import PlainDomain
@testable import PlainPersistence

/// The repository against a real in-memory SwiftData store — the trash rules
/// are the ones that decide whether somebody loses work.
@MainActor
@Suite("Trash")
struct TrashTests {
    private func makeRepository() -> SwiftDataNoteRepository {
        SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
    }

    @Test("Deleting moves a note out of the library and into the trash")
    func deleteIsSoft() throws {
        let repository = makeRepository()
        let note = Note(title: "Draft", body: "body")
        try repository.save(note)

        try repository.delete(noteIDs: [note.id])

        #expect(try repository.loadNotes().isEmpty)
        let trashed = try repository.loadDeletedNotes()
        #expect(trashed.count == 1)
        #expect(trashed.first?.deletedAt != nil)
        #expect(trashed.first?.body == "body")
    }

    @Test("A trashed note is no longer live or pinned")
    func deleteClearsLiveAndPin() throws {
        let repository = makeRepository()
        var note = Note(title: "Draft")
        note.isPinned = true
        note.live = LiveSession(duration: 3_600)
        try repository.save(note)

        try repository.delete(noteIDs: [note.id])

        let trashed = try #require(try repository.loadDeletedNotes().first)
        #expect(trashed.isPinned == false)
        #expect(trashed.live == nil)
    }

    @Test("Restoring brings the note back whole")
    func restore() throws {
        let repository = makeRepository()
        let note = Note(title: "Draft", body: "# Draft\n\nkeep me")
        try repository.save(note)
        try repository.delete(noteIDs: [note.id])

        try repository.restore(noteIDs: [note.id])

        #expect(try repository.loadDeletedNotes().isEmpty)
        let restored = try #require(try repository.loadNotes().first)
        #expect(restored.body == "# Draft\n\nkeep me")
        #expect(restored.deletedAt == nil)
    }

    @Test("Purging is the only thing that destroys a note")
    func purge() throws {
        let repository = makeRepository()
        let note = Note(title: "Draft")
        try repository.save(note)
        try repository.delete(noteIDs: [note.id])

        try repository.purge(noteIDs: [note.id])

        #expect(try repository.loadNotes().isEmpty)
        #expect(try repository.loadDeletedNotes().isEmpty)
    }

    @Test("The thirty-day sweep takes the old and leaves the recent")
    func purgeExpired() throws {
        let repository = makeRepository()
        let old = Note(title: "Old")
        let recent = Note(title: "Recent")
        try repository.save(old)
        try repository.save(recent)
        try repository.delete(noteIDs: [old.id, recent.id])

        // Age one of them past the window.
        var aged = try #require(try repository.loadDeletedNotes().first { $0.id == old.id })
        aged.deletedAt = .now.addingTimeInterval(-31 * 86_400)
        try repository.save(aged)

        try repository.purgeDeleted(before: .now.addingTimeInterval(-30 * 86_400))

        let remaining = try repository.loadDeletedNotes()
        #expect(remaining.count == 1)
        #expect(remaining.first?.title == "Recent")
    }

    @Test("Deleting a folder trashes its notes instead of destroying them")
    func folderDeleteKeepsNotes() throws {
        let repository = makeRepository()
        let folder = try repository.createFolder(named: "Work")
        let note = Note(title: "Spec", folderID: folder.id)
        try repository.save(note)

        try repository.deleteFolder(id: folder.id)

        #expect(try repository.loadFolders().isEmpty)
        let trashed = try #require(try repository.loadDeletedNotes().first)
        #expect(trashed.title == "Spec")
        // Unfiled, so restoring it cannot point at a folder that is gone.
        #expect(trashed.folderID == nil)
    }
}

@MainActor
@Suite("Shared library location")
struct SharedStoreTests {
    @Test("An in-memory container never touches the shared file")
    func inMemoryIsIsolated() throws {
        let first = SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
        let second = SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
        try first.save(Note(title: "Only here"))

        #expect(try first.loadNotes().count == 1)
        #expect(try second.loadNotes().isEmpty)
    }

    @Test("The shared store sits in a container both the app and its extensions can open")
    func sharedPath() {
        // Nil is a legitimate answer on a build without the entitlement; the
        // app falls back to its own container in that case.
        guard let url = PlainStore.sharedStoreURL() else { return }
        #expect(url.lastPathComponent == "Plain.store")
        #expect(url.isFileURL)
        #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }
}

@MainActor
@Suite("Import shape")
struct ImportShapeTests {
    @Test("However a note arrives, its tags come from its body")
    func tagsAreDerived() {
        // The file path and the paste path both go through NoteExchange…
        let fromFile = NoteExchange.note(fromFileNamed: "a.md", contents: "# A\n\n#spec #api")
        #expect(fromFile.tags == ["spec", "api"])

        let pasted = NoteExchange.note(fromPastedText: "notes about #backend")
        #expect(pasted?.tags == ["backend"])

        // …and the rule itself is the one the editor uses.
        #expect(MarkdownText.tags(in: "# A\n\n#spec #api") == ["spec", "api"])
    }
}

@MainActor
@Suite("Schema versioning")
struct SchemaTests {
    /// Moving the models inside `PlainSchemaV1` must not rename anything in the
    /// store: a renamed entity would orphan every note already on a phone — and
    /// in CloudKit, where field names cannot be taken back.
    @Test("The persisted shape keeps the names it already had")
    func entityNames() {
        let names = Set(PlainStore.schema.entities.map(\.name))
        #expect(names == ["NoteEntity", "FolderEntity", "RevisionEntity", "PhotoEntity"])
    }

    @Test("The schema is stamped with a version")
    func version() {
        #expect(PlainStore.schema.version == Schema.Version(2, 0, 0))
        #expect(PlainMigrationPlan.schemas.count == 2)
        // Photo records are added in a lightweight migration from version 1.
        #expect(PlainMigrationPlan.stages.count == 1)
    }

    @Test("A container built from the versioned schema still reads and writes")
    func roundTrip() throws {
        let repository = SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
        let note = Note(title: "After versioning", body: "still here")
        try repository.save(note)

        let loaded = try #require(try repository.loadNotes().first)
        #expect(loaded.title == "After versioning")
        #expect(loaded.body == "still here")
    }
}
