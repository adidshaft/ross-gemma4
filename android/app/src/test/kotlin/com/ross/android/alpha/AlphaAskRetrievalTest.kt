package com.ross.android.alpha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlphaAskRetrievalTest {
    @Test
    fun `selected long document can surface later relevant pages and chunk them`() {
        val document = document(
            id = "doc-long",
            title = "Interim Injunction Order",
            pages = listOf(
                page(1, "Introductory background only."),
                page(2, "Procedural history without the requested relief."),
                page(3, "Further background and appearances."),
                page(
                    4,
                    buildString {
                        repeat(30) {
                            append("The court discusses the temporary injunction factors, balance of convenience, and irreparable loss in detail. ")
                        }
                    },
                ),
                page(5, "Closing directions."),
            ),
        )

        val sourcePack = AlphaAskRetrieval.buildSourcePack(
            question = "What does the order say about temporary injunction?",
            candidateDocuments = listOf(caseMatter("case-1") to document),
            selectedDocumentIds = setOf(document.id),
            policy = AlphaAskSourcePackPolicy(
                sourceBlockLimit = 6,
                selectedDocumentPageLimit = 4,
                preferredChunkChars = 320,
                overlapChars = 40,
            ),
        )

        assertTrue(sourcePack.any { it.pageNumber == 4 })
        assertNotNull(sourcePack.firstOrNull { it.pageNumber == 4 }?.sourceRef?.paragraphRange)
    }

    @Test
    fun `unselected source pack balances top context across multiple documents`() {
        val question = "What does the record say about unpaid rent?"
        val documents = listOf(
            document(
                id = "doc-a",
                title = "Rent Notice",
                pages = listOf(
                    page(1, "Unpaid rent is alleged for January and February. The unpaid rent notice repeats the unpaid rent default."),
                    page(2, "Unpaid rent calculations continue for March. The unpaid rent ledger is attached."),
                ),
            ),
            document(
                id = "doc-b",
                title = "Ledger",
                pages = listOf(
                    page(1, "The ledger confirms unpaid rent and arrears. The unpaid rent ledger tracks unpaid rent month by month."),
                ),
            ),
            document(
                id = "doc-c",
                title = "Email Chain",
                pages = listOf(
                    page(1, "The tenant admits unpaid rent in the email response and discusses unpaid rent again in the reply."),
                ),
            ),
        )

        val sourcePack = AlphaAskRetrieval.buildSourcePack(
            question = question,
            candidateDocuments = documents.mapIndexed { index, document ->
                caseMatter("case-${index + 1}") to document
            },
            selectedDocumentIds = emptySet(),
            policy = AlphaAskSourcePackPolicy(sourceBlockLimit = 3),
        )

        assertEquals(3, sourcePack.size)
        assertEquals(3, sourcePack.map { it.sourceRef.documentId }.distinct().size)
    }

    @Test
    fun `selected documents each keep representation even when one dominates the query`() {
        val dominant = document(
            id = "doc-dominant",
            title = "Detailed Lease Notice",
            pages = listOf(
                page(1, "The lease notice describes unpaid rent and default in repeated detail."),
                page(2, "Further unpaid rent detail appears here."),
            ),
        )
        val secondary = document(
            id = "doc-secondary",
            title = "Client Notes",
            pages = listOf(
                page(1, "Client notes mention strategy and one short rent reference."),
            ),
        )

        val sourcePack = AlphaAskRetrieval.buildSourcePack(
            question = "What supports the unpaid rent default?",
            candidateDocuments = listOf(caseMatter("case-1") to dominant, caseMatter("case-1") to secondary),
            selectedDocumentIds = setOf(dominant.id, secondary.id),
            policy = AlphaAskSourcePackPolicy(sourceBlockLimit = 2),
        )

        assertEquals(2, sourcePack.size)
        assertTrue(sourcePack.any { it.sourceRef.documentId == dominant.id })
        assertTrue(sourcePack.any { it.sourceRef.documentId == secondary.id })
    }

    @Test
    fun `higher runtime budgets expand android ask source pack policy`() {
        val quickStartPolicy = alphaAskSourcePackPolicy(
            capabilityTier = AlphaCapabilityTier.QuickStart,
            maxInputChars = 12_000,
        )
        val caseAssociatePolicy = alphaAskSourcePackPolicy(
            capabilityTier = AlphaCapabilityTier.CaseAssociate,
            maxInputChars = 14_000,
        )
        val seniorPolicy = alphaAskSourcePackPolicy(
            capabilityTier = AlphaCapabilityTier.SeniorDraftingSupport,
            maxInputChars = 18_000,
        )

        assertTrue(quickStartPolicy.sourceBlockLimit < caseAssociatePolicy.sourceBlockLimit)
        assertTrue(caseAssociatePolicy.sourceBlockLimit < seniorPolicy.sourceBlockLimit)
        assertTrue(caseAssociatePolicy.selectedDocumentPageLimit <= seniorPolicy.selectedDocumentPageLimit)
        assertTrue(caseAssociatePolicy.preferredChunkChars <= seniorPolicy.preferredChunkChars)
    }

    private fun caseMatter(id: String) = AlphaCaseMatter(
        id = id,
        title = "Matter $id",
        forum = "Forum",
        stage = AlphaCaseStage.Pleadings,
        summary = "summary",
        issueHighlights = emptyList(),
        evidenceNotes = emptyList(),
        draftTasks = emptyList(),
        documents = emptyList(),
        sourceRefs = emptyList(),
    )

    private fun document(
        id: String,
        title: String,
        pages: List<AlphaDocumentPage>,
    ) = AlphaCaseDocument(
        id = id,
        title = title,
        fileName = "$id.pdf",
        kind = AlphaDocumentKind.Pdf,
        storedRelativePath = "docs/$id.pdf",
        pageCount = pages.size,
        ocrStatus = AlphaOcrStatus.Indexed,
        extractedText = pages.joinToString("\n") { it.extractedText.orEmpty() },
        dominantSourceSnippet = pages.firstOrNull()?.snippet,
        pages = pages,
    )

    private fun page(
        number: Int,
        text: String,
    ) = AlphaDocumentPage(
        pageNumber = number,
        snippet = text.take(160),
        extractedText = text,
    )
}
