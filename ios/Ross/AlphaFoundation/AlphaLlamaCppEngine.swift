import Foundation
import llama

enum LlamaError: Error {
    case couldNotInitializeContext
    case couldNotInitializeSampler
}

func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
    batch.token   [Int(batch.n_tokens)] = id
    batch.pos     [Int(batch.n_tokens)] = pos
    batch.n_seq_id[Int(batch.n_tokens)] = Int32(seq_ids.count)
    for i in 0..<seq_ids.count {
        if let seqIdPtr = batch.seq_id[Int(batch.n_tokens)] {
            seqIdPtr[Int(i)] = seq_ids[i]
        }
    }
    batch.logits  [Int(batch.n_tokens)] = logits ? 1 : 0

    batch.n_tokens += 1
}

actor LlamaContext {
    nonisolated(unsafe) private var model: OpaquePointer
    nonisolated(unsafe) private var context: OpaquePointer
    private var vocab: OpaquePointer
    nonisolated(unsafe) private var sampling: UnsafeMutablePointer<llama_sampler>
    nonisolated(unsafe) private var batch: llama_batch
    private var tokens_list: [llama_token]
    var is_done: Bool = false

    /// This variable is used to store temporarily invalid cchars
    private var temporary_invalid_cchars: [CChar]

    var n_len: Int32 = 1024
    private let defaultMaxNewTokens: Int32 = 96
    private var maxNewTokens: Int32 = 96
    private var currentSamplerSettings = AlphaLlamaSamplerSettings.legalQA
    var n_cur: Int32 = 0

    var n_decode: Int32 = 0
    private var hasDecodableLogits = false

    init(model: OpaquePointer, context: OpaquePointer, sampling: UnsafeMutablePointer<llama_sampler>) {
        self.model = model
        self.context = context
        self.tokens_list = []
        self.batch = llama_batch_init(1024, 0, 1)
        self.temporary_invalid_cchars = []
        self.sampling = sampling
        vocab = llama_model_get_vocab(model)
    }

    deinit {
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
    }

    nonisolated(unsafe) private static var backendInitialized = false
    private static let backendLock = NSLock()

    static func create_context(path: String) throws -> LlamaContext {
        backendLock.lock()
        if !backendInitialized {
            llama_backend_init()
            backendInitialized = true
        }
        backendLock.unlock()

        var model_params = llama_model_default_params()

        // Check for sufficient RAM (simplified check)
        let memory = ProcessInfo.processInfo.physicalMemory
        print("System physical memory: \(memory / 1024 / 1024 / 1024) GB")

#if targetEnvironment(simulator)
        model_params.n_gpu_layers = 0
        print("Running on simulator, force use n_gpu_layers = 0")
#else
        model_params.n_gpu_layers = AlphaLlamaRuntimeProfile.gpuLayerCount(
            forModelPath: path,
            physicalMemory: memory
        )
        print("Using n_gpu_layers = \(model_params.n_gpu_layers)")
#endif
        let model = llama_model_load_from_file(path, model_params)
        guard let model else {
            print("Could not load model at \(path)")
            throw LlamaError.couldNotInitializeContext
        }

        let n_threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("Using \(n_threads) threads")

        var ctx_params = llama_context_default_params()
        ctx_params.n_ctx = AlphaLlamaRuntimeProfile.contextWindowTokens(forModelPath: path, physicalMemory: memory)
        ctx_params.n_threads       = Int32(n_threads)
        ctx_params.n_threads_batch = Int32(n_threads)

        let context = llama_init_from_model(model, ctx_params)
        guard let context else {
            print("Could not load context!")
            llama_model_free(model)
            throw LlamaError.couldNotInitializeContext
        }

        do {
            let sampler = try Self.makeSampler(settings: AlphaLlamaSamplerSettings.legalQA)
            return LlamaContext(model: model, context: context, sampling: sampler)
        } catch {
            llama_free(context)
            llama_model_free(model)
            throw error
        }
    }

    func model_info() -> String {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        result.initialize(repeating: Int8(0), count: 256)
        defer {
            result.deallocate()
        }

        let nChars = llama_model_desc(model, result, 256)
        if nChars > 0 {
            result[min(Int(nChars), 255)] = 0
        }
        return String(cString: result)
    }

    func get_n_tokens() -> Int32 {
        return batch.n_tokens;
    }

    nonisolated(unsafe) static var samplerFactory: (llama_sampler_chain_params) -> UnsafeMutablePointer<llama_sampler>? = { params in
        llama_sampler_chain_init(params)
    }

    private static func makeSampler(settings: AlphaLlamaSamplerSettings) throws -> UnsafeMutablePointer<llama_sampler> {
        let sparams = llama_sampler_chain_default_params()
        guard let sampler = samplerFactory(sparams) else {
            print("llama sampler chain failed to initialize")
            throw LlamaError.couldNotInitializeSampler
        }
        let topK = Int32(max(1, min(settings.topK, 200)))
        let topP = Float(max(0.05, min(settings.topP, 1.0)))
        let temperature = Float(max(0.0, min(settings.temperature, 1.5)))
        let repeatPenalty = Float(max(1.0, min(settings.repeatPenalty, 1.5)))
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(64, repeatPenalty, 0.0, 0.0))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(settings.seed))
        return sampler
    }

    func completion_init(
        text: String,
        maxNewTokens requestedMaxNewTokens: Int32? = nil,
        samplerSettings requestedSamplerSettings: AlphaLlamaSamplerSettings? = nil
    ) throws {
        if let requestedMaxNewTokens {
            maxNewTokens = max(16, min(384, requestedMaxNewTokens))
        } else {
            maxNewTokens = defaultMaxNewTokens
        }
        if let requestedSamplerSettings, requestedSamplerSettings != currentSamplerSettings {
            let replacementSampler = try Self.makeSampler(settings: requestedSamplerSettings)
            llama_sampler_free(sampling)
            currentSamplerSettings = requestedSamplerSettings
            sampling = replacementSampler
        }
        print("attempting local completion: prompt_chars=\(text.count), max_new_tokens=\(maxNewTokens)")

        tokens_list = tokenize(text: text, add_bos: true)
        temporary_invalid_cchars = []
        is_done = false
        hasDecodableLogits = false
        llama_memory_clear(llama_get_memory(context), false)
        llama_sampler_reset(sampling)

        let n_ctx = Int32(llama_n_ctx(context))
        let maxInputTokens = max(1, Int(n_ctx - maxNewTokens))
        if tokens_list.count > maxInputTokens {
            print("Prompt is too large for requested output budget. Truncating input.")
            let prefixCount = min(max(768, maxInputTokens / 3), maxInputTokens / 2)
            let suffixCount = maxInputTokens - prefixCount
            tokens_list = Array(tokens_list.prefix(prefixCount)) + Array(tokens_list.suffix(suffixCount))
        }
        n_len = min(n_ctx, Int32(tokens_list.count) + maxNewTokens)

        print("\n n_len = \(n_len), n_ctx = \(n_ctx), prompt_tokens = \(tokens_list.count), max_new_tokens = \(maxNewTokens)")

        // We don't need to print all tokens, it spams the log for large inputs
        llama_batch_clear(&batch)

        var decodedFinalPromptChunk = false
        for i in 0..<tokens_list.count {
            let isFinalPromptToken = i == tokens_list.count - 1
            llama_batch_add(&batch, tokens_list[i], Int32(i), [0], isFinalPromptToken)

            // Chunk prompt evaluation to avoid exceeding batch size.
            if batch.n_tokens >= 1024 {
                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during prompt evaluation chunk")
                    hasDecodableLogits = false
                    is_done = true
                    llama_batch_clear(&batch)
                    return
                }
                if isFinalPromptToken {
                    decodedFinalPromptChunk = true
                    hasDecodableLogits = true
                } else {
                    llama_batch_clear(&batch)
                }
            }
        }

        if batch.n_tokens > 0 && !decodedFinalPromptChunk {
            batch.logits[Int(batch.n_tokens) - 1] = 1 // true
            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during final prompt chunk")
                hasDecodableLogits = false
                is_done = true
                llama_batch_clear(&batch)
                return
            }
            hasDecodableLogits = true
        }

        n_cur = Int32(tokens_list.count)
    }

    func completion_loop() -> String {
        guard hasDecodableLogits else {
            print("llama_sampler_sample skipped because no prompt logits are available")
            is_done = true
            return ""
        }

        var new_token_id: llama_token = 0

        new_token_id = llama_sampler_sample(sampling, context, -1)
        llama_sampler_accept(sampling, new_token_id)

        if llama_vocab_is_eog(vocab, new_token_id) || n_cur >= n_len {
            print("\n")
            is_done = true
            let new_token_str = decodeTokenBytes(temporary_invalid_cchars, repairingInvalidUTF8: true) ?? ""
            temporary_invalid_cchars.removeAll()
            return new_token_str
        }

        let new_token_cchars = token_to_piece(token: new_token_id)
        temporary_invalid_cchars.append(contentsOf: new_token_cchars)
        let new_token_str: String
        if let string = decodeTokenBytes(temporary_invalid_cchars, repairingInvalidUTF8: false) {
            temporary_invalid_cchars.removeAll()
            new_token_str = string
        } else if (0 ..< temporary_invalid_cchars.count).contains(where: { $0 != 0 && decodeTokenBytes(Array(temporary_invalid_cchars.suffix($0)), repairingInvalidUTF8: false) != nil }) {
            // in this case, at least the suffix of the temporary_invalid_cchars can be interpreted as UTF8 string
            let string = decodeTokenBytes(temporary_invalid_cchars, repairingInvalidUTF8: true) ?? ""
            temporary_invalid_cchars.removeAll()
            new_token_str = string
        } else {
            new_token_str = ""
        }
        // tokens_list.append(new_token_id)

        llama_batch_clear(&batch)
        llama_batch_add(&batch, new_token_id, n_cur, [0], true)

        n_decode += 1
        n_cur    += 1

        if llama_decode(context, batch) != 0 {
            print("failed to evaluate llama!")
            hasDecodableLogits = false
            is_done = true
            return new_token_str
        }
        hasDecodableLogits = true

        return new_token_str
    }

    private func decodeTokenBytes(_ cchars: [CChar], repairingInvalidUTF8: Bool) -> String? {
        let bytes = cchars.map { UInt8(bitPattern: $0) }
        if repairingInvalidUTF8 {
            return String(decoding: bytes, as: UTF8.self)
        }
        return String(bytes: bytes, encoding: .utf8)
    }

    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) -> String {
        var pp_avg: Double = 0
        var tg_avg: Double = 0

        var pp_std: Double = 0
        var tg_std: Double = 0

        for _ in 0..<nr {
            // bench prompt processing

            llama_batch_clear(&batch)

            let n_tokens = pp

            for i in 0..<n_tokens {
                llama_batch_add(&batch, 0, Int32(i), [0], false)
            }
            batch.logits[Int(batch.n_tokens) - 1] = 1 // true

            llama_memory_clear(llama_get_memory(context), false)

            let t_pp_start = DispatchTime.now().uptimeNanoseconds / 1000;

            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during prompt")
            }
            llama_synchronize(context)

            let t_pp_end = DispatchTime.now().uptimeNanoseconds / 1000;

            // bench text generation

            llama_memory_clear(llama_get_memory(context), false)

            let t_tg_start = DispatchTime.now().uptimeNanoseconds / 1000;

            for i in 0..<tg {
                llama_batch_clear(&batch)

                for j in 0..<pl {
                    llama_batch_add(&batch, 0, Int32(i), [Int32(j)], true)
                }

                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during text generation")
                }
                llama_synchronize(context)
            }

            let t_tg_end = DispatchTime.now().uptimeNanoseconds / 1000;

            llama_memory_clear(llama_get_memory(context), false)

            let t_pp = Double(t_pp_end - t_pp_start) / 1000000.0
            let t_tg = Double(t_tg_end - t_tg_start) / 1000000.0

            let speed_pp = Double(pp)    / t_pp
            let speed_tg = Double(pl*tg) / t_tg

            pp_avg += speed_pp
            tg_avg += speed_tg

            pp_std += speed_pp * speed_pp
            tg_std += speed_tg * speed_tg

            print("pp \(speed_pp) t/s, tg \(speed_tg) t/s")
        }

        pp_avg /= Double(nr)
        tg_avg /= Double(nr)

        if nr > 1 {
            pp_std = sqrt(pp_std / Double(nr - 1) - pp_avg * pp_avg * Double(nr) / Double(nr - 1))
            tg_std = sqrt(tg_std / Double(nr - 1) - tg_avg * tg_avg * Double(nr) / Double(nr - 1))
        } else {
            pp_std = 0
            tg_std = 0
        }

        let model_desc     = model_info();
        let model_size     = String(format: "%.2f GiB", Double(llama_model_size(model)) / 1024.0 / 1024.0 / 1024.0);
        let model_n_params = String(format: "%.2f B", Double(llama_model_n_params(model)) / 1e9);
        let backend        = "Metal";
        let pp_avg_str     = String(format: "%.2f", pp_avg);
        let tg_avg_str     = String(format: "%.2f", tg_avg);
        let pp_std_str     = String(format: "%.2f", pp_std);
        let tg_std_str     = String(format: "%.2f", tg_std);

        var result = ""

        result += String("| model | size | params | backend | test | t/s |\n")
        result += String("| --- | --- | --- | --- | --- | --- |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | pp \(pp) | \(pp_avg_str) ± \(pp_std_str) |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | tg \(tg) | \(tg_avg_str) ± \(tg_std_str) |\n")

        return result;
    }

    func clear() {
        is_done = false
        n_cur = 0
        n_decode = 0
        tokens_list.removeAll()
        temporary_invalid_cchars.removeAll()
        llama_batch_clear(&batch)
        llama_memory_clear(llama_get_memory(context), true)
    }

    private func tokenize(text: String, add_bos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: n_tokens)
        let tokenCount = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(n_tokens), add_bos, true)

        var swiftTokens: [llama_token] = []
        for i in 0..<tokenCount {
            swiftTokens.append(tokens[Int(i)])
        }

        tokens.deallocate()

        return swiftTokens
    }

    /// - note: The result does not contain null-terminator
    private func token_to_piece(token: llama_token) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer {
            result.deallocate()
        }
        let nTokens = llama_token_to_piece(vocab, token, result, 8, 0, false)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(vocab, token, newResult, -nTokens, 0, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
}
