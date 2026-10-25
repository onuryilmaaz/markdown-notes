import SwiftUI
import PlainDomain
import PlainDesignSystem
import PhotosUI

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
    @Environment(PurchaseStore.self) private var purchases

    @State private var text: String = ""
    @State private var mode: EditorMode = .write
    @State private var controller = EditorController()
    @State private var saveTask: Task<Void, Never>?
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var photoImportFailed = false
    @State private var importedPhotoCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PlainScreen {
            VStack(spacing: 12) {
                HStack {
                    Text("Plain").font(PlainFont.headline)
                    Spacer()
                    if isImportingPhotos { ProgressView() }
                    PhotosPicker(selection: $photoSelection, maxSelectionCount: 5, matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                            .font(PlainFont.label)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(PlainPalette.surface, in: .capsule)
                    }
                    .disabled(isImportingPhotos)
                    .accessibilityIdentifier("add-photos")
                }
                .foregroundStyle(PlainPalette.ink)
                .padding(.horizontal, Metrics.Space.gutter)
                .padding(.top, 6)

                ShortcutBar(
                    controller: controller,
                    mode: $mode,
                    focusMode: proPreference(\.focusMode),
                    typewriterMode: proPreference(\.typewriterMode)
                )
                .padding(.horizontal, Metrics.Space.gutter)

                // Photos already in the text are drawn there; the rest wait
                // here until they are tapped into place.
                if !unplacedPhotos.isEmpty {
                    NotePhotoGallery(photos: unplacedPhotos, editable: true, onPlace: { controller.insertPhoto($0) })
                        .padding(.horizontal, Metrics.Space.gutter)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
            controller.onDeletePhoto = { id in
                persist(immediately: true)
                store.deletePhoto(id)
            }
            #if DEBUG
            if let requested = ProcessInfo.processInfo.environment["PLAIN_EDITOR_MODE"],
               let parsed = EditorMode(rawValue: requested) {
                mode = parsed
            }
            #endif
        }
        .onChange(of: text) { _, _ in persist(immediately: false) }
        .onDisappear { persist(immediately: true) }
        .task(id: photoSelection) {
            guard !photoSelection.isEmpty else { return }
            isImportingPhotos = true
            defer { isImportingPhotos = false }
            persist(immediately: true)
            for item in photoSelection {
                do {
                    let prepared = try await PhotoImport.prepare(item)
                    try Task.checkCancellation()
                    try store.addPhoto(prepared.photo, jpegData: prepared.jpeg, to: noteID)
                    controller.insertPhoto(prepared.photo)
                    importedPhotoCount += 1
                } catch is CancellationError { return }
                catch { photoImportFailed = true }
            }
            photoSelection = []
        }
        .sensoryFeedback(.success, trigger: importedPhotoCount)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: unplacedPhotos.map(\.id))
        .alert("Some photos could not be added", isPresented: $photoImportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check that the photo is downloaded and there is free space on your device.")
        }
    }

    private var photos: [NotePhoto] { store.note(noteID)?.photos ?? [] }

    /// Read from the text being edited, which runs ahead of the saved body.
    private var unplacedPhotos: [NotePhoto] {
        guard !photos.isEmpty else { return [] }
        let placed = Set(PhotoMarkdown.placedIDs(in: text))
        return photos.filter { !placed.contains($0.id) }
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
            isFocusMode: purchases.hasPro && settings.focusMode,
            isTypewriter: purchases.hasPro && settings.typewriterMode,
            photos: photos,
            photoData: store.photoData,
            controller: controller
        )
    }

    private var preview: some View {
        ScrollView {
            MarkdownRenderedView(document: MarkdownDocument(parsing: text), bodySize: settings.textSize - 1, photos: photos, photoData: store.photoData)
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

    private func proPreference(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { purchases.hasPro && settings[keyPath: keyPath] },
            set: { enabled in
                if enabled && !purchases.hasPro {
                    router.present(.pro(.writing))
                } else {
                    settings[keyPath: keyPath] = enabled
                }
            }
        )
    }

    /// Debounced autosave; `Done` and leaving the screen flush it.
    private func persist(immediately: Bool) {
        saveTask?.cancel()
        let body = text

        if immediately {
            guard var note = store.note(noteID) else { return }
            note.body = body
            store.update(note)
            return
        }
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            guard var note = store.note(noteID) else { return }
            note.body = body
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
