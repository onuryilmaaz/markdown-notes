import SwiftUI
import PlainDomain
import PlainDesignSystem

/// The thirty-day safety net. Nothing leaves the app without passing through
/// here first, so a mis-tap is never the end of a note.
struct TrashView: View {
    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router

    @State private var confirmingEmpty = false

    private var notes: [Note] { store.deletedNotes }

    var body: some View {
        PlainScreen {
            VStack(spacing: 0) {
                ScreenHeader(
                    title: "Recently deleted",
                    caption: notes.isEmpty ? "Nothing here" : "Kept for 30 days",
                    onBack: { router.pop() }
                )

                if notes.isEmpty {
                    VStack {
                        EmptyStateCard(
                            glyph: "∅",
                            title: "Trash is empty",
                            message: "Deleted notes wait here for 30 days before they go for good."
                        )
                    }
                    .padding(.horizontal, Metrics.Space.gutter)
                    .padding(.bottom, 10)
                } else {
                    list
                    PillButton("Empty trash", style: .destructive) { confirmingEmpty = true }
                        .padding(.horizontal, Metrics.Space.gutter)
                        .padding(.bottom, 8)
                }
            }
        }
        .confirmationDialog("Empty the trash?", isPresented: $confirmingEmpty, titleVisibility: .visible) {
            Button("Delete ^[\(notes.count) note](inflect: true) for good", role: .destructive) {
                store.emptyTrash()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(notes) { note in
                    row(for: note)
                }
            }
            .padding(.horizontal, Metrics.Space.gutter)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func row(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title)
                .font(PlainFont.cardTitle)
                .foregroundStyle(PlainPalette.ink)
                .lineLimit(1)

            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(PlainFont.callout)
                    .foregroundStyle(PlainPalette.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 10) {
                Text("^[\(store.daysLeftInTrash(note)) day](inflect: true) left")
                    .font(PlainFont.meta)
                    .foregroundStyle(PlainPalette.inkTertiary)

                Spacer(minLength: 0)

                Button("Restore") { store.restore(noteIDs: [note.id]) }
                    .font(PlainFont.sans(12.5, .semibold))
                    .foregroundStyle(PlainPalette.onEmphasis)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(PlainPalette.emphasis, in: .capsule)

                Button("Delete") { store.purge(noteIDs: [note.id]) }
                    .font(PlainFont.sans(12.5, .semibold))
                    .foregroundStyle(PlainPalette.destructive)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(PlainPalette.fill, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plainCard()
    }
}
