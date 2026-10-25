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
    private func launch(route: String, seeded: Bool = true, note: String? = nil, language: String = "en", photo: Bool = false, placedPhoto: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launchEnvironment["PLAIN_RESET"] = "1"
        app.launchEnvironment["PLAIN_ROUTE"] = route
        if seeded { app.launchEnvironment["PLAIN_SEED"] = "1" }
        if let note { app.launchEnvironment["PLAIN_NOTE_TITLE"] = note }
        if photo { app.launchEnvironment["PLAIN_SEED_PHOTO"] = "1" }
        if placedPhoto { app.launchEnvironment["PLAIN_SEED_PHOTO"] = "placed" }
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

        // UIKit can group the injected typing into one or several undo steps.
        // Every character must still be recoverable after the heading step.
        for _ in 0..<5 {
            if editor.value as? String == "" { break }
            app.typeKey("z", modifierFlags: .command)
        }
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

    func testProOfferCanBeClosedWithoutLosingTheNotebook() {
        let app = launch(route: "settings", seeded: false)
        app.buttons["settings-pro"].tap()
        XCTAssertTrue(app.staticTexts["Make space for your best work"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["New note"].exists)
    }

    func testPDFOffersProWhileMarkdownStaysFree() {
        let app = launch(route: "note")
        app.buttons["Note options"].tap()
        XCTAssertTrue(app.buttons["Export markdown"].exists)
        app.buttons["Export PDF"].tap()
        XCTAssertTrue(app.staticTexts["Ready to send, beautifully"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Release checklist"].exists)
    }

    func testProOfferSpeaksTurkish() {
        let app = launch(route: "pro", seeded: false, language: "tr")
        XCTAssertTrue(app.staticTexts["En iyi fikirlerine yer aç"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Odaklanarak yaz"].exists)
    }

    func testLockedNoteCannotExportOrRemoveItsLockWithoutUnlocking() {
        let app = launch(route: "note")
        app.buttons["Note options"].tap()
        app.buttons["Lock note"].tap()
        XCTAssertTrue(app.staticTexts["This note is locked"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Note options"].isEnabled)
        XCTAssertFalse(app.buttons["Go Live"].isEnabled)
        XCTAssertTrue(app.buttons["Unlock"].exists)
    }

    func testCheckboxInSearchUpdatesItsOriginalLine() {
        let app = launch(route: "note")
        app.buttons["Note options"].tap()
        app.buttons["Find in note"].tap()
        app.textFields["Find in note"].typeText("Export")
        let task = app.buttons["task-0"]
        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()
        expectation(for: NSPredicate(format: "value == %@", "done"), evaluatedWith: task)
        waitForExpectations(timeout: 3)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["task-5"].value as? String, "done")
    }

    func testPhotoOpensAndSurvivesRelaunch() {
        let app = launch(route: "note", photo: true)
        XCTAssertTrue(app.buttons["Open photo"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Open photo"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Photos"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "PLAIN_RESET")
        app.launchEnvironment.removeValue(forKey: "PLAIN_SEED_PHOTO")
        app.launch()
        XCTAssertTrue(app.buttons["Open photo"].firstMatch.waitForExistence(timeout: 5))
    }

    func testPhotoCanBeRemovedFromTheEditor() {
        let app = launch(route: "editor", photo: true)
        XCTAssertTrue(app.buttons["Remove photo"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Remove photo"].firstMatch.tap()
        app.sheets.buttons["Remove photo"].tap()
        XCTAssertFalse(app.buttons["Open photo"].exists)
        XCTAssertTrue(app.buttons["add-photos"].exists)
    }

    func testPhotoPickerCanBeCanceledWithoutLosingText() {
        let app = launch(route: "editor")
        XCTAssertTrue(app.buttons["add-photos"].waitForExistence(timeout: 5))
        let text = app.textViews.firstMatch.value as? String
        app.buttons["add-photos"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.textViews.firstMatch.value as? String, text)
    }

    func testWidgetGalleryShowsTheActualPhotoNote() {
        let app = launch(route: "widgets", photo: true)
        XCTAssertTrue(app.staticTexts["Small windows. Big ideas."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photo note"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Release checklist"].firstMatch.exists)
    }

    func testAPhotoPlacedInTheTextOpensFromThere() {
        let app = launch(route: "note", placedPhoto: true)
        let inline = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inline-photo-'")).firstMatch
        XCTAssertTrue(inline.waitForExistence(timeout: 5))
        // Placed photos are not repeated in the strip above the text.
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-'")).count, 0)
        inline.tap()
        XCTAssertTrue(app.staticTexts["Photos"].waitForExistence(timeout: 3))
    }

    func testAPhotoCanLeaveTheTextAndBePlacedAgain() {
        let app = launch(route: "editor", placedPhoto: true)
        let options = app.buttons["photo-options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        app.buttons["Remove from text"].tap()
        let place = app.buttons["Place in text"]
        XCTAssertTrue(place.waitForExistence(timeout: 3))
        XCTAssertFalse((app.textViews.firstMatch.value as? String ?? "").contains("photo:"))

        place.tap()
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        XCTAssertFalse(place.exists)
        XCTAssertTrue((app.textViews.firstMatch.value as? String ?? "").contains("photo:"))
    }

    func testAPhotoCanBeDraggedToAnotherSpotInTheText() {
        let app = launch(route: "editor", placedPhoto: true)
        let photo = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'editor-photo-'")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        let editor = app.textViews.firstMatch
        let before = editor.value as? String ?? ""
        XCTAssertLessThan(before.range(of: "photo:")!.lowerBound, before.range(of: "Walk the empty states")!.lowerBound)

        // The editor opens scrolled to the caret, so hold the part of the photo still in view.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).press(forDuration: 0.6, thenDragTo: editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))

        let after = editor.value as? String ?? ""
        XCTAssertGreaterThan(after.range(of: "photo:")!.lowerBound, after.range(of: "Walk the empty states")!.lowerBound)
        XCTAssertEqual(after.components(separatedBy: "photo:").count, 2, "the photo moved, it was not copied")
    }
}
