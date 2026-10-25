import Foundation

/// Starting points. A blank page is the right default; these are for the notes
/// somebody writes the same way every time.
public enum NoteTemplate: String, CaseIterable, Identifiable, Sendable {
    case blank
    case daily
    case meeting
    case checklist

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .blank: "Blank note"
        case .daily: "Daily note"
        case .meeting: "Meeting"
        case .checklist: "Checklist"
        }
    }

    public var icon: String {
        switch self {
        case .blank: "doc"
        case .daily: "calendar"
        case .meeting: "person.2"
        case .checklist: "checklist"
        }
    }

    public func body(on date: Date = .now, calendar: Calendar = .current) -> String {
        switch self {
        case .blank:
            return ""
        case .daily:
            return """
            # \(Self.dayTitle(date, calendar: calendar))

            ## Today

            - [ ] 

            ## Notes

            """
        case .meeting:
            return """
            # Meeting — \(Self.shortDate(date))

            **Who:**
            **Why:**

            ## Notes

            ## Decisions

            ## Next

            - [ ] 

            """
        case .checklist:
            return """
            # Checklist

            - [ ] 
            - [ ] 
            - [ ] 

            """
        }
    }

    public var title: String {
        switch self {
        case .blank: "Untitled"
        case .daily: Self.dayTitle(.now, calendar: .current)
        case .meeting: "Meeting — \(Self.shortDate(.now))"
        case .checklist: "Checklist"
        }
    }

    private static func dayTitle(_ date: Date, calendar: Calendar) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
