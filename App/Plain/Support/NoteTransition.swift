import SwiftUI

private struct NoteTransitionKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var noteTransitionNamespace: Namespace.ID? {
        get { self[NoteTransitionKey.self] }
        set { self[NoteTransitionKey.self] = newValue }
    }
}

struct NoteTransitionSource: ViewModifier {
    let id: UUID
    @Environment(\.noteTransitionNamespace) private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace, !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
