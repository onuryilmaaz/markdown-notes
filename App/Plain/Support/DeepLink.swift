import Foundation
import PlainDomain

/// Everything that can point at this app from outside: the `plain://` scheme,
/// a Spotlight result, a widget tap, a Shortcuts action.
enum DeepLink: Equatable {
    case home
    case newNote(text: String?)
    case note(UUID)
    case noteTitled(String)
    case search(String?)
    case trash

    static let scheme = "plain"

    init?(url: URL) {
        // `[[wiki links]]` come through their own scheme from rendered text.
        if let target = WikiLink.target(from: url) {
            self = .noteTitled(target)
            return
        }
        guard url.scheme == Self.scheme else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queries = components?.queryItems ?? []
        func value(_ name: String) -> String? {
            queries.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines).nilWhenEmpty
        }
        // plain://new, plain:///new and plain://open?… all read the same way.
        let action = (url.host ?? url.pathComponents.first { $0 != "/" } ?? "").lowercased()

        switch action {
        case "home": self = .home
        case "new", "create":
            self = .newNote(text: value("text") ?? value("body"))
        case "note", "open":
            if let id = value("id").flatMap(UUID.init(uuidString:)) {
                self = .note(id)
            } else if let title = value("title") {
                self = .noteTitled(title)
            } else {
                return nil
            }
        case "search", "find":
            self = .search(value("q") ?? value("query"))
        case "trash":
            self = .trash
        default:
            return nil
        }
    }
}

/// Carries a term from a deep link into the search screen, which owns its own
/// query state.
@MainActor
final class SearchSeed {
    static let shared = SearchSeed()
    var term: String?

    func take() -> String? {
        defer { term = nil }
        return term
    }
}

private extension String {
    var nilWhenEmpty: String? { isEmpty ? nil : self }
}
