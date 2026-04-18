package com.ross.android.core.domain

import com.ross.android.core.model.AdvocateCaseSummary
import com.ross.android.core.model.AiPackOffer
import com.ross.android.core.model.CaptureDraft
import com.ross.android.core.model.CaseWorkspace
import com.ross.android.core.model.DeviceCapabilityRecommendation
import com.ross.android.core.model.DeviceCapabilitySnapshot
import com.ross.android.core.model.DownloadSession
import com.ross.android.core.model.InstantModeBanner
import com.ross.android.core.model.OnboardingCopy
import com.ross.android.core.model.OnboardingSelection
import com.ross.android.core.model.PackSetupPlan
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.PublicLawPreview
import com.ross.android.core.model.SettingsSnapshot

interface OnboardingService {
    fun hasCompletedOnboarding(): Boolean
    fun onboardingCopy(): OnboardingCopy
    fun complete(selection: OnboardingSelection)
}

interface PrivateAiPackSetupService {
    fun availableOffers(): List<AiPackOffer>
    fun buildPlan(
        selection: OnboardingSelection,
        recommendation: DeviceCapabilityRecommendation,
    ): PackSetupPlan
}

interface DeviceCapabilityRecommender {
    fun recommend(snapshot: DeviceCapabilitySnapshot): DeviceCapabilityRecommendation
}

interface InstantModeAdvisor {
    fun bannerFor(recommendation: DeviceCapabilityRecommendation): InstantModeBanner?
}

interface CaseWorkspaceService {
    fun listCases(): List<AdvocateCaseSummary>
    fun workspace(caseId: String): CaseWorkspace
}

interface QuickCaptureService {
    fun draft(): CaptureDraft
    fun save(draft: CaptureDraft): PrivacyLedgerEntry
}

interface PublicLawPreviewService {
    fun preview(query: String): PublicLawPreview
}

interface PrivacyLedgerService {
    fun recentEntries(): List<PrivacyLedgerEntry>
    fun record(entry: PrivacyLedgerEntry)
}

interface SettingsService {
    fun snapshot(): SettingsSnapshot
    fun update(snapshot: SettingsSnapshot)
}

interface ModelDownloadOrchestrator {
    fun schedule(plan: PackSetupPlan): DownloadSession
    fun latestSession(): DownloadSession?
}

interface PublicLawGateway {
    fun fetchPreview(query: String): PublicLawPreview
}

interface ModelDownloadGateway {
    fun createSession(plan: PackSetupPlan, sessionId: String): DownloadSession
}

interface DownloadWorkScheduler {
    fun enqueue(plan: PackSetupPlan): String
}

interface DeviceCapabilityWorkScheduler {
    fun schedule(
        snapshot: DeviceCapabilitySnapshot,
        recommendation: DeviceCapabilityRecommendation,
    )
}

interface InstantModeBannerScheduler {
    fun schedule(recommendation: DeviceCapabilityRecommendation)
}

interface PrivacyLedgerWorkScheduler {
    fun scheduleMaintenance()
}
