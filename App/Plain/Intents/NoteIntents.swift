import AppIntents
import PlainDomain
import PlainPersistence

/// A note, as Shortcuts and Siri see it.
struct NoteAppEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")
    static let defaultQuery = NoteEntityQuery()

    let id: UUID
    let title: String
    let preview: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(preview)")
    }

    init(_ note: Note) {
        id = note.id
        title = note.title
        preview = note.isLocked ? String(localized: "Locked") : note.preview
    }
}

struct NoteEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteAppEntity] {
        await IntentLibrary.notes().filter { identifiers.contains($0.id) }.map(NoteAppEntity.init)
    }

    func entities(matching string: String) async throws -> [NoteAppEntity] {
        await IntentLibrary.notes()
            .filter { $0.isLocked ? $0.title.localizedCaseInsensitiveContains(string) : $0.matches(string) }
            .prefix(25)
            .map(NoteAppEntity.init)
    }

    func suggestedEntities() async throws -> [NoteAppEntity] {
        await IntentLibrary.notes().prefix(10).map(NoteAppEntity.init)
    }
}

// MARK: - Intents

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Writes a new markdown note into Plain.")
    static var parameterSummary: some ParameterSummary {
        Summary("Create a note with \(\.$text)")
    }

    @Parameter(title: "Text", inputOptions: .init(multiline: true))
    var text: String

    @Parameter(title: "Open in Plain", default: false)
    var shouldOpen: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteAppEntity> {
        let note = try IntentLibrary.create(from: text)
        if shouldOpen { PendingLink.shared.link = .note(note.id) }
        return .result(value: NoteAppEntity(note))
    }

    static var openAppWhenRun: Bool { false }
}

struct AppendToNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Append to Note"
    static let description = IntentDescription("Adds a line to the end of an existing note.")
    static var parameterSummary: some ParameterSummary {
        Summary("Append \(\.$text) to \(\.$note)")
    }

    @Parameter(title: "Note")
    var note: NoteAppEntity

    @Parameter(title: "Text", inputOptions: .init(multiline: true))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteAppEntity> {
        let updated = try IntentLibrary.append(text, to: note.id)
        return .result(value: NoteAppEntity(updated))
    }
}

struct OpenNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    static let description = IntentDescription("Opens a note in Plain.")
    static let openAppWhenRun = true

    @Parameter(title: "Note")
    var note: NoteAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingLink.shared.link = .note(note.id)
        return .result()
    }
}

struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Notes"
    static let description = IntentDescription("Finds notes containing a word.")

    @Parameter(title: "Term")
    var term: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteAppEntity]> {
        let hits = IntentLibrary.search(term)
        return .result(value: hits.map(NoteAppEntity.init))
    }
}

struct PlainShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Write a note in \(.applicationName)",
                "New \(.applicationName) note",
                "Note it in \(.applicationName)"
            ],
            shortTitle: "New note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: ["Search \(.applicationName)", "Find a note in \(.applicationName)"],
            shortTitle: "Search notes",
            systemImageName: "magnifyingglass"
        )
    }
}
