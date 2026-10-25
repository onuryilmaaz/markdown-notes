import SwiftUI
import PlainDomain
import PlainDesignSystem

struct SearchView: View {
    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router

    @State private var query = ""
    @State private var scope: SearchScope = .all
    @FocusState private var isFocused: Bool

    private var hits: [SearchHit] { store.hits(for: query, scope: scope) }
    private var unscopedHits: [SearchHit] { store.hits(for: query, scope: .all) }

    var body: some View {
        PlainScreen {
            VStack(spacing: 12) {
                searchField
                if !query.isEmpty { filters }
                results
            }
            .padding(.top, 8)
        }
        .onAppear {
            if let seeded = SearchSeed.shared.take() { query = seeded }
            isFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PlainPalette.inkTertiary)
                TextField("Search all notes", text: $query)
                    .font(PlainFont.body)
                    .foregroundStyle(PlainPalette.ink)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(PlainPalette.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .plainCard(radius: Metrics.Radius.control)

            Button("Cancel") { router.pop() }
                .font(PlainFont.label)
                .foregroundStyle(PlainPalette.inkSecondary)
        }
        .padding(.horizontal, Metrics.Space.gutter)
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(label: "All \(unscopedHits.count)", scope: .all)
                ForEach(topTags, id: \.self) { tag in
                    let count = unscopedHits.count { $0.note.tags.contains(tag) }
                    chip(label: "#\(tag) \(count)", scope: .tag(tag))
                }
                ForEach(topFolders, id: \.id) { folder in
                    let count = unscopedHits.count { $0.note.folderID == folder.id }
                    chip(label: "\(folder.name) \(count)", scope: .folder(folder.id))
                }
            }
            .padding(.horizontal, Metrics.Space.gutter)
        }
        .scrollIndicators(.hidden)
        .frame(height: 34)
    }

    private func chip(label: String, scope target: SearchScope) -> some View {
        TagChip(label, isSelected: scope == target) {
            withAnimation(.snappy) { scope = scope == target ? .all : target }
        }
    }

    @ViewBuilder
    private var results: some View {
        if query.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                Text("Search titles, bodies and #tags")
                    .font(PlainFont.callout)
                    .foregroundStyle(PlainPalette.inkTertiary)
                Spacer()
            }
        } else if hits.isEmpty {
            VStack {
                EmptyStateCard(glyph: "?", title: "No matches", message: "Nothing in the library mentions “\(query)” yet.")
                    .padding(.horizontal, Metrics.Space.gutter)
                    .frame(height: 220)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(hits) { hit in
                        Button {
                            router.push(.note(hit.note.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(hit.note.title)
                                    .font(PlainFont.cardTitle)
                                    .foregroundStyle(PlainPalette.ink)
                                    .lineLimit(1)
                                Text(MarkdownInline.highlighted(hit.snippet, term: query, size: 13))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(Metrics.Space.card)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .plainCard()
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, Metrics.Space.gutter)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var topTags: [String] {
        var counts: [String: Int] = [:]
        for hit in unscopedHits {
            for tag in hit.note.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.prefix(2).map(\.key)
    }

    private var topFolders: [Folder] {
        let ids = Set(unscopedHits.compactMap(\.note.folderID))
        return store.folders.filter { ids.contains($0.id) }.prefix(2).map { $0 }
    }
}
