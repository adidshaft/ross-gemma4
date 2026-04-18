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
        "client",
        "party",
        "petitioner",
        "respondent",
        "ocr",
        "chat history",
        "source chunk",
        "filename",
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
        val fields = case?.documents.orEmpty().flatMap { it.extractedFields }
        val issue = fields.firstOrNull { it.fieldType == AlphaExtractedLegalFieldType.Issue }?.value
        val section = fields.firstOrNull { it.fieldType == AlphaExtractedLegalFieldType.Section }?.value
        val documentType = case?.documents?.firstOrNull()?.classification?.type?.name
        val tokens = listOf(issue, section, documentType, "India")
            .filterNotNull()
            .joinToString(" ")
            .replace(Regex("\\s+"), " ")
            .trim()
        return tokens.takeIf { it.isNotBlank() }
    }
}
