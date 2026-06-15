import Foundation
import LlamaSwift

enum AlphaLlamaRuntimeProfile {
    private enum ArchiveProfile {
        case flash
        case e4b
        case gemma12b
        case gemma26bA4b
        case unknown
    }

    private static func containsAny(_ value: String, fragments: [String]) -> Bool {
        let lowered = value.lowercased()
        return fragments.contains { lowered.contains($0.lowercased()) }
    }

    private static func archiveProfile(forModelPath path: String?) -> ArchiveProfile {
        guard let path else { return .unknown }
        if containsAny(path, fragments: ["E2B", "e2b"]) {
            return .flash
        }
        if containsAny(path, fragments: ["26B-A4B", "26b-a4b"]) {
            return .gemma26bA4b
        }
        if containsAny(path, fragments: ["12B", "12b"]) {
            return .gemma12b
        }
        if containsAny(path, fragments: ["E4B", "e4b"]) {
            return .e4b
        }
        return .unknown
    }

    static func contextWindowTokens(forModelPath path: String?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> UInt32 {
        if physicalMemory < 6_000_000_000 {
            return 4_096
        }

        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 8_192 : 6_144
        case .e4b:
            if physicalMemory >= 12_000_000_000 {
                return 20_480
            }
            return physicalMemory >= 8_000_000_000 ? 16_384 : 10_240
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 32_768
            }
            if physicalMemory >= 12_000_000_000 {
                return 24_576
            }
            return 18_432
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 24_576
            }
            return physicalMemory >= 16_000_000_000 ? 16_384 : 10_240
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 14_336 : 10_240
        }
    }

    static func gpuLayerCount(forModelPath path: String?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Int32 {
        if physicalMemory < 6_000_000_000 {
            return 0
        }

        switch archiveProfile(forModelPath: path) {
        case .flash:
            if physicalMemory < 8_000_000_000 {
                return 20
            }
            return 40
        case .e4b:
            if physicalMemory < 8_000_000_000 {
                return 32
            }
            return 99
        case .gemma12b:
            if physicalMemory < 8_000_000_000 {
                return 24
            }
            if physicalMemory < 12_000_000_000 {
                return 56
            }
            return 99
        case .gemma26bA4b:
            if physicalMemory < 12_000_000_000 {
                return 0
            }
            if physicalMemory < 18_000_000_000 {
                return 24
            }
            return 40
        case .unknown:
            return physicalMemory < 10_000_000_000 ? 32 : 99
        }
    }

    static func maxInputChars(for tier: AlphaCapabilityTier, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Int {
        switch tier {
        case .flash:
            return 12_000
        case .quickStart:
            return physicalMemory >= 8_000_000_000 ? 30_000 : 22_000
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 56_000
            }
            return physicalMemory >= 12_000_000_000 ? 48_000 : 38_000
        case .seniorDraftingSupport:
            if physicalMemory >= 20_000_000_000 {
                return 60_000
            }
            return physicalMemory >= 16_000_000_000 ? 52_000 : 40_000
        }
    }

    static func maxNewTokens(for tier: AlphaCapabilityTier, task: AlphaLocalModelTask) -> Int32 {
        switch task {
        case .matterQuestionAnswer, .orderSummary, .chronologyGeneration, .issueExtraction, .caseMemorySynthesis:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 224
            case .caseAssociate:
                return 320
            case .seniorDraftingSupport:
                return 384
            }
        default:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 224
            case .caseAssociate:
                return 320
            case .seniorDraftingSupport:
                return 384
            }
        }
    }

    static func sourceBlockLimit(for tier: AlphaCapabilityTier) -> Int {
        switch tier {
        case .flash:
            return 4
        case .quickStart:
            return 7
        case .caseAssociate:
            return 9
        case .seniorDraftingSupport:
            return 12
        }
    }

    static func promptBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> UInt32 {
        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 1_024 : 768
        case .e4b:
            if physicalMemory >= 12_000_000_000 {
                return 2_048
            }
            return physicalMemory >= 8_000_000_000 ? 1_536 : 1_024
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 2_048
            }
            return physicalMemory >= 12_000_000_000 ? 1_536 : 1_024
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 1_536
            }
            return physicalMemory >= 16_000_000_000 ? 1_024 : 768
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 1_536 : 1_024
        }
    }

    static func physicalBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> UInt32 {
        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 768 : 512
        case .e4b:
            if physicalMemory >= 12_000_000_000 {
                return 1_536
            }
            return physicalMemory >= 8_000_000_000 ? 1_024 : 768
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 1_536
            }
            return physicalMemory >= 12_000_000_000 ? 1_024 : 768
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 1_024
            }
            return physicalMemory >= 16_000_000_000 ? 768 : 512
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 1_024 : 768
        }
    }

}

final class AlphaLlamaCppProvider: AlphaRealLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode = .llamaCppGguf
    let modelPathLabel: String?
    let modelPath: String?
    let checksumVerified: Bool
    
    init(
        capabilityTier: AlphaCapabilityTier,
        modelPathLabel: String?,
        modelPath: String?,
        checksumVerified: Bool
    ) {
        self.capabilityTier = capabilityTier
        self.modelPathLabel = modelPathLabel
        self.modelPath = modelPath
        self.checksumVerified = checksumVerified
    }
    
    func isAvailable() -> Bool {
        runtimeAvailability().available
    }

    private func runtimeAvailability() -> (available: Bool, errorCategory: String?, status: String) {
        guard let modelPath, !modelPath.isEmpty else {
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath)
        let bytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let hasMinimumBytes: Bool
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["ROSS_RUNNING_TESTS"] == "1" ||
            Bundle.allBundles.contains(where: { $0.bundlePath.hasSuffix(".xctest") }) {
            hasMinimumBytes = bytes > 0
        } else {
            hasMinimumBytes = bytes > 1_000_000
        }
        guard hasMinimumBytes else {
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        do {
            try Self.validateModelCanLoad(at: modelPath)
            return (true, nil, alphaRuntimeHealthStatus(.llamaReady))
        } catch {
            return (false, "runtime_validation_failed", alphaRuntimeHealthStatus(.llamaNeedsRepair))
        }
    }

    nonisolated(unsafe) static var modelLoadValidator: (String) throws -> Void = { path in
        _ = try LlamaContext.create_context(path: path)
    }

    nonisolated(unsafe) static var contextFactory: (String) throws -> LlamaContext = { path in
        try LlamaContext.create_context(path: path)
    }

    static func validateModelCanLoad(at modelPath: String) throws {
        guard !modelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "RossLlamaCppValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The private assistant file path is missing."]
            )
        }
        try modelLoadValidator(modelPath)
    }
    
    func supportedTasks() -> Set<AlphaLocalModelTask> {
        return Set(AlphaLocalModelTask.allCases)
    }
    
    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        let availability = runtimeAvailability()
        return AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: availability.available,
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: Array(supportedTasks()),
            maxInputChars: maxInputChars(),
            estimatedContextTokens: contextWindowEstimate(),
            accelerationMode: .standard,
            lastErrorCategory: availability.errorCategory,
            userFacingStatus: availability.status,
            explicitOptInEnabled: true
        )
    }
    
    func contextWindowEstimate() -> Int? {
        Int(AlphaLlamaRuntimeProfile.contextWindowTokens(forModelPath: modelPath))
    }
    
    func maxInputChars() -> Int? {
        AlphaLlamaRuntimeProfile.maxInputChars(for: capabilityTier)
    }
    
    nonisolated(unsafe) private static var cachedContext: LlamaContext?
    nonisolated(unsafe) private static var cachedPath: String?
    private static let cacheLock = NSLock()

    private func getOrContext(path: String) throws -> LlamaContext {
        AlphaLlamaCppProvider.cacheLock.lock()
        defer { AlphaLlamaCppProvider.cacheLock.unlock() }
        
        if let cached = AlphaLlamaCppProvider.cachedContext, AlphaLlamaCppProvider.cachedPath == path {
            return cached
        }
        
        // Clear old context if path changed
        AlphaLlamaCppProvider.cachedContext = nil
        
        let newContext = try AlphaLlamaCppProvider.contextFactory(path)
        AlphaLlamaCppProvider.cachedContext = newContext
        AlphaLlamaCppProvider.cachedPath = path
        return newContext
    }
    
    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput {
        await runInternal(taskInput, onPartial: nil)
    }

    func runStreaming(_ taskInput: AlphaLocalModelInput) -> AsyncStream<AlphaLocalModelOutput>? {
        AsyncStream { continuation in
            Task {
                let output = await self.runInternal(taskInput) { partial in
                    continuation.yield(partial)
                }
                continuation.yield(output)
                continuation.finish()
            }
        }
    }

    private func runInternal(
        _ taskInput: AlphaLocalModelInput,
        onPartial: (@Sendable (AlphaLocalModelOutput) -> Void)?
    ) async -> AlphaLocalModelOutput {
        let effectiveMaxInputChars = taskInput.promptBudgetOverrideChars ?? maxInputChars() ?? 7_000
        let pack = AlphaPromptPackBuilder(
            maxInputChars: effectiveMaxInputChars,
            sourceBlockLimit: taskInput.sourceBlockLimitOverride,
            sourceExcerptChars: taskInput.sourceExcerptCharsOverride
        ).build(input: taskInput)
        
        guard let modelPath = self.modelPath, !modelPath.isEmpty else {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: [AlphaLocalModelWarningCopy.assistantSetupMissing],
                sourceRefs: [],
                errorCategory: "model_path_missing"
            )
        }
        
        do {
            let context = try getOrContext(path: modelPath)
            await context.clear()
            let runStartedAt = Date()
            
            let usesPlainMatterAnswerPrompt = taskInput.task == .matterQuestionAnswer
            let systemPrompt = usesPlainMatterAnswerPrompt ? "" : pack.systemInstructions
            let userPrompt = pack.promptText
            let combinedPrompt: String
            if usesPlainMatterAnswerPrompt {
                // Matter chat is free-form text, and some GGUF exports already
                // carry Gemma chat-template behavior. Plain prompting avoids
                // the model echoing <start_of_turn>/<end_of_turn> markers.
                combinedPrompt = "\(userPrompt)\n"
            } else if systemPrompt.isEmpty {
                combinedPrompt = "<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            } else {
                combinedPrompt = "<start_of_turn>user\n\(systemPrompt)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            }
            
            let maxNewTokens = min(
                Int32(max(taskInput.maxOutputTokens, 1)),
                AlphaLlamaRuntimeProfile.maxNewTokens(for: capabilityTier, task: taskInput.task)
            )
            try await context.completion_init(
                text: combinedPrompt,
                maxNewTokens: maxNewTokens,
                samplerSettings: taskInput.samplerSettings ?? .legalQA
            )
            let promptTokenCount = await context.promptTokenCount()
            
            var generatedResponse = ""
            var lastPartialCount = 0
            var timeToFirstTokenMs: Int?
            let generationLoopStartedAt = Date()
            while await !context.is_done {
                let tokenStr = await context.completion_loop()
                generatedResponse += tokenStr
                let generatedTokenCount = await context.generatedTokenCount()
                if generatedTokenCount > 0, timeToFirstTokenMs == nil {
                    timeToFirstTokenMs = max(Int(Date().timeIntervalSince(runStartedAt) * 1_000), 0)
                }
                if shouldStopGeneration(afterAppending: tokenStr, fullText: generatedResponse) {
                    let strippedResponse = stripTurnMarkerFragments(from: generatedResponse)
                    if strippedResponse.isEmpty {
                        generatedResponse = ""
                        continue
                    }
                    generatedResponse = strippedResponse
                    break
                }

                if let onPartial {
                    let cleanedPartial = stripTurnMarkerFragments(from: generatedResponse)
                    if cleanedPartial.count - lastPartialCount >= 48 || tokenStr.contains("\n") {
                        lastPartialCount = cleanedPartial.count
                        let partialOutput = AlphaLocalModelOutput(
                            rawText: cleanedPartial,
                            parsedJson: nil,
                            schemaValid: false,
                            warnings: pack.truncated ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : [],
                            sourceRefs: pack.includedSourceRefs
                        )
                        onPartial(partialOutput)
                    }
                }
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > max(effectiveMaxInputChars, 12_000) { break }
            }
            let generationLoopEndedAt = Date()
            let outputTokenCount = await context.generatedTokenCount()
            let outputTokensPerSecond: Double?
            if outputTokenCount > 0 {
                let elapsedSeconds = max(generationLoopEndedAt.timeIntervalSince(generationLoopStartedAt), 0.001)
                outputTokensPerSecond = Double(outputTokenCount) / elapsedSeconds
            } else {
                outputTokensPerSecond = nil
            }
            
            let cleanedResponse = stripTurnMarkerFragments(from: generatedResponse)
            let languagePreservingFallback = usesPlainMatterAnswerPrompt
                ? Self.sourceLanguageFallbackIfNeeded(
                    for: taskInput,
                    sourcePack: pack.includedSourceBlocks,
                    generatedText: cleanedResponse
                )
                : nil
            let finalResponse = languagePreservingFallback ?? cleanedResponse
            let jsonString = languagePreservingFallback == nil ? extractJSON(from: cleanedResponse) : nil
            let schemaValid = usesPlainMatterAnswerPrompt
                ? !finalResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                : jsonString != nil
            var warnings = pack.truncated ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : []
            if languagePreservingFallback != nil {
                warnings.append(AlphaLocalModelWarningCopy.sourceLanguageFallback)
            }
            
            return AlphaLocalModelOutput(
                rawText: finalResponse,
                parsedJson: jsonString,
                schemaValid: schemaValid,
                warnings: warnings,
                sourceRefs: pack.includedSourceRefs,
                inputTokenCount: promptTokenCount,
                outputTokenCount: outputTokenCount,
                outputTokensPerSecond: outputTokensPerSecond,
                timeToFirstTokenMs: timeToFirstTokenMs
            )
        } catch {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: [AlphaLocalModelWarningCopy.assistantCouldNotFinish],
                sourceRefs: [],
                errorCategory: "inference_failed"
            )
        }
    }
    
    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalModelResourceEstimate {
        let maxChars = input.promptBudgetOverrideChars ?? maxInputChars() ?? 12_000
        let promptChars = AlphaPromptPackBuilder(
            maxInputChars: maxChars,
            sourceBlockLimit: input.sourceBlockLimitOverride,
            sourceExcerptChars: input.sourceExcerptCharsOverride
        ).build(input: input).inputChars
        let estimatedTokens = max(promptChars / 4, 1)
        let estimatedRuntimeMs = max(900, min(12_000, estimatedTokens * 6))
        let estimatedMemoryMb: Int
        switch capabilityTier {
        case .flash:
            estimatedMemoryMb = 3_500
        case .quickStart:
            estimatedMemoryMb = 5_500
        case .caseAssociate:
            estimatedMemoryMb = 8_000
        case .seniorDraftingSupport:
            estimatedMemoryMb = 14_000
        }
        return AlphaLocalModelResourceEstimate(
            inputChars: promptChars,
            estimatedTokens: estimatedTokens,
            estimatedRuntimeMs: estimatedRuntimeMs,
            estimatedMemoryMb: estimatedMemoryMb,
            estimatedDurationSeconds: max(1, estimatedRuntimeMs / 1_000),
            shouldRunNow: promptChars <= maxChars,
            reason: promptChars > maxChars ? "Prompt pack exceeded the current local budget of \(maxChars) characters." : nil,
            notes: ["Llama.cpp estimate after focused source packing."]
        )
    }
    
    func cancel(invocationID: UUID) -> Bool {
        return false // Not supported in this simplified wrapper
    }
    
    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }

    nonisolated static func sourceLanguageFallbackIfNeeded(
        for input: AlphaLocalModelInput,
        sourcePack: [AlphaSourceTextBlock]? = nil,
        generatedText: String
    ) -> String? {
        let effectiveSourcePack = (sourcePack?.isEmpty == false ? sourcePack : nil) ?? input.sourcePack
        guard !effectiveSourcePack.isEmpty else { return nil }
        let language = input.languageProfile?.primaryLanguage
        let hints = Set(effectiveSourcePack.compactMap { $0.languageHint?.lowercased() })
        if language == .bengali || hints.contains("bn") || hints.contains("bengali") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0980...0x09FF) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0980...0x09FF, heading: "উৎসভিত্তিক উত্তর")
        }
        if language == .hindi || hints.contains("hi") || hints.contains("hindi") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0900...0x097F) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0900...0x097F, heading: "स्रोत-आधारित उत्तर")
        }
        if language == .tamil || hints.contains("ta") || hints.contains("tamil") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0B80...0x0BFF) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0B80...0x0BFF, heading: "மூலத்தின் அடிப்படையிலான பதில்")
        }
        if language == .telugu || hints.contains("te") || hints.contains("telugu") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0C00...0x0C7F) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0C00...0x0C7F, heading: "మూలాల ఆధారిత సమాధానం")
        }
        return nil
    }

    private nonisolated static func extractiveMatterAnswer(
        from sourcePack: [AlphaSourceTextBlock],
        scriptRange: ClosedRange<Int>,
        heading: String
    ) -> String {
        var bullets: [String] = []
        for block in sourcePack.prefix(3) {
            let label = block.sourceRef.label
            let candidates = block.text
                .components(separatedBy: CharacterSet(charactersIn: ".।!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { sentence in
                    !sentence.isEmpty && containsUnicodeScalar(in: sentence, range: scriptRange)
                }
            for sentence in candidates.prefix(2) {
                bullets.append("- \(sentence). [\(label)]")
                if bullets.count >= 3 { break }
            }
            if bullets.count >= 3 { break }
        }
        if bullets.isEmpty, let first = sourcePack.first {
            let excerpt = first.text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            bullets.append("- \(String(excerpt.prefix(220))) [\(first.sourceRef.label)]")
        }
        return ([heading] + bullets).joined(separator: "\n")
    }

    private nonisolated static func containsUnicodeScalar(in text: String, range: ClosedRange<Int>) -> Bool {
        text.unicodeScalars.contains { scalar in
            range.contains(Int(scalar.value))
        }
    }

    private func shouldStopGeneration(afterAppending token: String, fullText: String) -> Bool {
        let stopSequences = [
            "<end_of_turn>",
            "<start_of_turn>",
            "<|endoftext|>",
            "\n\nQuestion:",
            "\nQuestion:",
            "\nUser:"
        ]
        return stopSequences.contains { token.contains($0) || fullText.hasSuffix($0) }
    }

    private func stripTurnMarkerFragments(from text: String) -> String {
        text
            .replacingOccurrences(
                of: #"(?is)(</?\s*(start|end)\s*_\s*of\s*_\s*turn\s*>|start\s*of\s*turn|end\s*of\s*turn).*$"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?is)<\s*bos\s*>"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
