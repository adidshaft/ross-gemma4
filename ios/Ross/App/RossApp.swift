import SwiftUI

@MainActor
@main
struct RossApp: App {
    @State private var appState = AppState()

    private let services = AppServices.bootstrap()
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
