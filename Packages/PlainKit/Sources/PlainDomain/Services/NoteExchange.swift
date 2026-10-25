import Foundation

/// Markdown in, markdown out. A note is a file: no proprietary wrapper, so a
/// library can leave this app as easily as it arrived.
public enum NoteExchange {
    public static let fileExtension = "md"

    /// The note as it should land on disk — the body, with a heading added only
    /// when the body does not already open with one.
    public static func markdown(for note: Note) -> String {
        let body = exportingPhotoLines(of: note).trimmingCharacters(in: .whitespacesAndNewlines)
        let text: String
        if MarkdownText.firstHeading(in: body) != nil || body.isEmpty {
            text = body.isEmpty ? "# \(note.title)\n" : body + "\n"
        } else {
            text = "# \(note.title)\n\n\(body)\n"
        }
        // Photos the body does not place go at the end, as before.
        return text + note.unplacedPhotos.map { "\n![Photo](\(photoPath($0, in: note.id)))\n" }.joined()
    }

    /// Placed photos point at the exported file instead of the app's own id.
    private static func exportingPhotoLines(of note: Note) -> String {
        let photos = Dictionary(note.photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return note.body.components(separatedBy: "\n").map { line in
            guard let id = PhotoMarkdown.id(inLine: line) else { return line }
            guard let photo = photos[id] else { return "" }
            return "![Photo](\(photoPath(photo, in: note.id)))"
        }
        .joined(separator: "\n")
    }

    public static func photoPath(_ photo: NotePhoto, in noteID: UUID) -> String {
        "attachments/\(noteID.uuidString)/\(photo.fileName)"
    }

    /// A file name that survives every file system: no slashes, no colons, not
    /// endless, and never empty.
    public static func fileName(for note: Note, existing: Set<String> = []) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        var stem = note.title
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stem.isEmpty { stem = "Untitled" }
        if stem.count > 80 { stem = String(stem.prefix(80)).trimmingCharacters(in: .whitespaces) }

        var candidate = "\(stem).\(fileExtension)"
        var suffix = 2
        while existing.contains(candidate.lowercased()) {
            candidate = "\(stem) \(suffix).\(fileExtension)"
            suffix += 1
        }
        return candidate
    }

    /// Turns an imported file into a note. The file name is the fallback title
    /// for a document that does not carry a heading of its own.
    public static func note(fromFileNamed name: String, contents: String, folderID: UUID? = nil) -> Note {
        let body = normalise(contents)
        let stem = (name as NSString).deletingPathExtension
        let title = MarkdownText.firstHeading(in: body)
            ?? stem.trimmingCharacters(in: .whitespacesAndNewlines)
        return Note(
            title: title.isEmpty ? "Untitled" : title,
            body: body,
            folderID: folderID,
            tags: MarkdownText.tags(in: body)
        )
    }

    /// Pasted or imported text, as a note.
    public static func note(fromPastedText text: String, folderID: UUID? = nil) -> Note? {
        let body = normalise(text)
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let title = MarkdownText.firstHeading(in: body)
            ?? body.components(separatedBy: "\n").first.map(MarkdownText.stripped)
            ?? "Untitled"
        return Note(
            title: title.isEmpty ? "Untitled" : String(title.prefix(120)),
            body: body,
            folderID: folderID,
            tags: MarkdownText.tags(in: body)
        )
    }

    /// Windows and classic-Mac line endings would otherwise break line-indexed
    /// features such as task toggling.
    public static func normalise(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
