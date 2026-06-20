import CryptoKit
import Foundation

struct AlphaLocalModelInvocation: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var task: AlphaLocalModelTask
    var runtimeMode: String
    var caseId: UUID?
    var documentId: UUID?
    var extractionRunId: UUID?
    var capabilityTier: String
    var inputSourceRefs: [AlphaSourceRef]
    var assistantDisplayName: String?
    var preferredRuntimeMode: String?
    var runtimeSelectionReason: String?
    var executionPathLabel: String?
    var runtimeContextTokens: Int?
    var runtimeInputBudgetChars: Int?
    var reviewedSourceCount: Int?
    var packedSourceCount: Int?
    var omittedSourceCount: Int?
    var omittedSourceLabels: [String]?
    var promptBudgetChars: Int?
    var accelerationMode: AlphaLocalRuntimeAccelerationMode?
    var accelerationDraftTokens: Int?
    var accelerationDraftModelLabel: String?
    var promptHash: String
    var inputHash: String
    var outputHash: String?
    var inputChars: Int?
    var estimatedInputTokens: Int?
    var outputChars: Int?
    var estimatedOutputTokens: Int?
    var estimatedOutputTokensPerSecond: Double?
    var durationMs: Int?
    var timeToFirstTokenMs: Int?
    var usesMeasuredTokenCounts: Bool
    var startedAt: Date
    var completedAt: Date?
    var status: AlphaLocalModelInvocationStatus
    var errorCategory: String?
    var localOnly: Bool

    init(
        id: UUID = UUID(),
        task: AlphaLocalModelTask,
        runtimeMode: String,
        caseId: UUID?,
        documentId: UUID?,
        extractionRunId: UUID?,
        capabilityTier: String,
        inputSourceRefs: [AlphaSourceRef],
        assistantDisplayName: String? = nil,
        preferredRuntimeMode: String? = nil,
        runtimeSelectionReason: String? = nil,
        executionPathLabel: String? = nil,
        runtimeContextTokens: Int? = nil,
        runtimeInputBudgetChars: Int? = nil,
        reviewedSourceCount: Int? = nil,
        packedSourceCount: Int? = nil,
        omittedSourceCount: Int? = nil,
        omittedSourceLabels: [String]? = nil,
        promptBudgetChars: Int? = nil,
        accelerationMode: AlphaLocalRuntimeAccelerationMode? = nil,
        accelerationDraftTokens: Int? = nil,
        accelerationDraftModelLabel: String? = nil,
        promptHash: String,
        inputHash: String,
        outputHash: String? = nil,
        inputChars: Int? = nil,
        estimatedInputTokens: Int? = nil,
        outputChars: Int? = nil,
        estimatedOutputTokens: Int? = nil,
        estimatedOutputTokensPerSecond: Double? = nil,
        durationMs: Int? = nil,
        timeToFirstTokenMs: Int? = nil,
        usesMeasuredTokenCounts: Bool = false,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        status: AlphaLocalModelInvocationStatus,
        errorCategory: String? = nil,
        localOnly: Bool = true
    ) {
        self.id = id
        self.task = task
        self.runtimeMode = runtimeMode
        self.caseId = caseId
        self.documentId = documentId
        self.extractionRunId = extractionRunId
        self.capabilityTier = capabilityTier
        self.inputSourceRefs = inputSourceRefs
        self.assistantDisplayName = assistantDisplayName
        self.preferredRuntimeMode = preferredRuntimeMode
        self.runtimeSelectionReason = runtimeSelectionReason
        self.executionPathLabel = executionPathLabel
        self.runtimeContextTokens = runtimeContextTokens
        self.runtimeInputBudgetChars = runtimeInputBudgetChars
        self.reviewedSourceCount = reviewedSourceCount
        self.packedSourceCount = packedSourceCount
        self.omittedSourceCount = omittedSourceCount
        self.omittedSourceLabels = omittedSourceLabels
        self.promptBudgetChars = promptBudgetChars
        self.accelerationMode = accelerationMode
        self.accelerationDraftTokens = accelerationDraftTokens
        self.accelerationDraftModelLabel = accelerationDraftModelLabel
        self.promptHash = promptHash
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.inputChars = inputChars
        self.estimatedInputTokens = estimatedInputTokens
        self.outputChars = outputChars
        self.estimatedOutputTokens = estimatedOutputTokens
        self.estimatedOutputTokensPerSecond = estimatedOutputTokensPerSecond
        self.durationMs = durationMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.usesMeasuredTokenCounts = usesMeasuredTokenCounts
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.errorCategory = errorCategory
        self.localOnly = localOnly
    }
}

enum AlphaModelInvocationStore {
    private static func documentSourceIdentity(_ sourceRef: AlphaSourceRef) -> String? {
        guard sourceRef.effectiveSourceCategory == .documentSource else { return nil }
        return [
            sourceRef.documentId.uuidString,
            String(sourceRef.pageNumber),
            sourceRef.paragraphRange ?? "",
            sourceRef.label
        ].joined(separator: "|")
    }

    static func begin(
        task: AlphaLocalModelTask,
        runtimeMode: AlphaPackRuntimeMode = .deterministicDev,
        capabilityTier: AlphaCapabilityTier,
        caseId: UUID?,
        documentId: UUID?,
        extractionRunId: UUID?,
        assistantDisplayName: String? = nil,
        preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
        runtimeSelectionReason: String? = nil,
        executionPathLabel: String? = nil,
        runtimeContextTokens: Int? = nil,
        runtimeInputBudgetChars: Int? = nil,
        accelerationMode: AlphaLocalRuntimeAccelerationMode? = nil,
        accelerationDraftTokens: Int? = nil,
        accelerationDraftModelLabel: String? = nil,
        input: AlphaLocalModelInput
    ) -> AlphaLocalModelInvocation {
        AlphaLocalModelInvocation(
            task: task,
            runtimeMode: runtimeMode.rawValue,
            caseId: caseId,
            documentId: documentId,
            extractionRunId: extractionRunId,
            capabilityTier: capabilityTier.rawValue,
            inputSourceRefs: input.sourcePack.map { sourceBlock in
                AlphaSourceRef(
                    caseId: sourceBlock.sourceRef.caseId,
                    documentId: sourceBlock.sourceRef.documentId,
                    documentTitle: "Source document",
                    pageNumber: sourceBlock.sourceRef.pageNumber,
                    paragraphRange: nil,
                    textSnippet: nil,
                    ocrConfidence: sourceBlock.sourceRef.ocrConfidence
                )
            },
            assistantDisplayName: assistantDisplayName,
            preferredRuntimeMode: preferredRuntimeMode?.rawValue,
            runtimeSelectionReason: runtimeSelectionReason,
            executionPathLabel: executionPathLabel,
            runtimeContextTokens: runtimeContextTokens,
            runtimeInputBudgetChars: runtimeInputBudgetChars,
            promptBudgetChars: input.promptBudgetOverrideChars,
            accelerationMode: accelerationMode,
            accelerationDraftTokens: accelerationDraftTokens,
            accelerationDraftModelLabel: accelerationDraftModelLabel,
            promptHash: sha256Hex("\(input.instruction)\n\(input.expectedSchema)"),
            inputHash: sha256Hex(input.sourcePack.map { "\($0.sourceRef.documentId.uuidString):\($0.pageNumber):\($0.text)" }.joined(separator: "|")),
            inputChars: input.instruction.count + input.expectedSchema.count + input.sourcePack.reduce(0) { $0 + $1.text.count },
            estimatedInputTokens: max((input.instruction.count + input.expectedSchema.count + input.sourcePack.reduce(0) { $0 + $1.text.count }) / 4, 1),
            status: .running
        )
    }

    static func complete(
        _ invocation: AlphaLocalModelInvocation,
        output: AlphaLocalModelOutput
    ) -> AlphaLocalModelInvocation {
        var copy = invocation
        let outputText = output.parsedJson ?? output.rawText
        let completedAt = Date.now
        let outputTokens = output.outputTokenCount ?? (outputText.isEmpty ? 0 : max(outputText.count / 4, 1))
        copy.outputHash = sha256Hex(outputText)
        if let executionPathLabel = output.executionPathLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !executionPathLabel.isEmpty {
            copy.executionPathLabel = executionPathLabel
        }
        if let accelerationMode = output.accelerationMode {
            copy.accelerationMode = accelerationMode
        }
        if output.accelerationMode == .draftModelSpeculative {
            copy.accelerationDraftTokens = output.accelerationDraftTokens
            if let draftModelLabel = output.accelerationDraftModelLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
               !draftModelLabel.isEmpty {
                copy.accelerationDraftModelLabel = draftModelLabel
            } else {
                copy.accelerationDraftModelLabel = nil
            }
        } else if output.accelerationMode == .standard {
            copy.accelerationDraftTokens = output.accelerationDraftTokens
            if let draftModelLabel = output.accelerationDraftModelLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
               !draftModelLabel.isEmpty {
                copy.accelerationDraftModelLabel = draftModelLabel
            } else {
                copy.accelerationDraftModelLabel = nil
            }
        }
        if let inputChars = output.inputChars {
            copy.inputChars = inputChars
        }
        copy.outputChars = outputText.isEmpty ? 0 : outputText.count
        if let inputTokenCount = output.inputTokenCount {
            copy.estimatedInputTokens = inputTokenCount
        }
        let reviewedDocumentSourceCount = Set(output.sourceRefs.compactMap {
            documentSourceIdentity($0)
        }).count
        if reviewedDocumentSourceCount > 0 {
            copy.reviewedSourceCount = reviewedDocumentSourceCount
        }
        copy.packedSourceCount = output.packedSourceCount ?? (reviewedDocumentSourceCount > 0 ? reviewedDocumentSourceCount : nil)
        copy.omittedSourceCount = output.omittedSourceCount
        copy.omittedSourceLabels = output.omittedSourceLabels?.isEmpty == false ? output.omittedSourceLabels : nil
        copy.estimatedOutputTokens = outputTokens
        copy.completedAt = completedAt
        copy.durationMs = max(Int(completedAt.timeIntervalSince(invocation.startedAt) * 1_000), 0)
        if let measuredOutputSpeed = output.outputTokensPerSecond, measuredOutputSpeed > 0 {
            copy.estimatedOutputTokensPerSecond = measuredOutputSpeed
        } else if let durationMs = copy.durationMs, durationMs > 0, outputTokens > 0 {
            copy.estimatedOutputTokensPerSecond = Double(outputTokens) / (Double(durationMs) / 1_000)
        }
        if copy.timeToFirstTokenMs == nil, let timeToFirstTokenMs = output.timeToFirstTokenMs {
            copy.timeToFirstTokenMs = timeToFirstTokenMs
        }
        copy.usesMeasuredTokenCounts = output.usesMeasuredTokenCounts
        copy.status = switch output.errorCategory {
        case "cancelled":
            .cancelled
        case nil:
            .complete
        default:
            .failed
        }
        copy.errorCategory = output.errorCategory
        return copy
    }

    static func fail(
        _ invocation: AlphaLocalModelInvocation,
        errorCategory: String
    ) -> AlphaLocalModelInvocation {
        var copy = invocation
        let completedAt = Date.now
        copy.completedAt = completedAt
        copy.durationMs = max(Int(completedAt.timeIntervalSince(invocation.startedAt) * 1_000), 0)
        copy.status = .failed
        copy.errorCategory = errorCategory
        return copy
    }

    static func recordFirstToken(
        _ invocation: AlphaLocalModelInvocation,
        at recordedAt: Date = .now
    ) -> AlphaLocalModelInvocation {
        guard invocation.timeToFirstTokenMs == nil else {
            return invocation
        }
        var copy = invocation
        copy.timeToFirstTokenMs = max(Int(recordedAt.timeIntervalSince(invocation.startedAt) * 1_000), 0)
        return copy
    }

    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

func alphaInvocationHasAdaptivePerformanceMetrics(_ invocation: AlphaLocalModelInvocation) -> Bool {
    guard invocation.status == .complete,
          invocation.timeToFirstTokenMs != nil,
          invocation.estimatedOutputTokensPerSecond != nil else {
        return false
    }
    return alphaInvocationHasSubstantivePerformanceSample(invocation)
}

func alphaInvocationHasSubstantivePerformanceSample(_ invocation: AlphaLocalModelInvocation) -> Bool {
    let inputChars = invocation.inputChars
    let outputTokens = invocation.estimatedOutputTokens
    let durationMs = invocation.durationMs
    let reviewedSourceCount = invocation.reviewedSourceCount ?? invocation.packedSourceCount

    guard inputChars != nil || outputTokens != nil || durationMs != nil || reviewedSourceCount != nil else {
        return true
    }

    let promptLooksSmall = inputChars.map { $0 < 8_000 } ?? false
    let answerLooksSmall = outputTokens.map { $0 < 160 } ?? false
    let runWasShort = durationMs.map { $0 < 2_500 } ?? false
    let sourceSetWasNarrow = reviewedSourceCount.map { $0 <= 2 } ?? false

    if promptLooksSmall && answerLooksSmall && (runWasShort || sourceSetWasNarrow) {
        return false
    }

    return true
}

func alphaInvocationLooksComparableForLargeFileExpansion(
    _ invocation: AlphaLocalModelInvocation,
    sourceBlockCount: Int,
    sourceCharCount: Int
) -> Bool {
    let reviewedSourceCount = invocation.reviewedSourceCount ?? invocation.packedSourceCount
    let inputChars = invocation.inputChars

    if reviewedSourceCount == nil && inputChars == nil {
        return true
    }

    let minimumComparableSourceCount = max(4, Int((Double(sourceBlockCount) * 0.5).rounded(.down)))
    let minimumComparableInputChars = max(12_000, Int((Double(sourceCharCount) * 0.45).rounded(.down)))

    if let reviewedSourceCount, reviewedSourceCount >= minimumComparableSourceCount {
        return true
    }
    if let inputChars, inputChars >= minimumComparableInputChars {
        return true
    }

    return false
}
