import SwiftUI

@MainActor
@main
struct RossApp: App {
    @State private var appState = AppState()

    private let services = AppServices.bootstrap()

    var body: some Scene {
        WindowGroup {
            RossRootView(
                services: services,
                state: appState
            )
        }
    }
}
