import SwiftUI

struct AskCaseView: View {
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                InstantModeCard(assessment: instantModeAssessment)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ask this case")
                        .font(.headline)
                    TextEditor(text: $state.askCaseInput)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text("Source-backed output")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(22)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button(action: runLocalReview) {
                    if isRunning {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Run Local Review")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.selectedCase == nil || isRunning)

                if let response = state.askCaseResponse {
                    AskCaseResponseCard(response: response)
                }
            }
            .padding(20)
        }
        .background(Color.rossGroupedBackground)
        .navigationTitle("Ask Case")
        .rossInlineNavigationTitle()
    }

    private var instantModeAssessment: InstantModeAssessment {
        localRuntimeService.instantModeAssessment(
            deviceCapability: state.deviceCapability,
            activePack: settingsStore.settings.activePackTier,
            settings: settingsStore.settings
        )
    }

    private func runLocalReview() {
        guard let selectedCase = state.selectedCase else {
            return
        }

        isRunning = true

        Task {
            let response = await localRuntimeService.askCase(
                state.askCaseInput,
                in: selectedCase,
                activePack: settingsStore.settings.activePackTier,
                settings: settingsStore.settings
            )

            await MainActor.run {
                state.askCaseResponse = response
                isRunning = false
            }
        }
    }
}

private struct InstantModeCard: View {
    let assessment: InstantModeAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(assessment.title)
                    .font(.headline)
                Spacer()
                Image(systemName: assessment.isAvailable ? "bolt.fill" : "bolt.slash")
                    .foregroundStyle(assessment.isAvailable ? .yellow : .secondary)
            }

            Text(assessment.detail)
                .foregroundStyle(.secondary)

            Text(assessment.guidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct AskCaseResponseCard: View {
    let response: AskCaseResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(response.headline)
                .font(.title3.weight(.semibold))

            Text(response.draftNotice)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(response.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    Text(section.body)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Sources")
                    .font(.headline)
                ForEach(response.citations) { citation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(citation.label)
                            .font(.footnote.weight(.semibold))
                        Text(citation.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.rossSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
