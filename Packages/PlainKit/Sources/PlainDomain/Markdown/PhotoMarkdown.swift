import Foundation

/// Where a photo sits in a note is written into the body itself, as a line of
/// its own: `![](photo:<id>)`. Moving the line moves the photo, and the note
/// stays plain markdown that any editor can read.
public enum PhotoMarkdown {
    public static let scheme = "photo"

    public static func line(for id: UUID) -> String {
        "![](\(scheme):\(id.uuidString))"
    }

    /// The photo a line places, when the whole line is nothing but that.
    public static func id(inLine line: some StringProtocol) -> UUID? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("!["), trimmed.hasSuffix(")"),
              let open = trimmed.range(of: "](\(scheme):") else { return nil }
        // Alt text, if someone wrote one, cannot hold a closing bracket.
        guard !trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<open.lowerBound].contains("]") else { return nil }
        return UUID(uuidString: String(trimmed[open.upperBound..<trimmed.index(before: trimmed.endIndex)]))
    }

    public static func isPhotoLine(_ line: some StringProtocol) -> Bool {
        id(inLine: line) != nil
    }

    /// Photos placed in the body, in reading order.
    public static func placedIDs(in body: String) -> [UUID] {
        body.split(separator: "\n", omittingEmptySubsequences: true).compactMap { id(inLine: $0) }
    }

    /// The body without the lines that place `id`.
    public static func removing(_ id: UUID, from body: String) -> String {
        guard body.contains(id.uuidString) else { return body }
        return body.components(separatedBy: "\n")
            .filter { self.id(inLine: $0) != id }
            .joined(separator: "\n")
    }

    /// The body with every photo line gone — for text that is read, not shown.
    public static func strippingPhotos(from body: String) -> String {
        guard body.contains("](\(scheme):") else { return body }
        return body.components(separatedBy: "\n")
            .filter { !isPhotoLine($0) }
            .joined(separator: "\n")
    }
}

public extension Note {
    /// Photos the body does not place yet; they are shown as a strip instead.
    var unplacedPhotos: [NotePhoto] {
        let placed = Set(PhotoMarkdown.placedIDs(in: body))
        return photos.filter { !placed.contains($0.id) }
    }
}
