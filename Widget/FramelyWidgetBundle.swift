import WidgetKit
import SwiftUI

@main
struct FramelyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhotoWidget()
        MosaicWidget()
        InfoWidget()
        LockScreenWidget()
    }
}
