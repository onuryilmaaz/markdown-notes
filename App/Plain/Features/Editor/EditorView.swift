import SwiftUI
import PlainDomain
import PlainDesignSystem

/// How the editing screen is split between writing and reading.
enum EditorMode: String, CaseIterable, Identifiable {
    case write, split, read

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .write: "pencil"
        case .split: "rectangle.split.1x2"
        case .read: "eye"
        }
    }
}

struct EditorView: View {
    let noteID: UUID

    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings

    @State private var text: String = ""
    @State private var mode: EditorMode = .write
    @State private var controller = EditorController()
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        @Bindable var settings = settings

        PlainScreen {
            VStack(spacing: 12) {
                Text("Mononote")
                    .font(PlainFont.headline)
                    .foregroundStyle(PlainPalette.ink)
                    .padding(.top, 10)

                ShortcutBar(
                    controller: controller,
                    mode: $mode,
                    focusMode: $settings.focusMode,
                    typewriterMode: $settings.typewriterMode
                )
                .padding(.horizontal, Metrics.Space.gutter)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Metrics.Space.gutter)

                PillButton("Done") { finish() }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 6)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .onAppear {
            text = store.note(noteID)?.body ?? ""
            #if DEBUG
            if let requested = ProcessInfo.processInfo.environment["PLAIN_EDITOR_MODE"],
               let parsed = EditorMode(rawValue: requested) {
                mode = parsed
            }
            #endif
        }
        .onChange(of: text) { _, _ in persist(immediately: false) }
        .onDisappear { persist(immediately: true) }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .write:
            editor.plainCard()
        case .read:
            preview.plainCard()
        case .split:
            // Write above, render below — the same note twice, so a long
            // document stays navigable while it is being written.
            VStack(spacing: 10) {
                editor.plainCard()
                preview.plainCard()
            }
        }
    }

    private var editor: some View {
        MarkdownTextView(
            text: $text,
            isMonospaced: settings.monospaceEditor,
            fontSize: settings.textSize,
            isFocusMode: settings.focusMode,
            isTypewriter: settings.typewriterMode,
            controller: controller
        )
    }

    private var preview: some View {
        ScrollView {
            MarkdownRenderedView(document: MarkdownDocument(parsing: text), bodySize: settings.textSize - 1)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func finish() {
        controller.resign()
        persist(immediately: true)
        router.pop()
    }

    /// Debounced autosave; `Done` and leaving the screen flush it.
    private func persist(immediately: Bool) {
        saveTask?.cancel()
        guard var note = store.note(noteID) else { return }
        note.body = text

        if immediately {
            store.update(note)
            return
        }
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            store.update(note)
        }
    }
}

/// H1 H2 B i ` [ ] [[ ]] — the markdown shortcut bar, with the view options
/// tucked behind the eye on the right.
struct ShortcutBar: View {
    let controller: EditorController
    @Binding var mode: EditorMode
    @Binding var focusMode: Bool
    @Binding var typewriterMode: Bool

    var body: some View {
        HStack(spacing: 6) {
            key("H1", label: "Heading 1", isEmphasised: true) { controller.toggleLinePrefix("# ") }
            key("H2", label: "Heading 2") { controller.toggleLinePrefix("## ") }
            key("B", label: "Bold", font: PlainFont.sans(13, .bold)) { controller.wrapSelection(with: "**") }
            key("i", label: "Italic", font: PlainFont.sans(13, .medium).italic()) { controller.wrapSelection(with: "*") }
            key("`", label: "Inline code", font: PlainFont.mono(13)) { controller.wrapSelection(with: "`") }
            key("-", label: "Bullet", font: PlainFont.mono(13)) { controller.toggleLinePrefix("- ") }
            key("[ ]", label: "Checkbox", font: PlainFont.mono(12)) { controller.insert("- [ ] ") }
            // Opens a link to another note with the caret between the brackets.
            key("[[", label: "Link to a note", font: PlainFont.mono(12)) { controller.insert("[[]]", caretOffset: 2) }
            Spacer(minLength: 0)
            options
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .plainCard(radius: Metrics.Radius.inner)
    }

    private var options: some View {
        Menu {
            Picker("View", selection: $mode) {
                ForEach(EditorMode.allCases) { option in
                    Label(LocalizedStringKey(option.label), systemImage: option.icon).tag(option)
                }
            }
            Toggle("Focus mode", isOn: $focusMode)
            Toggle("Typewriter", isOn: $typewriterMode)
        } label: {
            Image(systemName: mode == .write ? "eye" : "eye.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PlainPalette.ink)
                .frame(width: 32, height: 30)
        }
        .accessibilityIdentifier("editor-options")
        .accessibilityLabel("View options")
    }

    private func key(
        _ title: String,
        label: LocalizedStringKey,
        font: Font = PlainFont.sans(12.5, .semibold),
        isEmphasised: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(isEmphasised ? PlainPalette.onEmphasis : PlainPalette.ink)
                .frame(minWidth: 28, minHeight: 30)
                .padding(.horizontal, 3)
                .background(isEmphasised ? PlainPalette.emphasis : Color.clear, in: .capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}
