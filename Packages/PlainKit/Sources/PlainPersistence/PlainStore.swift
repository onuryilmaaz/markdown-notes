import Foundation
import SwiftData
import PlainDomain

public enum PlainStore {
    public static let schema = Schema(versionedSchema: PlainSchemaV2.self)
    private static let fileName = "Plain.store"

    /// The library lives in the app group so the share extension and the
    /// widgets can reach the same notes the app is holding. Falls back to an
    /// in-memory store if the on-disk one cannot be opened, so a corrupt store
    /// never bricks the app.
    @MainActor
    public static func makeContainer(inMemory: Bool = false, syncsWithICloud: Bool = false) -> ModelContainer {
        // Each rung is tried in turn, so a missing entitlement or an
        // unreachable iCloud account costs the sync, never the library.
        for configuration in configurations(inMemory: inMemory, syncsWithICloud: syncsWithICloud) {
            if let container = try? ModelContainer(
                for: schema,
                migrationPlan: PlainMigrationPlan.self,
                configurations: configuration
            ) {
                return container
            }
        }
        return try! ModelContainer(
            for: schema,
            migrationPlan: PlainMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private static func configurations(inMemory: Bool, syncsWithICloud: Bool) -> [ModelConfiguration] {
        guard !inMemory else {
            return [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        }

        var ladder: [ModelConfiguration] = []
        if let shared = sharedStoreURL() {
            adoptLegacyStore(movingTo: shared)
            if syncsWithICloud {
                ladder.append(ModelConfiguration(
                    schema: schema,
                    url: shared,
                    cloudKitDatabase: .private(AppGroup.cloudContainer)
                ))
            }
            ladder.append(ModelConfiguration(schema: schema, url: shared, cloudKitDatabase: .none))
        }
        // No app group (unsigned build): the app's own container still works,
        // extensions simply will not see it.
        ladder.append(ModelConfiguration(schema: schema, cloudKitDatabase: .none))
        return ladder
    }

    public static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(fileName)
    }

    /// Builds before the move kept the library in the app's own container.
    /// Carry it over once, rather than greeting those installs with an empty app.
    private static func adoptLegacyStore(movingTo destination: URL) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { return }
        guard let support = try? manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }

        let legacy = support.appendingPathComponent("default.store")
        guard manager.fileExists(atPath: legacy.path) else { return }

        // SQLite keeps its write-ahead log beside the database; all three move.
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: legacy.path + suffix)
            let to = URL(fileURLWithPath: destination.path + suffix)
            guard manager.fileExists(atPath: from.path) else { continue }
            try? manager.copyItem(at: from, to: to)
        }
    }
}

@MainActor
public final class SwiftDataNoteRepository: NoteRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public convenience init(container: ModelContainer) {
        self.init(context: ModelContext(container))
    }

    // MARK: Reading

    public func loadFolders() throws -> [Folder] {
        let descriptor = FetchDescriptor<FolderEntity>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).map(\.domain)
    }

    public func loadNotes() throws -> [Note] {
        let descriptor = FetchDescriptor<NoteEntity>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try attachPhotos(to: context.fetch(descriptor))
    }

    public func loadDeletedNotes() throws -> [Note] {
        let descriptor = FetchDescriptor<NoteEntity>(
            predicate: #Predicate { $0.deletedAt != nil },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        return try attachPhotos(to: context.fetch(descriptor))
    }

    // MARK: Folders

    @discardableResult
    public func createFolder(named name: String) throws -> Folder {
        let count = try context.fetchCount(FetchDescriptor<FolderEntity>())
        let entity = FolderEntity(name: name, sortIndex: count)
        context.insert(entity)
        try context.save()
        return entity.domain
    }

    public func renameFolder(id: UUID, to name: String) throws {
        guard let entity = try folderEntity(id) else { return }
        entity.name = name
        try context.save()
    }

    /// Deleting a folder sends its notes to the trash rather than destroying
    /// them, and unfiles them so a restored note is not orphaned.
    public func deleteFolder(id: UUID) throws {
        let now = Date.now
        for note in try noteEntities(inFolder: id) {
            note.folderID = nil
            if note.deletedAt == nil { note.deletedAt = now }
        }
        if let entity = try folderEntity(id) { context.delete(entity) }
        try context.save()
    }

    // MARK: Notes

    public func save(_ note: Note) throws {
        if let entity = try noteEntity(note.id) {
            // The body about to be overwritten may be worth keeping.
            let previous = entity.body
            let last = try revisions(for: note.id).first?.savedAt
            if RevisionPolicy.shouldRecord(previous: previous, next: note.body, lastSavedAt: last) {
                context.insert(RevisionEntity(revision: NoteRevision(
                    noteID: note.id,
                    title: entity.title,
                    body: previous
                )))
                try trimRevisions(for: note.id)
            }
            entity.apply(note)
        } else {
            context.insert(NoteEntity(note: note))
        }
        try context.save()
    }

    public func delete(noteIDs: Set<UUID>) throws {
        let now = Date.now
        for id in noteIDs {
            guard let entity = try noteEntity(id), entity.deletedAt == nil else { continue }
            entity.deletedAt = now
            // A trashed note is not live and is not pinned anywhere.
            entity.liveID = nil
            entity.liveStartedAt = nil
            entity.liveExpiresAt = nil
            entity.isPinned = false
        }
        try context.save()
    }

    public func addPhoto(_ photo: NotePhoto, jpegData: Data, to noteID: UUID) throws {
        guard let note = try noteEntity(noteID), note.deletedAt == nil else { throw CocoaError(.fileNoSuchFile) }
        let existing = try photos(for: noteID)
        guard !existing.contains(where: { $0.id == photo.id }) else { return }
        context.insert(PhotoEntity(photo: photo, jpegData: jpegData, noteID: noteID, sortIndex: (existing.map(\.sortIndex).max() ?? -1) + 1))
        note.updatedAt = .now
        try context.save()
    }

    public func photoData(id: UUID) throws -> Data? {
        let descriptor = FetchDescriptor<PhotoEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first?.jpegData
    }

    public func deletePhoto(id: UUID) throws {
        let descriptor = FetchDescriptor<PhotoEntity>(predicate: #Predicate { $0.id == id })
        for photo in try context.fetch(descriptor) {
            try noteEntity(photo.noteID)?.updatedAt = .now
            context.delete(photo)
        }
        try context.save()
    }

    public func restore(noteIDs: Set<UUID>) throws {
        for id in noteIDs {
            guard let entity = try noteEntity(id) else { continue }
            entity.deletedAt = nil
        }
        try context.save()
    }

    public func purge(noteIDs: Set<UUID>) throws {
        for id in noteIDs {
            if let entity = try noteEntity(id) { context.delete(entity) }
            try deletePhotos(for: id)
            try deleteRevisions(for: id)
        }
        try context.save()
    }

    /// Housekeeping for the thirty-day window.
    public func purgeDeleted(before date: Date) throws {
        let descriptor = FetchDescriptor<NoteEntity>(
            predicate: #Predicate { entity in
                if let deletedAt = entity.deletedAt { return deletedAt < date } else { return false }
            }
        )
        for entity in try context.fetch(descriptor) {
            try deleteRevisions(for: entity.id)
            try deletePhotos(for: entity.id)
            context.delete(entity)
        }
        try context.save()
    }

    public func deleteEverything() throws {
        try context.delete(model: NoteEntity.self)
        try context.delete(model: FolderEntity.self)
        try context.delete(model: RevisionEntity.self)
        try context.delete(model: PhotoEntity.self)
        try context.save()
    }

    // MARK: History

    public func revisions(for noteID: UUID) throws -> [NoteRevision] {
        let descriptor = FetchDescriptor<RevisionEntity>(
            predicate: #Predicate { $0.noteID == noteID },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.domain)
    }

    public func record(_ revision: NoteRevision) throws {
        context.insert(RevisionEntity(revision: revision))
        try trimRevisions(for: revision.noteID)
        try context.save()
    }

    public func deleteRevisions(for noteID: UUID) throws {
        let descriptor = FetchDescriptor<RevisionEntity>(predicate: #Predicate { $0.noteID == noteID })
        for entity in try context.fetch(descriptor) { context.delete(entity) }
        try context.save()
    }

    /// Keeps the newest `RevisionPolicy.limit` and drops the rest.
    private func trimRevisions(for noteID: UUID) throws {
        let descriptor = FetchDescriptor<RevisionEntity>(
            predicate: #Predicate { $0.noteID == noteID },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        guard all.count > RevisionPolicy.limit else { return }
        for entity in all.dropFirst(RevisionPolicy.limit) { context.delete(entity) }
    }

    // MARK: Lookups

    private func attachPhotos(to entities: [NoteEntity]) throws -> [Note] {
        let descriptors = FetchDescriptor<PhotoEntity>(sortBy: [SortDescriptor(\.sortIndex)])
        let byNote = Dictionary(grouping: try context.fetch(descriptors), by: \.noteID)
        return entities.map { entity in
            var note = entity.domain
            note.photos = (byNote[entity.id] ?? []).map(\.domain)
            return note
        }
    }

    private func photos(for noteID: UUID) throws -> [PhotoEntity] {
        let descriptor = FetchDescriptor<PhotoEntity>(predicate: #Predicate { $0.noteID == noteID })
        return try context.fetch(descriptor)
    }

    private func deletePhotos(for noteID: UUID) throws {
        for photo in try photos(for: noteID) { context.delete(photo) }
    }

    private func folderEntity(_ id: UUID) throws -> FolderEntity? {
        var descriptor = FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func noteEntity(_ id: UUID) throws -> NoteEntity? {
        var descriptor = FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func noteEntities(inFolder id: UUID) throws -> [NoteEntity] {
        let descriptor = FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.folderID == id })
        return try context.fetch(descriptor)
    }
}
