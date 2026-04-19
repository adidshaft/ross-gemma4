package com.ross.android.alpha

import com.google.gson.Gson

data class AlphaVerificationPayload(
    val fields: List<AlphaExtractedLegalField>,
    val findings: List<AlphaExtractionFinding>,
)

object AlphaModelOutputValidator {
    fun extractJsonCandidate(rawText: String): String? {
        val raw = rawText.trim()
        if (raw.isEmpty()) {
            return null
        }
        if ((raw.startsWith("{") && raw.endsWith("}")) || (raw.startsWith("[") && raw.endsWith("]"))) {
            return raw
        }
        listOf("```json", "```").forEach { fence ->
            val start = raw.indexOf(fence)
            if (start >= 0) {
                val afterFence = raw.substring(start + fence.length)
                val end = afterFence.indexOf("```")
                if (end > 0) {
                    val candidate = afterFence.substring(0, end).trim()
                    if ((candidate.startsWith("{") && candidate.endsWith("}")) || (candidate.startsWith("[") && candidate.endsWith("]"))) {
                        return candidate
                    }
                }
            }
        }
        val arrayStart = raw.indexOf('[')
        val arrayEnd = raw.lastIndexOf(']')
        if (arrayStart >= 0 && arrayEnd > arrayStart) {
            return raw.substring(arrayStart, arrayEnd + 1)
        }
        val objectStart = raw.indexOf('{')
        val objectEnd = raw.lastIndexOf('}')
        if (objectStart >= 0 && objectEnd > objectStart) {
            return raw.substring(objectStart, objectEnd + 1)
        }
        return null
    }

    fun repairedJson(output: AlphaLocalModelOutput): String? {
        output.parsedJson?.let { return it }
        return extractJsonCandidate(output.rawText)
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
