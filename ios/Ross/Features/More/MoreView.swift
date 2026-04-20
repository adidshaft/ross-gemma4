import SwiftUI

// MARK: - More Tab (plain list, 4 rows)

struct MoreView: View {
    let publicLawSearchService: any PublicLawSearchServicing
    let modelDownloadService: BackgroundModelDownloadService
    let privacyLedger: PrivacyLedgerService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DocumentListView(documents: state.selectedCase?.documents ?? [])
                    } label: {
                        Label("Documents", systemImage: "doc.text")
                    }

                    NavigationLink {
                        PublicLawSearchPreviewView(
                            publicLawSearchService: publicLawSearchService,
                            settingsStore: settingsStore,
                            state: state
                        )
                    } label: {
                        Label("Look up a law", systemImage: "magnifyingglass")
                    }

                    NavigationLink {
                        PrivacyLedgerView(privacyLedger: privacyLedger)
                    } label: {
                        Label("Activity log", systemImage: "clock")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView(
                            modelDownloadService: modelDownloadService,
                            state: state,
                            settingsStore: settingsStore
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("More")
        }
    }
}
