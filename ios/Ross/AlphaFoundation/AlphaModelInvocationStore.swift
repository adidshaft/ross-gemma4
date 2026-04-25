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
    var promptHash: String
    var inputHash: String
    var outputHash: String?
    var inputChars: Int?
    var estimatedInputTokens: Int?
    var outputChars: Int?
    var estimatedOutputTokens: Int?
    var durationMs: Int?
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
        promptHash: String,
        inputHash: String,
        outputHash: String? = nil,
        inputChars: Int? = nil,
        estimatedInputTokens: Int? = nil,
        outputChars: Int? = nil,
        estimatedOutputTokens: Int? = nil,
        durationMs: Int? = nil,
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
        self.promptHash = promptHash
        self.inputHash = inputHash
        self.outputHash = outputHash
        self.inputChars = inputChars
        self.estimatedInputTokens = estimatedInputTokens
        self.outputChars = outputChars
        self.estimatedOutputTokens = estimatedOutputTokens
        self.durationMs = durationMs
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.errorCategory = errorCategory
        self.localOnly = localOnly
    }
}

enum AlphaModelInvocationStore {
    static func begin(
        task: AlphaLocalModelTask,
        runtimeMode: AlphaPackRuntimeMode = .deterministicDev,
        capabilityTier: AlphaCapabilityTier,
        caseId: UUID?,
        documentId: UUID?,
        extractionRunId: UUID?,
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
        copy.outputHash = sha256Hex(outputText)
        copy.outputChars = outputText.isEmpty ? 0 : outputText.count
        copy.estimatedOutputTokens = outputText.isEmpty ? 0 : max(outputText.count / 4, 1)
        copy.completedAt = completedAt
        copy.durationMs = max(Int(completedAt.timeIntervalSince(invocation.startedAt) * 1_000), 0)
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

    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
