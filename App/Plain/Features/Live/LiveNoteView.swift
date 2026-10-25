import SwiftUI
import PlainDomain
import PlainDesignSystem

/// The ring statistic: how long this note has been public, and when it stops.
struct LiveNoteView: View {
    let noteID: UUID

    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(LiveActivityController.self) private var liveActivities

    private var note: Note? { store.note(noteID) }

    var body: some View {
        PlainScreen {
            if let note, let session = note.live {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(note: note, session: session, now: context.date)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    EmptyStateCard(glyph: "◦", title: "Not live", message: "This note is not broadcasting right now.")
                        .frame(height: 220)
                        .padding(.horizontal, Metrics.Space.gutter)
                    PillButton("Back") { router.pop() }
                        .padding(.horizontal, 30)
                    Spacer()
                }
            }
        }
    }

    private func content(note: Note, session: LiveSession, now: Date) -> some View {
        VStack(spacing: 0) {
            header(note: note, session: session)

            Spacer()

            RingGauge(progress: session.progress(at: now), lineWidth: 17) {
                VStack(spacing: 4) {
                    Text("Your note has been live")
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkSecondary)
                    Text(PlainDate.duration(session.elapsed(at: now)))
                        .font(PlainFont.sans(34, .bold, relativeTo: .largeTitle))
                        .foregroundStyle(PlainPalette.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 226, height: 226)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your note has been live")
            .accessibilityValue(Text(verbatim: PlainDate.duration(session.elapsed(at: now))))
            .padding(.bottom, 34)

            HStack(spacing: 64) {
                stat(title: "Started", value: PlainDate.clock(session.startedAt))
                stat(title: "Expires", value: PlainDate.clock(session.expiresAt))
            }

            Spacer()
            Spacer()

            PillButton("End Live Activity", systemImage: "lock", style: .plain) {
                liveActivities.end(noteID: note.id)
                store.endLive(noteID: note.id)
                router.pop()
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 10)
        }
    }

    private func header(note: Note, session: LiveSession) -> some View {
        ZStack {
            Menu {
                ForEach(LiveDuration.allCases) { duration in
                    Button(LocalizedStringKey(duration.label)) { restart(note: note, duration: duration) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(PlainDate.remaining(session.remaining()).replacingOccurrences(of: " left", with: " Live"))
                        .font(PlainFont.headline)
                        .foregroundStyle(PlainPalette.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PlainPalette.inkSecondary)
                }
            }

            HStack {
                CircleIconButton("clock.arrow.circlepath", label: "Back", size: 38) { router.pop() }
                Spacer()
                CircleIconButton("plus", label: "Add an hour", size: 38) { extend(note: note, session: session) }
            }
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.vertical, 10)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
            Text(value)
                .font(PlainFont.sans(16, .semibold))
                .foregroundStyle(PlainPalette.ink)
        }
    }

    private func restart(note: Note, duration: LiveDuration) {
        guard let session = store.startLive(noteID: note.id, duration: duration),
              let updated = store.note(note.id) else { return }
        liveActivities.start(note: updated, session: session)
    }

    /// The `+` button buys another hour on the Lock Screen.
    private func extend(note: Note, session: LiveSession) {
        var updated = note
        updated.live = LiveSession(
            id: session.id,
            startedAt: session.startedAt,
            expiresAt: session.expiresAt.addingTimeInterval(3600)
        )
        store.update(updated, touch: false)
        if let refreshed = store.note(note.id), let live = refreshed.live {
            liveActivities.update(note: refreshed, session: live)
        }
    }
}
