import WidgetKit
import SwiftUI

@main
struct PlainWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayCountWidget()
        PinnedNoteWidget()
        RecentlyLiveWidget()
        PhotoNoteWidget()
        QuickNoteWidget()
        LiveNoteActivityWidget()
        NewNoteControl()
        SearchControl()
    }
}
