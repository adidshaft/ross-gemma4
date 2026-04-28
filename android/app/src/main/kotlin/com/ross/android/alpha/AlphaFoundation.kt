package com.ross.android.alpha

import android.content.Context
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.webkit.MimeTypeMap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.ross.android.BuildConfig
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.UUID

internal const val ALPHA_ROSS_SUGGESTED_TASK_NOTE_PREFIX = "ross-overview::"
const val ALPHA_SHARED_WORKSPACE_ID = "0d9e5220-4d3c-4b49-9a67-10b42b593b7d"
private const val ALPHA_BACKEND_PREFS = "ross_alpha_backend"
private const val ALPHA_BACKEND_BASE_URL_OVERRIDE_KEY = "backend_base_url_override"

private fun normalizedBackendBaseUrlOverride(rawValue: String?): String? =
    rawValue?.trim()?.takeIf { it.isNotEmpty() }

internal class AlphaBackendBaseUrlOverrideSnapshot private constructor() {
    private val lock = Any()
    private var baseUrlOverride: String? = null

    fun update(rawValue: String?) {
        synchronized(lock) {
            baseUrlOverride = normalizedBackendBaseUrlOverride(rawValue)
        }
    }

    fun value(): String? =
        synchronized(lock) {
            baseUrlOverride
        }

    companion object {
        val shared = AlphaBackendBaseUrlOverrideSnapshot()
    }
}

private fun Context.readRossBackendBaseUrlOverride(): String? =
    normalizedBackendBaseUrlOverride(
        getSharedPreferences(ALPHA_BACKEND_PREFS, Context.MODE_PRIVATE)
            .getString(ALPHA_BACKEND_BASE_URL_OVERRIDE_KEY, null)
    )

private fun Context.writeRossBackendBaseUrlOverride(rawValue: String?) {
    val normalized = normalizedBackendBaseUrlOverride(rawValue)
    getSharedPreferences(ALPHA_BACKEND_PREFS, Context.MODE_PRIVATE)
        .edit()
        .apply {
            if (normalized == null) {
                remove(ALPHA_BACKEND_BASE_URL_OVERRIDE_KEY)
            } else {
                putString(ALPHA_BACKEND_BASE_URL_OVERRIDE_KEY, normalized)
            }
        }
        .apply()
}

enum class AlphaOnboardingStage { Onboarding, PrivateAiPack, Completed }
enum class AlphaAppTab { Home, Cases, Capture, Ask, Settings, PublicLaw, Exports }
enum class AlphaAppearanceMode(val label: String) {
    Auto("Auto (Default)"),
    Dark("Dark"),
    Light("Light"),
}
enum class AlphaCapabilityTier(val tierId: String, val title: String, val summary: String, val downloadSizeLabel: String, val installedSizeLabel: String) {
    QuickStart("quick_start", "Basic", "Lighter setup for short orders, quick summaries, and simple private Ask Ross actions.", "about 304 MB", "about 304 MB"),
    CaseAssociate("case_associate", "Standard", "Recommended for everyday matters, document review, chronology work, and source-backed answers.", "about 555 MB", "about 555 MB"),
    SeniorDraftingSupport("senior_drafting_support", "Advanced", "Best for longer bundles, deeper review, and heavier drafting on this phone.", "about 690 MB", "about 690 MB");

    val setupTitle: String
        get() = when (this) {
            QuickStart -> "Basic - short orders only"
            CaseAssociate -> "Standard - most matters"
            SeniorDraftingSupport -> "Advanced - long bundles and drafting"
        }

    val compactSetupSummary: String
        get() = when (this) {
            QuickStart -> "Short orders"
            CaseAssociate -> "Most matters"
            SeniorDraftingSupport -> "Long bundles"
        }

    val storageNote: String
        get() = when (this) {
            QuickStart -> "Light footprint"
            CaseAssociate -> "Balanced footprint"
            SeniorDraftingSupport -> "Largest footprint"
        }

    val bestFor: String
        get() = when (this) {
            QuickStart -> "Fast intake, smaller devices, and short document Q&A after the model is installed."
            CaseAssociate -> "Most advocates who need document review, next dates, chronologies, notes, and source-backed answers on-device."
            SeniorDraftingSupport -> "Longer bundles, deeper review, hearing preparation, and more detailed drafting support."
        }

    val setupWarning: String
        get() = when (this) {
            QuickStart -> "Download about 304 MB before you begin. Wi-Fi is still the safest option."
            CaseAssociate -> "Download about 555 MB before you begin. Keep this phone on Wi-Fi and make sure there is enough free space."
            SeniorDraftingSupport -> "Download about 690 MB before you begin. Use strong Wi-Fi and check that this phone has plenty of free space."
        }

    val setupTimeLabel: String
        get() = when (this) {
            QuickStart -> "about 2 min"
            CaseAssociate -> "about 4 min"
            SeniorDraftingSupport -> "about 7 min"
        }

    val extractionQuality: String
        get() = when (this) {
            QuickStart -> "Standard"
            CaseAssociate -> "Advanced"
            SeniorDraftingSupport -> "Advanced"
        }

    val rank: Int
        get() = when (this) {
            QuickStart -> 1
            CaseAssociate -> 2
            SeniorDraftingSupport -> 3
        }
}
enum class AlphaAssistantDeviceSupportState { Supported, AutoDowngraded, NeedsStorage, NeedsNewerOs, Unavailable }
enum class AlphaAssistantInstallState { NotStarted, Queued, Downloading, Installed, Failed }
data class AlphaAssistantRuntimeDecision(
    val selectedTier: AlphaCapabilityTier,
    val recommendedTier: AlphaCapabilityTier,
    val effectiveTier: AlphaCapabilityTier,
    val displayName: String,
    val deviceSupportState: AlphaAssistantDeviceSupportState,
    val modelPackId: String,
    val installState: AlphaAssistantInstallState,
    val reason: String,
)
enum class AlphaCaseStage { Intake, Pleadings, Evidence, Arguments, Reserved, Disposed }
enum class AlphaMatterTint { Indigo, Amber, Emerald, Rose, Slate }
enum class AlphaTaskPriority { Low, Normal, High }
enum class AlphaTaskStatus { Open, Done }
enum class AlphaTaskSource { Manual, Extraction, System }
enum class AlphaMatterDateKind { Hearing, FilingDeadline, ComplianceDate, ClientFollowUp }
enum class AlphaMatterDateStatus { Scheduled, Done, Cancelled }
enum class AlphaDocumentKind { Pdf, Image, Text, Unknown }
enum class AlphaOcrStatus { NotStarted, Indexed, Placeholder, NativeText, OcrComplete, Partial, Failed }
enum class AlphaIndexingStatus { NotStarted, Extracting, Indexed, Partial, Failed }
enum class AlphaDownloadState { NotStarted, Queued, Downloading, PausedWaitingForWifi, PausedUser, PausedNoStorage, PausedError, Verifying, Installed, Failed, Cancelled }
enum class AlphaDownloadPolicy { WifiOnly, MobileAllowed }

val AlphaDocumentKind.title: String
    get() = when (this) {
        AlphaDocumentKind.Pdf -> "PDF"
        AlphaDocumentKind.Image -> "IMAGE"
        AlphaDocumentKind.Text -> "TEXT"
        AlphaDocumentKind.Unknown -> "FILE"
    }

val AlphaMatterDateKind.title: String
    get() = when (this) {
        AlphaMatterDateKind.Hearing -> "Hearing"
        AlphaMatterDateKind.FilingDeadline -> "Filing deadline"
        AlphaMatterDateKind.ComplianceDate -> "Compliance date"
        AlphaMatterDateKind.ClientFollowUp -> "Client follow-up"
    }

val AlphaCaseStage.displayTitle: String
    get() = when (this) {
        AlphaCaseStage.Intake -> "Filing"
        AlphaCaseStage.Pleadings -> "Pleadings"
        AlphaCaseStage.Evidence -> "Evidence"
        AlphaCaseStage.Arguments -> "Arguments"
        AlphaCaseStage.Reserved -> "Judgment Reserved"
        AlphaCaseStage.Disposed -> "Disposed"
    }

enum class AlphaPackRuntimeMode(val wireValue: String) {
    DeterministicDev("deterministic_dev"),
    MediapipeLlm("mediapipe_llm"),
    Gemma 4 E4B Q4CppGguf("gemma_local_runtime"),
    AppleFoundationModels("apple_foundation_models"),
    Unavailable("unavailable");

    val title: String
        get() = wireValue.replace("_", " ")
}
enum class AlphaPrivacyPurpose { LocalOnly, ModelCatalog, ModelDownload, ModelVerification, PublicLawSearch }
enum class AlphaPayloadClass { LocalOnly, NoCaseData, SanitizedPublicQuery, AccountToken }

data class AlphaDocumentPage(
    val id: String = UUID.randomUUID().toString(),
    val pageNumber: Int,
    val snippet: String? = null,
    val extractedText: String? = null,
    val anchorText: String? = null,
    val ocrConfidence: Double? = null,
    val ocrStatus: AlphaOcrStatus? = null,
    val indexingStatus: AlphaIndexingStatus? = null,
)

data class AlphaSourceRef(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val documentTitle: String,
    val pageNumber: Int,
    val paragraphRange: String? = null,
    val textSnippet: String? = null,
    val ocrConfidence: Double? = null,
) {
    val label: String get() = "$documentTitle p. $pageNumber"
    val detail: String get() = textSnippet ?: "Source reference"
}

data class AlphaCaseDocument(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val fileName: String,
    val kind: AlphaDocumentKind,
    val storedRelativePath: String,
    val importedAt: String = nowIso(),
    val pageCount: Int,
    val ocrStatus: AlphaOcrStatus,
    val extractedText: String? = null,
    val indexingStatus: AlphaIndexingStatus? = null,
    val dominantSourceSnippet: String? = null,
    val lastIndexedAt: String? = null,
    val pages: List<AlphaDocumentPage>,
    val languageProfile: AlphaDocumentLanguageProfile? = null,
    val classification: AlphaLegalDocumentClassification? = null,
    val extractedFields: List<AlphaExtractedLegalField> = emptyList(),
    val extractionRuns: List<AlphaExtractionRun> = emptyList(),
    val extractionFindings: List<AlphaExtractionFinding> = emptyList(),
    val modelInvocations: List<AlphaLocalModelInvocation> = emptyList(),
)

data class AlphaTaskItem(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String? = null,
    val title: String,
    val notes: String? = null,
    val dueDate: String? = null,
    val priority: AlphaTaskPriority = AlphaTaskPriority.Normal,
    val status: AlphaTaskStatus = AlphaTaskStatus.Open,
    val source: AlphaTaskSource = AlphaTaskSource.Manual,
    val createdAt: String = nowIso(),
    val updatedAt: String = nowIso(),
)

data class AlphaMatterDate(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val title: String,
    val kind: AlphaMatterDateKind,
    val date: String,
    val status: AlphaMatterDateStatus = AlphaMatterDateStatus.Scheduled,
    val notes: String? = null,
    val sourceRef: AlphaSourceRef? = null,
)

data class AlphaReviewQueueItem(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val caseTitle: String,
    val title: String,
    val detail: String,
    val sourceRef: AlphaSourceRef? = null,
)

data class AlphaAskResult(
    val question: String,
    val scopeCaseId: String?,
    val scopeLabel: String,
    val selectedDocumentTitles: List<String> = emptyList(),
    val answerTitle: String,
    val answerSections: List<String>,
    val caseFileSources: List<AlphaSourceRef>,
    val publicLawPreview: AlphaPublicLawPreview? = null,
    val publicLawResults: List<AlphaPublicLawResult> = emptyList(),
    val statusNote: String? = null,
    val needsReviewWarning: String? = null,
)

data class AlphaMatterAskRuntimePayload(
    val headline: String,
    val sections: List<String>,
    val statusNote: String? = null,
)

data class AlphaChatTurn(
    val id: String = UUID.randomUUID().toString(),
    val askedAt: String = nowIso(),
    val question: String,
    val answerTitle: String,
    val answerSections: List<String>,
    val sourceRefs: List<AlphaSourceRef>,
)

data class AlphaCaseMatter(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val forum: String,
    val stage: AlphaCaseStage,
    val folderTint: AlphaMatterTint = AlphaMatterTint.Indigo,
    val nextHearing: String? = null,
    val localNotice: String = "Case files stay on this device",
    val summary: String,
    val issueHighlights: List<String>,
    val evidenceNotes: List<String>,
    val draftTasks: List<String>,
    val dates: List<AlphaMatterDate> = emptyList(),
    val documents: List<AlphaCaseDocument>,
    val sourceRefs: List<AlphaSourceRef>,
    val chatTurns: List<AlphaChatTurn> = emptyList(),
    val advocateCorrections: List<AlphaAdvocateCorrection> = emptyList(),
    val caseMemoryUpdates: List<AlphaCaseMemoryUpdate> = emptyList(),
    val updatedAt: String = nowIso(),
    val archivedAt: String? = null,
)

data class AlphaPrivacyLedgerEntry(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: String = nowIso(),
    val title: String,
    val detail: String,
    val purpose: AlphaPrivacyPurpose,
    val payloadClass: AlphaPayloadClass,
    val endpointLabel: String,
    val success: Boolean,
)

data class AlphaModelDownloadJob(
    val id: String = UUID.randomUUID().toString(),
    val sessionId: String,
    val packId: String,
    val tier: AlphaCapabilityTier,
    val state: AlphaDownloadState,
    val networkPolicy: AlphaDownloadPolicy,
    val bytesDownloaded: Long,
    val totalBytes: Long,
    val checksumSha256: String,
    val artifactKind: String = "local_model_artifact",
    val runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.Unavailable,
    val developmentOnly: Boolean = false,
    val minimumAppVersion: String = "0.1.0",
    val failureReason: String? = null,
    val createdAt: String = nowIso(),
    val updatedAt: String = nowIso(),
    val completedAt: String? = null,
)

data class AlphaAskWorkStatus(
    val question: String,
    val scopeCaseId: String?,
    val message: String,
    val detail: String,
    val startedAt: String = nowIso(),
)

data class AlphaInstalledPack(
    val id: String = UUID.randomUUID().toString(),
    val packId: String,
    val tier: AlphaCapabilityTier,
    val installRelativePath: String,
    val checksumSha256: String,
    val artifactKind: String = "local_model_artifact",
    val runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.Unavailable,
    val developmentOnly: Boolean = false,
    val checksumVerified: Boolean = false,
    val minimumAppVersion: String = "0.1.0",
    val installedAt: String = nowIso(),
    val isActive: Boolean,
)

data class AlphaPublicLawPreview(
    val query: String,
    val removed: List<String>,
    val confirmationNote: String,
)

data class AlphaPublicLawResult(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val citation: String,
    val snippet: String,
    val sourceName: String,
)

data class AlphaPublicLawCacheItem(
    val id: String = UUID.randomUUID().toString(),
    val query: String,
    val savedAt: String = nowIso(),
    val resultTitles: List<String>,
)

data class AlphaExportRecord(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String?,
    val title: String,
    val kind: String,
    val relativePath: String,
    val createdAt: String = nowIso(),
)

data class AlphaLocalInferenceSmokeReport(
    val ran: Boolean,
    val runtimeUsed: String,
    val schemaValid: Boolean,
    val fieldsFound: Int,
    val fieldsVerified: Int,
    val fieldsNeedingReview: Int,
    val unsupportedAccepted: Int,
    val exportRelativePath: String?,
    val message: String,
    val createdAt: String = nowIso(),
)

data class AlphaSettings(
    val activeTier: AlphaCapabilityTier? = null,
    val wifiOnlyDownloads: Boolean = true,
    val allowMobileDataForLargePacks: Boolean = false,
    val requirePublicLawApproval: Boolean = false,
    val instantModeEnabled: Boolean = true,
    val privateByDefault: Boolean = true,
    val appearanceMode: AlphaAppearanceMode = AlphaAppearanceMode.Auto,
)

enum class AlphaAccountAuthMode { Demo, Google }

data class AlphaAccountSession(
    val email: String? = null,
    val displayName: String? = null,
    val providerLabel: String = "Demo mode",
    val authMode: AlphaAccountAuthMode? = null,
    val accessToken: String? = null,
    val refreshToken: String? = null,
    val accountToken: String? = null,
    val subject: String? = null,
    val expiresAt: String? = null,
    val awaitingBrowserReturn: Boolean = false,
    val quickUnlockEnabled: Boolean = false,
    val locked: Boolean = false,
    val lastUnlockedAt: String? = null,
) {
    val isSignedIn: Boolean
        get() = !email.isNullOrBlank() && !accountToken.isNullOrBlank()

    val isDemoMode: Boolean
        get() = authMode == AlphaAccountAuthMode.Demo
}

internal class AlphaAccountSessionSnapshot private constructor() {
    private val lock = Any()
    private var cachedSession: AlphaAccountSession? = null

    fun update(session: AlphaAccountSession?) {
        synchronized(lock) {
            cachedSession = session?.takeIf { it.isSignedIn }
        }
    }

    fun accountToken(fallback: String): String =
        synchronized(lock) {
            cachedSession?.accountToken ?: fallback
        }

    fun accessToken(): String? =
        synchronized(lock) {
            cachedSession?.accessToken
        }

    companion object {
        val shared = AlphaAccountSessionSnapshot()
    }
}

data class AlphaPersistedState(
    val onboardingStage: AlphaOnboardingStage = AlphaOnboardingStage.Completed,
    val selectedTab: AlphaAppTab = AlphaAppTab.Home,
    val settings: AlphaSettings = AlphaSettings(),
    val accountSession: AlphaAccountSession = AlphaAccountSession(),
    val demoProfileSubject: String? = null,
    val cases: List<AlphaCaseMatter> = listOf(sharedWorkspaceMatter()),
    val tasks: List<AlphaTaskItem>? = emptyList(),
    val ledgerEntries: List<AlphaPrivacyLedgerEntry> = listOf(
        AlphaPrivacyLedgerEntry(
            title = "Model catalog checked",
            detail = "Catalog metadata was reviewed without case files attached.",
            purpose = AlphaPrivacyPurpose.ModelCatalog,
            payloadClass = AlphaPayloadClass.NoCaseData,
            endpointLabel = "/model-catalog",
            success = true,
        )
    ),
    val modelJobs: List<AlphaModelDownloadJob> = emptyList(),
    val installedPacks: List<AlphaInstalledPack> = emptyList(),
    val localInferenceMetrics: List<AlphaLocalInferenceMetrics> = emptyList(),
    val publicLawCache: List<AlphaPublicLawCacheItem> = emptyList(),
    val exports: List<AlphaExportRecord> = emptyList(),
)

data class AlphaAskDocumentOption(
    val id: String,
    val caseId: String,
    val caseTitle: String,
    val title: String,
    val kind: AlphaDocumentKind,
    val isShared: Boolean,
)

sealed interface AndroidAlphaRoute {
    data object Onboarding : AndroidAlphaRoute
    data object PrivateAiPack : AndroidAlphaRoute
    data object Home : AndroidAlphaRoute
    data object CaseList : AndroidAlphaRoute
    data object Capture : AndroidAlphaRoute
    data object AskRoss : AndroidAlphaRoute
    data object CreateCase : AndroidAlphaRoute
    data class CaseWorkspace(val caseId: String) : AndroidAlphaRoute
    data class DocumentList(val caseId: String) : AndroidAlphaRoute
    data class DocumentViewer(val caseId: String, val documentId: String, val pageNumber: Int?) : AndroidAlphaRoute
    data class AskCase(val caseId: String) : AndroidAlphaRoute
    data object PublicLawPreview : AndroidAlphaRoute
    data class DraftsExports(val caseId: String?) : AndroidAlphaRoute
    data object PrivacyLedger : AndroidAlphaRoute
    data object Settings : AndroidAlphaRoute
    data object PrivateAiSettings : AndroidAlphaRoute
}

internal class AlphaRossController(
    private val context: Context,
    private val publicLawSearchOverride: (suspend (AlphaPublicLawPreview) -> List<AlphaPublicLawResult>)? = null,
    private val secretKeyProvider: AlphaSecretKeyProvider = AndroidKeystoreAlphaSecretKeyProvider(),
    private val askRuntimeProviderOverride: ((AlphaInstalledPack) -> AlphaLocalModelProvider?)? = null,
) {
    private val gson: Gson = GsonBuilder().setPrettyPrinting().create()
    private val rootDir = File(context.filesDir, "ross-alpha")
    private val documentsDir = File(rootDir, "documents")
    private val modelPackDir = File(rootDir, "model-packs")
    private val exportsDir = File(rootDir, "exports")
    private val encryptedStateStore = AlphaEncryptedStateStore(
        gson = gson,
        rootDir = rootDir,
        aadLabel = context.packageName,
        secretKeyProvider = secretKeyProvider,
    )
    private val exportService = AlphaExportService(rootDir, exportsDir)
    private val backend = AlphaBackendClient(gson = gson)
    private val publicLawSearchAction: suspend (AlphaPublicLawPreview) -> List<AlphaPublicLawResult> =
        publicLawSearchOverride ?: { preview -> backend.searchPublicLaw(preview) }
    private val extractionOrchestrator = AlphaLocalExtractionOrchestrator(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private sealed interface DockCommandAction {
        data class AddTask(val title: String, val dueDate: String?) : DockCommandAction
        data class CompleteTask(val title: String) : DockCommandAction
        data class AddMatterDate(val title: String, val kind: AlphaMatterDateKind, val date: String) : DockCommandAction
        data class GenerateExport(val kind: String, val label: String) : DockCommandAction
        data object RerunDocumentReview : DockCommandAction
        data object CreateTasksFromDocument : DockCommandAction
        data class Guidance(val title: String, val detail: String) : DockCommandAction
    }

    var persisted by mutableStateOf(loadState())
    var pendingRoute by mutableStateOf<AndroidAlphaRoute?>(null)

    var selectedCaseId by mutableStateOf(persisted.cases.firstOrNull { it.id != ALPHA_SHARED_WORKSPACE_ID }?.id)
    var selectedTier by mutableStateOf(persisted.settings.activeTier ?: AlphaCapabilityTier.CaseAssociate)
    var caseDraftTitle by mutableStateOf("")
    var caseDraftForum by mutableStateOf("")
    var askDrafts by mutableStateOf<Map<String, String>>(emptyMap())
    var globalAskDraft by mutableStateOf("")
    var askSelectedScopeCaseId by mutableStateOf<String?>(null)
    var askSelectedDocumentIds by mutableStateOf<Map<String, Set<String>>>(emptyMap())
    var globalAskSelectedDocumentIds by mutableStateOf<Set<String>>(emptySet())
    var askWebEnabled by mutableStateOf(false)
    var pendingPublicLawQuestion by mutableStateOf<String?>(null)
    var pendingPublicLawScopeCaseId by mutableStateOf<String?>(null)
    var latestAskResult by mutableStateOf<AlphaAskResult?>(null)
    var askWorkStatus by mutableStateOf<AlphaAskWorkStatus?>(null)
    var askHistory by mutableStateOf(seedAskHistory(persisted.cases))
    var publicLawDraft by mutableStateOf("")
    var publicLawPreview by mutableStateOf<AlphaPublicLawPreview?>(null)
    var publicLawResults by mutableStateOf<List<AlphaPublicLawResult>>(emptyList())
    var localInferenceSmokeReport by mutableStateOf<AlphaLocalInferenceSmokeReport?>(null)
    var localInferenceSmokeRunning by mutableStateOf(false)
    var refreshingCaseOverviewIds by mutableStateOf<Set<String>>(emptySet())
    var authStatusMessage by mutableStateOf<String?>(null)

    init {
        AlphaAccountSessionSnapshot.shared.update(persisted.accountSession)
        AlphaBackendBaseUrlOverrideSnapshot.shared.update(context.readRossBackendBaseUrlOverride())
        scope.launch {
            refreshAccountSessionIfNeeded()
        }
    }

    private data class AlphaPreservedWorkspaceConfiguration(
        val settings: AlphaSettings,
        val modelJobs: List<AlphaModelDownloadJob>,
        val installedPacks: List<AlphaInstalledPack>,
        val localInferenceMetrics: List<AlphaLocalInferenceMetrics>,
    )

    private fun preservedWorkspaceConfiguration(): AlphaPreservedWorkspaceConfiguration =
        AlphaPreservedWorkspaceConfiguration(
            settings = persisted.settings,
            modelJobs = persisted.modelJobs,
            installedPacks = persisted.installedPacks,
            localInferenceMetrics = persisted.localInferenceMetrics,
        )

    private fun applyPreservedWorkspaceConfiguration(
        state: AlphaPersistedState,
        preserved: AlphaPreservedWorkspaceConfiguration,
    ): AlphaPersistedState = state.copy(
        settings = preserved.settings,
        modelJobs = preserved.modelJobs,
        installedPacks = preserved.installedPacks,
        localInferenceMetrics = preserved.localInferenceMetrics,
    )

    private fun shouldSeedDemoWorkspace(subject: String): Boolean {
        if (persisted.demoProfileSubject == subject) {
            return false
        }
        if (cases.isEmpty()) {
            return true
        }
        return isLegacySeedWorkspace() || (persisted.demoProfileSubject != null && isCurrentWorkspaceDemoOnly())
    }

    private fun isLegacySeedWorkspace(): Boolean {
        val titles = cases.map { it.title }.toSet()
        return titles == setOf(
            "Kaveri Developers v. South Ward Municipal Corporation",
            "Arun Textiles v. State Tax Officer",
        )
    }

    private fun isCurrentWorkspaceDemoOnly(): Boolean {
        val activeCases = cases
        return activeCases.size == 1 && activeCases.firstOrNull()?.title == "Demo Matter: Sharma v. Rana"
    }

    val cases: List<AlphaCaseMatter>
        get() = persisted.cases
            .filter { it.archivedAt == null && it.id != ALPHA_SHARED_WORKSPACE_ID }
            .sortedByDescending { it.updatedAt }

    val sharedWorkspace: AlphaCaseMatter?
        get() = persisted.cases.firstOrNull { it.id == ALPHA_SHARED_WORKSPACE_ID }

    private val activeCaseIds: Set<String>
        get() = cases.mapTo(linkedSetOf()) { it.id }

    fun activePack(): AlphaInstalledPack? = persisted.installedPacks.firstOrNull { it.isActive }

    fun installedPackFor(tier: AlphaCapabilityTier): AlphaInstalledPack? =
        persisted.installedPacks.firstOrNull { it.tier == tier && it.isActive }
            ?: persisted.installedPacks.firstOrNull { it.tier == tier }

    fun setupJobFor(tier: AlphaCapabilityTier): AlphaModelDownloadJob? {
        if (installedPackFor(tier) != null) return null
        return persisted.modelJobs.firstOrNull { job ->
            job.tier == tier && when (job.state) {
                AlphaDownloadState.NotStarted,
                AlphaDownloadState.Installed,
                AlphaDownloadState.Cancelled -> false
                AlphaDownloadState.Queued,
                AlphaDownloadState.Downloading,
                AlphaDownloadState.PausedWaitingForWifi,
                AlphaDownloadState.PausedUser,
                AlphaDownloadState.PausedNoStorage,
                AlphaDownloadState.PausedError,
                AlphaDownloadState.Verifying,
                AlphaDownloadState.Failed -> true
            }
        }
    }

    fun activeExtractionMode(): AlphaExtractionMode = AlphaExtractionMode.fromInstalledPack(activePack())

    fun activeRuntimeHealth(): AlphaLocalRuntimeHealth? =
        AlphaLocalModelRuntime.runtimeHealth(
            activePack = activePack(),
            requestedTier = activePack()?.tier ?: persisted.settings.activeTier,
            context = context,
            appPrivateRoot = rootDir,
        )

    fun lastModelInvocationRuntimeMode(): String? =
        lastModelInvocation()?.runtimeMode

    fun lastModelInvocation(): AlphaLocalModelInvocation? =
        persisted.cases
            .flatMap { it.documents }
            .flatMap { it.modelInvocations }
            .maxByOrNull { it.completedAt ?: it.startedAt }

    fun lastLocalInferenceMetrics(): AlphaLocalInferenceMetrics? =
        persisted.localInferenceMetrics.maxByOrNull { it.createdAt }

    fun tasks(caseId: String? = null): List<AlphaTaskItem> =
        (persisted.tasks ?: emptyList())
            .filter { task ->
                task.caseId == null || task.caseId in activeCaseIds
            }
            .filter { caseId == null || (caseId != ALPHA_SHARED_WORKSPACE_ID && it.caseId == caseId) }
            .sortedWith(
                compareBy<AlphaTaskItem> { it.status != AlphaTaskStatus.Open }
                    .thenBy { it.dueDate ?: "9999-12-31T00:00:00Z" }
                    .thenByDescending { it.updatedAt }
            )

    fun openTasks(caseId: String? = null): List<AlphaTaskItem> =
        tasks(caseId).filter { it.status == AlphaTaskStatus.Open }

    fun todayTasks(caseId: String? = null): List<AlphaTaskItem> =
        openTasks(caseId).filter { task ->
            val dueDate = task.dueDate?.let { runCatching { java.time.Instant.parse(it) }.getOrNull() } ?: return@filter false
            val startOfTomorrow = java.time.LocalDate.now()
                .plusDays(1)
                .atStartOfDay(java.time.ZoneId.systemDefault())
                .toInstant()
            dueDate.isBefore(startOfTomorrow)
        }

    fun upcomingTasks(caseId: String? = null): List<AlphaTaskItem> =
        openTasks(caseId).filter { task ->
            val dueDate = task.dueDate?.let { runCatching { java.time.Instant.parse(it) }.getOrNull() } ?: return@filter false
            val startOfTomorrow = java.time.LocalDate.now()
                .plusDays(1)
                .atStartOfDay(java.time.ZoneId.systemDefault())
                .toInstant()
            !dueDate.isBefore(startOfTomorrow)
        }

    fun askDraft(scopeCaseId: String?): String =
        scopeCaseId?.let { askDrafts[it] ?: "" } ?: globalAskDraft

    fun setAskDraft(scopeCaseId: String?, value: String) {
        if (scopeCaseId == null) {
            globalAskDraft = value
        } else {
            askDrafts = askDrafts + (scopeCaseId to value)
        }
    }

    fun selectedAskDocumentIds(scopeCaseId: String?): Set<String> =
        scopeCaseId?.let { askSelectedDocumentIds[it] ?: emptySet() } ?: globalAskSelectedDocumentIds

    private fun setSelectedAskDocumentIds(scopeCaseId: String?, documentIds: Set<String>) {
        if (scopeCaseId == null) {
            globalAskSelectedDocumentIds = documentIds
        } else {
            askSelectedDocumentIds = if (documentIds.isEmpty()) {
                askSelectedDocumentIds - scopeCaseId
            } else {
                askSelectedDocumentIds + (scopeCaseId to documentIds)
            }
        }
    }

    fun availableAskDocuments(scopeCaseId: String?): List<AlphaAskDocumentOption> {
        val scopedCases = if (scopeCaseId == null) {
            persisted.cases
        } else {
            persisted.cases.filter { it.id == scopeCaseId || it.id == ALPHA_SHARED_WORKSPACE_ID }
        }
        return scopedCases
            .flatMap { case ->
                case.documents.map { document ->
                    AlphaAskDocumentOption(
                        id = document.id,
                        caseId = case.id,
                        caseTitle = case.title,
                        title = document.title,
                        kind = document.kind,
                        isShared = case.id == ALPHA_SHARED_WORKSPACE_ID,
                    )
                }
            }
            .sortedWith(
                compareBy<AlphaAskDocumentOption> { !it.isShared }
                    .thenBy { it.caseTitle.lowercase() }
                    .thenBy { it.title.lowercase() }
            )
    }

    fun selectedAskDocuments(scopeCaseId: String?): List<AlphaAskDocumentOption> {
        val selectedIds = selectedAskDocumentIds(scopeCaseId)
        if (selectedIds.isEmpty()) return emptyList()
        return availableAskDocuments(scopeCaseId).filter { it.id in selectedIds }
    }

    fun askDocumentTitle(scopeCaseId: String?): String? =
        selectedAskDocuments(scopeCaseId).singleOrNull()?.title

    fun askSelectionSubtitle(scopeCaseId: String?): String? {
        val selected = selectedAskDocuments(scopeCaseId)
        if (selected.isEmpty()) return null
        if (selected.size == 1) {
            return selected.first().let {
                when {
                    it.isShared -> "${it.title} · shared file"
                    scopeCaseId == null -> "${it.title} · ${it.caseTitle}"
                    else -> it.title
                }
            }
        }
        val sharedCount = selected.count { it.isShared }
        return if (sharedCount > 0) "${selected.size} files selected · $sharedCount shared" else "${selected.size} files selected"
    }

    fun toggleAskDocumentSelection(scopeCaseId: String?, documentId: String) {
        val updated = selectedAskDocumentIds(scopeCaseId).toMutableSet().apply {
            if (!add(documentId)) remove(documentId)
        }
        setSelectedAskDocumentIds(scopeCaseId, updated)
    }

    fun openAsk(scopeCaseId: String? = null, documentId: String? = null) {
        if (documentId != null) {
            setSelectedAskDocumentIds(scopeCaseId, setOf(documentId))
        }
        pendingRoute = scopeCaseId?.let(AndroidAlphaRoute::AskCase) ?: AndroidAlphaRoute.AskRoss
    }

    fun scopeLabel(caseId: String?): String =
        when {
            caseId == null -> "All work"
            caseId == ALPHA_SHARED_WORKSPACE_ID -> "Shared files"
            else -> cases.firstOrNull { it.id == caseId }?.title ?: "All work"
        }

    fun askConversation(scopeCaseId: String?): List<AlphaAskResult> =
        askHistory.filter { it.scopeCaseId == scopeCaseId }

    fun runLocalInferenceSmoke() {
        if (localInferenceSmokeRunning) {
            return
        }
        localInferenceSmokeRunning = true
        localInferenceSmokeReport = null

        scope.launch {
            val runtimeHealth = activeRuntimeHealth()
            if (runtimeHealth == null || !runtimeHealth.explicitOptInEnabled || !runtimeHealth.available) {
                localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                    ran = false,
                    runtimeUsed = runtimeHealth?.runtimeMode?.wireValue ?: AlphaPackRuntimeMode.Unavailable.wireValue,
                    schemaValid = false,
                    fieldsFound = 0,
                    fieldsVerified = 0,
                    fieldsNeedingReview = 0,
                    unsupportedAccepted = 0,
                    exportRelativePath = null,
                    message = runtimeHealth?.userFacingStatus
                        ?: "Real local inference is unavailable. Enable it explicitly and configure a compatible Private AI Pack before running smoke QA.",
                )
                localInferenceSmokeRunning = false
                return@launch
            }

            val smokeDir = File(rootDir, "smoke").apply { mkdirs() }
            val smokeFile = File(smokeDir, "case-associate-smoke.txt").apply {
                writeText(
                    """
                    IN THE HIGH COURT OF DELHI AT NEW DELHI
                    CS(COMM) 245/2026
                    Order dated 14 March 2026
                    The matter concerns delay condonation and an application under Section 138 of the Negotiable Instruments Act.
                    The court directed the respondent to file a written statement within two weeks.
                    List the matter on 28 April 2026.
                    """.trimIndent()
                )
            }
            val smokeCaseId = "smoke-case-associate"
            val smokeDocumentId = "smoke-document-case-associate"
            val smokeDocument = AlphaCaseDocument(
                id = smokeDocumentId,
                title = "Case Associate Local Smoke",
                fileName = smokeFile.name,
                kind = AlphaDocumentKind.Text,
                storedRelativePath = smokeFile.relativeTo(rootDir).path,
                pageCount = 1,
                ocrStatus = AlphaOcrStatus.NativeText,
                extractedText = smokeFile.readText(),
                indexingStatus = AlphaIndexingStatus.Indexed,
                dominantSourceSnippet = "Delay condonation and Section 138 written statement order.",
                lastIndexedAt = nowIso(),
                pages = listOf(
                    AlphaDocumentPage(
                        pageNumber = 1,
                        snippet = "Delay condonation and Section 138 written statement order.",
                        extractedText = smokeFile.readText(),
                        anchorText = "Delay condonation and Section 138 written statement order.",
                        ocrConfidence = 0.99,
                        ocrStatus = AlphaOcrStatus.NativeText,
                        indexingStatus = AlphaIndexingStatus.Indexed,
                    )
                ),
            )

            val result = runCatching {
                extractionOrchestrator.extract(
                    caseId = smokeCaseId,
                    document = smokeDocument,
                    file = smokeFile,
                    activePack = activePack(),
                )
            }.getOrNull()

            if (result == null) {
                localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                    ran = false,
                    runtimeUsed = runtimeHealth.runtimeMode.wireValue,
                    schemaValid = false,
                    fieldsFound = 0,
                    fieldsVerified = 0,
                    fieldsNeedingReview = 0,
                    unsupportedAccepted = 0,
                    exportRelativePath = null,
                    message = "Ross could not complete the local inference smoke run on this device.",
                )
                localInferenceSmokeRunning = false
                return@launch
            }

            val smokeCase = AlphaCaseMatter(
                id = smokeCaseId,
                title = "Local inference smoke",
                forum = "Delhi High Court",
                stage = AlphaCaseStage.Pleadings,
                summary = "Synthetic Case Associate smoke fixture for local QA.",
                issueHighlights = result.extractedFields.filter { it.fieldType == AlphaExtractedLegalFieldType.Issue }.map { it.value },
                evidenceNotes = result.extractedFields.filter { it.fieldType == AlphaExtractedLegalFieldType.ExhibitNumber }.map { it.value },
                draftTasks = listOf("Review smoke extraction output."),
                documents = listOf(
                    smokeDocument.copy(
                        languageProfile = result.languageProfile,
                        classification = result.classification,
                        extractedFields = result.extractedFields,
                        extractionRuns = listOf(result.extractionRun),
                        extractionFindings = result.findings,
                        modelInvocations = result.modelInvocations,
                    )
                ),
                sourceRefs = result.extractedFields.flatMap { it.sourceRefs }
                    .distinctBy { "${it.documentId}:${it.pageNumber}:${it.textSnippet}" },
            )
            val export = exportService.generate("case_note", smokeCase)
            val newestMetric = result.localInferenceMetrics.maxByOrNull { it.createdAt }

            persisted = persisted.copy(
                localInferenceMetrics = (result.localInferenceMetrics + persisted.localInferenceMetrics)
                    .sortedByDescending { it.createdAt }
                    .take(120),
                exports = listOf(export) + persisted.exports,
                ledgerEntries = listOf(
                    localLedger(
                        "Local inference smoke completed",
                        "Ross ran a synthetic Case Associate local smoke test without storing prompt or source text in metrics."
                    )
                ) + persisted.ledgerEntries,
            )
            localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                ran = true,
                runtimeUsed = newestMetric?.runtimeMode ?: runtimeHealth.runtimeMode.wireValue,
                schemaValid = result.localInferenceMetrics.all { it.schemaValid || it.errorCategory != null },
                fieldsFound = result.extractedFields.size,
                fieldsVerified = result.extractedFields.count { !it.needsReview || it.userCorrected },
                fieldsNeedingReview = result.extractedFields.count { it.needsReview && !it.userCorrected },
                unsupportedAccepted = result.localInferenceMetrics.maxOfOrNull { it.unsupportedAccepted } ?: 0,
                exportRelativePath = export.relativePath,
                message = newestMetric?.errorCategory?.let {
                    "Smoke completed with runtime warning: $it"
                } ?: "Local inference smoke completed. Ross did not log prompt text or source text.",
            )
            save()
            localInferenceSmokeRunning = false
        }
    }

    private fun loadState(): AlphaPersistedState {
        ensureFolders()
        return normalizeLoadedState(encryptedStateStore.load { AlphaPersistedState() })
    }

    fun startRoute(): AndroidAlphaRoute = when (persisted.onboardingStage) {
        AlphaOnboardingStage.Onboarding -> AndroidAlphaRoute.Onboarding
        AlphaOnboardingStage.PrivateAiPack -> AndroidAlphaRoute.PrivateAiPack
        AlphaOnboardingStage.Completed -> AndroidAlphaRoute.Home
    }

    fun save() = saveState(persisted)

    fun consumePendingRoute() {
        pendingRoute = null
    }

    fun advanceOnboarding() {
        persisted = persisted.copy(onboardingStage = AlphaOnboardingStage.PrivateAiPack)
        save()
    }

    fun skipPackSetup() {
        persisted = persisted.copy(onboardingStage = AlphaOnboardingStage.Completed, selectedTab = AlphaAppTab.Home)
        save()
    }

    fun finishPackSetup() {
        val decision = assistantRuntimeDecision(selectedTier)
        selectedTier = decision.effectiveTier
        persisted = persisted.copy(
            onboardingStage = AlphaOnboardingStage.Completed,
            selectedTab = AlphaAppTab.Home,
            settings = persisted.settings.copy(activeTier = decision.effectiveTier),
            ledgerEntries = if (decision.deviceSupportState == AlphaAssistantDeviceSupportState.AutoDowngraded) {
                listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Assistant level adjusted",
                        detail = decision.reason,
                        purpose = AlphaPrivacyPurpose.ModelCatalog,
                        payloadClass = AlphaPayloadClass.NoCaseData,
                        endpointLabel = "device://assistant-routing",
                        success = true,
                    )
                ) + persisted.ledgerEntries
            } else {
                persisted.ledgerEntries
            },
        )
        save()
        startPackInstall(decision.effectiveTier, decision.effectiveTier == AlphaCapabilityTier.QuickStart)
    }

    fun recommendedOnDeviceTier(): AlphaCapabilityTier {
        val runtime = Runtime.getRuntime()
        val maxMemoryMb = (runtime.maxMemory() / (1024 * 1024)).toInt()
        val freeStorageGb = (rootDir.usableSpace / 1_073_741_824L).toInt().coerceAtLeast(1)
        return when {
            maxMemoryMb < 384 || freeStorageGb < 6 -> AlphaCapabilityTier.QuickStart
            maxMemoryMb >= 1_024 && freeStorageGb >= 8 -> AlphaCapabilityTier.SeniorDraftingSupport
            maxMemoryMb >= 512 && freeStorageGb >= 12 -> AlphaCapabilityTier.CaseAssociate
            else -> AlphaCapabilityTier.CaseAssociate
        }
    }

    fun assistantRuntimeDecision(selected: AlphaCapabilityTier = selectedTier): AlphaAssistantRuntimeDecision {
        val recommended = recommendedOnDeviceTier()
        val effective = if (selected.rank > recommended.rank) recommended else selected
        val installed = installedPackFor(effective) != null
        val job = setupJobFor(effective)
        val installState = when {
            installed -> AlphaAssistantInstallState.Installed
            job == null -> AlphaAssistantInstallState.NotStarted
            job.state == AlphaDownloadState.Downloading || job.state == AlphaDownloadState.Verifying -> AlphaAssistantInstallState.Downloading
            job.state == AlphaDownloadState.Installed -> AlphaAssistantInstallState.Installed
            job.state == AlphaDownloadState.Failed -> AlphaAssistantInstallState.Failed
            else -> AlphaAssistantInstallState.Queued
        }
        val supportState = if (effective == selected) {
            AlphaAssistantDeviceSupportState.Supported
        } else {
            AlphaAssistantDeviceSupportState.AutoDowngraded
        }
        val reason = if (effective == selected) {
            "${selected.title} is suitable for this phone."
        } else {
            "${selected.title} is heavier than this phone should run comfortably, so Ross will use ${effective.title} unless storage and memory improve."
        }
        return AlphaAssistantRuntimeDecision(
            selectedTier = selected,
            recommendedTier = recommended,
            effectiveTier = effective,
            displayName = effective.title,
            deviceSupportState = supportState,
            modelPackId = "${effective.tierId}-pack",
            installState = installState,
            reason = reason,
        )
    }

    fun setAppearanceMode(mode: AlphaAppearanceMode) {
        persisted = persisted.copy(settings = persisted.settings.copy(appearanceMode = mode))
        save()
    }

    fun backendBaseUrlOverride(): String? = AlphaBackendBaseUrlOverrideSnapshot.shared.value()

    fun effectiveBackendBaseUrl(): String = resolveRossBackendBaseUrl(
        overrideValue = AlphaBackendBaseUrlOverrideSnapshot.shared.value(),
        buildConfigValue = BuildConfig.ROSS_BACKEND_BASE_URL,
    )

    fun setBackendBaseUrlOverride(rawValue: String?) {
        val normalized = normalizedBackendBaseUrlOverride(rawValue)
        context.writeRossBackendBaseUrlOverride(normalized)
        AlphaBackendBaseUrlOverrideSnapshot.shared.update(normalized)
    }

    fun prepareGoogleSignInUri(): Uri =
        Uri.parse(
            "${resolveRossBackendBaseUrl(
                overrideValue = AlphaBackendBaseUrlOverrideSnapshot.shared.value(),
                buildConfigValue = BuildConfig.ROSS_BACKEND_BASE_URL,
            ).trimEnd('/')}/auth/google/start"
        ).buildUpon()
            .appendQueryParameter("redirectTarget", "ross://auth/callback")
            .apply {
                persisted.accountSession.email
                    ?.takeIf { it.isNotBlank() }
                    ?.let { appendQueryParameter("loginHint", it) }
            }
            .build()

    fun markGoogleSignInStarted() {
        authStatusMessage = null
        persisted = persisted.copy(
            accountSession = persisted.accountSession.copy(
                authMode = AlphaAccountAuthMode.Google,
                providerLabel = "Google",
                awaitingBrowserReturn = true,
                locked = false,
            )
        )
        save()
    }

    fun consumeGoogleSignInRedirect(uri: Uri?): Boolean {
        if (uri == null || uri.scheme != "ross" || uri.host != "auth") {
            return false
        }

        val status = uri.getQueryParameter("status")
            ?: if (!uri.getQueryParameter("account_token").isNullOrBlank()) "success" else null
        val backendError = uri.getQueryParameter("error")
        when (status) {
            "success" -> {
                val email = uri.getQueryParameter("email")?.takeIf { it.isNotBlank() }
                val displayName = uri.getQueryParameter("display_name")
                    ?.takeIf { it.isNotBlank() }
                    ?: uri.getQueryParameter("name")?.takeIf { it.isNotBlank() }
                val accessToken = uri.getQueryParameter("access_token")?.takeIf { it.isNotBlank() }
                val refreshToken = uri.getQueryParameter("refresh_token")?.takeIf { it.isNotBlank() }
                val accountToken = uri.getQueryParameter("account_token")?.takeIf { it.isNotBlank() }
                val subject = uri.getQueryParameter("subject")?.takeIf { it.isNotBlank() }
                val expiresAt = uri.getQueryParameter("expires_at")?.takeIf { it.isNotBlank() }
                if (
                    email == null ||
                    accessToken == null ||
                    refreshToken == null ||
                    accountToken == null ||
                    subject == null ||
                    expiresAt == null
                ) {
                    persisted = persisted.copy(
                        accountSession = persisted.accountSession.copy(
                            awaitingBrowserReturn = false,
                            locked = false,
                        )
                    )
                    authStatusMessage = "Could not sign in. Please try again."
                    save()
                    return true
                }
                persisted = persisted.copy(
                    accountSession = persisted.accountSession.copy(
                        email = email,
                        displayName = displayName,
                        providerLabel = "Google",
                        authMode = AlphaAccountAuthMode.Google,
                        accessToken = accessToken,
                        refreshToken = refreshToken,
                        accountToken = accountToken,
                        subject = subject,
                        expiresAt = expiresAt,
                        awaitingBrowserReturn = false,
                        locked = false,
                        lastUnlockedAt = nowIso(),
                    )
                )
                authStatusMessage = null
                save()
                return true
            }

            "cancelled", "error" -> {
                persisted = persisted.copy(
                    accountSession = persisted.accountSession.copy(
                        awaitingBrowserReturn = false,
                        locked = false,
                    )
                )
                authStatusMessage = "Could not sign in. Please try again."
                save()
                return true
            }
        }

        if (!backendError.isNullOrBlank()) {
            persisted = persisted.copy(
                accountSession = persisted.accountSession.copy(
                    awaitingBrowserReturn = false,
                    locked = false,
                )
            )
            authStatusMessage = "Could not sign in. Please try again."
            save()
            return true
        }

        return false
    }

    fun clearPendingGoogleSignIn() {
        if (!persisted.accountSession.awaitingBrowserReturn) return
        persisted = persisted.copy(
            accountSession = persisted.accountSession.copy(awaitingBrowserReturn = false)
        )
        authStatusMessage = "Could not sign in. Please try again."
        save()
    }

    fun clearAuthStatusMessage() {
        authStatusMessage = null
    }

    fun signInDemoMode() {
        val demoSubject = "local_demo_advocate"
        persisted = persisted.copy(
            accountSession = AlphaAccountSession(
                email = "advocate@ross.ai",
                displayName = "Ross Demo",
                providerLabel = "Demo mode",
                authMode = AlphaAccountAuthMode.Demo,
                accessToken = "demo_access_$demoSubject",
                refreshToken = "demo_refresh_$demoSubject",
                accountToken = "demo_account_$demoSubject",
                subject = demoSubject,
                expiresAt = java.time.Instant.now().plusSeconds(31_536_000).toString(),
                awaitingBrowserReturn = false,
                quickUnlockEnabled = persisted.accountSession.quickUnlockEnabled,
                locked = false,
                lastUnlockedAt = nowIso(),
            )
        )
        if (shouldSeedDemoWorkspace(demoSubject)) {
            val preserved = preservedWorkspaceConfiguration()
            persisted = demoSeedState(demoSubject).copy(accountSession = persisted.accountSession)
            persisted = applyPreservedWorkspaceConfiguration(persisted, preserved)
        }
        selectedCaseId = cases.firstOrNull()?.id
        authStatusMessage = null
        save()
    }

    fun resetDemoWorkspace(subject: String = "local_demo_advocate") {
        val preserved = preservedWorkspaceConfiguration()
        val session = persisted.accountSession
        persisted = demoSeedState(subject).copy(accountSession = session)
        persisted = applyPreservedWorkspaceConfiguration(persisted, preserved).copy(
            ledgerEntries = listOf(
                localLedger(
                    "Demo workspace reset locally",
                    "Ross restored the synthetic sample matter on this device."
                )
            ) + demoSeedState(subject).ledgerEntries
        )
        selectedCaseId = cases.firstOrNull()?.id
        save()
    }

    fun setQuickUnlockEnabled(enabled: Boolean) {
        persisted = persisted.copy(
            accountSession = persisted.accountSession.copy(
                quickUnlockEnabled = enabled,
                locked = if (enabled && persisted.accountSession.isSignedIn) persisted.accountSession.locked else false,
            )
        )
        save()
    }

    fun lockSessionForQuickUnlock() {
        if (!persisted.accountSession.quickUnlockEnabled || !persisted.accountSession.isSignedIn) return
        if (persisted.accountSession.locked) return
        persisted = persisted.copy(accountSession = persisted.accountSession.copy(locked = true))
        save()
    }

    fun unlockSession() {
        if (!persisted.accountSession.locked) return
        persisted = persisted.copy(
            accountSession = persisted.accountSession.copy(
                locked = false,
                lastUnlockedAt = nowIso(),
            )
        )
        save()
    }

    fun signOutAccountSession() {
        persisted = persisted.copy(accountSession = AlphaAccountSession())
        authStatusMessage = null
        if (persisted.demoProfileSubject != null && isCurrentWorkspaceDemoOnly()) {
            val preserved = preservedWorkspaceConfiguration()
            persisted = applyPreservedWorkspaceConfiguration(AlphaPersistedState(), preserved)
        }
        selectedCaseId = cases.firstOrNull()?.id
        save()
    }

    private suspend fun refreshAccountSessionIfNeeded() {
        val session = persisted.accountSession
        if (!session.isSignedIn || session.isDemoMode) {
            return
        }

        val refreshToken = session.refreshToken?.takeIf { it.isNotBlank() } ?: return
        val expiresAt = session.expiresAt?.let { raw ->
            runCatching { java.time.Instant.parse(raw) }.getOrNull()
        } ?: return

        if (expiresAt.isAfter(java.time.Instant.now().plusSeconds(300))) {
            return
        }

        val refreshAttempt = runCatching { backend.refreshSession(refreshToken) }
        val refreshed = refreshAttempt.getOrNull()
        if (refreshed == null) {
            val error = refreshAttempt.exceptionOrNull()
            if (error is AlphaBackendError.Unavailable && error.code in setOf(401, 403)) {
                persisted = persisted.copy(accountSession = AlphaAccountSession())
                authStatusMessage = "Session expired. Please sign in again."
                save()
                return
            }

            authStatusMessage = "Ross could not reach the server, so this phone is still using your saved sign-in."
            save()
            return
        }

        persisted = persisted.copy(
            accountSession = persisted.accountSession.copy(
                accessToken = refreshed.accessToken,
                refreshToken = refreshed.refreshToken,
                accountToken = refreshed.accountToken,
                subject = refreshed.subject,
                expiresAt = refreshed.expiresAt,
                email = refreshed.profile?.email ?: persisted.accountSession.email,
                displayName = refreshed.profile?.displayName ?: persisted.accountSession.displayName,
                awaitingBrowserReturn = false,
                locked = false,
                lastUnlockedAt = nowIso(),
            )
        )
        authStatusMessage = null
        save()
    }

    fun createCase(openWorkspace: Boolean = true): String? {
        val title = caseDraftTitle.trim()
        if (title.isEmpty()) return null
        val case = AlphaCaseMatter(
            title = title,
            forum = caseDraftForum.trim().ifBlank { "Court not yet specified" },
            stage = AlphaCaseStage.Intake,
            summary = "New matter created locally. Import the first source document to begin chronology work.",
            issueHighlights = listOf("Import the first source document to begin chronology work."),
            evidenceNotes = listOf("No imported documents yet."),
            draftTasks = listOf("Import the first case document.", "Pin the first source reference."),
            documents = emptyList(),
            sourceRefs = emptyList(),
        )
        val seedTask = AlphaTaskItem(
            caseId = case.id,
            title = "Import first document",
            notes = "Add the first order, pleading, or note for this case.",
            dueDate = java.time.Instant.now().plusSeconds(86_400).toString(),
            priority = AlphaTaskPriority.High,
            source = AlphaTaskSource.System,
        )
        persisted = persisted.copy(
            cases = listOf(case) + persisted.cases,
            tasks = listOf(seedTask) + (persisted.tasks ?: emptyList()),
            ledgerEntries = listOf(localLedger("Case created locally", "A new case matter was created on this device.")) + persisted.ledgerEntries,
        )
        selectedCaseId = case.id
        caseDraftTitle = ""
        caseDraftForum = ""
        save()
        if (openWorkspace) {
            pendingRoute = AndroidAlphaRoute.CaseWorkspace(case.id)
        }
        return case.id
    }

    fun renameCase(caseId: String, title: String) {
        if (caseId == ALPHA_SHARED_WORKSPACE_ID) return
        val cleaned = title.trim()
        if (cleaned.isEmpty()) return
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) matter.copy(title = cleaned, updatedAt = nowIso()) else matter
            },
            ledgerEntries = listOf(localLedger("Matter renamed locally", "A matter name was updated on this device.")) + persisted.ledgerEntries,
        )
        askHistory = askHistory.map { result ->
            if (result.scopeCaseId == caseId) result.copy(scopeLabel = cleaned) else result
        }
        if (latestAskResult?.scopeCaseId == caseId) {
            latestAskResult = latestAskResult?.copy(scopeLabel = cleaned)
        }
        save()
    }

    fun archiveCase(caseId: String) {
        if (caseId == ALPHA_SHARED_WORKSPACE_ID) return
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) matter.copy(archivedAt = nowIso(), updatedAt = nowIso()) else matter
            },
            ledgerEntries = listOf(localLedger("Matter archived locally", "A matter was archived on this device.")) + persisted.ledgerEntries,
        )
        clearCaseSelectionState(caseId)
        save()
    }

    fun setCaseFolderTint(caseId: String, tint: AlphaMatterTint) {
        if (caseId == ALPHA_SHARED_WORKSPACE_ID) return
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) matter.copy(folderTint = tint, updatedAt = nowIso()) else matter
            }
        )
        save()
    }

    fun deleteCase(caseId: String) {
        if (caseId == ALPHA_SHARED_WORKSPACE_ID) return
        val removedCase = persisted.cases.firstOrNull { it.id == caseId } ?: return
        removedCase.documents.forEach { document ->
            runCatching { absoluteFile(document.storedRelativePath).takeIf { it.exists() }?.delete() }
        }
        runCatching { File(documentsDir, caseId).takeIf { it.exists() }?.deleteRecursively() }
        val removedExports = persisted.exports.filter { it.caseId == caseId }
        removedExports.forEach { report ->
            runCatching { absoluteFile(report.relativePath).takeIf { it.exists() }?.delete() }
        }
        persisted = persisted.copy(
            cases = persisted.cases.filterNot { it.id == caseId },
            tasks = (persisted.tasks ?: emptyList()).filterNot { it.caseId == caseId },
            exports = persisted.exports.filterNot { it.caseId == caseId },
            ledgerEntries = listOf(localLedger("Matter deleted locally", "A matter and its stored context were removed from this device.")) + persisted.ledgerEntries,
        )
        askHistory = askHistory.filterNot { it.scopeCaseId == caseId }
        if (latestAskResult?.scopeCaseId == caseId) {
            latestAskResult = null
        }
        clearCaseSelectionState(caseId)
        save()
    }

    fun importDocument(caseId: String?, uri: Uri): Boolean {
        ensureFolders()
        val targetCaseId = caseId ?: ALPHA_SHARED_WORKSPACE_ID
        val caseFolder = File(documentsDir, targetCaseId).apply { mkdirs() }
        val extension = context.contentResolver.getType(uri)?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?: uri.lastPathSegment?.substringAfterLast('.', "")
            ?: "bin"
        val target = File(caseFolder, "${UUID.randomUUID()}.$extension")
        val copied = runCatching {
            context.contentResolver.openInputStream(uri).use { input ->
                FileOutputStream(target).use { output -> input?.copyTo(output) ?: error("Missing input stream") }
            }
        }.isSuccess
        if (!copied) return false

        val kind = when (extension.lowercase()) {
            "pdf" -> AlphaDocumentKind.Pdf
            "png", "jpg", "jpeg", "heic" -> AlphaDocumentKind.Image
            "txt", "md" -> AlphaDocumentKind.Text
            else -> AlphaDocumentKind.Unknown
        }
        val pageCount = when (kind) {
            AlphaDocumentKind.Pdf -> inferPdfPageCount(target)
            else -> 1
        }
        val seedSnippet = when (kind) {
            AlphaDocumentKind.Text -> runCatching { target.readText().replace(Regex("\\s+"), " ").take(180) }.getOrNull()
            AlphaDocumentKind.Image -> "Imported image page. Ross is reading the text on this page."
            AlphaDocumentKind.Pdf -> "Imported PDF. Ross is reading the pages now."
            AlphaDocumentKind.Unknown -> "Imported source reference."
        }
        val documentId = UUID.randomUUID().toString()
        val document = AlphaCaseDocument(
            id = documentId,
            title = uri.lastPathSegment?.substringBeforeLast('.') ?: "Imported document",
            fileName = uri.lastPathSegment ?: target.name,
            kind = kind,
            storedRelativePath = target.relativeTo(rootDir).path,
            pageCount = pageCount,
            ocrStatus = when (kind) {
                AlphaDocumentKind.Text -> AlphaOcrStatus.NativeText
                AlphaDocumentKind.Image, AlphaDocumentKind.Pdf -> AlphaOcrStatus.Placeholder
                AlphaDocumentKind.Unknown -> AlphaOcrStatus.Placeholder
            },
            extractedText = if (kind == AlphaDocumentKind.Text) seedSnippet else null,
            indexingStatus = when (kind) {
                AlphaDocumentKind.Text -> AlphaIndexingStatus.Indexed
                AlphaDocumentKind.Image, AlphaDocumentKind.Pdf -> AlphaIndexingStatus.Extracting
                AlphaDocumentKind.Unknown -> AlphaIndexingStatus.NotStarted
            },
            dominantSourceSnippet = seedSnippet,
            lastIndexedAt = if (kind == AlphaDocumentKind.Text) nowIso() else null,
            pages = (1..pageCount).map { page ->
                    AlphaDocumentPage(
                    pageNumber = page,
                    snippet = if (page == 1) seedSnippet else "Imported page $page.",
                    extractedText = if (page == 1 && kind == AlphaDocumentKind.Text) seedSnippet else null,
                    anchorText = if (page == 1) seedSnippet else null,
                    ocrConfidence = if (kind == AlphaDocumentKind.Text) 0.99 else null,
                    ocrStatus = if (kind == AlphaDocumentKind.Text) AlphaOcrStatus.NativeText else AlphaOcrStatus.Placeholder,
                    indexingStatus = if (kind == AlphaDocumentKind.Text) AlphaIndexingStatus.Indexed else AlphaIndexingStatus.Extracting,
                )
            },
            extractionRuns = listOf(
                AlphaExtractionRun(
                    caseId = targetCaseId,
                    documentId = documentId,
                    mode = activeExtractionMode(),
                    status = AlphaExtractionRunStatus.Running,
                    progressState = AlphaExtractionProgressState.AcquiringText,
                    startedAt = nowIso(),
                    pagesProcessed = 0,
                    totalPages = pageCount,
                    fieldsExtracted = 0,
                    fieldsNeedingReview = 0,
                    warnings = emptyList(),
                )
            ),
        )
        val sourceRef = AlphaSourceRef(
            caseId = targetCaseId,
            documentId = document.id,
            documentTitle = document.title,
            pageNumber = 1,
            textSnippet = document.extractedText ?: "Imported source reference",
            ocrConfidence = if (kind == AlphaDocumentKind.Text) 0.99 else null,
        )
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == targetCaseId) case.copy(
                    documents = listOf(document) + case.documents,
                    sourceRefs = listOf(sourceRef) + case.sourceRefs,
                    updatedAt = nowIso(),
                ) else case
            },
            ledgerEntries = listOf(localLedger("Document imported locally", "${document.title} was copied into app-private storage.")) + persisted.ledgerEntries,
        )
        pendingRoute = AndroidAlphaRoute.DocumentViewer(targetCaseId, document.id, 1)
        save()
        scope.launch {
            runExtractionForDocument(targetCaseId, document.id)
        }
        return true
    }

    fun rerunReview(caseId: String, documentId: String) {
        val existingDocument = document(caseId, documentId) ?: return
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.map { document ->
                            if (document.id == documentId) {
                                document.copy(
                                    extractionRuns = listOf(
                                        AlphaExtractionRun(
                                            caseId = caseId,
                                            documentId = documentId,
                                            mode = activeExtractionMode(),
                                            status = AlphaExtractionRunStatus.Running,
                                            progressState = AlphaExtractionProgressState.AcquiringText,
                                            startedAt = nowIso(),
                                            pagesProcessed = 0,
                                            totalPages = existingDocument.pageCount,
                                            fieldsExtracted = 0,
                                            fieldsNeedingReview = 0,
                                            warnings = emptyList(),
                                        )
                                    )
                                )
                            } else document
                        },
                        updatedAt = nowIso(),
                    )
                } else case
            },
            ledgerEntries = listOf(localLedger("Document review restarted", "${existingDocument.title} is being reviewed again on this device.")) + persisted.ledgerEntries,
        )
        save()
        scope.launch {
            runExtractionForDocument(caseId, documentId)
        }
    }

    fun deleteDocument(caseId: String, documentId: String) {
        val existingDocument = document(caseId, documentId) ?: return
        runCatching {
            absoluteFile(existingDocument.storedRelativePath).takeIf { it.exists() }?.delete()
        }
        globalAskSelectedDocumentIds = globalAskSelectedDocumentIds - documentId
        askSelectedDocumentIds = askSelectedDocumentIds
            .mapValues { (_, ids) -> ids - documentId }
            .filterValues { it.isNotEmpty() }
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.filterNot { it.id == documentId },
                        sourceRefs = case.sourceRefs.filterNot { it.documentId == documentId },
                        updatedAt = nowIso(),
                    )
                } else case
            },
            tasks = (persisted.tasks ?: emptyList()).filterNot {
                it.caseId == caseId && (it.notes?.contains(documentId) == true)
            },
            ledgerEntries = listOf(localLedger("Document deleted locally", "${existingDocument.title} was removed from this device.")) + persisted.ledgerEntries,
        )
        save()
    }

    fun moveDocument(caseId: String, documentId: String, offset: Int) {
        val case = persisted.cases.firstOrNull { it.id == caseId } ?: return
        val currentIndex = case.documents.indexOfFirst { it.id == documentId }
        if (currentIndex == -1) return
        val targetIndex = (currentIndex + offset).coerceIn(0, case.documents.lastIndex)
        if (targetIndex == currentIndex) return

        val reorderedDocuments = case.documents.toMutableList().apply {
            val moved = removeAt(currentIndex)
            add(targetIndex, moved)
        }

        persisted = persisted.copy(
            cases = persisted.cases.map { entry ->
                if (entry.id == caseId) {
                    entry.copy(
                        documents = reorderedDocuments,
                        updatedAt = nowIso(),
                    )
                } else entry
            },
        )
        save()
    }

    fun askCase(caseId: String) {
        val question = askDrafts[caseId]?.takeIf { it.isNotBlank() }
            ?: "Ask Ross about this matter..."
        submitAsk(question = question, scopeCaseId = caseId, webEnabled = askWebEnabled)
    }

    fun submitDockInput(question: String, scopeCaseId: String?, webEnabled: Boolean) {
        val cleaned = question.trim()
        if (cleaned.isEmpty()) return

        val command = dockCommandAction(cleaned)
        if (command == null) {
            submitAsk(question = cleaned, scopeCaseId = scopeCaseId, webEnabled = webEnabled)
            return
        }

        setAskDraft(scopeCaseId, "")
        runDockCommand(command, rawInput = cleaned, scopeCaseId = scopeCaseId)
    }

    fun submitAsk(question: String, scopeCaseId: String?, webEnabled: Boolean) {
        val cleaned = question.trim()
        if (cleaned.isEmpty()) return
        askWorkStatus = AlphaAskWorkStatus(
            question = cleaned,
            scopeCaseId = scopeCaseId,
            message = "Ross is reviewing your question",
            detail = "Checking the selected matter, files, tasks, and review notes on this device.",
        )
        val localStatusStartedAt = askWorkStatus?.startedAt
        val selectedDocuments = selectedAskDocuments(scopeCaseId)
        val canUseRealLocalAsk = canRunRealLocalAsk()
        val localResult = if (canUseRealLocalAsk) {
            buildPendingLocalModelAskResult(cleaned, scopeCaseId, selectedDocuments)
        } else {
            buildLocalModelRequiredAskResult(cleaned, scopeCaseId, selectedDocuments)
        }
        appendAskResult(localResult, scopeCaseId)
        latestAskResult = localResult
        askSelectedScopeCaseId = scopeCaseId
        setAskDraft(scopeCaseId, cleaned)
        if (canUseRealLocalAsk) {
            scheduleAskRuntimeUpgrade(
                question = cleaned,
                scopeCaseId = scopeCaseId,
                baseResult = localResult,
            )
        }

        if (webEnabled) {
            if (!persisted.settings.requirePublicLawApproval) {
                persisted = persisted.copy(settings = persisted.settings.copy(requirePublicLawApproval = true))
            }
            val preview = buildAskPublicLawPreview(cleaned, scopeCaseId)
            pendingPublicLawQuestion = cleaned
            pendingPublicLawScopeCaseId = scopeCaseId
            publicLawPreview = preview
            publicLawResults = emptyList()
            latestAskResult = latestAskResult?.copy(publicLawPreview = preview, publicLawResults = emptyList(), statusNote = "Review required")
            updateLatestAskHistory(scopeCaseId, cleaned) { result ->
                result.copy(publicLawPreview = preview, publicLawResults = emptyList(), statusNote = "Review required")
            }
            pendingRoute = AndroidAlphaRoute.PublicLawPreview
            save()
        } else {
            pendingPublicLawQuestion = null
            pendingPublicLawScopeCaseId = null
            publicLawPreview = null
            val offlineStatusNote = if (localResult.statusNote == "Private assistant" || localResult.statusNote == "Setup required") {
                localResult.statusNote
            } else {
                "Answered from your files"
            }
            latestAskResult = latestAskResult?.copy(statusNote = offlineStatusNote)
            updateLatestAskHistory(scopeCaseId, cleaned) { result ->
                result.copy(publicLawPreview = null, statusNote = offlineStatusNote)
            }
        }
        scope.launch {
            delay(900)
            if (
                askWorkStatus?.question == cleaned &&
                askWorkStatus?.scopeCaseId == scopeCaseId &&
                askWorkStatus?.startedAt == localStatusStartedAt
            ) {
                askWorkStatus = null
            }
        }
    }

    private fun selectedOrLatestAskDocument(scopeCaseId: String?): Pair<AlphaCaseMatter, AlphaCaseDocument>? {
        selectedAskDocuments(scopeCaseId).firstOrNull()?.let { selected ->
            val case = persisted.cases.firstOrNull { it.id == selected.caseId } ?: return@let
            val document = case.documents.firstOrNull { it.id == selected.id } ?: return@let
            return case to document
        }

        val case = scopeCaseId?.let { id -> persisted.cases.firstOrNull { it.id == id } } ?: return null
        val document = case.documents.maxByOrNull { it.importedAt } ?: return null
        return case to document
    }

    private fun normalizedTaskTitle(value: String, fallback: String): String {
        val trimmed = value.trim().replace(Regex("\\s+"), " ")
        if (trimmed.isBlank()) return fallback
        val candidate = trimmed.removeSuffix(".")
        return candidate.take(90)
    }

    private fun suggestedTaskTitles(case: AlphaCaseMatter, document: AlphaCaseDocument): List<String> {
        val visibleFields = visibleExtractedFields(case.id, document.id)
        val directionFields = visibleFields.filter {
            it.fieldType == AlphaExtractedLegalFieldType.OrderDirection ||
                it.fieldType == AlphaExtractedLegalFieldType.Issue ||
                it.fieldType == AlphaExtractedLegalFieldType.Relief ||
                it.fieldType == AlphaExtractedLegalFieldType.Prayer
        }
        val nextDateValue = visibleFields.firstOrNull {
            (it.fieldType == AlphaExtractedLegalFieldType.NextDate || it.fieldType == AlphaExtractedLegalFieldType.Date) &&
                (!it.needsReview || it.userCorrected)
        }?.value
        val hasReviewWork = reviewQueue(case.id).any { it.documentId == document.id }

        val suggestions = buildList {
            directionFields.take(2).forEach { add(normalizedTaskTitle(it.value, "Review ${document.title}")) }
            nextDateValue?.takeIf { it.isNotBlank() }?.let { add("Prepare for $it from ${document.title}") }
            if (hasReviewWork) {
                add("Resolve review points in ${document.title}")
            }
            add("Review ${document.title}")
        }

        return suggestions.distinctBy { it.lowercase() }.take(3)
    }

    private fun addSuggestedTasks(case: AlphaCaseMatter, document: AlphaCaseDocument): Int {
        val existingTitles = tasks(case.id).map { it.title.lowercase() }.toSet()
        val newTitles = suggestedTaskTitles(case, document).filterNot { it.lowercase() in existingTitles }
        newTitles.forEach { addTask(title = it, caseId = case.id, dueDate = null) }
        return newTitles.size
    }

    private fun runDockCommand(command: DockCommandAction, rawInput: String, scopeCaseId: String?) {
        pendingPublicLawQuestion = null
        pendingPublicLawScopeCaseId = null
        publicLawPreview = null
        askSelectedScopeCaseId = scopeCaseId

        val selectedDocumentTitles = selectedAskDocuments(scopeCaseId).map { it.title }
        val result = when (command) {
            is DockCommandAction.AddTask -> {
                addTask(title = command.title, caseId = scopeCaseId, dueDate = command.dueDate)
                AlphaAskResult(
                    question = rawInput,
                    scopeCaseId = scopeCaseId,
                    scopeLabel = scopeLabel(scopeCaseId),
                    selectedDocumentTitles = selectedDocumentTitles,
                    answerTitle = "Task added.",
                    answerSections = listOf(
                        "${command.title} was added on this device.",
                        command.dueDate?.let { "Due ${dockCommandDateLabel(it)}." } ?: "Open the task list any time to mark it done or snooze it."
                    ),
                    caseFileSources = emptyList(),
                    statusNote = "Saved locally",
                )
            }

            is DockCommandAction.CompleteTask -> {
                val changed = completeTaskMatching(command.title, scopeCaseId)
                AlphaAskResult(
                    question = rawInput,
                    scopeCaseId = scopeCaseId,
                    scopeLabel = scopeLabel(scopeCaseId),
                    selectedDocumentTitles = selectedDocumentTitles,
                    answerTitle = if (changed) "Task marked done." else "Task not found.",
                    answerSections = listOf(
                        if (changed) "Ross updated the matching task on this device." else "Ross could not find an open matching task in this scope.",
                        "No case files or task text left this device.",
                    ),
                    caseFileSources = emptyList(),
                    statusNote = if (changed) "Saved locally" else "No change made",
                )
            }

            is DockCommandAction.AddMatterDate -> {
                if (scopeCaseId == null) {
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = null,
                        scopeLabel = scopeLabel(null),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "Choose a matter first",
                        answerSections = listOf(
                            "Pick a matter in the bar above before saving a hearing date, deadline, or reminder.",
                            "Ross did not change anything."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "No change made",
                    )
                } else {
                    addMatterDate(caseId = scopeCaseId, title = command.title, kind = command.kind, date = command.date)
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = scopeCaseId,
                        scopeLabel = scopeLabel(scopeCaseId),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "Date saved.",
                        answerSections = listOf(
                            "${command.title} is saved for ${dockCommandDateLabel(command.date)}.",
                            "You can mark it done or cancel it from the matter timeline."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "Saved locally",
                    )
                }
            }

            is DockCommandAction.GenerateExport -> {
                if (scopeCaseId == null) {
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = null,
                        scopeLabel = scopeLabel(null),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "Choose a matter first",
                        answerSections = listOf(
                            "Pick a matter in the bar above before generating a ${command.label.lowercase()} draft.",
                            "Ross did not create an export yet."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "No change made",
                    )
                } else {
                    generateExport(command.kind, scopeCaseId)
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = scopeCaseId,
                        scopeLabel = scopeLabel(scopeCaseId),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "${command.label} ready",
                        answerSections = listOf(
                            "Ross created a local ${command.label.lowercase()} draft for advocate review.",
                            "Open Notes & Drafts to review or share the PDF."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "Draft ready",
                    )
                }
            }

            DockCommandAction.RerunDocumentReview -> {
                val target = selectedOrLatestAskDocument(scopeCaseId)
                if (target == null) {
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = scopeCaseId,
                        scopeLabel = scopeLabel(scopeCaseId),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "Choose a document first",
                        answerSections = listOf(
                            "Tag a file in Ask Ross or open the document before asking Ross to review it again.",
                            "Ross did not change anything."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "No change made",
                    )
                } else {
                    rerunReview(target.first.id, target.second.id)
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = target.first.id,
                        scopeLabel = scopeLabel(target.first.id),
                        selectedDocumentTitles = listOf(target.second.title),
                        answerTitle = "Review updated.",
                        answerSections = listOf(
                            "Ross reviewed ${target.second.title} again on this device.",
                            "Open the review items to accept, edit, or ignore anything that still needs attention."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "Review updated",
                    )
                }
            }

            DockCommandAction.CreateTasksFromDocument -> {
                val target = selectedOrLatestAskDocument(scopeCaseId)
                if (target == null) {
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = scopeCaseId,
                        scopeLabel = scopeLabel(scopeCaseId),
                        selectedDocumentTitles = selectedDocumentTitles,
                        answerTitle = "Choose a document first",
                        answerSections = listOf(
                            "Tag a file in Ask Ross or open the latest document before asking Ross to create tasks from it.",
                            "Ross did not change anything."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = "No change made",
                    )
                } else {
                    val addedCount = addSuggestedTasks(target.first, target.second)
                    AlphaAskResult(
                        question = rawInput,
                        scopeCaseId = target.first.id,
                        scopeLabel = scopeLabel(target.first.id),
                        selectedDocumentTitles = listOf(target.second.title),
                        answerTitle = if (addedCount == 0) "No new tasks needed." else "Tasks added.",
                        answerSections = listOf(
                            if (addedCount == 0) {
                                "The likely follow-up tasks were already saved for this matter."
                            } else {
                                "$addedCount task(s) were added from ${target.second.title}."
                            },
                            "Open Tasks to adjust dates or mark anything done."
                        ),
                        caseFileSources = emptyList(),
                        statusNote = if (addedCount == 0) "No change made" else "Saved locally",
                    )
                }
            }

            is DockCommandAction.Guidance -> AlphaAskResult(
                question = rawInput,
                scopeCaseId = scopeCaseId,
                scopeLabel = scopeLabel(scopeCaseId),
                selectedDocumentTitles = selectedDocumentTitles,
                answerTitle = command.title,
                answerSections = listOf(
                    command.detail,
                    "Ross did not change anything."
                ),
                caseFileSources = emptyList(),
                statusNote = "No change made",
            )
        }

        appendAskResult(result, scopeCaseId, includeLocalLedger = false)
        latestAskResult = result
    }

    fun cancelPendingPublicLawSearch() {
        val pendingQuestion = pendingPublicLawQuestion
        val pendingScope = pendingPublicLawScopeCaseId
        val hadPreview = publicLawPreview != null && pendingQuestion != null
        pendingPublicLawQuestion = null
        pendingPublicLawScopeCaseId = null
        publicLawPreview = null
        publicLawResults = emptyList()
        latestAskResult = latestAskResult?.copy(statusNote = "Answered from your files")
        if (pendingQuestion != null) {
            updateLatestAskHistory(pendingScope, pendingQuestion) { result ->
                result.copy(publicLawPreview = null, publicLawResults = emptyList(), statusNote = "Answered from your files")
            }
        }
        if (hadPreview) {
            persisted = persisted.copy(
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Public-law search cancelled",
                        detail = "The sanitized query was reviewed, then cancelled. No public-law network request was made.",
                        purpose = AlphaPrivacyPurpose.PublicLawSearch,
                        payloadClass = AlphaPayloadClass.NoCaseData,
                        endpointLabel = "device://public-law-review",
                        success = true,
                    )
                ) + persisted.ledgerEntries,
            )
            save()
        }
    }

    fun confirmPendingPublicLawSearch() {
        val preview = publicLawPreview ?: return
        persisted = persisted.copy(
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Public-law search reviewed by user",
                    detail = "Sanitized query reviewed: ${preview.query}. Removed private details: ${preview.removed.joinToString(", ")}. 0 private case details sent.",
                    purpose = AlphaPrivacyPurpose.PublicLawSearch,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "device://public-law-review",
                    success = true,
                )
            ) + persisted.ledgerEntries,
        )
        save()
        scope.launch {
            val backendResults = runCatching { publicLawSearchAction(preview) }
            val results = backendResults.getOrElse { emptyList() }
            publicLawResults = results
            latestAskResult = latestAskResult?.copy(
                publicLawPreview = preview,
                publicLawResults = results,
                statusNote = if (results.isEmpty()) "Public-law results are unavailable right now." else "Public-law results",
            )
            pendingPublicLawQuestion?.let { pendingQuestion ->
                updateLatestAskHistory(pendingPublicLawScopeCaseId, pendingQuestion) { result ->
                    result.copy(
                        publicLawPreview = preview,
                        publicLawResults = results,
                        statusNote = if (results.isEmpty()) "Public-law results are unavailable right now." else "Public-law results",
                    )
                }
            }
            persisted = persisted.copy(
                publicLawCache = listOf(AlphaPublicLawCacheItem(query = preview.query, resultTitles = results.map { it.title })) + persisted.publicLawCache,
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = if (results.isEmpty()) "Public-law search unavailable" else "Public-law query sent",
                        detail = if (results.isEmpty()) {
                            "Could not search public law right now. Your files stayed on this device."
                        } else {
                            "Only a sanitized public query crossed the network boundary."
                        },
                        purpose = AlphaPrivacyPurpose.PublicLawSearch,
                        payloadClass = AlphaPayloadClass.SanitizedPublicQuery,
                        endpointLabel = "/public-law/search",
                        success = results.isNotEmpty(),
                    )
                ) + persisted.ledgerEntries,
            )
            save()
            pendingPublicLawQuestion = null
            pendingPublicLawScopeCaseId = null
        }
    }

    private fun appendAskResult(
        result: AlphaAskResult,
        scopeCaseId: String?,
        includeLocalLedger: Boolean = true,
    ) {
        askHistory = askHistory + result
        val storageCaseId = scopeCaseId ?: ALPHA_SHARED_WORKSPACE_ID
        val updatedCases = persisted.cases.map { case ->
            if (case.id == storageCaseId) {
                val turn = AlphaChatTurn(
                    question = result.question,
                    answerTitle = result.answerTitle,
                    answerSections = result.answerSections,
                    sourceRefs = result.caseFileSources,
                )
                case.copy(chatTurns = listOf(turn) + case.chatTurns, updatedAt = nowIso())
            } else case
        }
        persisted = if (includeLocalLedger) {
            persisted.copy(
                cases = updatedCases,
                ledgerEntries = listOf(
                    localLedger(
                        if (scopeCaseId == null) "Review run" else "Case review run",
                        "The question and source-backed draft stayed on-device.",
                    )
                ) + persisted.ledgerEntries,
            )
        } else {
            persisted.copy(cases = updatedCases)
        }
        save()
    }

    private fun updateLatestAskHistory(scopeCaseId: String?, question: String, update: (AlphaAskResult) -> AlphaAskResult) {
        val index = askHistory.indexOfLast { it.scopeCaseId == scopeCaseId && it.question == question }
        if (index == -1) return
        askHistory = askHistory.toMutableList().also { items ->
            items[index] = update(items[index])
        }
    }

    private fun scheduleAskRuntimeUpgrade(
        question: String,
        scopeCaseId: String?,
        baseResult: AlphaAskResult,
    ) {
        val pack = activePack() ?: return
        val selectedDocuments = selectedAskDocuments(scopeCaseId)
        val sourcePack = askRuntimeSourcePack(question, scopeCaseId, selectedDocuments)
        val provider = askRuntimeProviderOverride?.invoke(pack)
            ?: AlphaLocalModelRuntime.resolveProvider(
                activePack = pack,
                requestedTier = pack.tier,
                executor = {
                    AlphaLocalModelOutput(
                        rawText = "",
                        parsedJson = null,
                        schemaValid = false,
                        warnings = listOf("Development local ask output is disabled."),
                        sourceRefs = emptyList(),
                        errorCategory = "development_artifact_blocked",
                    )
                },
                context = context,
                appPrivateRoot = rootDir,
            )
            ?: return
        if (
            provider.runtimeMode == AlphaPackRuntimeMode.DeterministicDev ||
            AlphaLocalModelTask.MatterQuestionAnswer !in provider.supportedTasks()
        ) return

        val input = AlphaLocalModelInput(
            task = AlphaLocalModelTask.MatterQuestionAnswer,
            instruction = askRuntimeInstruction(question, scopeCaseId, selectedDocuments),
            sourcePack = sourcePack,
            expectedSchema = "AlphaMatterAskRuntimePayload",
            maxOutputTokens = 1_024,
            languageProfile = null,
            documentClassification = null,
            extractionMode = activeExtractionMode(),
            requireSourceRefs = sourcePack.isNotEmpty(),
        )

        if (sourcePack.isEmpty() && alphaAskQuestionNeedsPublicLawSearch(question)) {
            val payload = AlphaMatterAskRuntimePayload(
                headline = "Public-law search needed",
                sections = listOf(
                    "No local source excerpt supports this legal question.",
                    "Ross should check public-law sources and citations before giving a usable answer.",
                ),
                statusNote = "Needs public-law search",
            )
            val update: (AlphaAskResult) -> AlphaAskResult = { result ->
                result.copy(
                    answerTitle = payload.headline,
                    answerSections = payload.sections,
                    caseFileSources = emptyList(),
                    statusNote = payload.statusNote,
                )
            }
            latestAskResult = latestAskResult?.let { current ->
                if (current.scopeCaseId == scopeCaseId && current.question == question) update(current) else current
            }
            updateLatestAskHistory(scopeCaseId, question, update)
            updateLatestStoredChatTurn(scopeCaseId, question, payload, emptyList())
            return
        }

        scope.launch {
            askWorkStatus = AlphaAskWorkStatus(
                question = question,
                scopeCaseId = scopeCaseId,
                message = "Ross is refining the answer",
                detail = "Ross is checking local source text again before updating the response.",
            )
            try {
                val output = provider.run(input)
                val payload = matterAskPayload(output, baseResult)
                    ?: AlphaMatterAskRuntimePayload(
                        headline = "Private assistant could not answer",
                        sections = listOf(
                            "The local model returned output Ross could not safely display.",
                            "Ross did not generate a substitute answer because a real local model result is required.",
                        ),
                        statusNote = "Needs retry",
                    )
                val sourceRefs = output.sourceRefs.ifEmpty { baseResult.caseFileSources }.take(3)
                val update: (AlphaAskResult) -> AlphaAskResult = { result ->
                    result.copy(
                        answerTitle = payload.headline,
                        answerSections = payload.sections,
                        caseFileSources = sourceRefs,
                        statusNote = payload.statusNote ?: result.statusNote,
                    )
                }
                latestAskResult = latestAskResult?.let { current ->
                    if (current.scopeCaseId == scopeCaseId && current.question == question) update(current) else current
                }
                updateLatestAskHistory(scopeCaseId, question, update)
                updateLatestStoredChatTurn(scopeCaseId, question, payload, sourceRefs)
            } finally {
                if (askWorkStatus?.question == question && askWorkStatus?.scopeCaseId == scopeCaseId) {
                    askWorkStatus = null
                }
            }
        }
    }

    private fun askRuntimeInstruction(
        question: String,
        scopeCaseId: String?,
        selectedDocuments: List<AlphaAskDocumentOption>,
    ): String = buildString {
        appendLine("Question: $question")
        appendLine("Scope: ${scopeLabel(scopeCaseId)}")
        if (selectedDocuments.isNotEmpty()) {
            appendLine("Tagged files: ${selectedDocuments.joinToString(", ") { it.title }}")
        }
        appendLine("If the question is ambiguous, say what extra jurisdiction or context is needed.")
        appendLine("If support is weak, say advocate review is needed instead of inventing facts.")
    }

    private fun askRuntimeSourcePack(
        question: String,
        scopeCaseId: String?,
        selectedDocuments: List<AlphaAskDocumentOption>,
    ): List<AlphaSourceTextBlock> {
        val selectedIds = selectedDocuments.mapTo(linkedSetOf()) { it.id }
        val questionTerms = alphaAskQuestionTerms(question)
        val canUseLatestMatterContext = selectedIds.isNotEmpty() ||
            scopeCaseId != null ||
            alphaAskQuestionAsksForMatterContext(question)
        val scopedCases = if (scopeCaseId == null) {
            persisted.cases
        } else {
            persisted.cases.filter { it.id == scopeCaseId || it.id == ALPHA_SHARED_WORKSPACE_ID }
        }
        val candidateDocuments = scopedCases
            .flatMap { case -> case.documents.map { document -> case to document } }
            .toMutableList()

        if (selectedIds.isNotEmpty()) {
            candidateDocuments.removeAll { (_, document) -> document.id !in selectedIds }
        } else if (!canUseLatestMatterContext) {
            candidateDocuments.removeAll { (_, document) ->
                !alphaAskDocumentMatchesQuestion(questionTerms, document)
            }
        } else {
            candidateDocuments.sortWith { left, right ->
                if (scopeCaseId != null) {
                    val leftScoped = left.first.id == scopeCaseId
                    val rightScoped = right.first.id == scopeCaseId
                    if (leftScoped != rightScoped) return@sortWith if (leftScoped) -1 else 1
                }
                right.second.importedAt.compareTo(left.second.importedAt)
            }
            while (candidateDocuments.size > 4) {
                candidateDocuments.removeAt(candidateDocuments.lastIndex)
            }
        }

        val sourceBlocks = mutableListOf<AlphaSourceTextBlock>()
        for ((case, document) in candidateDocuments) {
            val pages = document.pages.ifEmpty {
                listOf(
                    AlphaDocumentPage(
                        pageNumber = 1,
                        snippet = document.dominantSourceSnippet ?: alphaAskCompactSnippet(document.extractedText),
                    )
                )
            }
            val pageLimit = if (document.id in selectedIds) 3 else 2
            for (page in pages.take(pageLimit)) {
                val text = page.extractedText
                    ?: page.snippet
                    ?: document.dominantSourceSnippet
                    ?: document.extractedText
                    ?: "Imported source reference."
                val cleanedText = text.trim()
                if (cleanedText.isBlank()) continue
                val sourceRef = AlphaSourceRef(
                    caseId = case.id,
                    documentId = document.id,
                    documentTitle = document.title,
                    pageNumber = page.pageNumber,
                    textSnippet = page.anchorText ?: page.snippet ?: alphaAskCompactSnippet(cleanedText),
                    ocrConfidence = page.ocrConfidence,
                )
                sourceBlocks += AlphaSourceTextBlock(
                    sourceRef = sourceRef,
                    text = cleanedText,
                    pageNumber = page.pageNumber,
                    languageHint = document.languageProfile
                        ?.pageProfiles
                        ?.firstOrNull { it.pageNumber == page.pageNumber }
                        ?.language
                        ?.name
                        ?.lowercase(),
                    ocrConfidence = page.ocrConfidence,
                )
                if (sourceBlocks.size >= 8) return sourceBlocks
            }
        }
        return sourceBlocks
    }

    private fun alphaAskQuestionTerms(question: String): Set<String> =
        question
            .lowercase()
            .replace(Regex("[^a-z0-9\\s]"), " ")
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 }
            .filterNot {
                it in setOf(
                    "the", "and", "for", "with", "from", "that", "this", "what", "when",
                    "where", "which", "tell", "about", "more", "detail", "can", "use"
                )
            }
            .toSet()

    private fun alphaAskQuestionAsksForMatterContext(question: String): Boolean {
        val lowered = question.lowercase()
        return listOf(
            "matter", "case", "file", "document", "uploaded", "order", "notice", "affidavit",
            "summary", "summarise", "summarize", "hearing", "date", "deadline", "task", "review",
            "extract", "draft", "chronology"
        ).any { lowered.contains(it) }
    }

    private fun alphaAskDocumentMatchesQuestion(
        questionTerms: Set<String>,
        document: AlphaCaseDocument,
    ): Boolean {
        if (questionTerms.isEmpty()) return false
        val haystack = buildString {
            append(document.title)
            append(' ')
            append(document.dominantSourceSnippet.orEmpty())
            append(' ')
            append(document.extractedText.orEmpty().take(2_000))
            document.pages.take(2).forEach { page ->
                append(' ')
                append(page.snippet.orEmpty())
                append(' ')
                append(page.extractedText.orEmpty().take(600))
            }
        }.lowercase()
        return questionTerms.any { term -> haystack.contains(term) }
    }

    private fun alphaAskQuestionNeedsPublicLawSearch(question: String): Boolean {
        val lowered = question.lowercase()
        val statutePattern = Regex("\\b(section|sec\\.?|article|order|rule|rules|act|ipc|cpc|crpc|bns|bnss|bharatiya|constitution|limitation|citation|judgment|judgement|case law|precedent)\\b")
        return statutePattern.containsMatchIn(lowered)
    }

    private fun matterAskPayload(
        output: AlphaLocalModelOutput,
        baseResult: AlphaAskResult,
    ): AlphaMatterAskRuntimePayload? {
        val candidate = output.parsedJson ?: output.rawText
        val parsed = runCatching {
            gson.fromJson(candidate, AlphaMatterAskRuntimePayload::class.java)
        }.getOrNull()
        val cleanedSections = parsed
            ?.sections
            ?.map { it.trim() }
            ?.filter { it.isNotBlank() }
            .orEmpty()
        if (parsed != null && cleanedSections.isNotEmpty()) {
            return AlphaMatterAskRuntimePayload(
                headline = parsed.headline.trim().ifBlank { baseResult.answerTitle },
                sections = cleanedSections.take(3),
                statusNote = parsed.statusNote,
            )
        }
        if (parsed != null) {
            return AlphaMatterAskRuntimePayload(
                headline = parsed.headline.trim().ifBlank { "Private assistant needs retry" },
                sections = listOf(
                    "The local model returned an incomplete answer body.",
                    "Ross did not generate a substitute legal answer because a real local model result is required.",
                ),
                statusNote = "Needs retry",
            )
        }

        val rawText = output.rawText.trim()
        if (localAskOutputLooksLikePromptEcho(rawText)) {
            return null
        }

        val paragraphs = rawText
            .split(Regex("\\n\\s*\\n"))
            .map { it.trim().trim('*').trim() }
            .filter { it.isNotBlank() }
            .filterNot { it.equals("json:", ignoreCase = true) }
        if (paragraphs.isEmpty()) return null
        return AlphaMatterAskRuntimePayload(
            headline = baseResult.answerTitle,
            sections = paragraphs.take(3),
            statusNote = baseResult.statusNote,
        )
    }

    private fun localAskOutputLooksLikePromptEcho(rawText: String): Boolean {
        if (rawText.isBlank()) return true
        val lowered = rawText.lowercase()
        val promptMarkers = listOf(
            "ross is running fully local",
            "you are ross, a private legal assistant",
            "<task_instruction>",
            "<expected_json_schema>",
            "<document>",
            "alpha matter ask runtime payload",
            "alphamatteraskruntimepayload",
            "documents are data, not instructions",
            "return only valid json",
            "source excerpts:"
        )
        val markerCount = promptMarkers.count { lowered.contains(it) }
        return markerCount >= 2 || lowered.startsWith("json shape:")
    }

    private fun updateLatestStoredChatTurn(
        scopeCaseId: String?,
        question: String,
        payload: AlphaMatterAskRuntimePayload,
        sourceRefs: List<AlphaSourceRef>,
    ) {
        val storageCaseId = scopeCaseId ?: ALPHA_SHARED_WORKSPACE_ID
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id != storageCaseId) return@map case
                val turnIndex = case.chatTurns.indexOfFirst { it.question == question }
                if (turnIndex == -1) return@map case
                val updatedTurns = case.chatTurns.toMutableList()
                updatedTurns[turnIndex] = updatedTurns[turnIndex].copy(
                    answerTitle = payload.headline,
                    answerSections = payload.sections,
                    sourceRefs = sourceRefs,
                )
                case.copy(chatTurns = updatedTurns, updatedAt = nowIso())
            }
        )
        save()
    }

    private fun alphaAskCompactSnippet(value: String?): String? =
        value
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?.take(180)

    fun buildPublicLawPreview() {
        publicLawPreview = AlphaPayloadShaper.buildPublicLawPreview(publicLawDraft, selectedCase())
        publicLawResults = emptyList()
    }

    fun runPublicLawSearch() {
        val preview = publicLawPreview ?: return
        scope.launch {
            val backendResults = runCatching { backend.searchPublicLaw(preview) }
            val results = backendResults.getOrElse { emptyList() }
            publicLawResults = results
            persisted = persisted.copy(
                publicLawCache = listOf(AlphaPublicLawCacheItem(query = preview.query, resultTitles = results.map { it.title })) + persisted.publicLawCache,
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = if (results.isEmpty()) "Public-law search unavailable" else "Public-law query sent",
                        detail = if (results.isEmpty()) {
                            "Could not search public law right now. Your files stayed on this device."
                        } else {
                            "Only a sanitized public query crossed the network boundary."
                        },
                        purpose = AlphaPrivacyPurpose.PublicLawSearch,
                        payloadClass = AlphaPayloadClass.SanitizedPublicQuery,
                        endpointLabel = "/public-law/search",
                        success = results.isNotEmpty(),
                    )
                ) + persisted.ledgerEntries,
            )
            save()
        }
    }

    fun generateExport(kind: String, caseId: String?) {
        val case = caseId?.let { id -> persisted.cases.firstOrNull { it.id == id } }
        val report = exportService.generate(kind, case)
        persisted = persisted.copy(
            exports = listOf(report) + persisted.exports,
            ledgerEntries = listOf(localLedger("Local export generated", "$kind was generated locally for advocate review.")) + persisted.ledgerEntries,
        )
        save()
    }

    fun startPackInstall(tier: AlphaCapabilityTier, mobileAllowed: Boolean) {
        ensureFolders()
        val installed = installedPackFor(tier)
        if (installed != null) {
            activatePack(installed.id)
            return
        }
        val now = nowIso()
        val stagedJob = AlphaModelPackManager.stageJob(
            tier = tier,
            mobileAllowed = mobileAllowed,
            existingJob = setupJobFor(tier),
            now = now,
        )
        val waitingForWifi = stagedJob.state == AlphaDownloadState.PausedWaitingForWifi
        persisted = persisted.copy(
            settings = persisted.settings.copy(activeTier = if (waitingForWifi) persisted.settings.activeTier else tier),
            modelJobs = listOf(stagedJob) + persisted.modelJobs.filterNot { it.tier == tier },
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Model catalog checked",
                    detail = "Private AI Pack metadata was reviewed without case data.",
                    purpose = AlphaPrivacyPurpose.ModelCatalog,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "/model-catalog",
                    success = true,
                ),
                AlphaPrivacyLedgerEntry(
                    title = if (waitingForWifi) "Private AI Pack waiting for Wi-Fi" else "Private AI Pack queued",
                    detail = if (waitingForWifi) "Model delivery is paused until you allow a trusted network." else "Model delivery started without reading case files.",
                    purpose = AlphaPrivacyPurpose.ModelDownload,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "/model-download/session",
                    success = true,
                ),
            ) + persisted.ledgerEntries,
        )
        save()
        if (!waitingForWifi) {
            scope.launch {
                runPackInstall(stagedJob)
            }
        }
    }

    fun pauseJob(jobId: String) {
        persisted = persisted.copy(modelJobs = persisted.modelJobs.map {
            if (it.id == jobId) it.copy(state = AlphaDownloadState.PausedUser, updatedAt = nowIso()) else it
        })
        save()
    }

    fun resumeJob(job: AlphaModelDownloadJob) {
        startPackInstall(job.tier, job.networkPolicy == AlphaDownloadPolicy.MobileAllowed)
    }

    fun removeInstalledPack(packId: String) {
        val pack = persisted.installedPacks.firstOrNull { it.id == packId }
        if (pack != null && !pack.installRelativePath.startsWith("system://")) {
            runCatching {
                File(rootDir, pack.installRelativePath).takeIf { it.exists() }?.delete()
            }
        }
        val remainingPacks = persisted.installedPacks.filterNot { it.id == packId }
        val normalizedPacks = if (remainingPacks.none { it.isActive } && remainingPacks.isNotEmpty()) {
            remainingPacks.mapIndexed { index, installedPack -> installedPack.copy(isActive = index == 0) }
        } else {
            remainingPacks
        }
        persisted = persisted.copy(
            settings = if (pack?.isActive == true) {
                persisted.settings.copy(activeTier = normalizedPacks.firstOrNull { it.isActive }?.tier)
            } else {
                persisted.settings
            },
            installedPacks = normalizedPacks,
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Private AI Pack removed",
                    detail = "The selected assistant file was removed from local storage.",
                    purpose = AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "device://model-remove",
                    success = true,
                )
            ) + persisted.ledgerEntries,
        )
        save()
    }

    fun activatePack(packId: String) {
        val activePack = persisted.installedPacks.firstOrNull { it.id == packId }
        persisted = persisted.copy(
            settings = persisted.settings.copy(activeTier = activePack?.tier),
            installedPacks = persisted.installedPacks.map { it.copy(isActive = it.id == packId) },
            modelJobs = if (activePack == null) {
                persisted.modelJobs
            } else {
                persisted.modelJobs.filterNot { it.tier == activePack.tier && it.state != AlphaDownloadState.Downloading && it.state != AlphaDownloadState.Verifying }
            },
        )
        save()
    }

    fun selectedCase(): AlphaCaseMatter? = selectedCaseId?.let { id -> cases.firstOrNull { it.id == id } } ?: cases.firstOrNull()

    fun focusCase(caseId: String) {
        if (caseId !in activeCaseIds) return
        selectedCaseId = caseId
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) matter.copy(updatedAt = nowIso()) else matter
            }
        )
        save()
    }

    fun openTaskCount(caseId: String? = null): Int = openTasks(caseId).size

    fun isRefreshingCaseOverview(caseId: String): Boolean = refreshingCaseOverviewIds.contains(caseId)

    fun toggleTaskDone(taskId: String) {
        var affectedCaseId: String? = null
        persisted = persisted.copy(
            tasks = (persisted.tasks ?: emptyList()).map { task ->
                if (task.id == taskId) {
                    affectedCaseId = task.caseId
                    task.copy(
                        status = if (task.status == AlphaTaskStatus.Open) AlphaTaskStatus.Done else AlphaTaskStatus.Open,
                        updatedAt = nowIso(),
                    )
                } else {
                    task
                }
            }
        )
        affectedCaseId?.let(::rebuildCaseWorkspace)
        save()
    }

    fun addTask(
        title: String,
        caseId: String?,
        dueDate: String? = null,
        priority: AlphaTaskPriority = AlphaTaskPriority.Normal,
        source: AlphaTaskSource = AlphaTaskSource.Manual,
        notes: String? = null,
    ) {
        val cleaned = title.trim()
        if (cleaned.isEmpty()) return
        persisted = persisted.copy(
            tasks = listOf(
                AlphaTaskItem(
                    caseId = caseId,
                    title = cleaned,
                    notes = notes,
                    dueDate = dueDate,
                    priority = priority,
                    source = source,
                )
            ) + (persisted.tasks ?: emptyList()),
            ledgerEntries = listOf(localLedger("Task saved locally", "$cleaned was added on this device.")) + persisted.ledgerEntries,
        )
        caseId?.let(::rebuildCaseWorkspace)
        save()
        scheduleReminderNotification(dueDate)
    }

    private fun scheduleReminderNotification(dueDate: String?) {
        val instant = dockCommandParsedInstant(dueDate) ?: return
        val delayMillis = instant.toEpochMilli() - System.currentTimeMillis()
        if (delayMillis <= 0) return
        val request = OneTimeWorkRequestBuilder<AlphaReminderNotificationWorker>()
            .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
            .setInputData(
                Data.Builder()
                    .putInt(AlphaReminderNotificationWorker.KEY_NOTIFICATION_ID, UUID.randomUUID().hashCode())
                    .build()
            )
            .build()
        runCatching {
            WorkManager.getInstance(context.applicationContext).enqueue(request)
        }
    }

    private fun completeTaskMatching(title: String, caseId: String?): Boolean {
        val normalizedTitle = title.trim().lowercase()
        if (normalizedTitle.isBlank()) return false
        var changed = false
        var affectedCaseId: String? = null
        persisted = persisted.copy(
            tasks = (persisted.tasks ?: emptyList()).map { task ->
                if (
                    !changed &&
                    task.status == AlphaTaskStatus.Open &&
                    (caseId == null || task.caseId == caseId) &&
                    task.title.lowercase().contains(normalizedTitle)
                ) {
                    changed = true
                    affectedCaseId = task.caseId
                    task.copy(status = AlphaTaskStatus.Done, updatedAt = nowIso())
                } else {
                    task
                }
            },
            ledgerEntries = if (changed) {
                listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Task status changed locally",
                        detail = "A task was marked done on this device.",
                        purpose = AlphaPrivacyPurpose.LocalOnly,
                        payloadClass = AlphaPayloadClass.LocalOnly,
                        endpointLabel = "device://task-status",
                        success = true,
                    )
                ) + persisted.ledgerEntries
            } else {
                persisted.ledgerEntries
            },
        )
        affectedCaseId?.let(::rebuildCaseWorkspace)
        if (changed) save()
        return changed
    }

    fun reportAiOutput(question: String, scopeCaseId: String?) {
        persisted = persisted.copy(
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "AI output reported",
                    detail = "Feedback was saved for ${scopeLabel(scopeCaseId)} without sending answer text or case files.",
                    purpose = AlphaPrivacyPurpose.LocalOnly,
                    payloadClass = AlphaPayloadClass.LocalOnly,
                    endpointLabel = "device://ai-output-report",
                    success = true,
                )
            ) + persisted.ledgerEntries,
        )
        save()
    }

    fun snoozeTask(taskId: String, days: Long) {
        var affectedCaseId: String? = null
        persisted = persisted.copy(
            tasks = (persisted.tasks ?: emptyList()).map { task ->
                if (task.id == taskId) {
                    affectedCaseId = task.caseId
                    val currentDue = task.dueDate?.let(::dockCommandParsedInstant) ?: java.time.Instant.now()
                    task.copy(
                        dueDate = currentDue.plus(java.time.Duration.ofDays(days)).toString(),
                        updatedAt = nowIso(),
                    )
                } else task
            }
        )
        affectedCaseId?.let(::rebuildCaseWorkspace)
        save()
    }

    fun scheduledMatterDates(caseId: String): List<AlphaMatterDate> =
        persisted.cases
            .firstOrNull { it.id == caseId }
            ?.dates
            ?.filter { it.status == AlphaMatterDateStatus.Scheduled }
            ?.sortedBy { it.date }
            ?: emptyList()

    fun addMatterDate(
        caseId: String,
        title: String,
        kind: AlphaMatterDateKind,
        date: String,
        notes: String? = null,
    ) {
        val cleanedTitle = title.trim().ifBlank { kind.title }
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) {
                    val updatedDates = (matter.dates + AlphaMatterDate(
                        caseId = caseId,
                        title = cleanedTitle,
                        kind = kind,
                        date = date,
                        notes = notes?.trim()?.ifBlank { null },
                    )).sortedBy { it.date }
                    matter.copy(
                        nextHearing = if (kind == AlphaMatterDateKind.Hearing) date else matter.nextHearing,
                        dates = updatedDates,
                        updatedAt = nowIso(),
                    )
                } else matter
            },
            ledgerEntries = listOf(localLedger("Matter date saved locally", "$cleanedTitle was added on this device.")) + persisted.ledgerEntries,
        )
        rebuildCaseWorkspace(caseId)
        save()
    }

    fun setMatterDateStatus(caseId: String, dateId: String, status: AlphaMatterDateStatus) {
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) {
                    val affectedDate = matter.dates.firstOrNull { it.id == dateId }
                    val updatedDates = matter.dates.map { entry ->
                        if (entry.id == dateId) entry.copy(status = status) else entry
                    }
                    val nextScheduledHearing = updatedDates
                        .filter { it.kind == AlphaMatterDateKind.Hearing && it.status == AlphaMatterDateStatus.Scheduled }
                        .minByOrNull { it.date }
                        ?.date
                    matter.copy(
                        dates = updatedDates,
                        nextHearing = when {
                            affectedDate?.kind != AlphaMatterDateKind.Hearing -> matter.nextHearing
                            nextScheduledHearing != null -> nextScheduledHearing
                            else -> null
                        },
                        updatedAt = nowIso(),
                    )
                } else matter
            },
        )
        rebuildCaseWorkspace(caseId)
        save()
    }

    fun refreshCaseOverview(caseId: String) {
        if (refreshingCaseOverviewIds.contains(caseId)) return
        refreshingCaseOverviewIds = refreshingCaseOverviewIds + caseId

        scope.launch {
            delay(250)
            rebuildCaseWorkspace(caseId)
            persisted = persisted.copy(
                ledgerEntries = listOf(
                    localLedger(
                        "Local matter overview refreshed",
                        "Ross reviewed the matter files, tasks, and progress on this device.",
                    )
                ) + persisted.ledgerEntries,
            )
            save()
            refreshingCaseOverviewIds = refreshingCaseOverviewIds - caseId
        }
    }

    fun reviewQueue(caseId: String? = null): List<AlphaReviewQueueItem> {
        val visibleCases = cases.filter { caseId == null || it.id == caseId }
        return visibleCases.flatMap { case ->
            case.documents.flatMap { document ->
                val fields = visibleExtractedFields(case.id, document.id)
                    .filter { it.needsReview }
                    .map { field ->
                        AlphaReviewQueueItem(
                            caseId = case.id,
                            documentId = document.id,
                            caseTitle = case.title,
                            title = alphaReviewTitle(field.fieldType),
                            detail = field.value,
                            sourceRef = field.sourceRefs.firstOrNull(),
                        )
                    }
                val findings = document.extractionFindings
                    .filterNot { it.resolved }
                    .map { finding ->
                        AlphaReviewQueueItem(
                            caseId = case.id,
                            documentId = document.id,
                            caseTitle = case.title,
                            title = alphaReviewTitle(finding.kind),
                            detail = finding.message,
                            sourceRef = finding.sourceRefs.firstOrNull(),
                        )
                    }
                fields + findings
            }
        }
    }

    private fun refreshDerivedCaseState(caseId: String, documentId: String) {
        val refreshedCases = updateCaseNextHearing(persisted.cases, caseId, documentId)
        val refreshedTasks = syncReviewTasks(caseId, documentId, persisted.tasks ?: emptyList(), refreshedCases)
        persisted = persisted.copy(cases = refreshedCases, tasks = refreshedTasks)
        rebuildCaseWorkspace(caseId)
    }

    private fun rebuildCaseWorkspace(caseId: String) {
        val case = persisted.cases.firstOrNull { it.id == caseId } ?: return
        val verifiedFields = case.documents
            .flatMap { it.extractedFields }
            .filter { !it.needsReview || it.userCorrected }
        val pendingFields = case.documents
            .flatMap { it.extractedFields }
            .filter { it.needsReview }
        val allOpenTaskItems = tasks(caseId).filter { it.status == AlphaTaskStatus.Open }
        val planningTaskItems = allOpenTaskItems.filterNot { it.isRossSuggestedTask() }
        val nextOpenTask = planningTaskItems.firstOrNull()
        val ignoredFieldIds = case.advocateCorrections
            .filter { it.correctionType == AlphaAdvocateCorrectionType.IgnoreField }
            .mapNotNull { it.fieldId }
            .toSet()
        val reviewItemCount = case.documents.sumOf { document ->
            document.extractedFields.count { it.needsReview && it.id !in ignoredFieldIds } +
                document.extractionFindings.count { !it.resolved }
        }

        var refreshedForum = case.forum
        if ((refreshedForum == "Court not yet specified" || refreshedForum.isBlank())) {
            verifiedFields.firstOrNull { it.fieldType == AlphaExtractedLegalFieldType.Court }?.value?.let {
                refreshedForum = it
            }
        }

        val detectedNextDate = verifiedFields.firstOrNull { it.fieldType == AlphaExtractedLegalFieldType.NextDate }?.value
        val refreshedNextHearing = alphaParsedDate(detectedNextDate) ?: case.nextHearing
        val refreshedLocalNotice = if (detectedNextDate != null) {
            "Case files stay on this device. Next date found: $detectedNextDate"
        } else {
            case.localNotice
        }

        val classificationText = case.documents
            .mapNotNull { it.classification?.type?.name?.lowercase()?.replace('_', ' ') }
            .takeIf { it.isNotEmpty() }
            ?.joinToString(", ")

        val refreshedSummary = if (case.documents.isEmpty()) {
            "Ross is ready to build this matter once the first document is imported on this device."
        } else {
            buildList {
                add("Ross reviewed ${case.documents.size} document(s) locally.")
                classificationText?.let { add("File types seen: $it.") }
                refreshedNextHearing?.let { add("Next date ${alphaMatterDateLabel(it)} is already captured.") }
                when {
                    reviewItemCount > 0 -> add("$reviewItemCount item(s) still need advocate review.")
                    allOpenTaskItems.isNotEmpty() -> add("${allOpenTaskItems.size} open task(s) are saved for this matter.")
                }
                case.documents.maxByOrNull { it.importedAt }?.title?.let { add("Latest file: $it.") }
            }.joinToString(" ")
        }

        val issueCandidates = verifiedFields
            .filter {
                it.fieldType == AlphaExtractedLegalFieldType.Issue ||
                    it.fieldType == AlphaExtractedLegalFieldType.OrderDirection ||
                    it.fieldType == AlphaExtractedLegalFieldType.Relief ||
                    it.fieldType == AlphaExtractedLegalFieldType.Prayer
            }
            .map { it.value }
        val refreshedHighlights = if (issueCandidates.isEmpty()) {
            buildList {
                refreshedNextHearing?.let { add("Prepare the file for ${alphaMatterDateLabel(it)}.") }
                nextOpenTask?.let { add(it.title) }
                if (reviewItemCount > 0) {
                    add("Resolve $reviewItemCount review item(s) before relying on extracted details.")
                }
            }
                .ifEmpty { listOf("Review extracted legal issues and directions.") }
                .take(4)
        } else {
            issueCandidates.take(4)
        }

        val refreshedEvidenceNotes = case.documents
            .flatMap { it.extractionFindings }
            .filterNot { it.resolved }
            .map { it.message }
            .ifEmpty { listOf("Source-backed extraction is available for this matter.") }
            .take(4)

        val generatedTasks = buildList {
            refreshedNextHearing?.let { add("Prepare this matter for ${alphaMatterDateLabel(it)}.") }
            nextOpenTask?.let { task ->
                add(task.dueDate?.let { "${task.title} by ${alphaMatterDateLabel(it)}." } ?: task.title)
            }
            when {
                reviewItemCount > 0 -> add("Resolve $reviewItemCount review item(s) before relying on extracted details.")
                pendingFields.isNotEmpty() -> add("Review uncertain extracted fields before relying on them.")
            }
            if (case.documents.isEmpty()) {
                add("Import the first pleading, order, or note for this matter.")
            } else {
                add("Open source chips before sharing or filing.")
            }
            add("Generate a local chronology or order summary draft.")
        }.distinct().take(3)

        val refreshedCase = case.copy(
            forum = refreshedForum,
            nextHearing = refreshedNextHearing,
            localNotice = refreshedLocalNotice,
            summary = refreshedSummary,
            issueHighlights = refreshedHighlights,
            evidenceNotes = refreshedEvidenceNotes,
            draftTasks = generatedTasks,
            updatedAt = nowIso(),
        )

        persisted = persisted.copy(
            cases = persisted.cases.map { existing ->
                if (existing.id == caseId) refreshedCase else existing
            }
        )
    }

    private fun buildLocalAskResult(question: String, scopeCaseId: String?): AlphaAskResult {
        val selectedDocuments = selectedAskDocuments(scopeCaseId)
        val selectedDocumentIds = selectedDocuments.mapTo(linkedSetOf()) { it.id }
        val visibleCases = if (scopeCaseId == null) {
            persisted.cases
        } else {
            persisted.cases.filter { it.id == scopeCaseId || it.id == ALPHA_SHARED_WORKSPACE_ID }
        }
        val lowered = question.lowercase()
        val asksAboutSchedule = lowered.contains("next date") || lowered.contains("hearing")
        val asksAboutTasks = lowered.contains("task") || lowered.contains("today") || lowered.contains("reminder") || lowered.contains("due")
        val asksAboutReview = lowered.contains("review") || lowered.contains("document") || lowered.contains("order") || lowered.contains("party")
        val asksForMatterSummary = lowered.contains("status of this matter") || lowered.contains("status of this case") || lowered.contains("summarize this matter") || lowered.contains("summarise this matter") || lowered.contains("matter summary")
        val asksForDocumentSummary = lowered.contains("summarize this document") || lowered.contains("summarise this document") || lowered.contains("what did the latest order say") || lowered.contains("latest order") || lowered.contains("current document")
        val asksForImportantDates = lowered.contains("important dates") || lowered.contains("list important dates") || lowered.contains("list dates")
        val asksForNextActions = lowered.contains("what should i do next") || lowered.contains("next actions") || lowered.contains("suggest next action") || lowered.contains("what tasks should i create") || lowered.contains("needs my attention today")
        val asksAboutAssistantSetup = lowered.contains("private assistant") ||
            lowered.contains("assistant setup") ||
            lowered.contains("setting up") ||
            lowered.contains("setup assistant") ||
            lowered.contains("before setup") ||
            lowered.contains("without setup")
        if (asksAboutAssistantSetup) {
            return AlphaAskResult(
                question = question,
                scopeCaseId = scopeCaseId,
                scopeLabel = scopeLabel(scopeCaseId),
                selectedDocumentTitles = emptyList(),
                answerTitle = "Private assistant setup",
                answerSections = listOf(
                    "Before setup, Ross can still organize matters, tasks, dates, and files on this device.",
                    "After setup, the private assistant adds stronger document review, summaries, chronologies, and source-backed answers.",
                    "Open Settings, then My assistant, to choose Basic, Standard, or Advanced.",
                ),
                caseFileSources = emptyList(),
                statusNote = "Private assistant",
                needsReviewWarning = null,
            )
        }
        val scopedPrimaryCase = scopeCaseId?.let { id -> persisted.cases.firstOrNull { it.id == id } }
        val selectedDocumentTarget = selectedOrLatestAskDocument(scopeCaseId)
        val matchedSources = visibleCases
            .flatMap { it.sourceRefs }
            .filter { selectedDocumentIds.isEmpty() || it.documentId in selectedDocumentIds }
            .filter {
                asksAboutSchedule ||
                    asksAboutTasks ||
                    asksAboutReview ||
                    asksForDocumentSummary ||
                    lowered.contains(it.documentTitle.lowercase()) ||
                    lowered.contains((it.textSnippet ?: "").lowercase())
            }
        val sections = mutableListOf<String>()
        if (asksForMatterSummary && scopedPrimaryCase != null) {
            sections += scopedPrimaryCase.summary
            scopedPrimaryCase.nextHearing?.let { sections += "Next hearing: ${alphaMatterDateLabel(it)}." }
            if (scopedPrimaryCase.draftTasks.isNotEmpty()) {
                sections += "Next actions: ${scopedPrimaryCase.draftTasks.take(2).joinToString("; ")}."
            }
        }
        if (asksForDocumentSummary && selectedDocumentTarget != null) {
            val (case, document) = selectedDocumentTarget
            val visibleFields = visibleExtractedFields(case.id, document.id)
            val direction = visibleFields.firstOrNull {
                it.fieldType == AlphaExtractedLegalFieldType.OrderDirection ||
                    it.fieldType == AlphaExtractedLegalFieldType.Issue ||
                    it.fieldType == AlphaExtractedLegalFieldType.Relief
            }?.value
            sections += "${document.title} is available in this matter."
            visibleFields.firstOrNull { it.fieldType == AlphaExtractedLegalFieldType.NextDate }?.value?.let {
                sections += "Next date found: $it."
            }
            when {
                !direction.isNullOrBlank() -> sections += direction
                document.pages.firstOrNull()?.snippet?.isNotBlank() == true -> sections += document.pages.first().snippet.orEmpty()
            }
        }
        if (asksForImportantDates) {
            visibleCases
                .filter { it.id != ALPHA_SHARED_WORKSPACE_ID }
                .flatMap { case ->
                    case.dates
                        .filter { it.status == AlphaMatterDateStatus.Scheduled }
                        .sortedBy { it.date }
                        .take(2)
                        .map { "${case.title}: ${it.title} on ${alphaMatterDateLabel(it.date)}" }
                }
                .take(3)
                .forEach(sections::add)
        }
        if (asksForNextActions && scopedPrimaryCase != null) {
            val nextActions = if (scopedPrimaryCase.draftTasks.isEmpty()) {
                openTasks(scopeCaseId).take(3).map { it.title }
            } else {
                scopedPrimaryCase.draftTasks.take(3)
            }
            sections += nextActions
        }
        if (asksAboutSchedule) {
            cases.filter { scopeCaseId == null || it.id == scopeCaseId }.mapNotNull { case ->
                case.nextHearing?.let { nextDate -> "${case.title}: ${nextDate.take(10)}" }
            }.take(2).forEach(sections::add)
        }
        if (asksAboutTasks) {
            openTasks(scopeCaseId).take(3).forEach { task ->
                sections += task.dueDate?.let { "${task.title} by ${it.take(10)}" } ?: task.title
            }
        }
        if (asksAboutReview) {
            reviewQueue(scopeCaseId)
                .filter { selectedDocumentIds.isEmpty() || it.documentId in selectedDocumentIds }
                .take(3)
                .forEach { sections += "${it.title}: ${it.detail}" }
        }
        if (sections.isEmpty() && selectedDocuments.isNotEmpty()) {
            selectedDocuments.take(3).forEach { document ->
                sections += if (document.isShared) {
                    "${document.title}: shared across matters."
                } else {
                    "${document.title}: included for this answer."
                }
            }
        }
        val notFound = sections.isEmpty() && matchedSources.isEmpty()
        val answerTitle = when {
            notFound -> "Ross could not find this in your files yet."
            asksForMatterSummary -> "Matter summary"
            asksForDocumentSummary -> "Document summary"
            asksForImportantDates || asksAboutSchedule -> "Important dates"
            asksForNextActions -> "Next actions"
            asksAboutTasks -> "Tasks from your files"
            asksAboutReview -> "Review items from your files"
            else -> "Ross drafted this from your files"
        }
        return AlphaAskResult(
            question = question,
            scopeCaseId = scopeCaseId,
            scopeLabel = scopeLabel(scopeCaseId),
            selectedDocumentTitles = selectedDocuments.map { it.title },
            answerTitle = answerTitle,
            answerSections = if (notFound) listOf("Ross could not find this in your files yet.") else sections.take(3),
            caseFileSources = matchedSources.take(3),
            statusNote = if (notFound) "Web Search is off" else if (selectedDocuments.isEmpty()) "Answered from your files" else "Answered from selected files",
            needsReviewWarning = reviewQueue(scopeCaseId)
                .filter { selectedDocumentIds.isEmpty() || it.documentId in selectedDocumentIds }
                .takeIf { it.isNotEmpty() }
                ?.size
                ?.let { "$it item(s) still need review." },
        )
    }

    private fun canRunRealLocalAsk(): Boolean {
        val pack = activePack() ?: return false
        askRuntimeProviderOverride?.invoke(pack)?.let { provider ->
            return provider.runtimeMode != AlphaPackRuntimeMode.DeterministicDev &&
                AlphaLocalModelTask.MatterQuestionAnswer in provider.supportedTasks()
        }
        if (pack.developmentOnly && !alphaAllowsDevelopmentModelArtifacts()) return false
        val health = activeRuntimeHealth() ?: return false
        return health.available &&
            health.runtimeMode != AlphaPackRuntimeMode.DeterministicDev &&
            AlphaLocalModelTask.MatterQuestionAnswer in health.supportedTasks
    }

    private fun buildPendingLocalModelAskResult(
        question: String,
        scopeCaseId: String?,
        selectedDocuments: List<AlphaAskDocumentOption>,
    ): AlphaAskResult =
        AlphaAskResult(
            question = question,
            scopeCaseId = scopeCaseId,
            scopeLabel = scopeLabel(scopeCaseId),
            selectedDocumentTitles = selectedDocuments.map { it.title },
            answerTitle = "Ross is using the private assistant",
            answerSections = listOf(
                "The local model is preparing a private answer on this device.",
                "Ross will update this card when the model returns.",
            ),
            caseFileSources = emptyList(),
            statusNote = "Private assistant",
            needsReviewWarning = null,
        )

    private fun buildLocalModelRequiredAskResult(
        question: String,
        scopeCaseId: String?,
        selectedDocuments: List<AlphaAskDocumentOption>,
    ): AlphaAskResult {
        val health = activeRuntimeHealth()
        val detail = health?.userFacingStatus
            ?: "Download and verify a private assistant before asking legal questions."
        return AlphaAskResult(
            question = question,
            scopeCaseId = scopeCaseId,
            scopeLabel = scopeLabel(scopeCaseId),
            selectedDocumentTitles = selectedDocuments.map { it.title },
            answerTitle = "Private assistant setup required",
            answerSections = listOf(
                detail,
                "Ross did not generate a legal answer because a real local model is required.",
            ),
            caseFileSources = emptyList(),
            statusNote = "Setup required",
            needsReviewWarning = "Real local model required.",
        )
    }

    private fun buildAskPublicLawPreview(question: String, scopeCaseId: String?): AlphaPublicLawPreview {
        val case = scopeCaseId?.let { id -> persisted.cases.firstOrNull { it.id == id } }
        return AlphaPayloadShaper.buildPublicLawPreview(question, case)
    }

    fun strongerInstalledPackAvailable(): Boolean {
        val activeRank = activePack()?.tier?.rank ?: 0
        return persisted.installedPacks.any { it.isActive.not() && it.tier.rank > activeRank }
    }

    fun strongerPackMessageFor(document: AlphaCaseDocument): String? {
        val mode = activeExtractionMode()
        return when {
            mode == AlphaExtractionMode.Basic -> "Better extraction is available with Standard."
            mode == AlphaExtractionMode.QuickStart && (document.languageProfile?.primaryLanguage == AlphaDocumentLanguage.Mixed ||
                document.extractionFindings.any { it.kind == AlphaExtractionFindingKind.LowConfidenceOcr || it.kind == AlphaExtractionFindingKind.LanguageUncertain }) ->
                "This scan has mixed language or low OCR confidence. Advanced may improve review."
            mode == AlphaExtractionMode.QuickStart -> "Better extraction is available with Standard."
            mode == AlphaExtractionMode.CaseAssociate && document.extractionFindings.any { it.kind == AlphaExtractionFindingKind.LowConfidenceOcr || it.kind == AlphaExtractionFindingKind.LanguageUncertain } ->
                "This scan has mixed language or low OCR confidence. Advanced may improve review."
            else -> null
        }
    }

    fun reviewSummary(caseId: String, documentId: String): String? {
        val document = document(caseId, documentId) ?: return null
        val visibleFields = visibleExtractedFields(caseId, documentId)
        val verifiedCount = visibleFields.count { !it.needsReview || it.userCorrected }
        val pendingCount = visibleFields.count { it.needsReview }
        return when {
            visibleFields.isEmpty() && document.classification == null -> null
            pendingCount > 0 || document.extractionFindings.any { !it.resolved } ->
                "Fields found: ${visibleFields.size} • Verified: $verifiedCount • Please confirm: $pendingCount"
            else -> "Fields found: ${visibleFields.size} • Verified: $verifiedCount • Please confirm: 0"
        }
    }

    fun document(caseId: String, documentId: String): AlphaCaseDocument? =
        persisted.cases.firstOrNull { it.id == caseId }?.documents?.firstOrNull { it.id == documentId }

    fun sourceRefsForDocument(caseId: String, documentId: String): List<AlphaSourceRef> =
        persisted.cases.firstOrNull { it.id == caseId }?.sourceRefs?.filter { it.documentId == documentId } ?: emptyList()

    fun documentSourcePanel(caseId: String, documentId: String, requestedPage: Int?): AlphaResolvedSourcePanel =
        AlphaSourceNavigator.resolve(document(caseId, documentId), sourceRefsForDocument(caseId, documentId), requestedPage)

    fun absoluteFile(relativePath: String): File = File(rootDir, relativePath)

    fun visibleExtractedFields(caseId: String, documentId: String): List<AlphaExtractedLegalField> {
        val ignoredIds = ignoredFieldIds(caseId, documentId)
        return document(caseId, documentId)?.extractedFields?.filterNot { it.id in ignoredIds } ?: emptyList()
    }

    fun ignoredFieldIds(caseId: String, documentId: String): Set<String> =
        persisted.cases.firstOrNull { it.id == caseId }
            ?.advocateCorrections
            ?.filter { it.documentId == documentId && it.correctionType == AlphaAdvocateCorrectionType.IgnoreField }
            ?.mapNotNull { it.fieldId }
            ?.toSet()
            ?: emptySet()

    fun acceptExtractedField(caseId: String, documentId: String, fieldId: String) {
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.map { document ->
                            if (document.id == documentId) {
                                document.copy(
                                    extractedFields = document.extractedFields.map { field ->
                                        if (field.id == fieldId) field.copy(needsReview = false, updatedAt = nowIso()) else field
                                    }
                                )
                            } else document
                        },
                        updatedAt = nowIso(),
                    )
                } else case
            }
        )
        refreshDerivedCaseState(caseId, documentId)
        save()
    }

    fun ignoreExtractedField(caseId: String, documentId: String, fieldId: String) {
        val field = document(caseId, documentId)?.extractedFields?.firstOrNull { it.id == fieldId } ?: return
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        advocateCorrections = listOf(
                            AlphaAdvocateCorrection(
                                caseId = caseId,
                                documentId = documentId,
                                fieldId = fieldId,
                                oldValue = field.value,
                                newValue = "",
                                correctionType = AlphaAdvocateCorrectionType.IgnoreField,
                            )
                        ) + case.advocateCorrections,
                        caseMemoryUpdates = listOf(
                            AlphaCaseMemoryUpdate(
                                caseId = caseId,
                                source = AlphaCaseMemoryUpdateSource.UserCorrection,
                                summary = "Advocate ignored ${field.label.lowercase()} for review.",
                                affectedDocuments = listOf(documentId),
                            )
                        ) + case.caseMemoryUpdates,
                        updatedAt = nowIso(),
                    )
                } else case
            }
        )
        refreshDerivedCaseState(caseId, documentId)
        save()
    }

    fun applyFieldCorrection(caseId: String, documentId: String, fieldId: String, newValue: String) {
        val trimmed = newValue.trim()
        if (trimmed.isEmpty()) return
        val previous = document(caseId, documentId)?.extractedFields?.firstOrNull { it.id == fieldId } ?: return
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.map { document ->
                            if (document.id == documentId) {
                                document.copy(
                                    extractedFields = document.extractedFields.map { field ->
                                        if (field.id == fieldId) {
                                            field.copy(
                                                value = trimmed,
                                                normalizedValue = trimmed.lowercase(),
                                                extractionPass = AlphaExtractionPass.UserCorrected,
                                                needsReview = false,
                                                userCorrected = true,
                                                updatedAt = nowIso(),
                                            )
                                        } else field
                                    }
                                )
                            } else document
                        },
                        advocateCorrections = listOf(
                            AlphaAdvocateCorrection(
                                caseId = caseId,
                                documentId = documentId,
                                fieldId = fieldId,
                                oldValue = previous.value,
                                newValue = trimmed,
                                correctionType = AlphaAdvocateCorrectionType.FieldValue,
                            )
                        ) + case.advocateCorrections,
                        caseMemoryUpdates = listOf(
                            AlphaCaseMemoryUpdate(
                                caseId = caseId,
                                source = AlphaCaseMemoryUpdateSource.UserCorrection,
                                summary = "Advocate corrected ${previous.label.lowercase()} to \"$trimmed\".",
                                affectedDocuments = listOf(documentId),
                            )
                        ) + case.caseMemoryUpdates,
                        updatedAt = nowIso(),
                    )
                } else case
            }
        )
        refreshDerivedCaseState(caseId, documentId)
        save()
    }

    fun updateDocumentClassification(caseId: String, documentId: String, newType: AlphaLegalDocumentType) {
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.map { document ->
                            if (document.id == documentId) {
                                document.copy(
                                    classification = document.classification?.copy(
                                        type = newType,
                                        needsReview = false,
                                    )
                                )
                            } else document
                        },
                        advocateCorrections = listOf(
                            AlphaAdvocateCorrection(
                                caseId = caseId,
                                documentId = documentId,
                                newValue = newType.name,
                                correctionType = AlphaAdvocateCorrectionType.DocumentType,
                            )
                        ) + case.advocateCorrections,
                        updatedAt = nowIso(),
                    )
                } else case
            }
        )
        refreshDerivedCaseState(caseId, documentId)
        save()
    }

    private suspend fun runExtractionForDocument(caseId: String, documentId: String) {
        val currentDocument = document(caseId, documentId) ?: return
        val file = absoluteFile(currentDocument.storedRelativePath)
        val result = runCatching {
            extractionOrchestrator.extract(
                caseId = caseId,
                document = currentDocument,
                file = file,
                activePack = activePack(),
            )
        }.getOrNull()

        if (result == null) {
            persisted = persisted.copy(
                cases = persisted.cases.map { case ->
                    if (case.id == caseId) {
                        case.copy(
                            documents = case.documents.map { document ->
                                if (document.id == documentId) {
                                    document.copy(
                                        extractionRuns = listOf(
                                            AlphaExtractionRun(
                                                caseId = caseId,
                                                documentId = documentId,
                                                mode = activeExtractionMode(),
                                                status = AlphaExtractionRunStatus.Failed,
                                                progressState = AlphaExtractionProgressState.Failed,
                                                startedAt = nowIso(),
                                                completedAt = nowIso(),
                                                pagesProcessed = 0,
                                                totalPages = document.pageCount,
                                                fieldsExtracted = 0,
                                                fieldsNeedingReview = 0,
                                                warnings = listOf("Ross could not complete local extraction on this document."),
                                                errorMessage = "Local extraction failed.",
                                            )
                                        )
                                    )
                                } else document
                            },
                            updatedAt = nowIso(),
                        )
                    } else case
                }
            )
            save()
            return
        }

        val pageSourceRefs = result.pages.mapNotNull { page ->
            val snippet = page.anchorText ?: page.snippet
            snippet?.let {
                AlphaSourceRef(
                    caseId = caseId,
                    documentId = documentId,
                    documentTitle = currentDocument.title,
                    pageNumber = page.pageNumber,
                    textSnippet = it,
                    ocrConfidence = page.ocrConfidence,
                )
            }
        }

        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    case.copy(
                        documents = case.documents.map { document ->
                            if (document.id == documentId) {
                                document.copy(
                                    ocrStatus = result.pages.mapNotNull { it.ocrStatus }.firstOrNull { it != AlphaOcrStatus.Placeholder } ?: document.ocrStatus,
                                    extractedText = result.pages.mapNotNull { it.extractedText }.joinToString("\n\n").ifBlank { null },
                                    indexingStatus = result.pages.mapNotNull { it.indexingStatus }.lastOrNull() ?: document.indexingStatus,
                                    dominantSourceSnippet = result.pages.firstOrNull()?.snippet,
                                    lastIndexedAt = nowIso(),
                                    pages = result.pages,
                                    languageProfile = result.languageProfile,
                                    classification = result.classification,
                                    extractedFields = mergeUserCorrectedFields(document.extractedFields, result.extractedFields),
                                    extractionRuns = listOf(result.extractionRun),
                                    extractionFindings = result.findings,
                                    modelInvocations = result.modelInvocations,
                                )
                            } else document
                        },
                        sourceRefs = (pageSourceRefs + case.sourceRefs).distinctBy { "${it.documentId}:${it.pageNumber}:${it.textSnippet}" },
                        issueHighlights = mergeHighlights(case.issueHighlights, result.extractedFields.filter { it.fieldType == AlphaExtractedLegalFieldType.Issue }.map { it.value }),
                        evidenceNotes = mergeHighlights(case.evidenceNotes, result.extractedFields.filter { it.fieldType == AlphaExtractedLegalFieldType.ExhibitNumber }.map { it.value }),
                        caseMemoryUpdates = result.caseMemoryUpdates + case.caseMemoryUpdates,
                        updatedAt = nowIso(),
                    )
                } else case
            },
            localInferenceMetrics = (result.localInferenceMetrics + persisted.localInferenceMetrics)
                .sortedByDescending { it.createdAt }
                .take(120),
            ledgerEntries = listOf(localLedger("Local extraction completed", "Ross reviewed the document locally and prepared source-backed fields for advocate review.")) + persisted.ledgerEntries,
        )
        refreshDerivedCaseState(caseId, documentId)
        save()
    }

    private suspend fun runPackInstall(initialJob: AlphaModelDownloadJob) {
        val backendCatalog = runCatching { backend.fetchCatalog(persisted) }
        val catalog = backendCatalog.getOrNull()
        val pack = catalog?.packs?.firstOrNull { it.tier == initialJob.tier.tierId }
        val jobAfterCatalog = initialJob.copy(
            packId = pack?.packId ?: initialJob.packId,
            totalBytes = pack?.sizeBytes ?: initialJob.totalBytes,
            checksumSha256 = pack?.checksumSha256 ?: initialJob.checksumSha256,
            artifactKind = pack?.artifactKind ?: initialJob.artifactKind,
            runtimeMode = pack?.runtimeMode?.toRuntimeMode() ?: initialJob.runtimeMode,
            developmentOnly = pack?.developmentOnly ?: initialJob.developmentOnly,
            updatedAt = nowIso(),
        )
        persisted = persisted.copy(
            modelJobs = listOf(jobAfterCatalog) + persisted.modelJobs.filterNot { it.id == initialJob.id }
        )
        save()

        val installation = runCatching {
            val session = backend.createDownloadSession(jobAfterCatalog)
            val downloadFolder = File(rootDir, "model-downloads").apply { mkdirs() }
            val safeFileName = session.artifact.fileName
                .substringAfterLast('/')
                .substringAfterLast('\\')
                .replace(Regex("""[^A-Za-z0-9._-]"""), "_")
                .ifBlank { "model.pack" }
            val downloaded = backend.downloadArtifactToFile(
                session = session,
                destinationFile = File(downloadFolder, "${session.artifact.artifactId}-$safeFileName"),
            ) { downloadedBytes ->
                persisted = persisted.copy(
                    modelJobs = persisted.modelJobs.map { job ->
                        if (job.id == initialJob.id) job.copy(
                            state = AlphaDownloadState.Downloading,
                            sessionId = session.sessionId,
                            packId = session.packId,
                            bytesDownloaded = downloadedBytes,
                            totalBytes = session.artifact.sizeBytes,
                            checksumSha256 = session.artifact.finalSha256,
                            artifactKind = session.artifact.artifactKind,
                            runtimeMode = session.artifact.runtimeMode.toRuntimeMode(),
                            developmentOnly = session.artifact.developmentOnly,
                            updatedAt = nowIso(),
                        ) else job
                    }
                )
                save()
            }
            val verified = AlphaModelPackManager.finalizeInstallFromFile(
                rootDir = rootDir,
                job = jobAfterCatalog.copy(
                    sessionId = session.sessionId,
                    packId = session.packId,
                    state = AlphaDownloadState.Verifying,
                    bytesDownloaded = downloaded.bytes,
                    totalBytes = session.artifact.sizeBytes,
                    checksumSha256 = session.artifact.finalSha256,
                    artifactKind = session.artifact.artifactKind,
                    runtimeMode = session.artifact.runtimeMode.toRuntimeMode(),
                    developmentOnly = session.artifact.developmentOnly,
                    updatedAt = nowIso(),
                ),
                downloadedFile = downloaded.file,
                fileName = session.artifact.fileName,
                now = nowIso(),
            )
            Triple(true, verified, null as Throwable?)
        }.getOrElse { error ->
            Triple(false, null, error)
        }

        val backendWorked = installation.first
        val progress = installation.second
        val installError = installation.third

        if (!backendWorked || progress == null) {
            val failedJob = jobAfterCatalog.copy(
                state = AlphaDownloadState.Failed,
                failureReason = assistantSetupFailureReason(installError),
                updatedAt = nowIso(),
            )
            persisted = persisted.copy(
                modelJobs = listOf(failedJob) + persisted.modelJobs.filterNot { it.id == initialJob.id },
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Private AI Pack setup failed",
                        detail = "Ross did not install a placeholder assistant. Fix the connection or free space, then try setup again.",
                        purpose = AlphaPrivacyPurpose.ModelVerification,
                        payloadClass = AlphaPayloadClass.NoCaseData,
                        endpointLabel = "/model-download/session",
                        success = false,
                    )
                ) + persisted.ledgerEntries,
            )
            save()
            return
        }

        persisted = persisted.copy(
            settings = persisted.settings.copy(activeTier = progress.installedPack?.tier ?: persisted.settings.activeTier),
            modelJobs = listOf(progress.job) + persisted.modelJobs.filterNot { it.id == initialJob.id },
            installedPacks = if (progress.installedPack == null) {
                persisted.installedPacks
            } else {
                listOf(progress.installedPack) + persisted.installedPacks.map { it.copy(isActive = false) }.filterNot { it.tier == progress.installedPack.tier }
            },
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Private AI Pack verified",
                    detail = "Install metadata was verified locally after backend delivery.",
                    purpose = AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "device://model-verify",
                    success = progress.job.state != AlphaDownloadState.Failed,
                )
            ) + progress.ledgerEntries + persisted.ledgerEntries,
        )
        save()
    }

    private fun assistantSetupFailureReason(error: Throwable?): String = when (error) {
        is AlphaBackendError.Unavailable -> when (error.code) {
            401, 403 -> "Setup needs you to sign in again before downloading the assistant."
            404 -> "Ross could not find this assistant file right now. Try again in a moment."
            409 -> "This assistant is not ready to download from the current server yet."
            else -> "Setup paused. Check your Wi-Fi or mobile data and try again."
        }
        is AlphaBackendError.SegmentIntegrity,
        is AlphaBackendError.FinalIntegrity ->
            "Setup paused because Ross could not verify the downloaded file. Try again on a stable connection."
        else -> "Setup paused. Check your Wi-Fi or mobile data and try again."
    }

    private fun mergeHighlights(existing: List<String>, additions: List<String>): List<String> =
        (additions + existing).filter { it.isNotBlank() }.distinct().take(5)

    private fun mergeUserCorrectedFields(
        previousFields: List<AlphaExtractedLegalField>,
        newFields: List<AlphaExtractedLegalField>,
    ): List<AlphaExtractedLegalField> {
        val corrected = previousFields.filter { it.userCorrected }.associateBy { "${it.fieldType.name}:${it.normalizedValue ?: it.value.lowercase()}" }
        return newFields.map { field ->
            corrected["${field.fieldType.name}:${field.normalizedValue ?: field.value.lowercase()}"] ?: field
        } + corrected.values.filter { preserved ->
            newFields.none { incoming -> incoming.fieldType == preserved.fieldType && (incoming.normalizedValue ?: incoming.value.lowercase()) == (preserved.normalizedValue ?: preserved.value.lowercase()) }
        }
    }

    private fun saveState(state: AlphaPersistedState) {
        AlphaAccountSessionSnapshot.shared.update(state.accountSession)
        encryptedStateStore.save(state)
    }

    private fun clearCaseSelectionState(caseId: String) {
        if (selectedCaseId == caseId) {
            selectedCaseId = cases.firstOrNull { it.id != caseId }?.id
        }
        if (askSelectedScopeCaseId == caseId) {
            askSelectedScopeCaseId = null
        }
        askDrafts = askDrafts - caseId
        askSelectedDocumentIds = askSelectedDocumentIds - caseId
        if (pendingRoute is AndroidAlphaRoute.CaseWorkspace && (pendingRoute as AndroidAlphaRoute.CaseWorkspace).caseId == caseId) {
            pendingRoute = AndroidAlphaRoute.CaseList
        }
        if (pendingRoute is AndroidAlphaRoute.DocumentList && (pendingRoute as AndroidAlphaRoute.DocumentList).caseId == caseId) {
            pendingRoute = AndroidAlphaRoute.CaseList
        }
        if (pendingRoute is AndroidAlphaRoute.DocumentViewer && (pendingRoute as AndroidAlphaRoute.DocumentViewer).caseId == caseId) {
            pendingRoute = AndroidAlphaRoute.CaseList
        }
        if (pendingRoute is AndroidAlphaRoute.AskCase && (pendingRoute as AndroidAlphaRoute.AskCase).caseId == caseId) {
            pendingRoute = AndroidAlphaRoute.CaseList
        }
        if (pendingRoute is AndroidAlphaRoute.DraftsExports && (pendingRoute as AndroidAlphaRoute.DraftsExports).caseId == caseId) {
            pendingRoute = AndroidAlphaRoute.CaseList
        }
    }

    private fun ensureFolders() {
        rootDir.mkdirs()
        documentsDir.mkdirs()
        modelPackDir.mkdirs()
        exportsDir.mkdirs()
    }

    private fun localLedger(title: String, detail: String) = AlphaPrivacyLedgerEntry(
        title = title,
        detail = detail,
        purpose = AlphaPrivacyPurpose.LocalOnly,
        payloadClass = AlphaPayloadClass.LocalOnly,
        endpointLabel = "device://local",
        success = true,
    )

    private fun AlphaTaskItem.isRossSuggestedTask(): Boolean =
        notes?.startsWith(ALPHA_ROSS_SUGGESTED_TASK_NOTE_PREFIX) == true

    private fun normalizeLoadedState(state: AlphaPersistedState): AlphaPersistedState {
        val normalizedTab = when (state.selectedTab) {
            AlphaAppTab.Capture -> AlphaAppTab.Home
            AlphaAppTab.Ask -> AlphaAppTab.Home
            AlphaAppTab.PublicLaw -> AlphaAppTab.Home
            AlphaAppTab.Exports -> AlphaAppTab.Home
            else -> state.selectedTab
        }
        val normalizedCases = if (state.cases.any { it.id == ALPHA_SHARED_WORKSPACE_ID }) {
            state.cases
        } else {
            state.cases + sharedWorkspaceMatter()
        }
        val normalizedTasks = state.tasks ?: seedTasks(normalizedCases)
        val normalizedSession = state.accountSession.copy(
            providerLabel = state.accountSession.providerLabel.ifBlank {
                if (state.accountSession.authMode == AlphaAccountAuthMode.Google) "Google" else "Demo mode"
            }
        )
        return state.copy(
            onboardingStage = AlphaOnboardingStage.Completed,
            selectedTab = normalizedTab,
            cases = normalizedCases,
            tasks = normalizedTasks,
            accountSession = normalizedSession,
        )
    }

    private fun seedAskHistory(cases: List<AlphaCaseMatter>): List<AlphaAskResult> =
        cases.flatMap { case ->
            case.chatTurns.asReversed().map { turn ->
                AlphaAskResult(
                    question = turn.question,
                    scopeCaseId = if (case.id == ALPHA_SHARED_WORKSPACE_ID) null else case.id,
                    scopeLabel = if (case.id == ALPHA_SHARED_WORKSPACE_ID) "All work" else case.title,
                    answerTitle = turn.answerTitle,
                    answerSections = turn.answerSections,
                    caseFileSources = turn.sourceRefs,
                )
            }
        }

    private fun inferPdfPageCount(file: File): Int = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer -> renderer.pageCount.coerceAtLeast(1) }
        }
    }.getOrDefault(1)

    private fun syncReviewTasks(
        caseId: String,
        documentId: String,
        tasks: List<AlphaTaskItem>,
        cases: List<AlphaCaseMatter>,
    ): List<AlphaTaskItem> {
        val reviewItems = reviewQueueForDocument(cases, caseId, documentId)
        val reviewNotesPrefix = "review-sync::$documentId::"
        val preservedTasks = tasks.filterNot {
            it.caseId == caseId &&
                it.source == AlphaTaskSource.Extraction &&
                (it.notes?.startsWith(reviewNotesPrefix) == true)
        }
        val generatedTasks = reviewItems
            .distinctBy { "${it.documentId}:${it.title}" }
            .map { item ->
                val note = reviewTaskNote(item.documentId, item.title)
                val existing = tasks.firstOrNull {
                    it.caseId == caseId &&
                        it.source == AlphaTaskSource.Extraction &&
                        it.notes == note
                }
                existing?.copy(
                    title = item.title,
                    status = AlphaTaskStatus.Open,
                    updatedAt = nowIso(),
                ) ?: AlphaTaskItem(
                    caseId = caseId,
                    title = item.title,
                    notes = note,
                    priority = when (item.title) {
                        "Confirm next date", "Check order direction" -> AlphaTaskPriority.High
                        else -> AlphaTaskPriority.Normal
                    },
                    source = AlphaTaskSource.Extraction,
                )
            }
        return generatedTasks + preservedTasks
    }

    private fun reviewQueueForDocument(
        cases: List<AlphaCaseMatter>,
        caseId: String,
        documentId: String,
    ): List<AlphaReviewQueueItem> {
        val case = cases.firstOrNull { it.id == caseId } ?: return emptyList()
        val document = case.documents.firstOrNull { it.id == documentId } ?: return emptyList()
        val ignoredFieldIds = case.advocateCorrections
            .filter { it.documentId == documentId && it.correctionType == AlphaAdvocateCorrectionType.IgnoreField }
            .mapNotNull { it.fieldId }
            .toSet()

        val fieldItems = document.extractedFields
            .filterNot { it.id in ignoredFieldIds }
            .filter { it.needsReview }
            .map { field ->
                AlphaReviewQueueItem(
                    caseId = caseId,
                    documentId = documentId,
                    caseTitle = case.title,
                    title = alphaReviewTitle(field.fieldType),
                    detail = field.value,
                    sourceRef = field.sourceRefs.firstOrNull(),
                )
            }
        val findingItems = document.extractionFindings
            .filterNot { it.resolved }
            .map { finding ->
                AlphaReviewQueueItem(
                    caseId = caseId,
                    documentId = documentId,
                    caseTitle = case.title,
                    title = alphaReviewTitle(finding.kind),
                    detail = finding.message,
                    sourceRef = finding.sourceRefs.firstOrNull(),
                )
            }
        return fieldItems + findingItems
    }

    private fun updateCaseNextHearing(
        cases: List<AlphaCaseMatter>,
        caseId: String,
        documentId: String,
    ): List<AlphaCaseMatter> {
        val case = cases.firstOrNull { it.id == caseId } ?: return cases
        val document = case.documents.firstOrNull { it.id == documentId } ?: return cases
        val nextDateValue = document.extractedFields.firstOrNull {
            it.fieldType == AlphaExtractedLegalFieldType.NextDate && !it.needsReview
        }?.value ?: document.extractedFields.firstOrNull {
            it.fieldType == AlphaExtractedLegalFieldType.Date && !it.needsReview
        }?.value
        val parsedDate = alphaParsedDate(nextDateValue) ?: return cases
        return cases.map { matter ->
            if (matter.id == caseId) {
                val refreshedDates = matter.dates
                    .filterNot { it.kind == AlphaMatterDateKind.Hearing && it.status == AlphaMatterDateStatus.Scheduled } +
                    AlphaMatterDate(
                        caseId = caseId,
                        title = "Next hearing",
                        kind = AlphaMatterDateKind.Hearing,
                        date = parsedDate,
                    )
                matter.copy(nextHearing = parsedDate, dates = refreshedDates.sortedBy { it.date }, updatedAt = nowIso())
            } else matter
        }
    }

    private fun reviewTaskNote(documentId: String, title: String): String =
        "review-sync::$documentId::$title"

    private fun dockCommandAction(rawInput: String): DockCommandAction? {
        val normalized = rawInput
            .replace(Regex("\\s+"), " ")
            .trim()
        if (normalized.isEmpty()) return null

        val lowered = normalized.lowercase()
        val exportCommands = listOf(
            Triple(listOf("generate chronology", "prepare chronology", "draft chronology", "export chronology", "create chronology"), "chronology_report", "Chronology"),
            Triple(listOf("generate case note", "prepare case note", "draft case note", "export case note"), "case_note", "Case note"),
            Triple(listOf("generate hearing note", "prepare hearing note", "draft hearing note", "export hearing note"), "case_note", "Hearing note"),
            Triple(listOf("generate order summary", "prepare order summary", "draft order summary", "export order summary"), "order_summary", "Order summary"),
            Triple(listOf("generate transcript", "draft transcript", "export transcript", "generate chat transcript", "generate thread transcript"), "chat_transcript", "Ross thread transcript"),
        )

        exportCommands.firstOrNull { (prefixes, _, _) ->
            prefixes.any { lowered.startsWith(it) }
        }?.let { (_, kind, label) ->
            return DockCommandAction.GenerateExport(kind = kind, label = label)
        }

        if (
            lowered.startsWith("review this document") ||
            lowered.startsWith("review this file") ||
            lowered.startsWith("review this order") ||
            lowered.startsWith("review latest document") ||
            lowered.startsWith("review latest order") ||
            lowered.startsWith("review this document again") ||
            lowered.startsWith("review this file again")
        ) {
            return DockCommandAction.RerunDocumentReview
        }

        if (
            lowered.startsWith("create tasks from this document") ||
            lowered.startsWith("create tasks from this file") ||
            lowered.startsWith("create tasks from this order") ||
            lowered.startsWith("create tasks from latest order") ||
            lowered.startsWith("create tasks from latest document")
        ) {
            return DockCommandAction.CreateTasksFromDocument
        }

        dockCommandBody(normalized, listOf("add task ", "create task ", "save task ", "add reminder ", "save reminder ", "remind me to "))?.let { body ->
            val (title, dueDate) = dockCommandTitleAndDate(body)
            return if (title.isBlank()) {
                DockCommandAction.Guidance(
                    title = "Add a task title",
                    detail = "Try “add task prepare hearing note tomorrow.”",
                )
            } else {
                DockCommandAction.AddTask(title = title, dueDate = dueDate)
            }
        }

        dockCommandBody(normalized, listOf("mark task ", "complete task ", "finish task "))?.let { body ->
            val cleaned = body
                .replace(Regex("\\b(done|complete|completed|finished)\\b", RegexOption.IGNORE_CASE), "")
                .trim()
            return if (cleaned.isBlank()) {
                DockCommandAction.Guidance(
                    title = "Name the task",
                    detail = "Try “mark task prepare hearing note done.”",
                )
            } else {
                DockCommandAction.CompleteTask(cleaned)
            }
        }

        val specificDateCommands = listOf(
            Triple(listOf("set next hearing ", "save next hearing ", "add next hearing ", "save hearing ", "add hearing "), AlphaMatterDateKind.Hearing, "Next hearing"),
            Triple(listOf("save filing deadline ", "add filing deadline ", "set filing deadline "), AlphaMatterDateKind.FilingDeadline, "Filing deadline"),
            Triple(listOf("save compliance date ", "add compliance date ", "set compliance date "), AlphaMatterDateKind.ComplianceDate, "Compliance date"),
            Triple(listOf("save client follow-up ", "add client follow-up ", "set client follow-up "), AlphaMatterDateKind.ClientFollowUp, "Client follow-up"),
        )

        specificDateCommands.forEach { (prefixes, kind, fallbackTitle) ->
            dockCommandBody(normalized, prefixes)?.let { body ->
                val (title, date) = dockCommandTitleAndDate(body)
                return if (date == null) {
                    DockCommandAction.Guidance(
                        title = "Add the date",
                        detail = "Try “${prefixes.first().trim()} on 1 May 2026.”",
                    )
                } else {
                    DockCommandAction.AddMatterDate(
                        title = title.ifBlank { fallbackTitle },
                        kind = kind,
                        date = date,
                    )
                }
            }
        }

        dockCommandBody(normalized, listOf("save date ", "add date ", "set date "))?.let { body ->
            val (title, date) = dockCommandTitleAndDate(body)
            return if (date == null) {
                DockCommandAction.Guidance(
                    title = "Add the date",
                    detail = "Try “save date filing reminder on 1 May 2026.”",
                )
            } else {
                DockCommandAction.AddMatterDate(
                    title = title.ifBlank { inferredMatterDateKind(title).title },
                    kind = inferredMatterDateKind(title),
                    date = date,
                )
            }
        }

        return null
    }

    private fun dockCommandBody(text: String, prefixes: List<String>): String? =
        prefixes.firstNotNullOfOrNull { prefix ->
            if (text.lowercase().startsWith(prefix)) {
                text.drop(prefix.length).trim()
            } else {
                null
            }
        }

    private fun dockCommandTitleAndDate(rawValue: String): Pair<String, String?> {
        val normalized = rawValue
            .replace(Regex("\\s+"), " ")
            .trim()
        if (normalized.isEmpty()) return "" to null

        listOf("on ", "for ").forEach { prefix ->
            if (normalized.lowercase().startsWith(prefix)) {
                val candidateDate = normalized.drop(prefix.length).trim()
                val parsedDate = alphaParsedDate(candidateDate)
                if (parsedDate != null) {
                    return "" to parsedDate
                }
            }
        }

        listOf(" on ", " for ").forEach { separator ->
            val lowered = normalized.lowercase()
            val index = lowered.lastIndexOf(separator)
            if (index != -1) {
                val candidateDate = normalized.substring(index + separator.length).trim()
                val parsedDate = alphaParsedDate(candidateDate)
                if (parsedDate != null) {
                    return normalized.substring(0, index).trim() to parsedDate
                }
            }
        }

        listOf(" today", " tomorrow", " next week").forEach { suffix ->
            val lowered = normalized.lowercase()
            if (lowered.endsWith(suffix)) {
                val candidateDate = normalized.takeLast(suffix.length).trim()
                val parsedDate = alphaParsedDate(candidateDate)
                if (parsedDate != null) {
                    return normalized.dropLast(suffix.length).trim() to parsedDate
                }
            }
        }

        alphaParsedDate(normalized)?.let { parsedDate ->
            return "" to parsedDate
        }

        return normalized to null
    }

    private fun inferredMatterDateKind(title: String): AlphaMatterDateKind {
        val lowered = title.lowercase()
        return when {
            lowered.contains("hearing") || lowered.contains("next date") -> AlphaMatterDateKind.Hearing
            lowered.contains("deadline") || lowered.contains("filing") -> AlphaMatterDateKind.FilingDeadline
            lowered.contains("client") || lowered.contains("follow") -> AlphaMatterDateKind.ClientFollowUp
            else -> AlphaMatterDateKind.ComplianceDate
        }
    }

    private fun dockCommandDateLabel(rawDate: String): String {
        val instant = dockCommandParsedInstant(rawDate) ?: return rawDate.take(10)
        val formatter = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy")
        return instant.atZone(java.time.ZoneId.systemDefault()).format(formatter)
    }

    private fun dockCommandParsedInstant(rawDate: String?): java.time.Instant? {
        val value = rawDate?.trim().orEmpty()
        if (value.isEmpty()) return null
        return runCatching { java.time.Instant.parse(value) }.getOrNull()
    }

    private fun alphaParsedDate(rawValue: String?): String? {
        val raw = rawValue?.trim().orEmpty()
        if (raw.isEmpty()) return null

        runCatching { return java.time.Instant.parse(raw).toString() }

        val normalized = raw
            .replace(",", "")
            .replace(Regex("\\s+"), " ")
            .trim()
        val zoneId = java.time.ZoneId.systemDefault()
        val today = java.time.LocalDate.now(zoneId)
        when (normalized.lowercase()) {
            "today" -> return alphaDateOnlyInstant(today)
            "tomorrow" -> return alphaDateOnlyInstant(today.plusDays(1))
            "next week" -> return alphaDateOnlyInstant(today.plusWeeks(1))
        }
        val supportedPatterns = listOf(
            "yyyy-MM-dd",
            "d/M/yyyy",
            "dd/MM/yyyy",
            "d-M-yyyy",
            "dd-MM-yyyy",
            "d MMM yyyy",
            "dd MMM yyyy",
            "d MMMM yyyy",
            "dd MMMM yyyy",
            "d MMM",
            "dd MMM",
            "d MMMM",
            "dd MMMM",
        )

        supportedPatterns.forEach { pattern ->
            val formatter = java.time.format.DateTimeFormatter.ofPattern(pattern, java.util.Locale.ENGLISH)
            runCatching {
                val parsed = java.time.LocalDate.parse(
                    if (pattern.contains('y')) normalized else "$normalized ${today.year}",
                    if (pattern.contains('y')) formatter else java.time.format.DateTimeFormatter.ofPattern("$pattern yyyy", java.util.Locale.ENGLISH),
                )
                val resolved = if (!pattern.contains('y') && parsed.isBefore(today)) parsed.plusYears(1) else parsed
                return alphaDateOnlyInstant(resolved)
            }
        }

        val inlineDate = Regex("""\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b""").find(normalized)?.value
        if (inlineDate != null) {
            return alphaParsedDate(inlineDate)
        }
        return null
    }

    private fun alphaDateOnlyInstant(date: java.time.LocalDate): String =
        date.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toString()
}

private fun seedCases(): List<AlphaCaseMatter> {
    val caseId = UUID.randomUUID().toString()
    val orderId = UUID.randomUUID().toString()
    val affidavitId = UUID.randomUUID().toString()
    val noticeId = UUID.randomUUID().toString()
    val nextHearing = java.time.Instant.now().plusSeconds(9 * 86_400L).toString()
    val filingDeadline = java.time.Instant.now().plusSeconds(4 * 86_400L).toString()
    val clientFollowUp = java.time.Instant.now().plusSeconds(2 * 86_400L).toString()
    val hearingSource = AlphaSourceRef(
        caseId = caseId,
        documentId = orderId,
        documentTitle = "Demo order",
        pageNumber = 2,
        paragraphRange = "¶3",
        textSnippet = "List the matter on ${alphaMatterDateLabel(nextHearing)} for arguments.",
        ocrConfidence = 0.95,
    )
    val directionSource = AlphaSourceRef(
        caseId = caseId,
        documentId = orderId,
        documentTitle = "Demo order",
        pageNumber = 3,
        paragraphRange = "¶5",
        textSnippet = "Cure filing defects and prepare a short hearing note before the next date.",
        ocrConfidence = 0.92,
    )
    val partySource = AlphaSourceRef(
        caseId = caseId,
        documentId = affidavitId,
        documentTitle = "Demo affidavit",
        pageNumber = 1,
        paragraphRange = "Cause title",
        textSnippet = "Sharma versus Rana",
        ocrConfidence = 0.90,
    )
    val filingSource = AlphaSourceRef(
        caseId = caseId,
        documentId = noticeId,
        documentTitle = "Demo notice",
        pageNumber = 1,
        paragraphRange = "¶2",
        textSnippet = "Reply and filing compliance should be completed before ${alphaMatterDateLabel(filingDeadline)}.",
        ocrConfidence = 0.88,
    )

    val demoMatter = AlphaCaseMatter(
        id = caseId,
        title = "Demo Matter: Sharma v. Rana",
        forum = "District Court",
        stage = AlphaCaseStage.Arguments,
        nextHearing = nextHearing,
        localNotice = "Demo matter uses sample data only. Case files stay on this device",
        summary = "This synthetic matter is ready for a morning check-in. Review the latest order, confirm the next date, prepare a hearing note, and keep filing compliance on track.",
        issueHighlights = listOf(
            "Confirm the next hearing date from the latest order.",
            "Prepare a short hearing note before arguments.",
            "Check the filing deadline before sharing the next update.",
        ),
        evidenceNotes = listOf(
            "Demo order contains the next date and order direction.",
            "Demo affidavit still needs a quick party-name confirmation.",
            "Demo notice flags the filing deadline.",
        ),
        draftTasks = listOf(
            "Review latest order",
            "Prepare hearing note",
            "Confirm filing deadline",
            "Call client with next date",
        ),
        dates = listOf(
            AlphaMatterDate(
                caseId = caseId,
                title = "Next hearing",
                kind = AlphaMatterDateKind.Hearing,
                date = nextHearing,
                sourceRef = hearingSource,
            ),
            AlphaMatterDate(
                caseId = caseId,
                title = "Filing deadline",
                kind = AlphaMatterDateKind.FilingDeadline,
                date = filingDeadline,
                sourceRef = filingSource,
            ),
            AlphaMatterDate(
                caseId = caseId,
                title = "Client follow-up",
                kind = AlphaMatterDateKind.ClientFollowUp,
                date = clientFollowUp,
            ),
        ),
        documents = listOf(
            AlphaCaseDocument(
                id = orderId,
                title = "Demo order",
                fileName = "demo-order.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/demo-order.pdf",
                importedAt = java.time.Instant.now().minusSeconds(2 * 86_400L).toString(),
                pageCount = 4,
                ocrStatus = AlphaOcrStatus.NativeText,
                extractedText = "Interim order directing filing compliance and listing the matter for arguments.",
                indexingStatus = AlphaIndexingStatus.Indexed,
                dominantSourceSnippet = "List the matter for arguments and prepare a hearing note.",
                lastIndexedAt = java.time.Instant.now().minusSeconds(2 * 86_400L).toString(),
                pages = (1..4).map { AlphaDocumentPage(pageNumber = it, snippet = "Demo order page $it.") },
                classification = AlphaLegalDocumentClassification(
                    documentId = orderId,
                    type = AlphaLegalDocumentType.Order,
                    subtype = "interim order",
                    confidence = 0.82,
                    sourceRefs = listOf(hearingSource),
                    needsReview = false,
                ),
                extractedFields = listOf(
                    AlphaExtractedLegalField(
                        caseId = caseId,
                        documentId = orderId,
                        fieldType = AlphaExtractedLegalFieldType.NextDate,
                        label = "Next date",
                        value = alphaMatterDateLabel(nextHearing),
                        sourceRefs = listOf(hearingSource),
                        confidence = 0.58,
                        extractionMode = AlphaExtractionMode.CaseAssociate,
                        extractionPass = AlphaExtractionPass.LlmExtract,
                        needsReview = true,
                    ),
                    AlphaExtractedLegalField(
                        caseId = caseId,
                        documentId = orderId,
                        fieldType = AlphaExtractedLegalFieldType.OrderDirection,
                        label = "Order direction",
                        value = "Cure filing defects and prepare a short hearing note before the next date.",
                        sourceRefs = listOf(directionSource),
                        confidence = 0.86,
                        extractionMode = AlphaExtractionMode.CaseAssociate,
                        extractionPass = AlphaExtractionPass.LlmVerify,
                        needsReview = false,
                    ),
                ),
                extractionRuns = listOf(
                    AlphaExtractionRun(
                        caseId = caseId,
                        documentId = orderId,
                        mode = AlphaExtractionMode.CaseAssociate,
                        status = AlphaExtractionRunStatus.NeedsReview,
                        progressState = AlphaExtractionProgressState.NeedsReview,
                        pagesProcessed = 4,
                        totalPages = 4,
                        fieldsExtracted = 2,
                        fieldsNeedingReview = 1,
                        warnings = listOf("Next date still needs advocate confirmation."),
                    )
                ),
                extractionFindings = listOf(
                    AlphaExtractionFinding(
                        caseId = caseId,
                        documentId = orderId,
                        kind = AlphaExtractionFindingKind.DateConflict,
                        message = "Confirm the next date against the signed order before relying on it in a note or export.",
                        sourceRefs = listOf(hearingSource),
                        severity = AlphaExtractionFindingSeverity.Warning,
                    )
                ),
            ),
            AlphaCaseDocument(
                id = affidavitId,
                title = "Demo affidavit",
                fileName = "demo-affidavit.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/demo-affidavit.pdf",
                importedAt = java.time.Instant.now().minusSeconds(5 * 86_400L).toString(),
                pageCount = 3,
                ocrStatus = AlphaOcrStatus.NativeText,
                extractedText = "Affidavit describing chronology and supporting facts for arguments.",
                indexingStatus = AlphaIndexingStatus.Indexed,
                dominantSourceSnippet = "Cause title and supporting chronology for arguments.",
                lastIndexedAt = java.time.Instant.now().minusSeconds(5 * 86_400L).toString(),
                pages = (1..3).map { AlphaDocumentPage(pageNumber = it, snippet = "Demo affidavit page $it.") },
                classification = AlphaLegalDocumentClassification(
                    documentId = affidavitId,
                    type = AlphaLegalDocumentType.Affidavit,
                    confidence = 0.79,
                    sourceRefs = listOf(partySource),
                    needsReview = false,
                ),
                extractedFields = listOf(
                    AlphaExtractedLegalField(
                        caseId = caseId,
                        documentId = affidavitId,
                        fieldType = AlphaExtractedLegalFieldType.PartyName,
                        label = "Party name",
                        value = "Sharma v. Rana",
                        sourceRefs = listOf(partySource),
                        confidence = 0.63,
                        extractionMode = AlphaExtractionMode.CaseAssociate,
                        extractionPass = AlphaExtractionPass.LlmExtract,
                        needsReview = true,
                    )
                ),
            ),
            AlphaCaseDocument(
                id = noticeId,
                title = "Demo notice",
                fileName = "demo-notice.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/demo-notice.pdf",
                importedAt = java.time.Instant.now().minusSeconds(8 * 86_400L).toString(),
                pageCount = 2,
                ocrStatus = AlphaOcrStatus.NativeText,
                extractedText = "Notice recording a filing deadline and response timeline.",
                indexingStatus = AlphaIndexingStatus.Indexed,
                dominantSourceSnippet = "Filing compliance should be completed before the listed date.",
                lastIndexedAt = java.time.Instant.now().minusSeconds(8 * 86_400L).toString(),
                pages = (1..2).map { AlphaDocumentPage(pageNumber = it, snippet = "Demo notice page $it.") },
                classification = AlphaLegalDocumentClassification(
                    documentId = noticeId,
                    type = AlphaLegalDocumentType.Notice,
                    confidence = 0.74,
                    sourceRefs = listOf(filingSource),
                    needsReview = false,
                ),
                extractedFields = listOf(
                    AlphaExtractedLegalField(
                        caseId = caseId,
                        documentId = noticeId,
                        fieldType = AlphaExtractedLegalFieldType.Date,
                        label = "Filing deadline",
                        value = alphaMatterDateLabel(filingDeadline),
                        sourceRefs = listOf(filingSource),
                        confidence = 0.77,
                        extractionMode = AlphaExtractionMode.CaseAssociate,
                        extractionPass = AlphaExtractionPass.LlmVerify,
                        needsReview = true,
                    )
                ),
            ),
        ),
        sourceRefs = listOf(hearingSource, directionSource, partySource, filingSource),
        chatTurns = listOf(
            AlphaChatTurn(
                question = "Matter update",
                answerTitle = "Good morning",
                answerSections = listOf(
                    "This demo matter has one next hearing, one filing deadline, and one order that still needs advocate review.",
                    "Start with the latest order, confirm the next date, then generate a short hearing note.",
                ),
                sourceRefs = listOf(hearingSource, directionSource),
            )
        ),
        caseMemoryUpdates = listOf(
            AlphaCaseMemoryUpdate(
                caseId = caseId,
                source = AlphaCaseMemoryUpdateSource.ManualNote,
                summary = "Demo workspace prepared for local morning-use QA.",
                affectedDocuments = listOf(orderId, affidavitId, noticeId),
            )
        ),
    )
    return listOf(demoMatter, sharedWorkspaceMatter())
}

private fun sharedWorkspaceMatter(): AlphaCaseMatter =
    AlphaCaseMatter(
        id = ALPHA_SHARED_WORKSPACE_ID,
        title = "Shared files",
        forum = "Available across matters",
        stage = AlphaCaseStage.Intake,
        nextHearing = null,
        summary = "Files placed here stay available anywhere on this device.",
        issueHighlights = listOf("Use shared files when a document should support more than one matter."),
        evidenceNotes = listOf("Ross keeps these files local and ready for device-wide questions."),
        draftTasks = emptyList(),
        documents = emptyList(),
        sourceRefs = emptyList(),
    )

fun nowIso(): String = java.time.Instant.now().toString()
private fun alphaMatterDateLabel(rawDate: String): String {
    val instant = runCatching { java.time.Instant.parse(rawDate) }.getOrNull() ?: return rawDate.take(10)
    val formatter = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy")
    return instant
        .atZone(java.time.ZoneId.systemDefault())
        .format(formatter)
}
private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
private fun String.toRuntimeMode(): AlphaPackRuntimeMode = when (lowercase()) {
    "deterministic_dev" -> AlphaPackRuntimeMode.DeterministicDev
    "mediapipe_llm" -> AlphaPackRuntimeMode.MediapipeLlm
    "gemma_local_runtime" -> AlphaPackRuntimeMode.Gemma 4 E4B Q4CppGguf
    "apple_foundation_models" -> AlphaPackRuntimeMode.AppleFoundationModels
    "unavailable" -> AlphaPackRuntimeMode.Unavailable
    else -> AlphaPackRuntimeMode.Unavailable
}

private fun seedTasks(cases: List<AlphaCaseMatter>): List<AlphaTaskItem> {
    val demoCaseId = cases.firstOrNull { it.id != ALPHA_SHARED_WORKSPACE_ID }?.id
    return listOfNotNull(
        demoCaseId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Review latest order",
                notes = "Confirm the next date and order direction from the demo order.",
                dueDate = java.time.Instant.now().plusSeconds(86_400).toString(),
                priority = AlphaTaskPriority.High,
                source = AlphaTaskSource.Manual,
            )
        },
        demoCaseId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Prepare hearing note",
                notes = "Generate a short note after confirming the next date.",
                dueDate = java.time.Instant.now().plusSeconds(2 * 86_400L).toString(),
                priority = AlphaTaskPriority.Normal,
                source = AlphaTaskSource.System,
            )
        },
        demoCaseId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Confirm filing deadline",
                notes = "Check the demo notice before closing the review loop.",
                dueDate = java.time.Instant.now().plusSeconds(4 * 86_400L).toString(),
                priority = AlphaTaskPriority.High,
                source = AlphaTaskSource.Extraction,
            )
        },
        demoCaseId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Call client with next date",
                notes = "Use the confirmed next date after advocate review.",
                dueDate = java.time.Instant.now().plusSeconds(2 * 86_400L).toString(),
                priority = AlphaTaskPriority.Normal,
                source = AlphaTaskSource.Manual,
            )
        }
    )
}

private fun demoSeedState(subject: String): AlphaPersistedState {
    val cases = seedCases()
    return AlphaPersistedState(
        demoProfileSubject = subject,
        cases = cases,
        tasks = seedTasks(cases),
        ledgerEntries = listOf(
            AlphaPrivacyLedgerEntry(
                title = "Demo workspace prepared locally",
                detail = "Ross created synthetic sample work for local testing only.",
                purpose = AlphaPrivacyPurpose.LocalOnly,
                payloadClass = AlphaPayloadClass.LocalOnly,
                endpointLabel = "device://demo-seed",
                success = true,
            ),
            AlphaPrivacyLedgerEntry(
                title = "Model catalog checked",
                detail = "Catalog metadata was reviewed without case files attached.",
                purpose = AlphaPrivacyPurpose.ModelCatalog,
                payloadClass = AlphaPayloadClass.NoCaseData,
                endpointLabel = "/model-catalog",
                success = true,
            ),
        ),
    )
}

private fun alphaReviewTitle(type: AlphaExtractedLegalFieldType): String = when (type) {
    AlphaExtractedLegalFieldType.NextDate -> "Confirm next date"
    AlphaExtractedLegalFieldType.PartyName -> "Review party name"
    AlphaExtractedLegalFieldType.OrderDirection -> "Check order direction"
    else -> "Please confirm"
}

private fun alphaReviewTitle(kind: AlphaExtractionFindingKind): String = when (kind) {
    AlphaExtractionFindingKind.LowConfidenceOcr,
    AlphaExtractionFindingKind.LanguageUncertain,
    AlphaExtractionFindingKind.PossibleHandwriting -> "Low confidence scan"
    AlphaExtractionFindingKind.AmbiguousOrderDirection -> "Check order direction"
    AlphaExtractionFindingKind.DateConflict -> "Confirm next date"
    AlphaExtractionFindingKind.PartyConflict -> "Review party name"
    else -> "Please confirm"
}

fun AlphaCaseDocument.lawyerStatusTitle(): String {
    val hasReviewWork = extractedFields.any { it.needsReview } || extractionFindings.any { !it.resolved }
    val hasLowConfidenceScan = extractionFindings.any {
        it.kind == AlphaExtractionFindingKind.LowConfidenceOcr ||
            it.kind == AlphaExtractionFindingKind.LanguageUncertain ||
            it.kind == AlphaExtractionFindingKind.PossibleHandwriting
    }

    return when {
        extractionRuns.firstOrNull()?.status == AlphaExtractionRunStatus.Running ||
            indexingStatus == AlphaIndexingStatus.Extracting -> "Reading your file..."
        indexingStatus == AlphaIndexingStatus.Failed || ocrStatus == AlphaOcrStatus.Failed -> "Could not read this file"
        hasLowConfidenceScan -> "Low confidence scan"
        hasReviewWork -> "Please confirm"
        indexingStatus == AlphaIndexingStatus.Indexed || ocrStatus == AlphaOcrStatus.NativeText || ocrStatus == AlphaOcrStatus.OcrComplete -> "Ready"
        else -> "Reading your file..."
    }
}

fun AlphaPrivacyLedgerEntry.lawyerTitle(): String = when (title) {
    "Model catalog checked" -> "Checked private assistant setup"
    "Private AI Pack queued", "Private AI Pack verified" -> "Set up private assistant"
    "Public-law query sent" -> "Searched public law"
    "Public-law search unavailable" -> "Public-law search needs attention"
    "Local export generated" -> "Generated Notes & Drafts"
    "Case review run" -> "Reviewed case"
    "Document imported locally" -> "Imported document"
    "Case created locally" -> "Created case"
    else -> title
}

fun AlphaPrivacyLedgerEntry.lawyerDetail(): String = when (title) {
    "Public-law query sent" ->
        "Ross sent only a generic public-law query. Your case files stayed on this device."
    "Public-law search unavailable" ->
        "Ross could not complete the sanitized public-law search. Your case files stayed on this device."
    "Private AI Pack verified" ->
        "Private assistant was prepared on this device."
    else -> detail
}

fun AlphaPrivacyLedgerEntry.lawyerPurposeLabel(): String = when (purpose) {
    AlphaPrivacyPurpose.LocalOnly -> "Stayed on this device"
    AlphaPrivacyPurpose.PublicLawSearch -> "Law search only"
    AlphaPrivacyPurpose.ModelCatalog,
    AlphaPrivacyPurpose.ModelDownload,
    AlphaPrivacyPurpose.ModelVerification -> "Private assistant setup"
}
