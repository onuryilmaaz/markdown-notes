import Foundation
import Observation
import PlainDomain
import PlainPersistence

/// Where an intent or extension finds the library. Uses the running app's own
/// store when there is one, so Shortcuts edits show up on screen immediately,
/// and opens its own only when the app is not in memory.
@MainActor
enum IntentLibrary {
    private static var standalone: NoteRepository?

    /// Set by the app while it is running.
    static weak var liveStore: NotesStore?

    private static var repository: NoteRepository {
        if let standalone { return standalone }
        let created = SwiftDataNoteRepository(container: PlainStore.makeContainer())
        standalone = created
        return created
    }

    static func notes() -> [Note] {
        if let liveStore { return liveStore.notes }
        return (try? repository.loadNotes()) ?? []
    }

    static func search(_ term: String) -> [Note] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return notes().filter { $0.matches(trimmed) }
    }

    @discardableResult
    static func create(from text: String) throws -> Note {
        let note = NoteExchange.note(fromPastedText: text) ?? Note(title: "Untitled", body: text)
        try save(note)
        return note
    }

    @discardableResult
    static func append(_ text: String, to id: UUID) throws -> Note {
        guard var note = notes().first(where: { $0.id == id }) else {
            throw IntentLibraryError.noteNotFound
        }
        let body = note.body.hasSuffix("\n") || note.body.isEmpty ? note.body : note.body + "\n"
        note.body = body + NoteExchange.normalise(text) + "\n"
        note.updatedAt = .now
        try save(note)
        return note
    }

    private static func save(_ note: Note) throws {
        if let liveStore {
            liveStore.update(note)
        } else {
            try repository.save(note)
        }
    }
}

enum IntentLibraryError: Error, LocalizedError {
    case noteNotFound

    var errorDescription: String? {
        switch self {
        case .noteNotFound: "That note is no longer in Plain."
        }
    }
}

/// A link waiting for the app's window to pick it up — set by an intent before
/// the app is brought to the front.
@MainActor
@Observable
final class PendingLink {
    static let shared = PendingLink()
    var link: DeepLink?
}
