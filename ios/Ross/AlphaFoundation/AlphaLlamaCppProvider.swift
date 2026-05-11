import Foundation
import LlamaSwift

final class AlphaLlamaCppProvider: AlphaRealLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode = .llamaCppGguf
    let modelPathLabel: String?
    let modelPath: String?
    let checksumVerified: Bool
    
    // Shared state or context
    private let queue = DispatchQueue(label: "com.ross.AlphaLlamaCppProvider", qos: .userInitiated)
    
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
        return 4096
    }
    
    func maxInputChars() -> Int? {
        return 16000
    }
    
    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput {
        let pack = AlphaPromptPackBuilder(maxInputChars: maxInputChars() ?? 16000).build(input: taskInput)
        
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
            let context = try LlamaContext.create_context(path: modelPath)
            
            let systemPrompt = pack.systemInstructions
            let userPrompt = pack.promptText
            let combinedPrompt = "<bos><start_of_turn>user\n\(systemPrompt)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            
            await context.completion_init(text: combinedPrompt)
            
            var generatedResponse = ""
            while await !context.is_done {
                let tokenStr = await context.completion_loop()
                generatedResponse += tokenStr
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > 10000 { break }
            }
            
            let schemaValid = generatedResponse.contains("{") && generatedResponse.contains("}")
            let jsonString = extractJSON(from: generatedResponse)
            
            return AlphaLocalModelOutput(
                rawText: generatedResponse,
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
}
