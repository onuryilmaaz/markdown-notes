import Foundation

/// Storage contract. The app talks to this; SwiftData lives behind it.
@MainActor
public protocol NoteRepository: AnyObject {
    func loadFolders() throws -> [Folder]
    /// Everything that is not in the trash.
    func loadNotes() throws -> [Note]
    func loadDeletedNotes() throws -> [Note]

    @discardableResult
    func createFolder(named name: String) throws -> Folder
    func renameFolder(id: UUID, to name: String) throws
    func deleteFolder(id: UUID) throws

    func save(_ note: Note) throws
    /// Moves notes to the trash; `purge` is what actually destroys them.
    func delete(noteIDs: Set<UUID>) throws
    func restore(noteIDs: Set<UUID>) throws
    func purge(noteIDs: Set<UUID>) throws
    func purgeDeleted(before date: Date) throws
    func deleteEverything() throws

    // MARK: History
    func revisions(for noteID: UUID) throws -> [NoteRevision]
    func record(_ revision: NoteRevision) throws
    func deleteRevisions(for noteID: UUID) throws
}
