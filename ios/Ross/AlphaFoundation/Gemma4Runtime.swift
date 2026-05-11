import Foundation

enum Gemma4RuntimeStatus {
    case unavailable(reason: String)
    case demo
    case ready(modelId: String)
    case loading(modelId: String)
    case failed(reason: String)
}

struct Gemma4InferenceRequest {
    let prompt: String
    let retrievedSources: [String]
    let workflowType: String
    let modelId: String
    let maxTokens: Int
    let temperature: Double
}

struct Gemma4InferenceResponse {
    let text: String
    let sourceReferences: [String]
    let isSimulated: Bool
    let modelId: String
    let runtimeName: String
    let generatedAt: Date
}

protocol Gemma4Runtime {
    var status: Gemma4RuntimeStatus { get }
    func loadModel(_ model: AlphaRossModel) async throws
    func generate(request: Gemma4InferenceRequest) async throws -> Gemma4InferenceResponse
    func unload() async
}

class Gemma4DemoRuntime: Gemma4Runtime {
    var status: Gemma4RuntimeStatus = .demo
    
    func loadModel(_ model: AlphaRossModel) async throws {
        // No-op for demo
    }
    
    func generate(request: Gemma4InferenceRequest) async throws -> Gemma4InferenceResponse {
        return Gemma4InferenceResponse(
            text: "This is a deterministic demo response for walkthrough purposes.",
            sourceReferences: request.retrievedSources,
            isSimulated: true,
            modelId: request.modelId,
            runtimeName: "Demo Mode",
            generatedAt: Date()
        )
    }
    
    func unload() async {
        // No-op for demo
    }
}

class Gemma4UnavailableRuntime: Gemma4Runtime {
    var status: Gemma4RuntimeStatus = .unavailable(reason: "Local Gemma 4 runtime is not configured.")
    
    func loadModel(_ model: AlphaRossModel) async throws {
        throw NSError(domain: "Gemma4UnavailableRuntime", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Local Gemma 4 runtime is not configured. Use Demo Mode or install a verified Gemma 4 runtime/artifact."
        ])
    }
    
    func generate(request: Gemma4InferenceRequest) async throws -> Gemma4InferenceResponse {
        throw NSError(domain: "Gemma4UnavailableRuntime", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Local Gemma 4 runtime is not configured. Use Demo Mode or install a verified Gemma 4 runtime/artifact."
        ])
    }
    
    func unload() async {
        // No-op
    }
}
