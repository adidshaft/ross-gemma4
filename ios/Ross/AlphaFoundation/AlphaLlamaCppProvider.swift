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
        guard let modelPath, !modelPath.isEmpty else { return false }
        let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath)
        let bytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return bytes > 1_000_000
    }
    
    func supportedTasks() -> Set<AlphaLocalModelTask> {
        return Set(AlphaLocalModelTask.allCases)
    }
    
    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: isAvailable(),
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: Array(supportedTasks()),
            maxInputChars: maxInputChars(),
            estimatedContextTokens: contextWindowEstimate(),
            lastErrorCategory: nil,
            userFacingStatus: isAvailable() ? "Gemma 4 (Llama.cpp) Ready" : "Gemma 4 model file is missing or incomplete.",
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
        
        let newContext = try LlamaContext.create_context(path: path)
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
                ? min(Int32(max(taskInput.maxOutputTokens, 1)), 56)
                : min(Int32(max(taskInput.maxOutputTokens, 1)), 96)
            await context.completion_init(
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
            let jsonString = extractJSON(from: cleanedResponse)
            let schemaValid = usesPlainMatterAnswerPrompt
                ? !cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                : jsonString != nil
            
            return AlphaLocalModelOutput(
                rawText: cleanedResponse,
                parsedJson: jsonString,
                schemaValid: schemaValid,
                warnings: pack.truncated ? ["Input was truncated."] : [],
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
        var prompt = """
        Ross private local answer. Use only SOURCES. Do not invent facts.
        Match the question language exactly.
        Hindi: Devanagari only, no Hinglish except names/dates/source labels.
        Bengali: Bengali script only except names/dates/source labels.
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
