import SwiftUI

struct WorkbenchRootView: View {
    let services: AppServices
    @Bindable var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {

            CaseWorkspaceView(
                caseRepository: services.caseRepository,
                privacyLedger: services.privacyLedgerService,
                localRuntimeService: services.localRuntimeService,
                state: state,
                settingsStore: services.settingsStore
            )
            .tabItem { Label("Cases", systemImage: "doc.text") }
            .tag(WorkbenchTab.workspace)

            QuickCaptureTabView(
                caseRepository: services.caseRepository,
                privacyLedger: services.privacyLedgerService,
                state: state
            )
            .tabItem { Label("Capture", systemImage: "pencil") }
            .tag(WorkbenchTab.capture)

            MoreView(
                publicLawSearchService: services.publicLawSearchService,
                modelDownloadService: services.modelDownloadService,
                privacyLedger: services.privacyLedgerService,
                state: state,
                settingsStore: services.settingsStore
            )
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(WorkbenchTab.more)
        }
        .tint(Color.rossAccent)
    }
}
