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
    static func markdownFile(for note: Note) throws -> URL {
        let directory = try scratchDirectory()
        let url = directory.appendingPathComponent(NoteExchange.fileName(for: note))
        try NoteExchange.markdown(for: note).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// The whole library, foldered exactly as it is in the app.
    static func archive(notes: [Note], folderName: (UUID?) -> String) throws -> URL {
        let staging = try scratchDirectory().appendingPathComponent("Plain Library", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        var used: [String: Set<String>] = [:]
        for note in notes {
            let folder = note.folderID.map { _ in folderName(note.folderID) } ?? "All Notes"
            let directory = staging.appendingPathComponent(safe(folder), isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let name = NoteExchange.fileName(for: note, existing: used[folder] ?? [])
            used[folder, default: []].insert(name.lowercased())
            try NoteExchange.markdown(for: note)
                .write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return try zip(staging)
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
        return trimmed.isEmpty ? "Notes" : trimmed
    }
}

/// Paginated PDF of a note's reading view — the same layout people see, cut
/// into pages instead of one endless strip.
@MainActor
enum NotePDF {
    static let pageSize = CGSize(width: 595, height: 842)   // A4 at 72dpi
    private static let margin: CGFloat = 48

    static func file(for note: Note, bodySize: CGFloat) throws -> URL {
        let contentWidth = pageSize.width - margin * 2
        let renderer = ImageRenderer(
            content: MarkdownRenderedView(document: MarkdownDocument(parsing: note.body), bodySize: bodySize)
                .frame(width: contentWidth, alignment: .leading)
                .padding(.vertical, 2)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2

        guard let image = renderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\((note.title as NSString).deletingPathExtension).pdf")

        let contentHeight = pageSize.height - margin * 2
        let pages = max(Int(ceil(image.size.height / contentHeight)), 1)

        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize)).writePDF(to: url) { context in
            for page in 0..<pages {
                context.beginPage()
                let offset = CGFloat(page) * contentHeight
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pageSize))
                // Clip to the printable area, then slide the full-height image
                // up so this page shows its own slice.
                context.cgContext.saveGState()
                context.cgContext.clip(to: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
                image.draw(in: CGRect(x: margin, y: margin - offset, width: image.size.width, height: image.size.height))
                context.cgContext.restoreGState()
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
