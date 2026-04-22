package com.ross.android.alpha

import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlphaPayloadsTest {
    private val gson = Gson()

    @Test
    fun `public law preview strips case details and fake secrets`() {
        val case = AlphaCaseMatter(
            title = "Kaveri Developers v. South Ward Municipal Corporation",
            forum = "Karnataka High Court",
            stage = AlphaCaseStage.Pleadings,
            summary = "summary",
            issueHighlights = emptyList(),
            evidenceNotes = emptyList(),
            draftTasks = emptyList(),
            documents = listOf(
                AlphaCaseDocument(
                    title = "Private Bundle",
                    fileName = "private-bundle.pdf",
                    kind = AlphaDocumentKind.Pdf,
                    storedRelativePath = "docs/private-bundle.pdf",
                    pageCount = 2,
                    ocrStatus = AlphaOcrStatus.Placeholder,
                    pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                )
            ),
            sourceRefs = emptyList(),
        )

        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "Find guidance for Kaveri Developers v. South Ward Municipal Corporation on 9876501234 at fakepriv@example.com from private-bundle.pdf and FAKE/123/2026",
            case = case,
        )

        assertFalse(preview.query.contains("Kaveri Developers", ignoreCase = true))
        assertFalse(preview.query.contains("9876501234"))
        assertFalse(preview.query.contains("fakepriv@example.com", ignoreCase = true))
        assertFalse(preview.query.contains("private-bundle.pdf", ignoreCase = true))
        assertTrue(preview.removed.isNotEmpty())
    }

    @Test
    fun `model catalog and download payloads never contain fake secrets`() {
        val state = AlphaPersistedState(
            cases = listOf(
                AlphaCaseMatter(
                    title = "Raghav Fakepriv",
                    forum = "Forum pending",
                    stage = AlphaCaseStage.Intake,
                    summary = "Call 9876501234 or fakepriv@example.com about blue suitcase near temple.",
                    issueHighlights = listOf("FAKE/123/2026"),
                    evidenceNotes = listOf("blue suitcase near temple"),
                    draftTasks = emptyList(),
                    documents = listOf(
                        AlphaCaseDocument(
                            title = "Confidential Note",
                            fileName = "confidential-note.txt",
                            kind = AlphaDocumentKind.Text,
                            storedRelativePath = "documents/confidential-note.txt",
                            pageCount = 1,
                            ocrStatus = AlphaOcrStatus.Indexed,
                            extractedText = "blue suitcase near temple",
                            pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                        )
                    ),
                    sourceRefs = emptyList(),
                )
            )
        )
        val job = AlphaModelDownloadJob(
            sessionId = "mdl-session",
            packId = "case-associate-pack",
            tier = AlphaCapabilityTier.CaseAssociate,
            state = AlphaDownloadState.Downloading,
            networkPolicy = AlphaDownloadPolicy.WifiOnly,
            bytesDownloaded = 8192,
            totalBytes = 16384,
            checksumSha256 = "abcd1234",
        )

        val catalogJson = gson.toJson(AlphaPayloadShaper.buildModelCatalogPayload(state))
        val downloadJson = gson.toJson(AlphaPayloadShaper.buildModelDownloadPayload(job))

        listOf(
            "Raghav Fakepriv",
            "9876501234",
            "fakepriv@example.com",
            "FAKE/123/2026",
            "blue suitcase near temple",
            "Confidential Note",
            "confidential-note.txt",
        ).forEach { secret ->
            assertFalse(catalogJson.contains(secret, ignoreCase = true))
            assertFalse(downloadJson.contains(secret, ignoreCase = true))
        }
    }

    @Test
    fun `verified fields drive public law suggestions without private facts`() {
        val caseId = "case-public-law"
        val documentId = "doc-public-law"
        val case = AlphaCaseMatter(
            title = "Raghav Fakepriv v. Private Matter",
            forum = "Forum pending",
            stage = AlphaCaseStage.Pleadings,
            summary = "summary",
            issueHighlights = emptyList(),
            evidenceNotes = listOf("blue suitcase near temple"),
            draftTasks = emptyList(),
            documents = listOf(
                AlphaCaseDocument(
                    id = documentId,
                    title = "Order",
                    fileName = "order.pdf",
                    kind = AlphaDocumentKind.Pdf,
                    storedRelativePath = "docs/order.pdf",
                    pageCount = 1,
                    ocrStatus = AlphaOcrStatus.Placeholder,
                    classification = AlphaLegalDocumentClassification(
                        documentId = documentId,
                        type = AlphaLegalDocumentType.Order,
                        confidence = 0.82,
                        sourceRefs = emptyList(),
                        needsReview = false,
                    ),
                    extractedFields = listOf(
                        AlphaExtractedLegalField(
                            caseId = caseId,
                            documentId = documentId,
                            fieldType = AlphaExtractedLegalFieldType.Section,
                            label = "Section",
                            value = "Section 138 cheque dishonour notice limitation",
                            sourceRefs = listOf(AlphaSourceRef(caseId = caseId, documentId = documentId, documentTitle = "Order", pageNumber = 1)),
                            confidence = 0.88,
                            extractionMode = AlphaExtractionMode.CaseAssociate,
                            extractionPass = AlphaExtractionPass.LlmVerify,
                            needsReview = false,
                        ),
                        AlphaExtractedLegalField(
                            caseId = caseId,
                            documentId = documentId,
                            fieldType = AlphaExtractedLegalFieldType.Issue,
                            label = "Issue",
                            value = "blue suitcase near temple",
                            sourceRefs = listOf(AlphaSourceRef(caseId = caseId, documentId = documentId, documentTitle = "Order", pageNumber = 1)),
                            confidence = 0.92,
                            extractionMode = AlphaExtractionMode.CaseAssociate,
                            extractionPass = AlphaExtractionPass.LlmVerify,
                            needsReview = false,
                        ),
                        AlphaExtractedLegalField(
                            caseId = caseId,
                            documentId = documentId,
                            fieldType = AlphaExtractedLegalFieldType.PartyName,
                            label = "Party",
                            value = "Raghav Fakepriv",
                            sourceRefs = listOf(AlphaSourceRef(caseId = caseId, documentId = documentId, documentTitle = "Order", pageNumber = 1)),
                            confidence = 0.92,
                            extractionMode = AlphaExtractionMode.CaseAssociate,
                            extractionPass = AlphaExtractionPass.LlmVerify,
                            needsReview = false,
                        ),
                    ),
                    pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                ),
            ),
            sourceRefs = emptyList(),
        )

        val preview = AlphaPayloadShaper.buildPublicLawPreview(rawQuery = "", case = case)

        assertTrue(preview.query.contains("Section 138", ignoreCase = true))
        assertTrue(preview.query.contains("dishonour", ignoreCase = true))
        assertFalse(preview.query.contains("Raghav Fakepriv", ignoreCase = true))
        assertFalse(preview.query.contains("blue suitcase near temple", ignoreCase = true))
        assertEquals(
            "Public-law search sends only a sanitized query after explicit confirmation.",
            preview.confirmationNote,
        )
    }

    @Test
    fun `generic morning question falls back to research anchored public law preview`() {
        val case = AlphaCaseMatter(
            title = "Demo Matter: Sharma v. Rana",
            forum = "District Court",
            stage = AlphaCaseStage.Arguments,
            nextHearing = "2026-05-01T10:00:00Z",
            summary = "summary",
            issueHighlights = emptyList(),
            evidenceNotes = emptyList(),
            draftTasks = emptyList(),
            documents = listOf(
                AlphaCaseDocument(
                    title = "Demo order",
                    fileName = "demo-order.pdf",
                    kind = AlphaDocumentKind.Pdf,
                    storedRelativePath = "docs/demo-order.pdf",
                    pageCount = 1,
                    ocrStatus = AlphaOcrStatus.Indexed,
                    classification = AlphaLegalDocumentClassification(
                        documentId = "doc-order",
                        type = AlphaLegalDocumentType.Order,
                        confidence = 0.88,
                        sourceRefs = emptyList(),
                        needsReview = false,
                    ),
                    pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                ),
                AlphaCaseDocument(
                    title = "Demo affidavit",
                    fileName = "demo-affidavit.pdf",
                    kind = AlphaDocumentKind.Pdf,
                    storedRelativePath = "docs/demo-affidavit.pdf",
                    pageCount = 1,
                    ocrStatus = AlphaOcrStatus.Indexed,
                    classification = AlphaLegalDocumentClassification(
                        documentId = "doc-affidavit",
                        type = AlphaLegalDocumentType.Affidavit,
                        confidence = 0.84,
                        sourceRefs = emptyList(),
                        needsReview = false,
                    ),
                    pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "snippet")),
                ),
            ),
            sourceRefs = emptyList(),
            dates = listOf(
                AlphaMatterDate(
                    caseId = "demo-case",
                    title = "Filing deadline",
                    kind = AlphaMatterDateKind.FilingDeadline,
                    date = "2026-04-24T10:00:00Z",
                ),
            ),
        )

        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "What needs my attention today?",
            case = case,
        )

        assertTrue(preview.query.contains("public law", ignoreCase = true))
        assertTrue(
            preview.query.contains("court procedure", ignoreCase = true) ||
                preview.query.contains("filing compliance", ignoreCase = true) ||
                preview.query.contains("hearing dates", ignoreCase = true),
        )
        assertFalse(preview.query.equals("order affidavit notice India", ignoreCase = true))
    }

    @Test
    fun `public law preview preserves legal citations and statutory time limits`() {
        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "Order 39 Rules 1 and 2 CPC temporary injunction, Section 138 NI Act notice limitation, Section 482 CrPC quashing FIR, Article 226 Constitution of India writ mandamus",
            case = null,
        )

        assertTrue(preview.query.contains("Order 39 Rules 1 and 2 CPC", ignoreCase = true))
        assertTrue(preview.query.contains("Section 138 NI Act", ignoreCase = true))
        assertTrue(preview.query.contains("Section 482 CrPC", ignoreCase = true))
        assertTrue(preview.query.contains("Article 226 Constitution of India", ignoreCase = true))

        val deadlinePreview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "delay filing written statement 120 days Commercial Courts Act",
            case = null,
        )

        assertTrue(deadlinePreview.query.contains("120 days Commercial Courts Act", ignoreCase = true))
    }

    @Test
    fun `public law preview strips exact dates and address-like private details`() {
        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "Find law on delay condonation for hearing fixed on 14 March 2026 at blue suitcase near temple and contact 9876501234",
            case = null,
        )

        assertFalse(preview.query.contains("14 March 2026", ignoreCase = true))
        assertFalse(preview.query.contains("blue suitcase near temple", ignoreCase = true))
        assertFalse(preview.query.contains("9876501234"))
        assertTrue(preview.query.contains("delay condonation", ignoreCase = true))
    }

    @Test
    fun `public law preview removes matter-scoped wording before confirmation`() {
        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "What should I do next for this matter about delay condonation and sufficient cause?",
            case = null,
        )

        assertFalse(preview.query.contains("what should i", ignoreCase = true))
        assertFalse(preview.query.contains("this matter", ignoreCase = true))
        assertTrue(preview.query.contains("delay condonation", ignoreCase = true))
        assertFalse(preview.removed.contains("No private case data detected"))
    }

    @Test
    fun `public law backend request always marks explicit confirmation`() {
        val preview = AlphaPayloadShaper.buildPublicLawPreview(
            rawQuery = "Find Section 138 cheque dishonour limitation law",
            case = null,
        )

        val request = AlphaPayloadShaper.buildPublicLawPayload(preview).toRequest()

        assertEquals(true, request.confirmedPublicPreview)
        assertEquals("IN-ALL", request.jurisdiction)
        assertEquals("en", request.language)
    }

    @Test
    fun `backend base url prefers canonical config name`() {
        val resolved = resolveRossBackendBaseUrl(
            overrideValue = null,
            systemPropertyValue = null,
            canonicalSystemPropertyValue = "http://127.0.0.1:8080",
            buildConfigValue = "",
        )

        assertEquals("http://127.0.0.1:8080", resolved)
    }

    @Test
    fun `backend base url override wins over other config`() {
        val resolved = resolveRossBackendBaseUrl(
            overrideValue = "http://10.0.2.2:8787",
            systemPropertyValue = "http://127.0.0.1:8080",
            canonicalSystemPropertyValue = "http://127.0.0.1:9090",
            buildConfigValue = "http://localhost:3000",
        )

        assertEquals("http://10.0.2.2:8787", resolved)
    }
}
