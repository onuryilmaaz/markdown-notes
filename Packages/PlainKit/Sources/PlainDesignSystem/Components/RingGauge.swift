import SwiftUI

/// The ring statistic from the live-note screen: a thick grey track with an ink
/// arc and a round cap, counting how long the note has been public.
public struct RingGauge<Center: View>: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let center: Center

    public init(progress: Double, lineWidth: CGFloat = 16, @ViewBuilder center: () -> Center) {
        self.progress = min(max(progress, 0), 1)
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(PlainPalette.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(PlainPalette.emphasis, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            center
        }
    }
}

/// Two rows of seven dots — a fortnight of writing activity.
public struct ActivityDots: View {
    private let states: [Bool]
    private let columns: Int
    private let dot: CGFloat

    public init(states: [Bool], columns: Int = 7, dot: CGFloat = 6) {
        self.states = states
        self.columns = columns
        self.dot = dot
    }

    public var body: some View {
        let rows = stride(from: 0, to: states.count, by: columns).map {
            Array(states[$0..<min($0 + columns, states.count)])
        }
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 9) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, active in
                        Circle()
                            .fill(active ? PlainPalette.ink : PlainPalette.dotIdle)
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
    }
}
