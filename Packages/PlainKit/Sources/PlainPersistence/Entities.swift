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

// Photo support reuses the unchanged version 1 note/folder/revision shapes.
public typealias FolderEntity = PlainSchemaV1.FolderEntity
public typealias NoteEntity = PlainSchemaV1.NoteEntity
public typealias RevisionEntity = PlainSchemaV1.RevisionEntity

/// Version 1 entities stay unchanged; version 2 adds independent photo records.
/// Keeping the binary outside the note avoids rewriting it on every keystroke.
public enum PlainSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        PlainSchemaV1.models + [PhotoEntity.self]
    }

    @Model
    public final class PhotoEntity {
        public var id: UUID = UUID()
        public var noteID: UUID = UUID()
        public var thumbnail: Data = Data()
        @Attribute(.externalStorage) public var jpegData: Data = Data()
        public var pixelWidth: Int = 0
        public var pixelHeight: Int = 0
        public var createdAt: Date = Date.now
        public var sortIndex: Int = 0

        public init(photo: NotePhoto, jpegData: Data, noteID: UUID, sortIndex: Int) {
            id = photo.id
            self.noteID = noteID
            thumbnail = photo.thumbnail
            self.jpegData = jpegData
            pixelWidth = photo.pixelWidth
            pixelHeight = photo.pixelHeight
            createdAt = photo.createdAt
            self.sortIndex = sortIndex
        }

        var domain: NotePhoto {
            NotePhoto(id: id, thumbnail: thumbnail, pixelWidth: pixelWidth, pixelHeight: pixelHeight, createdAt: createdAt)
        }
    }
}

public typealias PhotoEntity = PlainSchemaV2.PhotoEntity

/// How the store gets from one version to the next.
///
/// Version 2 adds photo records without changing existing note entities.
public enum PlainMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [PlainSchemaV1.self, PlainSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PlainSchemaV1.self, toVersion: PlainSchemaV2.self)]
    }
}
