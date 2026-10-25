import Foundation

public struct SearchHit: Identifiable, Hashable, Sendable {
    public let note: Note
    public let snippet: String
    /// Range of the matched term inside `snippet`, for the highlight chip.
    public let highlight: Range<String.Index>?

    public var id: UUID { note.id }
}

public enum SearchScope: Hashable, Sendable {
    case all
    case tag(String)
    case folder(UUID)
}

/// Pure ranking + snippet extraction. No storage, no UI — trivially testable.
public enum SearchEngine {
    public static func hits(for term: String, in notes: [Note], scope: SearchScope = .all, folderName: (UUID) -> String? = { _ in nil }) -> [SearchHit] {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        let scoped = notes.filter { note in
            switch scope {
            case .all: true
            case .tag(let tag): note.tags.contains(tag)
            case .folder(let id): note.folderID == id
            }
        }

        return scoped
            .filter { $0.matches(query) }
            .sorted { lhs, rhs in
                let l = rank(lhs, query: query), r = rank(rhs, query: query)
                return l == r ? lhs.updatedAt > rhs.updatedAt : l < r
            }
            .map { note in
                let snippet = snippet(for: query, in: note)
                return SearchHit(
                    note: note,
                    snippet: snippet,
                    highlight: snippet.range(of: query, options: .caseInsensitive)
                )
            }
    }

    /// Chip counts shown above the results — All / per tag / per folder.
    public static func rank(_ note: Note, query: String) -> Int {
        if note.title.localizedCaseInsensitiveContains(query) { return 0 }
        if note.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return 1 }
        return 2
    }

    static func snippet(for query: String, in note: Note) -> String {
        // The title is already above the snippet — start from the prose.
        let body = note.body
            .components(separatedBy: .newlines)
            .drop { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty || trimmed.hasPrefix("# ")
            }
            .joined(separator: " ")
        let flat = MarkdownText.stripped(body)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        guard let range = flat.range(of: query, options: .caseInsensitive) else {
            return String(flat.prefix(90))
        }
        let start = flat.index(range.lowerBound, offsetBy: -32, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(range.upperBound, offsetBy: 58, limitedBy: flat.endIndex) ?? flat.endIndex
        var snippet = String(flat[start..<end]).trimmingCharacters(in: .whitespaces)
        if start != flat.startIndex { snippet = "…" + snippet }
        if end != flat.endIndex { snippet += "…" }
        return snippet
    }
}
