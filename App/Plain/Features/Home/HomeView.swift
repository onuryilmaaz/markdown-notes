import SwiftUI
import PlainDomain
import PlainDesignSystem

struct HomeView: View {
    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        PlainScreen {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            TodayCard(statistics: store.statistics)
                            WeekCard(statistics: store.statistics)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .plainEntrance()

                        if let recent = store.notes.first {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pick up where you left off")
                                    .font(PlainFont.label).foregroundStyle(PlainPalette.inkSecondary)
                                    .padding(.horizontal, 4)
                                NoteCard(note: recent, folderName: store.folderName(recent.folderID), showsCover: true) {
                                    router.push(.note(recent.id))
                                }
                            }
                            .plainEntrance(delay: 0.06)
                        }

                        folderCard.plainEntrance(delay: 0.12)
                        if store.isEmpty {
                            EmptyStateCard(
                                glyph: "#",
                                title: "Nothing here yet",
                                message: "Start with a heading. Markdown works as you type."
                            )
                            .frame(height: 220)
                        } else if !store.tagCounts.isEmpty {
                            tagRow
                        }
                    }
                    .padding(.horizontal, Metrics.Space.gutter)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                PillButton("New note", systemImage: "plus") { compose(.blank) }
                    .contextMenu { templateMenu }
                    .keyboardShortcut("n", modifiers: .command)
                .padding(.horizontal, 30)
                .padding(.bottom, 8)
                .sensoryFeedback(.impact(weight: .light), trigger: store.notes.count)
            }
        }
    }

    private var header: some View {
        ScreenHeader(title: "All Notes", backIcon: "magnifyingglass", backLabel: "Search", onBack: { router.push(.search) }) {
            CircleIconButton("square.grid.2x2", label: "Widgets", size: 38) { router.present(.widgets) }
            CircleIconButton("asterisk", label: "Settings", size: 38) { router.push(.settings) }
        }
    }

    /// Long-press the compose button for the notes somebody writes the same
    /// way every time.
    @ViewBuilder
    private var templateMenu: some View {
        ForEach(NoteTemplate.allCases) { template in
            Button(LocalizedStringKey(template.label), systemImage: template.icon) { compose(template) }
        }
    }

    private func compose(_ template: NoteTemplate) {
        let note = store.createNote(in: store.folders.first?.id, template: template)
        router.push(.editor(note.id))
    }

    private var folderCard: some View {
        VStack(spacing: 0) {
            // Notes that never got filed still need a way in.
            Button {
                router.push(.list(.folder(nil)))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PlainPalette.ink)
                        .frame(width: 18)
                    Text("All notes")
                        .font(PlainFont.body)
                        .foregroundStyle(PlainPalette.ink)
                    Spacer()
                    Text("\(store.notes.count)")
                        .font(PlainFont.label)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
                .padding(.horizontal, Metrics.Space.card)
                .frame(height: 50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            PlainDivider(inset: 46)

            ForEach(store.folders) { folder in
                Button {
                    router.push(.list(.folder(folder.id)))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PlainPalette.ink)
                            .frame(width: 18)
                        Text(folder.name)
                            .font(PlainFont.body)
                            .foregroundStyle(PlainPalette.ink)
                        Spacer()
                        Text("\(store.count(in: folder))")
                            .font(PlainFont.label)
                            .foregroundStyle(PlainPalette.inkTertiary)
                    }
                    .padding(.horizontal, Metrics.Space.card)
                    .frame(height: 50)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Rename") { router.present(.renameFolder(folder.id)) }
                    Button("Delete", role: .destructive) { store.deleteFolder(folder.id) }
                }

                PlainDivider(inset: 46)
            }

            Button {
                router.present(.newFolder)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PlainPalette.inkTertiary)
                        .frame(width: 18)
                    Text("New folder")
                        .font(PlainFont.body)
                        .foregroundStyle(PlainPalette.inkTertiary)
                    Spacer()
                }
                .padding(.horizontal, Metrics.Space.card)
                .frame(height: 50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .plainCard()
    }

    private var tagRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.tagCounts.prefix(6), id: \.name) { tag in
                    TagChip("#" + tag.name) { router.push(.tags) }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .frame(height: 34)
    }
}
