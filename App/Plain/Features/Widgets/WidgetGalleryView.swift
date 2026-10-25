import SwiftUI
import PlainDomain
import PlainDesignSystem

struct WidgetGalleryView: View {
    @Environment(NotesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var snapshot: WidgetSnapshot { SnapshotStore.shared.read() ?? .empty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Small windows. Big ideas.").font(PlainFont.title)
                        Text("Your notebook, a little closer.").font(PlainFont.callout).foregroundStyle(PlainPalette.inkSecondary)
                    }
                    Spacer(minLength: 8)
                    CircleIconButton("xmark", label: "Close", size: 36) { dismiss() }
                }
                .padding(.top, 8)

                HStack(spacing: 14) {
                    preview(.capture, title: "Quick note")
                    preview(.today, title: "Today")
                }
                .plainEntrance()

                HStack(spacing: 14) {
                    preview(.photo, title: "Photo note")
                    preview(.pinned, title: "Pinned")
                }
                .plainEntrance(delay: 0.08)

                VStack(alignment: .leading, spacing: 10) {
                    NotebookWidgetView(kind: .recent, snapshot: snapshot, medium: true)
                        .padding(18).frame(height: 170).plainCard()
                        .allowsHitTesting(false)
                    Text("Recent notes").font(PlainFont.label).padding(.leading, 4)
                }
                .plainEntrance(delay: 0.16)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Make it yours", systemImage: "square.grid.2x2").font(PlainFont.headline)
                    Text("Touch and hold your Home Screen, tap Edit, then Add Widget. Search for Plain and choose a style.")
                        .font(PlainFont.body).foregroundStyle(PlainPalette.inkSecondary)
                    Text("Add a photo to a note to bring the photo widget to life. Locked notes keep their photos private.")
                        .font(PlainFont.callout).foregroundStyle(PlainPalette.inkTertiary)
                }
                .padding(20).plainCard()
            }
            .padding(20)
            .frame(maxWidth: PlainLayout.maximumColumn)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(PlainPalette.ink)
        .plainGround()
    }

    private func preview(_ kind: NotebookWidgetView.Kind, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NotebookWidgetView(kind: kind, snapshot: snapshot)
                .padding(kind == .photo ? 0 : 16)
                .frame(height: 164)
                .plainCard()
                .allowsHitTesting(false)
            Text(title).font(PlainFont.label).padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
