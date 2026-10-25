import XCTest
import UIKit
import PlainDomain
@testable import Plain

/// The editor keeps a photo's `![](photo:…)` line intact whatever is typed
/// around it, and moves it as a whole.
@MainActor
final class EditorPhotoTests: XCTestCase {
    private let photo = NotePhoto(thumbnail: Data([1]), pixelWidth: 400, pixelHeight: 300)
    private var token: String { PhotoMarkdown.line(for: photo.id) }

    private func editor(_ text: String) -> (EditorController, MarkdownUITextView) {
        let view = MarkdownUITextView(frame: CGRect(x: 0, y: 0, width: 360, height: 640))
        let controller = EditorController()
        view.controller = controller
        controller.textView = view
        view.photos = [photo.id: photo]
        view.text = text
        // Any edit runs the highlighter, which finds the photo lines.
        controller.replace(NSRange(location: 0, length: 0), with: "", caret: 0)
        return (controller, view)
    }

    private func location(of needle: String, in view: UITextView) -> Int {
        (view.text as NSString).range(of: needle).location
    }

    func testInsertingMidLineGivesThePhotoALineOfItsOwn() {
        let (controller, view) = editor("Hello world")
        view.selectedRange = NSRange(location: 5, length: 0)
        controller.insertPhoto(photo)
        XCTAssertEqual(view.text, "Hello\n\(token)\n world")
        XCTAssertEqual(view.photoLines.map(\.id), [photo.id])
    }

    func testInsertingAtTheEndLeavesTheCaretOnAFreshLine() {
        let (controller, view) = editor("Hello\n")
        view.selectedRange = NSRange(location: 6, length: 0)
        controller.insertPhoto(photo)
        XCTAssertEqual(view.text, "Hello\n\(token)\n")
        XCTAssertEqual(view.selectedRange.location, (view.text as NSString).length)
    }

    func testTypingOnAPhotoLineStartsANewLineBelowIt() throws {
        let (_, view) = editor("A\n\(token)")
        let end = (view.text as NSString).length
        guard case .replace(let range, let text, let caret) = try XCTUnwrap(view.photoSafeEdit(for: NSRange(location: end, length: 0), replacement: "x")) else {
            return XCTFail("expected a redirected edit")
        }
        XCTAssertEqual(range, NSRange(location: end, length: 0))
        XCTAssertEqual(text, "\nx")
        XCTAssertEqual(caret, end + 2)
    }

    func testTypingAtTheStartOfAPhotoLineWritesAboveIt() throws {
        let (_, view) = editor("A\n\(token)")
        guard case .replace(_, let text, let caret) = try XCTUnwrap(view.photoSafeEdit(for: NSRange(location: 2, length: 0), replacement: "x")) else {
            return XCTFail("expected a redirected edit")
        }
        XCTAssertEqual(text, "x\n")
        XCTAssertEqual(caret, 3)
        // A plain return there is fine as it is.
        XCTAssertNil(view.photoSafeEdit(for: NSRange(location: 2, length: 0), replacement: "\n"))
    }

    func testBackspaceBelowAPhotoTakesTheWholePhotoLine() throws {
        let (_, view) = editor("A\n\(token)\nB")
        let lineBreak = NSRange(location: location(of: "\nB", in: view), length: 1)
        guard case .replace(let range, let text, _) = try XCTUnwrap(view.photoSafeEdit(for: lineBreak, replacement: "")) else {
            return XCTFail("expected the photo line to go")
        }
        XCTAssertEqual(range, NSRange(location: 2, length: (token as NSString).length + 1))
        XCTAssertEqual(text, "")
    }

    func testBackspaceAtAPhotoLineStepsOverTheLineBreakAbove() throws {
        let (_, view) = editor("A\n\(token)")
        guard case .moveCaret(let caret) = try XCTUnwrap(view.photoSafeEdit(for: NSRange(location: 1, length: 1), replacement: "")) else {
            return XCTFail("expected the caret to move")
        }
        XCTAssertEqual(caret, 1)
        // A blank line above can simply be deleted.
        let (_, blank) = editor("A\n\n\(token)")
        XCTAssertNil(blank.photoSafeEdit(for: NSRange(location: 2, length: 1), replacement: ""))
    }

    func testUnrelatedEditsAreLeftAlone() {
        let (_, view) = editor("A\n\(token)\nB")
        XCTAssertNil(view.photoSafeEdit(for: NSRange(location: 0, length: 1), replacement: "Z"))
    }

    func testMovingAPhotoLineDownAndBackUp() {
        let (controller, view) = editor("\(token)\nOne\nTwo")
        let line = NSRange(location: 0, length: (token as NSString).length + 1)
        controller.moveLine(line, to: location(of: "Two", in: view))
        XCTAssertEqual(view.text, "One\n\(token)\nTwo")

        let moved = NSRange(location: location(of: token, in: view), length: (token as NSString).length + 1)
        controller.moveLine(moved, to: 0)
        XCTAssertEqual(view.text, "\(token)\nOne\nTwo")
    }

    func testMovingAPhotoPastALastLineWithoutABreak() {
        let (controller, view) = editor("\(token)\nOne")
        controller.moveLine(NSRange(location: 0, length: (token as NSString).length + 1), to: (view.text as NSString).length)
        XCTAssertEqual(view.text, "One\n\(token)")
    }
}
