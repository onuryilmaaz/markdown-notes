import Foundation

/// A markdown note. The single aggregate the whole app revolves around.
public struct Note: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var folderID: UUID?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    /// Hidden behind Face ID until the reader proves who they are.
    public var isLocked: Bool
    public var live: LiveSession?
    /// Set when the note is in the trash. Nil for a live note.
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String = "",
        folderID: UUID? = nil,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        isLocked: Bool = false,
        live: LiveSession? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderID = folderID
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.live = live
        self.deletedAt = deletedAt
    }
}

public extension Note {
    /// Plain-text first paragraph, markdown syntax stripped — used on list cards.
    var preview: String {
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            return MarkdownText.stripped(trimmed)
        }
        return ""
    }

    var wordCount: Int {
        body.split(whereSeparator: { $0 == " " || $0.isNewline }).count
    }

    func isLive(at date: Date = .now) -> Bool {
        live?.isActive(at: date) ?? false
    }

    /// A note answers to a search when its title, body or tags contain the term.
    func matches(_ term: String) -> Bool {
        guard !term.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(term)
            || body.localizedCaseInsensitiveContains(term)
            || tags.contains { $0.localizedCaseInsensitiveContains(term) }
    }
}
