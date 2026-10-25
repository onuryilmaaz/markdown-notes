import Foundation

/// A past state of a note. Cheap insurance: the editor overwrites in place, so
/// without these an accidental select-all-and-type is unrecoverable.
public struct NoteRevision: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let noteID: UUID
    public let title: String
    public let body: String
    public let savedAt: Date

    public init(id: UUID = UUID(), noteID: UUID, title: String, body: String, savedAt: Date = .now) {
        self.id = id
        self.noteID = noteID
        self.title = title
        self.body = body
        self.savedAt = savedAt
    }

    public var wordCount: Int {
        body.split(whereSeparator: { $0 == " " || $0.isNewline }).count
    }
}

public enum RevisionPolicy {
    /// How many versions of one note are kept.
    public static let limit = 25

    /// Edits arrive a keystroke at a time; a revision every few minutes keeps
    /// the history readable instead of a log of single characters.
    public static let interval: TimeInterval = 5 * 60

    /// Decides whether the body about to be saved deserves a snapshot of what
    /// is being replaced.
    public static func shouldRecord(previous: String, next: String, lastSavedAt: Date?, now: Date = .now) -> Bool {
        guard previous != next else { return false }
        guard !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let lastSavedAt else { return true }
        if now.timeIntervalSince(lastSavedAt) >= interval { return true }
        // A big change is worth keeping even if the last snapshot is recent —
        // this is the select-all-and-delete case.
        return shrunkSharply(previous: previous, next: next)
    }

    static func shrunkSharply(previous: String, next: String) -> Bool {
        guard previous.count > 200 else { return false }
        return next.count < previous.count / 2
    }
}
