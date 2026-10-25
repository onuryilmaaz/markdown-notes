import Foundation
import ActivityKit
import Observation
import PlainDomain
import PlainActivity

/// Wraps ActivityKit so the feature layer only deals in notes and sessions.
@MainActor
@Observable
final class LiveActivityController {
    private(set) var isSupported: Bool = ActivityAuthorizationInfo().areActivitiesEnabled
    private var activities: [UUID: Activity<NoteActivityAttributes>] = [:]

    init() {
        adoptRunningActivities()
    }

    /// Reconnects to activities that outlived the process.
    private func adoptRunningActivities() {
        for activity in Activity<NoteActivityAttributes>.activities {
            activities[activity.attributes.noteID] = activity
        }
    }

    func start(note: Note, session: LiveSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            isSupported = false
            return
        }
        end(noteID: note.id)

        let attributes = NoteActivityAttributes(noteID: note.id, title: note.title)
        let state = NoteActivityAttributes.ContentState(
            excerpt: note.preview,
            startedAt: session.startedAt,
            expiresAt: session.expiresAt
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: session.expiresAt),
                pushType: nil
            )
            activities[note.id] = activity
        } catch {
            isSupported = false
        }
    }

    func update(note: Note, session: LiveSession) {
        guard let activity = activities[note.id] else { return }
        let state = NoteActivityAttributes.ContentState(
            excerpt: note.preview,
            startedAt: session.startedAt,
            expiresAt: session.expiresAt
        )
        Task { await activity.update(.init(state: state, staleDate: session.expiresAt)) }
    }

    func end(noteID: UUID) {
        guard let activity = activities.removeValue(forKey: noteID) else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Drops activities whose note or session no longer exists.
    func reconcile(with notes: [Note]) {
        let liveIDs = Set(notes.filter { $0.isLive() }.map(\.id))
        for id in activities.keys where !liveIDs.contains(id) {
            end(noteID: id)
        }
    }
}
