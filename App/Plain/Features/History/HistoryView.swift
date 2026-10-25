import SwiftUI
import PlainDomain
import PlainDesignSystem

/// Every version of a note that the editor replaced, newest first.
struct HistoryView: View {
    let noteID: UUID

    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    @State private var previewing: NoteRevision?

    private var revisions: [NoteRevision] { store.revisions(for: noteID) }

    var body: some View {
        PlainScreen {
            VStack(spacing: 0) {
                ScreenHeader(
                    title: "History",
                    caption: revisions.isEmpty ? "No earlier versions" : "^[\(revisions.count) version](inflect: true) kept",
                    onBack: { router.pop() }
                )

                if revisions.isEmpty {
                    EmptyStateCard(
                        glyph: "⟲",
                        title: "Nothing to go back to",
                        message: "Plain keeps a version whenever you come back to a note and rewrite it."
                    )
                    .padding(.horizontal, Metrics.Space.gutter)
                    .padding(.bottom, 10)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(revisions) { revision in
                                row(revision)
                            }
                        }
                        .padding(.horizontal, Metrics.Space.gutter)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .sheet(item: $previewing) { revision in
            preview(revision)
                .presentationCornerRadius(Metrics.Radius.sheet)
                .presentationBackground(PlainPalette.ground)
        }
    }

    private func row(_ revision: NoteRevision) -> some View {
        Button {
            previewing = revision
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(PlainDate.relative(revision.savedAt))
                        .font(PlainFont.sans(13.5, .semibold))
                        .foregroundStyle(PlainPalette.ink)
                    Spacer(minLength: 0)
                    Text("^[\(revision.wordCount) word](inflect: true)")
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
                Text(revision.body.replacingOccurrences(of: "\n", with: " "))
                    .font(PlainFont.callout)
                    .foregroundStyle(PlainPalette.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(Metrics.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plainCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func preview(_ revision: NoteRevision) -> some View {
        VStack(spacing: 12) {
            Text(PlainDate.relative(revision.savedAt))
                .font(PlainFont.headline)
                .foregroundStyle(PlainPalette.ink)
                .padding(.top, 18)

            ScrollView {
                MarkdownRenderedView(
                    document: MarkdownDocument(parsing: revision.body),
                    bodySize: settings.textSize - 1
                )
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .plainCard()
                .padding(.horizontal, Metrics.Space.gutter)
            }
            .scrollIndicators(.hidden)

            PillButton("Restore this version") {
                store.restore(revision)
                previewing = nil
                router.pop()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .plainGround()
    }
}
