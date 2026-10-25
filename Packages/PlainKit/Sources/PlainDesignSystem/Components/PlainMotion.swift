import SwiftUI

public extension View {
    func plainEntrance(delay: Double = 0) -> some View {
        modifier(PlainEntrance(delay: delay))
    }
}

private struct PlainEntrance: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82).delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}
