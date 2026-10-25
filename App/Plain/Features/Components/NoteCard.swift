import SwiftUI
import PlainDomain
import PlainDesignSystem

/// The white card used by every note list. A live note flips to ink.
struct NoteCard: View {
    let note: Note
    var folderName: String?
    var isSelected: Bool = false
    var showsSelection: Bool = false
    var showsCover = false
    var action: () -> Void

    private var isLive: Bool { note.isLive() }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if showsCover, !note.isLocked, let photo = note.photos.first,
                   let image = UIImage(data: photo.thumbnail) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(height: 170).clipped()
                        .overlay(alignment: .bottomTrailing) {
                            Label("\(note.photos.count)", systemImage: "photo.on.rectangle")
                                .font(PlainFont.meta).foregroundStyle(.white)
                                .padding(10).background(.black.opacity(0.4), in: .capsule).padding(12)
                        }
                }
            HStack(alignment: .top, spacing: 12) {
                if showsSelection {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(isSelected ? PlainPalette.ink : PlainPalette.inkTertiary)
                        .padding(.top, 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if isLive {
                            Circle()
                                .fill(PlainPalette.onEmphasis)
                                .frame(width: 6, height: 6)
                        }
                        Text(note.title)
                            .font(PlainFont.cardTitle)
                            .foregroundStyle(isLive ? PlainPalette.onEmphasis : PlainPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if note.isLocked {
                        Label("Locked", systemImage: "lock.fill")
                            .font(PlainFont.meta)
                            .foregroundStyle(PlainPalette.inkTertiary)
                    } else if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(PlainFont.callout)
                            .foregroundStyle(isLive ? PlainPalette.onEmphasis.opacity(0.75) : PlainPalette.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Text(metaLine)
                        .font(PlainFont.meta)
                        .foregroundStyle(isLive ? PlainPalette.onEmphasis.opacity(0.6) : PlainPalette.inkTertiary)
                }
                Spacer(minLength: 0)

                if !showsCover, !note.isLocked, let photo = note.photos.first,
                   let image = UIImage(data: photo.thumbnail) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 72, height: 78).clipped()
                        .clipShape(.rect(cornerRadius: 16))
                }

                if note.isPinned, !showsSelection {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(isLive ? PlainPalette.onEmphasis.opacity(0.6) : PlainPalette.inkTertiary)
                }
            }
            .padding(Metrics.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(.rect(cornerRadius: Metrics.Radius.card))
            .plainCard(background: isLive ? PlainPalette.emphasis : PlainPalette.surface)
        }
        .buttonStyle(PressableButtonStyle())
        .modifier(NoteTransitionSource(id: note.id))
        // A card is one thing to a reader; it should be one thing to VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: note.title))
        .accessibilityValue(Text(verbatim: spokenDetail))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(showsSelection ? "" : String(localized: "Opens the note"))
    }

    /// What is worth hearing after the title: the state first, then the words.
    private var spokenDetail: String {
        var pieces: [String] = []
        if note.isLocked { pieces.append(String(localized: "Locked")) }
        if isLive { pieces.append(String(localized: "Live now")) }
        if note.isPinned { pieces.append(String(localized: "Pinned")) }
        if !note.isLocked, !note.preview.isEmpty { pieces.append(note.preview) }
        pieces.append(metaLine)
        return pieces.joined(separator: ", ")
    }

    private var metaLine: String {
        if let live = note.live, live.isActive() {
            return "Live on Dynamic Island · " + PlainDate.remaining(live.remaining())
        }
        var parts = [PlainDate.relative(note.updatedAt)]
        if let folderName { parts.append(folderName) }
        if let tag = note.tags.first { parts.append("#" + tag) }
        return parts.joined(separator: " · ")
    }
}
