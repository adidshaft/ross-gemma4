package com.ross.android.alpha

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.util.UUID
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

@RunWith(RobolectricTestRunner::class)
class AlphaLawyerUsabilityTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.filesDir.resolve("ross-alpha").deleteRecursively()
    }

    @Test
    fun `task persists after reload`() {
        val keyProvider = InMemorySecretKeyProvider()
        val title = "Prepare chronology for mention"

        val controller = buildController(secretKeyProvider = keyProvider)
        controller.addTask(title = title, caseId = null, dueDate = nowIso())

        val reloaded = buildController(secretKeyProvider = keyProvider)

        assertTrue(reloaded.tasks().any { it.title == title })
    }

    @Test
    fun `web off keeps public law backend idle`() {
        var publicLawCalls = 0
        val controller = buildController(
            secretKeyProvider = InMemorySecretKeyProvider(),
            publicLawSearchOverride = {
                publicLawCalls += 1
                emptyList()
            },
        )

        controller.submitAsk(
            question = "Find law on delay condonation",
            scopeCaseId = null,
            webEnabled = false,
        )
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(0, publicLawCalls)
        assertNull(controller.publicLawPreview)
        assertEquals("Web search off", controller.latestAskResult?.statusNote)
    }

    @Test
    fun `web on requires preview before public law request`() {
        var publicLawCalls = 0
        val controller = buildController(
            secretKeyProvider = InMemorySecretKeyProvider(),
            publicLawSearchOverride = {
                publicLawCalls += 1
                listOf(
                    AlphaPublicLawResult(
                        title = "Delay condonation and documented diligence",
                        citation = "(2024) 7 SCC 112",
                        snippet = "Diligence and chronology remain central to condonation review.",
                        sourceName = "Official source",
                    )
                )
            },
        )

        controller.submitAsk(
            question = "Find law on delay condonation",
            scopeCaseId = null,
            webEnabled = true,
        )

        assertEquals(0, publicLawCalls)
        assertNotNull(controller.publicLawPreview)
        assertEquals("Web search preview ready", controller.latestAskResult?.statusNote)

        controller.confirmPendingPublicLawSearch()
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(1, publicLawCalls)
        assertEquals("Public-law results", controller.latestAskResult?.statusNote)
        assertEquals(1, controller.publicLawResults.size)
    }

    @Test
    fun `sanitized preview strips fake secrets`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitAsk(
            question = "Find guidance for Raghav Fakepriv on 9876501234 using fakepriv@example.com and private-bundle.pdf in FAKE/123/2026",
            scopeCaseId = null,
            webEnabled = true,
        )

        val preview = controller.publicLawPreview
        assertNotNull(preview)
        assertFalse(preview!!.query.contains("Raghav Fakepriv", ignoreCase = true))
        assertFalse(preview.query.contains("9876501234"))
        assertFalse(preview.query.contains("fakepriv@example.com", ignoreCase = true))
        assertFalse(preview.query.contains("private-bundle.pdf", ignoreCase = true))
        assertFalse(preview.query.contains("FAKE/123/2026", ignoreCase = true))
    }

    @Test
    fun `local ask returns safe not found answer`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitAsk(
            question = "What does the blue suitcase near temple note say",
            scopeCaseId = null,
            webEnabled = false,
        )

        assertEquals("I could not find this in your case files.", controller.latestAskResult?.answerTitle)
        assertEquals(listOf("I could not find this in your case files."), controller.latestAskResult?.answerSections)
    }

    @Test
    fun `review count updates after field correction`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        val caseId = "case-review"
        val documentId = "doc-review"
        val fieldId = "field-next-date"
        val sourceRef = AlphaSourceRef(
            caseId = caseId,
            documentId = documentId,
            documentTitle = "Order",
            pageNumber = 1,
            textSnippet = "Listed on 15/05/2026",
        )
        controller.persisted = AlphaPersistedState(
            cases = listOf(
                AlphaCaseMatter(
                    id = caseId,
                    title = "Review Matter",
                    forum = "Delhi High Court",
                    stage = AlphaCaseStage.Pleadings,
                    summary = "summary",
                    issueHighlights = emptyList(),
                    evidenceNotes = emptyList(),
                    draftTasks = emptyList(),
                    documents = listOf(
                        AlphaCaseDocument(
                            id = documentId,
                            title = "Order",
                            fileName = "order.pdf",
                            kind = AlphaDocumentKind.Pdf,
                            storedRelativePath = "docs/order.pdf",
                            pageCount = 1,
                            ocrStatus = AlphaOcrStatus.Indexed,
                            extractedFields = listOf(
                                AlphaExtractedLegalField(
                                    id = fieldId,
                                    caseId = caseId,
                                    documentId = documentId,
                                    fieldType = AlphaExtractedLegalFieldType.NextDate,
                                    label = "Next date",
                                    value = "15/05/2026",
                                    sourceRefs = listOf(sourceRef),
                                    confidence = 0.52,
                                    extractionMode = AlphaExtractionMode.CaseAssociate,
                                    extractionPass = AlphaExtractionPass.LlmExtract,
                                    needsReview = true,
                                )
                            ),
                            pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "Listed on 15/05/2026")),
                        )
                    ),
                    sourceRefs = listOf(sourceRef),
                )
            ),
            tasks = emptyList(),
            ledgerEntries = emptyList(),
            modelJobs = emptyList(),
            installedPacks = emptyList(),
            localInferenceMetrics = emptyList(),
            publicLawCache = emptyList(),
            exports = emptyList(),
        )

        assertEquals(1, controller.reviewQueue(caseId).size)

        controller.applyFieldCorrection(caseId, documentId, fieldId, "15/05/2026")

        assertEquals(0, controller.reviewQueue(caseId).size)
        assertTrue(controller.persisted.cases.first().caseMemoryUpdates.isNotEmpty())
        val nextHearing = controller.persisted.cases.first().nextHearing
        assertNotNull(nextHearing)
        val resolvedDate = java.time.Instant.parse(nextHearing)
            .atZone(java.time.ZoneId.systemDefault())
            .toLocalDate()
            .toString()
        assertEquals("2026-05-15", resolvedDate)
    }

    @Test
    fun `finish pack setup starts assistant setup`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.selectedTier = AlphaCapabilityTier.CaseAssociate
        controller.finishPackSetup()
        shadowOf(Looper.getMainLooper()).idle()

        val hasAssistantSetupState = controller.persisted.modelJobs.any { it.tier == AlphaCapabilityTier.CaseAssociate }
            || controller.persisted.installedPacks.any { it.tier == AlphaCapabilityTier.CaseAssociate }

        assertEquals(AlphaOnboardingStage.Completed, controller.persisted.onboardingStage)
        assertEquals(AlphaAppTab.Home, controller.persisted.selectedTab)
        assertTrue(hasAssistantSetupState)
    }

    private fun buildController(
        secretKeyProvider: AlphaSecretKeyProvider,
        publicLawSearchOverride: (suspend (AlphaPublicLawPreview) -> List<AlphaPublicLawResult>)? = null,
    ): AlphaRossController = AlphaRossController(
        context = context,
        publicLawSearchOverride = publicLawSearchOverride,
        secretKeyProvider = secretKeyProvider,
    )
}

private class InMemorySecretKeyProvider : AlphaSecretKeyProvider {
    private val secretKey: SecretKey by lazy {
        KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    }

    override fun getOrCreate(): SecretKey = secretKey
}
