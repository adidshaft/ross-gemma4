package com.ross.android.alpha

import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

internal data class AlphaAskSourcePackPolicy(
    val sourceBlockLimit: Int = 8,
    val selectedDocumentPageLimit: Int = 4,
    val unselectedDocumentPageLimit: Int = 2,
    val preferredChunkChars: Int = 1_700,
    val overlapChars: Int = 260,
)

internal object AlphaAskRetrieval {
    private val stopWords = setOf(
        "the", "and", "for", "with", "from", "that", "this", "what", "when",
        "where", "which", "tell", "about", "more", "detail", "can", "use",
        "into", "does", "have", "give", "please", "ross", "explain",
    )

    private data class ScoredBlock(
        val block: AlphaSourceTextBlock,
        val score: Double,
    )

    private data class PageCandidate(
        val caseMatter: AlphaCaseMatter,
        val document: AlphaCaseDocument,
        val page: AlphaDocumentPage,
        val cleanedText: String,
        val score: Int,
        val documentOrder: Int,
        val pageOrder: Int,
        val isSelected: Boolean,
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
        return scoredBlocks(question, blocks, forceSelectedContext)
            .take(limit)
            .map { it.block }
    }

    fun buildSourcePack(
        question: String,
        candidateDocuments: List<Pair<AlphaCaseMatter, AlphaCaseDocument>>,
        selectedDocumentIds: Set<String>,
        policy: AlphaAskSourcePackPolicy = AlphaAskSourcePackPolicy(),
    ): List<AlphaSourceTextBlock> {
        if (candidateDocuments.isEmpty()) return emptyList()
        val terms = questionTerms(question)
        val forceSelectedContext = selectedDocumentIds.isNotEmpty()
        val pageCandidates = candidateDocuments.flatMapIndexed { documentOrder, (caseMatter, document) ->
            pageCandidatesFor(
                caseMatter = caseMatter,
                document = document,
                questionTerms = terms,
                documentOrder = documentOrder,
                isSelected = document.id in selectedDocumentIds,
                policy = policy,
            )
        }
        if (pageCandidates.isEmpty()) return emptyList()

        val blocks = pageCandidates.flatMap { candidate ->
            sourceBlocksFor(candidate, policy)
        }
        if (blocks.isEmpty()) return emptyList()

        val rankedBlocks = scoredBlocks(question, blocks, forceSelectedContext)
        if (rankedBlocks.isEmpty()) {
            return if (forceSelectedContext) {
                blocks
                    .distinctBy { sourceBlockKey(it) }
                    .take(policy.sourceBlockLimit)
            } else {
                emptyList()
            }
        }

        return if (forceSelectedContext) {
            prioritizeSelectedDocuments(
                scoredBlocks = rankedBlocks,
                allBlocks = blocks,
                selectedDocumentIds = selectedDocumentIds,
                policy = policy,
            )
        } else {
            balanceAcrossDocuments(rankedBlocks, policy.sourceBlockLimit)
        }
    }

    private fun scoredBlocks(
        question: String,
        blocks: List<AlphaSourceTextBlock>,
        forceSelectedContext: Boolean,
    ): List<ScoredBlock> {
        if (blocks.isEmpty()) return emptyList()
        val terms = questionTerms(question)
        if (terms.isEmpty()) {
            return if (forceSelectedContext) {
                blocks.map { ScoredBlock(it, 1.0) }
            } else {
                emptyList()
            }
        }
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
            ScoredBlock(block = block, score = score)
        }.sortedByDescending { it.score }
        val threshold = if (forceSelectedContext) 0.12 else 0.45
        val filtered = ranked.filter { it.score >= threshold }
        if (filtered.isNotEmpty()) {
            return filtered
        }
        return ranked
            .filter { it.score > 0.0 }
    }

    private fun pageCandidatesFor(
        caseMatter: AlphaCaseMatter,
        document: AlphaCaseDocument,
        questionTerms: Set<String>,
        documentOrder: Int,
        isSelected: Boolean,
        policy: AlphaAskSourcePackPolicy,
    ): List<PageCandidate> {
        val pages = document.pages.ifEmpty {
            listOf(
                AlphaDocumentPage(
                    pageNumber = 1,
                    snippet = document.dominantSourceSnippet ?: compactSnippet(document.extractedText),
                )
            )
        }
        val candidates = pages.mapIndexedNotNull { pageOrder, page ->
            val text = page.extractedText
                ?: page.anchorText
                ?: page.snippet
                ?: document.dominantSourceSnippet
                ?: document.extractedText
                ?: return@mapIndexedNotNull null
            val cleanedText = text.trim()
            if (cleanedText.isBlank()) return@mapIndexedNotNull null
            PageCandidate(
                caseMatter = caseMatter,
                document = document,
                page = page,
                cleanedText = cleanedText,
                score = pageRelevanceScore(questionTerms, document, page, cleanedText),
                documentOrder = documentOrder,
                pageOrder = pageOrder,
                isSelected = isSelected,
            )
        }
        if (candidates.isEmpty()) return emptyList()

        val ranked = candidates.sortedWith(
            compareByDescending<PageCandidate> { it.score }
                .thenBy { it.pageOrder }
        )
        val pageLimit = if (isSelected) policy.selectedDocumentPageLimit else policy.unselectedDocumentPageLimit
        val limited = when {
            ranked.size <= pageLimit -> ranked
            questionTerms.isEmpty() && isSelected -> candidates.take(pageLimit)
            ranked.any { it.score > 0 } -> ranked.take(pageLimit)
            isSelected -> candidates.take(pageLimit)
            else -> candidates.take(1)
        }
        return limited.sortedWith(compareBy<PageCandidate> { it.documentOrder }.thenBy { it.pageOrder })
    }

    private fun pageRelevanceScore(
        questionTerms: Set<String>,
        document: AlphaCaseDocument,
        page: AlphaDocumentPage,
        cleanedText: String,
    ): Int {
        if (questionTerms.isEmpty()) return 0
        val titleHaystack = document.title.lowercase()
        val pageHaystack = buildString {
            append(page.snippet.orEmpty())
            append(' ')
            append(page.anchorText.orEmpty())
            append(' ')
            append(cleanedText.take(4_000))
        }.lowercase()
        var score = 0
        for (term in questionTerms) {
            if (titleHaystack.contains(term)) {
                score += 8
            }
            if (pageHaystack.contains(term)) {
                score += if (term.length >= 6) 7 else 4
            }
        }
        return score
    }

    private fun sourceBlocksFor(
        candidate: PageCandidate,
        policy: AlphaAskSourcePackPolicy,
    ): List<AlphaSourceTextBlock> {
        val allowsChunking = candidate.isSelected || candidate.cleanedText.length > (policy.preferredChunkChars + 400)
        val segments = sourceSegments(
            text = candidate.cleanedText,
            allowsChunking = allowsChunking,
            preferredChunkChars = policy.preferredChunkChars,
            overlapChars = policy.overlapChars,
        )
        return segments.mapIndexed { index, segment ->
            AlphaSourceTextBlock(
                sourceRef = AlphaSourceRef(
                    caseId = candidate.caseMatter.id,
                    documentId = candidate.document.id,
                    documentTitle = candidate.document.title,
                    pageNumber = candidate.page.pageNumber,
                    paragraphRange = if (segments.size > 1) "chunk ${index + 1}/${segments.size}" else null,
                    textSnippet = candidate.page.anchorText
                        ?: candidate.page.snippet
                        ?: compactSnippet(segment),
                    ocrConfidence = candidate.page.ocrConfidence,
                ),
                text = segment,
                pageNumber = candidate.page.pageNumber,
                languageHint = candidate.document.languageProfile
                    ?.pageProfiles
                    ?.firstOrNull { it.pageNumber == candidate.page.pageNumber }
                    ?.language
                    ?.name
                    ?.lowercase(),
                ocrConfidence = candidate.page.ocrConfidence,
            )
        }
    }

    private fun sourceSegments(
        text: String,
        allowsChunking: Boolean,
        preferredChunkChars: Int,
        overlapChars: Int,
    ): List<String> {
        val cleaned = text.trim()
        if (!allowsChunking || cleaned.length <= preferredChunkChars + 240) {
            return listOf(cleaned)
        }

        val segments = mutableListOf<String>()
        var start = 0
        while (start < cleaned.length) {
            val maxEnd = min(start + preferredChunkChars, cleaned.length)
            var end = maxEnd
            if (maxEnd < cleaned.length) {
                val searchStart = min(cleaned.length - 1, start + max(preferredChunkChars / 2, 1))
                val newlineBreak = cleaned.lastIndexOf('\n', startIndex = maxEnd)
                val sentenceBreak = cleaned.lastIndexOf('.', startIndex = maxEnd)
                val whitespaceBreak = cleaned.lastIndexOf(' ', startIndex = maxEnd)
                val candidateBreak = listOf(newlineBreak, sentenceBreak, whitespaceBreak)
                    .filter { it >= searchStart }
                    .maxOrNull()
                if (candidateBreak != null && candidateBreak > start) {
                    end = candidateBreak + 1
                }
            }
            val segment = cleaned.substring(start, end).trim()
            if (segment.isNotEmpty()) {
                segments += segment
            }
            if (end >= cleaned.length) break
            start = max(end - overlapChars, start + 1)
        }
        return if (segments.isEmpty()) listOf(cleaned) else segments
    }

    private fun prioritizeSelectedDocuments(
        scoredBlocks: List<ScoredBlock>,
        allBlocks: List<AlphaSourceTextBlock>,
        selectedDocumentIds: Set<String>,
        policy: AlphaAskSourcePackPolicy,
    ): List<AlphaSourceTextBlock> {
        val groupedRanked = scoredBlocks.groupBy { it.block.sourceRef.documentId }
        val groupedAllBlocks = allBlocks.groupBy { it.sourceRef.documentId }
        val prioritized = mutableListOf<AlphaSourceTextBlock>()
        val seenKeys = mutableSetOf<String>()

        fun appendIfNeeded(block: AlphaSourceTextBlock?) {
            if (block == null) return
            val key = sourceBlockKey(block)
            if (seenKeys.add(key)) {
                prioritized += block
            }
        }

        for (documentId in selectedDocumentIds) {
            appendIfNeeded(groupedRanked[documentId]?.firstOrNull()?.block ?: groupedAllBlocks[documentId]?.firstOrNull())
        }
        for (candidate in scoredBlocks) {
            appendIfNeeded(candidate.block)
            if (prioritized.size >= policy.sourceBlockLimit) break
        }
        return prioritized.take(policy.sourceBlockLimit)
    }

    private fun balanceAcrossDocuments(
        scoredBlocks: List<ScoredBlock>,
        limit: Int,
    ): List<AlphaSourceTextBlock> {
        val grouped = linkedMapOf<String, MutableList<AlphaSourceTextBlock>>()
        for (candidate in scoredBlocks) {
            grouped.getOrPut(candidate.block.sourceRef.documentId) { mutableListOf() }
                .add(candidate.block)
        }

        val balanced = mutableListOf<AlphaSourceTextBlock>()
        val seenKeys = mutableSetOf<String>()
        var level = 0
        while (balanced.size < limit) {
            var appendedAny = false
            for (blocks in grouped.values) {
                val block = blocks.getOrNull(level) ?: continue
                val key = sourceBlockKey(block)
                if (seenKeys.add(key)) {
                    balanced += block
                    appendedAny = true
                    if (balanced.size >= limit) break
                }
            }
            if (!appendedAny) break
            level += 1
        }
        return balanced
    }

    private fun sourceBlockKey(block: AlphaSourceTextBlock): String =
        listOf(
            block.sourceRef.documentId,
            block.pageNumber.toString(),
            block.sourceRef.paragraphRange.orEmpty(),
            block.text,
        ).joinToString("|")

    private fun compactSnippet(text: String?, limit: Int = 180): String? {
        val cleaned = text?.replace(Regex("\\s+"), " ")?.trim().orEmpty()
        if (cleaned.isBlank()) return null
        return if (cleaned.length <= limit) cleaned else cleaned.take(limit).trimEnd() + "..."
    }

    private fun tokenize(value: String): List<String> =
        value
            .lowercase()
            .replace(Regex("[^\\p{L}\\p{N}\\s]"), " ")
            .split(Regex("\\s+"))
            .map { it.trim() }
            .filter { it.length >= 3 && it !in stopWords }
}
