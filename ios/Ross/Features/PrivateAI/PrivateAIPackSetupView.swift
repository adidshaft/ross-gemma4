import SwiftUI

struct PrivateAIPackSetupView: View {
    let modelDownloadService: BackgroundModelDownloadService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Private AI setup",
                    title: "Choose the local work tier that fits this device.",
                    detail: "The pack download happens after installation so Ross can stay light at install time and still explain storage, network posture, and Instant Mode clearly."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            RossInfoPill(title: state.deviceCapability.recommendedTier.title, systemImage: "sparkles")
                            RossInfoPill(title: "\(state.deviceCapability.freeStorageGB) GB free", systemImage: "internaldrive")
                            RossInfoPill(title: state.deviceCapability.instantModeReason, systemImage: "bolt.horizontal")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RossInfoPill(title: state.deviceCapability.recommendedTier.title, systemImage: "sparkles")
                            RossInfoPill(title: "\(state.deviceCapability.freeStorageGB) GB free", systemImage: "internaldrive")
                            RossInfoPill(title: state.deviceCapability.instantModeReason, systemImage: "bolt.horizontal")
                        }
                    }
                }

                RossSectionCard(
                    title: "Recommendation for this device",
                    subtitle: state.deviceCapability.recommendationReason
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            RossMetricTile(label: "Recommended", value: state.deviceCapability.recommendedTier.title, tint: .rossAccent)
                            RossMetricTile(label: "Memory", value: "\(state.deviceCapability.totalMemoryGB) GB", tint: .rossHighlight)
                            RossMetricTile(label: "Thermal", value: state.deviceCapability.thermalCondition, tint: .rossSuccess)
                        }

                        VStack(spacing: 12) {
                            RossMetricTile(label: "Recommended", value: state.deviceCapability.recommendedTier.title, tint: .rossAccent)
                            RossMetricTile(label: "Memory", value: "\(state.deviceCapability.totalMemoryGB) GB", tint: .rossHighlight)
                            RossMetricTile(label: "Thermal", value: state.deviceCapability.thermalCondition, tint: .rossSuccess)
                        }
                    }
                }

                RossSectionCard(
                    title: "Choose a capability tier",
                    subtitle: "The onboarding flow stays user-facing here. Technical model names remain hidden until settings."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(state.availablePacks) { pack in
                            Button {
                                state.selectedPackTier = pack.tier
                            } label: {
                                PackSelectionCard(
                                    pack: pack,
                                    isSelected: state.selectedPackTier == pack.tier,
                                    isRecommended: state.deviceCapability.recommendedTier == pack.tier
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RossSectionCard(
                    title: "What stays available while delivery continues",
                    subtitle: "You do not have to wait for the largest pack before opening the workbench."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        RossBulletRow(text: "Capture papers, sort documents, and review what is already stored locally.")
                        RossBulletRow(text: "Let larger downloads continue in the background when the network policy allows it.")
                        RossBulletRow(text: "Switch to a smaller tier later if the current footprint no longer fits the device.")
                    }
                }

                Button(action: activateSelection) {
                    Text("Continue to Workbench")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Text("The app remains usable for capture and organization while background delivery is staged for a trusted network.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .background(Color.rossGroupedBackground)
    }

    private func activateSelection() {
        guard let pack = state.availablePacks.first(where: { $0.tier == state.selectedPackTier }) else {
            return
        }

        state.finishPackSelection(using: settingsStore)
        modelDownloadService.queueDownload(for: pack)
    }
}

private struct PackSelectionCard: View {
    let pack: ModelPack
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pack.tier.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(pack.tier.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.rossAccent.opacity(0.12))
                            .foregroundStyle(Color.rossAccent)
                            .clipShape(Capsule())
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.rossAccent : .secondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    RossInfoPill(title: pack.downloadSize, systemImage: "arrow.down.circle")
                    RossInfoPill(title: pack.installedFootprint, systemImage: "shippingbox")
                    RossInfoPill(title: pack.tier.storageGuidance, systemImage: "internaldrive")
                }

                VStack(alignment: .leading, spacing: 8) {
                    RossInfoPill(title: pack.downloadSize, systemImage: "arrow.down.circle")
                    RossInfoPill(title: pack.installedFootprint, systemImage: "shippingbox")
                    RossInfoPill(title: pack.tier.storageGuidance, systemImage: "internaldrive")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(pack.tier.focusAreas, id: \.self) { focus in
                    Label(focus, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk)
                }
            }

            Text("Best for: \(pack.recommendedFor)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.rossAccent.opacity(0.07) : Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSelected ? Color.rossAccent : Color.rossBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
