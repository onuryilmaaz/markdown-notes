import SwiftUI
import PlainDesignSystem
import PlainPersistence

@main
struct PlainApp: App {
    @State private var store: NotesStore
    @State private var settings: AppSettings
    @State private var router: Router
    @State private var liveActivities: LiveActivityController
    @State private var locks = LockSession()

    init() {
        // App initialisation happens on the main thread; make that explicit so
        // the main-actor store can be built eagerly.
        let (store, settings, router, live) = MainActor.assumeIsolated {
            // The sync preference is read before anything else: it decides
            // which store the whole app is about to talk to.
            let syncs = UserDefaults.standard.bool(forKey: "settings.icloudSync")
            let repository = SwiftDataNoteRepository(container: PlainStore.makeContainer(syncsWithICloud: syncs))
            return (NotesStore(repository: repository), AppSettings(), Router(), LiveActivityController())
        }
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        _router = State(initialValue: router)
        _liveActivities = State(initialValue: live)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(router)
                .environment(liveActivities)
                .environment(locks)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(PlainPalette.ink)
                .task {
                    IntentLibrary.liveStore = store
                    SpotlightIndexer.sync(notes: store.notes)
                    liveActivities.reconcile(with: store.notes)
                    #if DEBUG
                    DebugLaunch.applyIfNeeded(store: store, router: router, settings: settings, liveActivities: liveActivities)
                    #endif
                }
        }
    }
}
