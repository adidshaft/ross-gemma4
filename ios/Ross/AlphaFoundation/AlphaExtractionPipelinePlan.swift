import Foundation

enum AlphaExtractionPipelineFallback: String, Codable, Hashable, Sendable {
    case skip
    case deterministic
    case needsReview = "needs_review"
}

enum AlphaUserFacingExtractionQuality: String, Codable, Hashable, Sendable {
    case Basic
    case Standard
    case Advanced
}

struct AlphaExtractionPipelinePass: Codable, Hashable, Sendable {
    var task: AlphaLocalModelTask
    var required: Bool
    var maxPagesPerBatch: Int
    var fallback: AlphaExtractionPipelineFallback
}

struct AlphaExtractionPipelinePlan: Codable, Hashable, Sendable {
    var mode: AlphaExtractionMode
    var passes: [AlphaExtractionPipelinePass]
    var requiresInstalledPack: Bool
    var userFacingQuality: AlphaUserFacingExtractionQuality
}

enum AlphaExtractionPipelinePlanner {
    static func plan(for pack: AlphaInstalledModelPack?) -> AlphaExtractionPipelinePlan {
        let mode = AlphaExtractionMode.fromInstalledPack(pack)
        switch mode {
        case .basic, .flash:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .languageCorrection, required: false, maxPagesPerBatch: 8, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: 12, fallback: .deterministic)
                ],
                requiresInstalledPack: mode == .flash,
                userFacingQuality: .Basic
            )

        case .quickStart:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: false, maxPagesPerBatch: 10, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: 10, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: 10, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: 10, fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Standard
            )

        case .caseAssociate:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: true, maxPagesPerBatch: 18, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .languageCorrection, required: true, maxPagesPerBatch: 18, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: 18, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: 18, fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: 18, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .caseMemorySynthesis, required: true, maxPagesPerBatch: 24, fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Advanced
            )

        case .seniorDraftingSupport:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: true, maxPagesPerBatch: 24, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .languageCorrection, required: true, maxPagesPerBatch: 24, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: 24, fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: 24, fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: 24, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .issueExtraction, required: false, maxPagesPerBatch: 24, fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .caseMemorySynthesis, required: true, maxPagesPerBatch: 32, fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Advanced
            )
        }
    }
}
