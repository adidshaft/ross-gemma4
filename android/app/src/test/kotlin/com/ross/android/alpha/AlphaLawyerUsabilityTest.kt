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
import java.time.Duration
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
    fun `ask ross explains private assistant setup before download`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitAsk(
            question = "What can I do before setting up the private assistant?",
            scopeCaseId = null,
            webEnabled = false,
        )
        shadowOf(Looper.getMainLooper()).idle()

        val result = controller.latestAskResult
        assertEquals("Private assistant setup", result?.answerTitle)
        assertEquals("Private assistant", result?.statusNote)
        assertTrue(result?.answerSections?.joinToString(" ")?.contains("basic local review") == true)
        assertTrue(result?.selectedDocumentTitles?.isEmpty() == true)
        assertTrue(result?.caseFileSources?.isEmpty() == true)
    }

    @Test
    fun `web on requires preview before public law request`() {
        var publicLawCalls = 0
        var approvedQuerySent: String? = null
        val controller = buildController(
            secretKeyProvider = InMemorySecretKeyProvider(),
            publicLawSearchOverride = { preview ->
                publicLawCalls += 1
                approvedQuerySent = preview.query
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
        assertEquals(controller.publicLawPreview?.query, approvedQuerySent)
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
    fun `sanitized preview keeps legal citation numbering intact`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitAsk(
            question = "Order 39 Rules 1 and 2 CPC temporary injunction",
            scopeCaseId = null,
            webEnabled = true,
        )

        val preview = controller.publicLawPreview
        assertNotNull(preview)
        assertEquals("Order 39 Rules 1 and 2 CPC temporary injunction", preview?.query)
    }

    @Test
    fun `refreshing case overview does not silently inflate open tasks`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()

        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id
        val initialOpenTaskCount = controller.openTaskCount(caseId)

        controller.refreshCaseOverview(caseId)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(400))

        val finalOpenTaskCount = controller.openTaskCount(caseId)
        assertEquals(initialOpenTaskCount, finalOpenTaskCount)
    }

    @Test
    fun `local ask returns safe not found answer`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitAsk(
            question = "What does the blue suitcase near temple note say",
            scopeCaseId = null,
            webEnabled = false,
        )

        assertEquals("Ross could not find this in your files yet.", controller.latestAskResult?.answerTitle)
        assertEquals(listOf("Ross could not find this in your files yet."), controller.latestAskResult?.answerSections)
    }

    @Test
    fun `dock command adds task without triggering web preview`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id

        controller.submitDockInput(
            question = "add task prepare hearing note tomorrow",
            scopeCaseId = caseId,
            webEnabled = true,
        )

        assertTrue(controller.tasks(caseId).any { it.title == "prepare hearing note" })
        assertEquals("Task added.", controller.latestAskResult?.answerTitle)
        assertEquals("Saved locally", controller.latestAskResult?.statusNote)
        assertNull(controller.publicLawPreview)
    }

    @Test
    fun `dock command adds matter date to scoped matter`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id

        controller.submitDockInput(
            question = "save next hearing on 1 May 2026",
            scopeCaseId = caseId,
            webEnabled = false,
        )

        assertTrue(
            controller.scheduledMatterDates(caseId).any {
                it.kind == AlphaMatterDateKind.Hearing && it.title == "Next hearing" && it.date.startsWith("2026-05-01")
            }
        )
        assertEquals("Date saved.", controller.latestAskResult?.answerTitle)
    }

    @Test
    fun `dock command generates scoped export`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id

        controller.submitDockInput(
            question = "prepare hearing note",
            scopeCaseId = caseId,
            webEnabled = false,
        )

        assertTrue(controller.persisted.exports.any { it.caseId == caseId })
        assertEquals("Hearing note ready", controller.latestAskResult?.answerTitle)
        assertEquals("Draft ready", controller.latestAskResult?.statusNote)
    }

    @Test
    fun `dock command creates tasks from selected document`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id
        val documentId = controller.persisted.cases.first { it.id == caseId }.documents.first().id
        controller.openAsk(caseId, documentId)
        val initialTaskCount = controller.tasks(caseId).size

        controller.submitDockInput(
            question = "create tasks from this document",
            scopeCaseId = caseId,
            webEnabled = false,
        )

        assertTrue(controller.tasks(caseId).size >= initialTaskCount)
        assertTrue(listOf("Tasks added.", "No new tasks needed.").contains(controller.latestAskResult?.answerTitle))
    }

    @Test
    fun `dock command can rerun selected document review`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id
        val documentId = controller.persisted.cases.first { it.id == caseId }.documents.first().id
        controller.openAsk(caseId, documentId)

        controller.submitDockInput(
            question = "review this document",
            scopeCaseId = caseId,
            webEnabled = false,
        )
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals("Review updated.", controller.latestAskResult?.answerTitle)
        assertEquals("Review updated", controller.latestAskResult?.statusNote)
    }

    @Test
    fun `installed assistant upgrades matter ask and preserves public law preview`() {
        var runtimeWasCalled = false
        val controller = buildController(
            secretKeyProvider = InMemorySecretKeyProvider(),
            askRuntimeProviderOverride = {
                FakeMatterAnswerProvider { input ->
                    runtimeWasCalled = true
                    assertEquals(AlphaLocalModelTask.MatterQuestionAnswer, input.task)
                    assertTrue(input.sourcePack.isNotEmpty())
                    assertTrue(input.instruction.contains("Order 39", ignoreCase = true))
                    AlphaLocalModelOutput(
                        rawText = """
                            {
                              "headline": "Assistant answer from files",
                              "sections": ["The installed assistant read the selected matter files and kept the answer local."],
                              "statusNote": null
                            }
                        """.trimIndent(),
                        parsedJson = """
                            {
                              "headline": "Assistant answer from files",
                              "sections": ["The installed assistant read the selected matter files and kept the answer local."],
                              "statusNote": null
                            }
                        """.trimIndent(),
                        schemaValid = true,
                        warnings = emptyList(),
                        sourceRefs = input.sourcePack.map { it.sourceRef },
                    )
                }
            },
        )
        controller.signInDemoMode()
        val caseId = controller.cases.first { it.title == "Demo Matter: Sharma v. Rana" }.id
        controller.persisted = controller.persisted.copy(
            settings = controller.persisted.settings.copy(activeTier = AlphaCapabilityTier.CaseAssociate),
            installedPacks = listOf(
                AlphaInstalledPack(
                    packId = "case-associate-local-debug-pack",
                    tier = AlphaCapabilityTier.CaseAssociate,
                    installRelativePath = "model-packs/case_associate/case-associate-local-debug.task",
                    checksumSha256 = "a".repeat(64),
                    artifactKind = "external_debug_model",
                    runtimeMode = AlphaPackRuntimeMode.MediapipeLlm,
                    developmentOnly = true,
                    checksumVerified = true,
                    isActive = true,
                )
            ),
        )

        controller.submitAsk(
            question = "Order 39 Rules 1 and 2 CPC temporary injunction",
            scopeCaseId = caseId,
            webEnabled = true,
        )
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue(runtimeWasCalled)
        assertEquals("Assistant answer from files", controller.latestAskResult?.answerTitle)
        assertTrue(controller.latestAskResult?.answerSections?.single()?.contains("kept the answer local") == true)
        assertNotNull(controller.latestAskResult?.publicLawPreview)
        assertEquals("Web search preview ready", controller.latestAskResult?.statusNote)
        assertTrue(
            controller.persisted.cases
                .first { it.id == caseId }
                .chatTurns
                .any { it.answerTitle == "Assistant answer from files" && it.sourceRefs.isNotEmpty() }
        )
    }

    @Test
    fun `dock question still falls back to standard ask flow`() {
        val controller = buildController(secretKeyProvider = InMemorySecretKeyProvider())

        controller.submitDockInput(
            question = "What needs my attention today?",
            scopeCaseId = null,
            webEnabled = false,
        )

        assertNull(controller.publicLawPreview)
        assertFalse(controller.latestAskResult?.answerTitle?.contains("saved locally", ignoreCase = true) == true)
        assertFalse(controller.latestAskResult?.answerTitle?.contains("ready", ignoreCase = true) == true)
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
        askRuntimeProviderOverride: ((AlphaInstalledPack) -> AlphaLocalModelProvider?)? = null,
    ): AlphaRossController = AlphaRossController(
        context = context,
        publicLawSearchOverride = publicLawSearchOverride,
        secretKeyProvider = secretKeyProvider,
        askRuntimeProviderOverride = askRuntimeProviderOverride,
    )
}

private class InMemorySecretKeyProvider : AlphaSecretKeyProvider {
    private val secretKey: SecretKey by lazy {
        KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    }

    override fun getOrCreate(): SecretKey = secretKey
}

private class FakeMatterAnswerProvider(
    private val runBlock: suspend (AlphaLocalModelInput) -> AlphaLocalModelOutput,
) : AlphaLocalModelProvider {
    override val capabilityTier: AlphaCapabilityTier = AlphaCapabilityTier.CaseAssociate
    override val runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.MediapipeLlm

    override fun isAvailable(): Boolean = true

    override fun supportedTasks(): Set<AlphaLocalModelTask> = setOf(AlphaLocalModelTask.MatterQuestionAnswer)

    override fun runtimeHealth(): AlphaLocalRuntimeHealth =
        AlphaLocalRuntimeHealth(
            runtimeMode = runtimeMode,
            available = true,
            modelPathPresent = true,
            modelPathLabel = "case-associate-local-debug.task",
            checksumVerified = true,
            supportedTasks = supportedTasks().toList(),
            maxInputChars = maxInputChars(),
            estimatedContextTokens = contextWindowEstimate(),
            userFacingStatus = "Private assistant is available for test.",
            fallbackActive = false,
            explicitOptInEnabled = true,
        )

    override fun contextWindowEstimate(): Int = 4_096

    override fun maxInputChars(): Int = 14_000

    override suspend fun run(taskInput: AlphaLocalModelInput): AlphaLocalModelOutput = runBlock(taskInput)

    override fun estimateCostOrResourceUse(input: AlphaLocalModelInput): AlphaLocalModelResourceEstimate =
        AlphaLocalModelResourceEstimate(
            inputChars = input.instruction.length + input.sourcePack.sumOf { it.text.length },
            estimatedTokens = null,
            estimatedRuntimeMs = 0,
            estimatedMemoryMb = 0,
            estimatedDurationSeconds = 0,
            shouldRunNow = true,
            reason = null,
            notes = emptyList(),
        )

    override fun cancel(invocationId: String): Boolean = false
}
