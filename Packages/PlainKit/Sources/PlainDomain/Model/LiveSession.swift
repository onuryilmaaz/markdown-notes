import Foundation

/// A note that is broadcasting itself to the Lock Screen / Dynamic Island.
public struct LiveSession: Hashable, Codable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var expiresAt: Date

    public init(id: UUID = UUID(), startedAt: Date = .now, expiresAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    public init(id: UUID = UUID(), startedAt: Date = .now, duration: TimeInterval) {
        self.init(id: id, startedAt: startedAt, expiresAt: startedAt.addingTimeInterval(duration))
    }

    public var duration: TimeInterval { expiresAt.timeIntervalSince(startedAt) }

    public func isActive(at date: Date = .now) -> Bool { date < expiresAt }

    public func elapsed(at date: Date = .now) -> TimeInterval {
        min(max(date.timeIntervalSince(startedAt), 0), duration)
    }

    public func remaining(at date: Date = .now) -> TimeInterval {
        max(expiresAt.timeIntervalSince(date), 0)
    }

    /// 0…1 — drives the ring on the live screen and the island progress.
    public func progress(at date: Date = .now) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(elapsed(at: date) / duration, 0), 1)
    }
}

public enum LiveDuration: TimeInterval, CaseIterable, Identifiable, Sendable {
    case oneHour = 3600
    case fourHours = 14400
    case eightHours = 28800
    case twelveHours = 43200

    public var id: TimeInterval { rawValue }

    public var label: String {
        switch self {
        case .oneHour: "1h Live"
        case .fourHours: "4h Live"
        case .eightHours: "8h Live"
        case .twelveHours: "12h Live"
        }
    }
}
