import WidgetKit
import AppIntents
import SwiftUI
import PlainDomain
import PlainDesignSystem

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the box the app writes after every change; refreshes hourly as a
/// belt-and-braces fallback to the app's explicit reloads.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: SnapshotStore.shared.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotStore.shared.read() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct DayCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.day", provider: SnapshotProvider()) { entry in
            DayCountView(entry: entry)
                .containerBackground(PlainPalette.surface, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("The date, and how much you have written.")
        .supportedFamilies([.systemSmall])
    }
}

private struct DayCountView: View {
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text(PlainDate.weekday(entry.date))
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.ink)
                Text(PlainDate.month(entry.date))
                    .font(PlainFont.sans(13, .medium))
                    .foregroundStyle(PlainPalette.inkTertiary)
            }
            Text("\(Calendar.current.component(.day, from: entry.date))")
                .font(PlainFont.counter)
                .foregroundStyle(PlainPalette.ink)
            Spacer(minLength: 2)
            Text("\(entry.snapshot.todayCount) notes written")
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct PinnedNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.pinned", provider: SnapshotProvider()) { entry in
            PinnedNoteView(entry: entry)
                .containerBackground(PlainPalette.surface, for: .widget)
        }
        .configurationDisplayName("Pinned")
        .description("Keep one note on the home screen.")
        .supportedFamilies([.systemSmall])
    }
}

private struct PinnedNoteView: View {
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pinned")
                .font(PlainFont.sans(13, .semibold))
                .foregroundStyle(PlainPalette.ink)
            Text(entry.snapshot.pinnedTitle ?? "Nothing pinned")
                .font(PlainFont.sans(12.5, .medium))
                .foregroundStyle(PlainPalette.inkSecondary)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(entry.snapshot.pinnedSubtitle ?? "Widget — home screen")
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct RecentlyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "plain.recent", provider: SnapshotProvider()) { entry in
            RecentlyLiveView(entry: entry)
                .containerBackground(PlainPalette.surface, for: .widget)
        }
        .configurationDisplayName("Recently live")
        .description("The last notes you touched.")
        .supportedFamilies([.systemMedium])
    }
}

private struct RecentlyLiveView: View {
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recently live")
                .font(PlainFont.sans(13, .semibold))
                .foregroundStyle(PlainPalette.ink)

            ForEach(entry.snapshot.recent) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.isLive ? PlainPalette.ink : PlainPalette.dotIdle)
                        .frame(width: 6, height: 6)
                    Text(item.title)
                        .font(PlainFont.sans(12.5, .medium))
                        .foregroundStyle(item.isLive ? PlainPalette.ink : PlainPalette.inkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(item.subtitle)
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
