package com.ross.android.alpha

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

enum class AlphaExtractionMode(val wireValue: String, val qualityLabel: String) {
    Basic("basic", "Basic"),
    QuickStart("quick_start", "Standard"),
    CaseAssociate("case_associate", "Advanced"),
    SeniorDraftingSupport("senior_drafting_support", "Advanced Plus");

    companion object {
        fun fromTier(tier: AlphaCapabilityTier?): AlphaExtractionMode = when (tier) {
            null -> Basic
            AlphaCapabilityTier.QuickStart -> QuickStart
            AlphaCapabilityTier.CaseAssociate -> CaseAssociate
            AlphaCapabilityTier.SeniorDraftingSupport -> SeniorDraftingSupport
        }
    }
}

enum class AlphaDocumentLanguage { English, Hindi, Mixed, Unknown }
enum class AlphaDocumentScript { Latin, Devanagari, Mixed, Other, Unknown }
enum class AlphaLegalDocumentType { Pleading, Order, Judgment, Affidavit, Notice, Evidence, Correspondence, Misc }
enum class AlphaExtractedLegalFieldType {
    Court,
    CaseNumber,
    PartyName,
    AdvocateName,
    JudgeName,
    Date,
    NextDate,
    Section,
    Relief,
    Prayer,
    OrderDirection,
    LimitationDate,
    Amount,
    ExhibitNumber,
    Fact,
    Issue,
    Unknown,
}
enum class AlphaExtractionPass { Ocr, Regex, LlmExtract, LlmVerify, UserCorrected }
enum class AlphaExtractionRunStatus { Queued, Running, NeedsReview, Complete, Failed, Cancelled }
enum class AlphaExtractionFindingKind {
    LowConfidenceOcr,
    LanguageUncertain,
    PossibleMissingPage,
    DateConflict,
    PartyConflict,
    CaseNumberConflict,
    AmbiguousOrderDirection,
    PossibleHandwriting,
    UnsupportedLayout,
}
enum class AlphaExtractionFindingSeverity { Info, Warning, Critical }
enum class AlphaAdvocateCorrectionType { FieldValue, DocumentType, Language, Date, Party, SourceRef, IgnoreField }
enum class AlphaCaseMemoryUpdateSource { ExtractionRun, UserCorrection, AskCase, ManualNote }

data class AlphaDocumentLanguageProfilePage(
    val pageNumber: Int,
    val language: AlphaDocumentLanguage,
    val script: AlphaDocumentScript,
    val confidence: Double,
)

data class AlphaDocumentLanguageProfile(
    val documentId: String,
    val primaryLanguage: AlphaDocumentLanguage,
    val scriptsDetected: List<String>,
    val confidence: Double,
    val pageProfiles: List<AlphaDocumentLanguageProfilePage>,
)

data class AlphaLegalDocumentClassification(
    val documentId: String,
    val type: AlphaLegalDocumentType,
    val subtype: String? = null,
    val confidence: Double,
    val sourceRefs: List<AlphaSourceRef>,
    val needsReview: Boolean,
)

data class AlphaExtractedLegalField(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val fieldType: AlphaExtractedLegalFieldType,
    val label: String,
    val value: String,
    val normalizedValue: String? = null,
    val sourceRefs: List<AlphaSourceRef>,
    val confidence: Double,
    val extractionMode: AlphaExtractionMode,
    val extractionPass: AlphaExtractionPass,
    val needsReview: Boolean,
    val userCorrected: Boolean = false,
    val createdAt: String = nowIso(),
    val updatedAt: String = nowIso(),
) {
    val confidenceLabel: String
        get() = when {
            needsReview || confidence < 0.64 -> "Needs review"
            confidence >= 0.84 -> "High"
            else -> "Medium"
        }
}

data class AlphaExtractionRun(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val mode: AlphaExtractionMode,
    val status: AlphaExtractionRunStatus,
    val startedAt: String? = null,
    val completedAt: String? = null,
    val pagesProcessed: Int,
    val totalPages: Int,
    val fieldsExtracted: Int,
    val fieldsNeedingReview: Int,
    val warnings: List<String>,
    val errorMessage: String? = null,
)

data class AlphaExtractionFinding(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val kind: AlphaExtractionFindingKind,
    val message: String,
    val sourceRefs: List<AlphaSourceRef>,
    val severity: AlphaExtractionFindingSeverity,
    val resolved: Boolean = false,
)

data class AlphaAdvocateCorrection(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val documentId: String,
    val fieldId: String? = null,
    val oldValue: String? = null,
    val newValue: String,
    val correctionType: AlphaAdvocateCorrectionType,
    val createdAt: String = nowIso(),
)

data class AlphaCaseMemoryUpdate(
    val id: String = UUID.randomUUID().toString(),
    val caseId: String,
    val source: AlphaCaseMemoryUpdateSource,
    val summary: String,
    val affectedDocuments: List<String>,
    val createdAt: String = nowIso(),
)

data class AlphaReviewQueue(
    val fieldIds: List<String>,
    val findingIds: List<String>,
    val summary: String,
)

data class AlphaLocalExtractionResult(
    val pages: List<AlphaDocumentPage>,
    val languageProfile: AlphaDocumentLanguageProfile?,
    val classification: AlphaLegalDocumentClassification?,
    val extractedFields: List<AlphaExtractedLegalField>,
    val extractionRun: AlphaExtractionRun,
    val findings: List<AlphaExtractionFinding>,
    val caseMemoryUpdates: List<AlphaCaseMemoryUpdate>,
    val reviewQueue: AlphaReviewQueue,
)

object AlphaLanguageHeuristics {
    fun detectProfile(documentId: String, pageTexts: List<Pair<Int, String>>): AlphaDocumentLanguageProfile {
        val pageProfiles = pageTexts.map { (pageNumber, text) ->
            val counts = scriptCounts(text)
            val total = counts.first + counts.second + counts.third
            when {
                total == 0 -> AlphaDocumentLanguageProfilePage(pageNumber, AlphaDocumentLanguage.Unknown, AlphaDocumentScript.Unknown, 0.0)
                counts.first > 0 && counts.second > 0 -> AlphaDocumentLanguageProfilePage(pageNumber, AlphaDocumentLanguage.Mixed, AlphaDocumentScript.Mixed, 0.64)
                counts.second > 0 -> AlphaDocumentLanguageProfilePage(pageNumber, AlphaDocumentLanguage.Hindi, AlphaDocumentScript.Devanagari, 0.88)
                counts.first > 0 -> AlphaDocumentLanguageProfilePage(pageNumber, AlphaDocumentLanguage.English, AlphaDocumentScript.Latin, 0.88)
                else -> AlphaDocumentLanguageProfilePage(pageNumber, AlphaDocumentLanguage.Unknown, AlphaDocumentScript.Other, 0.42)
            }
        }
        val hasLatin = pageProfiles.any { it.script == AlphaDocumentScript.Latin || it.script == AlphaDocumentScript.Mixed }
        val hasDevanagari = pageProfiles.any { it.script == AlphaDocumentScript.Devanagari || it.script == AlphaDocumentScript.Mixed }
        val primaryLanguage = when {
            hasLatin && hasDevanagari -> AlphaDocumentLanguage.Mixed
            hasDevanagari -> AlphaDocumentLanguage.Hindi
            hasLatin -> AlphaDocumentLanguage.English
            else -> AlphaDocumentLanguage.Unknown
        }
        val scripts = buildList {
            if (hasLatin) add("latin")
            if (hasDevanagari) add("devanagari")
            if (isEmpty()) add("other")
        }
        return AlphaDocumentLanguageProfile(
            documentId = documentId,
            primaryLanguage = primaryLanguage,
            scriptsDetected = scripts,
            confidence = if (pageProfiles.isEmpty()) 0.0 else pageProfiles.map { it.confidence }.average(),
            pageProfiles = pageProfiles,
        )
    }
}

object AlphaReviewQueues {
    fun build(fields: List<AlphaExtractedLegalField>, findings: List<AlphaExtractionFinding>): AlphaReviewQueue =
        AlphaReviewQueue(
            fieldIds = fields.filter { it.needsReview }.map { it.id },
            findingIds = findings.filterNot { it.resolved }.map { it.id },
            summary = if (fields.any { it.needsReview } || findings.any { !it.resolved }) {
                "Ross found key details. Please review the uncertain ones."
            } else {
                "Ross found key details."
            },
        )
}

private data class AlphaPageAcquisition(
    val pageNumber: Int,
    val text: String?,
    val snippet: String?,
    val anchorText: String?,
    val ocrConfidence: Double?,
    val ocrStatus: AlphaOcrStatus,
    val indexingStatus: AlphaIndexingStatus,
)

class AlphaLocalExtractionOrchestrator(private val context: Context) {
    suspend fun extract(
        caseId: String,
        document: AlphaCaseDocument,
        file: File,
        activeTier: AlphaCapabilityTier?,
    ): AlphaLocalExtractionResult = withContext(Dispatchers.IO) {
        val mode = AlphaExtractionMode.fromTier(activeTier)
        val acquiredPages = acquirePages(document, file)
        val languageProfile = detectLanguageProfile(document.id, acquiredPages)
        val classification = classifyDocument(document, acquiredPages, languageProfile)
        val rawFields = extractFields(caseId, document, acquiredPages, languageProfile, classification, mode)
        val verification = verifyFields(caseId, document, acquiredPages, rawFields)
        val findings = verification.findings + baseFindings(caseId, document.id, acquiredPages, languageProfile)
        val caseMemoryUpdates = buildCaseMemory(caseId, document.id, classification, verification.fields)
        val reviewQueue = AlphaReviewQueues.build(verification.fields, findings)
        val warnings = findings.map { it.message }
        val status = when {
            verification.fields.isEmpty() -> AlphaExtractionRunStatus.Failed
            verification.fields.any { it.needsReview } || findings.any { !it.resolved } -> AlphaExtractionRunStatus.NeedsReview
            else -> AlphaExtractionRunStatus.Complete
        }
        val updatedPages = acquiredPages.map { page ->
            AlphaDocumentPage(
                pageNumber = page.pageNumber,
                snippet = page.snippet,
                extractedText = page.text,
                anchorText = page.anchorText,
                ocrConfidence = page.ocrConfidence,
                ocrStatus = page.ocrStatus,
                indexingStatus = page.indexingStatus,
            )
        }

        AlphaLocalExtractionResult(
            pages = updatedPages,
            languageProfile = languageProfile,
            classification = classification,
            extractedFields = verification.fields,
            extractionRun = AlphaExtractionRun(
                caseId = caseId,
                documentId = document.id,
                mode = mode,
                status = status,
                startedAt = nowIso(),
                completedAt = nowIso(),
                pagesProcessed = updatedPages.size,
                totalPages = document.pageCount,
                fieldsExtracted = verification.fields.size,
                fieldsNeedingReview = verification.fields.count { it.needsReview },
                warnings = warnings,
                errorMessage = if (verification.fields.isEmpty()) "Ross could not find supported legal fields in this document yet." else null,
            ),
            findings = findings,
            caseMemoryUpdates = caseMemoryUpdates,
            reviewQueue = reviewQueue,
        )
    }

    private suspend fun acquirePages(document: AlphaCaseDocument, file: File): List<AlphaPageAcquisition> = when (document.kind) {
        AlphaDocumentKind.Text -> {
            val text = runCatching { file.readText() }.getOrDefault("")
            listOf(
                AlphaPageAcquisition(
                    pageNumber = 1,
                    text = text.ifBlank { null },
                    snippet = compactSnippet(text),
                    anchorText = compactSnippet(text),
                    ocrConfidence = if (text.isBlank()) null else 0.99,
                    ocrStatus = if (text.isBlank()) AlphaOcrStatus.Failed else AlphaOcrStatus.NativeText,
                    indexingStatus = if (text.isBlank()) AlphaIndexingStatus.Failed else AlphaIndexingStatus.Indexed,
                )
            )
        }

        AlphaDocumentKind.Image -> {
            val bitmap = runCatching { android.graphics.BitmapFactory.decodeFile(file.absolutePath) }.getOrNull()
            if (bitmap == null) {
                listOf(
                    AlphaPageAcquisition(
                        pageNumber = 1,
                        text = null,
                        snippet = "Imported image page. OCR could not run locally.",
                        anchorText = null,
                        ocrConfidence = null,
                        ocrStatus = AlphaOcrStatus.Failed,
                        indexingStatus = AlphaIndexingStatus.Failed,
                    )
                )
            } else {
                val text = recognizeBitmap(bitmap)
                listOf(
                    AlphaPageAcquisition(
                        pageNumber = 1,
                        text = text.ifBlank { null },
                        snippet = compactSnippet(text),
                        anchorText = compactSnippet(text),
                        ocrConfidence = if (text.isBlank()) null else 0.78,
                        ocrStatus = if (text.isBlank()) AlphaOcrStatus.Failed else AlphaOcrStatus.OcrComplete,
                        indexingStatus = if (text.isBlank()) AlphaIndexingStatus.Failed else AlphaIndexingStatus.Indexed,
                    )
                )
            }
        }

        AlphaDocumentKind.Pdf -> {
            val pages = mutableListOf<AlphaPageAcquisition>()
            runCatching {
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                    PdfRenderer(descriptor).use { renderer ->
                        for (index in 0 until renderer.pageCount) {
                            renderer.openPage(index).use { page ->
                                val bitmap = Bitmap.createBitmap(
                                    (page.width * 1.5f).toInt().coerceAtLeast(1),
                                    (page.height * 1.5f).toInt().coerceAtLeast(1),
                                    Bitmap.Config.ARGB_8888,
                                )
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val text = recognizeBitmap(bitmap)
                                pages += AlphaPageAcquisition(
                                    pageNumber = index + 1,
                                    text = text.ifBlank { null },
                                    snippet = compactSnippet(text).ifBlankFallback("Imported page ${index + 1}."),
                                    anchorText = compactSnippet(text),
                                    ocrConfidence = if (text.isBlank()) null else 0.72,
                                    ocrStatus = when {
                                        text.isBlank() -> AlphaOcrStatus.Partial
                                        else -> AlphaOcrStatus.OcrComplete
                                    },
                                    indexingStatus = when {
                                        text.isBlank() -> AlphaIndexingStatus.Partial
                                        else -> AlphaIndexingStatus.Indexed
                                    },
                                )
                            }
                        }
                    }
                }
            }
            if (pages.isEmpty()) {
                listOf(
                    AlphaPageAcquisition(
                        pageNumber = 1,
                        text = null,
                        snippet = "PDF imported locally. OCR could not run on this file.",
                        anchorText = null,
                        ocrConfidence = null,
                        ocrStatus = AlphaOcrStatus.Failed,
                        indexingStatus = AlphaIndexingStatus.Failed,
                    )
                )
            } else {
                pages
            }
        }

        AlphaDocumentKind.Unknown -> listOf(
            AlphaPageAcquisition(
                pageNumber = 1,
                text = null,
                snippet = "Imported source reference.",
                anchorText = null,
                ocrConfidence = null,
                ocrStatus = AlphaOcrStatus.Placeholder,
                indexingStatus = AlphaIndexingStatus.NotStarted,
            )
        )
    }

    private suspend fun recognizeBitmap(bitmap: Bitmap): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val image = InputImage.fromBitmap(bitmap, 0)
        return runCatching {
            recognizer.process(image).await().text.orEmpty().trim()
        }.getOrDefault("")
    }

    private fun detectLanguageProfile(
        documentId: String,
        pages: List<AlphaPageAcquisition>,
    ): AlphaDocumentLanguageProfile = AlphaLanguageHeuristics.detectProfile(
        documentId = documentId,
        pageTexts = pages.map { it.pageNumber to it.text.orEmpty() },
    )

    private fun classifyDocument(
        document: AlphaCaseDocument,
        pages: List<AlphaPageAcquisition>,
        languageProfile: AlphaDocumentLanguageProfile,
    ): AlphaLegalDocumentClassification {
        val joined = pages.joinToString("\n") { it.text.orEmpty() }.lowercase()
        val type = when {
            "affidavit" in joined || "solemnly affirm" in joined -> AlphaLegalDocumentType.Affidavit
            "judgment" in joined || "coram" in joined || "hon'ble" in joined -> AlphaLegalDocumentType.Judgment
            "show cause notice" in joined || "legal notice" in joined || "notice" in joined -> AlphaLegalDocumentType.Notice
            "exhibit" in joined || "annexure" in joined -> AlphaLegalDocumentType.Evidence
            "dear sir" in joined || "subject:" in joined -> AlphaLegalDocumentType.Correspondence
            "petition" in joined || "plaint" in joined || "written statement" in joined -> AlphaLegalDocumentType.Pleading
            "order" in joined || "it is directed" in joined || "listed on" in joined -> AlphaLegalDocumentType.Order
            else -> AlphaLegalDocumentType.Misc
        }
        val confidence = when (type) {
            AlphaLegalDocumentType.Misc -> 0.48
            else -> 0.78
        }
        return AlphaLegalDocumentClassification(
            documentId = document.id,
            type = type,
            subtype = if (type == AlphaLegalDocumentType.Pleading && languageProfile.primaryLanguage == AlphaDocumentLanguage.Mixed) {
                "bilingual_pleading"
            } else {
                null
            },
            confidence = confidence,
            sourceRefs = pages.take(2).map { page -> sourceRefForPage(document, page.pageNumber, page.snippet, page.ocrConfidence) },
            needsReview = confidence < 0.66 || languageProfile.primaryLanguage == AlphaDocumentLanguage.Mixed,
        )
    }

    private fun extractFields(
        caseId: String,
        document: AlphaCaseDocument,
        pages: List<AlphaPageAcquisition>,
        languageProfile: AlphaDocumentLanguageProfile,
        classification: AlphaLegalDocumentClassification,
        mode: AlphaExtractionMode,
    ): List<AlphaExtractedLegalField> {
        val fields = mutableListOf<AlphaExtractedLegalField>()
        val seen = linkedSetOf<String>()
        pages.forEach { page ->
            val sourceRef = sourceRefForPage(document, page.pageNumber, page.snippet, page.ocrConfidence, caseId)
            extractCaseNumbers(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.CaseNumber, "Case number", value, value, 0.84, AlphaExtractionPass.Regex, index)
            }
            extractCourts(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.Court, "Court", value, value, 0.8, AlphaExtractionPass.Regex, index)
            }
            extractDates(page.text.orEmpty()).forEachIndexed { index, date ->
                val type = if (date.isNextDate) AlphaExtractedLegalFieldType.NextDate else AlphaExtractedLegalFieldType.Date
                addField(fields, seen, caseId, document.id, mode, sourceRef, type, if (type == AlphaExtractedLegalFieldType.NextDate) "Next date" else "Date", date.original, date.normalized, 0.8, AlphaExtractionPass.Regex, index)
            }
            extractParties(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.PartyName, "Party", value, normalizeMatch(value), 0.76, AlphaExtractionPass.Regex, index)
            }
            extractSections(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.Section, "Section", value, normalizeMatch(value), 0.74, AlphaExtractionPass.Regex, index)
            }
            extractExhibits(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.ExhibitNumber, "Exhibit", value, normalizeMatch(value), 0.72, AlphaExtractionPass.Regex, index)
            }
            extractAmounts(page.text.orEmpty()).forEachIndexed { index, value ->
                addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.Amount, "Amount", value, normalizeMatch(value), 0.68, AlphaExtractionPass.Regex, index)
            }
            if (mode != AlphaExtractionMode.Basic) {
                extractIssues(page.text.orEmpty()).forEachIndexed { index, value ->
                    addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.Issue, "Issue", value, normalizeMatch(value), if (mode == AlphaExtractionMode.QuickStart) 0.58 else 0.68, AlphaExtractionPass.LlmExtract, index)
                }
                extractOrderDirections(page.text.orEmpty()).forEachIndexed { index, value ->
                    addField(fields, seen, caseId, document.id, mode, sourceRef, AlphaExtractedLegalFieldType.OrderDirection, "Order direction", value, normalizeMatch(value), if (classification.type == AlphaLegalDocumentType.Order) 0.74 else 0.62, AlphaExtractionPass.LlmExtract, index)
                }
                extractReliefs(page.text.orEmpty()).forEachIndexed { index, value ->
                    val type = if (value.lowercase().contains("prayer")) AlphaExtractedLegalFieldType.Prayer else AlphaExtractedLegalFieldType.Relief
                    addField(fields, seen, caseId, document.id, mode, sourceRef, type, if (type == AlphaExtractedLegalFieldType.Prayer) "Prayer" else "Relief", value, normalizeMatch(value), 0.64, AlphaExtractionPass.LlmExtract, index)
                }
            }
        }
        return fields.map { field ->
            field.copy(
                confidence = scoreFieldConfidence(field.confidence, field.sourceRefs.firstOrNull()?.ocrConfidence, languageProfile.confidence, field.extractionPass == AlphaExtractionPass.LlmVerify),
                needsReview = field.confidence < 0.64 || field.sourceRefs.isEmpty(),
            )
        }
    }

    private fun verifyFields(
        caseId: String,
        document: AlphaCaseDocument,
        pages: List<AlphaPageAcquisition>,
        fields: List<AlphaExtractedLegalField>,
    ): VerificationBundle {
        val findings = mutableListOf<AlphaExtractionFinding>()
        val verified = fields.map { field ->
            val supported = field.sourceRefs.any { ref ->
                pages.firstOrNull { it.pageNumber == ref.pageNumber }?.let { page ->
                    normalizeMatch(page.text.orEmpty()).contains(field.normalizedValue ?: normalizeMatch(field.value))
                } ?: false
            }
            if (!supported) {
                findings += AlphaExtractionFinding(
                    caseId = caseId,
                    documentId = document.id,
                    kind = if (field.fieldType == AlphaExtractedLegalFieldType.OrderDirection) AlphaExtractionFindingKind.AmbiguousOrderDirection else AlphaExtractionFindingKind.UnsupportedLayout,
                    message = "${field.label} needs review because Ross could not confirm it against the cited page text.",
                    sourceRefs = field.sourceRefs,
                    severity = AlphaExtractionFindingSeverity.Warning,
                )
                field.copy(needsReview = true, confidence = (field.confidence - 0.24).coerceAtLeast(0.08))
            } else if (field.extractionPass == AlphaExtractionPass.LlmExtract) {
                field.copy(extractionPass = AlphaExtractionPass.LlmVerify, confidence = (field.confidence + 0.1).coerceAtMost(0.96))
            } else {
                field
            }
        }
        findings += conflictFindings(caseId, document.id, verified)
        return VerificationBundle(verified, findings)
    }

    private fun baseFindings(
        caseId: String,
        documentId: String,
        pages: List<AlphaPageAcquisition>,
        languageProfile: AlphaDocumentLanguageProfile,
    ): List<AlphaExtractionFinding> {
        val findings = mutableListOf<AlphaExtractionFinding>()
        if (languageProfile.primaryLanguage == AlphaDocumentLanguage.Mixed || languageProfile.confidence < 0.62) {
            findings += AlphaExtractionFinding(
                caseId = caseId,
                documentId = documentId,
                kind = AlphaExtractionFindingKind.LanguageUncertain,
                message = "Ross detected mixed or uncertain language/script content. Review bilingual fields carefully.",
                sourceRefs = pages.take(2).map { page -> AlphaSourceRef(caseId = caseId, documentId = documentId, documentTitle = "Imported document", pageNumber = page.pageNumber, textSnippet = page.snippet, ocrConfidence = page.ocrConfidence) },
                severity = AlphaExtractionFindingSeverity.Warning,
            )
        }
        pages.firstOrNull { (it.ocrConfidence ?: 0.8) < 0.58 }?.let { page ->
            findings += AlphaExtractionFinding(
                caseId = caseId,
                documentId = documentId,
                kind = AlphaExtractionFindingKind.LowConfidenceOcr,
                message = "Ross detected a low-confidence scan on at least one page. Review uncertain fields before relying on them.",
                sourceRefs = listOf(AlphaSourceRef(caseId = caseId, documentId = documentId, documentTitle = "Imported document", pageNumber = page.pageNumber, textSnippet = page.snippet, ocrConfidence = page.ocrConfidence)),
                severity = AlphaExtractionFindingSeverity.Warning,
            )
        }
        return findings
    }

    private fun buildCaseMemory(
        caseId: String,
        documentId: String,
        classification: AlphaLegalDocumentClassification,
        fields: List<AlphaExtractedLegalField>,
    ): List<AlphaCaseMemoryUpdate> {
        val parties = fields.filter { it.fieldType == AlphaExtractedLegalFieldType.PartyName }.joinToString(" | ") { it.value }.ifBlank { "Not found" }
        val dates = fields.filter { it.fieldType == AlphaExtractedLegalFieldType.Date }.joinToString(" | ") { it.value }.ifBlank { "Not found" }
        val nextDate = fields.filter { it.fieldType == AlphaExtractedLegalFieldType.NextDate }.joinToString(" | ") { it.value }.ifBlank { "Not found" }
        val directions = fields.filter { it.fieldType == AlphaExtractedLegalFieldType.OrderDirection }.joinToString(" | ") { it.value }.ifBlank { "Not found" }
        val issues = fields.filter { it.fieldType == AlphaExtractedLegalFieldType.Issue }.joinToString(" | ") { it.value }.ifBlank { "Not found" }

        return buildList {
            add(
                AlphaCaseMemoryUpdate(
                    caseId = caseId,
                    source = AlphaCaseMemoryUpdateSource.ExtractionRun,
                    summary = "Document classified as ${classification.type.name}. Parties: $parties. Important dates: $dates.",
                    affectedDocuments = listOf(documentId),
                )
            )
            if (directions != "Not found" || nextDate != "Not found") {
                add(
                    AlphaCaseMemoryUpdate(
                        caseId = caseId,
                        source = AlphaCaseMemoryUpdateSource.ExtractionRun,
                        summary = "Order and compliance candidate. Next date: $nextDate. Directions: $directions.",
                        affectedDocuments = listOf(documentId),
                    )
                )
            }
            if (issues != "Not found") {
                add(
                    AlphaCaseMemoryUpdate(
                        caseId = caseId,
                        source = AlphaCaseMemoryUpdateSource.ExtractionRun,
                        summary = "Issue candidate: $issues.",
                        affectedDocuments = listOf(documentId),
                    )
                )
            }
        }
    }

    private fun addField(
        fields: MutableList<AlphaExtractedLegalField>,
        seen: MutableSet<String>,
        caseId: String,
        documentId: String,
        mode: AlphaExtractionMode,
        sourceRef: AlphaSourceRef,
        type: AlphaExtractedLegalFieldType,
        label: String,
        value: String,
        normalizedValue: String?,
        confidence: Double,
        pass: AlphaExtractionPass,
        ordinal: Int,
    ) {
        val cleaned = value.trim()
        if (cleaned.isEmpty()) return
        val dedupe = "${type.name}:${normalizedValue ?: normalizeMatch(cleaned)}"
        if (!seen.add(dedupe)) return
        fields += AlphaExtractedLegalField(
            id = "$documentId-${type.name.lowercase()}-${sourceRef.pageNumber}-$ordinal",
            caseId = caseId,
            documentId = documentId,
            fieldType = type,
            label = label,
            value = cleaned,
            normalizedValue = normalizedValue,
            sourceRefs = listOf(sourceRef.copy(textSnippet = sourceRef.textSnippet ?: compactSnippet(cleaned))),
            confidence = confidence,
            extractionMode = mode,
            extractionPass = pass,
            needsReview = confidence < 0.64,
        )
    }

    private fun sourceRefForPage(
        document: AlphaCaseDocument,
        pageNumber: Int,
        snippet: String?,
        confidence: Double?,
        caseId: String = "",
    ) = AlphaSourceRef(
        caseId = caseId.ifBlank { "case-local" },
        documentId = document.id,
        documentTitle = document.title,
        pageNumber = pageNumber,
        textSnippet = snippet,
        ocrConfidence = confidence,
    )

    private data class DateMatch(val original: String, val normalized: String, val isNextDate: Boolean)
    private data class VerificationBundle(val fields: List<AlphaExtractedLegalField>, val findings: List<AlphaExtractionFinding>)

    private fun extractCaseNumbers(text: String): List<String> {
        val matches = CASE_NUMBER_REGEX.findAll(text).map { it.value.trim() }.toList()
        if (matches.isNotEmpty()) return matches.take(3)
        return text.lines()
            .map { it.trim() }
            .filter { line -> line.contains('/') && line.any { ch -> ch.isUpperCase() } }
            .take(3)
    }

    private fun extractCourts(text: String): List<String> = text.lines()
        .map { it.trim() }
        .filter { line ->
            val lowered = line.lowercase()
            "court" in lowered || "tribunal" in lowered || "commission" in lowered
        }
        .take(3)

    private fun extractDates(text: String): List<DateMatch> {
        val matches = mutableListOf<DateMatch>()
        text.lines().forEach { line ->
            val normalizedLine = normalizeOcrDigits(line)
            DATE_REGEX.findAll(normalizedLine).forEach { match ->
                val prefix = normalizedLine.substring(0, match.range.first).lowercase()
                matches += DateMatch(
                    original = match.value.trim(),
                    normalized = match.value.replace('.', '/').replace('-', '/').replace(" ", ""),
                    isNextDate = "next date" in prefix || "listed on" in prefix,
                )
            }
        }
        return matches.take(6)
    }

    private fun extractSections(text: String): List<String> =
        SECTION_REGEX.findAll(text).map { it.value.trim() }.take(8).toList()

    private fun extractExhibits(text: String): List<String> =
        EXHIBIT_REGEX.findAll(text).map { it.value.trim() }.take(8).toList()

    private fun extractParties(text: String): List<String> {
        text.lines().map { it.trim() }.forEach { line ->
            val lowered = line.lowercase()
            val separator = when {
                " versus " in lowered -> "versus"
                " vs " in lowered -> "vs"
                " v. " in lowered -> "v."
                else -> null
            }
            if (separator != null) {
                return line.split(separator).map { it.trim().trim(':', '-') }.filter { it.isNotEmpty() }.take(4)
            }
        }
        return emptyList()
    }

    private fun extractAmounts(text: String): List<String> =
        AMOUNT_REGEX.findAll(text).map { it.value.trim() }.take(5).toList()

    private fun extractIssues(text: String): List<String> = text.lines()
        .map { it.trim() }
        .filter { line ->
            val lowered = line.lowercase()
            lowered.startsWith("issue") || lowered.startsWith("whether") || lowered.contains("point for consideration")
        }
        .take(4)

    private fun extractOrderDirections(text: String): List<String> = text.lines()
        .map { it.trim() }
        .filter { line ->
            val lowered = line.lowercase()
            lowered.contains("it is directed") ||
                lowered.contains("shall") ||
                lowered.contains("listed on") ||
                lowered.contains("next date") ||
                lowered.contains("compliance")
        }
        .take(5)

    private fun extractReliefs(text: String): List<String> = text.lines()
        .map { it.trim() }
        .filter { line ->
            val lowered = line.lowercase()
            lowered.startsWith("prayer") || lowered.contains("it is therefore prayed") || lowered.contains("relief sought")
        }
        .take(4)

    private fun conflictFindings(
        caseId: String,
        documentId: String,
        fields: List<AlphaExtractedLegalField>,
    ): List<AlphaExtractionFinding> = buildList {
        addAll(conflictFinding(caseId, documentId, fields, AlphaExtractedLegalFieldType.CaseNumber, AlphaExtractionFindingKind.CaseNumberConflict, "Ross found multiple competing case numbers. Review the supported value."))
        addAll(conflictFinding(caseId, documentId, fields, AlphaExtractedLegalFieldType.Date, AlphaExtractionFindingKind.DateConflict, "Ross found multiple important dates that may conflict. Review the supported source pages."))
        addAll(conflictFinding(caseId, documentId, fields, AlphaExtractedLegalFieldType.PartyName, AlphaExtractionFindingKind.PartyConflict, "Ross found party naming variation that needs advocate review."))
    }

    private fun conflictFinding(
        caseId: String,
        documentId: String,
        fields: List<AlphaExtractedLegalField>,
        type: AlphaExtractedLegalFieldType,
        kind: AlphaExtractionFindingKind,
        message: String,
    ): List<AlphaExtractionFinding> {
        val relevant = fields.filter { it.fieldType == type }
        val unique = relevant.map { it.normalizedValue ?: normalizeMatch(it.value) }.toSet()
        return if (relevant.size > 1 && unique.size > 1) {
            listOf(
                AlphaExtractionFinding(
                    caseId = caseId,
                    documentId = documentId,
                    kind = kind,
                    message = message,
                    sourceRefs = relevant.flatMap { it.sourceRefs }.take(4),
                    severity = AlphaExtractionFindingSeverity.Warning,
                )
            )
        } else {
            emptyList()
        }
    }
}

private fun scoreFieldConfidence(
    evidenceStrength: Double,
    sourceQuality: Double?,
    languageConfidence: Double,
    verified: Boolean,
): Double {
    val verificationBonus = if (verified) 0.12 else -0.06
    return (evidenceStrength * 0.45 + (sourceQuality ?: 0.56) * 0.35 + languageConfidence * 0.2 + verificationBonus)
        .coerceIn(0.05, 0.98)
}

private fun normalizeOcrDigits(value: String): String = buildString {
    value.forEach { ch ->
        append(
            when (ch) {
                'O', 'o' -> '0'
                'I', 'l', '|' -> '1'
                else -> ch
            }
        )
    }
}

private fun normalizeMatch(value: String): String =
    normalizeOcrDigits(value)
        .lowercase()
        .map { ch -> if (ch.isLetterOrDigit()) ch else ' ' }
        .joinToString("")
        .split(Regex("\\s+"))
        .filter { it.isNotBlank() }
        .joinToString(" ")

private fun compactSnippet(value: String?): String? =
    value
        ?.replace(Regex("\\s+"), " ")
        ?.trim()
        ?.takeIf { it.isNotBlank() }
        ?.take(180)

private fun String?.ifBlankFallback(fallback: String): String =
    if (this.isNullOrBlank()) fallback else this

private fun scriptCounts(value: String): Triple<Int, Int, Int> {
    var latin = 0
    var devanagari = 0
    var other = 0
    value.forEach { ch ->
        when {
            ch.isLetter() && ch.code < 128 -> latin += 1
            ch in '\u0900'..'\u097F' || ch in '\uA8E0'..'\uA8FF' -> devanagari += 1
            ch.isLetter() -> other += 1
        }
    }
    return Triple(latin, devanagari, other)
}

private val CASE_NUMBER_REGEX = Regex(
    pattern = """\b((?:[A-Z]{1,10}(?:\([A-Z]+\))?|W\.?P\.?|C\.?S\.?|M\.?A\.?|OA|Case|Petition|Appeal|Application|Suit)\s*(?:No\.?|Number)?\s*[:.-]?\s*[A-Z0-9./() -]{1,30}\d{1,8}/\d{2,4}|[A-Z]{2,12}/\d{1,8}/\d{4})\b""",
    option = RegexOption.IGNORE_CASE,
)
private val DATE_REGEX = Regex(
    pattern = """\b(\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{2,4})\b""",
    options = setOf(RegexOption.IGNORE_CASE),
)
private val SECTION_REGEX = Regex("""\b(?:section|sections|u/s|under section)\s+[0-9A-Za-z/(), -]{1,40}""", RegexOption.IGNORE_CASE)
private val EXHIBIT_REGEX = Regex("""\b(?:exhibit|ex\.?|annexure)\s+[A-Za-z0-9/-]{1,20}""", RegexOption.IGNORE_CASE)
private val AMOUNT_REGEX = Regex("""(?:₹|rs\.?|inr)\s*[\d,]+(?:\.\d{2})?""", RegexOption.IGNORE_CASE)
