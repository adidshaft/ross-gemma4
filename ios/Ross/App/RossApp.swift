import SwiftUI

@MainActor
@main
struct RossApp: App {
    private let launchMode = RossLaunchMode.current

    var body: some Scene {
        WindowGroup {
            switch launchMode {
            case .interactive:
                AlphaRossRootView()
            case .screenshotExport:
                ScreenshotExportView()
            }
        }
    }
}
