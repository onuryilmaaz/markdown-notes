import Foundation
import SwiftData
import PlainDomain

/// Version 1 of the library's shape, frozen.
///
/// The models live inside the version rather than beside it so that the day a
/// field is renamed, split or retyped, the old shape still exists in code for a
/// migration to read. Everything else addresses them through the type aliases
/// below, so the app never names a version.
public enum PlainSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [FolderEntity.self, NoteEntity.self, RevisionEntity.self]
    }

    @Model
    public final class FolderEntity {
        public var id: UUID = UUID()
        public var name: String = ""
        public var createdAt: Date = Date.now
        public var sortIndex: Int = 0

        public init(id: UUID = UUID(), name: String, createdAt: Date = .now, sortIndex: Int = 0) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.sortIndex = sortIndex
        }

        var domain: Folder {
            Folder(id: id, name: name, createdAt: createdAt, sortIndex: sortIndex)
        }
    }

    @Model
    public final class RevisionEntity {
        public var id: UUID = UUID()
        public var noteID: UUID = UUID()
        public var title: String = ""
        public var body: String = ""
        public var savedAt: Date = Date.now

        public init(revision: NoteRevision) {
            id = revision.id
            noteID = revision.noteID
            title = revision.title
            body = revision.body
            savedAt = revision.savedAt
        }

        var domain: NoteRevision {
            NoteRevision(id: id, noteID: noteID, title: title, body: body, savedAt: savedAt)
        }
    }

    @Model
    public final class NoteEntity {
        public var id: UUID = UUID()
        public var title: String = ""
        public var body: String = ""
        public var folderID: UUID?
        public var tags: [String] = []
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isPinned: Bool = false
        public var isLocked: Bool = false
        public var deletedAt: Date?

        public var liveID: UUID?
        public var liveStartedAt: Date?
        public var liveExpiresAt: Date?

        public init(note: Note) {
            apply(note)
        }

        func apply(_ note: Note) {
            id = note.id
            title = note.title
            body = note.body
            folderID = note.folderID
            tags = note.tags
            createdAt = note.createdAt
            updatedAt = note.updatedAt
            isPinned = note.isPinned
            isLocked = note.isLocked
            deletedAt = note.deletedAt
            liveID = note.live?.id
            liveStartedAt = note.live?.startedAt
            liveExpiresAt = note.live?.expiresAt
        }

        var domain: Note {
            let live: LiveSession? = {
                guard let liveID, let liveStartedAt, let liveExpiresAt else { return nil }
                return LiveSession(id: liveID, startedAt: liveStartedAt, expiresAt: liveExpiresAt)
            }()
            return Note(
                id: id,
                title: title,
                body: body,
                folderID: folderID,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                isLocked: isLocked,
                live: live,
                deletedAt: deletedAt
            )
        }
    }
}

// The shape the app is written against today. A version 2 would change these
// three lines and nothing else.
public typealias FolderEntity = PlainSchemaV1.FolderEntity
public typealias NoteEntity = PlainSchemaV1.NoteEntity
public typealias RevisionEntity = PlainSchemaV1.RevisionEntity

/// How the store gets from one version to the next.
///
/// There is one version so far and therefore no stage to run — but the plan is
/// registered with the container now, while the library on people's phones is
/// still small enough to be forgiving. A plan added after the fact cannot
/// rescue a store that has already been guessed at.
public enum PlainMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [PlainSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
