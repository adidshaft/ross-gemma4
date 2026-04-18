import SwiftUI

struct PrivateAIPackSetupView: View {
    let modelDownloadService: BackgroundModelDownloadService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PackSetupHeader(capability: state.deviceCapability)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Recommended for this device")
                        .font(.headline)

                    HStack {
                        Text(state.deviceCapability.recommendedTier.title)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(state.deviceCapability.freeStorageGB) GB free")
                            .foregroundStyle(.secondary)
                    }

                    Text(state.deviceCapability.recommendationReason)
                        .foregroundStyle(.secondary)

                    Label(state.deviceCapability.instantModeReason, systemImage: "bolt.horizontal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(22)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a capability tier")
                        .font(.headline)

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
            }
            .padding(24)
        }
        .background(Color.clerkGroupedBackground)
    }

    private func activateSelection() {
        guard let pack = state.availablePacks.first(where: { $0.tier == state.selectedPackTier }) else {
            return
        }

        state.finishPackSelection(using: settingsStore)
        modelDownloadService.queueDownload(for: pack)
    }
}

private struct PackSetupHeader: View {
    let capability: DeviceCapability

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Private AI Pack setup")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Pick a capability tier for local review on \(capability.deviceLabel.lowercased()). Technical model names stay hidden here and appear only in technical settings.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                PackFact(title: "Memory", value: "\(capability.totalMemoryGB) GB")
                PackFact(title: "Thermal", value: capability.thermalCondition)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.93),
                    Color(red: 0.89, green: 0.93, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PackSelectionCard: View {
    let pack: ModelPack
    let isSelected: Bool
    let isRecommended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(pack.tier.title)
                    .font(.title3.weight(.semibold))

                if isRecommended {
                    Text("Recommended")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.86, green: 0.92, blue: 0.98))
                        .clipShape(Capsule())
                }

                Spacer()

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color(red: 0.08, green: 0.33, blue: 0.55) : .secondary)
            }

            Text(pack.tier.summary)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(pack.tier.focusAreas, id: \.self) { focus in
                    Label(focus, systemImage: "checkmark.circle")
                        .font(.subheadline)
                }
            }

            HStack {
                Label(pack.downloadSize, systemImage: "arrow.down.circle")
                Spacer()
                Text(pack.tier.storageGuidance)
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .padding(20)
        .background(.background)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected ? Color(red: 0.08, green: 0.33, blue: 0.55) : Color.secondary.opacity(0.22),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PackFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
