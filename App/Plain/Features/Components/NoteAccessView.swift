import SwiftUI
import PlainDesignSystem

/// Protect every destination that can reveal a locked note, including when
/// returning from the background into an editor or history preview.
struct NoteAccessView<Content: View>: View {
    let noteID: UUID
    @ViewBuilder var content: () -> Content
    @Environment(NotesStore.self) private var store
    @Environment(LockSession.self) private var locks
    @Environment(Router.self) private var router

    var body: some View {
        if let note = store.note(noteID), note.isLocked && !locks.isUnlocked(noteID) {
            PlainScreen {
                VStack(spacing: 20) {
                    ScreenHeader(title: "Locked", onBack: { router.pop() })
                    Spacer()
                    EmptyStateCard(glyph: "🔒", title: "This note is locked", message: "It opens with Face ID and locks itself again when you leave Plain.")
                    PillButton("Unlock") { Task { await locks.unlock(noteID) } }
                    if let message = locks.errorMessage {
                        Text(LocalizedStringKey(message)).font(PlainFont.callout)
                            .foregroundStyle(PlainPalette.inkSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        } else {
            content()
        }
    }
}
