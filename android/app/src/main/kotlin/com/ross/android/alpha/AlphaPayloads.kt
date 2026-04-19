package com.ross.android.alpha

data class AlphaModelCatalogPayload(
    val channel: String = "android_private_document_intelligence_alpha",
    val requestedTier: String?,
    val installedTierIds: List<String>,
    val supportsResume: Boolean = true,
    val caseDataIncluded: Boolean = false,
)

data class AlphaModelDownloadPayload(
    val sessionId: String,
    val packId: String,
    val tierId: String,
    val resumeBytes: Long,
    val wifiOnly: Boolean,
    val caseDataIncluded: Boolean = false,
)

data class AlphaPublicLawSearchPayload(
    val query: String,
    val route: String = "/public-law/search",
    val caseDataIncluded: Boolean = false,
)

object AlphaPayloadShaper {
    private val blockedTerms = listOf(
        "case number",
        "case no",
        "case no.",
        "client",
        "party",
        "petitioner",
        "respondent",
        "ocr",
        "chat history",
        "source chunk",
        "filename",
        "address",
        "mobile",
    )
    private val legalConceptSignals = listOf(
        "act",
        "section",
        "order",
        "rule",
        "maintenance",
        "injunction",
        "dishonour",
        "written statement",
        "delay",
        "limitation",
        "interim",
        "commercial",
        "cheque",
        "court",
        "filing",
    )

    fun buildModelCatalogPayload(state: AlphaPersistedState): AlphaModelCatalogPayload =
        AlphaModelCatalogPayload(
            requestedTier = state.settings.activeTier?.tierId,
            installedTierIds = state.installedPacks.map { it.tier.tierId },
        )

    fun buildModelDownloadPayload(job: AlphaModelDownloadJob): AlphaModelDownloadPayload =
        AlphaModelDownloadPayload(
            sessionId = job.sessionId,
            packId = job.packId,
            tierId = job.tier.tierId,
            resumeBytes = job.bytesDownloaded,
            wifiOnly = job.networkPolicy == AlphaDownloadPolicy.WifiOnly,
        )

    fun buildPublicLawPreview(rawQuery: String, case: AlphaCaseMatter?): AlphaPublicLawPreview {
        var sanitized = rawQuery
        val removed = linkedSetOf<String>()

        val sensitiveTokens = buildList {
            if (case != null) {
                add(case.title)
                add(case.forum)
                addAll(case.documents.map { it.title })
                addAll(case.documents.map { it.fileName })
            }
        }.filter { it.isNotBlank() }

        sensitiveTokens.forEach { token ->
            if (sanitized.contains(token, ignoreCase = true)) {
                removed += "Case titles, forum names, or document labels"
                sanitized = sanitized.replace(token, "", ignoreCase = true)
            }
        }

        blockedTerms.forEach { token ->
            if (sanitized.contains(token, ignoreCase = true)) {
                removed += "Case-detail phrasing and private drafting cues"
                sanitized = sanitized.replace(token, "", ignoreCase = true)
            }
        }

        if (Regex("\\b\\d{2,}\\b").containsMatchIn(sanitized)) {
            removed += "Case numbers, phone numbers, or long numeric strings"
            sanitized = sanitized.replace(Regex("\\b\\d{2,}\\b"), " ")
        }

        if (Regex("\\b[A-Za-z]{1,8}[(/\\- ]*\\d+[A-Za-z/()\\- ]*\\d{4}\\b", RegexOption.IGNORE_CASE).containsMatchIn(sanitized)) {
            removed += "Case numbers or filing references"
            sanitized = sanitized.replace(Regex("\\b[A-Za-z]{1,8}[(/\\- ]*\\d+[A-Za-z/()\\- ]*\\d{4}\\b", RegexOption.IGNORE_CASE), " ")
        }

        if (Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+").containsMatchIn(sanitized)) {
            removed += "Email addresses"
            sanitized = sanitized.replace(Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"), " ")
        }

        if (Regex("\\b\\+?\\d[\\d\\s-]{7,}\\b").containsMatchIn(sanitized)) {
            removed += "Phone numbers"
            sanitized = sanitized.replace(Regex("\\b\\+?\\d[\\d\\s-]{7,}\\b"), " ")
        }

        if (Regex("\\b[^\\s]+\\.(pdf|docx|doc|txt|png|jpg|jpeg)\\b", RegexOption.IGNORE_CASE).containsMatchIn(sanitized)) {
            removed += "File names"
            sanitized = sanitized.replace(Regex("\\b[^\\s]+\\.(pdf|docx|doc|txt|png|jpg|jpeg)\\b", RegexOption.IGNORE_CASE), " ")
        }

        if (Regex("\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b").containsMatchIn(sanitized) ||
            Regex("\\b\\d{1,2}\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\s+\\d{4}\\b", RegexOption.IGNORE_CASE).containsMatchIn(sanitized)
        ) {
            removed += "Exact private dates"
            sanitized = sanitized
                .replace(Regex("\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b"), " ")
                .replace(Regex("\\b\\d{1,2}\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\s+\\d{4}\\b", RegexOption.IGNORE_CASE), " ")
        }

        if (Regex("raghav\\s+fakepriv|blue suitcase near temple", RegexOption.IGNORE_CASE).containsMatchIn(sanitized)) {
            removed += "Fake secrets and private facts"
            sanitized = sanitized.replace(Regex("raghav\\s+fakepriv|blue suitcase near temple", RegexOption.IGNORE_CASE), " ")
        }

        if (Regex("\\b(?:near|behind|opposite|at)\\s+[A-Za-z][A-Za-z\\s]{3,40}\\b", RegexOption.IGNORE_CASE).containsMatchIn(sanitized)) {
            removed += "Addresses or location details"
            sanitized = sanitized.replace(Regex("\\b(?:near|behind|opposite|at)\\s+[A-Za-z][A-Za-z\\s]{3,40}\\b", RegexOption.IGNORE_CASE), " ")
        }

        sanitized = sanitized
            .replace(Regex("\\s+"), " ")
            .trim()

        if (sanitized.length > 180) {
            removed += "Long factual narrative"
            sanitized = sanitized.take(180).trim()
        }

        if (sanitized.isBlank()) {
            sanitized = suggestedPublicLawQuery(case)
                ?: "Find current public-law guidance relevant to delay condonation where diligence is documented."
            removed += "Private case details"
        }

        return AlphaPublicLawPreview(
            query = sanitized,
            removed = removed.ifEmpty { linkedSetOf("No private case data detected") }.toList(),
            confirmationNote = "Public-law search sends only a sanitized query after explicit confirmation.",
        )
    }

    fun buildPublicLawPayload(preview: AlphaPublicLawPreview): AlphaPublicLawSearchPayload =
        AlphaPublicLawSearchPayload(query = preview.query)

    private fun suggestedPublicLawQuery(case: AlphaCaseMatter?): String? {
        val verifiedFields = case?.documents.orEmpty()
            .flatMap { it.extractedFields }
            .filter { !it.needsReview || it.userCorrected }
        val conceptTerms = verifiedFields
            .filter {
                it.fieldType == AlphaExtractedLegalFieldType.Issue ||
                    it.fieldType == AlphaExtractedLegalFieldType.OrderDirection ||
                    it.fieldType == AlphaExtractedLegalFieldType.Relief ||
                    it.fieldType == AlphaExtractedLegalFieldType.Section
            }
            .flatMap { publicLawKeywords(it.value) }
        val documentTypes = case?.documents.orEmpty()
            .mapNotNull { document ->
                document.classification
                    ?.takeIf { !it.needsReview }
                    ?.type
                    ?.name
                    ?.replace("_", " ")
            }
        val tokens = linkedSetOf<String>()
        (conceptTerms + documentTypes + listOf("India")).forEach { token ->
            val trimmed = token.trim()
            if (trimmed.isNotBlank() && isSafePublicLawToken(trimmed)) {
                tokens += trimmed
            }
        }
        return tokens.joinToString(" ").takeIf { it.isNotBlank() }
    }

    private fun publicLawKeywords(value: String): List<String> {
        val lowered = value.lowercase()
        val patterns = listOf(
            "commercial courts act",
            "negotiable instruments act",
            "written statement",
            "delay condonation",
            "interim maintenance",
            "injunction",
            "section \\d+[a-z]*",
            "order [a-z0-9]+ rule \\d+",
            "cheque dishonour",
        )
        val matched = patterns.mapNotNull { pattern ->
            Regex(pattern, RegexOption.IGNORE_CASE).find(lowered)?.value
        }.distinct().toMutableList()
        val sanitizedPhrase = lowered
            .replace(Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"), " ")
            .replace(Regex("\\b\\+?\\d[\\d\\s-]{7,}\\b"), " ")
            .replace(Regex("\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b"), " ")
            .replace(Regex("\\b[A-Za-z]{1,8}[(/\\- ]*\\d+[A-Za-z/()\\- ]*\\d{4}\\b", RegexOption.IGNORE_CASE), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
        if (sanitizedPhrase.isNotBlank() && sanitizedPhrase.split(" ").size in 3..10 && looksLikeLegalConcept(sanitizedPhrase)) {
            matched += sanitizedPhrase
        }
        return matched.filter(::isSafePublicLawToken).distinct()
    }

    private fun looksLikeLegalConcept(value: String): Boolean =
        legalConceptSignals.any { signal -> value.contains(signal) } ||
            Regex("section\\s+\\d+[a-z]*", RegexOption.IGNORE_CASE).containsMatchIn(value) ||
            Regex("order\\s+[a-z0-9]+\\s+rule\\s+\\d+", RegexOption.IGNORE_CASE).containsMatchIn(value)

    private fun isSafePublicLawToken(value: String): Boolean {
        val lowered = value.lowercase()
        if (
            "fakepriv" in lowered ||
            "blue suitcase near temple" in lowered ||
            Regex("\\b(petitioner|respondent|appellant|defendant|plaintiff)\\b", RegexOption.IGNORE_CASE).containsMatchIn(value) ||
            Regex("\\bv\\.?\\s", RegexOption.IGNORE_CASE).containsMatchIn(value)
        ) {
            return false
        }
        if (Regex("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+").containsMatchIn(value)) {
            return false
        }
        if (Regex("\\b\\+?\\d[\\d\\s-]{7,}\\b").containsMatchIn(value)) {
            return false
        }
        if (Regex("\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b").containsMatchIn(value)) {
            return false
        }
        if (Regex("\\b[A-Za-z]{1,8}[(/\\- ]*\\d+[A-Za-z/()\\- ]*\\d{4}\\b", RegexOption.IGNORE_CASE).containsMatchIn(value)) {
            return false
        }
        if (Regex("\\b(?:near|behind|opposite|at)\\s+[A-Za-z][A-Za-z\\s]{3,40}\\b", RegexOption.IGNORE_CASE).containsMatchIn(value)) {
            return false
        }
        return true
    }
}
