import SwiftUI

public enum Metrics {
    public enum Radius {
        public static let card: CGFloat = 22
        public static let inner: CGFloat = 16
        public static let control: CGFloat = 13
        public static let sheet: CGFloat = 28
        public static let screen: CGFloat = 34
    }

    public enum Space {
        public static let hairlineInset: CGFloat = 16
        public static let gutter: CGFloat = 16
        public static let card: CGFloat = 16
        public static let stack: CGFloat = 12
    }

    public static let controlHeight: CGFloat = 52
    public static let circleButton: CGFloat = 44
}

/// The single soft shadow the whole design leans on. Dark mode drops it and
/// draws a hairline instead — shadows are invisible on black.
public struct PlainCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    let radius: CGFloat
    let background: Color

    public func body(content: Content) -> some View {
        content
            .background(background, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(PlainPalette.hairline, lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 14, x: 0, y: 6)
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.03), radius: 2, x: 0, y: 1)
    }
}

public extension View {
    func plainCard(radius: CGFloat = Metrics.Radius.card, background: Color = PlainPalette.surface) -> some View {
        modifier(PlainCardStyle(radius: radius, background: background))
    }

    /// Full-bleed grey page background used by every screen.
    func plainGround() -> some View {
        background(PlainPalette.ground.ignoresSafeArea())
    }
}
