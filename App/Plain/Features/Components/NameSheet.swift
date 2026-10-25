import SwiftUI
import PlainDesignSystem

/// One text field on the grey ground — new folder, rename, and the profile card.
struct NameSheet: View {
    enum Mode: Hashable {
        case create
        case rename(UUID)
    }

    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let mode: Mode

    @Environment(NotesStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var value = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(PlainFont.title)
                .foregroundStyle(PlainPalette.ink)
                .padding(.top, 8)

            field(placeholder, text: $value)
                .plainCard(radius: Metrics.Radius.inner)

            PillButton("Save") { save() }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: prefill)
    }

    private func field(_ prompt: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .font(PlainFont.body)
            .foregroundStyle(PlainPalette.ink)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, 14)
            .frame(height: 50)
    }

    private func prefill() {
        switch mode {
        case .create:
            value = ""
        case .rename(let id):
            value = store.folder(id)?.name ?? ""
        }
        isFocused = true
    }

    private func save() {
        switch mode {
        case .create:
            store.createFolder(named: value)
        case .rename(let id):
            store.renameFolder(id, to: value)
        }
        dismiss()
    }
}
