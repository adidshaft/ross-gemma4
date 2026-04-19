import SwiftUI

struct AskCaseView: View {
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                RossHeroCard(
                    eyebrow: "Local case review",
                    title: "Ask a focused question grounded in the indexed file.",
                    detail: "Ross treats the output as a draft for advocate review, keeps the question on-device, and only cites what is actually present in the selected case."
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: activePackTitle, systemImage: "cpu")
                            RossInfoPill(title: "Draft for review", systemImage: "doc.text")
                            RossInfoPill(title: "Source-backed", systemImage: "paperclip")
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
                        .foregroundStyle(Color.rossInk.opacity(0.8))
                }

                RossSectionCard(
                    title: "Question prompt",
                    subtitle: "Keep the ask precise. The answer should be something you could carry into a hearing prep note."
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        TextEditor(text: $state.askCaseInput)
                            .frame(minHeight: 160)
                            .padding(16)
                            .background(Color.rossGroupedBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.rossBorder, lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 2)
                        
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                RossInfoPill(title: "Chronology posture", systemImage: "calendar")
                                RossInfoPill(title: "Next hearing issues", systemImage: "text.alignleft")
                                RossInfoPill(title: "Source chip check", systemImage: "checklist")
                            }

                            VStack(alignment: .leading, spacing: 10) {
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
                            .tint(.white)
                    } else {
                        Text("Run Local Review")
                    }
                }
                .rossPrimaryButtonStyle()
                .disabled(state.selectedCase == nil || isRunning)
                .opacity(state.selectedCase == nil || isRunning ? 0.6 : 1.0)
                .padding(.top, 8)

                if let response = state.askCaseResponse {
                    AskCaseResponseCard(response: response)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
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

        withAnimation(.easeInOut(duration: 0.3)) {
            isRunning = true
            state.askCaseResponse = nil 
        }

        Task {
            let response = await localRuntimeService.askCase(
                state.askCaseInput,
                in: selectedCase,
                activePack: settingsStore.settings.activePackTier,
                settings: settingsStore.settings
            )

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    state.askCaseResponse = response
                    isRunning = false
                }
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
            VStack(alignment: .leading, spacing: 24) {
                ForEach(response.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(Color.rossInk)

                        Text(section.body)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundStyle(Color.rossInk.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()
                    .overlay(Color.rossBorder)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Source chips")
                        .font(.rossSerifHeadline())
                        .foregroundStyle(Color.rossInk)
                        .padding(.bottom, 4)

                    ForEach(response.citations) { citation in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(citation.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(citation.note)
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.6))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.rossGroupedBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.rossBorder, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}
