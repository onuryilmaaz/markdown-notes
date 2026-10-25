import SwiftUI
import PlainDesignSystem

/// "Nothing here yet" — a tall empty card with a glyph, used by empty folders
/// and empty search states.
struct EmptyStateCard: View {
    let glyph: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(glyph)
                .font(PlainFont.mono(20, .medium))
                .foregroundStyle(PlainPalette.inkTertiary)
                .frame(width: 46, height: 46)
                .background(PlainPalette.fill, in: .rect(cornerRadius: 14, style: .continuous))
                .padding(.bottom, 6)
            Text(title)
                .font(PlainFont.headline)
                .foregroundStyle(PlainPalette.ink)
            Text(message)
                .font(PlainFont.callout)
                .foregroundStyle(PlainPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .plainCard()
    }
}
