import SwiftUI
import UniformTypeIdentifiers
import PlainDomain
import PlainDesignSystem

struct SettingsView: View {
    @Environment(NotesStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(PurchaseStore.self) private var purchases
    @Environment(LockSession.self) private var locks

    @State private var confirmingReset = false
    /// The store is built at launch, so a change here only lands next time.
    @State private var syncAtLaunch = UserDefaults.standard.bool(forKey: "settings.icloudSync")
    @State private var isImporting = false
    @State private var exportedFile: ExportedFile?
    @State private var exchangeMessage: LocalizedStringKey?

    private let textSizes: [Double] = [14, 15, 16, 17, 18, 20]

    var body: some View {
        @Bindable var settings = settings

        PlainScreen {
            VStack(spacing: 0) {
                ScreenHeader(title: "Settings", onBack: { router.pop() })

                ScrollView {
                    VStack(spacing: 14) {
                        proCard
                        libraryCard
                        exchangeCard
                        appearanceCard(selection: $settings.appearance)
                        preferencesCard(liveActivity: $settings.liveActivityByDefault, monospace: $settings.monospaceEditor)
                    }
                    .padding(.horizontal, Metrics.Space.gutter)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    if settings.icloudSync != syncAtLaunch {
                        Text(settings.icloudSync
                             ? "Reopen Plain to finish turning iCloud sync on."
                             : "Reopen Plain to finish turning iCloud sync off.")
                            .font(PlainFont.meta)
                            .foregroundStyle(PlainPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    PillButton("Delete everything", style: .destructive) { confirmingReset = true }
                    Text("Plain 1.0 · build 214")
                        .font(PlainFont.meta)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: LibraryExchange.importableTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let imported = store.importNotes(LibraryExchange.notes(from: urls, folderID: nil))
                exchangeMessage = imported == 0
                    ? "Nothing could be read from those files."
                    : "Imported \(imported) of \(urls.count) files."
            case .failure:
                exchangeMessage = "That file could not be opened."
            }
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert(
            exchangeMessage ?? "",
            isPresented: Binding(get: { exchangeMessage != nil }, set: { if !$0 { exchangeMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Delete everything?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Delete ^[\(store.notes.count) note](inflect: true)", role: .destructive) { store.deleteLibrary() }
        } message: {
            Text("Every note and folder on this device goes. There is no cloud copy.")
        }
    }

    private var proCard: some View {
        Button { router.present(.pro(nil)) } label: {
            HStack(spacing: 14) {
                Image(systemName: purchases.hasPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 24, weight: .medium))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Plain Pro").font(PlainFont.headline)
                    Text(purchases.hasPro ? "Your Pro tools are ready" : "More focus. More possibilities.")
                        .font(PlainFont.callout)
                        .foregroundStyle(PlainPalette.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(PlainPalette.ink)
            .padding(20)
            .plainCard()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("settings-pro")
    }

    /// There is no account in this app, so the top card counts what is actually
    /// here instead of inventing a person.
    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Library")
                .font(PlainFont.sans(13, .semibold))
                .foregroundStyle(PlainPalette.ink)
            HStack(spacing: 0) {
                count("Notes", store.notes.count)
                count("Folders", store.folders.count)
                count("Tags", store.tagCounts.count)
            }
        }
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plainCard()
    }

    private var fileCount: String {
        String(localized: "^[\(store.notes.count) file](inflect: true)")
    }

    /// What the app is currently reading in, in that language's own words.
    private var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code.uppercased()
    }

    private func count(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(PlainFont.sans(24, .bold, relativeTo: .title))
                .foregroundStyle(PlainPalette.ink)
            Text(title)
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Notes go in and out as plain markdown files — the promise that nothing
    /// written here is trapped here.
    private var exchangeCard: some View {
        VStack(spacing: 0) {
            ValueRow("Recently deleted", value: store.deletedNotes.isEmpty ? "" : "\(store.deletedNotes.count)") {
                router.push(.trash)
            }
            PlainDivider()
            ValueRow("Import markdown files") { isImporting = true }
            PlainDivider()
            ValueRow("Paste as new note") { pasteNote() }
            PlainDivider()
            ValueRow("Export library", value: store.notes.isEmpty ? "" : fileCount) { exportLibrary() }
        }
        .plainCard()
    }

    private func pasteNote() {
        guard let text = UIPasteboard.general.string,
              let note = NoteExchange.note(fromPastedText: text, folderID: nil) else {
            exchangeMessage = "The clipboard has no text in it."
            return
        }
        store.importNotes([note])
        router.push(.note(note.id))
    }

    private func exportLibrary() {
        guard !store.notes.isEmpty else {
            exchangeMessage = "There is nothing to export yet."
            return
        }
        Task {
            let locked = Set(store.notes.filter(\.isLocked).map(\.id))
            guard await locks.unlock(locked) else {
                if let message = locks.errorMessage { exchangeMessage = LocalizedStringKey(message) }
                return
            }
            do {
                let url = try LibraryExchange.archive(notes: store.notes, folderName: { store.folderName($0) }, photoData: store.photoData)
                exportedFile = ExportedFile(url: url)
            } catch {
                exchangeMessage = "The library could not be packaged."
            }
        }
    }

    private func appearanceCard(selection: Binding<AppSettings.Appearance>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(PlainFont.sans(13, .semibold))
                .foregroundStyle(PlainPalette.ink)
            SegmentedPill(
                selection: selection,
                options: AppSettings.Appearance.allCases.map { (value: $0, label: LocalizedStringKey($0.label)) }
            )
        }
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plainCard()
    }

    private func preferencesCard(liveActivity: Binding<Bool>, monospace: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            ToggleRow("Live Activity by default", isOn: liveActivity)
            PlainDivider()
            ToggleRow("Monospace editor", isOn: monospace)
            PlainDivider()
            Menu {
                ForEach(textSizes, id: \.self) { size in
                    Button("\(Int(size)) pt") { settings.textSize = size }
                }
            } label: {
                ValueRow("Text size", value: "\(Int(settings.textSize)) pt")
            }
            PlainDivider()
            ToggleRow("iCloud sync", isOn: Bindable(settings).icloudSync)
            PlainDivider()
            // iOS owns per-app language, so this points at the right page
            // rather than keeping a second switch in here.
            ValueRow("Language", value: languageName) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            PlainDivider()
            ValueRow("Privacy policy") { router.present(.privacy) }
            PlainDivider()
            ValueRow("Widgets") { router.present(.widgets) }
        }
        .plainCard()
    }
}
