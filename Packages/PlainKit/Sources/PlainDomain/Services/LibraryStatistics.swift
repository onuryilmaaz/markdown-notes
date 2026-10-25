import Foundation

/// Numbers behind the two cards at the top of Home.
public struct LibraryStatistics: Hashable, Sendable {
    public struct Day: Hashable, Identifiable, Sendable {
        public let date: Date
        public let count: Int
        public var id: Date { date }
        public var isActive: Bool { count > 0 }
    }

    public let today: Date
    public let todayCount: Int
    /// Fourteen days, oldest first — drawn as two rows of seven dots.
    public let recentDays: [Day]

    public var activeRatio: Double {
        guard !recentDays.isEmpty else { return 0 }
        return Double(recentDays.filter(\.isActive).count) / Double(recentDays.count)
    }

    public var percentLabel: String { "\(Int((activeRatio * 100).rounded()))%" }

    public static func make(from notes: [Note], now: Date = .now, calendar: Calendar = .current) -> LibraryStatistics {
        let startOfToday = calendar.startOfDay(for: now)
        let days: [Day] = (0..<14).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { return nil }
            let count = notes.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
            return Day(date: date, count: count)
        }
        return LibraryStatistics(
            today: startOfToday,
            todayCount: days.last?.count ?? 0,
            recentDays: days
        )
    }
}
