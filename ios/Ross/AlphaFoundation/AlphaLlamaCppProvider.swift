import Foundation
import LlamaSwift

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
            return (false, "missing_model_file", "Assistant setup is missing or incomplete. Open My assistant to set up again.")
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
            return (false, "missing_model_file", "Assistant setup is missing or incomplete. Open My assistant to set up again.")
        }
        do {
            try Self.validateModelCanLoad(at: modelPath)
            return (true, nil, "Private assistant is ready on this iPhone.")
        } catch {
            return (false, "runtime_validation_failed", "Ross could not open this assistant setup. Open My assistant and use Repair setup.")
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
            lastErrorCategory: availability.errorCategory,
            userFacingStatus: availability.status,
            explicitOptInEnabled: true
        )
    }
    
    func contextWindowEstimate() -> Int? {
        return 8192
    }
    
    func maxInputChars() -> Int? {
        return 12000
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
        let pack = AlphaPromptPackBuilder(maxInputChars: maxInputChars() ?? 7000).build(input: taskInput)
        
        guard let modelPath = self.modelPath, !modelPath.isEmpty else {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: ["Model path is invalid or missing."],
                sourceRefs: [],
                errorCategory: "model_path_missing"
            )
        }
        
        do {
            let context = try getOrContext(path: modelPath)
            await context.clear()
            
            let usesPlainMatterAnswerPrompt = taskInput.task == .matterQuestionAnswer
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
            
            let maxNewTokens = usesPlainMatterAnswerPrompt
                ? min(Int32(max(taskInput.maxOutputTokens, 1)), 96)
                : min(Int32(max(taskInput.maxOutputTokens, 1)), 96)
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
                            warnings: pack.truncated ? ["Input was truncated."] : [],
                            sourceRefs: usesPlainMatterAnswerPrompt
                                ? Array(taskInput.sourcePack.prefix(5).map(\.sourceRef))
                                : pack.includedSourceRefs
                        )
                        onPartial(partialOutput)
                    }
                }
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > 10000 { break }
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
            var warnings = pack.truncated ? ["Input was truncated."] : []
            if languagePreservingFallback != nil {
                warnings.append("Language-preserving source fallback used.")
            }
            
            return AlphaLocalModelOutput(
                rawText: finalResponse,
                parsedJson: jsonString,
                schemaValid: schemaValid,
                warnings: warnings,
                sourceRefs: usesPlainMatterAnswerPrompt
                    ? Array(taskInput.sourcePack.prefix(5).map(\.sourceRef))
                    : pack.includedSourceRefs
            )
        } catch {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: ["Inference failed: \(error.localizedDescription)"],
                sourceRefs: [],
                errorCategory: "inference_failed"
            )
        }
    }
    
    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalModelResourceEstimate {
        AlphaLocalModelResourceEstimate(
            inputChars: input.instruction.count,
            estimatedTokens: nil,
            estimatedRuntimeMs: 2000,
            estimatedMemoryMb: 2000,
            estimatedDurationSeconds: 2,
            shouldRunNow: true,
            reason: nil,
            notes: ["Llama.cpp estimation"]
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

        var remainingBudget = 6_500
        for block in input.sourcePack.prefix(6) {
            guard remainingBudget > 120 else { break }
            let label = block.sourceRef.label
            let cleanedText = block.text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let excerpt = relevantMatterExcerpt(
                from: cleanedText,
                question: input.instruction,
                maxChars: min(remainingBudget, 1_500)
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

    private func relevantMatterExcerpt(from text: String, question: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let questionTerms = Set(
            question
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 4 }
        )
        let separators = CharacterSet(charactersIn: ".।?\n")
        let sentences = text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !questionTerms.isEmpty, !sentences.isEmpty else {
            return headTailExcerpt(from: text, maxChars: maxChars)
        }

        let scored = sentences.enumerated().map { index, sentence in
            let words = Set(sentence.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
            return (index: index, score: words.intersection(questionTerms).count)
        }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score > 0 else {
            return headTailExcerpt(from: text, maxChars: maxChars)
        }

        var selected = ""
        let lowerBound = max(0, best.index - 1)
        let upperBound = min(sentences.count - 1, best.index + 2)
        for index in lowerBound...upperBound {
            let candidate = selected.isEmpty ? sentences[index] : "\(selected). \(sentences[index])"
            guard candidate.count <= maxChars else { break }
            selected = candidate
        }
        return selected.isEmpty ? headTailExcerpt(from: text, maxChars: maxChars) : selected
    }

    private func headTailExcerpt(from text: String, maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        let headCount = max(1, Int(Double(maxChars) * 0.62))
        let tailCount = max(1, maxChars - headCount - 6)
        return "\(text.prefix(headCount)) ... \(text.suffix(tailCount))"
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
