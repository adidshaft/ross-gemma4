package com.ross.android.alpha

import java.security.MessageDigest
import java.util.UUID

data class AlphaLocalModelInvocation(
    val id: String = UUID.randomUUID().toString(),
    val task: AlphaLocalModelTask,
    val runtimeMode: String,
    val caseId: String? = null,
    val documentId: String? = null,
    val extractionRunId: String? = null,
    val capabilityTier: String,
    val inputSourceRefs: List<AlphaSourceRef>,
    val promptHash: String,
    val inputHash: String,
    val outputHash: String? = null,
    val startedAt: String = nowIso(),
    val completedAt: String? = null,
    val status: AlphaLocalModelInvocationStatus,
    val errorCategory: String? = null,
    val localOnly: Boolean = true,
)

object AlphaModelInvocationStore {
    fun begin(
        task: AlphaLocalModelTask,
        runtimeMode: AlphaPackRuntimeMode = AlphaPackRuntimeMode.DeterministicDev,
        capabilityTier: AlphaCapabilityTier,
        caseId: String?,
        documentId: String?,
        extractionRunId: String?,
        input: AlphaLocalModelInput,
    ): AlphaLocalModelInvocation = AlphaLocalModelInvocation(
        task = task,
        runtimeMode = runtimeMode.wireValue,
        caseId = caseId,
        documentId = documentId,
        extractionRunId = extractionRunId,
        capabilityTier = capabilityTier.tierId,
        inputSourceRefs = input.sourcePack.map {
            it.sourceRef.copy(
                documentTitle = "Source document",
                paragraphRange = null,
                textSnippet = null,
            )
        },
        promptHash = sha256("${input.instruction}\n${input.expectedSchema}"),
        inputHash = sha256(input.sourcePack.joinToString("|") { "${it.sourceRef.documentId}:${it.pageNumber}:${it.text.hashCode()}" }),
        status = AlphaLocalModelInvocationStatus.Running,
    )

    fun complete(
        invocation: AlphaLocalModelInvocation,
        output: AlphaLocalModelOutput,
    ): AlphaLocalModelInvocation = invocation.copy(
        outputHash = sha256(output.parsedJson ?: output.rawText),
        completedAt = nowIso(),
        status = when (output.errorCategory) {
            "cancelled" -> AlphaLocalModelInvocationStatus.Cancelled
            null -> AlphaLocalModelInvocationStatus.Complete
            else -> AlphaLocalModelInvocationStatus.Failed
        },
        errorCategory = output.errorCategory,
    )

    fun fail(
        invocation: AlphaLocalModelInvocation,
        errorCategory: String,
    ): AlphaLocalModelInvocation = invocation.copy(
        completedAt = nowIso(),
        status = AlphaLocalModelInvocationStatus.Failed,
        errorCategory = errorCategory,
    )

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray())
            .joinToString("") { "%02x".format(it) }
}
