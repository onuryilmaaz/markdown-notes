import Foundation

public enum PlainDate {
    /// This package's own catalogue — the words around a date live here rather
    /// than in the app, so every target formats a date the same way.
    static let bundle = Bundle.module

    /// "Today 14:02", "Yesterday 09:15", "4 Sep" — the meta line on every card.
    /// Month names and time format follow the reader's locale; the words around
    /// them come from this package's own catalogue.
    public static func relative(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "Today \(time(date))", bundle: bundle, comment: "Date label: today, with a time")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday \(time(date))", bundle: bundle, comment: "Date label: yesterday, with a time")
        }
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 340 {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// The tighter form used on compact rows and in widgets.
    public static func short(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "now", bundle: bundle, comment: "Shortest form of 'today'")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "yest.", bundle: bundle, comment: "Abbreviation of 'yesterday'")
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    public static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    public static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    public static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    public static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated))
    }

    /// "1h 41m" — the number inside the live ring.
    public static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m", bundle: bundle, comment: "A duration in hours and minutes")
        }
        if minutes > 0 {
            return String(localized: "\(minutes)m", bundle: bundle, comment: "A duration in minutes")
        }
        return String(localized: "\(max(total, 0))s", bundle: bundle, comment: "A duration in seconds")
    }

    /// "6h left" — the trailing label on live cards and the island.
    public static func remaining(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        if total <= 0 {
            return String(localized: "ended", bundle: bundle, comment: "A live note whose window has closed")
        }
        if total >= 3600 {
            return String(localized: "\(total / 3600)h left", bundle: bundle, comment: "Time remaining, in hours")
        }
        if total >= 60 {
            return String(localized: "\(total / 60)m left", bundle: bundle, comment: "Time remaining, in minutes")
        }
        return String(localized: "\(total)s left", bundle: bundle, comment: "Time remaining, in seconds")
    }
}
