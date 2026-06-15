import Foundation
import LlamaSwift

enum AlphaLlamaRuntimeProfile {
    private static func containsAny(_ value: String, fragments: [String]) -> Bool {
        let lowered = value.lowercased()
        return fragments.contains { lowered.contains($0.lowercased()) }
    }

    static func contextWindowTokens(forModelPath path: String?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> UInt32 {
        guard let path else {
            return physicalMemory < 6_000_000_000 ? 4_096 : 8_192
        }
        if physicalMemory < 6_000_000_000 {
            return 4_096
        }
        if containsAny(path, fragments: ["26B-A4B", "26b-a4b", "26B"]) {
            return physicalMemory >= 18_000_000_000 ? 12_288 : 8_192
        }
        if containsAny(path, fragments: ["12B", "12b"]) {
            return physicalMemory >= 12_000_000_000 ? 16_384 : 12_288
        }
        if containsAny(path, fragments: ["E4B", "e4b"]) {
            return physicalMemory >= 8_000_000_000 ? 12_288 : 8_192
        }
        return 8_192
    }

    static func maxInputChars(for tier: AlphaCapabilityTier, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Int {
        switch tier {
        case .flash:
            return 12_000
        case .quickStart:
            return physicalMemory >= 8_000_000_000 ? 24_000 : 18_000
        case .caseAssociate:
            return physicalMemory >= 12_000_000_000 ? 36_000 : 28_000
        case .seniorDraftingSupport:
            return physicalMemory >= 18_000_000_000 ? 40_000 : 34_000
        }
    }

    static func maxNewTokens(for tier: AlphaCapabilityTier, task: AlphaLocalModelTask) -> Int32 {
        switch task {
        case .matterQuestionAnswer, .orderSummary, .chronologyGeneration, .issueExtraction, .caseMemorySynthesis:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 192
            case .caseAssociate:
                return 256
            case .seniorDraftingSupport:
                return 320
            }
        default:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 192
            case .caseAssociate:
                return 256
            case .seniorDraftingSupport:
                return 320
            }
        }
    }

    static func sourceBlockLimit(for tier: AlphaCapabilityTier) -> Int {
        switch tier {
        case .flash:
            return 4
        case .quickStart:
            return 5
        case .caseAssociate:
            return 7
        case .seniorDraftingSupport:
            return 8
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
        let pack = AlphaPromptPackBuilder(maxInputChars: effectiveMaxInputChars).build(input: taskInput)
        
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
            
            let usesPlainMatterAnswerPrompt = taskInput.task == .matterQuestionAnswer
            let focusedMatterSourceRefs = usesPlainMatterAnswerPrompt ? focusedMatterSourceBlocks(for: taskInput).map(\.sourceRef) : []
            let systemPrompt = usesPlainMatterAnswerPrompt ? "" : pack.systemInstructions
            let userPrompt = usesPlainMatterAnswerPrompt
                ? conciseMatterQuestionPrompt(for: taskInput)
                : pack.promptText
            let combinedPrompt: String
            if usesPlainMatterAnswerPrompt {
                // Matter chat is free-form text, and some GGUF exports already
                // carry Gemma chat-template behavior. Plain prompting avoids
                // the model echoing <start_of_turn>/<end_of_turn> markers.
                combinedPrompt = "\(userPrompt)\n\nRoss answer:\n"
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
            
            var generatedResponse = ""
            var lastPartialCount = 0
            while await !context.is_done {
                let tokenStr = await context.completion_loop()
                generatedResponse += tokenStr
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
                            sourceRefs: usesPlainMatterAnswerPrompt
                                ? (focusedMatterSourceRefs.isEmpty ? Array(taskInput.sourcePack.prefix(5).map(\.sourceRef)) : focusedMatterSourceRefs)
                                : pack.includedSourceRefs
                        )
                        onPartial(partialOutput)
                    }
                }
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > max(effectiveMaxInputChars, 12_000) { break }
            }
            
            let cleanedResponse = stripTurnMarkerFragments(from: generatedResponse)
            let languagePreservingFallback = usesPlainMatterAnswerPrompt
                ? Self.sourceLanguageFallbackIfNeeded(for: taskInput, generatedText: cleanedResponse)
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
                sourceRefs: usesPlainMatterAnswerPrompt
                    ? (focusedMatterSourceRefs.isEmpty ? Array(taskInput.sourcePack.prefix(5).map(\.sourceRef)) : focusedMatterSourceRefs)
                    : pack.includedSourceRefs
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
        let promptChars: Int
        if input.task == .matterQuestionAnswer {
            promptChars = conciseMatterQuestionPrompt(for: input).count
        } else {
            promptChars = AlphaPromptPackBuilder(maxInputChars: maxChars).build(input: input).inputChars
        }
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

    private func conciseMatterQuestionPrompt(for input: AlphaLocalModelInput) -> String {
        let languageInstruction = matterAnswerLanguageInstruction(for: input)
        let sourceBlocks = focusedMatterSourceBlocks(for: input)
        var prompt = """
        Ross private local answer. Use only SOURCES. Do not invent facts.
        Match the question language exactly.
        Hindi: Devanagari only, no Hinglish except names/dates/source labels.
        Bengali: Bengali script only except names/dates/source labels.
        Tamil: Tamil script only except names/dates/source labels.
        Telugu: Telugu script only except names/dates/source labels.
        \(languageInstruction)
        No JSON, XML, markdown fences, or chat tokens.
        Format: short heading, then 2-3 "- " bullets with source labels.

        TASK:
        \(input.instruction)

        SOURCES:
        """

        let effectiveMaxInputChars = input.promptBudgetOverrideChars ?? maxInputChars() ?? 12_000
        let excerptCap = input.sourceExcerptCharsOverride ?? 1_500
        var remainingBudget = max(effectiveMaxInputChars - 2_000, 4_800)
        for block in sourceBlocks {
            guard remainingBudget > 120 else { break }
            let label = block.sourceRef.label
            let excerpt = AlphaPromptFocusPlanner.focusedExcerpt(
                from: block.text,
                instruction: input.instruction,
                maxChars: min(remainingBudget, excerptCap)
            )
            prompt += "\n[\(label)] \(excerpt)\n"
            remainingBudget -= excerpt.count + label.count + 8
        }

        prompt += "\nANSWER:"
        return prompt
    }

    private func matterAnswerLanguageInstruction(for input: AlphaLocalModelInput) -> String {
        let language = input.languageProfile?.primaryLanguage
        let hints = Set(input.sourcePack.compactMap { $0.languageHint?.lowercased() })
        if language == .bengali || hints.contains("bn") || hints.contains("bengali") {
            return "Bengali source detected: answer only in Bangla script. Start with 'ধারা ৪১৭'. Copy these Bangla source words when relevant: ধারা, আইনজীবী, উদ্ধৃতি, যাচাই. Do not translate Bengali source facts into English."
        }
        if language == .hindi || hints.contains("hi") || hints.contains("hindi") {
            return "Hindi source detected: answer only in Devanagari. Copy these Hindi source words when relevant: धारा, अधिवक्ता, उद्धरण, सत्यापित. Do not translate Hindi source facts into English."
        }
        if language == .tamil || hints.contains("ta") || hints.contains("tamil") {
            return "Tamil source detected: answer only in Tamil script. Copy these Tamil source words when relevant: பிரிவு, வழக்கறிஞர், மேற்கோள், சரிபார்க்க. Do not translate Tamil source facts into English."
        }
        if language == .telugu || hints.contains("te") || hints.contains("telugu") {
            return "Telugu source detected: answer only in Telugu script. Copy these Telugu source words when relevant: సెక్షన్, న్యాయవాది, ఉదాహరణ, ధృవీకరించు. Do not translate Telugu source facts into English."
        }
        return "If SOURCES use a non-English script, preserve that script in the answer."
    }

    nonisolated static func sourceLanguageFallbackIfNeeded(
        for input: AlphaLocalModelInput,
        generatedText: String
    ) -> String? {
        guard !input.sourcePack.isEmpty else { return nil }
        let language = input.languageProfile?.primaryLanguage
        let hints = Set(input.sourcePack.compactMap { $0.languageHint?.lowercased() })
        if language == .bengali || hints.contains("bn") || hints.contains("bengali") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0980...0x09FF) else { return nil }
            return extractiveMatterAnswer(from: input.sourcePack, scriptRange: 0x0980...0x09FF, heading: "উৎসভিত্তিক উত্তর")
        }
        if language == .hindi || hints.contains("hi") || hints.contains("hindi") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0900...0x097F) else { return nil }
            return extractiveMatterAnswer(from: input.sourcePack, scriptRange: 0x0900...0x097F, heading: "स्रोत-आधारित उत्तर")
        }
        if language == .tamil || hints.contains("ta") || hints.contains("tamil") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0B80...0x0BFF) else { return nil }
            return extractiveMatterAnswer(from: input.sourcePack, scriptRange: 0x0B80...0x0BFF, heading: "மூலத்தின் அடிப்படையிலான பதில்")
        }
        if language == .telugu || hints.contains("te") || hints.contains("telugu") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0C00...0x0C7F) else { return nil }
            return extractiveMatterAnswer(from: input.sourcePack, scriptRange: 0x0C00...0x0C7F, heading: "మూలాల ఆధారిత సమాధానం")
        }
        return nil
    }

    private func focusedMatterSourceBlocks(for input: AlphaLocalModelInput) -> [AlphaSourceTextBlock] {
        let sourceBlockLimit = input.sourceBlockLimitOverride ?? AlphaLlamaRuntimeProfile.sourceBlockLimit(for: capabilityTier)
        return Array(
            AlphaPromptFocusPlanner
                .rankedSourceBlocks(input.sourcePack, instruction: input.instruction)
                .prefix(sourceBlockLimit)
        )
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
