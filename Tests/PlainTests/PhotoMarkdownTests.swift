import Testing
import Foundation
@testable import PlainDomain

@Suite("Photos placed in the text")
struct PhotoMarkdownTests {
    private let id = UUID()

    @Test("A photo line round trips, and only a whole line counts")
    func lines() {
        let line = PhotoMarkdown.line(for: id)
        #expect(PhotoMarkdown.id(inLine: line) == id)
        #expect(PhotoMarkdown.id(inLine: "  \(line) ") == id)
        #expect(PhotoMarkdown.id(inLine: "![a cat](photo:\(id.uuidString))") == id)
        #expect(PhotoMarkdown.id(inLine: "Look: \(line)") == nil)
        #expect(PhotoMarkdown.id(inLine: "![](photo:not-an-id)") == nil)
        #expect(PhotoMarkdown.id(inLine: "![](https://example.com/a.jpg)") == nil)
    }

    @Test("The reading view gets a photo block where the line is")
    func parsing() {
        let body = "# Trip\n\nBefore.\n\(PhotoMarkdown.line(for: id))\nAfter."
        #expect(MarkdownDocument(parsing: body).blocks == [
            .heading(level: 1, text: "Trip"),
            .paragraph("Before."),
            .photo(id),
            .paragraph("After.")
        ])
    }

    @Test("A photo line is not prose: no preview, no words")
    func preview() {
        let note = Note(title: "Trip", body: "# Trip\n\(PhotoMarkdown.line(for: id))\n\nTwo words")
        #expect(note.preview == "Two words")
        #expect(note.wordCount == 4)
    }

    @Test("Removing a photo takes its line and nothing else")
    func removing() {
        let other = UUID()
        let body = "One\n\(PhotoMarkdown.line(for: id))\nTwo\n\(PhotoMarkdown.line(for: other))"
        #expect(PhotoMarkdown.removing(id, from: body) == "One\nTwo\n\(PhotoMarkdown.line(for: other))")
        #expect(PhotoMarkdown.placedIDs(in: body) == [id, other])
    }

    @Test("Only photos the text does not place are left over")
    func unplaced() {
        let placed = NotePhoto(id: id, thumbnail: Data([1]), pixelWidth: 4, pixelHeight: 3)
        let loose = NotePhoto(thumbnail: Data([2]), pixelWidth: 4, pixelHeight: 3)
        let note = Note(title: "Trip", body: PhotoMarkdown.line(for: id), photos: [placed, loose])
        #expect(note.unplacedPhotos == [loose])
    }

    @Test("Export points placed photos at their files and appends the rest")
    func export() {
        let placed = NotePhoto(id: id, thumbnail: Data([1]), pixelWidth: 4, pixelHeight: 3)
        let loose = NotePhoto(thumbnail: Data([2]), pixelWidth: 4, pixelHeight: 3)
        let gone = UUID()
        let note = Note(
            title: "Trip",
            body: "# Trip\n\nBefore.\n\(PhotoMarkdown.line(for: id))\n\(PhotoMarkdown.line(for: gone))\nAfter.",
            photos: [placed, loose]
        )
        let markdown = NoteExchange.markdown(for: note)
        let placedPath = NoteExchange.photoPath(placed, in: note.id)
        let loosePath = NoteExchange.photoPath(loose, in: note.id)
        #expect(markdown.contains("Before.\n![Photo](\(placedPath))\n\nAfter."))
        #expect(markdown.hasSuffix("\n![Photo](\(loosePath))\n"))
        #expect(!markdown.contains("photo:"))
    }
}
