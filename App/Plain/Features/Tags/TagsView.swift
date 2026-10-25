import SwiftUI
import PlainDesignSystem

struct TagsView: View {
    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router

    private var tags: [(name: String, count: Int)] { store.tagCounts }

    var body: some View {
        PlainScreen {
            VStack(spacing: 0) {
                ScreenHeader(title: "Tags", onBack: { router.pop() })

                ScrollView {
                    VStack(spacing: 14) {
                        mostUsedCard
                        listCard
                        Text("Tags live on the note, folders live around it. A note can carry many tags but sits in one folder.")
                            .font(PlainFont.meta)
                            .foregroundStyle(PlainPalette.inkTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, Metrics.Space.gutter)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var mostUsedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Most used")
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.ink)
                Spacer()
                Text("\(tags.count)")
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.inkTertiary)
            }
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Array(tags.prefix(7).enumerated()), id: \.element.name) { index, tag in
                    TagChip("#" + tag.name, isSelected: index == 0, isMuted: index > 3) {
                        router.push(.list(.tag(tag.name)))
                    }
                }
            }
        }
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plainCard()
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.element.name) { index, tag in
                ValueRow(verbatim: "#" + tag.name, value: "\(tag.count)", showsChevron: false) {
                    router.push(.list(.tag(tag.name)))
                }
                if index < tags.count - 1 { PlainDivider() }
            }
        }
        .plainCard()
    }
}
