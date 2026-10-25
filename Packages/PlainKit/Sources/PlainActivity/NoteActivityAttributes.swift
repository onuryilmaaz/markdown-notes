import Foundation
import ActivityKit

/// Shared between the app (which starts the activity) and the widget extension
/// (which draws it on the Lock Screen and in the Dynamic Island).
public struct NoteActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var excerpt: String
        public var startedAt: Date
        public var expiresAt: Date

        public init(excerpt: String, startedAt: Date, expiresAt: Date) {
            self.excerpt = excerpt
            self.startedAt = startedAt
            self.expiresAt = expiresAt
        }

        public var range: ClosedRange<Date> { startedAt...max(expiresAt, startedAt.addingTimeInterval(1)) }
    }

    public var noteID: UUID
    public var title: String

    public init(noteID: UUID, title: String) {
        self.noteID = noteID
        self.title = title
    }
}
