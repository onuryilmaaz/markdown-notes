import SwiftUI

/// The black (or, in dark mode, white) capsule that ends most screens.
public struct PillButton: View {
    public enum Style { case emphasis, plain, destructive }

    private let title: LocalizedStringKey
    private let systemImage: String?
    private let style: Style
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String? = nil, style: Style = .emphasis, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(PlainFont.button)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.controlHeight)
            .background(background, in: .capsule)
            .overlay {
                if style == .plain {
                    Capsule().strokeBorder(PlainPalette.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var background: Color {
        switch style {
        case .emphasis: PlainPalette.emphasis
        case .plain: PlainPalette.surface
        case .destructive: PlainPalette.surface
        }
    }

    private var foreground: Color {
        switch style {
        case .emphasis: PlainPalette.onEmphasis
        case .plain: PlainPalette.ink
        case .destructive: PlainPalette.destructive
        }
    }
}

/// Circular icon button — the satellites either side of a pill.
public struct CircleIconButton: View {
    public enum Style { case surface, emphasis, ghost }

    private let systemImage: String
    /// An icon alone says nothing to VoiceOver, so every one of these carries
    /// the word for what it does.
    private let label: LocalizedStringKey
    private let style: Style
    private let size: CGFloat
    private let action: () -> Void

    public init(
        _ systemImage: String,
        label: LocalizedStringKey,
        style: Style = .surface,
        size: CGFloat = Metrics.circleButton,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.style = style
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(style == .emphasis ? PlainPalette.onEmphasis : PlainPalette.ink)
                .frame(width: size, height: size)
                .background(style == .ghost ? Color.clear : (style == .emphasis ? PlainPalette.emphasis : PlainPalette.surface), in: .circle)
                .modifier(CircleShadow(enabled: style != .ghost))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}

private struct CircleShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled, scheme == .dark {
                    Circle().strokeBorder(PlainPalette.hairline, lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(enabled && scheme == .light ? 0.06 : 0), radius: 10, y: 4)
    }
}

public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
