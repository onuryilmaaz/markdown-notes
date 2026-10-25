import WidgetKit
import AppIntents
import SwiftUI
import PlainDomain
import PlainDesignSystem

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: SnapshotStore.shared.read() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotStore.shared.read() ?? .empty)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

private struct WidgetArtwork: View {
    let entry: SnapshotEntry
    let kind: NotebookWidgetView.Kind
    @Environment(\.widgetFamily) private var family

    private var destination: URL {
        if kind == .today || (kind == .pinned && entry.snapshot.pinnedID == nil) {
            return URL(string: "plain://home")!
        }
        let id: UUID?
        switch kind {
        case .pinned: id = entry.snapshot.pinnedID
        case .photo: id = entry.snapshot.photoNoteID
        case .recent: id = entry.snapshot.recent.first?.id
        default: id = nil
        }
        return id.map(WidgetSnapshot.noteURL) ?? URL(string: "plain://new")!
    }

    var body: some View {
        NotebookWidgetView(kind: kind, snapshot: entry.snapshot, date: entry.date, medium: family == .systemMedium)
            .containerBackground(PlainPalette.surface, for: .widget)
            .widgetURL(destination)
            .privacySensitive(kind == .photo || kind == .pinned || kind == .recent)
    }
}

struct DayCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.day", provider: SnapshotProvider()) { WidgetArtwork(entry: $0, kind: .today) }
            .configurationDisplayName("Today")
            .description("The date, and how much you have written.")
            .supportedFamilies([.systemSmall])
    }
}

struct PinnedNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.pinned", provider: SnapshotProvider()) { WidgetArtwork(entry: $0, kind: .pinned) }
            .configurationDisplayName("Pinned")
            .description("Keep one note on the home screen.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RecentlyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.recent", provider: SnapshotProvider()) { WidgetArtwork(entry: $0, kind: .recent) }
            .configurationDisplayName("Recent notes")
            .description("Pick up any of your three latest notes.")
            .supportedFamilies([.systemMedium])
    }
}

struct PhotoNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.photo", provider: SnapshotProvider()) { WidgetArtwork(entry: $0, kind: .photo) }
            .configurationDisplayName("Photo note")
            .description("The latest photo note, one tap away.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .contentMarginsDisabled()
    }
}

struct QuickNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.capture", provider: SnapshotProvider()) { WidgetArtwork(entry: $0, kind: .capture) }
            .configurationDisplayName("Quick note")
            .description("A fresh page is always one tap away.")
            .supportedFamilies([.systemSmall])
    }
}

/// Control Centre, Lock Screen and the Action button: one tap to a blank note.
struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.onur6541.plain.control.newnote") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "plain://new")!)) {
                Label("New note", systemImage: "square.and.pencil")
            }
        }
        .displayName("New note")
        .description("Start writing in Plain.")
    }
}

/// The same, pointed at search.
struct SearchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.onur6541.plain.control.search") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "plain://search")!)) {
                Label("Search notes", systemImage: "magnifyingglass")
            }
        }
        .displayName("Search notes")
        .description("Jump straight into Plain's search.")
    }
}
