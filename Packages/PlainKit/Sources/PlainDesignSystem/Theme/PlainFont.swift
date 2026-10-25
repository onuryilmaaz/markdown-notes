import SwiftUI

/// One heavy geometric sans does everything from the 44pt counter down to the
/// 11pt meta line; monospace is reserved for markdown and code.
public enum PlainFont {
    public enum Weight {
        case regular, medium, semibold, bold, extrabold

        var faceName: String {
            switch self {
            case .regular: "Figtree-Regular"
            case .medium: "Figtree-Medium"
            case .semibold: "Figtree-SemiBold"
            case .bold: "Figtree-Bold"
            case .extrabold: "Figtree-ExtraBold"
            }
        }

        var systemFallback: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .extrabold: .heavy
            }
        }
    }

    public static func sans(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.faceName, size: size, relativeTo: style)
    }

    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Semantic ramp — features name the role, never the number.
    public static let counter = sans(44, .extrabold, relativeTo: .largeTitle)
    public static let display = sans(30, .extrabold, relativeTo: .largeTitle)
    public static let title = sans(23, .bold, relativeTo: .title2)
    public static let headline = sans(16, .semibold, relativeTo: .headline)
    public static let cardTitle = sans(15, .semibold, relativeTo: .headline)
    public static let body = sans(15, .regular, relativeTo: .body)
    public static let callout = sans(13.5, .regular, relativeTo: .callout)
    public static let label = sans(14, .medium, relativeTo: .subheadline)
    public static let button = sans(15, .semibold, relativeTo: .headline)
    public static let meta = sans(11, .medium, relativeTo: .caption2)
    public static let tag = sans(12.5, .medium, relativeTo: .caption)
}
