import Foundation

/// How a note list is ordered. Pinned notes always float to the top — that is
/// what pinning means — and the chosen order applies below them.
public enum NoteSort: String, CaseIterable, Identifiable, Sendable {
    case recentlyEdited
    case recentlyCreated
    case oldestFirst
    case title

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .recentlyEdited: "Last edited"
        case .recentlyCreated: "Date created"
        case .oldestFirst: "Oldest first"
        case .title: "Title"
        }
    }

    /// The line under a list's title, so the order is never a mystery.
    public var caption: String {
        switch self {
        case .recentlyEdited: "newest first"
        case .recentlyCreated: "newest created"
        case .oldestFirst: "oldest first"
        case .title: "by title"
        }
    }

    public func apply(to notes: [Note]) -> [Note] {
        notes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            switch self {
            case .recentlyEdited: return lhs.updatedAt > rhs.updatedAt
            case .recentlyCreated: return lhs.createdAt > rhs.createdAt
            case .oldestFirst: return lhs.createdAt < rhs.createdAt
            case .title: return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
