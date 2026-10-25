import SwiftUI
import UIKit
import PlainDomain

/// The real widget artwork is shared with its in-app gallery.
public struct NotebookWidgetView: View {
    public enum Kind: String, CaseIterable, Identifiable {
        case today, pinned, recent, photo, capture
        public var id: String { rawValue }
    }

    let kind: Kind
    let snapshot: WidgetSnapshot
    let date: Date
    let medium: Bool

    public init(kind: Kind, snapshot: WidgetSnapshot, date: Date = .now, medium: Bool = false) {
        self.kind = kind
        self.snapshot = snapshot
        self.date = date
        self.medium = medium
    }

    public var body: some View {
        Group {
            switch kind {
            case .today: today
            case .pinned: pinned
            case .recent: recent
            case .photo: photo
            case .capture: capture
            }
        }
        .foregroundStyle(PlainPalette.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(PlainDate.weekday(date)).font(PlainFont.sans(12, .semibold))
                Spacer(minLength: 0)
                Image(systemName: "sun.max").font(.system(size: 14))
            }
            Text("\(Calendar.current.component(.day, from: date))")
                .font(PlainFont.counter).contentTransition(.numericText())
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(Array((snapshot.activeDays ?? Array(repeating: false, count: 14)).suffix(7).enumerated()), id: \.offset) { _, active in
                    Capsule().fill(active ? PlainPalette.ink : PlainPalette.dotIdle).frame(maxWidth: 14).frame(height: 5)
                }
            }
            Text("\(Calendar.current.isDate(snapshot.date, inSameDayAs: date) ? snapshot.todayCount : 0) notes written")
                .font(PlainFont.meta).foregroundStyle(PlainPalette.inkSecondary)
        }
    }

    private var pinned: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pinned", systemImage: "pin.fill").font(PlainFont.sans(11, .semibold))
                Spacer(minLength: 0)
                if let data = snapshot.pinnedThumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 38, height: 38).clipped()
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
            Text(verbatim: snapshot.pinnedTitle ?? String(localized: "Nothing pinned"))
                .font(PlainFont.sans(medium ? 18 : 15, .bold)).lineLimit(2)
            if let preview = snapshot.pinnedPreview, !preview.isEmpty {
                Text(verbatim: preview).font(PlainFont.callout).foregroundStyle(PlainPalette.inkSecondary).lineLimit(medium ? 3 : 2)
            }
            Spacer(minLength: 0)
            Text(verbatim: snapshot.pinnedSubtitle ?? String(localized: "Pin a note in Plain"))
                .font(PlainFont.meta).foregroundStyle(PlainPalette.inkTertiary).lineLimit(1)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent notes").font(PlainFont.sans(12, .semibold))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
            }
            if snapshot.recent.isEmpty {
                Spacer(minLength: 0)
                Text("Your next idea starts here").font(PlainFont.body).foregroundStyle(PlainPalette.inkSecondary)
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.recent.prefix(3)) { item in
                    Link(destination: WidgetSnapshot.noteURL(item.id)) {
                        HStack(spacing: 10) {
                            if let data = item.thumbnail, let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill().frame(width: 30, height: 30).clipped()
                                    .clipShape(.rect(cornerRadius: 8))
                            } else {
                                Image(systemName: item.isLive ? "circle.fill" : "doc.text")
                                    .font(.system(size: 13)).frame(width: 30, height: 30)
                                    .background(PlainPalette.fill, in: .rect(cornerRadius: 8))
                            }
                            Text(verbatim: item.title).font(PlainFont.sans(12.5, .medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(verbatim: item.subtitle).font(PlainFont.meta).foregroundStyle(PlainPalette.inkTertiary)
                        }
                    }
                }
            }
        }
    }

    private var photo: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let data = snapshot.photoThumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Photo note", systemImage: "photo").font(PlainFont.sans(10, .semibold))
                        Text(verbatim: snapshot.photoTitle ?? "").font(PlainFont.sans(15, .bold)).lineLimit(2)
                    }
                    .foregroundStyle(.white).padding(14)
                } else {
                    PlainPalette.fill
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 30, weight: .light))
                        Text("A little window into your notes").font(PlainFont.label)
                    }
                    .padding(16)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 20))
    }

    private var capture: some View {
        ZStack(alignment: .topTrailing) {
            Circle().stroke(PlainPalette.hairline, lineWidth: 1).frame(width: 116, height: 116).offset(x: 32, y: -34)
            Circle().stroke(PlainPalette.hairline, lineWidth: 1).frame(width: 82, height: 82).offset(x: 15, y: -17)
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "plus").font(.system(size: 22, weight: .medium))
                    .foregroundStyle(PlainPalette.onEmphasis).frame(width: 46, height: 46)
                    .background(PlainPalette.emphasis, in: .circle)
                Spacer(minLength: 0)
                Text("Catch a thought").font(PlainFont.sans(17, .bold))
                Text("One tap. A fresh page.").font(PlainFont.meta).foregroundStyle(PlainPalette.inkSecondary)
            }
        }
        .clipped()
    }
}
