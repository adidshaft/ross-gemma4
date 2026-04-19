import SwiftUI

struct SettingsView: View {
    let modelDownloadService: BackgroundModelDownloadService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section("Privacy defaults") {
                    Toggle("Private by default", isOn: $settingsStore.settings.privateByDefault)
                    Toggle("Require public-law query approval", isOn: $settingsStore.settings.requirePublicLawApproval)
                    Button("Restore privacy defaults", action: settingsStore.resetPrivacyDefaults)
                }

                Section("My assistant") {
                    LabeledContent("Status", value: settingsStore.settings.activePackTier != nil ? "Ready" : "Not set up")
                    NavigationLink {
                        PrivateAISettingsView(
                            modelDownloadService: modelDownloadService,
                            state: state,
                            settingsStore: settingsStore
                        )
                    } label: {
                        Label("My AI assistant settings", systemImage: "brain")
                    }
                }

                Section("Downloads") {
                    Toggle("Download on Wi-Fi only", isOn: $settingsStore.settings.wifiOnlyDownloads)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
