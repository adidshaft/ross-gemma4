import Foundation
import Observation

enum OnboardingStage: String, Sendable {
    case welcome
    case privateAIPack
    case completed
}

enum WorkbenchTab: String, Hashable, Sendable {
    case workspace
    case publicLaw
    case privacyLedger
    case settings
}

@MainActor
@Observable
final class AppState {
    var onboardingStage: OnboardingStage = .welcome
    var selectedTab: WorkbenchTab = .workspace
    var deviceCapability: DeviceCapability = .placeholder
    var availablePacks: [ModelPack] = []
    var selectedPackTier: CapabilityTier = .caseAssociate
    var caseFiles: [CaseFile] = []
    var selectedCaseID: CaseFile.ID?
    var quickCaptureDraft: QuickCaptureDraft = .fixture
    var askCaseInput = "Summarize the next hearing posture and identify the two strongest source-backed issues."
    var askCaseResponse: AskCaseResponse?
    var publicLawDraftText = "Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted."
    var publicLawPreview: SanitizedPublicQueryPreview?
    var publicLawResults: [PublicLawResult] = []
    var isBootstrapped = false

    var selectedCase: CaseFile? {
        guard let selectedCaseID else {
            return caseFiles.first
        }

        return caseFiles.first { $0.id == selectedCaseID }
    }

    func bootstrap(using services: AppServices) async {
        guard !isBootstrapped else {
            return
        }

        deviceCapability = services.deviceCapabilityService.currentCapability()
        availablePacks = await services.modelCatalogService.availablePacks()
        selectedPackTier = deviceCapability.recommendedTier
        caseFiles = await services.caseRepository.loadCases()
        selectedCaseID = caseFiles.first?.id
        askCaseResponse = makeInitialAskCaseResponse()
        isBootstrapped = true
    }

    func refreshCases(using caseRepository: any CaseRepository) async {
        caseFiles = await caseRepository.loadCases()
        if selectedCaseID == nil {
            selectedCaseID = caseFiles.first?.id
        }
    }

    func finishPackSelection(using settingsStore: LocalSettingsStore) {
        settingsStore.activatePack(selectedPackTier)
        onboardingStage = .completed
        selectedTab = .workspace
    }

    private func makeInitialAskCaseResponse() -> AskCaseResponse {
        AskCaseResponse(
            headline: "Local review is ready",
            draftNotice: "Draft for advocate review",
            sections: [
                AskCaseSection(
                    title: "Procedural posture",
                    body: "The matter appears ready for a focused hearing update. The current workspace suggests that delay, chronology support, and documentary consistency should be checked before the next appearance."
                ),
                AskCaseSection(
                    title: "Immediate preparation",
                    body: "Confirm the date sequence, keep the key order pages bookmarked, and prepare a short note tying the next hearing objective to source-backed pages already in the file room."
                )
            ],
            citations: CaseFile.fixtureCases.first?.workspace.sourceAnchors ?? []
        )
    }
}
