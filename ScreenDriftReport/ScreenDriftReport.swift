import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct ScreenDriftReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { model in
            TotalActivityView(model: model)
        }
    }
}
