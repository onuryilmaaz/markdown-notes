import SwiftUI
import Observation
import PlainDomain

/// What a note list is showing.
enum ListScope: Hashable {
    case folder(UUID?)
    case tag(String)
}

enum Route: Hashable {
    case list(ListScope)
    case note(UUID)
    case editor(UUID)
    case live(UUID)
    case search
    case tags
    case settings
    case trash
    case history(UUID)
}

enum AppSheet: Identifiable, Hashable {
    case newFolder
    case renameFolder(UUID)
    case assist(UUID, NoteAssistantJob)
    case pro(ProFeature?)
    case privacy
    case widgets

    var id: Self { self }
}

@MainActor
@Observable
final class Router {
    var path: [Route] = []
    var sheet: AppSheet?

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Used after deleting whatever the top screens were showing.
    func popTo(_ route: Route) {
        guard let index = path.lastIndex(of: route) else { return popToRoot() }
        path.removeSubrange((index + 1)...)
    }

    func popToRoot() {
        path.removeAll()
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }
}
