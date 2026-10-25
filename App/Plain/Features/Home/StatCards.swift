import SwiftUI
import PlainDomain
import PlainDesignSystem

/// Left card: the date, and how much was written today.
struct TodayCard: View {
    let statistics: LibraryStatistics

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: statistics.today))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text("Today")
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.ink)
                Text(PlainDate.month(statistics.today))
                    .font(PlainFont.sans(13, .medium))
                    .foregroundStyle(PlainPalette.inkTertiary)
            }
            Text(dayNumber)
                .font(PlainFont.counter)
                .foregroundStyle(PlainPalette.ink)
                .padding(.top, 6)
            Spacer(minLength: 6)
            Text("^[\(statistics.todayCount) note](inflect: true) written")
                .font(PlainFont.meta)
                .foregroundStyle(PlainPalette.inkTertiary)
        }
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .plainCard()
        // One statement, rather than four fragments read in a row.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today, \(PlainDate.relative(statistics.today))")
        .accessibilityValue("^[\(statistics.todayCount) note](inflect: true) written")
    }
}

/// Right card: a fortnight of writing as two rows of dots.
struct WeekCard: View {
    let statistics: LibraryStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Week")
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.ink)
                Spacer()
                Text(statistics.percentLabel)
                    .font(PlainFont.sans(13, .semibold))
                    .foregroundStyle(PlainPalette.inkTertiary)
            }
            Spacer(minLength: 12)
            // The dots are a picture of the number above them.
            ActivityDots(states: statistics.recentDays.map(\.isActive))
                .accessibilityHidden(true)
            Spacer(minLength: 2)
        }
        .padding(Metrics.Space.card)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .plainCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Days written in, this fortnight")
        .accessibilityValue(statistics.percentLabel)
    }
}
