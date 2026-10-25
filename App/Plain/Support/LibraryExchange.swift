import SwiftUI
import UniformTypeIdentifiers
import PlainDomain

/// Getting notes out of the app: one markdown file, one PDF, or the whole
/// library as a zip of markdown files. Nothing here invents a format — what
/// comes out is what another editor can open.
enum LibraryExchange {
    static let importableTypes: [UTType] = [
        .plainText,
        UTType(filenameExtension: "md") ?? .plainText,
        UTType(filenameExtension: "markdown") ?? .plainText,
        UTType(filenameExtension: "txt") ?? .plainText
    ]

    /// A single note as a `.md` file in a fresh temporary directory, so two
    /// exports never collide over a file name.
    static func markdownFile(for note: Note, photoData: (UUID) -> Data? = { _ in nil }) throws -> URL {
        let directory = try scratchDirectory()
        let url = directory.appendingPathComponent(NoteExchange.fileName(for: note))
        try write(note, named: url.lastPathComponent, to: directory, photoData: photoData)
        return note.photos.isEmpty ? url : try zip(directory)
    }

    /// The whole library, foldered exactly as it is in the app.
    static func archive(notes: [Note], folderName: (UUID?) -> String, photoData: (UUID) -> Data? = { _ in nil }) throws -> URL {
        let staging = try scratchDirectory().appendingPathComponent("Plain Library", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        var used: [String: Set<String>] = [:]
        for note in notes {
            let folder = note.folderID.map { _ in folderName(note.folderID) } ?? "All Notes"
            let directory = staging.appendingPathComponent(safe(folder), isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Distinct names such as A/B and A:B can sanitize to the same
            // directory. Track the actual destination to preserve both notes.
            let destination = directory.standardizedFileURL.path.precomposedStringWithCanonicalMapping.lowercased()
            let name = NoteExchange.fileName(for: note, existing: used[destination] ?? [])
            used[destination, default: []].insert(name.lowercased())
            try write(note, named: name, to: directory, photoData: photoData)
        }
        return try zip(staging)
    }

    private static func write(_ note: Note, named name: String, to directory: URL, photoData: (UUID) -> Data?) throws {
        for photo in note.photos {
            guard let data = photoData(photo.id) else { throw CocoaError(.fileReadNoSuchFile) }
            let url = directory.appendingPathComponent(NoteExchange.photoPath(photo, in: note.id))
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        try NoteExchange.markdown(for: note).write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// `NSFileCoordinator` will hand back a zip of a directory; the copy has to
    /// happen inside the block, because the original is cleaned up after it.
    private static func zip(_ directory: URL) throws -> URL {
        let destination = try scratchDirectory().appendingPathComponent("Plain Library.zip")
        var coordinatorError: NSError?
        var copyError: Error?

        NSFileCoordinator().coordinate(readingItemAt: directory, options: [.forUploading], error: &coordinatorError) { zipped in
            do {
                try FileManager.default.copyItem(at: zipped, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        return destination
    }

    /// Reads files the document picker handed over. Security-scoped because
    /// they live outside the app's container.
    static func notes(from urls: [URL], folderID: UUID?) -> [Note] {
        urls.compactMap { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return NoteExchange.note(fromFileNamed: url.lastPathComponent, contents: contents, folderID: folderID)
        }
    }

    private static func scratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func safe(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: " ")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "." || trimmed == ".." ? "Notes" : trimmed
    }
}

/// Paginated PDF of a note's reading view — the same layout people see. Each
/// block is drawn on its own and moved to the next page whole when it does not
/// fit, so a photo or a line of text is never cut in two at a page edge.
@MainActor
enum NotePDF {
    static let pageSize = CGSize(width: 595, height: 842)   // A4 at 72dpi
    private static let margin: CGFloat = 48
    /// The reading view's own gap between blocks.
    private static let blockSpacing: CGFloat = 14

    static func file(for note: Note, bodySize: CGFloat, photoData: @escaping (UUID) -> Data? = { _ in nil }) throws -> URL {
        let contentWidth = pageSize.width - margin * 2
        let contentHeight = pageSize.height - margin * 2

        let blocks = try MarkdownDocument(parsing: note.body).blocks.map { block -> UIImage in
            let renderer = ImageRenderer(
                content: MarkdownRenderedView(
                    document: MarkdownDocument(blocks: [block]),
                    bodySize: bodySize,
                    photos: note.photos,
                    photoData: photoData
                )
                .frame(width: contentWidth, alignment: .leading)
                .padding(.vertical, 2)
                .environment(\.colorScheme, .light)
            )
            renderer.scale = 2
            guard let image = renderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
            return image
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\((NoteExchange.fileName(for: note) as NSString).deletingPathExtension).pdf")

        // Photos the text does not place still get a page each at the end.
        let photoBytes = try note.unplacedPhotos.map { photo -> Data in
            guard let data = photoData(photo.id), UIImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }
            return data
        }

        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize)).writePDF(to: url) { context in
            var y: CGFloat = 0
            func newPage() {
                context.beginPage()
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pageSize))
                y = 0
            }
            newPage()
            for image in blocks where image.size.height > 0 {
                if y > 0, y + image.size.height > contentHeight { newPage() }
                // Only a block taller than a whole page is sliced across pages.
                var shown: CGFloat = 0
                while true {
                    let slice = min(image.size.height - shown, contentHeight - y)
                    context.cgContext.saveGState()
                    context.cgContext.clip(to: CGRect(x: margin, y: margin + y, width: contentWidth, height: slice))
                    image.draw(in: CGRect(x: margin, y: margin + y - shown, width: image.size.width, height: image.size.height))
                    context.cgContext.restoreGState()
                    shown += slice
                    y += slice
                    if shown >= image.size.height - 0.5 { break }
                    newPage()
                }
                y += blockSpacing
            }
            for data in photoBytes {
                autoreleasepool {
                    guard let photo = UIImage(data: data) else { return }
                    newPage()
                    let scale = min(contentWidth / photo.size.width, contentHeight / photo.size.height)
                    let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
                    photo.draw(in: CGRect(x: (pageSize.width - size.width) / 2, y: (pageSize.height - size.height) / 2, width: size.width, height: size.height))
                }
            }
        }
        return url
    }
}

/// A file on its way to the share sheet. Identifiable so it can drive a sheet
/// without making `URL` itself identifiable app-wide.
struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet, for a file we just wrote.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
