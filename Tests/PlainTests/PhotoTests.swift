import Foundation
import SwiftData
import Testing
@testable import PlainDomain
@testable import PlainPersistence

@MainActor
@Suite("Photo storage and migration")
struct PhotoStoreTests {
    private func repository() -> SwiftDataNoteRepository {
        SwiftDataNoteRepository(container: PlainStore.makeContainer(inMemory: true))
    }

    @Test("Photo metadata and bytes round trip separately")
    func roundTrip() throws {
        let repository = repository()
        let note = Note(title: "Trip", body: "A good day")
        let photo = NotePhoto(thumbnail: Data([1, 2]), pixelWidth: 1_600, pixelHeight: 1_200)
        let original = Data(repeating: 42, count: 100_000)
        try repository.save(note)
        try repository.addPhoto(photo, jpegData: original, to: note.id)
        #expect(try repository.loadNotes().first?.photos == [photo])
        #expect(try repository.photoData(id: photo.id) == original)
    }

    @Test("Editing text cannot drop photos attached since the editor opened")
    func staleEditPreservesPhotos() throws {
        let repository = repository()
        var note = Note(title: "Trip")
        try repository.save(note)
        let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 10, pixelHeight: 20)
        try repository.addPhoto(photo, jpegData: Data([2]), to: note.id)
        note.body = "New text from an older note value"
        try repository.save(note)
        #expect(try repository.loadNotes().first?.photos == [photo])
    }

    @Test("Trash preserves a photo; permanent deletion removes its bytes")
    func lifecycle() throws {
        let repository = repository()
        let note = Note(title: "Trip")
        let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 10, pixelHeight: 20)
        try repository.save(note)
        try repository.addPhoto(photo, jpegData: Data([2]), to: note.id)
        try repository.delete(noteIDs: [note.id])
        #expect(try repository.loadDeletedNotes().first?.photos == [photo])
        try repository.restore(noteIDs: [note.id])
        #expect(try repository.loadNotes().first?.photos == [photo])
        try repository.purge(noteIDs: [note.id])
        #expect(try repository.photoData(id: photo.id) == nil)
    }

    @Test("Removing one photo leaves its note and other photos intact")
    func removeOne() throws {
        let repository = repository()
        let note = Note(title: "Trip", body: "Keep this")
        let photos = (0..<2).map { NotePhoto(thumbnail: Data([UInt8($0)]), pixelWidth: 10, pixelHeight: 20) }
        try repository.save(note)
        for photo in photos { try repository.addPhoto(photo, jpegData: Data([3]), to: note.id) }
        try repository.deletePhoto(id: photos[0].id)
        let loaded = try #require(try repository.loadNotes().first)
        #expect(loaded.body == note.body)
        #expect(loaded.photos == [photos[1]])
        #expect(try repository.photoData(id: photos[0].id) == nil)
    }

    @Test("The thirty-day sweep removes full photo data")
    func expiredTrash() throws {
        let repository = repository()
        var note = Note(title: "Trip")
        let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 10, pixelHeight: 20)
        try repository.save(note)
        try repository.addPhoto(photo, jpegData: Data([2]), to: note.id)
        note.deletedAt = .now.addingTimeInterval(-31 * 86_400)
        try repository.save(note)
        try repository.purgeDeleted(before: .now.addingTimeInterval(-30 * 86_400))
        #expect(try repository.photoData(id: photo.id) == nil)
    }

    @Test("A real version 1 file migrates without losing notes or history")
    func migrateExistingLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.store")
        let note = Note(title: "Before upgrade", body: "Important words", isLocked: true)
        try writeVersionOne(note, to: url)

        let schema = PlainStore.schema
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: PlainMigrationPlan.self, configurations: configuration)
        let repository = SwiftDataNoteRepository(container: container)
        let loaded = try #require(try repository.loadNotes().first)
        #expect(loaded.body == note.body)
        #expect(loaded.isLocked)
        #expect(loaded.photos.isEmpty)
        #expect(try repository.revisions(for: note.id).first?.body == "Older draft")
        let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 10, pixelHeight: 20)
        try repository.addPhoto(photo, jpegData: Data([2]), to: note.id)
        #expect(try repository.loadNotes().first?.photos == [photo])
    }

    private func writeVersionOne(_ note: Note, to url: URL) throws {
        let schema = Schema(versionedSchema: PlainSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.insert(PlainSchemaV1.NoteEntity(note: note))
        context.insert(PlainSchemaV1.RevisionEntity(revision: NoteRevision(noteID: note.id, title: note.title, body: "Older draft")))
        try context.save()
    }
}

@Suite("Photo exchange compatibility")
struct PhotoExchangeTests {
    @Test("Existing encoded notes decode with an empty photo gallery")
    func legacyJSON() throws {
        let note = Note(title: "Before photos")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        object.removeValue(forKey: "photos")
        let decoded = try JSONDecoder().decode(Note.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.id == note.id)
        #expect(decoded.photos.isEmpty)
    }

    @Test("Markdown references the exact file shipped in its photo archive")
    func markdownReferences() {
        let photo = NotePhoto(thumbnail: Data(), pixelWidth: 10, pixelHeight: 20)
        let note = Note(title: "Trip", body: "# Trip", photos: [photo])
        #expect(NoteExchange.markdown(for: note).contains("![Photo](attachments/\(note.id.uuidString)/\(photo.id.uuidString).jpg)"))
    }

    @Test("Old widget snapshots remain readable after the gallery update")
    func legacyWidgetSnapshot() throws {
        let snapshot = WidgetSnapshot(todayCount: 2)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        for key in ["pinnedID", "pinnedPreview", "pinnedThumbnail", "activeDays", "photoNoteID", "photoTitle", "photoThumbnail"] { object.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.todayCount == 2)
        #expect(decoded.photoThumbnail == nil)
    }
}
