import SwiftUI
import UIKit
import PlainDomain
import PlainDesignSystem

/// Commands the shortcut bar sends to the text view.
@MainActor
final class EditorController {
    weak var textView: UITextView?
    fileprivate var onChange: ((String) -> Void)?
    fileprivate var highlighter = MarkdownSyntaxHighlighter(isMonospaced: true, size: 16)
    /// Called after a photo's line has left the text, to delete the photo too.
    var onDeletePhoto: ((UUID) -> Void)?

    func focus() { textView?.becomeFirstResponder() }
    func resign() { textView?.resignFirstResponder() }

    /// Toggles a line prefix such as `# `, `## ` or `- `.
    func toggleLinePrefix(_ prefix: String) {
        guard let textView else { return }
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: NSRange(location: textView.selectedRange.location, length: 0))
        let line = text.substring(with: lineRange)
        let stripped = line.replacingOccurrences(of: "^(#{1,3} |- |\\d+\\. )", with: "", options: .regularExpression)
        let replacement = line.hasPrefix(prefix) ? stripped : prefix + stripped
        let caretDelta = (replacement as NSString).length - (line as NSString).length

        let caret = max(textView.selectedRange.location + caretDelta, lineRange.location)
        edit(lineRange, with: replacement, caret: caret)
    }

    /// Wraps the selection (or opens an empty pair) with `**`, `*` or a backtick.
    func wrapSelection(with token: String) {
        guard let textView else { return }
        let range = textView.selectedRange
        let selected = (textView.text as NSString).substring(with: range)
        edit(range, with: token + selected + token, caret: range.location + (token as NSString).length, length: range.length)
    }

    func insert(_ snippet: String, caretOffset: Int? = nil) {
        guard let textView else { return }
        let range = textView.selectedRange
        edit(range, with: snippet, caret: range.location + (caretOffset ?? (snippet as NSString).length))
    }

    /// Puts a photo on a line of its own at the caret.
    func insertPhoto(_ photo: NotePhoto) {
        guard let textView = textView as? MarkdownUITextView else { return }
        textView.photos[photo.id] = photo
        let text = textView.text as NSString
        var location = NSMaxRange(textView.selectedRange)
        // Never inside another photo's line: go below it.
        if let inside = textView.photoLines.first(where: { location > $0.content.location && location <= NSMaxRange($0.content) }) {
            location = NSMaxRange(inside.line)
        }
        let breakBefore = location > 0 && text.character(at: location - 1) != 10
        let breakAfter = location >= text.length || text.character(at: location) != 10
        let snippet = (breakBefore ? "\n" : "") + PhotoMarkdown.line(for: photo.id) + (breakAfter ? "\n" : "")
        edit(NSRange(location: location, length: 0), with: snippet, caret: location + (snippet as NSString).length)
    }

    /// Moves a whole line so it starts at `target`, a line start, as one undo step.
    func moveLine(_ line: NSRange, to target: Int) {
        guard let textView, target < line.location || target > NSMaxRange(line) else { return }
        let text = textView.text as NSString
        var moving = text.substring(with: line)
        if !moving.hasSuffix("\n") { moving += "\n" }
        if target < line.location {
            let between = text.substring(with: NSRange(location: target, length: line.location - target))
            edit(NSRange(location: target, length: NSMaxRange(line) - target), with: moving + between, caret: target + (moving as NSString).length - 1)
        } else {
            var between = text.substring(with: NSRange(location: NSMaxRange(line), length: target - NSMaxRange(line)))
            // Dropped after a last line that has no line break of its own.
            if !between.hasSuffix("\n") {
                between += "\n"
                moving.removeLast()
            }
            let replacement = between + moving
            edit(NSRange(location: line.location, length: target - line.location), with: replacement, caret: line.location + (replacement as NSString).length - 1)
        }
    }

    func replace(_ range: NSRange, with replacement: String, caret: Int) {
        edit(range, with: replacement, caret: caret)
    }

    /// Every programmatic edit goes through `UITextInput`, not the text storage.
    /// That is what puts the change on the undo stack, so ⌘Z and shake-to-undo
    /// treat a shortcut-bar edit exactly like something that was typed.
    private func edit(_ range: NSRange, with replacement: String, caret: Int, length: Int = 0) {
        guard let textView, let textRange = textView.plainTextRange(for: range) else { return }
        let photoView = textView as? MarkdownUITextView
        photoView?.isApplyingEdit = true
        textView.replace(textRange, withText: replacement)
        photoView?.isApplyingEdit = false

        let bounded = min(max(caret, 0), (textView.text as NSString).length)
        textView.selectedRange = NSRange(location: bounded, length: length)
        commit()
    }

    private func commit() {
        guard let textView else { return }
        highlighter.apply(to: textView)
        onChange?(textView.text)
    }
}

/// UITextView wrapper: gives the editor a real caret, selection and inline
/// markdown highlighting that SwiftUI's TextEditor cannot express yet.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var isMonospaced: Bool
    var fontSize: CGFloat
    /// Dims every paragraph but the one holding the caret.
    var isFocusMode: Bool = false
    /// Keeps the caret line near the middle of the screen while typing.
    var isTypewriter: Bool = false
    /// Photos the text can place, drawn where their lines are.
    var photos: [NotePhoto] = []
    var photoData: (UUID) -> Data? = { _ in nil }
    var controller: EditorController

    func makeUIView(context: Context) -> UITextView {
        let view = MarkdownUITextView()
        view.controller = controller
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 24, right: 12)
        view.keyboardDismissMode = .interactive
        view.alwaysBounceVertical = true
        // A markdown editor is full of identifiers, tags and code. iOS
        // autocorrect rewrites `note-service` and `#spec` into prose, so the
        // whole correction stack stays off here.
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.autocapitalizationType = .sentences
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.tintColor = UIColor(PlainPalette.ink)
        view.text = text
        view.photos = photoIndex
        view.photoData = photoData
        controller.textView = view
        controller.onChange = { context.coordinator.push($0) }
        controller.highlighter = highlighter
        highlighter.configure(view)
        highlighter.apply(to: view)
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.highlighter = highlighter

        // While the user is typing, the text view is the source of truth.
        // Writing the binding back here would race with the keystrokes still in
        // flight and silently drop characters.
        let needsTextSync = view.text != text && !view.isFirstResponder
        if needsTextSync {
            view.text = text
            view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
        context.coordinator.isTypewriter = isTypewriter
        view.contentInset.bottom = isTypewriter ? view.bounds.height * 0.45 : 0

        var photosChanged = false
        if let view = view as? MarkdownUITextView {
            view.photoData = photoData
            photosChanged = view.photos != photoIndex
            if photosChanged { view.photos = photoIndex }
        }

        guard needsTextSync || photosChanged || context.coordinator.appliedStyle != highlighter else { return }
        context.coordinator.appliedStyle = highlighter
        highlighter.configure(view)
        highlighter.apply(to: view)
        context.coordinator.centreCaret(view)
    }

    private var photoIndex: [UUID: NotePhoto] {
        Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var highlighter: MarkdownSyntaxHighlighter {
        MarkdownSyntaxHighlighter(isMonospaced: isMonospaced, size: fontSize, dimsInactiveParagraphs: isFocusMode)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        var appliedStyle: MarkdownSyntaxHighlighter?
        var isTypewriter = false

        init(parent: MarkdownTextView) { self.parent = parent }

        /// Typing into or cutting through a photo's line is redirected, so the
        /// marker under the photo is never left half there.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let view = textView as? MarkdownUITextView, !view.isApplyingEdit,
                  let adjusted = view.photoSafeEdit(for: range, replacement: text) else { return true }
            switch adjusted {
            case .moveCaret(let location):
                textView.selectedRange = NSRange(location: location, length: 0)
            case .replace(let range, let replacement, let caret):
                parent.controller.replace(range, with: replacement, caret: caret)
            }
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.controller.highlighter.apply(to: textView)
            centreCaret(textView)
            push(textView.text)
        }

        /// Focus mode follows the caret, so moving it has to redraw.
        func textViewDidChangeSelection(_ textView: UITextView) {
            if parent.controller.highlighter.dimsInactiveParagraphs {
                parent.controller.highlighter.apply(to: textView)
            }
            centreCaret(textView)
        }

        /// Typewriter scrolling: the line being written sits near the middle of
        /// the screen instead of marching down to the keyboard.
        func centreCaret(_ textView: UITextView) {
            guard isTypewriter, textView.isFirstResponder, let selection = textView.selectedTextRange else { return }
            let caret = textView.caretRect(for: selection.end)
            guard caret.origin.y.isFinite, caret.height.isFinite else { return }
            let target = caret.midY - textView.bounds.height / 2
            let maximum = max(textView.contentSize.height + textView.contentInset.bottom - textView.bounds.height, 0)
            textView.setContentOffset(CGPoint(x: 0, y: min(max(target, 0), maximum)), animated: false)
        }

        func push(_ value: String) {
            guard parent.text != value else { return }
            parent.text = value
        }
    }
}

/// Lightweight highlighter: headings gain weight, syntax marks fade back,
/// `code` spans get a chip. Runs on every keystroke over the document.
struct MarkdownSyntaxHighlighter: Equatable {
    let isMonospaced: Bool
    let size: CGFloat
    var dimsInactiveParagraphs = false

    func configure(_ view: UITextView) {
        view.typingAttributes = [
            .font: baseFont(),
            .foregroundColor: UIColor(PlainPalette.ink)
        ]
    }

    func apply(to view: UITextView) {
        let storage = view.textStorage
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string as NSString
        let selected = view.selectedRange

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont(),
            .foregroundColor: UIColor(PlainPalette.ink)
        ], range: full)

        // Headings
        enumerate(pattern: "^(#{1,3})\\s+(.*)$", in: text, range: full) { match in
            let hashes = match.range(at: 1)
            let title = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: UIColor(PlainPalette.inkTertiary), range: hashes)
            storage.addAttribute(.font, value: boldFont(), range: title)
        }
        // Bullets and ordered markers
        enumerate(pattern: "^\\s*(-|\\d+\\.)\\s", in: text, range: full) { match in
            storage.addAttribute(.foregroundColor, value: UIColor(PlainPalette.inkTertiary), range: match.range(at: 1))
        }
        // Inline code
        enumerate(pattern: "`[^`\\n]+`", in: text, range: full) { match in
            storage.addAttribute(.backgroundColor, value: UIColor(PlainPalette.fill), range: match.range)
            storage.addAttribute(.foregroundColor, value: UIColor(PlainPalette.inkSecondary), range: match.range)
        }
        // Tags
        enumerate(pattern: "(^|\\s)(#[a-zA-Z0-9-]+)(?=\\s|$)", in: text, range: full) { match in
            storage.addAttribute(.foregroundColor, value: UIColor(PlainPalette.inkSecondary), range: match.range(at: 2))
        }
        // Photo lines: the marker turns invisible and the line as tall as
        // the photo that is drawn over it.
        let photoView = view as? MarkdownUITextView
        if let photoView {
            photoView.photoLines = photoView.findPhotoLines()
            for photo in photoView.photoLines {
                let style = NSMutableParagraphStyle()
                style.minimumLineHeight = photo.height + PhotoLine.gap * 2
                style.maximumLineHeight = style.minimumLineHeight
                storage.addAttributes([
                    .font: UIFont.systemFont(ofSize: 1),
                    .foregroundColor: UIColor.clear,
                    .paragraphStyle: style
                ], range: photo.line)
            }
        }
        if dimsInactiveParagraphs { dim(view) }
        storage.endEditing()

        view.selectedRange = selected
        // The character before the caret may be a hidden photo marker; what is
        // typed next should not inherit its invisible style.
        configure(view)
        photoView?.layoutPhotoTiles()
    }

    /// Focus mode: everything but the caret's own paragraph fades back.
    private func dim(_ view: UITextView) {
        let storage = view.textStorage
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0 else { return }
        let active = (view.text as NSString).paragraphRange(for: view.selectedRange)

        storage.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            guard let colour = value as? UIColor else { return }
            for piece in range.subtracting(active) {
                storage.addAttribute(.foregroundColor, value: colour.withAlphaComponent(0.25), range: piece)
            }
        }
    }

    private func enumerate(pattern: String, in text: NSString, range: NSRange, body: (NSTextCheckingResult) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        regex.enumerateMatches(in: text as String, options: [], range: range) { match, _, _ in
            guard let match else { return }
            body(match)
        }
    }

    private func baseFont() -> UIFont {
        isMonospaced
            ? UIFont.monospacedSystemFont(ofSize: size - 1, weight: .regular)
            : UIFont(name: "Figtree-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    private func boldFont() -> UIFont {
        isMonospaced
            ? UIFont.monospacedSystemFont(ofSize: size - 1, weight: .semibold)
            : UIFont(name: "Figtree-SemiBold", size: size) ?? .systemFont(ofSize: size, weight: .semibold)
    }
}


extension UITextView {
    /// `UITextInput` works in `UITextPosition`s, the text storage in `NSRange`s.
    func plainTextRange(for range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length) else { return nil }
        return textRange(from: start, to: end)
    }
}

extension NSRange {
    /// The parts of this range that fall outside `other`.
    func subtracting(_ other: NSRange) -> [NSRange] {
        let overlap = intersection(other)
        guard let overlap, overlap.length > 0 else { return [self] }
        var pieces: [NSRange] = []
        if overlap.location > location {
            pieces.append(NSRange(location: location, length: overlap.location - location))
        }
        let end = location + length
        let overlapEnd = overlap.location + overlap.length
        if overlapEnd < end {
            pieces.append(NSRange(location: overlapEnd, length: end - overlapEnd))
        }
        return pieces
    }
}

/// A text view that answers an attached keyboard: ⌘B, ⌘I, ⌘K and ⌘⇧C do what
/// the shortcut bar does.
final class MarkdownUITextView: UITextView {
    weak var controller: EditorController?

    var photos: [UUID: NotePhoto] = [:]
    var photoData: (UUID) -> Data? = { _ in nil }
    var photoLines: [PhotoLine] = []
    var photoTiles: [PhotoTileView] = []
    var draggedTile: PhotoTileView?
    var dragOffset: CGFloat = 0
    let dropIndicator = UIView()
    /// Set while the controller edits, so its own changes are not redirected.
    var isApplyingEdit = false
    private var laidOutWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        // Photo heights follow the width, so a new width needs a new pass.
        guard bounds.width != laidOutWidth else { return }
        laidOutWidth = bounds.width
        if !photos.isEmpty { controller?.highlighter.apply(to: self) }
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(title: "Bold", action: #selector(plainBold), input: "b", modifierFlags: .command),
            UIKeyCommand(title: "Italic", action: #selector(plainItalic), input: "i", modifierFlags: .command),
            UIKeyCommand(title: "Code", action: #selector(plainCode), input: "k", modifierFlags: .command),
            UIKeyCommand(title: "Heading", action: #selector(plainHeading), input: "h", modifierFlags: [.command, .shift]),
            UIKeyCommand(title: "Checkbox", action: #selector(plainCheckbox), input: "l", modifierFlags: [.command, .shift])
        ]
    }

    @objc private func plainBold() { controller?.wrapSelection(with: "**") }
    @objc private func plainItalic() { controller?.wrapSelection(with: "*") }
    @objc private func plainCode() { controller?.wrapSelection(with: "`") }
    @objc private func plainHeading() { controller?.toggleLinePrefix("# ") }
    @objc private func plainCheckbox() { controller?.insert("- [ ] ") }
}
