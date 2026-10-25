import SwiftUI
import Observation
import PlainDomain

/// User preferences from the Settings screen, persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case light, dark, system
        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var colorScheme: ColorScheme? {
            switch self {
            case .light: .light
            case .dark: .dark
            case .system: nil
            }
        }
    }

    var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    var liveActivityByDefault: Bool { didSet { defaults.set(liveActivityByDefault, forKey: Key.liveByDefault) } }
    var monospaceEditor: Bool { didSet { defaults.set(monospaceEditor, forKey: Key.monospace) } }
    var textSize: Double { didSet { defaults.set(textSize, forKey: Key.textSize) } }
    var noteSort: NoteSort { didSet { defaults.set(noteSort.rawValue, forKey: Key.noteSort) } }
    var focusMode: Bool { didSet { defaults.set(focusMode, forKey: Key.focusMode) } }
    var icloudSync: Bool { didSet { defaults.set(icloudSync, forKey: Key.icloudSync) } }
    var typewriterMode: Bool { didSet { defaults.set(typewriterMode, forKey: Key.typewriterMode) } }

    private let defaults: UserDefaults

    private enum Key {
        static let appearance = "settings.appearance"
        static let liveByDefault = "settings.liveByDefault"
        static let monospace = "settings.monospaceEditor"
        static let textSize = "settings.textSize"
        static let noteSort = "settings.noteSort"
        static let focusMode = "settings.focusMode"
        static let icloudSync = "settings.icloudSync"
        static let typewriterMode = "settings.typewriterMode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .light
        liveActivityByDefault = defaults.object(forKey: Key.liveByDefault) as? Bool ?? true
        monospaceEditor = defaults.object(forKey: Key.monospace) as? Bool ?? true
        textSize = defaults.object(forKey: Key.textSize) as? Double ?? 16
        noteSort = defaults.string(forKey: Key.noteSort).flatMap(NoteSort.init(rawValue:)) ?? .recentlyEdited
        focusMode = defaults.bool(forKey: Key.focusMode)
        icloudSync = defaults.bool(forKey: Key.icloudSync)
        typewriterMode = defaults.bool(forKey: Key.typewriterMode)
    }
}
