import Foundation

struct AppServices {
    let caseRepository: any CaseRepository
    let deviceCapabilityService: any DeviceCapabilityProviding
    let modelCatalogService: any ModelCatalogProviding
    let modelDownloadService: BackgroundModelDownloadService
    let localRuntimeService: any LocalRuntimeServicing
    let publicLawSearchService: any PublicLawSearchServicing
    let privacyLedgerService: PrivacyLedgerService
    let settingsStore: LocalSettingsStore

    @MainActor
    static func bootstrap() -> AppServices {
        let privacyLedgerService = PrivacyLedgerService(seed: PrivacyLedgerEntry.seedEntries)
        let settingsStore = LocalSettingsStore()
        let modelCatalogService = FixtureModelCatalogService()
        let caseRepository = InMemoryCaseRepository(seed: CaseFile.fixtureCases)
        let modelDownloadService = BackgroundModelDownloadService(
            settingsStore: settingsStore,
            privacyLedger: privacyLedgerService,
            startTransfersAutomatically: false
        )

        return AppServices(
            caseRepository: caseRepository,
            deviceCapabilityService: DefaultDeviceCapabilityService(),
            modelCatalogService: modelCatalogService,
            modelDownloadService: modelDownloadService,
            localRuntimeService: StubLocalRuntimeService(privacyLedger: privacyLedgerService),
            publicLawSearchService: StubPublicLawSearchService(privacyLedger: privacyLedgerService),
            privacyLedgerService: privacyLedgerService,
            settingsStore: settingsStore
        )
    }
}
