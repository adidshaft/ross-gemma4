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
    static func plan(
        for pack: AlphaInstalledModelPack?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> AlphaExtractionPipelinePlan {
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
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: false, maxPagesPerBatch: tunedBatchPages(base: 10, task: .ocrCleanup, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: tunedBatchPages(base: 10, task: .documentClassification, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: tunedBatchPages(base: 10, task: .legalFieldExtraction, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: tunedBatchPages(base: 10, task: .legalFieldVerification, for: pack, physicalMemory: physicalMemory), fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Standard
            )

        case .caseAssociate:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: true, maxPagesPerBatch: tunedBatchPages(base: 18, task: .ocrCleanup, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .languageCorrection, required: true, maxPagesPerBatch: tunedBatchPages(base: 18, task: .languageCorrection, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: tunedBatchPages(base: 18, task: .documentClassification, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: tunedBatchPages(base: 18, task: .legalFieldExtraction, for: pack, physicalMemory: physicalMemory), fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: tunedBatchPages(base: 18, task: .legalFieldVerification, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .caseMemorySynthesis, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .caseMemorySynthesis, for: pack, physicalMemory: physicalMemory), fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Advanced
            )

        case .seniorDraftingSupport:
            return AlphaExtractionPipelinePlan(
                mode: mode,
                passes: [
                    AlphaExtractionPipelinePass(task: .ocrCleanup, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .ocrCleanup, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .languageCorrection, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .languageCorrection, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .documentClassification, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .documentClassification, for: pack, physicalMemory: physicalMemory), fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldExtraction, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .legalFieldExtraction, for: pack, physicalMemory: physicalMemory), fallback: .needsReview),
                    AlphaExtractionPipelinePass(task: .legalFieldVerification, required: true, maxPagesPerBatch: tunedBatchPages(base: 24, task: .legalFieldVerification, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .issueExtraction, required: false, maxPagesPerBatch: tunedBatchPages(base: 24, task: .issueExtraction, for: pack, physicalMemory: physicalMemory), fallback: .deterministic),
                    AlphaExtractionPipelinePass(task: .caseMemorySynthesis, required: true, maxPagesPerBatch: tunedBatchPages(base: 32, task: .caseMemorySynthesis, for: pack, physicalMemory: physicalMemory), fallback: .deterministic)
                ],
                requiresInstalledPack: true,
                userFacingQuality: .Advanced
            )
        }
    }

    private static func tunedBatchPages(
        base: Int,
        task: AlphaLocalModelTask,
        for pack: AlphaInstalledModelPack?,
        physicalMemory: UInt64
    ) -> Int {
        guard let pack else { return base }

        switch pack.runtimeMode {
        case .mlxSwiftLm:
            switch pack.tier {
            case .quickStart:
                guard physicalMemory >= 8_000_000_000 else { return base }
                return max(base, 12)
            case .caseAssociate:
                if physicalMemory >= 16_000_000_000 {
                    return task == .caseMemorySynthesis ? max(base, 30) : max(base, 24)
                }
                guard physicalMemory >= 12_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 28) : max(base, 22)
            case .seniorDraftingSupport:
                guard physicalMemory >= 16_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 36) : max(base, 28)
            case .flash:
                return base
            }
        case .appleFoundationModels:
            switch pack.tier {
            case .quickStart:
                guard physicalMemory >= 8_000_000_000 else { return base }
                return max(base, 12)
            case .caseAssociate:
                if physicalMemory >= 16_000_000_000 {
                    return task == .caseMemorySynthesis ? max(base, 28) : max(base, 22)
                }
                guard physicalMemory >= 12_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 28) : max(base, 22)
            case .seniorDraftingSupport:
                guard physicalMemory >= 16_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 34) : max(base, 26)
            case .flash:
                return base
            }
        case .llamaCppGguf:
            switch pack.tier {
            case .quickStart:
                guard physicalMemory >= 8_000_000_000 else { return base }
                return max(base, 12)
            case .caseAssociate:
                guard physicalMemory >= 12_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 26) : max(base, 20)
            case .seniorDraftingSupport:
                guard physicalMemory >= 16_000_000_000 else { return base }
                return task == .caseMemorySynthesis ? max(base, 34) : max(base, 26)
            case .flash:
                return base
            }
        case .deterministicDev, .mediapipeLlm, .unavailable:
            return base
        }
    }
}

extension AlphaExtractionPipelinePlan {
    func pass(for task: AlphaLocalModelTask) -> AlphaExtractionPipelinePass? {
        passes.first { $0.task == task }
    }
}
