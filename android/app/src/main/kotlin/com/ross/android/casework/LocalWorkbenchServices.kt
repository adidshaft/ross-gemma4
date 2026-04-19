package com.ross.android.casework

import com.ross.android.core.domain.CaseWorkspaceService
import com.ross.android.core.domain.OnboardingService
import com.ross.android.core.domain.PrivacyLedgerService
import com.ross.android.core.domain.PrivateAiPackSetupService
import com.ross.android.core.domain.QuickCaptureService
import com.ross.android.core.domain.SettingsService
import com.ross.android.core.model.AdvocateCaseSummary
import com.ross.android.core.model.AiPackOffer
import com.ross.android.core.model.CaptureDraft
import com.ross.android.core.model.CaseWorkspace
import com.ross.android.core.model.DeviceCapabilityRecommendation
import com.ross.android.core.model.LedgerLocality
import com.ross.android.core.model.OnboardingCopy
import com.ross.android.core.model.OnboardingSelection
import com.ross.android.core.model.PackSetupPlan
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.SettingsSnapshot
import com.ross.android.core.model.SetupMode

class LocalOnboardingService : OnboardingService {
    private var completed = false

    override fun hasCompletedOnboarding(): Boolean = completed

    override fun onboardingCopy(): OnboardingCopy {
        return OnboardingCopy(
            title = "A private file room for your practice",
            body = "Choose the setup that matches your phone and start with a calm, case-safe workspace.",
            promises = listOf(
                "Your case files never leave this phone.",
                "Ross reads only the documents you add to a matter.",
                "Ross asks before anything goes online.",
            ),
        )
    }

    override fun complete(selection: OnboardingSelection) {
        completed = selection.selectedOfferId.isNotBlank()
    }
}

class LocalPrivateAiPackSetupService : PrivateAiPackSetupService {
    private val offers = listOf(
        AiPackOffer(
            internalPackId = "intake-ready",
            displayName = "Fast intake desk",
            promise = "Start interviews, notes, and triage immediately while the rest of the workspace fills in quietly.",
            diskFootprintLabel = "Light local footprint",
            privacyLabel = "Best when you want the smallest local surface area on day one.",
            suggested = false,
        ),
        AiPackOffer(
            internalPackId = "balanced-counsel",
            displayName = "Balanced counsel desk",
            promise = "Keep drafting and statute preview close at hand with a measured local footprint.",
            diskFootprintLabel = "Moderate local footprint",
            privacyLabel = "Good default for steady case review and protected research.",
            suggested = true,
        ),
        AiPackOffer(
            internalPackId = "full-library",
            displayName = "Deep offline library",
            promise = "Carry a broader private research bench for extended travel or sensitive field work.",
            diskFootprintLabel = "Largest local footprint",
            privacyLabel = "Best when your practice requires longer stretches away from network access.",
            suggested = false,
        ),
    )

    override fun availableOffers(): List<AiPackOffer> = offers

    override fun buildPlan(
        selection: OnboardingSelection,
        recommendation: DeviceCapabilityRecommendation,
    ): PackSetupPlan {
        val offer = offers.firstOrNull { it.internalPackId == selection.selectedOfferId } ?: offers[1]
        val mode = recommendation.recommendedMode

        return PackSetupPlan(
            internalPackId = offer.internalPackId,
            publicName = offer.displayName,
            mode = mode,
            totalSegments = when (mode) {
                SetupMode.Instant -> 2
                SetupMode.Balanced -> 4
                SetupMode.FullLocal -> 6
            },
            requiresWifi = mode != SetupMode.Instant,
            readyEstimate = when (mode) {
                SetupMode.Instant -> "ready in minutes"
                SetupMode.Balanced -> "ready this session"
                SetupMode.FullLocal -> "ready after protected staged download"
            },
        )
    }
}

class LocalCaseWorkspaceService : CaseWorkspaceService {
    private val cases = listOf(
        AdvocateCaseSummary(
            id = "case-01",
            title = "Housing lockout intake",
            sensitivity = "Tenant testimony",
            urgencyLabel = "Today",
            nextStep = "Confirm documentary timeline and preserve photos.",
        ),
        AdvocateCaseSummary(
            id = "case-02",
            title = "Benefits denial appeal",
            sensitivity = "Medical disclosures",
            urgencyLabel = "This week",
            nextStep = "Draft reconsideration letter and hearing checklist.",
        ),
        AdvocateCaseSummary(
            id = "case-03",
            title = "Neighborhood records request",
            sensitivity = "Community strategy",
            urgencyLabel = "Monitoring",
            nextStep = "Track the response deadline and likely legal grounds.",
        ),
    )

    private val workspaces = mapOf(
        "case-01" to CaseWorkspace(
            caseId = "case-01",
            summary = "Potential unlawful exclusion after rent dispute. Preserve time-stamped evidence and emergency relief options.",
            parties = "Client, property manager, city marshal liaison",
            upcomingTasks = listOf(
                "Record witness names from building hallway",
                "Prepare temporary access demand",
                "Flag local anti-lockout protections",
            ),
            legalQuestions = listOf(
                "What emergency filing path is fastest in this borough?",
                "Which records can corroborate possession without a lease copy?",
            ),
        ),
        "case-02" to CaseWorkspace(
            caseId = "case-02",
            summary = "Administrative appeal with sparse agency reasoning. Need chronology, evidence map, and hearing prep.",
            parties = "Client, agency reviewer, treating clinician",
            upcomingTasks = listOf(
                "Organize denial rationale by category",
                "Draft appeal narrative",
                "Prepare accommodations request if needed",
            ),
            legalQuestions = listOf(
                "Is there a pre-hearing supplementation window?",
                "Which findings need medical corroboration?",
            ),
        ),
        "case-03" to CaseWorkspace(
            caseId = "case-03",
            summary = "Open records matter tied to zoning oversight. Research timing rules and exceptions before escalation.",
            parties = "Neighborhood coalition, records officer, oversight board",
            upcomingTasks = listOf(
                "Compare response date against statutory deadline",
                "Draft narrow follow-up request",
                "Prepare escalation memo",
            ),
            legalQuestions = listOf(
                "Which exemptions are usually over-claimed here?",
                "What public-interest framing improves release odds?",
            ),
        ),
    )

    override fun listCases(): List<AdvocateCaseSummary> = cases

    override fun workspace(caseId: String): CaseWorkspace {
        return workspaces[caseId] ?: workspaces.getValue(cases.first().id)
    }
}

class LocalQuickCaptureService(
    private val ledgerService: PrivacyLedgerService,
) : QuickCaptureService {
    override fun draft(): CaptureDraft {
        return CaptureDraft(
            headline = "Field capture",
            body = "",
            promptHint = "Record only what you need right now. You can structure and file it later.",
            sensitivityLabel = "Device-only until filed to a case",
        )
    }

    override fun save(draft: CaptureDraft): PrivacyLedgerEntry {
        val entry = PrivacyLedgerEntry(
            id = "ledger-capture-${System.currentTimeMillis()}",
            title = "Quick capture saved",
            detail = "Saved '${draft.headline}' locally for later case filing.",
            occurredAt = "Just now",
            locality = LedgerLocality.DeviceOnly,
        )
        ledgerService.record(entry)
        return entry
    }
}

class InMemoryPrivacyLedgerService : PrivacyLedgerService {
    private val entries = mutableListOf(
        PrivacyLedgerEntry(
            id = "ledger-01",
            title = "Opened Ross",
            detail = "Ross showed your case summaries without contacting external services.",
            occurredAt = "Today 09:10",
            locality = LedgerLocality.DeviceOnly,
        ),
        PrivacyLedgerEntry(
            id = "ledger-02",
            title = "Looked up a law",
            detail = "Ross looked up a law online without sending case notes.",
            occurredAt = "Today 08:42",
            locality = LedgerLocality.Escorted,
        ),
    )

    override fun recentEntries(): List<PrivacyLedgerEntry> = entries.toList().reversed()

    override fun record(entry: PrivacyLedgerEntry) {
        entries += entry
    }
}

class InMemorySettingsService : SettingsService {
    private var current = SettingsSnapshot(
        instantModeAllowed = true,
        biometricGateEnabled = true,
        escortNetworkRequests = true,
        wifiOnlyDownloads = true,
    )

    override fun snapshot(): SettingsSnapshot = current

    override fun update(snapshot: SettingsSnapshot) {
        current = snapshot
    }
}
