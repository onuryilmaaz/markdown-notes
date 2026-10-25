import Testing
import Foundation
@testable import PlainDomain

@Suite("Markdown parsing")
struct MarkdownParsingTests {
    @Test("Task lines parse with their source line number")
    func tasksCarryLineNumbers() {
        let source = """
        # Checklist

        - [x] Done thing
        - [ ] Open thing
        """
        let document = MarkdownDocument(parsing: source)

        guard case .tasks(let items) = document.blocks.last else {
            Issue.record("Expected a task block, got \(String(describing: document.blocks.last))")
            return
        }
        #expect(items.count == 2)
        #expect(items[0] == TaskItem(text: "Done thing", isDone: true, line: 2))
        #expect(items[1] == TaskItem(text: "Open thing", isDone: false, line: 3))
    }

    @Test("A bullet that is not a checkbox stays a bullet")
    func plainBulletsAreNotTasks() {
        let document = MarkdownDocument(parsing: "- just a bullet\n- [not a box] still a bullet")
        #expect(document.blocks == [.bullets(["just a bullet", "[not a box] still a bullet"])])
    }

    @Test("Toggling edits only the line it was given")
    func togglingIsLineLocal() {
        let source = "- [ ] one\n- [ ] two\n- [x] three"
        let afterSecond = MarkdownText.toggledTask(atLine: 1, in: source)
        #expect(afterSecond == "- [ ] one\n- [x] two\n- [x] three")

        let afterThird = MarkdownText.toggledTask(atLine: 2, in: afterSecond)
        #expect(afterThird == "- [ ] one\n- [x] two\n- [ ] three")
    }

    @Test("Toggling a line that is out of range changes nothing")
    func togglingOutOfRangeIsSafe() {
        let source = "- [ ] one"
        #expect(MarkdownText.toggledTask(atLine: 7, in: source) == source)
    }

    @Test("A hash without a space is a tag, not a heading")
    func tagsAreNotHeadings() {
        let document = MarkdownDocument(parsing: "#spec is a tag")
        #expect(document.blocks == [.paragraph("#spec is a tag")])
    }

    @Test("Checkbox markers are stripped from previews")
    func previewDropsCheckboxes() {
        let note = Note(title: "x", body: "- [ ] Export the library")
        #expect(note.preview == "Export the library")
    }
}

@Suite("Sorting")
struct NoteSortTests {
    private func note(_ title: String, created: TimeInterval, updated: TimeInterval, pinned: Bool = false) -> Note {
        Note(
            title: title,
            createdAt: Date(timeIntervalSince1970: created),
            updatedAt: Date(timeIntervalSince1970: updated),
            isPinned: pinned
        )
    }

    @Test("Pinned notes lead every order")
    func pinnedFirst() {
        let notes = [
            note("old pinned", created: 0, updated: 0, pinned: true),
            note("fresh", created: 100, updated: 100)
        ]
        for sort in NoteSort.allCases {
            #expect(sort.apply(to: notes).first?.title == "old pinned", "\(sort) should float pins")
        }
    }

    @Test("Each order puts the right note on top")
    func orders() {
        let notes = [
            note("alpha", created: 10, updated: 50),
            note("zulu", created: 90, updated: 20)
        ]
        #expect(NoteSort.recentlyEdited.apply(to: notes).first?.title == "alpha")
        #expect(NoteSort.recentlyCreated.apply(to: notes).first?.title == "zulu")
        #expect(NoteSort.oldestFirst.apply(to: notes).first?.title == "alpha")
        #expect(NoteSort.title.apply(to: notes).first?.title == "alpha")
    }
}

@Suite("Markdown exchange")
struct NoteExchangeTests {
    @Test("A note without a heading gains one on the way out")
    func exportAddsHeading() {
        let note = Note(title: "Groceries", body: "milk\nbread")
        #expect(NoteExchange.markdown(for: note) == "# Groceries\n\nmilk\nbread\n")
    }

    @Test("A note that already opens with a heading is exported as written")
    func exportKeepsExistingHeading() {
        let note = Note(title: "Groceries", body: "# Groceries\n\nmilk")
        #expect(NoteExchange.markdown(for: note) == "# Groceries\n\nmilk\n")
    }

    @Test("File names survive slashes, length and collisions")
    func fileNames() {
        let slashes = Note(title: "9/11 report: draft", body: "")
        #expect(NoteExchange.fileName(for: slashes) == "9 11 report  draft.md")

        let empty = Note(title: "   ", body: "")
        #expect(NoteExchange.fileName(for: empty) == "Untitled.md")

        let long = Note(title: String(repeating: "a", count: 200), body: "")
        #expect(NoteExchange.fileName(for: long).count == 83)

        let taken: Set<String> = ["notes.md", "notes 2.md"]
        let collision = Note(title: "Notes", body: "")
        #expect(NoteExchange.fileName(for: collision, existing: taken) == "Notes 3.md")
    }

    @Test("An imported file takes its title from the heading, then the file name")
    func importTitles() {
        let withHeading = NoteExchange.note(fromFileNamed: "dump.md", contents: "# Real title\n\nbody")
        #expect(withHeading.title == "Real title")

        let withoutHeading = NoteExchange.note(fromFileNamed: "Meeting notes.md", contents: "body only")
        #expect(withoutHeading.title == "Meeting notes")
    }

    @Test("Windows line endings are normalised so line numbers stay true")
    func normalisesLineEndings() {
        let note = NoteExchange.note(fromFileNamed: "a.md", contents: "# A\r\n\r\n- [ ] one\r\n")
        #expect(!note.body.contains("\r"))

        guard case .tasks(let items) = MarkdownDocument(parsing: note.body).blocks.last else {
            Issue.record("Expected the checkbox to survive import")
            return
        }
        #expect(items.first?.line == 2)
    }

    @Test("Pasting empty text makes no note")
    func pasteNeedsContent() {
        #expect(NoteExchange.note(fromPastedText: "   \n  ") == nil)
        #expect(NoteExchange.note(fromPastedText: "something")?.title == "something")
    }

    @Test("Imported tags are picked up from the body")
    func importCollectsTags() {
        let note = NoteExchange.note(fromFileNamed: "a.md", contents: "# A\n\nwork on #spec and #api")
        #expect(note.tags == ["spec", "api"])
    }
}

@Suite("Tag lists")
struct TagListTests {
    @Test("A model's comma-separated answer becomes clean tags")
    func cleansAList() {
        #expect(MarkdownText.tags(fromList: "#Spec, API , backend") == ["spec", "api", "backend"])
    }

    @Test("Repeats, single letters and punctuation drop out")
    func filtersJunk() {
        #expect(MarkdownText.tags(fromList: "spec, spec, a, !!, note-taking") == ["spec", "note-taking"])
    }

    @Test("Newlines separate just as well as commas")
    func newlines() {
        #expect(MarkdownText.tags(fromList: "one\ntwo\nthree") == ["one", "two", "three"])
    }

    @Test("Nothing in, nothing out")
    func empty() {
        #expect(MarkdownText.tags(fromList: "  ,  , ").isEmpty)
    }
}

@Suite("Dates and durations")
struct DateFormattingTests {
    /// Reads one language's table directly, because the translation a process
    /// gets is chosen from its own preferred languages, not from a parameter.
    private func string(_ key: String, in language: String) throws -> String {
        let path = try #require(PlainDate.bundle.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    @Test("The package ships Turkish; English is the key itself")
    func turkishShips() throws {
        #expect(try string("ended", in: "tr") == "bitti")
        #expect(try string("now", in: "tr") == "şimdi")
        #expect(try string("Today %@", in: "tr") == "Bugün %@")
        // English is the source language, so it has no table of its own — the
        // key is the English string.
        #expect(PlainDate.bundle.path(forResource: "en", ofType: "lproj") == nil)
    }

    @Test("Turkish puts the hours and minutes back in the right order")
    func positionalArguments() throws {
        // %1$ and %2$ matter: a translation that dropped them would silently
        // swap hours and minutes.
        let pattern = try string("%lldh %lldm", in: "tr")
        #expect(pattern.contains("%1$lld"))
        #expect(pattern.contains("%2$lld"))
    }

    @Test("A duration carries its numbers whatever the language")
    func durations() {
        let long = PlainDate.duration(6_060)
        #expect(long.contains("1") && long.contains("41"))
        #expect(PlainDate.duration(120).contains("2"))
        #expect(PlainDate.duration(5).contains("5"))
        #expect(PlainDate.duration(-5).contains("0"))
    }

    @Test("Time remaining counts down and then ends")
    func remaining() {
        #expect(PlainDate.remaining(7_200).contains("2"))
        #expect(PlainDate.remaining(90).contains("1"))
        // Whatever the language, a finished window reads the same as the word
        // the catalogue holds for it.
        #expect(PlainDate.remaining(0) == PlainDate.remaining(-10))
        #expect(!PlainDate.remaining(0).contains("0"))
    }

    @Test("Month names follow the reader, not the developer")
    func monthsAreLocalised() {
        let lastYear = Date(timeIntervalSince1970: 1_767_225_600)
        #expect(!PlainDate.month(lastYear).isEmpty)
        // An old date is day-and-month; today's carries the clock.
        #expect(!PlainDate.relative(lastYear).contains(PlainDate.time(lastYear)))
        #expect(PlainDate.relative(.now).contains(PlainDate.time(.now)))
    }
}
