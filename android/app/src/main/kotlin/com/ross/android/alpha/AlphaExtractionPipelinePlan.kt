package com.ross.android.alpha

enum class AlphaExtractionPipelineFallback { Skip, Deterministic, NeedsReview }
enum class AlphaUserFacingExtractionQuality { Basic, Standard, Advanced }

data class AlphaExtractionPipelinePass(
    val task: AlphaLocalModelTask,
    val required: Boolean,
    val maxPagesPerBatch: Int,
    val fallback: AlphaExtractionPipelineFallback,
)

data class AlphaExtractionPipelinePlan(
    val mode: AlphaExtractionMode,
    val passes: List<AlphaExtractionPipelinePass>,
    val requiresInstalledPack: Boolean,
    val userFacingQuality: AlphaUserFacingExtractionQuality,
)

object AlphaExtractionPipelinePlanner {
    fun planFor(pack: AlphaInstalledPack?): AlphaExtractionPipelinePlan {
        val mode = AlphaExtractionMode.fromInstalledPack(pack)
        return when (mode) {
            AlphaExtractionMode.Basic -> AlphaExtractionPipelinePlan(
                mode = mode,
                passes = listOf(
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LanguageCorrection,
                        required = false,
                        maxPagesPerBatch = 8,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldVerification,
                        required = true,
                        maxPagesPerBatch = 12,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                ),
                requiresInstalledPack = false,
                userFacingQuality = AlphaUserFacingExtractionQuality.Basic,
            )

            AlphaExtractionMode.QuickStart -> AlphaExtractionPipelinePlan(
                mode = mode,
                passes = listOf(
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.OcrCleanup,
                        required = false,
                        maxPagesPerBatch = 10,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.DocumentClassification,
                        required = true,
                        maxPagesPerBatch = 10,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldExtraction,
                        required = true,
                        maxPagesPerBatch = 10,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldVerification,
                        required = true,
                        maxPagesPerBatch = 10,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                ),
                requiresInstalledPack = true,
                userFacingQuality = AlphaUserFacingExtractionQuality.Standard,
            )

            AlphaExtractionMode.CaseAssociate -> AlphaExtractionPipelinePlan(
                mode = mode,
                passes = listOf(
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.OcrCleanup,
                        required = true,
                        maxPagesPerBatch = 18,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LanguageCorrection,
                        required = true,
                        maxPagesPerBatch = 18,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.DocumentClassification,
                        required = true,
                        maxPagesPerBatch = 18,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldExtraction,
                        required = true,
                        maxPagesPerBatch = 18,
                        fallback = AlphaExtractionPipelineFallback.NeedsReview,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldVerification,
                        required = true,
                        maxPagesPerBatch = 18,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.CaseMemorySynthesis,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                ),
                requiresInstalledPack = true,
                userFacingQuality = AlphaUserFacingExtractionQuality.Advanced,
            )

            AlphaExtractionMode.SeniorDraftingSupport -> AlphaExtractionPipelinePlan(
                mode = mode,
                passes = listOf(
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.OcrCleanup,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LanguageCorrection,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.DocumentClassification,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.NeedsReview,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldExtraction,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.NeedsReview,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.LegalFieldVerification,
                        required = true,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.IssueExtraction,
                        required = false,
                        maxPagesPerBatch = 24,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                    AlphaExtractionPipelinePass(
                        task = AlphaLocalModelTask.CaseMemorySynthesis,
                        required = true,
                        maxPagesPerBatch = 32,
                        fallback = AlphaExtractionPipelineFallback.Deterministic,
                    ),
                ),
                requiresInstalledPack = true,
                userFacingQuality = AlphaUserFacingExtractionQuality.Advanced,
            )
        }
    }
}
