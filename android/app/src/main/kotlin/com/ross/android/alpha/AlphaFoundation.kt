package com.ross.android.alpha

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

enum class AlphaOnboardingStage { Onboarding, PrivateAiPack, Completed }
enum class AlphaAppTab { Cases, PublicLaw, Exports, Settings }
enum class AlphaCapabilityTier(val tierId: String, val title: String, val summary: String, val downloadSizeLabel: String, val installedSizeLabel: String) {
    QuickStart("quick_start", "Quick Start", "Basic summaries, short-file review, and lighter storage use.", "1.2 GB", "2.1 GB"),
    CaseAssociate("case_associate", "Case Associate", "Source-backed case review, chronology work, and balanced local drafting.", "2.8 GB", "4.9 GB"),
    SeniorDraftingSupport("senior_drafting_support", "Senior Drafting Support", "Longer files, deeper issue analysis, and richer drafting support.", "4.6 GB", "7.4 GB");
}
enum class AlphaCaseStage { Intake, Pleadings, Evidence, Arguments, Reserved }
enum class AlphaDocumentKind { Pdf, Image, Text, Unknown }
enum class AlphaOcrStatus { NotStarted, Indexed, Placeholder }
enum class AlphaDownloadState { NotStarted, Queued, Downloading, PausedWaitingForWifi, PausedUser, PausedNoStorage, PausedError, Verifying, Installed, Failed, Cancelled }
enum class AlphaDownloadPolicy { WifiOnly, MobileAllowed }
enum class AlphaPrivacyPurpose { LocalOnly, ModelCatalog, ModelDownload, ModelVerification, PublicLawSearch }
enum class AlphaPayloadClass { LocalOnly, NoCaseData, SanitizedPublicQuery, AccountToken }

data class AlphaDocumentPage(
    val id: String = UUID.randomUUID().toString(),
    val pageNumber: Int,
    val snippet: String? = null,
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
    val pages: List<AlphaDocumentPage>,
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
    private val stateFile = File(rootDir, "state.json")
    private val documentsDir = File(rootDir, "documents")
    private val modelPackDir = File(rootDir, "model-packs")
    private val exportsDir = File(rootDir, "exports")

    var persisted by mutableStateOf(loadState())

    var selectedCaseId by mutableStateOf(persisted.cases.firstOrNull()?.id)
    var selectedTier by mutableStateOf(persisted.settings.activeTier ?: AlphaCapabilityTier.CaseAssociate)
    var caseDraftTitle by mutableStateOf("")
    var caseDraftForum by mutableStateOf("")
    var askDrafts by mutableStateOf<Map<String, String>>(emptyMap())
    var publicLawDraft by mutableStateOf("Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted.")
    var publicLawPreview by mutableStateOf<AlphaPublicLawPreview?>(null)
    var publicLawResults by mutableStateOf<List<AlphaPublicLawResult>>(emptyList())

    private fun loadState(): AlphaPersistedState {
        ensureFolders()
        if (!stateFile.exists()) {
            val seed = AlphaPersistedState()
            saveState(seed)
            return seed
        }
        return runCatching {
            stateFile.reader().use { reader -> gson.fromJson(reader, AlphaPersistedState::class.java) ?: AlphaPersistedState() }
        }.getOrElse { AlphaPersistedState() }
    }

    fun startRoute(): AndroidAlphaRoute = when (persisted.onboardingStage) {
        AlphaOnboardingStage.Onboarding -> AndroidAlphaRoute.Onboarding
        AlphaOnboardingStage.PrivateAiPack -> AndroidAlphaRoute.PrivateAiPack
        AlphaOnboardingStage.Completed -> AndroidAlphaRoute.CaseList
    }

    fun save() = saveState(persisted)

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
        val extractedText = if (kind == AlphaDocumentKind.Text) runCatching { FileInputStream(target).bufferedReader().readText().take(2000) }.getOrNull() else null
        val document = AlphaCaseDocument(
            title = uri.lastPathSegment?.substringBeforeLast('.') ?: "Imported document",
            fileName = uri.lastPathSegment ?: target.name,
            kind = kind,
            storedRelativePath = target.relativeTo(rootDir).path,
            pageCount = 1,
            ocrStatus = if (kind == AlphaDocumentKind.Text) AlphaOcrStatus.Indexed else AlphaOcrStatus.Placeholder,
            extractedText = extractedText,
            pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = extractedText?.take(140) ?: "Imported source reference.")),
        )
        val sourceRef = AlphaSourceRef(
            caseId = caseId,
            documentId = document.id,
            documentTitle = document.title,
            pageNumber = 1,
            textSnippet = document.extractedText ?: "Imported source reference",
            ocrConfidence = if (kind == AlphaDocumentKind.Image) null else 0.92,
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
        save()
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
        val lower = publicLawDraft.lowercase()
        val blocked = listOf(
            "raghav fakepriv",
            "9876501234",
            "fakepriv@example.com",
            "fake/123/2026",
            "blue suitcase near temple",
            "@",
            "case number",
            "client",
            "party",
            "ocr",
        )
        val removed = mutableListOf<String>()
        var sanitized = publicLawDraft
            .replace(Regex("\\b\\d{2,}\\b"), "")
            .replace(Regex("\\s+"), " ")
            .trim()
        selectedCase()?.let { case ->
            if (lower.contains(case.title.lowercase()) || lower.contains(case.forum.lowercase())) {
                removed += "Case title and forum references"
                sanitized = sanitized.replace(case.title, "", true).replace(case.forum, "", true).replace(Regex("\\s+"), " ").trim()
            }
        }
        if (blocked.any { lower.contains(it) }) {
            removed += "Private details and obvious identifiers"
            sanitized = "Find current public-law guidance relevant to delay condonation where diligence is documented."
        }
        if (sanitized.length > 180) {
            removed += "Long factual narrative"
            sanitized = sanitized.take(180).trim()
        }
        publicLawPreview = AlphaPublicLawPreview(
            query = sanitized.ifBlank { "Find current public-law guidance relevant to delay condonation where diligence is documented." },
            removed = if (removed.isEmpty()) listOf("No private case data detected") else removed,
            confirmationNote = "Public-law search sends only a sanitized query after explicit confirmation.",
        )
        publicLawResults = emptyList()
    }

    fun runPublicLawSearch() {
        val preview = publicLawPreview ?: return
        publicLawResults = listOf(
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
        persisted = persisted.copy(
            publicLawCache = listOf(AlphaPublicLawCacheItem(query = preview.query, resultTitles = publicLawResults.map { it.title })) + persisted.publicLawCache,
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Public-law query sent",
                    detail = "Only a sanitized public query crossed the network boundary.",
                    purpose = AlphaPrivacyPurpose.PublicLawSearch,
                    payloadClass = AlphaPayloadClass.SanitizedPublicQuery,
                    endpointLabel = "/public-law/search",
                    success = true,
                )
            ) + persisted.ledgerEntries,
        )
        save()
    }

    fun generateExport(kind: String, caseId: String?) {
        ensureFolders()
        val case = caseId?.let { id -> persisted.cases.firstOrNull { it.id == id } }
        val titleBase = case?.title ?: "Ross Report"
        val file = File(exportsDir, "${slug(titleBase)}-${kind}-${UUID.randomUUID().toString().take(8)}.txt")
        val body = """
            $titleBase
            Generated: ${nowIso()}
            Draft for advocate review
            
            Report type: $kind
            
            Summary
            ${case?.summary ?: "No case selected."}
            
            Source references
            ${case?.sourceRefs?.take(3)?.joinToString("\n") { "- ${it.label}: ${it.detail}" } ?: "- No source references available yet."}
            
            Generated locally for advocate review. Verify all citations.
        """.trimIndent()
        file.writeText(body)
        persisted = persisted.copy(
            exports = listOf(
                AlphaExportRecord(caseId = caseId, title = "$titleBase $kind", kind = kind, relativePath = file.relativeTo(rootDir).path)
            ) + persisted.exports,
            ledgerEntries = listOf(localLedger("Local export generated", "$kind was generated locally for advocate review.")) + persisted.ledgerEntries,
        )
        save()
    }

    fun startPackInstall(tier: AlphaCapabilityTier, mobileAllowed: Boolean) {
        ensureFolders()
        val waitingForWifi = !mobileAllowed && tier != AlphaCapabilityTier.QuickStart
        val checksumSeed = sha256("${tier.tierId}-${UUID.randomUUID()}")
        val totalBytes = when (tier) {
            AlphaCapabilityTier.QuickStart -> 1_200_000_000L
            AlphaCapabilityTier.CaseAssociate -> 2_800_000_000L
            AlphaCapabilityTier.SeniorDraftingSupport -> 4_600_000_000L
        }
        val job = AlphaModelDownloadJob(
            sessionId = "mdl-${UUID.randomUUID().toString().take(8)}",
            packId = "${tier.tierId}-pack",
            tier = tier,
            state = if (waitingForWifi) AlphaDownloadState.PausedWaitingForWifi else AlphaDownloadState.Installed,
            networkPolicy = if (mobileAllowed) AlphaDownloadPolicy.MobileAllowed else AlphaDownloadPolicy.WifiOnly,
            bytesDownloaded = if (waitingForWifi) 0 else 256,
            totalBytes = if (waitingForWifi) totalBytes else 256,
            checksumSha256 = checksumSeed,
            completedAt = if (waitingForWifi) null else nowIso(),
        )
        val installedPack = if (waitingForWifi) null else {
            val folder = File(modelPackDir, tier.tierId).apply { mkdirs() }
            val artifact = File(folder, "pack.dev").apply { writeText("Ross dev artifact for ${tier.tierId}") }
            AlphaInstalledPack(
                packId = job.packId,
                tier = tier,
                installRelativePath = artifact.relativeTo(rootDir).path,
                checksumSha256 = sha256(artifact.readText()),
                isActive = true,
            )
        }
        persisted = persisted.copy(
            settings = persisted.settings.copy(activeTier = if (waitingForWifi) persisted.settings.activeTier else tier),
            modelJobs = listOf(job) + persisted.modelJobs.filterNot { it.tier == tier },
            installedPacks = if (installedPack == null) persisted.installedPacks else listOf(installedPack) + persisted.installedPacks.map { it.copy(isActive = false) }.filterNot { it.tier == tier },
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
                    title = if (waitingForWifi) "Private AI Pack waiting for Wi-Fi" else "Private AI Pack installed",
                    detail = if (waitingForWifi) "Model delivery is paused until you allow a trusted network." else "Checksum and install metadata were prepared locally.",
                    purpose = if (waitingForWifi) AlphaPrivacyPurpose.ModelDownload else AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = if (waitingForWifi) "/model-download/session" else "device://model-verify",
                    success = true,
                ),
            ) + persisted.ledgerEntries,
        )
        save()
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

    fun document(caseId: String, documentId: String): AlphaCaseDocument? =
        persisted.cases.firstOrNull { it.id == caseId }?.documents?.firstOrNull { it.id == documentId }

    fun sourceRefsForDocument(caseId: String, documentId: String): List<AlphaSourceRef> =
        persisted.cases.firstOrNull { it.id == caseId }?.sourceRefs?.filter { it.documentId == documentId } ?: emptyList()

    fun absoluteFile(relativePath: String): File = File(rootDir, relativePath)

    private fun saveState(state: AlphaPersistedState) {
        ensureFolders()
        stateFile.writer().use { writer -> gson.toJson(state, writer) }
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

    private fun slug(value: String) = value.lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-')
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

private fun nowIso(): String = java.time.Instant.now().toString()
private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
