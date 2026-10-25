import UIKit
import SwiftUI
import UniformTypeIdentifiers
import PlainDomain
import PlainPersistence
import PlainDesignSystem

/// "Share to Plain" from anywhere in iOS. Writes straight into the shared
/// library, so the note is there before the app is next opened.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(
            rootView: ShareCaptureView(
                load: { [weak self] in await self?.collectSharedText() ?? nil },
                onSave: { [weak self] text in self?.save(text) },
                onCancel: { [weak self] in self?.close() }
            )
        )
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    /// Text first, then a URL, then anything that can describe itself as text.
    private func collectSharedText() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        var pieces: [String] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                pieces.append(text)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                      let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                pieces.append(url.absoluteString)
            }
        }
        let joined = pieces.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }

    @MainActor
    private func save(_ text: String) {
        guard let note = NoteExchange.note(fromPastedText: text) else { return close() }
        let repository = SwiftDataNoteRepository(container: PlainStore.makeContainer())
        try? repository.save(note)
        close()
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// The sheet itself — the app's own card language, not a system form.
private struct ShareCaptureView: View {
    let load: () async -> String?
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("Save to Plain")
                    .font(PlainFont.cardTitle)
                    .foregroundStyle(PlainPalette.ink)

                if let text {
                    ScrollView {
                        Text(text)
                            .font(PlainFont.mono(13))
                            .foregroundStyle(PlainPalette.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                } else {
                    Text("Nothing to save from here.")
                        .font(PlainFont.callout)
                        .foregroundStyle(PlainPalette.inkTertiary)
                }
            }
            .padding(Metrics.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plainCard()

            PillButton(isSaving ? "Saved" : "Save note") {
                guard let text, !isSaving else { return }
                isSaving = true
                onSave(text)
            }
            .disabled(text == nil || isSaving)
            .opacity(text == nil ? 0.5 : 1)

            PillButton("Cancel", style: .plain) { onCancel() }
        }
        .padding(Metrics.Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .plainGround()
        .task { text = await load() }
    }
}
