import Testing
import Foundation
@testable import PlainDomain

@Suite("Wiki links")
struct WikiLinkTests {
    @Test("Targets are found in order, without repeats")
    func targets() {
        let body = "See [[Spec]] and [[Retry policy]], and [[spec]] again."
        #expect(WikiLink.targets(in: body) == ["Spec", "Retry policy"])
    }

    @Test("Brackets that are not links are left alone")
    func ignoresOtherBrackets() {
        #expect(WikiLink.targets(in: "- [ ] a task").isEmpty)
        #expect(WikiLink.targets(in: "an [inline](https://example.com) link").isEmpty)
        #expect(WikiLink.targets(in: "[[]]").isEmpty)
    }

    @Test("A link survives the trip through a URL, spaces and all")
    func urlRoundTrip() throws {
        let url = try #require(WikiLink.url(for: "Retry policy & timeouts"))
        #expect(WikiLink.target(from: url) == "Retry policy & timeouts")
    }

    @Test("Another app's URL is not ours to open")
    func foreignURLs() throws {
        let url = try #require(URL(string: "https://example.com?title=Spec"))
        #expect(WikiLink.target(from: url) == nil)
    }

    @Test("Titles match regardless of case and padding")
    func matching() {
        #expect(WikiLink.matches("Retry Policy", " retry policy "))
        #expect(!WikiLink.matches("Retry", "Retries"))
    }

    @Test("A note knows what it points at")
    func noteLinks() {
        let note = Note(title: "Design", body: "built on [[Spec]]")
        #expect(note.linkedTitles == ["Spec"])
        #expect(note.links(to: "spec"))
        #expect(!note.links(to: "Something else"))
    }
}

@Suite("Templates")
struct NoteTemplateTests {
    @Test("Blank really is blank")
    func blank() {
        #expect(NoteTemplate.blank.body().isEmpty)
        #expect(NoteTemplate.blank.title == "Untitled")
    }

    @Test("Every other template opens with a heading that matches its title")
    func headings() {
        for template in NoteTemplate.allCases where template != .blank {
            let body = template.body()
            #expect(MarkdownText.firstHeading(in: body) == template.title, "\(template)")
        }
    }

    @Test("The checklist template is made of real checkboxes")
    func checklistBoxes() {
        guard case .tasks(let items) = MarkdownDocument(parsing: NoteTemplate.checklist.body()).blocks.last else {
            Issue.record("Expected checkboxes")
            return
        }
        #expect(items.count == 3)
        #expect(items.allSatisfy { !$0.isDone })
    }

    @Test("An empty checkbox is still a checkbox")
    func emptyCheckbox() {
        guard case .tasks(let items) = MarkdownDocument(parsing: "- [ ]").blocks.first else {
            Issue.record("An empty box should parse as a task")
            return
        }
        #expect(items == [TaskItem(text: "", isDone: false, line: 0)])
    }

    @Test("Templates carry no invisible characters")
    func noZeroWidthJunk() {
        for template in NoteTemplate.allCases {
            #expect(!template.body().unicodeScalars.contains { $0.properties.isDefaultIgnorableCodePoint }, "\(template)")
        }
    }
}

@Suite("Tables and code fences")
struct TableTests {
    @Test("A pipe table becomes a table block")
    func table() {
        let source = """
        | Service | Owner |
        | --- | --- |
        | auth | Ada |
        | notes | Mert |
        """
        #expect(MarkdownDocument(parsing: source).blocks == [
            .table(header: ["Service", "Owner"], rows: [["auth", "Ada"], ["notes", "Mert"]])
        ])
    }

    @Test("A lone pipe line is just a paragraph")
    func notATable() {
        #expect(MarkdownDocument(parsing: "| not really a table").blocks == [.paragraph("not really a table")])
    }

    @Test("A fence keeps its language")
    func fenceLanguage() {
        let source = "```swift\nlet x = 1\n```"
        #expect(MarkdownDocument(parsing: source).blocks == [.code("let x = 1", language: "swift")])
    }

    @Test("A fence without a language is still code")
    func fenceWithoutLanguage() {
        #expect(MarkdownDocument(parsing: "```\nplain\n```").blocks == [.code("plain", language: nil)])
    }

    @Test("An unterminated fence still renders what was typed")
    func unterminatedFence() {
        #expect(MarkdownDocument(parsing: "```js\nconsole.log(1)").blocks == [.code("console.log(1)", language: "js")])
    }
}
