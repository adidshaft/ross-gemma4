package com.ross.android.alpha

import android.app.Application
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlphaLocalModelRuntimeTest {
    @Test
    fun `pipeline plan follows installed pack tier and fallback expectations`() {
        val basic = AlphaExtractionPipelinePlanner.planFor(null)
        assertEquals(AlphaExtractionMode.Basic, basic.mode)
        assertFalse(basic.requiresInstalledPack)
        assertEquals(
            listOf(
                AlphaLocalModelTask.LanguageCorrection,
                AlphaLocalModelTask.LegalFieldVerification,
            ),
            basic.passes.map { it.task },
        )

        val quickStart = AlphaExtractionPipelinePlanner.planFor(installedPack(AlphaCapabilityTier.QuickStart))
        assertEquals(AlphaExtractionMode.QuickStart, quickStart.mode)
        assertTrue(quickStart.requiresInstalledPack)
        assertEquals(AlphaUserFacingExtractionQuality.Standard, quickStart.userFacingQuality)
        assertEquals(
            listOf(
                AlphaLocalModelTask.OcrCleanup,
                AlphaLocalModelTask.DocumentClassification,
                AlphaLocalModelTask.LegalFieldExtraction,
                AlphaLocalModelTask.LegalFieldVerification,
            ),
            quickStart.passes.map { it.task },
        )
        assertTrue(quickStart.passes.all { it.maxPagesPerBatch == 10 })
        assertTrue(quickStart.passes.all { it.fallback == AlphaExtractionPipelineFallback.Deterministic })

        val caseAssociate = AlphaExtractionPipelinePlanner.planFor(installedPack(AlphaCapabilityTier.CaseAssociate))
        assertEquals(AlphaExtractionMode.CaseAssociate, caseAssociate.mode)
        assertEquals(AlphaUserFacingExtractionQuality.Advanced, caseAssociate.userFacingQuality)
        assertEquals(
            AlphaExtractionPipelineFallback.NeedsReview,
            caseAssociate.passes.single { it.task == AlphaLocalModelTask.LegalFieldExtraction }.fallback,
        )
        assertEquals(
            AlphaExtractionPipelineFallback.Deterministic,
            caseAssociate.passes.single { it.task == AlphaLocalModelTask.LegalFieldVerification }.fallback,
        )

        val seniorDrafting = AlphaExtractionPipelinePlanner.planFor(installedPack(AlphaCapabilityTier.SeniorDraftingSupport))
        assertEquals(AlphaExtractionMode.SeniorDraftingSupport, seniorDrafting.mode)
        assertTrue(
            seniorDrafting.passes.any {
                it.task == AlphaLocalModelTask.IssueExtraction &&
                    !it.required &&
                    it.fallback == AlphaExtractionPipelineFallback.Deterministic
            },
        )
        assertEquals(
            AlphaExtractionPipelineFallback.NeedsReview,
            seniorDrafting.passes.single { it.task == AlphaLocalModelTask.DocumentClassification }.fallback,
        )
        assertEquals(
            AlphaExtractionPipelineFallback.NeedsReview,
            seniorDrafting.passes.single { it.task == AlphaLocalModelTask.LegalFieldExtraction }.fallback,
        )
    }

    @Test
    fun `deterministic dev provider returns injected output and stable estimate`() = runBlocking {
        val sourceRef = AlphaSourceRef(
            caseId = "case-1",
            documentId = "doc-1",
            documentTitle = "Order",
            pageNumber = 1,
            textSnippet = "Order text",
        )
        val input = AlphaLocalModelInput(
            task = AlphaLocalModelTask.LegalFieldExtraction,
            instruction = "Keep this prompt deterministic.",
            sourcePack = listOf(
                AlphaSourceTextBlock(
                    sourceRef = sourceRef,
                    text = "Order text with a case number.",
                    pageNumber = 1,
                    ocrConfidence = 0.91,
                )
            ),
            expectedSchema = "array<AlphaExtractedLegalField>",
            maxOutputTokens = 512,
            extractionMode = AlphaExtractionMode.CaseAssociate,
        )
        val output = AlphaLocalModelOutput(
            rawText = """[{"caseId":"case-1"}]""",
            parsedJson = """[{"caseId":"case-1"}]""",
            schemaValid = true,
            warnings = listOf("deterministic"),
            sourceRefs = listOf(sourceRef),
        )
        val provider = DeterministicDevLocalModelProvider(AlphaCapabilityTier.CaseAssociate) { taskInput ->
            assertEquals(input, taskInput)
            output
        }

        assertTrue(provider.isAvailable())
        assertEquals(AlphaLocalModelTask.entries.toSet(), provider.supportedTasks())

        val produced = provider.run(input)
        val estimate = provider.estimateCostOrResourceUse(input)

        assertEquals(output, produced)
        assertEquals(120L, estimate.estimatedRuntimeMs)
        assertEquals(6, estimate.estimatedMemoryMb)
        assertTrue(estimate.notes.single().contains("deterministic", ignoreCase = true))
        assertTrue(provider.cancel("invocation-1"))
    }

    @Test
    fun `invocation records keep hashes instead of raw prompt or source text`() {
        val sourceRef = AlphaSourceRef(
            caseId = "case-2",
            documentId = "doc-2",
            documentTitle = "Motion",
            pageNumber = 4,
            textSnippet = "Sensitive source snippet",
        )
        val input = AlphaLocalModelInput(
            task = AlphaLocalModelTask.LegalFieldVerification,
            instruction = "Never surface the raw prompt value: secret prompt text.",
            sourcePack = listOf(
                AlphaSourceTextBlock(
                    sourceRef = sourceRef,
                    text = "raw source text from page four",
                    pageNumber = 4,
                    ocrConfidence = 0.77,
                )
            ),
            expectedSchema = "AlphaVerificationPayload",
            maxOutputTokens = 256,
            extractionMode = AlphaExtractionMode.QuickStart,
        )

        val invocation = AlphaModelInvocationStore.begin(
            task = AlphaLocalModelTask.LegalFieldVerification,
            capabilityTier = AlphaCapabilityTier.CaseAssociate,
            caseId = "case-2",
            documentId = "doc-2",
            extractionRunId = "run-2",
            input = input,
        )
        val completed = AlphaModelInvocationStore.complete(
            invocation = invocation,
            output = AlphaLocalModelOutput(
                rawText = """{"verified":true}""",
                parsedJson = """{"verified":true}""",
                schemaValid = true,
                warnings = emptyList(),
                sourceRefs = listOf(sourceRef),
            ),
        )

        val invocationFieldNames = AlphaLocalModelInvocation::class.java.declaredFields.map { it.name }
        assertFalse("instruction" in invocationFieldNames)
        assertFalse("sourcePack" in invocationFieldNames)
        assertFalse("expectedSchema" in invocationFieldNames)
        assertEquals(64, invocation.promptHash.length)
        assertEquals(64, invocation.inputHash.length)
        assertEquals(1, invocation.inputSourceRefs.size)
        assertEquals("Source document", invocation.inputSourceRefs.single().documentTitle)
        assertEquals(null, invocation.inputSourceRefs.single().textSnippet)
        assertEquals(64, completed.outputHash?.length)
        assertEquals(AlphaLocalModelInvocationStatus.Complete, completed.status)
    }

    @Test
    fun `case associate verifier promotes supported fields and flags unsupported ones`() {
        val orchestrator = AlphaLocalExtractionOrchestrator(Application())
        val document = AlphaCaseDocument(
            id = "doc-3",
            title = "Order",
            fileName = "order.txt",
            kind = AlphaDocumentKind.Text,
            storedRelativePath = "documents/doc-3/order.txt",
            pageCount = 1,
            ocrStatus = AlphaOcrStatus.OcrComplete,
            pages = emptyList(),
        )
        val page = privatePageAcquisition(
            pageNumber = 1,
            text = "CS(COMM) 245/2026",
        )
        val supportedField = AlphaExtractedLegalField(
            id = "field-supported",
            caseId = "case-3",
            documentId = "doc-3",
            fieldType = AlphaExtractedLegalFieldType.CaseNumber,
            label = "Case number",
            value = "CS(COMM) 245/2026",
            normalizedValue = "cs comm 245 2026",
            sourceRefs = listOf(
                AlphaSourceRef(
                    caseId = "case-3",
                    documentId = "doc-3",
                    documentTitle = "Order",
                    pageNumber = 1,
                    textSnippet = "CS(COMM) 245/2026",
                )
            ),
            confidence = 0.62,
            extractionMode = AlphaExtractionMode.CaseAssociate,
            extractionPass = AlphaExtractionPass.LlmExtract,
            needsReview = false,
        )
        val unsupportedField = AlphaExtractedLegalField(
            id = "field-unsupported",
            caseId = "case-3",
            documentId = "doc-3",
            fieldType = AlphaExtractedLegalFieldType.Court,
            label = "Court",
            value = "Bombay High Court",
            normalizedValue = "bombay high court",
            sourceRefs = listOf(
                AlphaSourceRef(
                    caseId = "case-3",
                    documentId = "doc-3",
                    documentTitle = "Order",
                    pageNumber = 1,
                    textSnippet = "The respondent shall file a reply within two weeks.",
                )
            ),
            confidence = 0.86,
            extractionMode = AlphaExtractionMode.CaseAssociate,
            extractionPass = AlphaExtractionPass.Regex,
            needsReview = false,
        )

        val bundle = invokePrivate(
            instance = orchestrator,
            methodName = "verifyFields",
            "case-3",
            document,
            listOf(page),
            listOf(supportedField, unsupportedField),
        )
        val verifiedFields = bundleField<List<AlphaExtractedLegalField>>(requireNotNull(bundle), "fields")
        val findings = bundleField<List<AlphaExtractionFinding>>(requireNotNull(bundle), "findings")

        val flagged = verifiedFields.single { it.id == unsupportedField.id }

        assertTrue(verifiedFields.any { it.id == supportedField.id })
        assertTrue(flagged.needsReview)
        assertTrue(flagged.confidence < unsupportedField.confidence)
        assertTrue(findings.any { it.kind == AlphaExtractionFindingKind.UnsupportedLayout })
    }

    @Test
    fun `user corrected field values are preserved during merge`() {
        val controller = allocateWithoutConstructor(AlphaRossController::class.java)
        val preserved = AlphaExtractedLegalField(
            id = "field-preserved",
            caseId = "case-4",
            documentId = "doc-4",
            fieldType = AlphaExtractedLegalFieldType.CaseNumber,
            label = "Case number",
            value = "CS(COMM) 245/2026",
            normalizedValue = "cs comm 245 2026",
            sourceRefs = emptyList(),
            confidence = 0.93,
            extractionMode = AlphaExtractionMode.CaseAssociate,
            extractionPass = AlphaExtractionPass.Regex,
            needsReview = false,
            userCorrected = true,
        )
        val carriedForward = AlphaExtractedLegalField(
            id = "field-carried-forward",
            caseId = "case-4",
            documentId = "doc-4",
            fieldType = AlphaExtractedLegalFieldType.PartyName,
            label = "Party",
            value = "Petitioner",
            normalizedValue = "petitioner",
            sourceRefs = emptyList(),
            confidence = 0.79,
            extractionMode = AlphaExtractionMode.CaseAssociate,
            extractionPass = AlphaExtractionPass.Regex,
            needsReview = false,
            userCorrected = true,
        )
        val incoming = listOf(
            AlphaExtractedLegalField(
                id = "field-new",
                caseId = "case-4",
                documentId = "doc-4",
                fieldType = AlphaExtractedLegalFieldType.CaseNumber,
                label = "Case number",
                value = "CS(COMM) 245/2026",
                normalizedValue = "cs comm 245 2026",
                sourceRefs = emptyList(),
                confidence = 0.51,
                extractionMode = AlphaExtractionMode.CaseAssociate,
                extractionPass = AlphaExtractionPass.LlmExtract,
                needsReview = true,
            )
        )

        val merged = invokePrivate(
            instance = controller,
            methodName = "mergeUserCorrectedFields",
            listOf(preserved, carriedForward),
            incoming,
        ) as List<AlphaExtractedLegalField>

        val restored = merged.single { it.fieldType == AlphaExtractedLegalFieldType.CaseNumber }
        assertEquals(preserved.id, restored.id)
        assertTrue(restored.userCorrected)
        assertEquals(preserved.value, restored.value)
        assertTrue(merged.any { it.id == carriedForward.id && it.userCorrected })
    }

    private fun installedPack(tier: AlphaCapabilityTier): AlphaInstalledPack =
        AlphaInstalledPack(
            packId = "${tier.tierId}-pack",
            tier = tier,
            installRelativePath = "model-packs/${tier.tierId}/pack.dev",
            checksumSha256 = "deadbeef",
            runtimeMode = AlphaPackRuntimeMode.DeterministicDev,
            developmentOnly = true,
            installedAt = "2026-04-19T00:00:00Z",
            isActive = true,
        )

    private fun privatePageAcquisition(
        pageNumber: Int,
        text: String,
    ): Any {
        val clazz = Class.forName("com.ross.android.alpha.AlphaPageAcquisition")
        val ctor = clazz.declaredConstructors.single()
        ctor.isAccessible = true
        return ctor.newInstance(
            pageNumber,
            text,
            text,
            text,
            0.91,
            AlphaOcrStatus.OcrComplete,
            AlphaIndexingStatus.Indexed,
        )
    }

    private fun invokePrivate(instance: Any, methodName: String, vararg args: Any?): Any? {
        val method = instance.javaClass.declaredMethods.single { it.name == methodName && it.parameterCount == args.size }
        method.isAccessible = true
        return method.invoke(instance, *args)
    }

    private fun <T : Any> allocateWithoutConstructor(clazz: Class<T>): T {
        val reflectionFactory = Class.forName("sun.reflect.ReflectionFactory")
            .getMethod("getReflectionFactory")
            .invoke(null)
        @Suppress("UNCHECKED_CAST")
        val constructor = reflectionFactory.javaClass
            .getMethod("newConstructorForSerialization", Class::class.java, java.lang.reflect.Constructor::class.java)
            .invoke(reflectionFactory, clazz, Any::class.java.getDeclaredConstructor()) as java.lang.reflect.Constructor<T>
        constructor.isAccessible = true
        return constructor.newInstance()
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> bundleField(bundle: Any, fieldName: String): T {
        val field = bundle.javaClass.getDeclaredField(fieldName)
        field.isAccessible = true
        return field.get(bundle) as T
    }
}
