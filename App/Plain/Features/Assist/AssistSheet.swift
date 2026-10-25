import SwiftUI
import PlainDomain
import PlainDesignSystem

/// Shows what the on-device model came back with and lets the writer take it
/// or leave it. Nothing is applied to a note without this step.
struct AssistSheet: View {
    let note: Note
    let job: NoteAssistant.Job

    @Environment(NotesStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var assistant = NoteAssistant()

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(PlainPalette.inkTertiary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text(LocalizedStringKey(job.label))
                .font(PlainFont.headline)
                .foregroundStyle(PlainPalette.ink)

            card
                .padding(.horizontal, Metrics.Space.gutter)

            Spacer(minLength: 0)

            if case .answered(let answer) = assistant.state {
                PillButton(applyLabel) {
                    apply(answer)
                    dismiss()
                }
                .padding(.horizontal, 24)
            }

            PillButton("Close", style: .plain) { dismiss() }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .plainGround()
        .task { assistant.run(job, on: note) }
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch assistant.state {
            case .idle, .working:
                HStack(spacing: 10) {
                    ProgressView().tint(PlainPalette.inkSecondary)
                    Text("Working on it, on this phone.")
                        .font(PlainFont.callout)
                        .foregroundStyle(PlainPalette.inkSecondary)
                }
            case .answered(let answer):
                if job == .tags {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(NoteAssistant.tags(from: answer), id: \.self) { tag in
                            TagChip("#" + tag)
                        }
                    }
                } else {
                    Text(answer)
                        .font(PlainFont.body)
                        .foregroundStyle(PlainPalette.ink)
                        .multilineTextAlignment(.leading)
                }
            case .failed(let message):
                Text(LocalizedStringKey(message))
                    .font(PlainFont.callout)
                    .foregroundStyle(PlainPalette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.Space.card)
        .plainCard()
    }

    private var applyLabel: LocalizedStringKey {
        switch job {
        case .title: "Use as the title"
        case .tags: "Add these tags"
        case .summary: "Put it at the top"
        }
    }

    /// Everything the model offers is written into the note as plain markdown —
    /// there is no hidden metadata anywhere.
    private func apply(_ answer: String) {
        guard var current = store.note(note.id) else { return }
        switch job {
        case .title:
            let title = answer.replacingOccurrences(of: "\n", with: " ")
            if let heading = MarkdownText.firstHeading(in: current.body) {
                current.body = current.body.replacingOccurrences(of: "# \(heading)", with: "# \(title)")
            } else {
                current.body = "# \(title)\n\n" + current.body
            }
        case .tags:
            let tags = NoteAssistant.tags(from: answer).filter { !current.tags.contains($0) }
            guard !tags.isEmpty else { return }
            let line = tags.map { "#" + $0 }.joined(separator: " ")
            current.body = current.body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + line + "\n"
        case .summary:
            let heading = MarkdownText.firstHeading(in: current.body)
            let summary = "> " + answer.replacingOccurrences(of: "\n", with: " ")
            if let heading, let range = current.body.range(of: "# \(heading)") {
                current.body.insert(contentsOf: "\n\n\(summary)", at: range.upperBound)
            } else {
                current.body = summary + "\n\n" + current.body
            }
        }
        store.update(current)
    }
}
