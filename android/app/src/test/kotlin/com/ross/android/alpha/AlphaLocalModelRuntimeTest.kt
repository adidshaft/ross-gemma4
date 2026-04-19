package com.ross.android.alpha

import android.app.Application
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

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
        assertEquals(AlphaPackRuntimeMode.DeterministicDev, provider.runtimeMode)
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
    fun `canonical local runtime config parses debug overrides`() {
        val environment = AlphaLocalRuntimeEnvironment.fromBuildConfig(
            runtimeOverrides = mapOf(
                "ROSS_ENABLE_REAL_LOCAL_INFERENCE" to "1",
                "ROSS_LOCAL_RUNTIME" to "mediapipe_llm",
                "ROSS_LOCAL_MODEL_PATH" to "/tmp/ross/model.task",
                "ROSS_LOCAL_MODEL_CHECKSUM" to "a".repeat(64),
                "ROSS_LOCAL_MODEL_KIND" to "mediapipe_task",
            ),
        )

        assertTrue(environment.enableRealInference)
        assertEquals(AlphaPackRuntimeMode.MediapipeLlm, environment.runtimeModeOverride)
        assertEquals("/tmp/ross/model.task", environment.modelPath)
        assertEquals("a".repeat(64), environment.modelChecksum)
        assertEquals("mediapipe_task", environment.modelKind)
    }

    @Test
    fun `runtime selection uses real provider when debug model path exists`() {
        val root = Files.createTempDirectory("ross-mediapipe-runtime").toFile()
        val modelFile = File(root, "case-associate.task").apply { writeText("developer supplied model bytes") }
        val environment = AlphaLocalRuntimeEnvironment(
            enableRealInference = true,
            runtimeModeOverride = AlphaPackRuntimeMode.MediapipeLlm,
            modelPath = modelFile.absolutePath,
            modelChecksum = null,
            modelKind = "mediapipe_task",
        )

        val provider = AlphaLocalModelRuntime.resolveProvider(
            activePack = null,
            requestedTier = AlphaCapabilityTier.CaseAssociate,
            executor = { input ->
                AlphaLocalModelOutput(
                    rawText = input.expectedSchema,
                    parsedJson = input.expectedSchema,
                    schemaValid = true,
                    warnings = emptyList(),
                    sourceRefs = input.sourcePack.map { it.sourceRef },
                )
            },
            context = Application(),
            appPrivateRoot = root,
            runtimeEnvironment = environment,
            mediaPipeRunner = AlphaMediaPipeRunner { _, _, _, _ -> """[]""" },
            deviceSupported = true,
        )
        val health = AlphaLocalModelRuntime.runtimeHealth(
            activePack = null,
            requestedTier = AlphaCapabilityTier.CaseAssociate,
            context = Application(),
            appPrivateRoot = root,
            runtimeEnvironment = environment,
        )

        assertTrue(provider is AlphaMediaPipeLocalModelProvider)
        assertEquals(AlphaPackRuntimeMode.MediapipeLlm, provider?.runtimeMode)
        assertTrue(health?.available == true)
        assertTrue(health?.modelPathPresent == true)
        assertFalse(health?.fallbackActive ?: true)
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
        assertEquals("deterministic_dev", invocation.runtimeMode)
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
    fun `real runtime selection falls back safely when android adapter is unavailable`() = runBlocking {
        val pack = installedPack(
            tier = AlphaCapabilityTier.CaseAssociate,
            runtimeMode = AlphaPackRuntimeMode.MediapipeLlm,
            artifactKind = "local_model_artifact",
        )
        val provider = AlphaLocalModelRuntime.resolveProvider(
            activePack = pack,
            requestedTier = pack.tier,
            executor = { input ->
                AlphaLocalModelOutput(
                    rawText = input.expectedSchema,
                    parsedJson = input.expectedSchema,
                    schemaValid = true,
                    warnings = emptyList(),
                    sourceRefs = input.sourcePack.map { it.sourceRef },
                )
            },
            context = Application(),
            appPrivateRoot = Files.createTempDirectory("ross-missing-runtime").toFile(),
        )
        val health = AlphaLocalModelRuntime.runtimeHealth(
            activePack = pack,
            requestedTier = pack.tier,
            context = Application(),
            appPrivateRoot = Files.createTempDirectory("ross-missing-runtime-health").toFile(),
        )

        assertTrue(provider is DeterministicDevLocalModelProvider)
        assertEquals(AlphaPackRuntimeMode.DeterministicDev, provider?.runtimeMode)
        assertEquals(AlphaPackRuntimeMode.MediapipeLlm, health?.runtimeMode)
        assertFalse(health?.available ?: true)
        assertTrue(health?.fallbackActive == true)
        assertEquals("model_file_missing", health?.lastErrorCategory)
    }

    @Test
    fun `missing debug model path reports unavailable health`() {
        val environment = AlphaLocalRuntimeEnvironment(
            enableRealInference = true,
            runtimeModeOverride = AlphaPackRuntimeMode.MediapipeLlm,
            modelPath = "/tmp/ross/does-not-exist.task",
            modelChecksum = null,
            modelKind = "mediapipe_task",
        )

        val health = AlphaLocalModelRuntime.runtimeHealth(
            activePack = null,
            requestedTier = AlphaCapabilityTier.CaseAssociate,
            context = Application(),
            appPrivateRoot = null,
            runtimeEnvironment = environment,
        )

        assertEquals(AlphaPackRuntimeMode.MediapipeLlm, health?.runtimeMode)
        assertFalse(health?.available ?: true)
        assertTrue(health?.fallbackActive ?: false)
        assertEquals("model_file_missing", health?.lastErrorCategory)
    }

    @Test
    fun `invalid model output is rejected before extraction can trust it`() = runBlocking {
        val modelFile = Files.createTempFile("ross-invalid-output", ".task").toFile().apply {
            writeText("developer supplied model bytes")
        }
        val provider = AlphaMediaPipeLocalModelProvider(
            context = Application(),
            capabilityTier = AlphaCapabilityTier.CaseAssociate,
            modelFile = modelFile,
            modelPathLabel = modelFile.name,
            expectedChecksum = null,
            checksumVerifiedFromPack = false,
            modelKind = "mediapipe_task",
            explicitOptInEnabled = true,
            runner = AlphaMediaPipeRunner { _, _, _, _ -> "The court is likely Delhi High Court." },
            deviceSupported = true,
        )
        val output = provider.run(
            AlphaLocalModelInput(
                task = AlphaLocalModelTask.LegalFieldExtraction,
                instruction = "Extract only source-backed legal fields.",
                sourcePack = listOf(
                    AlphaSourceTextBlock(
                        sourceRef = AlphaSourceRef(
                            caseId = "case-invalid",
                            documentId = "doc-invalid",
                            documentTitle = "Order",
                            pageNumber = 1,
                            textSnippet = "Order text",
                        ),
                        text = "Order text",
                        pageNumber = 1,
                    ),
                ),
                expectedSchema = "array<AlphaExtractedLegalField>",
                maxOutputTokens = 256,
                extractionMode = AlphaExtractionMode.CaseAssociate,
            ),
        )

        assertFalse(output.schemaValid)
        assertEquals("invalid_model_output", output.errorCategory)
    }

    @Test
    fun `prompt pack budget enforcement returns needs review style failure`() = runBlocking {
        val modelFile = Files.createTempFile("ross-budget", ".task").toFile().apply {
            writeText("developer supplied model bytes")
        }
        val provider = AlphaMediaPipeLocalModelProvider(
            context = Application(),
            capabilityTier = AlphaCapabilityTier.CaseAssociate,
            modelFile = modelFile,
            modelPathLabel = modelFile.name,
            expectedChecksum = null,
            checksumVerifiedFromPack = false,
            modelKind = "mediapipe_task",
            explicitOptInEnabled = true,
            runner = AlphaMediaPipeRunner { _, _, _, _ -> """[]""" },
            deviceSupported = true,
        )
        val hugeBlock = "A".repeat(25_000)
        val output = provider.run(
            AlphaLocalModelInput(
                task = AlphaLocalModelTask.LegalFieldExtraction,
                instruction = "Extract only source-backed legal fields.",
                sourcePack = listOf(
                    AlphaSourceTextBlock(
                        sourceRef = AlphaSourceRef(
                            caseId = "case-budget",
                            documentId = "doc-budget",
                            documentTitle = "Order",
                            pageNumber = 1,
                            textSnippet = "snippet",
                        ),
                        text = hugeBlock,
                        pageNumber = 1,
                    ),
                ),
                expectedSchema = "array<AlphaExtractedLegalField>",
                maxOutputTokens = 512,
                extractionMode = AlphaExtractionMode.CaseAssociate,
            ),
        )

        assertFalse(output.schemaValid)
        assertEquals("budget_exceeded", output.errorCategory)
    }

    @Test
    fun `android local model runtime source keeps network imports out of provider`() {
        val workingDir = File(requireNotNull(System.getProperty("user.dir")))
        val sourceFile = listOf(
            File(workingDir, "app/src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt"),
            File(workingDir, "src/main/kotlin/com/ross/android/alpha/AlphaLocalModelRuntime.kt"),
        ).firstOrNull { it.exists() }
            ?: error("Could not locate AlphaLocalModelRuntime.kt from ${workingDir.absolutePath}")
        val source = sourceFile.readText()

        assertFalse(source.contains("java.net."))
        assertFalse(source.contains("HttpURLConnection"))
        assertFalse(source.contains("URLSession"))
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

    private fun installedPack(
        tier: AlphaCapabilityTier,
        runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.DeterministicDev,
        artifactKind: String = "tiny_dev_artifact",
    ): AlphaInstalledPack =
        AlphaInstalledPack(
            packId = "${tier.tierId}-pack",
            tier = tier,
            installRelativePath = "model-packs/${tier.tierId}/pack.dev",
            checksumSha256 = "deadbeef",
            artifactKind = artifactKind,
            runtimeMode = runtimeMode,
            developmentOnly = runtimeMode == AlphaPackRuntimeMode.DeterministicDev,
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
