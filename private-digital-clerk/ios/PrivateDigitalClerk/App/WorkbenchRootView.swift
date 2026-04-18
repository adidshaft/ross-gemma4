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
            .tabItem {
                Label("Workspace", systemImage: "folder")
            }
            .tag(WorkbenchTab.workspace)

            PublicLawSearchPreviewView(
                publicLawSearchService: services.publicLawSearchService,
                settingsStore: services.settingsStore,
                state: state
            )
            .tabItem {
                Label("Public Law", systemImage: "magnifyingglass")
            }
            .tag(WorkbenchTab.publicLaw)

            PrivacyLedgerView(privacyLedger: services.privacyLedgerService)
                .tabItem {
                    Label("Ledger", systemImage: "checklist")
                }
                .tag(WorkbenchTab.privacyLedger)

            SettingsView(
                modelDownloadService: services.modelDownloadService,
                state: state,
                settingsStore: services.settingsStore
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(WorkbenchTab.settings)
        }
        .tint(Color(red: 0.08, green: 0.33, blue: 0.55))
    }
}
