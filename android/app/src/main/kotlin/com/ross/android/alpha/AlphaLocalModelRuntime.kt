package com.ross.android.alpha

import com.google.gson.Gson

enum class AlphaLocalModelTask(val wireValue: String) {
    OcrCleanup("ocr_cleanup"),
    LanguageCorrection("language_correction"),
    DocumentClassification("document_classification"),
    LegalFieldExtraction("legal_field_extraction"),
    LegalFieldVerification("legal_field_verification"),
    CaseMemorySynthesis("case_memory_synthesis"),
    ChronologyGeneration("chronology_generation"),
    OrderSummary("order_summary"),
    IssueExtraction("issue_extraction"),
}

enum class AlphaLocalModelInvocationStatus { Queued, Running, Complete, Failed, Cancelled }
enum class AlphaLocalRuntimeMode { DeterministicDev, PlatformStub }

data class AlphaSourceTextBlock(
    val sourceRef: AlphaSourceRef,
    val text: String,
    val pageNumber: Int,
    val languageHint: String? = null,
    val ocrConfidence: Double? = null,
)

data class AlphaLocalModelInput(
    val task: AlphaLocalModelTask,
    val instruction: String,
    val sourcePack: List<AlphaSourceTextBlock>,
    val expectedSchema: String,
    val maxOutputTokens: Int,
    val languageProfile: AlphaDocumentLanguageProfile? = null,
    val documentClassification: AlphaLegalDocumentClassification? = null,
    val extractionMode: AlphaExtractionMode,
)

data class AlphaLocalModelOutput(
    val rawText: String,
    val parsedJson: String? = null,
    val schemaValid: Boolean,
    val warnings: List<String>,
    val sourceRefs: List<AlphaSourceRef>,
)

data class AlphaLocalResourceEstimate(
    val estimatedRuntimeMs: Long,
    val estimatedMemoryMb: Int,
    val notes: List<String>,
)

interface AlphaLocalModelProvider {
    val capabilityTier: AlphaCapabilityTier
    fun isAvailable(): Boolean
    fun supportedTasks(): Set<AlphaLocalModelTask>
    suspend fun run(taskInput: AlphaLocalModelInput): AlphaLocalModelOutput
    fun estimateCostOrResourceUse(input: AlphaLocalModelInput): AlphaLocalResourceEstimate
    fun cancel(invocationId: String): Boolean
}

class DeterministicDevLocalModelProvider(
    override val capabilityTier: AlphaCapabilityTier,
    private val executor: suspend (AlphaLocalModelInput) -> AlphaLocalModelOutput,
) : AlphaLocalModelProvider {
    override fun isAvailable(): Boolean = true

    override fun supportedTasks(): Set<AlphaLocalModelTask> = AlphaLocalModelTask.entries.toSet()

    override suspend fun run(taskInput: AlphaLocalModelInput): AlphaLocalModelOutput = executor(taskInput)

    override fun estimateCostOrResourceUse(input: AlphaLocalModelInput): AlphaLocalResourceEstimate =
        AlphaLocalResourceEstimate(
            estimatedRuntimeMs = (input.sourcePack.size.coerceAtLeast(1) * 120L),
            estimatedMemoryMb = input.sourcePack.size.coerceAtLeast(1) * 6,
            notes = listOf("Deterministic development runtime estimate."),
        )

    override fun cancel(invocationId: String): Boolean = true
}

class InstalledPackLocalModelProvider(
    private val pack: AlphaInstalledPack,
) : AlphaLocalModelProvider {
    override val capabilityTier: AlphaCapabilityTier = pack.tier

    override fun isAvailable(): Boolean = false

    override fun supportedTasks(): Set<AlphaLocalModelTask> = emptySet()

    override suspend fun run(taskInput: AlphaLocalModelInput): AlphaLocalModelOutput =
        AlphaLocalModelOutput(
            rawText = "",
            parsedJson = null,
            schemaValid = false,
            warnings = listOf(
                "A future on-device runtime can use ${pack.installRelativePath}, but this alpha build still fails safely without bundling a large model."
            ),
            sourceRefs = taskInput.sourcePack.map { it.sourceRef },
        )

    override fun estimateCostOrResourceUse(input: AlphaLocalModelInput): AlphaLocalResourceEstimate =
        AlphaLocalResourceEstimate(
            estimatedRuntimeMs = 0,
            estimatedMemoryMb = 0,
            notes = listOf("Runtime unavailable; Ross will fall back deterministically or mark needs review."),
        )

    override fun cancel(invocationId: String): Boolean = false
}

object AlphaLocalModelRuntime {
    fun modeFor(pack: AlphaInstalledPack?): AlphaLocalRuntimeMode? = when {
        pack?.runtimeMode == AlphaPackRuntimeMode.DeterministicDev -> AlphaLocalRuntimeMode.DeterministicDev
        pack != null -> AlphaLocalRuntimeMode.PlatformStub
        else -> null
    }

    fun resolveProvider(
        activePack: AlphaInstalledPack?,
        requestedTier: AlphaCapabilityTier?,
        executor: suspend (AlphaLocalModelInput) -> AlphaLocalModelOutput,
    ): AlphaLocalModelProvider? = when (modeFor(activePack)) {
        AlphaLocalRuntimeMode.DeterministicDev ->
            DeterministicDevLocalModelProvider(activePack?.tier ?: requestedTier ?: AlphaCapabilityTier.QuickStart, executor)

        AlphaLocalRuntimeMode.PlatformStub ->
            activePack?.let(::InstalledPackLocalModelProvider)

        null -> null
    }
}

internal fun AlphaLocalModelInput.encodedExistingFields(
    gson: Gson,
    fields: List<AlphaExtractedLegalField>,
): AlphaLocalModelInput = copy(
    instruction = if (fields.isEmpty()) {
        instruction
    } else {
        "$instruction\nexisting_fields_json=${gson.toJson(fields)}"
    },
)

internal fun AlphaLocalModelInput.encodedClassification(
    gson: Gson,
    classification: AlphaLegalDocumentClassification?,
): AlphaLocalModelInput = copy(
    instruction = if (classification == null) {
        instruction
    } else {
        "$instruction\nclassification_json=${gson.toJson(classification)}"
    },
)
