package com.ross.android.alpha

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlphaExtractionTest {
    private val gson = Gson()

    @Test
    fun `extraction mode gating follows installed pack capability`() {
        assertEquals(AlphaExtractionMode.Basic, AlphaExtractionMode.fromTier(null))
        assertEquals(AlphaExtractionMode.QuickStart, AlphaExtractionMode.fromTier(AlphaCapabilityTier.QuickStart))
        assertEquals(AlphaExtractionMode.CaseAssociate, AlphaExtractionMode.fromTier(AlphaCapabilityTier.CaseAssociate))
        assertEquals(AlphaExtractionMode.SeniorDraftingSupport, AlphaExtractionMode.fromTier(AlphaCapabilityTier.SeniorDraftingSupport))
    }

    @Test
    fun `language heuristic detects hindi and mixed pages`() {
        val hindi = AlphaLanguageHeuristics.detectProfile(
            documentId = "doc-1",
            pageTexts = listOf(1 to "यह एक अंतरिम आदेश है। अगली सुनवाई 12/05/2026 है।"),
        )
        val mixed = AlphaLanguageHeuristics.detectProfile(
            documentId = "doc-2",
            pageTexts = listOf(1 to "Order dated 12/05/2026. अगली सुनवाई 14/06/2026 है।"),
        )

        assertEquals(AlphaDocumentLanguage.Hindi, hindi.primaryLanguage)
        assertEquals(AlphaDocumentLanguage.Mixed, mixed.primaryLanguage)
        assertTrue(mixed.scriptsDetected.contains("latin"))
        assertTrue(mixed.scriptsDetected.contains("devanagari"))
    }

    @Test
    fun `extracted fields persist through gson`() {
        val document = AlphaCaseDocument(
            id = "doc-1",
            title = "Impugned Order",
            fileName = "order.pdf",
            kind = AlphaDocumentKind.Pdf,
            storedRelativePath = "documents/doc-1/order.pdf",
            pageCount = 2,
            ocrStatus = AlphaOcrStatus.OcrComplete,
            pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "order page 1")),
            extractedFields = listOf(
                AlphaExtractedLegalField(
                    id = "field-1",
                    caseId = "case-1",
                    documentId = "doc-1",
                    fieldType = AlphaExtractedLegalFieldType.CaseNumber,
                    label = "Case number",
                    value = "CS(COMM) 245/2026",
                    normalizedValue = "cs comm 245 2026",
                    sourceRefs = listOf(
                        AlphaSourceRef(
                            caseId = "case-1",
                            documentId = "doc-1",
                            documentTitle = "Impugned Order",
                            pageNumber = 1,
                            textSnippet = "CS(COMM) 245/2026",
                            ocrConfidence = 0.82,
                        )
                    ),
                    confidence = 0.82,
                    extractionMode = AlphaExtractionMode.CaseAssociate,
                    extractionPass = AlphaExtractionPass.Regex,
                    needsReview = false,
                )
            ),
        )

        val encoded = gson.toJson(document)
        val decoded = gson.fromJson(encoded, AlphaCaseDocument::class.java)

        assertEquals(1, decoded.extractedFields.size)
        assertEquals("CS(COMM) 245/2026", decoded.extractedFields.first().value)
    }

    @Test
    fun `review queue keeps only uncertain fields and unresolved findings`() {
        val queue = AlphaReviewQueues.build(
            fields = listOf(
                AlphaExtractedLegalField(
                    caseId = "case-1",
                    documentId = "doc-1",
                    fieldType = AlphaExtractedLegalFieldType.CaseNumber,
                    label = "Case number",
                    value = "CS(COMM) 245/2026",
                    sourceRefs = listOf(
                        AlphaSourceRef(
                            caseId = "case-1",
                            documentId = "doc-1",
                            documentTitle = "Order",
                            pageNumber = 1,
                        )
                    ),
                    confidence = 0.88,
                    extractionMode = AlphaExtractionMode.CaseAssociate,
                    extractionPass = AlphaExtractionPass.Regex,
                    needsReview = false,
                ),
                AlphaExtractedLegalField(
                    caseId = "case-1",
                    documentId = "doc-1",
                    fieldType = AlphaExtractedLegalFieldType.OrderDirection,
                    label = "Order direction",
                    value = "Respondent shall file a reply within two weeks.",
                    sourceRefs = listOf(
                        AlphaSourceRef(
                            caseId = "case-1",
                            documentId = "doc-1",
                            documentTitle = "Order",
                            pageNumber = 2,
                        )
                    ),
                    confidence = 0.41,
                    extractionMode = AlphaExtractionMode.CaseAssociate,
                    extractionPass = AlphaExtractionPass.LlmExtract,
                    needsReview = true,
                ),
            ),
            findings = listOf(
                AlphaExtractionFinding(
                    caseId = "case-1",
                    documentId = "doc-1",
                    kind = AlphaExtractionFindingKind.LanguageUncertain,
                    message = "Mixed language detected.",
                    sourceRefs = emptyList(),
                    severity = AlphaExtractionFindingSeverity.Warning,
                    resolved = false,
                )
            ),
        )

        assertEquals(1, queue.fieldIds.size)
        assertEquals(1, queue.findingIds.size)
        assertTrue(queue.summary.contains("Please review the uncertain ones"))
    }

    @Test
    fun `blank public law preview falls back to extracted legal query`() {
        val case = AlphaCaseMatter(
            id = "case-1",
            title = "Private Matter",
            forum = "Forum",
            stage = AlphaCaseStage.Pleadings,
            summary = "summary",
            issueHighlights = emptyList(),
            evidenceNotes = emptyList(),
            draftTasks = emptyList(),
            documents = listOf(
                AlphaCaseDocument(
                    id = "doc-1",
                    title = "Order",
                    fileName = "order.pdf",
                    kind = AlphaDocumentKind.Pdf,
                    storedRelativePath = "documents/order.pdf",
                    pageCount = 1,
                    ocrStatus = AlphaOcrStatus.OcrComplete,
                    pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                    classification = AlphaLegalDocumentClassification(
                        documentId = "doc-1",
                        type = AlphaLegalDocumentType.Order,
                        confidence = 0.82,
                        sourceRefs = emptyList(),
                        needsReview = false,
                    ),
                    extractedFields = listOf(
                        AlphaExtractedLegalField(
                            caseId = "case-1",
                            documentId = "doc-1",
                            fieldType = AlphaExtractedLegalFieldType.Issue,
                            label = "Issue",
                            value = "delay in filing written statement",
                            sourceRefs = listOf(
                                AlphaSourceRef(caseId = "case-1", documentId = "doc-1", documentTitle = "Order", pageNumber = 1)
                            ),
                            confidence = 0.8,
                            extractionMode = AlphaExtractionMode.CaseAssociate,
                            extractionPass = AlphaExtractionPass.LlmVerify,
                            needsReview = false,
                        ),
                        AlphaExtractedLegalField(
                            caseId = "case-1",
                            documentId = "doc-1",
                            fieldType = AlphaExtractedLegalFieldType.Section,
                            label = "Section",
                            value = "Commercial Courts Act",
                            sourceRefs = listOf(
                                AlphaSourceRef(caseId = "case-1", documentId = "doc-1", documentTitle = "Order", pageNumber = 1)
                            ),
                            confidence = 0.81,
                            extractionMode = AlphaExtractionMode.CaseAssociate,
                            extractionPass = AlphaExtractionPass.Regex,
                            needsReview = false,
                        ),
                    ),
                )
            ),
            sourceRefs = emptyList(),
        )

        val preview = AlphaPayloadShaper.buildPublicLawPreview("", case)

        assertTrue(preview.query.contains("delay in filing written statement", ignoreCase = true))
        assertTrue(preview.query.contains("Commercial Courts Act", ignoreCase = true))
        assertFalse(preview.query.contains("Private Matter", ignoreCase = true))
    }
}
