import SwiftUI

struct PrivateAISettingsView: View {
    @Bindable var modelDownloadService: BackgroundModelDownloadService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        List {
            Section("Device recommendation") {
                LabeledContent("Recommended tier", value: state.deviceCapability.recommendedTier.title)
                LabeledContent("Memory", value: "\(state.deviceCapability.totalMemoryGB) GB")
                LabeledContent("Free storage", value: "\(state.deviceCapability.freeStorageGB) GB")
                Text(state.deviceCapability.recommendationReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Active pack") {
                ForEach(state.availablePacks) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pack.tier.title)
                            Text(pack.recommendedFor)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if settingsStore.settings.activePackTier == pack.tier {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Use") {
                                settingsStore.activatePack(pack.tier)
                                state.selectedPackTier = pack.tier
                            }
                        }
                    }
                }

                Button("Stage Recommended Pack") {
                    guard let pack = state.availablePacks.first(where: { $0.tier == state.deviceCapability.recommendedTier }) else {
                        return
                    }
                    settingsStore.activatePack(pack.tier)
                    modelDownloadService.queueDownload(for: pack)
                }
            }

            Section("Runtime") {
                Toggle("Instant Mode", isOn: $settingsStore.settings.instantModeEnabled)
                Toggle("Show technical details", isOn: $settingsStore.settings.showTechnicalDetails)
                Text(state.deviceCapability.instantModeReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Download queue") {
                if modelDownloadService.jobs.isEmpty {
                    Text("No pack downloads have been staged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(modelDownloadService.jobs) { job in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(job.packTier.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(job.phase.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(job.deliveryNote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if job.phase == .paused {
                                Button("Resume") {
                                    modelDownloadService.resume(jobID: job.id)
                                }
                            } else if job.phase == .queued || job.phase == .scheduled {
                                Button("Pause") {
                                    modelDownloadService.pause(jobID: job.id)
                                }
                            }
                        }
                    }
                }
            }

            if settingsStore.settings.showTechnicalDetails {
                Section("Technical details") {
                    ForEach(state.availablePacks) { pack in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pack.tier.title)
                                .font(.subheadline.weight(.semibold))

                            ForEach(pack.technicalDetails) { detail in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(detail.name)
                                        .font(.footnote.weight(.semibold))
                                    Text(detail.purpose)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Private AI Settings")
    }
}
