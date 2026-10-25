import SwiftUI

/// Three-up selector on a fill track with a sliding ink knob (Appearance,
/// link access, editor mode).
public struct SegmentedPill<Value: Hashable>: View {
    private let options: [(value: Value, label: LocalizedStringKey)]
    @Binding private var selection: Value
    @Namespace private var namespace

    public init(selection: Binding<Value>, options: [(value: Value, label: LocalizedStringKey)]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(PlainFont.sans(13.5, isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? PlainPalette.onEmphasis : PlainPalette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(PlainPalette.emphasis)
                                    .matchedGeometryEffect(id: "knob", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(PlainPalette.fill, in: .capsule)
    }
}
