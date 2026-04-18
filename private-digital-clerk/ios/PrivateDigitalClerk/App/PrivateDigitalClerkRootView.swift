import SwiftUI

struct PrivateDigitalClerkRootView: View {
    let services: AppServices
    @Bindable var state: AppState

    var body: some View {
        Group {
            switch state.onboardingStage {
            case .welcome:
                OnboardingView(state: state)
            case .privateAIPack:
                PrivateAIPackSetupView(
                    modelDownloadService: services.modelDownloadService,
                    state: state,
                    settingsStore: services.settingsStore
                )
            case .completed:
                WorkbenchRootView(
                    services: services,
                    state: state
                )
            }
        }
        .task {
            await state.bootstrap(using: services)
        }
    }
}
