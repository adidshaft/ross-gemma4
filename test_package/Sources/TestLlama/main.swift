import Foundation

let modelPath = "../artifacts/gemma-2-2b-it-Q4_K_M.gguf"
print("Loading model from: \(modelPath)")

do {
    let context = try LlamaContext.create_context(path: modelPath)
    print("Model loaded successfully!")
    
    let prompt = "<bos><start_of_turn>user\nHello Gemma! Can you confirm you are working?\n<end_of_turn>\n<start_of_turn>model\n"
    print("Running inference...")
    
    await context.completion_init(text: prompt)
    
    var generatedResponse = ""
    while await !context.is_done {
        let tokenStr = await context.completion_loop()
        generatedResponse += tokenStr
        print(tokenStr, terminator: "")
        fflush(stdout)
    }
    
    print("\n--- RESPONSE ---")
    print(generatedResponse)
    print("----------------")
} catch {
    print("Failed: \(error)")
}
