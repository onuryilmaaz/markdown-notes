import XCTest

/// Smoke tests over the real app. They drive it through the launch seam
/// (`PLAIN_SEED`, `PLAIN_ROUTE`) so each test starts on the screen it is about.
final class PlainUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The language is pinned on every launch: these tests assert the words on
    /// screen, so they cannot inherit whatever the simulator happens to be set
    /// to.
    private func launch(route: String, seeded: Bool = true, note: String? = nil, language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launchEnvironment["PLAIN_RESET"] = "1"
        app.launchEnvironment["PLAIN_ROUTE"] = route
        if seeded { app.launchEnvironment["PLAIN_SEED"] = "1" }
        if let note { app.launchEnvironment["PLAIN_NOTE_TITLE"] = note }
        app.launch()
        return app
    }

    func testTappingACheckboxTicksIt() {
        let app = launch(route: "note")
        let task = app.buttons["task-5"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertEqual(task.value as? String, "open")

        task.tap()

        // The row redraws from the stored note, so a ticked box here means the
        // toggle round-tripped through the repository.
        expectation(for: NSPredicate(format: "value == %@", "done"), evaluatedWith: task)
        waitForExpectations(timeout: 3)
    }

    func testDeletingANoteSendsItToTheTrash() {
        let app = launch(route: "note")
        XCTAssertTrue(app.staticTexts["Release checklist"].waitForExistence(timeout: 5))

        app.buttons["trash"].firstMatch.tap()
        app.buttons["Move to trash"].tap()

        // Back on the list, the note is gone.
        XCTAssertFalse(app.staticTexts["Release checklist"].waitForExistence(timeout: 2))
    }

    func testTrashRestoresANote() {
        let app = launch(route: "trash")
        XCTAssertTrue(app.staticTexts["Old draft"].waitForExistence(timeout: 5))

        app.buttons["Restore"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Trash is empty"].waitForExistence(timeout: 3))
    }

    func testFollowingAWikiLinkOpensTheOtherNote() {
        let app = launch(route: "note", note: "scratch")
        XCTAssertTrue(app.staticTexts["Markdown scratch"].waitForExistence(timeout: 5))

        app.links["Release checklist"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Release checklist"].waitForExistence(timeout: 3))
        // And the note it came from shows up as a backlink.
        XCTAssertTrue(app.staticTexts["Linked from"].exists)
    }

    func testAShortcutBarEditCanBeUndone() {
        let app = launch(route: "compose", seeded: false)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))

        editor.tap()
        // The simulator drops the first command keystroke of a session, so one
        // is spent here before anything is being measured.
        app.typeKey("z", modifierFlags: .command)

        editor.typeText("hello")
        app.buttons["Heading 1"].tap()
        XCTAssertEqual(editor.value as? String, "# hello")

        // ⌘Z is the same path shake-to-undo takes. The heading is its own step:
        // undoing it leaves the typing alone.
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(editor.value as? String, "hello")

        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(editor.value as? String, "")
    }

    func testIconButtonsHaveNamesForVoiceOver() {
        let app = launch(route: "note")
        // Icons alone; without a label these would be read as symbol names.
        XCTAssertTrue(app.buttons["Note options"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete note"].exists)
        XCTAssertTrue(app.buttons["Back"].exists)

        // And a card reads as one sentence rather than four fragments.
        app.buttons["Back"].tap()
        let card = app.buttons["Release checklist"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertTrue((card.value as? String ?? "").contains("Cut the build"))
    }

    func testTheAppSpeaksTurkishWhenTheSystemDoes() {
        let app = launch(route: "", seeded: false, language: "tr")

        XCTAssertTrue(app.staticTexts["Tüm Notlar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tüm notlar"].exists)
        XCTAssertTrue(app.buttons["Yeni not"].exists)
        // The empty state, which is a whole sentence rather than a label.
        XCTAssertTrue(app.staticTexts["Burada henüz bir şey yok"].exists)
    }

    func testEmptyLibraryStartsEmpty() {
        let app = launch(route: "", seeded: false)
        XCTAssertTrue(app.staticTexts["Nothing here yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All notes"].exists)
    }
}
