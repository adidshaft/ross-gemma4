package com.privatedigitalclerk.android.feature

import com.privatedigitalclerk.android.core.model.AdvocateCaseSummary
import com.privatedigitalclerk.android.core.model.CaptureDraft
import com.privatedigitalclerk.android.core.model.CaseWorkspace
import com.privatedigitalclerk.android.core.model.DownloadSession
import com.privatedigitalclerk.android.core.model.InstantModeBanner
import com.privatedigitalclerk.android.core.model.OnboardingCopy
import com.privatedigitalclerk.android.core.model.OnboardingPackCard
import com.privatedigitalclerk.android.core.model.PrivacyLedgerEntry
import com.privatedigitalclerk.android.core.model.PublicLawPreview
import com.privatedigitalclerk.android.core.model.SettingsSnapshot
import com.privatedigitalclerk.android.core.model.WorkbenchSection

data class AppUiState(
    val onboardingRequired: Boolean,
    val onboarding: OnboardingUiState,
    val workbench: WorkbenchUiState,
)

data class OnboardingUiState(
    val copy: OnboardingCopy,
    val recommendationHeadline: String,
    val recommendationReason: String,
    val packCards: List<OnboardingPackCard>,
    val selectedOfferId: String,
)

data class WorkbenchUiState(
    val activeSection: WorkbenchSection,
    val cases: List<AdvocateCaseSummary>,
    val selectedCaseId: String,
    val workspace: CaseWorkspace,
    val captureDraft: CaptureDraft,
    val lawQuery: String,
    val lawPreview: PublicLawPreview,
    val ledgerEntries: List<PrivacyLedgerEntry>,
    val downloadSession: DownloadSession?,
    val instantModeBanner: InstantModeBanner?,
    val settings: SettingsSnapshot,
)
