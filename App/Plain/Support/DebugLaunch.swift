#if DEBUG
import Foundation
import PlainDomain
import UIKit

/// Test seam: `PLAIN_ROUTE=note` opens the app straight on a screen, so UI
/// tests and screenshot runs do not have to drive the navigation by hand.
@MainActor
enum DebugLaunch {
    static func applyIfNeeded(store: NotesStore, router: Router, settings: AppSettings, liveActivities: LiveActivityController) {
        // UI tests share one installed app, so a run has to be able to start
        // from a known-empty library.
        if ProcessInfo.processInfo.environment["PLAIN_RESET"] != nil {
            store.deleteLibrary()
        }
        if ProcessInfo.processInfo.environment["PLAIN_SEED"] != nil, store.isEmpty {
            seed(store)
        }
        if ProcessInfo.processInfo.environment["PLAIN_SEED_PHOTO"] != nil,
           let note = store.notes.first, note.photos.isEmpty {
            seedPhoto(in: note.id, store: store, placed: ProcessInfo.processInfo.environment["PLAIN_SEED_PHOTO"] == "placed")
        }
        if let appearance = ProcessInfo.processInfo.environment["PLAIN_APPEARANCE"],
           let value = AppSettings.Appearance(rawValue: appearance) {
            settings.appearance = value
        }
        guard let value = ProcessInfo.processInfo.environment["PLAIN_ROUTE"] else { return }
        let folder = store.folders.first
        // PLAIN_NOTE_TITLE picks which note the note/editor routes open.
        let wanted = ProcessInfo.processInfo.environment["PLAIN_NOTE_TITLE"]
        let note = wanted.flatMap { title in store.notes.first { $0.title.localizedCaseInsensitiveContains(title) } }
            ?? store.notes.first
        let live = store.liveNotes.first ?? note

        switch value {
        case "folder": router.path = [.list(.folder(folder?.id))]
        case "empty":
            if let created = store.createFolder(named: "Reading list") {
                router.path = [.list(.folder(created.id))]
            }
        case "note":
            if let note { router.path = [.list(.folder(note.folderID)), .note(note.id)] }
        case "editor":
            if let note { router.path = [.editor(note.id)] }
        case "live":
            if let live {
                router.path = [.live(live.id)]
                if let session = live.live { liveActivities.start(note: live, session: session) }
            }
        case "compose":
            // The same path the "New note" pill takes.
            router.path = [.editor(store.createNote(in: folder?.id).id)]
        case "trash": router.path = [.trash]
        case "search": router.path = [.search]
        case "tags": router.path = [.tags]
        case "settings": router.path = [.settings]
        case "pro": router.sheet = .pro(nil)
        case "widgets": router.sheet = .widgets
        default: break
        }
    }
}
#endif


#if DEBUG
private extension DebugLaunch {
    /// `placed` also writes the photo into the text, after the first paragraph.
    static func seedPhoto(in noteID: UUID, store: NotesStore, placed: Bool) {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 650)).image { context in
            UIColor(red: 0.83, green: 0.87, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 650))
            UIColor(red: 0.98, green: 0.68, blue: 0.43, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 590, y: 90, width: 170, height: 170)).fill()
            UIColor(red: 0.38, green: 0.49, blue: 0.56, alpha: 1).setFill()
            let hill = UIBezierPath()
            hill.move(to: CGPoint(x: 0, y: 480))
            hill.addCurve(to: CGPoint(x: 900, y: 420), controlPoint1: CGPoint(x: 320, y: 100), controlPoint2: CGPoint(x: 540, y: 720))
            hill.addLine(to: CGPoint(x: 900, y: 650)); hill.addLine(to: CGPoint(x: 0, y: 650)); hill.close(); hill.fill()
            UIColor(red: 0.24, green: 0.36, blue: 0.39, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: -150, y: 440, width: 1_200, height: 600)).fill()
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plain-photo-fixture.jpg")
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: url)
        if let prepared = try? PhotoImport.process(url) {
            try? store.addPhoto(prepared.photo, jpegData: prepared.jpeg, to: noteID)
            if placed, var note = store.note(noteID) {
                var lines = note.body.components(separatedBy: "\n")
                let firstBreak = lines.indices.dropFirst(2).first { lines[$0].isEmpty } ?? lines.endIndex
                lines.insert(contentsOf: [PhotoMarkdown.line(for: prepared.photo.id), ""], at: min(firstBreak + 1, lines.endIndex))
                note.body = lines.joined(separator: "\n")
                store.update(note)
            }
        }
    }

    /// Fixtures for driving screens by hand. Only ever runs behind PLAIN_SEED —
    /// a shipped build starts empty.
    static func seed(_ store: NotesStore) {
        let folder = store.createFolder(named: "Work")
        let stale = Note(title: "Old draft", body: "# Old draft\n\nSuperseded.", updatedAt: .now.addingTimeInterval(-3 * 86_400))
        store.importNotes([stale])
        store.delete(noteIDs: [stale.id])
        store.importNotes([
            Note(
                title: "Release checklist",
                body: """
                # Release checklist

                Cut the build once every box is ticked.

                - [x] Bump the build number
                - [ ] Export the library and check the zip
                - [ ] Walk the empty states
                - [ ] Screenshot pass on the small phone

                > Nothing ships on a Friday.

                #todo #release
                """,
                folderID: folder?.id,
                updatedAt: .now
            ),
            Note(
                title: "Markdown scratch",
                body: """
                # Markdown scratch

                A paragraph with `code` and **weight** in it, pointing at
                [[Release checklist]].

                | Service | Owner |
                | --- | --- |
                | auth | Ada |
                | notes | Mert |

                ```swift
                let note = Note(title: "Spec")
                ```

                #spec
                """,
                folderID: nil,
                updatedAt: .now.addingTimeInterval(-3_600)
            )
        ])
    }
}
#endif
