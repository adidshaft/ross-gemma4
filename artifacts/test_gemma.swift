import Foundation
import LlamaSwift

@main
struct TestGemma {
    static func main() async throws {
        let modelPath = "artifacts/gemma-2-2b-it-Q4_K_M.gguf"
        print("Loading model from: \(modelPath)")
        
        let context = try Llama(path: modelPath)
        print("Model loaded successfully!")
        
        let prompt = "<bos><start_of_turn>user\nHello Gemma! Can you confirm you are working?\n<end_of_turn>\n<start_of_turn>model\n"
        print("Running inference...")
        
        let response = try await context.complete(prompt)
        print("\n--- RESPONSE ---")
        print(response)
        print("----------------")
    }
}
