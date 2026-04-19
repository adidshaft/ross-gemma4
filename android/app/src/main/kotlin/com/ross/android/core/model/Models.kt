package com.ross.android.core.model

enum class WorkbenchSection(val label: String) {
    Cases("Cases"),
    Capture("Notes"),
    Law("Look up a law"),
    Ledger("Activity"),
    Settings("Settings"),
}

enum class SetupMode {
    Instant,
    Balanced,
    FullLocal,
}

enum class DownloadPhase {
    Queued,
    Preparing,
    Ready,

    ;

    val displayTitle: String
        get() = when (this) {
            Queued -> "Waiting to start"
            Preparing -> "Ready to download"
            Ready -> "Downloading..."
        }
}

enum class LedgerLocality(val label: String) {
    DeviceOnly("Device only"),
    Escorted("Escorted"),
}

data class OnboardingCopy(
    val title: String,
    val body: String,
    val promises: List<String>,
)

data class OnboardingSelection(
    val selectedOfferId: String,
)

data class OnboardingPackCard(
    val offerId: String,
    val title: String,
    val body: String,
    val storageNote: String,
    val privacyNote: String,
    val recommended: Boolean,
)

data class AiPackOffer(
    val internalPackId: String,
    val displayName: String,
    val promise: String,
    val diskFootprintLabel: String,
    val privacyLabel: String,
    val suggested: Boolean,
)

data class DeviceCapabilitySnapshot(
    val memoryGb: Int,
    val freeStorageGb: Int,
    val batterySaverEnabled: Boolean,
    val prefersOfflineOnly: Boolean,
)

data class DeviceCapabilityRecommendation(
    val headline: String,
    val reason: String,
    val recommendedMode: SetupMode,
    val suggestedOfferId: String,
    val showInstantModeBanner: Boolean,
)

data class PackSetupPlan(
    val internalPackId: String,
    val publicName: String,
    val mode: SetupMode,
    val totalSegments: Int,
    val requiresWifi: Boolean,
    val readyEstimate: String,
)

data class DownloadSession(
    val sessionId: String,
    val publicName: String,
    val setupMode: SetupMode,
    val phase: DownloadPhase,
    val progressNote: String,
    val resumable: Boolean,
)

data class DownloadCheckpoint(
    val sessionId: String,
    val publicName: String,
    val completedSegments: Int,
    val totalSegments: Int,
)

data class AdvocateCaseSummary(
    val id: String,
    val title: String,
    val sensitivity: String,
    val urgencyLabel: String,
    val nextStep: String,
)

data class CaseWorkspace(
    val caseId: String,
    val summary: String,
    val parties: String,
    val upcomingTasks: List<String>,
    val legalQuestions: List<String>,
)

data class CaptureDraft(
    val headline: String,
    val body: String,
    val promptHint: String,
    val sensitivityLabel: String,
)

data class PublicLawPreview(
    val title: String,
    val jurisdiction: String,
    val summary: String,
    val highlights: List<String>,
    val cautionLabel: String,
)

data class PrivacyLedgerEntry(
    val id: String,
    val title: String,
    val detail: String,
    val occurredAt: String,
    val locality: LedgerLocality,
)

data class InstantModeBanner(
    val title: String,
    val body: String,
    val actionLabel: String,
)

data class SettingsSnapshot(
    val instantModeAllowed: Boolean,
    val biometricGateEnabled: Boolean,
    val escortNetworkRequests: Boolean,
    val wifiOnlyDownloads: Boolean,
)
