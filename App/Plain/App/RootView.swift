import SwiftUI
import CoreSpotlight
import PlainDomain
import PlainDesignSystem

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(NotesStore.self) private var store
    @Environment(LockSession.self) private var locks
    @Environment(\.scenePhase) private var scenePhase

    private let pending = PendingLink.shared

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: $router.sheet) { sheet in
            sheetContent(for: sheet)
        }
        .onOpenURL { url in
            if let link = DeepLink(url: url) { follow(link) }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let id = UUID(uuidString: identifier) else { return }
            follow(.note(id))
        }
        .onChange(of: pending.link) { _, link in
            guard let link else { return }
            pending.link = nil
            follow(link)
        }
        .onChange(of: scenePhase) { _, phase in
            // An extension or a Shortcuts action may have written while the app
            // was in the background.
            if phase == .active { store.reload() }
            // Leaving the app re-locks every note that was opened with Face ID.
            if phase == .background { locks.lockAll() }
        }
    }

    /// Everything from outside the app lands here: URL scheme, Spotlight,
    /// widgets, Shortcuts.
    private func follow(_ link: DeepLink) {
        router.sheet = nil
        switch link {
        case .newNote(let text):
            let note = text.flatMap { NoteExchange.note(fromPastedText: $0) }
            if let note {
                store.importNotes([note])
                router.path = [.editor(note.id)]
            } else {
                router.path = [.editor(store.createNote(in: nil).id)]
            }
        case .note(let id):
            guard store.note(id) != nil else { return }
            router.path = [.note(id)]
        case .noteTitled(let title):
            if let existing = store.note(titled: title) {
                router.path = [.note(existing.id)]
            } else {
                router.path = [.editor(store.createNote(titled: title, in: nil).id)]
            }
        case .search(let term):
            router.path = [.search]
            if let term { SearchSeed.shared.term = term }
        case .trash:
            router.path = [.trash]
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .list(let scope): NoteListView(scope: scope)
        case .note(let id): NoteDetailView(noteID: id)
        case .editor(let id): EditorView(noteID: id)
        case .live(let id): LiveNoteView(noteID: id)
        case .search: SearchView()
        case .tags: TagsView()
        case .settings: SettingsView()
        case .trash: TrashView()
        case .history(let id): HistoryView(noteID: id)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .newFolder:
            NameSheet(title: "New folder", placeholder: "Folder name", mode: .create)
                .presentationDetents([.height(230)])
                .presentationCornerRadius(Metrics.Radius.sheet)
                .presentationBackground(PlainPalette.ground)
        case .assist(let id, let job):
            if let note = store.note(id) {
                AssistSheet(note: note, job: job.kind)
                    .presentationDetents([.height(380)])
                    .presentationCornerRadius(Metrics.Radius.sheet)
                    .presentationBackground(PlainPalette.ground)
            }
        case .renameFolder(let id):
            NameSheet(title: "Rename folder", placeholder: "Folder name", mode: .rename(id))
                .presentationDetents([.height(230)])
                .presentationCornerRadius(Metrics.Radius.sheet)
                .presentationBackground(PlainPalette.ground)
        }
    }
}

/// A line of text stops being readable somewhere past 70 characters, so on an
/// iPad the column stays put and the grey ground widens around it.
enum PlainLayout {
    static let maximumColumn: CGFloat = 620
}

/// Every screen paints the grey ground and hides the system bar — the app draws
/// its own circular chrome.
struct PlainScreen<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: PlainLayout.maximumColumn, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .center)
            .plainGround()
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
    }
}
