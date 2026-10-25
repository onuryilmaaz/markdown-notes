import SwiftUI

public struct PlainDivider: View {
    private let inset: CGFloat

    public init(inset: CGFloat = Metrics.Space.hairlineInset) {
        self.inset = inset
    }

    public var body: some View {
        Rectangle()
            .fill(PlainPalette.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

/// `Title …………… value ›` — the settings and tag list workhorse.
public struct ValueRow: View {
    private let title: Text
    /// The value is data — a count, a size, a date — so it is not translated.
    private let value: String?
    private let showsChevron: Bool
    private let action: (() -> Void)?

    public init(_ title: LocalizedStringKey, value: String? = nil, showsChevron: Bool = true, action: (() -> Void)? = nil) {
        self.init(label: Text(title), value: value, showsChevron: showsChevron, action: action)
    }

    /// For rows whose title is the user's own words — a tag, a folder — which
    /// must never be looked up in a translation table.
    public init(verbatim title: String, value: String? = nil, showsChevron: Bool = true, action: (() -> Void)? = nil) {
        self.init(label: Text(verbatim: title), value: value, showsChevron: showsChevron, action: action)
    }

    private init(label: Text, value: String?, showsChevron: Bool, action: (() -> Void)?) {
        self.title = label
        self.value = value
        self.showsChevron = showsChevron
        self.action = action
    }

    public var body: some View {
        let content = HStack(spacing: 10) {
            title
                .font(PlainFont.body)
                .foregroundStyle(PlainPalette.ink)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(PlainFont.label)
                    .foregroundStyle(PlainPalette.inkSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PlainPalette.inkTertiary)
            }
        }
        .padding(.horizontal, Metrics.Space.card)
        .frame(height: 52)
        .contentShape(.rect)

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

public struct ToggleRow: View {
    private let title: LocalizedStringKey
    @Binding private var isOn: Bool

    public init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(PlainFont.body)
                .foregroundStyle(PlainPalette.ink)
        }
        .tint(PlainPalette.emphasis)
        .padding(.horizontal, Metrics.Space.card)
        .frame(height: 52)
    }
}

/// Screen chrome: circular back button, centred title (optionally with a
/// caption underneath), trailing control.
public struct ScreenHeader<Trailing: View>: View {
    private let title: Text
    private let caption: Text?
    private let onBack: (() -> Void)?
    private let backIcon: String
    private let backLabel: LocalizedStringKey
    private let trailing: Trailing

    /// A screen whose title is written in the app.
    public init(
        title: LocalizedStringKey,
        caption: LocalizedStringKey? = nil,
        backIcon: String = "chevron.left",
        backLabel: LocalizedStringKey = "Back",
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.init(
            label: Text(title),
            captionLabel: caption.map { Text($0) },
            backIcon: backIcon,
            backLabel: backLabel,
            onBack: onBack,
            trailing: trailing()
        )
    }

    /// A screen titled with the user's own words — a folder, a note — and
    /// optionally captioned with data such as a date.
    public init(
        verbatimTitle: String,
        caption: LocalizedStringKey? = nil,
        verbatimCaption: String? = nil,
        backIcon: String = "chevron.left",
        backLabel: LocalizedStringKey = "Back",
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.init(
            label: Text(verbatim: verbatimTitle),
            captionLabel: verbatimCaption.map { Text(verbatim: $0) } ?? caption.map { Text($0) },
            backIcon: backIcon,
            backLabel: backLabel,
            onBack: onBack,
            trailing: trailing()
        )
    }

    private init(label: Text, captionLabel: Text?, backIcon: String, backLabel: LocalizedStringKey, onBack: (() -> Void)?, trailing: Trailing) {
        self.title = label
        self.caption = captionLabel
        self.backIcon = backIcon
        self.backLabel = backLabel
        self.onBack = onBack
        self.trailing = trailing
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 2) {
                title
                    .font(PlainFont.headline)
                    .foregroundStyle(PlainPalette.ink)
                if let caption {
                    caption
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
            }
            HStack {
                if let onBack {
                    CircleIconButton(backIcon, label: backLabel, size: 38, action: onBack)
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .padding(.vertical, 10)
    }
}
