import Foundation

/// What the home-screen widgets show. Written by the app after every mutation,
/// read by the widget extension — the two processes share nothing else.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Identifiable, Sendable {
        public var id: UUID
        public var title: String
        public var subtitle: String
        public var isLive: Bool

        public init(id: UUID, title: String, subtitle: String, isLive: Bool) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.isLive = isLive
        }
    }

    public var date: Date
    public var todayCount: Int
    public var pinnedTitle: String?
    public var pinnedSubtitle: String?
    public var recent: [Item]

    public init(date: Date = .now, todayCount: Int = 0, pinnedTitle: String? = nil, pinnedSubtitle: String? = nil, recent: [Item] = []) {
        self.date = date
        self.todayCount = todayCount
        self.pinnedTitle = pinnedTitle
        self.pinnedSubtitle = pinnedSubtitle
        self.recent = recent
    }

    public static let placeholder = WidgetSnapshot(
        todayCount: 9,
        pinnedTitle: "Search index sync",
        pinnedSubtitle: "Widget — home screen",
        recent: [
            Item(id: UUID(), title: "Search index sync", subtitle: "now", isLive: true),
            Item(id: UUID(), title: "Collect parcel after lunch", subtitle: "yest.", isLive: false),
            Item(id: UUID(), title: "Standup — three blockers", subtitle: "4 Sep", isLive: false)
        ]
    )
}

public enum AppGroup {
    /// The CloudKit container that backs iCloud sync, published the same way as
    /// the app group so renaming the app moves both together.
    public static let cloudContainer: String = {
        Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String
            ?? "iCloud.com.onur6541.plain"
    }()

    /// Published by both Info.plists so the identifier lives in exactly one
    /// place — the APP_NAME build setting — and never drifts from the
    /// entitlements when the app is renamed.
    public static let identifier: String = {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.onur6541.plain"
    }()
}

/// Small shared box between the app and its extension. Falls back to standard
/// defaults when the app group is unavailable (unsigned simulator builds), so a
/// missing entitlement degrades to "widget shows placeholder" and never crashes.
public struct SnapshotStore: Sendable {
    public static let shared = SnapshotStore()
    private static let key = "widget.snapshot"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    public init() {}

    public func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func read() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
