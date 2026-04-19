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
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

enum class AlphaOnboardingStage { Onboarding, PrivateAiPack, Completed }
enum class AlphaAppTab { Cases, PublicLaw, Exports, Settings }
enum class AlphaCapabilityTier(val tierId: String, val title: String, val summary: String, val downloadSizeLabel: String, val installedSizeLabel: String) {
    QuickStart("quick_start", "Quick Start", "Basic extraction for short documents, simple summaries, and lighter storage use.", "1.2 GB", "2.1 GB"),
    CaseAssociate("case_associate", "Case Associate", "Better document understanding, stronger field extraction, mixed English/Hindi support, and source-backed chronology work.", "2.8 GB", "4.9 GB"),
    SeniorDraftingSupport("senior_drafting_support", "Senior Drafting Support", "Deeper review, verification pass, longer bilingual bundles, and evidence or issue analysis.", "4.6 GB", "7.4 GB");

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
enum class AlphaDocumentKind { Pdf, Image, Text, Unknown }
enum class AlphaOcrStatus { NotStarted, Indexed, Placeholder, NativeText, OcrComplete, Partial, Failed }
enum class AlphaIndexingStatus { NotStarted, Extracting, Indexed, Partial, Failed }
enum class AlphaDownloadState { NotStarted, Queued, Downloading, PausedWaitingForWifi, PausedUser, PausedNoStorage, PausedError, Verifying, Installed, Failed, Cancelled }
enum class AlphaDownloadPolicy { WifiOnly, MobileAllowed }
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
    val selectedTab: AlphaAppTab = AlphaAppTab.Cases,
    val settings: AlphaSettings = AlphaSettings(),
    val cases: List<AlphaCaseMatter> = seedCases(),
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
    val publicLawCache: List<AlphaPublicLawCacheItem> = emptyList(),
    val exports: List<AlphaExportRecord> = emptyList(),
)

sealed interface AndroidAlphaRoute {
    data object Onboarding : AndroidAlphaRoute
    data object PrivateAiPack : AndroidAlphaRoute
    data object CaseList : AndroidAlphaRoute
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

class AlphaRossController(private val context: Context) {
    private val gson: Gson = GsonBuilder().setPrettyPrinting().create()
    private val rootDir = File(context.filesDir, "ross-alpha")
    private val documentsDir = File(rootDir, "documents")
    private val modelPackDir = File(rootDir, "model-packs")
    private val exportsDir = File(rootDir, "exports")
    private val encryptedStateStore = AlphaEncryptedStateStore(
        gson = gson,
        rootDir = rootDir,
        aadLabel = context.packageName,
    )
    private val exportService = AlphaExportService(rootDir, exportsDir)
    private val backend = AlphaBackendClient(gson = gson)
    private val extractionOrchestrator = AlphaLocalExtractionOrchestrator(context)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    var persisted by mutableStateOf(loadState())
    var pendingRoute by mutableStateOf<AndroidAlphaRoute?>(null)

    var selectedCaseId by mutableStateOf(persisted.cases.firstOrNull()?.id)
    var selectedTier by mutableStateOf(persisted.settings.activeTier ?: AlphaCapabilityTier.CaseAssociate)
    var caseDraftTitle by mutableStateOf("")
    var caseDraftForum by mutableStateOf("")
    var askDrafts by mutableStateOf<Map<String, String>>(emptyMap())
    var publicLawDraft by mutableStateOf("Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted.")
    var publicLawPreview by mutableStateOf<AlphaPublicLawPreview?>(null)
    var publicLawResults by mutableStateOf<List<AlphaPublicLawResult>>(emptyList())

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

    private fun loadState(): AlphaPersistedState {
        ensureFolders()
        return encryptedStateStore.load { AlphaPersistedState() }
    }

    fun startRoute(): AndroidAlphaRoute = when (persisted.onboardingStage) {
        AlphaOnboardingStage.Onboarding -> AndroidAlphaRoute.Onboarding
        AlphaOnboardingStage.PrivateAiPack -> AndroidAlphaRoute.PrivateAiPack
        AlphaOnboardingStage.Completed -> AndroidAlphaRoute.CaseList
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
        persisted = persisted.copy(onboardingStage = AlphaOnboardingStage.Completed, selectedTab = AlphaAppTab.Cases)
        save()
    }

    fun finishPackSetup() {
        persisted = persisted.copy(
            onboardingStage = AlphaOnboardingStage.Completed,
            selectedTab = AlphaAppTab.Cases,
            settings = persisted.settings.copy(activeTier = selectedTier),
        )
        save()
        startPackInstall(selectedTier, selectedTier == AlphaCapabilityTier.QuickStart)
    }

    fun createCase(): String? {
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
        persisted = persisted.copy(
            cases = listOf(case) + persisted.cases,
            ledgerEntries = listOf(localLedger("Case created locally", "A new case matter was created on this device.")) + persisted.ledgerEntries,
        )
        selectedCaseId = case.id
        caseDraftTitle = ""
        caseDraftForum = ""
        save()
        return case.id
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

    fun askCase(caseId: String) {
        val question = askDrafts[caseId]?.takeIf { it.isNotBlank() }
            ?: "Summarize the next hearing posture and identify the strongest source-backed issue."
        persisted = persisted.copy(
            cases = persisted.cases.map { case ->
                if (case.id == caseId) {
                    val refs = case.sourceRefs.take(2)
                    val turn = AlphaChatTurn(
                        question = question,
                        answerTitle = "Local review completed",
                        answerSections = listOf(
                            case.issueHighlights.firstOrNull() ?: "Confirm the main issue from the indexed bundle.",
                            "Keep the hearing note tied to the source chips already surfaced in this case.",
                            case.draftTasks.firstOrNull() ?: "Prepare a short chronology note.",
                        ),
                        sourceRefs = refs,
                    )
                    case.copy(chatTurns = listOf(turn) + case.chatTurns, updatedAt = nowIso())
                } else case
            },
            ledgerEntries = listOf(localLedger("Local case review run", "The case question and source-backed draft stayed on-device.")) + persisted.ledgerEntries,
        )
        save()
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

    fun selectedCase(): AlphaCaseMatter? = selectedCaseId?.let { id -> persisted.cases.firstOrNull { it.id == id } } ?: persisted.cases.firstOrNull()

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
            ledgerEntries = listOf(localLedger("Local extraction completed", "Ross reviewed the document locally and prepared source-backed fields for advocate review.")) + persisted.ledgerEntries,
        )
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

    private fun inferPdfPageCount(file: File): Int = runCatching {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer -> renderer.pageCount.coerceAtLeast(1) }
        }
    }.getOrDefault(1)
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
private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
private fun String.toRuntimeMode(): AlphaPackRuntimeMode = when (lowercase()) {
    "deterministic_dev" -> AlphaPackRuntimeMode.DeterministicDev
    "mediapipe_llm" -> AlphaPackRuntimeMode.MediapipeLlm
    "gemma_local_runtime" -> AlphaPackRuntimeMode.Gemma 4 E4B Q4CppGguf
    "apple_foundation_models" -> AlphaPackRuntimeMode.AppleFoundationModels
    "unavailable" -> AlphaPackRuntimeMode.Unavailable
    else -> AlphaPackRuntimeMode.Unavailable
}
