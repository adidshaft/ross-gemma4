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
        return modelPath != nil
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
            userFacingStatus: "Gemma 4 (Llama.cpp) Ready",
            explicitOptInEnabled: true
        )
    }
    
    func contextWindowEstimate() -> Int? {
        return 2048
    }
    
    func maxInputChars() -> Int? {
        return 5000
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
            
            let systemPrompt = pack.systemInstructions
            let userPrompt = taskInput.task == .matterQuestionAnswer
                ? conciseMatterQuestionPrompt(for: taskInput)
                : pack.promptText
            let combinedPrompt = "<start_of_turn>user\n\(systemPrompt)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            
            await context.completion_init(text: combinedPrompt)
            
            var generatedResponse = ""
            while await !context.is_done {
                let tokenStr = await context.completion_loop()
                generatedResponse += tokenStr
                if containsTurnMarkerFragment(generatedResponse) {
                    generatedResponse = stripTurnMarkerFragments(from: generatedResponse)
                    break
                }
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > 10000 { break }
            }
            
            let cleanedResponse = stripTurnMarkerFragments(from: generatedResponse)
            let schemaValid = cleanedResponse.contains("{") && cleanedResponse.contains("}")
            let jsonString = extractJSON(from: cleanedResponse)
            
            return AlphaLocalModelOutput(
                rawText: cleanedResponse,
                parsedJson: jsonString,
                schemaValid: schemaValid,
                warnings: pack.truncated ? ["Input was truncated."] : [],
                sourceRefs: pack.includedSourceRefs
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
        You are Ross, a private legal assistant running locally on this device.
        Use only the SOURCES below. Do not invent facts.
        Match the advocate's language exactly.
        If the question uses Devanagari/Hindi, answer only in natural Hindi using Devanagari script. Do not use Hinglish or English words except exact names, dates, and source labels.
        If the question uses Bengali, answer only in natural Bengali using Bengali script. Do not use English words except exact names, dates, and source labels.
        Do not output JSON, XML, markdown fences, or chat template tokens.
        Write a short heading and 2 to 4 useful bullet points.
        Cite local source labels in parentheses, for example: (03_Affidavit_Asha_Menon_Camera_Retention · p. 1).

        TASK:
        \(input.instruction)

        SOURCES:
        """

        var remainingBudget = 3_600
        for block in input.sourcePack.prefix(5) {
            guard remainingBudget > 120 else { break }
            let label = block.sourceRef.label
            let cleanedText = block.text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let excerpt = String(cleanedText.prefix(min(cleanedText.count, remainingBudget)))
            prompt += "\n[\(label)] \(excerpt)\n"
            remainingBudget -= excerpt.count + label.count + 8
        }

        prompt += "\nANSWER:"
        return prompt
    }

    private func containsTurnMarkerFragment(_ text: String) -> Bool {
        text.range(
            of: #"(?is)(</?\s*(start|end)\s*_\s*of\s*_\s*turn\s*>|start\s*of\s*turn|end\s*of\s*turn)"#,
            options: .regularExpression
        ) != nil
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
