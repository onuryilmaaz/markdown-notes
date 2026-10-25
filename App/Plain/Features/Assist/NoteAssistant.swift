import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif
import PlainDomain

/// On-device help with a note: a title, some tags, a summary. Runs through
/// Apple's system model, so nothing a person writes leaves the phone and there
/// is no API bill behind any of it.
@MainActor
@Observable
final class NoteAssistant {
    enum Job: String, CaseIterable, Identifiable {
        case title, tags, summary

        var id: String { rawValue }

        var label: String {
            switch self {
            case .title: "Suggest a title"
            case .tags: "Suggest tags"
            case .summary: "Summarise"
            }
        }

        var icon: String {
            switch self {
            case .title: "textformat"
            case .tags: "number"
            case .summary: "text.line.first.and.arrowtriangle.forward"
            }
        }

        var instructions: String {
            switch self {
            case .title:
                "You name notes. Reply with one short title, five words at most, in the language the note is written in. No quotes, no punctuation at the end, no explanation."
            case .tags:
                "You tag notes. Reply with two to four lowercase single-word tags, comma separated, no # signs and no explanation."
            case .summary:
                "You summarise notes. Reply with two or three sentences in the language the note is written in. Plain prose, no headings, no bullet points."
            }
        }
    }

    enum State: Equatable {
        case idle
        case working
        case answered(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var job: Job?

    /// Whether the system model is usable right now, with the reason when not.
    static var availability: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "This iPhone does not run Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in Settings to use this."
            case .unavailable(.modelNotReady):
                return "The on-device model is still downloading."
            case .unavailable:
                return "The on-device model is not available right now."
            }
        }
        return "This needs iOS 26 or newer."
        #else
        return "This build has no on-device model."
        #endif
    }

    static var isAvailable: Bool { availability == nil }

    func reset() {
        state = .idle
        job = nil
    }

    func run(_ job: Job, on note: Note) {
        self.job = job
        state = .working

        Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await Self.ask(job, about: note)
                let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                state = cleaned.isEmpty ? .failed("The model had nothing to say about this note.") : .answered(cleaned)
            } catch {
                state = .failed(Self.availability ?? "That did not work. Try again in a moment.")
            }
        }
    }

    /// The tags the model proposed, cleaned into the app's own tag shape.
    static func tags(from answer: String) -> [String] {
        MarkdownText.tags(fromList: answer)
    }

    private static func ask(_ job: Job, about note: Note) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: job.instructions)
            // Long notes are trimmed: the model has a context window and the
            // opening of a note carries its subject.
            let body = String(note.body.prefix(4_000))
            let response = try await session.respond(to: "Note:\n\n\(body)")
            return response.content
        }
        #endif
        throw AssistantError.unavailable
    }
}

enum AssistantError: Error {
    case unavailable
}

/// A `Job` wrapped so it can travel in a `Hashable` sheet route without the
/// navigation layer importing the assistant's internals.
struct NoteAssistantJob: Hashable, Identifiable {
    let kind: NoteAssistant.Job
    var id: String { kind.rawValue }
}
