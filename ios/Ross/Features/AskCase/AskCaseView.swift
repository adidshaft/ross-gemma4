import SwiftUI

struct AskCaseView: View {
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Local case review",
                    title: "Ask a focused question and keep the answer grounded in the indexed file.",
                    detail: "Ross treats the output as a draft for advocate review, keeps the question on-device, and only cites what is actually present in the selected case."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            RossInfoPill(title: activePackTitle, systemImage: "cpu")
                            RossInfoPill(title: "Draft for advocate review", systemImage: "doc.text")
                            RossInfoPill(title: "Source-backed output", systemImage: "paperclip")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            RossInfoPill(title: activePackTitle, systemImage: "cpu")
                            RossInfoPill(title: "Draft for advocate review", systemImage: "doc.text")
                            RossInfoPill(title: "Source-backed output", systemImage: "paperclip")
                        }
                    }
                }

                RossSectionCard(
                    title: instantModeAssessment.title,
                    subtitle: instantModeAssessment.detail
                ) {
                    Text(instantModeAssessment.guidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                RossSectionCard(
                    title: "Question prompt",
                    subtitle: "Keep the ask precise. The answer should be something you could carry into a hearing prep note."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $state.askCaseInput)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(Color.rossSecondaryGroupedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                RossInfoPill(title: "Chronology posture", systemImage: "calendar")
                                RossInfoPill(title: "Next hearing issues", systemImage: "text.alignleft")
                                RossInfoPill(title: "Source chip check", systemImage: "checklist")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                RossInfoPill(title: "Chronology posture", systemImage: "calendar")
                                RossInfoPill(title: "Next hearing issues", systemImage: "text.alignleft")
                                RossInfoPill(title: "Source chip check", systemImage: "checklist")
                            }
                        }
                    }
                }

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

    private var activePackTitle: String {
        settingsStore.settings.activePackTier?.title ?? "No pack selected"
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

private struct AskCaseResponseCard: View {
    let response: AskCaseResponse

    var body: some View {
        RossSectionCard(
            title: response.headline,
            subtitle: response.draftNotice
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(response.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(Color.rossInk)

                        Text(section.body)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Source chips")
                        .font(.headline)

                    ForEach(response.citations) { citation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(citation.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(citation.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}
