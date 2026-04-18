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

        let packSummary = activePack?.title ?? "Capture-first mode"
        let firstIssue = caseFile.workspace.issueHighlights.first ?? "Reconfirm the strongest issue from the indexed bundle."
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
                    body: question.isEmpty ? "Review the indexed workspace and restate the next hearing objective." : question
                ),
                AskCaseSection(
                    title: "Working answer",
                    body: "The current file suggests the leading point is: \(firstIssue) The safest next step is to anchor the answer to the source chips already surfaced in the workspace before expanding into a longer draft."
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
                title: "Instant Mode off",
                detail: "Short local turns are disabled in settings.",
                isAvailable: false,
                guidance: "Turn Instant Mode on in Private AI settings when you want faster short reviews."
            )
        }

        guard let activePack else {
            return InstantModeAssessment(
                title: "Install a Private AI Pack",
                detail: "The app can still capture and organize locally, but instant review is limited without a pack.",
                isAvailable: false,
                guidance: "Choose a Private AI Pack to enable fuller local review."
            )
        }

        guard activePack.supportsInstantMode, deviceCapability.supportsInstantMode else {
            return InstantModeAssessment(
                title: "Instant Mode limited",
                detail: deviceCapability.instantModeReason,
                isAvailable: false,
                guidance: "Use standard local review for deeper tasks on this device."
            )
        }

        return InstantModeAssessment(
            title: "Instant Mode available",
            detail: activePack.instantModeSummary,
            isAvailable: true,
            guidance: "Use Instant Mode for short, source-backed questions and keep longer drafting in the full workspace."
        )
    }
}
