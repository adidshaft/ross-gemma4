import Foundation

@MainActor
protocol LocalRuntimeServicing {
    func askCase(
        _ question: String,
        in caseFile: CaseFile,
        activePack: CapabilityTier?,
        settings: AppSettings
    ) async -> AskCaseResponse
    func instantModeAssessment(
        deviceCapability: DeviceCapability,
        activePack: CapabilityTier?,
        settings: AppSettings
    ) -> InstantModeAssessment
}

@MainActor
struct StubLocalRuntimeService: LocalRuntimeServicing {
    private let privacyLedger: PrivacyLedgerService

    init(privacyLedger: PrivacyLedgerService) {
        self.privacyLedger = privacyLedger
    }

    func askCase(
        _ question: String,
        in caseFile: CaseFile,
        activePack: CapabilityTier?,
        settings: AppSettings
    ) async -> AskCaseResponse {
        await MainActor.run {
            privacyLedger.recordLocal(
                title: "Local case review run",
                detail: "The question, sources, and draft stayed on-device."
            )
        }

        let packSummary = activePack?.title ?? "basic local review"
        let firstIssue = caseFile.workspace.issueHighlights.first ?? "Reconfirm the strongest issue from the case file."
        let firstTask = caseFile.workspace.draftTasks.first ?? "Prepare a short source-backed note."
        let instantModeLine = instantModeAssessment(
            deviceCapability: .placeholder,
            activePack: activePack,
            settings: settings
        )

        return AskCaseResponse(
            headline: "Local review completed with \(packSummary)",
            draftNotice: "Draft for advocate review",
            sections: [
                AskCaseSection(
                    title: "Question focus",
                    body: question.isEmpty ? "Review the case file and restate the next hearing objective." : question
                ),
                AskCaseSection(
                    title: "Working answer",
                    body: "The current file suggests the leading point is: \(firstIssue) The safest next step is to anchor the answer to the references already surfaced in the workspace before expanding into a longer draft."
                ),
                AskCaseSection(
                    title: "Preparation note",
                    body: "\(firstTask) \(instantModeLine.guidance)"
                )
            ],
            citations: caseFile.workspace.sourceAnchors
        )
    }

    func instantModeAssessment(
        deviceCapability: DeviceCapability,
        activePack: CapabilityTier?,
        settings: AppSettings
    ) -> InstantModeAssessment {
        guard settings.instantModeEnabled else {
            return InstantModeAssessment(
                title: "Quick responses are off",
                detail: "Ross will still answer from your case files.",
                isAvailable: false,
                isBlocking: false,
                guidance: "Turn quick responses back on in Settings if you want faster short reviews."
            )
        }

        guard let activePack else {
            return InstantModeAssessment(
                title: "Set up your private assistant",
                detail: "Ross can organize case files now, but answering case questions needs assistant setup.",
                isAvailable: false,
                isBlocking: true,
                guidance: "Choose an assistant in Settings to answer questions from your case files."
            )
        }

        guard activePack.supportsInstantMode, deviceCapability.supportsInstantMode else {
            return InstantModeAssessment(
                title: "Quick responses are unavailable",
                detail: deviceCapability.instantModeReason,
                isAvailable: false,
                isBlocking: false,
                guidance: "Ross can still review this case on this device."
            )
        }

        return InstantModeAssessment(
            title: "Quick responses are ready",
            detail: activePack.instantModeSummary,
            isAvailable: true,
            isBlocking: false,
            guidance: "Use quick responses for short, source-backed questions and keep longer drafting in the full workspace."
        )
    }
}
