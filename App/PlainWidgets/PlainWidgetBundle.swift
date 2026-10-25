import WidgetKit
import SwiftUI

@main
struct PlainWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayCountWidget()
        PinnedNoteWidget()
        RecentlyLiveWidget()
        LiveNoteActivityWidget()
        NewNoteControl()
        SearchControl()
    }
}
