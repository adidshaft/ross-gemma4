package com.privatedigitalclerk.android.feature

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.privatedigitalclerk.android.app.AppContainer
import com.privatedigitalclerk.android.core.domain.OnboardingCopyPolicy
import com.privatedigitalclerk.android.core.model.OnboardingSelection
import com.privatedigitalclerk.android.core.model.PublicLawPreview
import com.privatedigitalclerk.android.core.model.SettingsSnapshot
import com.privatedigitalclerk.android.core.model.WorkbenchSection

class AppPresenter(
    private val container: AppContainer,
) {
    private val deviceSnapshot = container.defaultDeviceSnapshot()
    private val recommendation = container.capabilityRecommender.recommend(deviceSnapshot)
    private val packCards = container.packSetupService.availableOffers().map(OnboardingCopyPolicy::toCard)

    private var selectedOfferId = recommendation.suggestedOfferId
    private var activeSection = WorkbenchSection.Cases
    private var selectedCaseId = container.caseWorkspaceService.listCases().first().id
    private var captureDraft = container.quickCaptureService.draft()
    private var lawQuery = "public records response deadline"
    private var lawPreview = PublicLawPreview(
        title = "Ready for a network-safe preview",
        jurisdiction = "Public-law reference",
        summary = "Run a preview when you need statutes, deadlines, or procedure language without carrying case facts across the network boundary.",
        highlights = listOf(
            "Use neutral legal topics instead of client identifiers.",
            "Review the ledger after each outward preview.",
        ),
        cautionLabel = "No preview has been sent yet.",
    )

    var uiState by mutableStateOf(buildState())
        private set

    fun selectOffer(offerId: String) {
        selectedOfferId = offerId
        refresh()
    }

    fun completeOnboarding() {
        val selection = OnboardingSelection(selectedOfferId = selectedOfferId)
        container.onboardingService.complete(selection)
        val plan = container.packSetupService.buildPlan(selection, recommendation)
        container.capabilityWorkScheduler.schedule(deviceSnapshot, recommendation)
        container.instantModeBannerScheduler.schedule(recommendation)
        container.privacyLedgerWorkScheduler.scheduleMaintenance()
        container.downloadOrchestrator.schedule(plan)
        refresh()
    }

    fun openSection(section: WorkbenchSection) {
        activeSection = section
        refresh()
    }

    fun selectCase(caseId: String) {
        selectedCaseId = caseId
        refresh()
    }

    fun updateCaptureHeadline(headline: String) {
        captureDraft = captureDraft.copy(headline = headline)
        refresh()
    }

    fun updateCaptureBody(body: String) {
        captureDraft = captureDraft.copy(body = body)
        refresh()
    }

    fun saveCapture() {
        container.quickCaptureService.save(captureDraft)
        captureDraft = container.quickCaptureService.draft()
        activeSection = WorkbenchSection.Ledger
        refresh()
    }

    fun updateLawQuery(query: String) {
        lawQuery = query
        refresh()
    }

    fun runLawPreview() {
        lawPreview = container.publicLawPreviewService.preview(lawQuery)
        refresh()
    }

    fun updateSettings(transform: (SettingsSnapshot) -> SettingsSnapshot) {
        container.settingsService.update(transform(container.settingsService.snapshot()))
        refresh()
    }

    private fun refresh() {
        uiState = buildState()
    }

    private fun buildState(): AppUiState {
        val cases = container.caseWorkspaceService.listCases()

        return AppUiState(
            onboardingRequired = !container.onboardingService.hasCompletedOnboarding(),
            onboarding = OnboardingUiState(
                copy = container.onboardingService.onboardingCopy(),
                recommendationHeadline = recommendation.headline,
                recommendationReason = recommendation.reason,
                packCards = packCards.map { card ->
                    card.copy(recommended = card.offerId == recommendation.suggestedOfferId)
                },
                selectedOfferId = selectedOfferId,
            ),
            workbench = WorkbenchUiState(
                activeSection = activeSection,
                cases = cases,
                selectedCaseId = selectedCaseId,
                workspace = container.caseWorkspaceService.workspace(selectedCaseId),
                captureDraft = captureDraft,
                lawQuery = lawQuery,
                lawPreview = lawPreview,
                ledgerEntries = container.privacyLedgerService.recentEntries(),
                downloadSession = container.downloadOrchestrator.latestSession(),
                instantModeBanner = container.instantModeAdvisor.bannerFor(recommendation),
                settings = container.settingsService.snapshot(),
            ),
        )
    }
}
