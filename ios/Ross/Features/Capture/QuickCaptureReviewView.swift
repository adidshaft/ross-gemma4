import SwiftUI

struct QuickCaptureReviewView: View {
    let caseRepository: any CaseRepository
    let privacyLedger: PrivacyLedgerService
    @Bindable var state: AppState
    @State private var confirmationMessage: String?
    @State private var isFiling = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.quickCaptureDraft.captureTitle)
                        .font(.title2.weight(.bold))
                    Label(
                        "\(state.quickCaptureDraft.source.title) • \(state.quickCaptureDraft.receivedAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "camera.viewfinder"
                    )
                    .foregroundStyle(.secondary)
                }
                .padding(22)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                ReviewSection(
                    title: "Detected highlights",
                    items: state.quickCaptureDraft.extractedHighlights
                )

                ReviewSection(
                    title: "Review before filing",
                    items: state.quickCaptureDraft.redactionChecklist
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested filing")
                        .font(.headline)
                    Text(state.quickCaptureDraft.filingRecommendation)
                        .foregroundStyle(.secondary)
                    Text(state.quickCaptureDraft.destinationCaseTitle ?? "No case selected")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(22)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if let confirmationMessage {
                    Text(confirmationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(action: fileIntoSelectedCase) {
                    if isFiling {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("File Into Selected Case")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.selectedCaseID == nil || isFiling)

                Button {
                    privacyLedger.recordLocal(
                        title: "Quick capture retained locally",
                        detail: "The review remains in the local capture inbox."
                    )
                    confirmationMessage = "The capture remains local and was kept in the review inbox."
                } label: {
                    Text("Keep In Capture Inbox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
        }
        .background(Color.rossGroupedBackground)
        .navigationTitle("Quick Capture Review")
        .rossInlineNavigationTitle()
    }

    private func fileIntoSelectedCase() {
        isFiling = true

        Task {
            _ = await caseRepository.fileQuickCapture(
                state.quickCaptureDraft,
                into: state.selectedCaseID
            )
            await state.refreshCases(using: caseRepository)
            await MainActor.run {
                privacyLedger.recordLocal(
                    title: "Quick capture filed",
                    detail: "Capture review stayed on-device and was filed into the selected case."
                )
                confirmationMessage = "Filed into the selected case. The capture remains local to this device."
                isFiling = false
            }
        }
    }
}

private struct ReviewSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
