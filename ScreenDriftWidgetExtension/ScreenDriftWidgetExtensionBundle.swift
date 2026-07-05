import WidgetKit
import SwiftUI

@main
struct ScreenDriftWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ScreenDriftRingWidget()
        ScreenDriftMinimalWidget()
    }
}
