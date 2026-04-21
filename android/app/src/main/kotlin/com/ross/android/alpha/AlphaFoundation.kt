package com.ross.android.alpha

import android.content.Context
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.webkit.MimeTypeMap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
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
import java.util.UUID

private const val ALPHA_ROSS_SUGGESTED_TASK_NOTE_PREFIX = "ross-overview::"

enum class AlphaOnboardingStage { Onboarding, PrivateAiPack, Completed }
enum class AlphaAppTab { Home, Cases, Capture, Ask, Settings, PublicLaw, Exports }
enum class AlphaCapabilityTier(val tierId: String, val title: String, val summary: String, val downloadSizeLabel: String, val installedSizeLabel: String) {
    QuickStart("quick_start", "Quick Start", "Basic extraction for short documents, simple summaries, and lighter storage use.", "1.2 GB", "2.1 GB"),
    CaseAssociate("case_associate", "Case Associate", "Better document understanding, stronger field extraction, mixed English/Hindi support, and source-backed chronology work.", "2.8 GB", "4.9 GB"),
    SeniorDraftingSupport("senior_drafting_support", "Senior Drafting Support", "Deeper review, verification pass, longer bilingual bundles, and evidence or issue analysis.", "4.6 GB", "7.4 GB");

    val compactSetupSummary: String
        get() = when (this) {
            QuickStart -> "Short files"
            CaseAssociate -> "Most matters"
            SeniorDraftingSupport -> "Longer bundles"
        }

    val storageNote: String
        get() = when (this) {
            QuickStart -> "Light footprint"
            CaseAssociate -> "Balanced footprint"
            SeniorDraftingSupport -> "Largest footprint"
        }

    val bestFor: String
        get() = when (this) {
            QuickStart -> "Fast intake, smaller devices, and standard extraction for short documents."
            CaseAssociate -> "Most advocates who need source-backed extraction, chronology work, and mixed-language review on-device."
            SeniorDraftingSupport -> "Longer bundles, hearing prep, verification passes, and stronger bilingual workflows."
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
enum class AlphaCaseStage { Intake, Pleadings, Evidence, Arguments, Reserved }
enum class AlphaMatterTint { Indigo, Amber, Emerald, Rose, Slate }
enum class AlphaTaskPriority { Low, Normal, High }
enum class AlphaTaskStatus { Open, Done }
enum class AlphaTaskSource { Manual, Extraction, System }
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
    val answerTitle: String,
    val answerSections: List<String>,
    val caseFileSources: List<AlphaSourceRef>,
    val publicLawPreview: AlphaPublicLawPreview? = null,
    val publicLawResults: List<AlphaPublicLawResult> = emptyList(),
    val statusNote: String? = null,
    val needsReviewWarning: String? = null,
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
    val artifactKind: String = "tiny_dev_artifact",
    val runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.DeterministicDev,
    val developmentOnly: Boolean = true,
    val minimumAppVersion: String = "0.1.0",
    val failureReason: String? = null,
    val createdAt: String = nowIso(),
    val updatedAt: String = nowIso(),
    val completedAt: String? = null,
)

data class AlphaInstalledPack(
    val id: String = UUID.randomUUID().toString(),
    val packId: String,
    val tier: AlphaCapabilityTier,
    val installRelativePath: String,
    val checksumSha256: String,
    val artifactKind: String = "tiny_dev_artifact",
    val runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.DeterministicDev,
    val developmentOnly: Boolean = true,
    val checksumVerified: Boolean = true,
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
    val requirePublicLawApproval: Boolean = true,
    val instantModeEnabled: Boolean = true,
    val privateByDefault: Boolean = true,
)

data class AlphaPersistedState(
    val onboardingStage: AlphaOnboardingStage = AlphaOnboardingStage.Onboarding,
    val selectedTab: AlphaAppTab = AlphaAppTab.Home,
    val settings: AlphaSettings = AlphaSettings(),
    val cases: List<AlphaCaseMatter> = seedCases(),
    val tasks: List<AlphaTaskItem>? = null,
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

    var persisted by mutableStateOf(loadState())
    var pendingRoute by mutableStateOf<AndroidAlphaRoute?>(null)

    var selectedCaseId by mutableStateOf(persisted.cases.firstOrNull()?.id)
    var selectedTier by mutableStateOf(persisted.settings.activeTier ?: AlphaCapabilityTier.CaseAssociate)
    var caseDraftTitle by mutableStateOf("")
    var caseDraftForum by mutableStateOf("")
    var askDrafts by mutableStateOf<Map<String, String>>(emptyMap())
    var globalAskDraft by mutableStateOf("What needs my attention today?")
    var askSelectedScopeCaseId by mutableStateOf<String?>(null)
    var askDocumentTitles by mutableStateOf<Map<String, String>>(emptyMap())
    var globalAskDocumentTitle by mutableStateOf<String?>(null)
    var askWebEnabled by mutableStateOf(false)
    var pendingPublicLawQuestion by mutableStateOf<String?>(null)
    var pendingPublicLawScopeCaseId by mutableStateOf<String?>(null)
    var latestAskResult by mutableStateOf<AlphaAskResult?>(null)
    var askHistory by mutableStateOf(seedAskHistory(persisted.cases))
    var publicLawDraft by mutableStateOf("Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted.")
    var publicLawPreview by mutableStateOf<AlphaPublicLawPreview?>(null)
    var publicLawResults by mutableStateOf<List<AlphaPublicLawResult>>(emptyList())
    var localInferenceSmokeReport by mutableStateOf<AlphaLocalInferenceSmokeReport?>(null)
    var localInferenceSmokeRunning by mutableStateOf(false)
    var refreshingCaseOverviewIds by mutableStateOf<Set<String>>(emptySet())

    val cases: List<AlphaCaseMatter>
        get() = persisted.cases
            .filter { it.archivedAt == null }
            .sortedByDescending { it.updatedAt }

    private val activeCaseIds: Set<String>
        get() = cases.mapTo(linkedSetOf()) { it.id }

    fun activePack(): AlphaInstalledPack? = persisted.installedPacks.firstOrNull { it.isActive }

    fun activeExtractionMode(): AlphaExtractionMode = AlphaExtractionMode.fromInstalledPack(activePack())

    fun activeRuntimeHealth(): AlphaLocalRuntimeHealth? =
        AlphaLocalModelRuntime.runtimeHealth(
            activePack = activePack(),
            requestedTier = activePack()?.tier ?: persisted.settings.activeTier,
            context = context,
            appPrivateRoot = rootDir,
        )

    fun lastModelInvocationRuntimeMode(): String? =
        persisted.cases
            .flatMap { it.documents }
            .flatMap { it.modelInvocations }
            .lastOrNull()
            ?.runtimeMode

    fun lastLocalInferenceMetrics(): AlphaLocalInferenceMetrics? =
        persisted.localInferenceMetrics.maxByOrNull { it.createdAt }

    fun tasks(caseId: String? = null): List<AlphaTaskItem> =
        (persisted.tasks ?: emptyList())
            .filter { task ->
                task.caseId == null || task.caseId in activeCaseIds
            }
            .filter { caseId == null || it.caseId == caseId }
            .sortedWith(
                compareBy<AlphaTaskItem> { it.status != AlphaTaskStatus.Open }
                    .thenBy { it.dueDate ?: "9999-12-31T00:00:00Z" }
                    .thenByDescending { it.updatedAt }
            )

    fun openTasks(caseId: String? = null): List<AlphaTaskItem> =
        tasks(caseId).filter { it.status == AlphaTaskStatus.Open }

    fun todayTasks(caseId: String? = null): List<AlphaTaskItem> =
        openTasks(caseId).filter { it.dueDate?.startsWith(nowIso().substring(0, 10)) == true }

    fun upcomingTasks(caseId: String? = null): List<AlphaTaskItem> =
        openTasks(caseId).filter { it.dueDate != null && !it.dueDate.startsWith(nowIso().substring(0, 10)) }

    fun askDraft(scopeCaseId: String?): String =
        scopeCaseId?.let { askDrafts[it] ?: "Ask Ross about this case..." } ?: globalAskDraft

    fun setAskDraft(scopeCaseId: String?, value: String) {
        if (scopeCaseId == null) {
            globalAskDraft = value
        } else {
            askDrafts = askDrafts + (scopeCaseId to value)
        }
    }

    fun askDocumentTitle(scopeCaseId: String?): String? =
        scopeCaseId?.let { askDocumentTitles[it] } ?: globalAskDocumentTitle

    fun setAskDocumentTitle(scopeCaseId: String?, value: String?) {
        if (scopeCaseId == null) {
            globalAskDocumentTitle = value
        } else {
            askDocumentTitles = if (value.isNullOrBlank()) {
                askDocumentTitles - scopeCaseId
            } else {
                askDocumentTitles + (scopeCaseId to value)
            }
        }
    }

    fun openAsk(scopeCaseId: String? = null, documentTitle: String? = null) {
        setAskDocumentTitle(scopeCaseId, documentTitle)
        pendingRoute = scopeCaseId?.let(AndroidAlphaRoute::AskCase) ?: AndroidAlphaRoute.AskRoss
    }

    fun scopeLabel(caseId: String?): String =
        caseId?.let { id -> cases.firstOrNull { it.id == id }?.title } ?: "All matters"

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
        persisted = persisted.copy(
            onboardingStage = AlphaOnboardingStage.Completed,
            selectedTab = AlphaAppTab.Home,
            settings = persisted.settings.copy(activeTier = selectedTier),
        )
        save()
        startPackInstall(selectedTier, selectedTier == AlphaCapabilityTier.QuickStart)
    }

    fun createCase(openWorkspace: Boolean = true): String? {
        val title = caseDraftTitle.trim()
        if (title.isEmpty()) return null
        val case = AlphaCaseMatter(
            title = title,
            forum = caseDraftForum.trim().ifBlank { "Forum pending" },
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
        persisted = persisted.copy(
            cases = persisted.cases.map { matter ->
                if (matter.id == caseId) matter.copy(folderTint = tint, updatedAt = nowIso()) else matter
            }
        )
        save()
    }

    fun deleteCase(caseId: String) {
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

    fun importDocument(caseId: String, uri: Uri): Boolean {
        ensureFolders()
        val caseFolder = File(documentsDir, caseId).apply { mkdirs() }
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
            AlphaDocumentKind.Image -> "Imported image page. Ross is extracting text locally."
            AlphaDocumentKind.Pdf -> "Imported PDF. Ross is reviewing pages locally."
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
                    caseId = caseId,
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
            caseId = caseId,
            documentId = document.id,
            documentTitle = document.title,
            pageNumber = 1,
            textSnippet = document.extractedText ?: "Imported source reference",
            ocrConfidence = if (kind == AlphaDocumentKind.Text) 0.99 else null,
        )
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) case.copy(
                    documents = listOf(document) + case.documents,
                    sourceRefs = listOf(sourceRef) + case.sourceRefs,
                    updatedAt = nowIso(),
                ) else case
            },
            ledgerEntries = listOf(localLedger("Document imported locally", "${document.title} was copied into app-private storage.")) + persisted.ledgerEntries,
        )
        pendingRoute = AndroidAlphaRoute.DocumentViewer(caseId, document.id, 1)
        save()
        scope.launch {
            runExtractionForDocument(caseId, document.id)
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
            ?: "Ask Ross about this case..."
        val localResult = buildLocalAskResult(question, caseId)
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    val turn = AlphaChatTurn(
                        question = question,
                        answerTitle = localResult.answerTitle,
                        answerSections = localResult.answerSections,
                        sourceRefs = localResult.caseFileSources,
                    )
                    case.copy(chatTurns = listOf(turn) + case.chatTurns, updatedAt = nowIso())
                } else case
            },
            ledgerEntries = listOf(localLedger("Local case review run", "The case question and source-backed draft stayed on-device.")) + persisted.ledgerEntries,
        )
        latestAskResult = localResult
        save()
    }

    fun submitAsk(question: String, scopeCaseId: String?, webEnabled: Boolean) {
        val cleaned = question.trim()
        if (cleaned.isEmpty()) return
        val localResult = buildLocalAskResult(cleaned, scopeCaseId)
        appendAskResult(localResult, scopeCaseId)
        latestAskResult = localResult
        askSelectedScopeCaseId = scopeCaseId
        setAskDraft(scopeCaseId, cleaned)

        if (webEnabled) {
            val preview = buildAskPublicLawPreview(cleaned, scopeCaseId)
            pendingPublicLawQuestion = cleaned
            pendingPublicLawScopeCaseId = scopeCaseId
            publicLawPreview = preview
            latestAskResult = latestAskResult?.copy(publicLawPreview = preview, statusNote = "Web search preview ready")
            updateLatestAskHistory(scopeCaseId, cleaned) { result ->
                result.copy(publicLawPreview = preview, statusNote = "Web search preview ready")
            }
        } else {
            pendingPublicLawQuestion = null
            pendingPublicLawScopeCaseId = null
            publicLawPreview = null
        }
    }

    fun cancelPendingPublicLawSearch() {
        val pendingQuestion = pendingPublicLawQuestion
        val pendingScope = pendingPublicLawScopeCaseId
        pendingPublicLawQuestion = null
        pendingPublicLawScopeCaseId = null
        publicLawPreview = null
        latestAskResult = latestAskResult?.copy(statusNote = "Web search off")
        if (pendingQuestion != null) {
            updateLatestAskHistory(pendingScope, pendingQuestion) { result ->
                result.copy(publicLawPreview = null, statusNote = "Web search off")
            }
        }
    }

    fun confirmPendingPublicLawSearch() {
        val preview = publicLawPreview ?: return
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
                            "Ross could not reach the sanitized public-law backend with the approved preview."
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

    private fun appendAskResult(result: AlphaAskResult, scopeCaseId: String?) {
        askHistory = askHistory + result
        val updatedCases = if (scopeCaseId == null) {
            persisted.cases
        } else {
            persisted.cases.map { case ->
                if (case.id == scopeCaseId) {
                    val turn = AlphaChatTurn(
                        question = result.question,
                        answerTitle = result.answerTitle,
                        answerSections = result.answerSections,
                        sourceRefs = result.caseFileSources,
                    )
                    case.copy(chatTurns = listOf(turn) + case.chatTurns, updatedAt = nowIso())
                } else case
            }
        }
        persisted = persisted.copy(
            cases = updatedCases,
            ledgerEntries = listOf(
                localLedger(
                    if (scopeCaseId == null) "Local review run" else "Local case review run",
                    "The question and source-backed draft stayed on-device.",
                )
            ) + persisted.ledgerEntries,
        )
        save()
    }

    private fun updateLatestAskHistory(scopeCaseId: String?, question: String, update: (AlphaAskResult) -> AlphaAskResult) {
        val index = askHistory.indexOfLast { it.scopeCaseId == scopeCaseId && it.question == question }
        if (index == -1) return
        askHistory = askHistory.toMutableList().also { items ->
            items[index] = update(items[index])
        }
    }

    fun buildPublicLawPreview() {
        publicLawPreview = AlphaPayloadShaper.buildPublicLawPreview(publicLawDraft, selectedCase())
        publicLawResults = emptyList()
    }

    fun runPublicLawSearch() {
        val preview = publicLawPreview ?: return
        scope.launch {
            val backendResults = runCatching { backend.searchPublicLaw(preview) }
            publicLawResults = backendResults.getOrElse {
                    listOf(
                        AlphaPublicLawResult(
                            title = "Delay condonation and documented diligence",
                            citation = "(2024) 7 SCC 112",
                            snippet = "Diligence, chronology, and the absence of strategic delay remain central to condonation review.",
                            sourceName = "Official or licensed source (preview)",
                        ),
                        AlphaPublicLawResult(
                            title = "Administrative fairness in filing-delay matters",
                            citation = "2023 SCC OnLine SC 881",
                            snippet = "A brief disruption may be weighed differently where the record shows prompt corrective action and contemporaneous documentation.",
                            sourceName = "Official or licensed source (preview)",
                        ),
                    )
                }
            persisted = persisted.copy(
                publicLawCache = listOf(AlphaPublicLawCacheItem(query = preview.query, resultTitles = publicLawResults.map { it.title })) + persisted.publicLawCache,
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Public-law query sent",
                        detail = "Only a sanitized public query crossed the network boundary.",
                        purpose = AlphaPrivacyPurpose.PublicLawSearch,
                        payloadClass = AlphaPayloadClass.SanitizedPublicQuery,
                        endpointLabel = "/public-law/search",
                        success = backendResults.isSuccess,
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
        val now = nowIso()
        val stagedJob = AlphaModelPackManager.stageJob(
            tier = tier,
            mobileAllowed = mobileAllowed,
            existingJob = persisted.modelJobs.firstOrNull { it.tier == tier },
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
        persisted = persisted.copy(installedPacks = persisted.installedPacks.filterNot { it.id == packId })
        save()
    }

    fun activatePack(packId: String) {
        val activePack = persisted.installedPacks.firstOrNull { it.id == packId }
        persisted = persisted.copy(
            settings = persisted.settings.copy(activeTier = activePack?.tier),
            installedPacks = persisted.installedPacks.map { it.copy(isActive = it.id == packId) },
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
        if ((refreshedForum == "Forum pending" || refreshedForum.isBlank())) {
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
        syncRossSuggestedTasks(refreshedCase)
    }

    private fun syncRossSuggestedTasks(case: AlphaCaseMatter) {
        val existingTasks = persisted.tasks ?: emptyList()
        val preservedTasks = existingTasks.filterNot {
            it.caseId == case.id && it.status == AlphaTaskStatus.Open && it.isRossSuggestedTask()
        }
        val generatedTasks = case.draftTasks.mapIndexedNotNull { index, title ->
            if (preservedTasks.any { it.caseId == case.id && it.title == title }) {
                null
            } else {
                AlphaTaskItem(
                    caseId = case.id,
                    title = title,
                    notes = rossSuggestedTaskNote(case.id, index),
                    dueDate = if (index == 0) case.nextHearing else null,
                    priority = if (index == 0) AlphaTaskPriority.High else AlphaTaskPriority.Normal,
                    source = AlphaTaskSource.System,
                )
            }
        }
        persisted = persisted.copy(tasks = generatedTasks + preservedTasks)
    }

    private fun buildLocalAskResult(question: String, scopeCaseId: String?): AlphaAskResult {
        val visibleCases = persisted.cases.filter { scopeCaseId == null || it.id == scopeCaseId }
        val lowered = question.lowercase()
        val asksAboutSchedule = lowered.contains("next date") || lowered.contains("hearing")
        val asksAboutTasks = lowered.contains("task") || lowered.contains("today") || lowered.contains("reminder") || lowered.contains("due")
        val asksAboutReview = lowered.contains("review") || lowered.contains("document") || lowered.contains("order") || lowered.contains("party")
        val matchedSources = visibleCases
            .flatMap { it.sourceRefs }
            .filter {
                asksAboutSchedule ||
                    asksAboutTasks ||
                    asksAboutReview ||
                    lowered.contains(it.documentTitle.lowercase()) ||
                    lowered.contains((it.textSnippet ?: "").lowercase())
            }
        val sections = mutableListOf<String>()
        if (asksAboutSchedule) {
            visibleCases.mapNotNull { case ->
                case.nextHearing?.let { nextDate -> "${case.title}: ${nextDate.take(10)}" }
            }.take(2).forEach(sections::add)
        }
        if (asksAboutTasks) {
            openTasks(scopeCaseId).take(3).forEach { task ->
                sections += task.dueDate?.let { "${task.title} by ${it.take(10)}" } ?: task.title
            }
        }
        if (asksAboutReview) {
            reviewQueue(scopeCaseId).take(3).forEach { sections += "${it.title}: ${it.detail}" }
        }
        val notFound = sections.isEmpty() && matchedSources.isEmpty()
        return AlphaAskResult(
            question = question,
            scopeCaseId = scopeCaseId,
            scopeLabel = scopeLabel(scopeCaseId),
            answerTitle = if (notFound) "Ross could not find this in local matter files yet." else "Ross draft for advocate review",
            answerSections = if (notFound) listOf("Ross could not find this in local matter files yet.") else sections.take(3),
            caseFileSources = matchedSources.take(3),
            statusNote = if (notFound) "Web search off" else "Ross thread · local matter sources",
            needsReviewWarning = reviewQueue(scopeCaseId).takeIf { it.isNotEmpty() }?.size?.let { "$it item(s) still need review." },
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
            mode == AlphaExtractionMode.Basic -> "Better extraction is available with Case Associate."
            mode == AlphaExtractionMode.QuickStart && (document.languageProfile?.primaryLanguage == AlphaDocumentLanguage.Mixed ||
                document.extractionFindings.any { it.kind == AlphaExtractionFindingKind.LowConfidenceOcr || it.kind == AlphaExtractionFindingKind.LanguageUncertain }) ->
                "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
            mode == AlphaExtractionMode.QuickStart -> "Better extraction is available with Case Associate."
            mode == AlphaExtractionMode.CaseAssociate && document.extractionFindings.any { it.kind == AlphaExtractionFindingKind.LowConfidenceOcr || it.kind == AlphaExtractionFindingKind.LanguageUncertain } ->
                "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
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
                "Fields found: ${visibleFields.size} • Verified: $verifiedCount • Needs review: $pendingCount"
            else -> "Fields found: ${visibleFields.size} • Verified: $verifiedCount • Needs review: 0"
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
                                summary = "Advocate ignored ${field.label.lowercase()} for local review.",
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
            val downloaded = backend.downloadArtifact(session) { downloadedBytes ->
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
            val verified = AlphaModelPackManager.finalizeInstall(
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
                artifactBytes = downloaded.data,
                now = nowIso(),
            )
            Pair(true, verified)
        }.getOrElse {
            val fallback = AlphaModelPackManager.finalizeInstall(
                rootDir = rootDir,
                job = jobAfterCatalog.copy(state = AlphaDownloadState.Verifying, updatedAt = nowIso()),
                now = nowIso(),
            )
            Pair(false, fallback)
        }

        val backendWorked = installation.first
        val progress = installation.second
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
                    title = if (backendWorked) "Private AI Pack verified" else "Private AI Pack fallback installed",
                    detail = if (backendWorked) "Checksum and install metadata were verified locally after backend delivery." else "The backend was unavailable, so Ross prepared a local development artifact without case data.",
                    purpose = AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = if (backendWorked) "device://model-verify" else "device://model-verify",
                    success = progress.job.state != AlphaDownloadState.Failed,
                )
            ) + progress.ledgerEntries + persisted.ledgerEntries,
        )
        save()
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
        askDocumentTitles = askDocumentTitles - caseId
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

    private fun rossSuggestedTaskNote(caseId: String, slot: Int): String =
        "$ALPHA_ROSS_SUGGESTED_TASK_NOTE_PREFIX$caseId::$slot"

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
        val normalizedTasks = state.tasks ?: seedTasks(state.cases)
        return state.copy(selectedTab = normalizedTab, tasks = normalizedTasks)
    }

    private fun seedAskHistory(cases: List<AlphaCaseMatter>): List<AlphaAskResult> =
        cases.flatMap { case ->
            case.chatTurns.asReversed().map { turn ->
                AlphaAskResult(
                    question = turn.question,
                    scopeCaseId = case.id,
                    scopeLabel = case.title,
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
            if (matter.id == caseId) matter.copy(nextHearing = parsedDate, updatedAt = nowIso()) else matter
        }
    }

    private fun reviewTaskNote(documentId: String, title: String): String =
        "review-sync::$documentId::$title"

    private fun alphaParsedDate(rawValue: String?): String? {
        val raw = rawValue?.trim().orEmpty()
        if (raw.isEmpty()) return null

        runCatching { return java.time.Instant.parse(raw).toString() }

        val normalized = raw
            .replace(",", "")
            .replace(Regex("\\s+"), " ")
            .trim()
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
        )
        val zoneId = java.time.ZoneId.systemDefault()

        supportedPatterns.forEach { pattern ->
            val formatter = java.time.format.DateTimeFormatter.ofPattern(pattern, java.util.Locale.ENGLISH)
            runCatching {
                return java.time.LocalDate.parse(normalized, formatter)
                    .atStartOfDay(zoneId)
                    .toInstant()
                    .toString()
            }
        }

        val inlineDate = Regex("""\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b""").find(normalized)?.value
        if (inlineDate != null) {
            return alphaParsedDate(inlineDate)
        }
        return null
    }
}

private fun seedCases(): List<AlphaCaseMatter> {
    val caseId = UUID.randomUUID().toString()
    val draftId = UUID.randomUUID().toString()
    val noticeId = UUID.randomUUID().toString()
    val sources = listOf(
        AlphaSourceRef(caseId = caseId, documentId = draftId, documentTitle = "Writ Petition Draft", pageNumber = 4, paragraphRange = "¶2-3", textSnippet = "Representation and reply timeline.", ocrConfidence = 0.96),
        AlphaSourceRef(caseId = caseId, documentId = noticeId, documentTitle = "Impugned Notice", pageNumber = 2, paragraphRange = "¶1", textSnippet = "Inspection grounds and compliance window.", ocrConfidence = 0.91),
    )
    val petitionCase = AlphaCaseMatter(
        id = caseId,
        title = "Kaveri Developers v. South Ward Municipal Corporation",
        forum = "Karnataka High Court",
        stage = AlphaCaseStage.Pleadings,
        nextHearing = nowIso(),
        summary = "The file is ready for a chronology-focused hearing note. The strongest near-term task is tying the representation sequence to the municipal demand pages already in the bundle.",
        issueHighlights = listOf(
            "Whether the demand proceeds without addressing the representation already on record.",
            "Whether the notice timing supports a procedural fairness argument.",
        ),
        evidenceNotes = listOf(
            "Representation acknowledgment page should stay close to the hearing note.",
            "Photo bundle still needs placeholder page records for quick navigation.",
        ),
        draftTasks = listOf(
            "Prepare a short chronology for the next hearing.",
            "Anchor the reply timeline to source chips.",
            "Draft a focused procedural fairness note.",
        ),
        documents = listOf(
            AlphaCaseDocument(
                id = draftId,
                title = "Writ Petition Draft",
                fileName = "writ-petition-draft.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/writ-petition-draft.pdf",
                pageCount = 28,
                ocrStatus = AlphaOcrStatus.Indexed,
                extractedText = "Representation chronology, demand challenge, and hearing posture.",
                pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "Draft reference page 1.")),
            ),
            AlphaCaseDocument(
                id = noticeId,
                title = "Impugned Notice",
                fileName = "impugned-notice.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/impugned-notice.pdf",
                pageCount = 6,
                ocrStatus = AlphaOcrStatus.Indexed,
                extractedText = "Inspection grounds and compliance window.",
                pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "Notice page 1.")),
            )
        ),
        sourceRefs = sources,
    )
    val taxCaseId = UUID.randomUUID().toString()
    val orderId = UUID.randomUUID().toString()
    val taxCase = AlphaCaseMatter(
        id = taxCaseId,
        title = "Arun Textiles v. State Tax Officer",
        forum = "Madras High Court",
        stage = AlphaCaseStage.Evidence,
        nextHearing = nowIso(),
        summary = "The file supports an evidence-focused review with the order and reconciliation pages ready for source-backed issue extraction.",
        issueHighlights = listOf(
            "Mismatch between the assessment reasoning and the reconciliation schedule.",
            "Need to isolate whether the clarification already supplied was engaged.",
        ),
        evidenceNotes = listOf(
            "Order pages are ready for source-backed notes.",
            "A short hearing-preparation export can be generated once discrepancy pages are pinned.",
        ),
        draftTasks = listOf(
            "Map discrepancy pages against the order reasoning.",
            "Prepare a short note for the next hearing.",
        ),
        documents = listOf(
            AlphaCaseDocument(
                id = orderId,
                title = "Assessment Order",
                fileName = "assessment-order.pdf",
                kind = AlphaDocumentKind.Pdf,
                storedRelativePath = "seed/assessment-order.pdf",
                pageCount = 19,
                ocrStatus = AlphaOcrStatus.Indexed,
                extractedText = "Assessment reasoning and discrepancy notes.",
                pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "Assessment page 1.")),
            )
        ),
        sourceRefs = listOf(
            AlphaSourceRef(caseId = taxCaseId, documentId = orderId, documentTitle = "Assessment Order", pageNumber = 11, paragraphRange = "¶4", textSnippet = "Reasoning on discrepancy.", ocrConfidence = 0.89)
        ),
    )
    return listOf(petitionCase, taxCase)
}

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
    val petitionId = cases.firstOrNull()?.id
    val taxCaseId = cases.drop(1).firstOrNull()?.id
    return listOfNotNull(
        petitionId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Prepare chronology",
                notes = "Tie the representation timeline to the demand pages before the next hearing.",
                dueDate = java.time.Instant.now().plusSeconds(86_400).toString(),
                priority = AlphaTaskPriority.High,
                source = AlphaTaskSource.Manual,
            )
        },
        petitionId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Review order direction",
                notes = "Confirm whether the notice timing supports the procedural fairness point.",
                dueDate = java.time.Instant.now().plusSeconds(3 * 86_400L).toString(),
                priority = AlphaTaskPriority.Normal,
                source = AlphaTaskSource.Extraction,
            )
        },
        taxCaseId?.let {
            AlphaTaskItem(
                caseId = it,
                title = "Confirm next date",
                notes = "Check the latest order before sharing hearing notes.",
                dueDate = java.time.Instant.now().plusSeconds(5 * 86_400L).toString(),
                priority = AlphaTaskPriority.High,
                source = AlphaTaskSource.System,
            )
        },
        AlphaTaskItem(
            caseId = null,
            title = "Call client",
            notes = "Share the review-ready hearing note after source checks.",
            dueDate = java.time.Instant.now().plusSeconds(2 * 86_400L).toString(),
            priority = AlphaTaskPriority.Normal,
            source = AlphaTaskSource.Manual,
        )
    )
}

private fun alphaReviewTitle(type: AlphaExtractedLegalFieldType): String = when (type) {
    AlphaExtractedLegalFieldType.NextDate -> "Confirm next date"
    AlphaExtractedLegalFieldType.PartyName -> "Review party name"
    AlphaExtractedLegalFieldType.OrderDirection -> "Check order direction"
    else -> "Needs review"
}

private fun alphaReviewTitle(kind: AlphaExtractionFindingKind): String = when (kind) {
    AlphaExtractionFindingKind.LowConfidenceOcr,
    AlphaExtractionFindingKind.LanguageUncertain,
    AlphaExtractionFindingKind.PossibleHandwriting -> "Low confidence scan"
    AlphaExtractionFindingKind.AmbiguousOrderDirection -> "Check order direction"
    AlphaExtractionFindingKind.DateConflict -> "Confirm next date"
    AlphaExtractionFindingKind.PartyConflict -> "Review party name"
    else -> "Needs review"
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
            indexingStatus == AlphaIndexingStatus.Extracting -> "Still reading"
        indexingStatus == AlphaIndexingStatus.Failed || ocrStatus == AlphaOcrStatus.Failed -> "Could not read this clearly"
        hasLowConfidenceScan -> "Low confidence scan"
        hasReviewWork -> "Needs review"
        indexingStatus == AlphaIndexingStatus.Indexed || ocrStatus == AlphaOcrStatus.NativeText || ocrStatus == AlphaOcrStatus.OcrComplete -> "Ready"
        else -> "Still reading"
    }
}

fun AlphaPrivacyLedgerEntry.lawyerTitle(): String = when (title) {
    "Model catalog checked" -> "Checked Private AI availability"
    "Private AI Pack queued", "Private AI Pack verified", "Private AI Pack fallback installed" -> "Downloaded Private AI Pack"
    "Public-law query sent" -> "Searched public law"
    "Public-law search unavailable" -> "Public-law search needs attention"
    "Local export generated" -> "Generated local export"
    "Local case review run" -> "Reviewed case locally"
    "Document imported locally" -> "Imported document"
    "Case created locally" -> "Created case"
    else -> title
}

fun AlphaPrivacyLedgerEntry.lawyerDetail(): String = when (title) {
    "Public-law query sent" ->
        "Ross sent only a generic public-law query. Your case files stayed on this device."
    "Public-law search unavailable" ->
        "Ross could not complete the approved public-law search. Your case files stayed on this device."
    "Private AI Pack verified", "Private AI Pack fallback installed" ->
        "A Private AI Pack was prepared on this device."
    else -> detail
}
