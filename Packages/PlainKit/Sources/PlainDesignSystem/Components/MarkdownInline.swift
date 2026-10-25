import SwiftUI
import PlainDomain

/// Inline markdown (bold, italic, `code`) rendered as an AttributedString so a
/// paragraph stays a single Text — no view soup, no broken line breaking.
public enum MarkdownInline {
    public static func attributed(
        _ source: String,
        size: CGFloat,
        weight: PlainFont.Weight = .regular,
        color: Color = PlainPalette.ink,
        codeBackground: Color = PlainPalette.fill
    ) -> AttributedString {
        var attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: linkified(source),
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attributed = AttributedString(source)
        }

        attributed.font = PlainFont.sans(size, weight)
        attributed.foregroundColor = color

        for run in attributed.runs where run.link != nil {
            attributed[run.range].foregroundColor = color
            attributed[run.range].font = PlainFont.sans(size, .semibold)
            attributed[run.range].underlineStyle = .single
        }

        for run in attributed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let range = run.range
            if intent.contains(.code) {
                attributed[range].font = PlainFont.mono(size - 1.5)
                attributed[range].backgroundColor = codeBackground
            }
            if intent.contains(.stronglyEmphasized) {
                attributed[range].font = PlainFont.sans(size, .semibold)
            }
            if intent.contains(.emphasized) {
                attributed[range].font = PlainFont.sans(size, weight).italic()
            }
        }
        return attributed
    }

    /// `[[Another note]]` is not markdown, so it is rewritten as a real link
    /// before parsing. Replacing from the end keeps the earlier ranges valid.
    private static func linkified(_ source: String) -> String {
        var result = source
        for match in WikiLink.matches(in: source).reversed() {
            guard let url = WikiLink.url(for: match.text) else { continue }
            result.replaceSubrange(match.range, with: "[\(match.text)](\(url.absoluteString))")
        }
        return result
    }

    /// Search results highlight the matched term with an ink chip.
    public static func highlighted(_ source: String, term: String, size: CGFloat) -> AttributedString {
        var attributed = AttributedString(source)
        attributed.font = PlainFont.sans(size, .regular)
        attributed.foregroundColor = PlainPalette.inkSecondary

        guard !term.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(of: term, options: .caseInsensitive) {
            attributed[found].backgroundColor = PlainPalette.emphasis
            attributed[found].foregroundColor = PlainPalette.onEmphasis
            attributed[found].font = PlainFont.sans(size, .semibold)
            guard found.upperBound < attributed.endIndex else { break }
            searchRange = found.upperBound..<attributed.endIndex
        }
        return attributed
    }
}
