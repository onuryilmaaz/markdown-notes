import UIKit
import PlainDomain
import PlainDesignSystem

/// A photo placed in the text being edited. Its `![](photo:…)` line stays in
/// the text — invisible, and as tall as the photo drawn over it — so the body
/// is still the single source of truth and undo keeps working.
struct PhotoLine: Equatable {
    static let gap: CGFloat = 8

    let id: UUID
    /// The marker itself, without its line break.
    let content: NSRange
    /// The whole line, line break included when there is one.
    let line: NSRange
    let height: CGFloat
}

/// What a keystroke near a photo turns into, so it can never leave half a
/// marker behind.
enum PhotoSafeEdit {
    case moveCaret(Int)
    case replace(NSRange, String, caret: Int)
}

enum PhotoTileAction {
    case moveUp, moveDown, removeFromText, delete
}

extension MarkdownUITextView {
    private static let photoPattern = try? NSRegularExpression(
        pattern: "^[ \\t]*!\\[[^\\]\\n]*\\]\\(\(PhotoMarkdown.scheme):([0-9A-Fa-f-]{36})\\)[ \\t]*$",
        options: [.anchorsMatchLines]
    )

    /// Lines that place a photo this note owns. A marker for anything else
    /// stays visible as text, so it can be seen and deleted.
    func findPhotoLines() -> [PhotoLine] {
        guard !photos.isEmpty, let pattern = Self.photoPattern else { return [] }
        let text = self.text as NSString
        let width = max(textContainer.size.width - textContainer.lineFragmentPadding * 2, 120)
        return pattern.matches(in: self.text, range: NSRange(location: 0, length: text.length)).compactMap { match in
            guard let id = UUID(uuidString: text.substring(with: match.range(at: 1))), let photo = photos[id] else { return nil }
            return PhotoLine(
                id: id,
                content: match.range,
                line: text.lineRange(for: match.range),
                height: (width / PhotoCache.displayAspect(of: photo)).rounded()
            )
        }
    }

    // MARK: Drawing

    func layoutPhotoTiles() {
        guard let layout = textLayoutManager, let content = layout.textContentManager else { return }
        while photoTiles.count < photoLines.count {
            let tile = PhotoTileView()
            tile.onAction = { [weak self, weak tile] action in
                guard let self, let tile else { return }
                self.perform(action, onTileAt: tile.tag)
            }
            tile.onTap = { [weak self, weak tile] in
                guard let self, let tile, self.photoLines.indices.contains(tile.tag) else { return }
                // Carry on writing just below the photo.
                self.selectedRange = NSRange(location: NSMaxRange(self.photoLines[tile.tag].line), length: 0)
                self.becomeFirstResponder()
            }
            tile.dragGesture.addTarget(self, action: #selector(dragTile(_:)))
            addSubview(tile)
            photoTiles.append(tile)
        }
        if !photoLines.isEmpty { layout.ensureLayout(for: layout.documentRange) }

        let x = textContainerInset.left + textContainer.lineFragmentPadding
        let width = textContainer.size.width - textContainer.lineFragmentPadding * 2
        for (index, tile) in photoTiles.enumerated() {
            guard photoLines.indices.contains(index),
                  let start = content.location(content.documentRange.location, offsetBy: photoLines[index].content.location),
                  let fragment = layout.textLayoutFragment(for: start) else {
                tile.isHidden = true
                continue
            }
            let line = photoLines[index]
            tile.isHidden = false
            tile.tag = index
            if tile.photoID != line.id, let photo = photos[line.id] {
                tile.photoID = line.id
                tile.imageView.image = PhotoCache.shared.image(for: photo, data: photoData)
                tile.imageView.accessibilityIdentifier = "editor-photo-\(line.id)"
            }
            guard tile !== draggedTile else { continue }
            tile.frame = CGRect(
                x: x,
                y: fragment.layoutFragmentFrame.minY + textContainerInset.top + PhotoLine.gap,
                width: width,
                height: line.height
            )
        }
    }

    // MARK: Editing around a photo

    /// Adjusts an edit that would type into, or cut through, a photo's line.
    /// Nil means the edit is fine as it is.
    func photoSafeEdit(for range: NSRange, replacement: String) -> PhotoSafeEdit? {
        guard !photoLines.isEmpty else { return nil }
        let text = self.text as NSString
        let typed = (replacement as NSString).length

        if range.length == 0 {
            for photo in photoLines {
                let marker = photo.content
                let end = NSMaxRange(marker)
                // Typing on a photo's line starts a new line below it…
                if (range.location > marker.location && range.location < end)
                    || (range.location == end && !replacement.hasPrefix("\n")) {
                    return .replace(NSRange(location: end, length: 0), "\n" + replacement, caret: end + 1 + typed)
                }
                // …or, at its very start, a new line above it.
                if range.location == marker.location, !replacement.hasSuffix("\n") {
                    return .replace(NSRange(location: marker.location, length: 0), replacement + "\n", caret: marker.location + typed)
                }
            }
            return nil
        }

        // Backspace at the start of a photo's line would glue the marker onto
        // the line above. Step over the line break instead, unless the line
        // above is blank and can simply go.
        if replacement.isEmpty, range.length == 1, text.character(at: range.location) == 10,
           photoLines.contains(where: { $0.content.location == NSMaxRange(range) }) {
            let lineAboveIsBlank = range.location == 0 || text.character(at: range.location - 1) == 10
            return lineAboveIsBlank ? nil : .moveCaret(range.location)
        }

        // Anything that cuts into a photo's line takes the whole line, so the
        // photo leaves the text cleanly and comes back with undo.
        var expanded = range
        for photo in photoLines {
            let overlap = NSIntersectionRange(expanded, photo.line)
            if overlap.length > 0, overlap != photo.line {
                expanded = NSUnionRange(expanded, photo.line)
            }
        }
        guard expanded != range else { return nil }
        return .replace(expanded, replacement, caret: expanded.location + typed)
    }

    private func perform(_ action: PhotoTileAction, onTileAt index: Int) {
        guard photoLines.indices.contains(index), let controller else { return }
        let photo = photoLines[index]
        switch action {
        case .moveUp:
            if let target = lineStart(before: photo.line.location) { controller.moveLine(photo.line, to: target) }
        case .moveDown:
            if let target = lineEnd(after: NSMaxRange(photo.line)) { controller.moveLine(photo.line, to: target) }
        case .removeFromText:
            controller.replace(photo.line, with: "", caret: photo.line.location)
        case .delete:
            controller.replace(photo.line, with: "", caret: photo.line.location)
            controller.onDeletePhoto?(photo.id)
        }
    }

    /// The start of the nearest line above that has something on it.
    private func lineStart(before location: Int) -> Int? {
        let text = self.text as NSString
        var cursor = location
        while cursor > 0 {
            let line = text.lineRange(for: NSRange(location: cursor - 1, length: 0))
            if !text.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return line.location }
            cursor = line.location
        }
        return nil
    }

    /// The end of the nearest line below that has something on it.
    private func lineEnd(after location: Int) -> Int? {
        let text = self.text as NSString
        var cursor = location
        while cursor < text.length {
            let line = text.lineRange(for: NSRange(location: cursor, length: 0))
            if !text.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return NSMaxRange(line) }
            cursor = NSMaxRange(line)
        }
        return nil
    }

    // MARK: Dragging

    @objc private func dragTile(_ gesture: UILongPressGestureRecognizer) {
        guard let tile = gesture.view?.superview as? PhotoTileView, photoLines.indices.contains(tile.tag) else { return }
        let point = gesture.location(in: self)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        switch gesture.state {
        case .began:
            draggedTile = tile
            dragOffset = point.y - tile.center.y
            bringSubviewToFront(tile)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIView.animate(withDuration: reduceMotion ? 0 : 0.2) {
                tile.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                tile.alpha = 0.85
            }
            dropIndicator.backgroundColor = UIColor(PlainPalette.ink)
            dropIndicator.layer.cornerRadius = 1.5
            addSubview(dropIndicator)
        case .changed:
            tile.center.y = point.y - dragOffset
            scrollWhileDragging(near: point)
            let target = dropTarget(for: point)
            let x = textContainerInset.left + textContainer.lineFragmentPadding
            dropIndicator.frame = CGRect(x: x, y: target.y - 1.5, width: textContainer.size.width - textContainer.lineFragmentPadding * 2, height: 3)
        case .ended:
            let line = photoLines[tile.tag].line
            let target = dropTarget(for: point).offset
            endDrag(tile, animated: !reduceMotion)
            controller?.moveLine(line, to: target)
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            endDrag(tile, animated: !reduceMotion)
        }
    }

    private func endDrag(_ tile: PhotoTileView, animated: Bool) {
        draggedTile = nil
        dropIndicator.removeFromSuperview()
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            tile.transform = .identity
            tile.alpha = 1
            self.layoutPhotoTiles()
        }
    }

    /// Before or after the paragraph under the finger, whichever half it is in.
    private func dropTarget(for point: CGPoint) -> (offset: Int, y: CGFloat) {
        let length = (text as NSString).length
        guard let layout = textLayoutManager, let content = layout.textContentManager,
              let fragment = layout.textLayoutFragment(for: CGPoint(x: 1, y: point.y - textContainerInset.top)) else {
            return (length, contentSize.height - textContainerInset.bottom)
        }
        let frame = fragment.layoutFragmentFrame
        let start = content.documentRange.location
        let after = point.y - textContainerInset.top > frame.midY
        let offset = content.offset(from: start, to: after ? fragment.rangeInElement.endLocation : fragment.rangeInElement.location)
        return (min(max(offset, 0), length), (after ? frame.maxY : frame.minY) + textContainerInset.top)
    }

    private func scrollWhileDragging(near point: CGPoint) {
        let visible = point.y - contentOffset.y
        let top = -adjustedContentInset.top
        let bottom = max(contentSize.height - bounds.height + adjustedContentInset.bottom, top)
        if visible < 60 {
            contentOffset.y = max(contentOffset.y - 12, top)
        } else if visible > bounds.height - 60 {
            contentOffset.y = min(contentOffset.y + 12, bottom)
        }
    }
}

/// The photo drawn over its line: tap to write below it, hold to drag it to
/// another spot, or use the menu.
final class PhotoTileView: UIView {
    let imageView = UIImageView()
    let dragGesture = UILongPressGestureRecognizer()
    var photoID: UUID?
    var onAction: ((PhotoTileAction) -> Void)?
    var onTap: (() -> Void)?

    private let menuButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Metrics.Radius.inner
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = UIColor(PlainPalette.fill)
        imageView.isUserInteractionEnabled = true
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = String(localized: "Photo")
        imageView.accessibilityHint = String(localized: "Hold and drag to move it.")
        imageView.accessibilityCustomActions = [
            action("Move up", .moveUp),
            action("Move down", .moveDown),
            action("Remove from text", .removeFromText),
            action("Delete photo", .delete)
        ]
        addSubview(imageView)

        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .black
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 7, bottom: 9, trailing: 7)
        menuButton.configuration = configuration
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.accessibilityLabel = String(localized: "Photo options")
        menuButton.accessibilityIdentifier = "photo-options"
        menuButton.menu = UIMenu(children: [
            UIAction(title: String(localized: "Move up"), image: UIImage(systemName: "arrow.up")) { [weak self] _ in self?.onAction?(.moveUp) },
            UIAction(title: String(localized: "Move down"), image: UIImage(systemName: "arrow.down")) { [weak self] _ in self?.onAction?(.moveDown) },
            UIAction(title: String(localized: "Remove from text"), image: UIImage(systemName: "text.badge.minus")) { [weak self] _ in self?.onAction?(.removeFromText) },
            // A nested menu is the confirmation: deleting cannot be undone.
            UIMenu(title: String(localized: "Delete photo"), image: UIImage(systemName: "trash"), options: .destructive, children: [
                UIAction(title: String(localized: "Delete photo"), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.onAction?(.delete) }
            ])
        ])
        addSubview(menuButton)

        dragGesture.minimumPressDuration = 0.3
        imageView.addGestureRecognizer(dragGesture)
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let size = menuButton.intrinsicContentSize
        menuButton.frame = CGRect(x: bounds.width - size.width - 10, y: 10, width: size.width, height: size.height)
    }

    @objc private func tapped() { onTap?() }

    private func action(_ title: String.LocalizationValue, _ kind: PhotoTileAction) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: title)) { [weak self] _ in
            self?.onAction?(kind)
            return true
        }
    }
}
