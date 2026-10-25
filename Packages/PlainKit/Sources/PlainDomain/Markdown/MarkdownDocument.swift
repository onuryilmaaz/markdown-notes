import Foundation

/// A block of a parsed markdown document. Deliberately small: the editor is the
/// source of truth, this is only what the rendered reading view needs to draw.
public enum MarkdownBlock: Hashable, Identifiable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case quote(String)
    case bullets([String])
    case tasks([TaskItem])
    case ordered([String])
    case code(String, language: String?)
    case table(header: [String], rows: [[String]])
    case photo(UUID)
    case divider

    public var id: Int { hashValue }
}

/// A `- [ ]` line. Carries the line it came from so tapping the box can edit
/// exactly that line of the source and leave the rest of the note alone.
public struct TaskItem: Hashable, Identifiable, Sendable {
    public let text: String
    public let isDone: Bool
    public let line: Int

    public init(text: String, isDone: Bool, line: Int) {
        self.text = text
        self.isDone = isDone
        self.line = line
    }

    public var id: Int { line }
}

public struct MarkdownDocument: Hashable, Sendable {
    public let blocks: [MarkdownBlock]

    public init(blocks: [MarkdownBlock]) { self.blocks = blocks }

    public init(parsing source: String) {
        self.blocks = MarkdownDocument.parse(source)
    }

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var tasks: [TaskItem] = []
        var ordered: [String] = []
        var quote: [String] = []
        var code: [String] = []
        var inFence = false
        var fenceLanguage: String?
        var table: [[String]] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
        func flushBullets() {
            guard !bullets.isEmpty else { return }
            blocks.append(.bullets(bullets))
            bullets.removeAll()
        }
        func flushTasks() {
            guard !tasks.isEmpty else { return }
            blocks.append(.tasks(tasks))
            tasks.removeAll()
        }
        func flushOrdered() {
            guard !ordered.isEmpty else { return }
            blocks.append(.ordered(ordered))
            ordered.removeAll()
        }
        func flushQuote() {
            guard !quote.isEmpty else { return }
            blocks.append(.quote(quote.joined(separator: " ")))
            quote.removeAll()
        }
        func flushTable() {
            guard !table.isEmpty else { return }
            // A one-line table is just a line with pipes in it.
            if table.count > 1 {
                blocks.append(.table(header: table[0], rows: Array(table.dropFirst())))
            } else {
                blocks.append(.paragraph(table[0].joined(separator: " | ")))
            }
            table.removeAll()
        }
        func flushAll() {
            flushParagraph(); flushBullets(); flushTasks(); flushOrdered(); flushQuote(); flushTable()
        }

        for (index, rawLine) in source.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inFence {
                    blocks.append(.code(code.joined(separator: "\n"), language: fenceLanguage))
                    code.removeAll()
                    fenceLanguage = nil
                    inFence = false
                } else {
                    flushAll()
                    let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    fenceLanguage = language.isEmpty ? nil : language
                    inFence = true
                }
                continue
            }
            if inFence {
                code.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushAll()
                continue
            }
            if let photo = PhotoMarkdown.id(inLine: line) {
                flushAll()
                blocks.append(.photo(photo))
                continue
            }
            if line == "---" || line == "***" {
                flushAll()
                blocks.append(.divider)
                continue
            }
            // A heading needs a space after the hashes, otherwise `#spec` — a
            // tag — would be read as a title.
            if line.hasPrefix("#"), let heading = heading(in: line) {
                flushAll()
                blocks.append(heading)
                continue
            }
            if let cells = tableRow(in: line) {
                flushParagraph(); flushBullets(); flushTasks(); flushOrdered(); flushQuote()
                // The `| --- |` rule under the header carries no content.
                if !isTableSeparator(cells) { table.append(cells) }
                continue
            }
            if let task = taskItem(in: line, at: index) {
                flushParagraph(); flushBullets(); flushOrdered(); flushQuote()
                tasks.append(task)
                continue
            }
            if line.hasPrefix(">") {
                flushParagraph(); flushBullets(); flushTasks(); flushOrdered()
                quote.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph(); flushTasks(); flushOrdered(); flushQuote()
                bullets.append(String(line.dropFirst(2)))
                continue
            }
            if let item = orderedItem(in: line) {
                flushParagraph(); flushBullets(); flushTasks(); flushQuote()
                ordered.append(item)
                continue
            }
            flushBullets(); flushTasks(); flushOrdered(); flushQuote(); flushTable()
            paragraph.append(line)
        }

        if inFence, !code.isEmpty { blocks.append(.code(code.joined(separator: "\n"), language: fenceLanguage)) }
        flushAll()
        return blocks
    }

    private static func heading(in line: String) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes <= 3, line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        let text = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(level: hashes, text: text)
    }

    private static func tableRow(in line: String) -> [String]? {
        guard line.hasPrefix("|"), line.count > 1 else { return nil }
        var trimmed = line.dropFirst()
        if trimmed.hasSuffix("|") { trimmed = trimmed.dropLast() }
        let cells = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.isEmpty ? nil : cells
    }

    private static func isTableSeparator(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
        }
    }

    private static func taskItem(in line: String, at index: Int) -> TaskItem? {
        guard line.hasPrefix("- [") || line.hasPrefix("* [") else { return nil }
        let marker = line.dropFirst(2)
        // An empty box — `- [ ]` with nothing after it — is a task too; it is
        // what every checklist starts life as.
        guard marker.count >= 3 else { return nil }
        let box = marker.prefix(3)
        guard box.hasPrefix("["), box.hasSuffix("]") else { return nil }
        let state = box.dropFirst().first
        let isDone: Bool
        switch state {
        case " ": isDone = false
        case "x", "X": isDone = true
        default: return nil
        }
        let text = marker.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return TaskItem(text: text, isDone: isDone, line: index)
    }

    private static func orderedItem(in line: String) -> String? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return String(rest.dropFirst(2))
    }
}

/// Helpers for turning markdown into readable plain text.
public enum MarkdownText {
    public static func stripped(_ source: String) -> String {
        var text = source
        // Only strip pair markers — a lone `_` or `*` is usually part of an
        // identifier such as note_shares.
        for token in ["**", "__", "`"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        if text.hasPrefix("- ") || text.hasPrefix("* ") { text.removeFirst(2) }
        for box in ["[ ] ", "[x] ", "[X] "] where text.hasPrefix(box) { text.removeFirst(box.count) }
        while text.hasPrefix("#") || text.hasPrefix(">") { text.removeFirst() }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// The first heading of a document, used to keep a note's title in sync with its body.
    public static func firstHeading(in source: String) -> String? {
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }
            let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }
        return nil
    }

    /// Cleans a comma- or newline-separated list of words into tags the app
    /// would have produced itself.
    public static func tags(fromList source: String) -> [String] {
        source
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { piece in
                piece.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            }
            .filter { $0.count > 1 }
            .reduce(into: [String]()) { found, tag in
                if !found.contains(tag) { found.append(tag) }
            }
    }

    /// Flips one `- [ ]` line without disturbing the rest of the note.
    public static func toggledTask(atLine index: Int, in source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        guard lines.indices.contains(index) else { return source }
        let line = lines[index]
        if let range = line.range(of: "[ ]") {
            lines[index] = line.replacingCharacters(in: range, with: "[x]")
        } else if let range = line.range(of: "[x]", options: .caseInsensitive) {
            lines[index] = line.replacingCharacters(in: range, with: "[ ]")
        }
        return lines.joined(separator: "\n")
    }

    /// True when a line carries nothing but tags — rendered as chips, not prose.
    public static func isTagLine(_ source: String) -> Bool {
        let words = source.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return false }
        return words.allSatisfy { $0.hasPrefix("#") && $0.count > 1 }
    }

    /// Inline `#tags` found in the body, lowercased and de-duplicated in order.
    public static func tags(in source: String) -> [String] {
        var found: [String] = []
        for word in source.split(whereSeparator: { $0.isWhitespace }) {
            guard word.hasPrefix("#"), word.count > 1 else { continue }
            let name = word.dropFirst().lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
            guard !name.isEmpty, !found.contains(name) else { continue }
            found.append(name)
        }
        return found
    }
}
