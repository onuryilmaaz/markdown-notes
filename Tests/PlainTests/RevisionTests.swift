import Testing
import Foundation
@testable import PlainDomain
@testable import PlainPersistence

@Suite("Revision policy")
struct RevisionPolicyTests {
    @Test("The first edit of a written note is always kept")
    func firstEdit() {
        #expect(RevisionPolicy.shouldRecord(previous: "something", next: "something else", lastSavedAt: nil))
    }

    @Test("Typing into an empty note records nothing")
    func emptyPrevious() {
        #expect(!RevisionPolicy.shouldRecord(previous: "", next: "first words", lastSavedAt: nil))
        #expect(!RevisionPolicy.shouldRecord(previous: "   \n ", next: "first words", lastSavedAt: nil))
    }

    @Test("An unchanged body is not a version")
    func noChange() {
        #expect(!RevisionPolicy.shouldRecord(previous: "same", next: "same", lastSavedAt: nil))
    }

    @Test("Keystrokes inside the window do not each become a version")
    func throttled() {
        let justNow = Date.now.addingTimeInterval(-10)
        #expect(!RevisionPolicy.shouldRecord(previous: "hello", next: "hello w", lastSavedAt: justNow))
    }

    @Test("After the window, the next edit is kept")
    func afterWindow() {
        let old = Date.now.addingTimeInterval(-RevisionPolicy.interval - 1)
        #expect(RevisionPolicy.shouldRecord(previous: "hello", next: "hello w", lastSavedAt: old))
    }

    @Test("Losing half a long note is kept even inside the window")
    func suddenShrink() {
        let long = String(repeating: "word ", count: 100)
        #expect(RevisionPolicy.shouldRecord(previous: long, next: "oops", lastSavedAt: .now))
    }
}

@MainActor
@Suite("History")
struct RevisionStoreTests {
    private func makeRepository() -> SwiftDataNoteRepository {
        SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
    }

    @Test("Rewriting a note keeps what was replaced")
    func savesPreviousBody() throws {
        let repository = makeRepository()
        var note = Note(title: "Spec", body: "first draft")
        try repository.save(note)

        note.body = "second draft"
        try repository.save(note)

        let history = try repository.revisions(for: note.id)
        #expect(history.count == 1)
        #expect(history.first?.body == "first draft")
        // The live note is the new one.
        #expect(try repository.loadNotes().first?.body == "second draft")
    }

    @Test("History is capped so a long-lived note cannot grow forever")
    func trimsToLimit() throws {
        let repository = makeRepository()
        let note = Note(title: "Journal", body: "v0")

        for version in 0...(RevisionPolicy.limit + 5) {
            try repository.record(NoteRevision(noteID: note.id, title: "Journal", body: "v\(version)"))
        }

        let history = try repository.revisions(for: note.id)
        #expect(history.count == RevisionPolicy.limit)
    }

    @Test("Destroying a note takes its history with it")
    func purgeRemovesHistory() throws {
        let repository = makeRepository()
        let note = Note(title: "Spec", body: "first")
        try repository.save(note)
        try repository.record(NoteRevision(noteID: note.id, title: "Spec", body: "older"))

        try repository.delete(noteIDs: [note.id])
        try repository.purge(noteIDs: [note.id])

        #expect(try repository.revisions(for: note.id).isEmpty)
    }

    @Test("The automatic trash sweep also destroys private revision bodies")
    func expiredTrashRemovesHistory() throws {
        let repository = makeRepository()
        let note = Note(title: "Private", body: "private body", deletedAt: .now.addingTimeInterval(-31 * 86_400))
        try repository.save(note)
        try repository.record(NoteRevision(noteID: note.id, title: note.title, body: "older private body"))

        try repository.purgeDeleted(before: .now.addingTimeInterval(-30 * 86_400))

        #expect(try repository.loadDeletedNotes().isEmpty)
        #expect(try repository.revisions(for: note.id).isEmpty)
    }

    @Test("A locked note stays locked through a round trip")
    func lockSurvives() throws {
        let repository = makeRepository()
        var note = Note(title: "Diary", body: "private")
        note.isLocked = true
        try repository.save(note)

        #expect(try repository.loadNotes().first?.isLocked == true)
    }
}
