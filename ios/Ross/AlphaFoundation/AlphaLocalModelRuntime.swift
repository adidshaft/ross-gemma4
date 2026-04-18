import Foundation

enum AlphaLocalModelTask: String, Codable, Hashable, Sendable {
    case ocrCleanup = "ocr_cleanup"
    case languageCorrection = "language_correction"
    case documentClassification = "document_classification"
    case legalFieldExtraction = "legal_field_extraction"
    case legalFieldVerification = "legal_field_verification"
    case caseMemorySynthesis = "case_memory_synthesis"
    case chronologyGeneration = "chronology_generation"
    case orderSummary = "order_summary"
    case issueExtraction = "issue_extraction"
}

enum AlphaLocalModelInvocationStatus: String, Codable, Hashable, Sendable {
    case queued
    case running
    case complete
    case failed
    case cancelled
}

enum AlphaLocalRuntimeMode: String, Codable, Hashable, Sendable {
    case deterministicDev = "deterministic_dev"
    case platformStub = "platform_stub"
}

struct AlphaSourceTextBlock: Codable, Hashable, Sendable {
    var sourceRef: AlphaSourceRef
    var text: String
    var pageNumber: Int
    var languageHint: String?
    var ocrConfidence: Double?
}

struct AlphaLocalModelInput: Codable, Hashable, Sendable {
    var task: AlphaLocalModelTask
    var instruction: String
    var sourcePack: [AlphaSourceTextBlock]
    var expectedSchema: String
    var maxOutputTokens: Int
    var languageProfile: AlphaDocumentLanguageProfile?
    var documentClassification: AlphaLegalDocumentClassification?
    var extractionMode: AlphaExtractionMode

    func encodedExistingFields(_ fields: [AlphaExtractedLegalField], encoder: JSONEncoder) -> AlphaLocalModelInput {
        guard !fields.isEmpty, let data = try? encoder.encode(fields), let json = String(data: data, encoding: .utf8) else {
            return self
        }
        var copy = self
        copy.instruction += "\nexisting_fields_json=\(json)"
        return copy
    }

    func encodedClassification(_ classification: AlphaLegalDocumentClassification?, encoder: JSONEncoder) -> AlphaLocalModelInput {
        guard let classification, let data = try? encoder.encode(classification), let json = String(data: data, encoding: .utf8) else {
            return self
        }
        var copy = self
        copy.instruction += "\nclassification_json=\(json)"
        return copy
    }
}

struct AlphaLocalModelOutput: Codable, Hashable, Sendable {
    var rawText: String
    var parsedJson: String?
    var schemaValid: Bool
    var warnings: [String]
    var sourceRefs: [AlphaSourceRef]
}

struct AlphaLocalResourceEstimate: Codable, Hashable, Sendable {
    var estimatedRuntimeMs: Int
    var estimatedMemoryMb: Int
    var notes: [String]
}

protocol AlphaLocalModelProvider {
    var capabilityTier: AlphaCapabilityTier { get }
    func isAvailable() -> Bool
    func supportedTasks() -> Set<AlphaLocalModelTask>
    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput
    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalResourceEstimate
    func cancel(invocationID: UUID) -> Bool
}

struct DeterministicDevLocalModelProvider: AlphaLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let executor: @Sendable (AlphaLocalModelInput) async -> AlphaLocalModelOutput

    func isAvailable() -> Bool { true }

    func supportedTasks() -> Set<AlphaLocalModelTask> { Set(AlphaLocalModelTask.allCases) }

    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput {
        await executor(taskInput)
    }

    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalResourceEstimate {
        AlphaLocalResourceEstimate(
            estimatedRuntimeMs: max(input.sourcePack.count, 1) * 120,
            estimatedMemoryMb: max(input.sourcePack.count, 1) * 6,
            notes: ["Deterministic development runtime estimate."]
        )
    }

    func cancel(invocationID: UUID) -> Bool { true }
}

struct InstalledPackLocalModelProvider: AlphaLocalModelProvider {
    let pack: AlphaInstalledModelPack

    var capabilityTier: AlphaCapabilityTier { pack.tier }

    func isAvailable() -> Bool { false }

    func supportedTasks() -> Set<AlphaLocalModelTask> { [] }

    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput {
        AlphaLocalModelOutput(
            rawText: "",
            parsedJson: nil,
            schemaValid: false,
            warnings: ["A future on-device runtime can use \(pack.installPath), but this alpha build still fails safely without bundling a large model."],
            sourceRefs: taskInput.sourcePack.map(\.sourceRef)
        )
    }

    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalResourceEstimate {
        AlphaLocalResourceEstimate(
            estimatedRuntimeMs: 0,
            estimatedMemoryMb: 0,
            notes: ["Runtime unavailable; Ross will fall back deterministically or mark needs review."]
        )
    }

    func cancel(invocationID: UUID) -> Bool { false }
}

enum AlphaLocalModelRuntime {
    static func mode(for pack: AlphaInstalledModelPack?) -> AlphaLocalRuntimeMode? {
        switch pack?.runtimeMode {
        case .deterministicDev:
            .deterministicDev
        case .platformStub:
            .platformStub
        case nil:
            nil
        }
    }

    static func resolveProvider(
        activePack: AlphaInstalledModelPack?,
        requestedTier: AlphaCapabilityTier?,
        executor: @escaping @Sendable (AlphaLocalModelInput) async -> AlphaLocalModelOutput
    ) -> (any AlphaLocalModelProvider)? {
        switch mode(for: activePack) {
        case .deterministicDev:
            return DeterministicDevLocalModelProvider(capabilityTier: activePack?.tier ?? requestedTier ?? .quickStart, executor: executor)
        case .platformStub:
            return activePack.map(InstalledPackLocalModelProvider.init)
        case nil:
            return nil
        }
    }
}

extension AlphaLocalModelTask: CaseIterable {}
