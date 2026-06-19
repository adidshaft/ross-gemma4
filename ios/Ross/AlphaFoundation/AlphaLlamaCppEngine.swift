import Foundation
import llama

enum LlamaError: Error {
    case couldNotInitializeContext
    case couldNotInitializeDraftContext
    case couldNotInitializeSampler
    case missingPromptState
}

struct AlphaSpeculativeDraftMetrics: Codable, Hashable, Sendable {
    var attemptedTokens: Int
    var acceptedTokens: Int
}

@_silgen_name("_Z26llama_set_embeddings_nextnP13llama_contextbb")
private func llama_set_embeddings_nextn_bridge(_ ctx: OpaquePointer?, _ value: Bool, _ masked: Bool)

@_silgen_name("_Z26llama_get_embeddings_nextnP13llama_context")
private func llama_get_embeddings_nextn_bridge(_ ctx: OpaquePointer?) -> UnsafePointer<Float>?

@_silgen_name("_Z30llama_get_embeddings_nextn_ithP13llama_contexti")
private func llama_get_embeddings_nextn_ith_bridge(_ ctx: OpaquePointer?, _ index: Int32) -> UnsafePointer<Float>?

@_silgen_name("_Z19llama_get_ctx_otherP13llama_context")
private func llama_get_ctx_other_bridge(_ ctx: OpaquePointer?) -> OpaquePointer?

func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
    batch.token[Int(batch.n_tokens)] = id
    batch.pos[Int(batch.n_tokens)] = pos
    batch.n_seq_id[Int(batch.n_tokens)] = Int32(seq_ids.count)
    for i in 0..<seq_ids.count {
        if let seqIdPtr = batch.seq_id[Int(batch.n_tokens)] {
            seqIdPtr[Int(i)] = seq_ids[i]
        }
    }
    batch.logits[Int(batch.n_tokens)] = logits ? 1 : 0
    batch.n_tokens += 1
}

protocol AlphaLlamaCompletionContext: Sendable {
    func clear() async
    func completionInit(
        text: String,
        maxNewTokens requestedMaxNewTokens: Int32?,
        samplerSettings requestedSamplerSettings: AlphaLlamaSamplerSettings?
    ) async throws
    func completionLoop() async -> String
    func isDone() async -> Bool
    func promptTokenCount() async -> Int
    func generatedTokenCount() async -> Int
    func accelerationMode() async -> AlphaLocalRuntimeAccelerationMode
    func executionPathLabel() async -> String
    func speculativeDraftMetrics() async -> AlphaSpeculativeDraftMetrics?
}

extension AlphaLlamaCompletionContext {
    func speculativeDraftMetrics() async -> AlphaSpeculativeDraftMetrics? { nil }
}

private struct LlamaSpeculativeDraftConfiguration: Sendable {
    let path: String
    let maxDraftTokens: Int32
}

private struct LlamaSpeculativeDraftState: @unchecked Sendable {
    var model: OpaquePointer
    var context: OpaquePointer
    var sampling: UnsafeMutablePointer<llama_sampler>
    var batch: llama_batch
    let nEmbd: Int32
    let maxDraftTokens: Int32
    let isSharedMemory: Bool
}

actor LlamaContext: AlphaLlamaCompletionContext {
    nonisolated(unsafe) private var model: OpaquePointer
    nonisolated(unsafe) private var context: OpaquePointer
    nonisolated let configuredAccelerationMode: AlphaLocalRuntimeAccelerationMode
    private var draftState: LlamaSpeculativeDraftState?
    private var vocab: OpaquePointer
    nonisolated(unsafe) private var sampling: UnsafeMutablePointer<llama_sampler>
    nonisolated(unsafe) private var batch: llama_batch
    private let batchTokenCapacity: Int32
    private var tokensList: [llama_token]
    private var isDoneFlag = false
    private var temporaryInvalidCChars: [CChar]
    private var pendingNextnEmbedding: [Float]
    private var currentAccelerationMode: AlphaLocalRuntimeAccelerationMode = .standard
    private var currentExecutionPathLabel = "Gemma GGUF via llama.cpp"
    private var lastAcceptedToken: llama_token?
    private var speculativeDraftTokenAttempts = 0
    private var speculativeDraftTokenAccepts = 0

    var n_len: Int32 = 1024
    private let defaultMaxNewTokens: Int32 = 96
    private var maxNewTokens: Int32 = 96
    private var currentSamplerSettings = AlphaLlamaSamplerSettings.legalQA
    var n_cur: Int32 = 0
    var n_decode: Int32 = 0
    private var hasDecodableLogits = false

    fileprivate init(
        model: OpaquePointer,
        context: OpaquePointer,
        sampling: UnsafeMutablePointer<llama_sampler>,
        batchTokenCapacity: Int32,
        draftState: LlamaSpeculativeDraftState? = nil
    ) {
        self.model = model
        self.context = context
        self.draftState = draftState
        self.configuredAccelerationMode = draftState == nil ? .standard : .draftModelSpeculative
        self.tokensList = []
        self.batchTokenCapacity = max(256, batchTokenCapacity)
        self.batch = llama_batch_init(self.batchTokenCapacity, 0, 1)
        self.temporaryInvalidCChars = []
        self.pendingNextnEmbedding = draftState.map { Array(repeating: 0, count: Int($0.nEmbd)) } ?? []
        self.sampling = sampling
        self.vocab = llama_model_get_vocab(model)
    }

    deinit {
        if let draftState = draftState {
            llama_sampler_free(draftState.sampling)
            llama_batch_free(draftState.batch)
            llama_free(draftState.context)
            llama_model_free(draftState.model)
        }
        llama_sampler_free(sampling)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
    }

    nonisolated(unsafe) private static var backendInitialized = false
    private static let backendLock = NSLock()

    static func create_context(
        path: String,
        draftPath: String? = nil,
        draftTokens: Int? = nil,
        strictDraftSetup: Bool = false
    ) throws -> LlamaContext {
        backendLock.lock()
        if !backendInitialized {
            llama_backend_init()
            backendInitialized = true
        }
        backendLock.unlock()

        let memory = ProcessInfo.processInfo.physicalMemory
        print("System physical memory: \(memory / 1024 / 1024 / 1024) GB")

        var modelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        modelParams.n_gpu_layers = 0
        print("Running on simulator, force use n_gpu_layers = 0")
#else
        modelParams.n_gpu_layers = AlphaLlamaRuntimeProfile.gpuLayerCount(
            forModelPath: path,
            physicalMemory: memory
        )
        print("Using n_gpu_layers = \(modelParams.n_gpu_layers)")
#endif

        guard let model = llama_model_load_from_file(path, modelParams) else {
            print("Could not load model at \(path)")
            throw LlamaError.couldNotInitializeContext
        }

        let nThreads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        print("Using \(nThreads) threads")

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = AlphaLlamaRuntimeProfile.effectiveContextWindowTokens(forModelPath: path, physicalMemory: memory)
        ctxParams.n_batch = AlphaLlamaRuntimeProfile.effectivePromptBatchTokens(forModelPath: path, physicalMemory: memory)
        ctxParams.n_ubatch = AlphaLlamaRuntimeProfile.effectivePhysicalBatchTokens(forModelPath: path, physicalMemory: memory)
        ctxParams.n_threads = Int32(nThreads)
        ctxParams.n_threads_batch = Int32(nThreads)
        let shouldOffloadKQV = modelParams.n_gpu_layers > 0 && AlphaLlamaRuntimeProfile.shouldOffloadKQV(
            forModelPath: path,
            physicalMemory: memory
        )
        let shouldOffloadHostOperations = modelParams.n_gpu_layers > 0 && AlphaLlamaRuntimeProfile.shouldOffloadHostOperations(
            forModelPath: path,
            physicalMemory: memory
        )
        ctxParams.offload_kqv = shouldOffloadKQV
        ctxParams.op_offload = shouldOffloadHostOperations
        print("Using offload_kqv = \(ctxParams.offload_kqv) op_offload = \(ctxParams.op_offload)")
        ctxParams.defrag_thold = 0.1

        guard let context = llama_init_from_model(model, ctxParams) else {
            print("Could not load context!")
            llama_model_free(model)
            throw LlamaError.couldNotInitializeContext
        }

        do {
            let sampler = try Self.makeSampler(settings: .legalQA)
            let draftConfiguration = speculativeDraftConfiguration(
                draftPath: draftPath,
                draftTokens: draftTokens
            )
            let draftState: LlamaSpeculativeDraftState?
            if let draftConfiguration {
                do {
                    draftState = try makeDraftState(
                        configuration: draftConfiguration,
                        targetContext: context,
                        physicalMemory: memory,
                        nThreads: Int32(nThreads),
                        samplerSettings: .legalQA
                    )
                    llama_set_embeddings_nextn_bridge(context, true, false)
                } catch {
                    print("Speculative draft setup failed for \(draftConfiguration.path): \(error)")
                    if strictDraftSetup {
                        throw LlamaError.couldNotInitializeDraftContext
                    }
                    draftState = nil
                }
            } else {
                draftState = nil
            }
            return LlamaContext(
                model: model,
                context: context,
                sampling: sampler,
                batchTokenCapacity: Int32(ctxParams.n_batch),
                draftState: draftState
            )
        } catch {
            llama_free(context)
            llama_model_free(model)
            throw error
        }
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

    private static func speculativeDraftConfiguration(
        draftPath: String?,
        draftTokens: Int?
    ) -> LlamaSpeculativeDraftConfiguration? {
        guard
            let draftPath = draftPath?.trimmingCharacters(in: .whitespacesAndNewlines),
            !draftPath.isEmpty
        else {
            return nil
        }
        let effectiveTokens = max(1, min(draftTokens ?? 4, 8))
        return LlamaSpeculativeDraftConfiguration(
            path: draftPath,
            maxDraftTokens: Int32(effectiveTokens)
        )
    }

    private static func makeDraftState(
        configuration: LlamaSpeculativeDraftConfiguration,
        targetContext: OpaquePointer,
        physicalMemory: UInt64,
        nThreads: Int32,
        samplerSettings: AlphaLlamaSamplerSettings
    ) throws -> LlamaSpeculativeDraftState {
        var draftModelParams = llama_model_default_params()
#if targetEnvironment(simulator)
        draftModelParams.n_gpu_layers = 0
#else
        draftModelParams.n_gpu_layers = AlphaLlamaRuntimeProfile.gpuLayerCount(
            forModelPath: configuration.path,
            physicalMemory: physicalMemory
        )
#endif
        guard let draftModel = llama_model_load_from_file(configuration.path, draftModelParams) else {
            throw LlamaError.couldNotInitializeContext
        }

        var draftContextParams = llama_context_default_params()
        draftContextParams.n_ctx = AlphaLlamaRuntimeProfile.effectiveContextWindowTokens(
            forModelPath: configuration.path,
            physicalMemory: physicalMemory
        )
        let draftBatchCapacity = UInt32(max(32, min(Int(configuration.maxDraftTokens) + 8, 128)))
        draftContextParams.n_batch = draftBatchCapacity
        draftContextParams.n_ubatch = draftBatchCapacity
        draftContextParams.n_threads = nThreads
        draftContextParams.n_threads_batch = nThreads
        let shouldOffloadDraftKQV = draftModelParams.n_gpu_layers > 0 && AlphaLlamaRuntimeProfile.shouldOffloadKQV(
            forModelPath: configuration.path,
            physicalMemory: physicalMemory
        )
        let shouldOffloadDraftHostOperations = draftModelParams.n_gpu_layers > 0 && AlphaLlamaRuntimeProfile.shouldOffloadHostOperations(
            forModelPath: configuration.path,
            physicalMemory: physicalMemory
        )
        draftContextParams.offload_kqv = shouldOffloadDraftKQV
        draftContextParams.op_offload = shouldOffloadDraftHostOperations
        draftContextParams.defrag_thold = 0.1
        draftContextParams.ctx_type = LLAMA_CONTEXT_TYPE_MTP
        draftContextParams.ctx_other = targetContext

        guard let draftContext = llama_init_from_model(draftModel, draftContextParams) else {
            llama_model_free(draftModel)
            throw LlamaError.couldNotInitializeContext
        }

        let draftSampler = try makeSampler(settings: samplerSettings)
        let nEmbd = Int32(llama_model_n_embd_out(draftModel))
        var draftBatch = llama_batch_init(Int32(draftBatchCapacity), nEmbd, 1)
        let tokenBuffer = UnsafeMutablePointer<llama_token>.allocate(capacity: Int(draftBatchCapacity))
        tokenBuffer.initialize(repeating: 0, count: Int(draftBatchCapacity))
        draftBatch.token = tokenBuffer

        llama_set_embeddings_nextn_bridge(targetContext, true, false)
        llama_set_embeddings_nextn_bridge(draftContext, true, true)

        return LlamaSpeculativeDraftState(
            model: draftModel,
            context: draftContext,
            sampling: draftSampler,
            batch: draftBatch,
            nEmbd: nEmbd,
            maxDraftTokens: configuration.maxDraftTokens,
            isSharedMemory: llama_get_ctx_other_bridge(draftContext) == targetContext
        )
    }

    func clear() {
        isDoneFlag = false
        n_cur = 0
        n_decode = 0
        tokensList.removeAll()
        temporaryInvalidCChars.removeAll()
        pendingNextnEmbedding.removeAll(keepingCapacity: true)
        lastAcceptedToken = nil
        speculativeDraftTokenAttempts = 0
        speculativeDraftTokenAccepts = 0
        currentAccelerationMode = .standard
        currentExecutionPathLabel = "Gemma GGUF via llama.cpp"
        hasDecodableLogits = false
        llama_batch_clear(&batch)
        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampling)

        if var draftState = draftState {
            llama_sampler_reset(draftState.sampling)
            llama_batch_clear(&draftState.batch)
            llama_memory_clear(llama_get_memory(draftState.context), true)
            self.draftState = draftState
        }
    }

    func completionInit(
        text: String,
        maxNewTokens requestedMaxNewTokens: Int32? = nil,
        samplerSettings requestedSamplerSettings: AlphaLlamaSamplerSettings? = nil
    ) throws {
        if let requestedMaxNewTokens {
            maxNewTokens = max(1, min(384, requestedMaxNewTokens))
        } else {
            maxNewTokens = defaultMaxNewTokens
        }
        if let requestedSamplerSettings, requestedSamplerSettings != currentSamplerSettings {
            let replacementSampler = try Self.makeSampler(settings: requestedSamplerSettings)
            llama_sampler_free(sampling)
            sampling = replacementSampler
            if var draftState = draftState {
                let draftSampler = try Self.makeSampler(settings: requestedSamplerSettings)
                llama_sampler_free(draftState.sampling)
                draftState.sampling = draftSampler
                self.draftState = draftState
            }
            currentSamplerSettings = requestedSamplerSettings
        }

        print("attempting local completion: prompt_chars=\(text.count), max_new_tokens=\(maxNewTokens)")

        tokensList = tokenize(text: text, add_bos: true)
        temporaryInvalidCChars = []
        pendingNextnEmbedding = draftState.map { Array(repeating: 0, count: Int($0.nEmbd)) } ?? []
        isDoneFlag = false
        hasDecodableLogits = false
        n_decode = 0
        lastAcceptedToken = nil
        speculativeDraftTokenAttempts = 0
        speculativeDraftTokenAccepts = 0
        currentAccelerationMode = draftState == nil ? .standard : .draftModelSpeculative
        currentExecutionPathLabel = draftState == nil
            ? "Gemma GGUF via llama.cpp"
            : "Gemma GGUF with draft acceleration"

        llama_memory_clear(llama_get_memory(context), false)
        llama_sampler_reset(sampling)
        if let draftState = draftState {
            llama_memory_clear(llama_get_memory(draftState.context), false)
            llama_sampler_reset(draftState.sampling)
        }

        let nCtx = Int32(llama_n_ctx(context))
        let maxInputTokens = max(1, Int(nCtx - maxNewTokens))
        if tokensList.count > maxInputTokens {
            print("Prompt is too large for requested output budget. Truncating input.")
            let prefixCount = min(max(768, maxInputTokens / 3), maxInputTokens / 2)
            let suffixCount = maxInputTokens - prefixCount
            tokensList = Array(tokensList.prefix(prefixCount)) + Array(tokensList.suffix(suffixCount))
        }
        n_len = min(nCtx, Int32(tokensList.count) + maxNewTokens)

        print("\n n_len = \(n_len), n_ctx = \(nCtx), prompt_tokens = \(tokensList.count), max_new_tokens = \(maxNewTokens)")

        llama_batch_clear(&batch)

        var decodedFinalPromptChunk = false
        for i in 0..<tokensList.count {
            let isFinalPromptToken = i == tokensList.count - 1
            llama_batch_add(&batch, tokensList[i], Int32(i), [0], isFinalPromptToken)

            if batch.n_tokens >= batchTokenCapacity {
                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during prompt evaluation chunk")
                    hasDecodableLogits = false
                    isDoneFlag = true
                    llama_batch_clear(&batch)
                    currentAccelerationMode = .standard
                    currentExecutionPathLabel = "Gemma GGUF via llama.cpp"
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
            batch.logits[Int(batch.n_tokens) - 1] = 1
            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during final prompt chunk")
                hasDecodableLogits = false
                isDoneFlag = true
                llama_batch_clear(&batch)
                currentAccelerationMode = .standard
                currentExecutionPathLabel = "Gemma GGUF via llama.cpp"
                return
            }
            hasDecodableLogits = true
        }

        n_cur = Int32(tokensList.count)
        lastAcceptedToken = tokensList.last

        if currentAccelerationMode == .draftModelSpeculative,
           !capturePendingEmbeddingFromTarget(rowIndex: max(batch.n_tokens - 1, 0)) {
            downgradeSpeculation()
        }
    }

    func completionLoop() -> String {
        guard hasDecodableLogits else {
            print("llama completion skipped because no prompt logits are available")
            isDoneFlag = true
            return ""
        }

        if currentAccelerationMode == .draftModelSpeculative {
            let speculativeChunk = speculativeCompletionLoop()
            if !speculativeChunk.isEmpty || isDoneFlag {
                return speculativeChunk
            }
        }

        return standardCompletionLoop()
    }

    func isDone() -> Bool {
        isDoneFlag
    }

    func promptTokenCount() -> Int {
        tokensList.count
    }

    func generatedTokenCount() -> Int {
        Int(n_decode)
    }

    func accelerationMode() -> AlphaLocalRuntimeAccelerationMode {
        currentAccelerationMode
    }

    func executionPathLabel() -> String {
        currentExecutionPathLabel
    }

    func speculativeDraftMetrics() -> AlphaSpeculativeDraftMetrics? {
        guard speculativeDraftTokenAttempts > 0 || speculativeDraftTokenAccepts > 0 else {
            return nil
        }
        return AlphaSpeculativeDraftMetrics(
            attemptedTokens: speculativeDraftTokenAttempts,
            acceptedTokens: speculativeDraftTokenAccepts
        )
    }

    func model_info() -> String {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        result.initialize(repeating: Int8(0), count: 256)
        defer { result.deallocate() }

        let nChars = llama_model_desc(model, result, 256)
        if nChars > 0 {
            result[min(Int(nChars), 255)] = 0
        }
        return String(cString: result)
    }

    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) -> String {
        var ppAvg: Double = 0
        var tgAvg: Double = 0
        var ppStd: Double = 0
        var tgStd: Double = 0

        for _ in 0..<nr {
            llama_batch_clear(&batch)

            for i in 0..<pp {
                llama_batch_add(&batch, 0, Int32(i), [0], false)
            }
            batch.logits[Int(batch.n_tokens) - 1] = 1

            llama_memory_clear(llama_get_memory(context), false)

            let tPPStart = DispatchTime.now().uptimeNanoseconds / 1_000
            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during prompt")
            }
            llama_synchronize(context)
            let tPPEnd = DispatchTime.now().uptimeNanoseconds / 1_000

            llama_memory_clear(llama_get_memory(context), false)
            let tTGStart = DispatchTime.now().uptimeNanoseconds / 1_000

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

            let tTGEnd = DispatchTime.now().uptimeNanoseconds / 1_000
            llama_memory_clear(llama_get_memory(context), false)

            let tPP = Double(tPPEnd - tPPStart) / 1_000_000.0
            let tTG = Double(tTGEnd - tTGStart) / 1_000_000.0
            let speedPP = Double(pp) / tPP
            let speedTG = Double(pl * tg) / tTG

            ppAvg += speedPP
            tgAvg += speedTG
            ppStd += speedPP * speedPP
            tgStd += speedTG * speedTG

            print("pp \(speedPP) t/s, tg \(speedTG) t/s")
        }

        ppAvg /= Double(nr)
        tgAvg /= Double(nr)

        if nr > 1 {
            ppStd = sqrt(ppStd / Double(nr - 1) - ppAvg * ppAvg * Double(nr) / Double(nr - 1))
            tgStd = sqrt(tgStd / Double(nr - 1) - tgAvg * tgAvg * Double(nr) / Double(nr - 1))
        } else {
            ppStd = 0
            tgStd = 0
        }

        let modelDesc = model_info()
        let modelSize = String(format: "%.2f GiB", Double(llama_model_size(model)) / 1024.0 / 1024.0 / 1024.0)
        let modelParams = String(format: "%.2f B", Double(llama_model_n_params(model)) / 1e9)
        let backend = "Metal"
        let ppAvgStr = String(format: "%.2f", ppAvg)
        let tgAvgStr = String(format: "%.2f", tgAvg)
        let ppStdStr = String(format: "%.2f", ppStd)
        let tgStdStr = String(format: "%.2f", tgStd)

        var result = ""
        result += "| model | size | params | backend | test | t/s |\n"
        result += "| --- | --- | --- | --- | --- | --- |\n"
        result += "| \(modelDesc) | \(modelSize) | \(modelParams) | \(backend) | pp \(pp) | \(ppAvgStr) ± \(ppStdStr) |\n"
        result += "| \(modelDesc) | \(modelSize) | \(modelParams) | \(backend) | tg \(tg) | \(tgAvgStr) ± \(tgStdStr) |\n"
        return result
    }

    private func standardCompletionLoop() -> String {
        let newTokenID = llama_sampler_sample(sampling, context, -1)
        llama_sampler_accept(sampling, newTokenID)
        return commitMainToken(newTokenID)
    }

    private func speculativeCompletionLoop() -> String {
        guard
            var draftState,
            let lastAcceptedToken,
            n_cur < n_len
        else {
            downgradeSpeculation()
            return ""
        }

        let remainingTokenBudget = max(Int(n_len - n_cur), 0)
        let maxDraftTokens = min(
            Int(draftState.maxDraftTokens),
            max(remainingTokenBudget - 1, 1)
        )
        guard maxDraftTokens > 0 else {
            return standardCompletionLoop()
        }

        let draftedTokens = speculateDraftTokens(
            using: &draftState,
            seedToken: lastAcceptedToken,
            maxDraftTokens: maxDraftTokens
        )
        speculativeDraftTokenAttempts += draftedTokens.count
        self.draftState = draftState

        let firstTargetToken = llama_sampler_sample(sampling, context, -1)
        guard !draftedTokens.isEmpty, firstTargetToken == draftedTokens[0] else {
            llama_sampler_accept(sampling, firstTargetToken)
            return commitMainToken(firstTargetToken)
        }

        let basePos = n_cur
        llama_sampler_accept(sampling, firstTargetToken)

        if !decodeDraftVerificationBatchOnMain(draftedTokens, basePos: basePos) {
            downgradeSpeculation()
            return commitMainToken(firstTargetToken)
        }

        var acceptedDraftTokens: [llama_token] = [firstTargetToken]
        var mismatchToken: llama_token?

        if draftedTokens.count > 1 {
            for draftIndex in 1..<draftedTokens.count {
                let sampledTargetToken = llama_sampler_sample(sampling, context, Int32(draftIndex - 1))
                if sampledTargetToken == draftedTokens[draftIndex] {
                    llama_sampler_accept(sampling, sampledTargetToken)
                    acceptedDraftTokens.append(sampledTargetToken)
                    continue
                }
                mismatchToken = sampledTargetToken
                break
            }
        }

        if acceptedDraftTokens.count < draftedTokens.count {
            let removeStart = basePos + Int32(acceptedDraftTokens.count)
            let removeEnd = basePos + Int32(draftedTokens.count)
            if !llama_memory_seq_rm(llama_get_memory(context), 0, removeStart, removeEnd) {
                print("llama_memory_seq_rm() failed during speculative rollback")
                hasDecodableLogits = false
                isDoneFlag = true
                return flushPendingDecodedText()
            }
        }

        var emitted = acceptVerifiedDraftTokens(acceptedDraftTokens)
        if isDoneFlag {
            return emitted
        }

        if let mismatchToken {
            llama_sampler_accept(sampling, mismatchToken)
            emitted += commitMainToken(mismatchToken)
            return emitted
        }

        let extraTargetToken = llama_sampler_sample(sampling, context, Int32(draftedTokens.count - 1))
        llama_sampler_accept(sampling, extraTargetToken)
        emitted += commitMainToken(extraTargetToken)
        return emitted
    }

    private func speculateDraftTokens(
        using draftState: inout LlamaSpeculativeDraftState,
        seedToken: llama_token,
        maxDraftTokens: Int
    ) -> [llama_token] {
        guard !pendingNextnEmbedding.isEmpty else {
            return []
        }

        llama_memory_clear(llama_get_memory(draftState.context), false)
        llama_sampler_reset(draftState.sampling)
        llama_batch_clear(&draftState.batch)

        let seedPosition = max(n_cur - 1, 0)
        llama_batch_add(&draftState.batch, seedToken, seedPosition, [0], true)
        copyEmbedding(
            pendingNextnEmbedding,
            into: &draftState.batch,
            rowIndex: 0,
            width: Int(draftState.nEmbd)
        )

        guard llama_decode(draftState.context, draftState.batch) == 0 else {
            print("llama_decode() failed while seeding speculative draft context")
            return []
        }

        var draftedTokens: [llama_token] = []
        while draftedTokens.count < maxDraftTokens, n_cur + Int32(draftedTokens.count) < n_len {
            let token = llama_sampler_sample(draftState.sampling, draftState.context, -1)
            if llama_vocab_is_eog(vocab, token) {
                break
            }
            llama_sampler_accept(draftState.sampling, token)
            draftedTokens.append(token)

            guard draftedTokens.count < maxDraftTokens, n_cur + Int32(draftedTokens.count) < n_len else {
                break
            }
            guard let hiddenState = llama_get_embeddings_nextn_ith_bridge(draftState.context, 0) else {
                break
            }

            llama_batch_clear(&draftState.batch)
            let nextPosition: Int32
            if draftState.isSharedMemory {
                nextPosition = seedPosition
            } else {
                nextPosition = n_cur + Int32(draftedTokens.count - 1)
            }
            llama_batch_add(&draftState.batch, token, nextPosition, [0], true)
            copyEmbedding(
                hiddenState,
                into: &draftState.batch,
                rowIndex: 0,
                width: Int(draftState.nEmbd)
            )
            guard llama_decode(draftState.context, draftState.batch) == 0 else {
                print("llama_decode() failed while extending speculative draft context")
                break
            }
        }

        return draftedTokens
    }

    private func decodeDraftVerificationBatchOnMain(
        _ draftedTokens: [llama_token],
        basePos: Int32
    ) -> Bool {
        llama_batch_clear(&batch)
        for (offset, token) in draftedTokens.enumerated() {
            llama_batch_add(&batch, token, basePos + Int32(offset), [0], true)
        }
        if llama_decode(context, batch) != 0 {
            print("llama_decode() failed during speculative verification")
            return false
        }
        hasDecodableLogits = true
        return true
    }

    private func acceptVerifiedDraftTokens(_ tokens: [llama_token]) -> String {
        var emitted = ""
        speculativeDraftTokenAccepts += tokens.count
        for token in tokens {
            emitted += appendDecodedToken(token)
            lastAcceptedToken = token
            n_decode += 1
            n_cur += 1
            if n_cur >= n_len {
                isDoneFlag = true
                hasDecodableLogits = false
                emitted += flushPendingDecodedText()
                break
            }
        }
        return emitted
    }

    private func commitMainToken(_ token: llama_token) -> String {
        if llama_vocab_is_eog(vocab, token) || n_cur >= n_len {
            isDoneFlag = true
            hasDecodableLogits = false
            return flushPendingDecodedText()
        }

        var emitted = appendDecodedToken(token)
        lastAcceptedToken = token

        llama_batch_clear(&batch)
        llama_batch_add(&batch, token, n_cur, [0], true)
        n_decode += 1
        n_cur += 1

        if n_cur >= n_len {
            isDoneFlag = true
            hasDecodableLogits = false
            emitted += flushPendingDecodedText()
            return emitted
        }

        if llama_decode(context, batch) != 0 {
            print("failed to evaluate llama!")
            hasDecodableLogits = false
            isDoneFlag = true
            return emitted
        }
        hasDecodableLogits = true

        if currentAccelerationMode == .draftModelSpeculative,
           !capturePendingEmbeddingFromTarget(rowIndex: 0) {
            downgradeSpeculation()
        }

        return emitted
    }

    private func downgradeSpeculation() {
        currentAccelerationMode = .standard
        currentExecutionPathLabel = "Gemma GGUF via llama.cpp"
    }

    private func capturePendingEmbeddingFromTarget(rowIndex: Int32) -> Bool {
        guard
            let draftState,
            let hiddenState = llama_get_embeddings_nextn_ith_bridge(context, rowIndex)
        else {
            return false
        }
        let width = Int(draftState.nEmbd)
        pendingNextnEmbedding = Array(UnsafeBufferPointer(start: hiddenState, count: width))
        return true
    }

    private func copyEmbedding(
        _ embedding: [Float],
        into batch: inout llama_batch,
        rowIndex: Int,
        width: Int
    ) {
        embedding.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            copyEmbedding(baseAddress, into: &batch, rowIndex: rowIndex, width: width)
        }
    }

    private func copyEmbedding(
        _ embedding: UnsafePointer<Float>,
        into batch: inout llama_batch,
        rowIndex: Int,
        width: Int
    ) {
        let destination = batch.embd.advanced(by: rowIndex * width)
        destination.update(from: embedding, count: width)
    }

    private func appendDecodedToken(_ token: llama_token) -> String {
        let tokenCChars = token_to_piece(token: token)
        temporaryInvalidCChars.append(contentsOf: tokenCChars)

        if let string = decodeTokenBytes(temporaryInvalidCChars, repairingInvalidUTF8: false) {
            temporaryInvalidCChars.removeAll()
            return string
        }

        if (0..<temporaryInvalidCChars.count).contains(where: {
            $0 != 0 && decodeTokenBytes(Array(temporaryInvalidCChars.suffix($0)), repairingInvalidUTF8: false) != nil
        }) {
            let string = decodeTokenBytes(temporaryInvalidCChars, repairingInvalidUTF8: true) ?? ""
            temporaryInvalidCChars.removeAll()
            return string
        }

        return ""
    }

    private func flushPendingDecodedText() -> String {
        guard !temporaryInvalidCChars.isEmpty else { return "" }
        let string = decodeTokenBytes(temporaryInvalidCChars, repairingInvalidUTF8: true) ?? ""
        temporaryInvalidCChars.removeAll()
        return string
    }

    private func decodeTokenBytes(_ cchars: [CChar], repairingInvalidUTF8: Bool) -> String? {
        let bytes = cchars.map { UInt8(bitPattern: $0) }
        if repairingInvalidUTF8 {
            return String(decoding: bytes, as: UTF8.self)
        }
        return String(bytes: bytes, encoding: .utf8)
    }

    private func tokenize(text: String, add_bos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let nTokens = utf8Count + (add_bos ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: nTokens)
        let tokenCount = llama_tokenize(vocab, text, Int32(utf8Count), tokens, Int32(nTokens), add_bos, true)

        var swiftTokens: [llama_token] = []
        for i in 0..<tokenCount {
            swiftTokens.append(tokens[Int(i)])
        }

        tokens.deallocate()
        return swiftTokens
    }

    private func token_to_piece(token: llama_token) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer { result.deallocate() }

        let nTokens = llama_token_to_piece(vocab, token, result, 8, 0, false)
        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer { newResult.deallocate() }

            let nNewTokens = llama_token_to_piece(vocab, token, newResult, -nTokens, 0, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        }

        let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
        return Array(bufferPointer)
    }
}
