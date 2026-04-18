package com.ross.android.feature

import com.ross.android.core.model.AdvocateCaseSummary
import com.ross.android.core.model.CaptureDraft
import com.ross.android.core.model.CaseWorkspace
import com.ross.android.core.model.DownloadSession
import com.ross.android.core.model.InstantModeBanner
import com.ross.android.core.model.OnboardingCopy
import com.ross.android.core.model.OnboardingPackCard
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.PublicLawPreview
import com.ross.android.core.model.SettingsSnapshot
import com.ross.android.core.model.WorkbenchSection

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
