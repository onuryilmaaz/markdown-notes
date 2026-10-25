#if DEBUG
import Foundation
import PlainDomain

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
        default: break
        }
    }
}
#endif


#if DEBUG
private extension DebugLaunch {
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
