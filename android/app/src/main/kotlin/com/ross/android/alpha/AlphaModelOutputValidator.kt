package com.ross.android.alpha

import com.google.gson.Gson

data class AlphaVerificationPayload(
    val fields: List<AlphaExtractedLegalField>,
    val findings: List<AlphaExtractionFinding>,
)

object AlphaModelOutputValidator {
    fun repairedJson(output: AlphaLocalModelOutput): String? {
        output.parsedJson?.let { return it }
        val raw = output.rawText.trim()
        return when {
            raw.startsWith("{") && raw.endsWith("}") -> raw
            raw.startsWith("[") && raw.endsWith("]") -> raw
            else -> null
        }
    }

    fun parseClassification(gson: Gson, output: AlphaLocalModelOutput): AlphaLegalDocumentClassification? =
        repairedJson(output)?.let { runCatching { gson.fromJson(it, AlphaLegalDocumentClassification::class.java) }.getOrNull() }

    fun parseFields(gson: Gson, output: AlphaLocalModelOutput): List<AlphaExtractedLegalField> =
        repairedJson(output)
            ?.let { json ->
                runCatching {
                    gson.fromJson(json, Array<AlphaExtractedLegalField>::class.java)?.toList().orEmpty()
                }.getOrDefault(emptyList())
            }
            .orEmpty()

    fun parseVerification(gson: Gson, output: AlphaLocalModelOutput): AlphaVerificationPayload? =
        repairedJson(output)?.let { runCatching { gson.fromJson(it, AlphaVerificationPayload::class.java) }.getOrNull() }

    fun parseCaseMemory(gson: Gson, output: AlphaLocalModelOutput): List<AlphaCaseMemoryUpdate> =
        repairedJson(output)
            ?.let { json ->
                runCatching {
                    gson.fromJson(json, Array<AlphaCaseMemoryUpdate>::class.java)?.toList().orEmpty()
                }.getOrDefault(emptyList())
            }
            .orEmpty()

    fun fieldsHaveSourceRefs(fields: List<AlphaExtractedLegalField>): Boolean =
        fields.all { it.sourceRefs.isNotEmpty() }
}
