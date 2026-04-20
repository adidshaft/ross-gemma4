import SwiftUI

// MARK: - Capture Tab (keyboard-first, no scroll, no cards)

struct QuickCaptureTabView: View {
    let caseRepository: any CaseRepository
    let privacyLedger: PrivacyLedgerService
    @Bindable var state: AppState

    @State private var noteText = ""
    @State private var isSaving = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // ── Text input — fills all available height ───────────
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $noteText)
                        .font(.body)
                        .foregroundStyle(Color.rossInk)
                        .padding(14)
                        .background(Color.rossCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.rossBorder, lineWidth: 1)
                        }

                    if noteText.isEmpty {
                        Text("What happened?")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.25))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Case filing selector ──────────────────────────────
                HStack {
                    Text("Filing to:")
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.5))
                    Spacer()
                    Text(state.selectedCase?.title ?? "Select a matter")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.rossAccent)
                        .lineLimit(1)
                }

                // ── Primary action ────────────────────────────────────
                Button(action: saveCapture) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .tint(.white)
                    } else if saved {
                        Label("Saved", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Save to case")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .rossPrimaryButtonStyle()
                .disabled(noteText.isEmpty || state.selectedCase == nil || isSaving)
                .opacity((noteText.isEmpty || state.selectedCase == nil) && !isSaving ? 0.5 : 1.0)

                // ── Secondary — text link only ────────────────────────
                Button("Save for later") {
                    privacyLedger.recordLocal(
                        title: "Capture kept local",
                        detail: "Retained in capture inbox."
                    )
                    saved = true
                    resetAfterDelay()
                }
                .font(.subheadline)
                .foregroundStyle(Color.rossInk.opacity(0.4))
                .frame(maxWidth: .infinity)
                .disabled(noteText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationTitle("Capture a note")
        }
    }

    private func saveCapture() {
        guard !noteText.isEmpty, let caseID = state.selectedCaseID else { return }
        isSaving = true

        // Build a minimal draft to file
        let draft = QuickCaptureDraft(
            id: UUID(),
            captureTitle: String(noteText.prefix(60)),
            source: .camera,
            receivedAt: Date(),
            extractedHighlights: [],
            redactionChecklist: [],
            filingRecommendation: "Filed from Capture tab",
            destinationCaseTitle: state.selectedCase?.title
        )

        Task {
            _ = await caseRepository.fileQuickCapture(draft, into: caseID)
            await state.refreshCases(using: caseRepository)
            await MainActor.run {
                privacyLedger.recordLocal(
                    title: "Capture filed",
                    detail: "Filed into selected case on-device."
                )
                isSaving = false
                saved = true
                noteText = ""
                resetAfterDelay()
            }
        }
    }

    private func resetAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            saved = false
        }
    }
}
