package com.ross.android.alpha

data class AlphaResolvedSourcePanel(
    val resolvedPage: Int,
    val pageCount: Int,
    val currentPageRefs: List<AlphaSourceRef>,
    val otherRefs: List<AlphaSourceRef>,
    val fallbackMessage: String?,
)

object AlphaSourceNavigator {
    fun resolve(
        document: AlphaCaseDocument?,
        refs: List<AlphaSourceRef>,
        requestedPage: Int?,
    ): AlphaResolvedSourcePanel {
        val pageCount = document?.pageCount?.takeIf { it > 0 }
            ?: refs.maxOfOrNull { it.pageNumber }?.coerceAtLeast(1)
            ?: 1
        val resolvedPage = (requestedPage ?: refs.firstOrNull()?.pageNumber ?: 1).coerceIn(1, pageCount)
        val currentPageRefs = refs.filter { it.pageNumber == resolvedPage }
        val otherRefs = refs.filterNot { it.pageNumber == resolvedPage }
        val fallbackMessage = when {
            document == null -> "This source is not available on the device anymore. Ross will still show the last saved source metadata."
            refs.isEmpty() -> "No pinned source excerpt is available for this document yet. Ross will keep page and extracted-text context visible."
            currentPageRefs.isEmpty() -> "No pinned source excerpt is stored for page $resolvedPage yet. Ross will show the nearest available source metadata."
            else -> null
        }

        return AlphaResolvedSourcePanel(
            resolvedPage = resolvedPage,
            pageCount = pageCount,
            currentPageRefs = currentPageRefs,
            otherRefs = otherRefs,
            fallbackMessage = fallbackMessage,
        )
    }
}
