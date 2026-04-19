import SwiftUI

struct AskCaseView: View {
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if instantModeAssessment.isBlocking {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(Color.rossHighlight)
                            Text(instantModeAssessment.guidance)
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.8))
                        }
                        .padding(16)
                        .background(Color.rossHighlight.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ross will only use your case documents to answer.")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.45))

                        TextEditor(text: $state.askCaseInput)
                            .frame(minHeight: 120)
                            .padding(14)
                            .background(Color.rossGroupedBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.rossBorder, lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        HStack(spacing: 8) {
                            AskSuggestionPill(
                                title: "Next court date?",
                                systemImage: "calendar",
                                action: { state.askCaseInput = "What is the next court date?" }
                            )
                            AskSuggestionPill(
                                title: "Summarise facts",
                                systemImage: "text.alignleft",
                                action: { state.askCaseInput = "Summarise the main facts" }
                            )
                            Spacer()
                        }
                    }

                    Button(action: runLocalReview) {
                        if isRunning {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .tint(.white)
                        } else {
                            Text("Ask Ross")
                        }
                    }
                    .rossPrimaryButtonStyle()
                    .disabled(state.selectedCase == nil || isRunning)
                    .opacity(state.selectedCase == nil || isRunning ? 0.6 : 1.0)

                    if let response = state.askCaseResponse {
                        AskCaseResponseCard(response: response)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationTitle(state.selectedCase?.title ?? "Ask Ross")
            .rossInlineNavigationTitle()
        }
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

private struct AskSuggestionPill: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RossInfoPill(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct AskCaseResponseCard: View {
    let response: AskCaseResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(response.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.rossInk)

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
                Text("Where this came from")
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
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rossGroupedBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.rossBorder, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Text(response.draftNotice)
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.4))
                .padding(.top, 8)
        }
        .padding(.top, 8)
    }
}
