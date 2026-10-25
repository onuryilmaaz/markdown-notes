import Foundation

/// `[[Another note]]` — the link that turns a folder of files into a web of
/// notes. Matching is by title, case- and whitespace-insensitive, because that
/// is how people type them.
public enum WikiLink {
    public static let scheme = "plain-note"

    /// Every `[[target]]` in a body, in order, without duplicates.
    public static func targets(in source: String) -> [String] {
        var found: [String] = []
        for match in matches(in: source) {
            let name = match.text
            guard !found.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
            found.append(name)
        }
        return found
    }

    /// Ranges so a renderer can swap the raw `[[…]]` for a link.
    public static func matches(in source: String) -> [(range: Range<String.Index>, text: String)] {
        guard let regex = try? NSRegularExpression(pattern: "\\[\\[([^\\[\\]\\n]+)\\]\\]") else { return [] }
        let nsSource = source as NSString
        return regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length)).compactMap { match in
            guard match.numberOfRanges == 2,
                  let full = Range(match.range, in: source),
                  let inner = Range(match.range(at: 1), in: source) else { return nil }
            let text = String(source[inner]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return (full, text)
        }
    }

    public static func url(for target: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "title", value: target)]
        return components.url
    }

    public static func target(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "title" }?
            .value
    }

    public static func matches(_ title: String, _ target: String) -> Bool {
        title.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(target.trimmingCharacters(in: .whitespaces)) == .orderedSame
    }
}

public extension Note {
    /// Titles this note points at.
    var linkedTitles: [String] { WikiLink.targets(in: body) }

    /// True when this note links to the given title.
    func links(to title: String) -> Bool {
        linkedTitles.contains { WikiLink.matches(title, $0) }
    }
}
