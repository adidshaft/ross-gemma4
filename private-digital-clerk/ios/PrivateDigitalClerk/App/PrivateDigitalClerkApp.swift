import SwiftUI

@MainActor
@main
struct PrivateDigitalClerkApp: App {
    @State private var appState = AppState()

    private let services = AppServices.bootstrap()

    var body: some Scene {
        WindowGroup {
            PrivateDigitalClerkRootView(
                services: services,
                state: appState
            )
        }
    }
}
