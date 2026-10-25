import ActivityKit
import WidgetKit
import SwiftUI
import PlainDomain
import PlainDesignSystem
import PlainActivity

/// Lock Screen banner + Dynamic Island presentations for a live note.
struct LiveNoteActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoteActivityAttributes.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Note", systemImage: "note.text")
                        .font(PlainFont.sans(12, .semibold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerText(context.state))
                        .font(PlainFont.sans(12, .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.title)
                            .font(PlainFont.sans(15, .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.excerpt)
                            .font(PlainFont.sans(13, .regular))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "note.text")
                    .foregroundStyle(.white)
            } compactTrailing: {
                ProgressView(timerInterval: context.state.range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(width: 18)
            } minimal: {
                Image(systemName: "note.text")
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }

    private func lockScreen(context: ActivityViewContext<NoteActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("Note")
                    .font(PlainFont.sans(12, .semibold))
                Spacer()
                Text(timerText(context.state))
                    .font(PlainFont.sans(12, .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)

            Text(context.state.excerpt.isEmpty ? context.attributes.title : context.state.excerpt)
                .font(PlainFont.sans(15, .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timerText(_ state: NoteActivityAttributes.ContentState) -> String {
        PlainDate.remaining(state.expiresAt.timeIntervalSinceNow)
    }
}
