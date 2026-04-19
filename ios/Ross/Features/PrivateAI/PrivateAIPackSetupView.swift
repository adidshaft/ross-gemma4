import SwiftUI

struct PrivateAIPackSetupView: View {
    let modelDownloadService: BackgroundModelDownloadService
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                RossHeroCard(
                    eyebrow: "Private AI setup",
                    title: "Choose the local work tier that fits this device.",
                    detail: "Ross stays light at install time and adds stronger private review as setup completes."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: state.deviceCapability.recommendedTier.title, systemImage: "sparkles")
                            RossInfoPill(title: "\(state.deviceCapability.freeStorageGB) GB free", systemImage: "internaldrive")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RossInfoPill(title: state.deviceCapability.recommendedTier.title, systemImage: "sparkles")
                            RossInfoPill(title: "\(state.deviceCapability.freeStorageGB) GB free", systemImage: "internaldrive")
                        }
                    }
                }

                Text("This phone works best with \(state.deviceCapability.recommendedTier.title).")
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
                    .padding(.horizontal, 4)

                RossSectionCard(
                    title: "Choose your assistant's power level",
                    subtitle: "Pick one - you can change this later in Settings."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(state.availablePacks) { pack in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    state.selectedPackTier = pack.tier
                                }
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

                Button(action: activateSelection) {
                    Text("Start using Ross")
                }
                .rossPrimaryButtonStyle()
                .padding(.top, 8)

                Text("You can start using Ross right away. The assistant improves as setup completes in the background.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pack.tier.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(pack.tier.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.rossHighlight.opacity(0.15))
                            .foregroundStyle(Color.rossHighlight)
                            .clipShape(Capsule())
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.15))
                }
            }

            Text("Takes about \(pack.installedFootprint) on your phone")
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.55))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(pack.tier.focusAreas.prefix(2), id: \.self) { focus in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.rossSuccess)
                            .font(.subheadline)

                        Text(focus)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.rossAccent.opacity(0.04) : Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isSelected ? Color.rossAccent : Color.rossBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: isSelected ? Color.rossAccent.opacity(0.1) : Color.black.opacity(0.03), radius: isSelected ? 16 : 8, y: isSelected ? 8 : 4)
    }
}
