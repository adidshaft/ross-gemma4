package com.ross.android.alpha

import kotlin.math.ln

internal object AlphaAskRetrieval {
    private val stopWords = setOf(
        "the", "and", "for", "with", "from", "that", "this", "what", "when",
        "where", "which", "tell", "about", "more", "detail", "can", "use",
        "into", "does", "have", "give", "please", "ross", "explain",
    )

    fun isGenericLegalDefinition(question: String): Boolean {
        val lowered = question.trim().lowercase()
        return Regex("""^(what\s+is|what\s+are|define|explain)\s+[a-z0-9 .'-]{2,}\??$""").matches(lowered) ||
            Regex("""\b(is|are)\s+.+\s+(legal|lawful|allowed)\b""").containsMatchIn(lowered)
    }

    fun questionTerms(question: String): Set<String> =
        question
            .lowercase()
            .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 && it !in stopWords }
            .toSet()

    fun rank(
        question: String,
        blocks: List<AlphaSourceTextBlock>,
        forceSelectedContext: Boolean,
        limit: Int = 8,
    ): List<AlphaSourceTextBlock> {
        if (blocks.isEmpty()) return emptyList()
        val terms = questionTerms(question)
        if (terms.isEmpty()) return if (forceSelectedContext) blocks.take(limit) else emptyList()
        val documents = blocks.map { tokenize(it.text) }
        val averageLength = documents.map { it.size }.average().takeIf { !it.isNaN() } ?: 1.0
        val documentFrequency = terms.associateWith { term ->
            documents.count { tokens -> term in tokens.toSet() }.coerceAtLeast(1)
        }
        val ranked = blocks.zip(documents).map { (block, tokens) ->
            val counts = tokens.groupingBy { it }.eachCount()
            val score = terms.sumOf { term ->
                val tf = counts[term]?.toDouble() ?: 0.0
                if (tf == 0.0) {
                    0.0
                } else {
                    val idf = ln(1.0 + ((blocks.size - documentFrequency.getValue(term) + 0.5) / (documentFrequency.getValue(term) + 0.5)))
                    val denominator = tf + 1.2 * (1.0 - 0.75 + 0.75 * (tokens.size / averageLength))
                    idf * ((tf * 2.2) / denominator)
                }
            }
            block to score
        }.sortedByDescending { it.second }
        val threshold = if (forceSelectedContext) 0.12 else 0.45
        return ranked
            .filter { it.second >= threshold }
            .take(limit)
            .map { it.first }
    }

    private fun tokenize(value: String): List<String> =
        value
            .lowercase()
            .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 && it !in stopWords }
}
