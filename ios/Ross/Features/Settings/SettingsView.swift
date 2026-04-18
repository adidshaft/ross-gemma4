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

                Section("Private AI") {
                    LabeledContent("Installed pack", value: settingsStore.settings.activePackTier?.title ?? "Not selected")
                    Toggle("Instant Mode", isOn: $settingsStore.settings.instantModeEnabled)
                    NavigationLink {
                        PrivateAISettingsView(
                            modelDownloadService: modelDownloadService,
                            state: state,
                            settingsStore: settingsStore
                        )
                    } label: {
                        Label("Private AI Settings", systemImage: "cpu")
                    }
                }

                Section("Downloads") {
                    Toggle("Background model downloads", isOn: $settingsStore.settings.backgroundModelDownloadsEnabled)
                    Toggle("Wi-Fi only downloads", isOn: $settingsStore.settings.wifiOnlyDownloads)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
