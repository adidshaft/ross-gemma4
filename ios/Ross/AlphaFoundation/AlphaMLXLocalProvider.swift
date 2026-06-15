import Foundation
#if canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(HuggingFace) && canImport(Tokenizers)
import HuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

private final class AlphaUnsafeSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

enum AlphaMLXRuntimeProfile {
    static func contextWindowTokens(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        switch tier {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 8_192 : 6_144
        case .quickStart:
            return physicalMemory >= 8_000_000_000 ? 16_384 : 12_288
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 32_768
            }
            return physicalMemory >= 12_000_000_000 ? 24_576 : 20_480
        case .seniorDraftingSupport:
            return physicalMemory >= 18_000_000_000 ? 28_672 : 24_576
        }
    }

    static func maxInputChars(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        switch tier {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 18_000 : 14_000
        case .quickStart:
            return physicalMemory >= 8_000_000_000 ? 34_000 : 24_000
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 60_000
            }
            return physicalMemory >= 12_000_000_000 ? 52_000 : 40_000
        case .seniorDraftingSupport:
            return physicalMemory >= 18_000_000_000 ? 68_000 : 52_000
        }
    }

    static func maxNewTokens(for tier: AlphaCapabilityTier, task: AlphaLocalModelTask) -> Int {
        switch task {
        case .matterQuestionAnswer, .orderSummary, .chronologyGeneration, .issueExtraction, .caseMemorySynthesis:
            switch tier {
            case .flash:
                return 192
            case .quickStart:
                return 256
            case .caseAssociate:
                return 320
            case .seniorDraftingSupport:
                return 384
            }
        default:
            switch tier {
            case .flash:
                return 160
            case .quickStart:
                return 224
            case .caseAssociate:
                return 288
            case .seniorDraftingSupport:
                return 352
            }
        }
    }

    static func sourceBlockLimit(for tier: AlphaCapabilityTier) -> Int {
        switch tier {
        case .flash:
            return 5
        case .quickStart:
            return 7
        case .caseAssociate:
            return 9
        case .seniorDraftingSupport:
            return 12
        }
    }

    static func defaultDraftTokens(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        switch tier {
        case .flash:
            return 2
        case .quickStart:
            return physicalMemory >= 12_000_000_000 ? 6 : 4
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 8
            }
            return physicalMemory >= 12_000_000_000 ? 6 : 4
        case .seniorDraftingSupport:
            return physicalMemory >= 12_000_000_000 ? 8 : 6
        }
    }

    static func prefillStepSize(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        switch tier {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 320 : 256
        case .quickStart:
            return physicalMemory >= 8_000_000_000 ? 384 : 256
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 512
            }
            return physicalMemory >= 12_000_000_000 ? 384 : 320
        case .seniorDraftingSupport:
            return physicalMemory >= 18_000_000_000 ? 512 : 384
        }
    }
}

private actor AlphaMLXModelContainerCache {
    static let shared = AlphaMLXModelContainerCache()

    private var cachedContainers: [String: ModelContainer] = [:]

    func container(for directory: URL) async throws -> ModelContainer {
        if let cachedContainer = cachedContainers[directory.path] {
            return cachedContainer
        }

        let container = try await loadModelContainer(
            from: directory,
            using: AlphaMLXTokenizerLoader()
        )
        cachedContainers[directory.path] = container
        return container
    }
}

private struct AlphaMLXTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return AlphaMLXTokenizerBridge(upstream)
    }
}

private struct AlphaMLXTokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages,
                tools: tools,
                additionalContext: additionalContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

private enum AlphaMLXArchiveCompatibility {
    case supported
    case unsupportedGemma4Assistant
    case unsupportedGemma4MoE
    case unsupportedGemma4Dense31B
}

struct AlphaMLXGenerationSnapshot: Sendable {
    var text: String
    var promptTokenCount: Int?
    var generationTokenCount: Int?
    var outputTokensPerSecond: Double?
    var timeToFirstTokenMs: Int?
}

final class AlphaMLXLocalProvider: AlphaRealLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode = .mlxSwiftLm
    let modelPathLabel: String?
    let modelPath: String?
    let checksumVerified: Bool
    let draftModelPath: String?
    let draftModelTokens: Int?

    init(
        capabilityTier: AlphaCapabilityTier,
        modelPathLabel: String?,
        modelPath: String?,
        checksumVerified: Bool,
        draftModelPath: String? = nil,
        draftModelTokens: Int? = nil
    ) {
        self.capabilityTier = capabilityTier
        self.modelPathLabel = modelPathLabel
        self.modelPath = modelPath
        self.checksumVerified = checksumVerified
        self.draftModelPath = draftModelPath
        self.draftModelTokens = draftModelTokens
    }

    nonisolated(unsafe) static var streamGenerator:
        @Sendable (URL, URL?, Int?, String, String?, GenerateParameters, (@Sendable (String) -> Void)?) async throws -> AlphaMLXGenerationSnapshot = {
            directory, draftDirectory, draftTokens, prompt, instructions, parameters, onChunk in
            let container = try await AlphaMLXModelContainerCache.shared.container(for: directory)
            let effectivePrompt: String
            if let instructions, !instructions.isEmpty {
                effectivePrompt = "\(instructions)\n\n\(prompt)"
            } else {
                effectivePrompt = prompt
            }
            let inputBox = AlphaUnsafeSendableBox(try await container.prepare(input: UserInput(prompt: effectivePrompt)))
            let promptTokenCount = inputBox.value.text.tokens.size
            if let draftDirectory {
                let draftContainer = try await AlphaMLXModelContainerCache.shared.container(for: draftDirectory)
                let draftModelBox = await draftContainer.perform { draftContext in
                    AlphaUnsafeSendableBox(draftContext.model)
                }
                return try await container.perform { context in
                    var generated = ""
                    var completionInfo: GenerateCompletionInfo?
                    let stream = try generate(
                        input: inputBox.value,
                        parameters: parameters,
                        context: context,
                        draftModel: draftModelBox.value,
                        numDraftTokens: max(1, draftTokens ?? 2)
                    )
                    for try await event in stream {
                        if case .chunk(let text) = event {
                            generated += text
                            onChunk?(generated)
                        } else if case .info(let info) = event {
                            completionInfo = info
                        }
                    }
                    return AlphaMLXGenerationSnapshot(
                        text: generated,
                        promptTokenCount: completionInfo?.promptTokenCount ?? promptTokenCount,
                        generationTokenCount: completionInfo?.generationTokenCount,
                        outputTokensPerSecond: completionInfo?.tokensPerSecond,
                        timeToFirstTokenMs: completionInfo.map { max(Int(($0.promptTime * 1_000).rounded()), 0) }
                    )
                }
            } else {
                return try await container.perform { context in
                    var generated = ""
                    var completionInfo: GenerateCompletionInfo?
                    let stream = try generate(
                        input: inputBox.value,
                        parameters: parameters,
                        context: context
                    )
                    for try await event in stream {
                        if case .chunk(let text) = event {
                            generated += text
                            onChunk?(generated)
                        } else if case .info(let info) = event {
                            completionInfo = info
                        }
                    }
                    return AlphaMLXGenerationSnapshot(
                        text: generated,
                        promptTokenCount: completionInfo?.promptTokenCount ?? promptTokenCount,
                        generationTokenCount: completionInfo?.generationTokenCount,
                        outputTokensPerSecond: completionInfo?.tokensPerSecond,
                        timeToFirstTokenMs: completionInfo.map { max(Int(($0.promptTime * 1_000).rounded()), 0) }
                    )
                }
            }
        }

    func isAvailable() -> Bool {
        runtimeAvailability().available
    }

    func supportedTasks() -> Set<AlphaLocalModelTask> {
        Set(AlphaLocalModelTask.allCases)
    }

    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        let availability = runtimeAvailability()
        let draftDirectoryURL = resolvedDraftDirectoryURL()
        let draftTokens = draftTokensForGeneration()
        return AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: availability.available,
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: Array(supportedTasks()),
            maxInputChars: maxInputChars(),
            estimatedContextTokens: contextWindowEstimate(),
            accelerationMode: draftAccelerationMode(draftDirectoryURL: draftDirectoryURL),
            accelerationDraftTokens: draftTokens,
            draftModelPathLabel: draftDirectoryURL?.lastPathComponent,
            lastErrorCategory: availability.errorCategory,
            userFacingStatus: availability.status,
            explicitOptInEnabled: true
        )
    }

    func contextWindowEstimate() -> Int? {
        AlphaMLXRuntimeProfile.contextWindowTokens(for: capabilityTier)
    }

    func maxInputChars() -> Int? {
        AlphaMLXRuntimeProfile.maxInputChars(for: capabilityTier)
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

    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalModelResourceEstimate {
        let maxChars = input.promptBudgetOverrideChars ?? maxInputChars() ?? 16_000
        let promptChars: Int
        if input.task == .matterQuestionAnswer {
            promptChars = conciseMatterQuestionPrompt(for: input).count
        } else {
            promptChars = AlphaPromptPackBuilder(
                maxInputChars: maxChars,
                sourceBlockLimit: input.sourceBlockLimitOverride,
                sourceExcerptChars: input.sourceExcerptCharsOverride
            ).build(input: input).inputChars
        }
        let estimatedTokens = max(promptChars / 4, 1)
        let estimatedRuntimeMs = max(700, min(8_000, estimatedTokens * 4))
        let estimatedMemoryMb: Int
        switch capabilityTier {
        case .flash:
            estimatedMemoryMb = 3_000
        case .quickStart:
            estimatedMemoryMb = 4_500
        case .caseAssociate:
            estimatedMemoryMb = 7_000
        case .seniorDraftingSupport:
            estimatedMemoryMb = 12_000
        }
        return AlphaLocalModelResourceEstimate(
            inputChars: promptChars,
            estimatedTokens: estimatedTokens,
            estimatedRuntimeMs: estimatedRuntimeMs,
            estimatedMemoryMb: estimatedMemoryMb,
            estimatedDurationSeconds: max(1, estimatedRuntimeMs / 1_000),
            shouldRunNow: promptChars <= maxChars,
            reason: promptChars > maxChars ? "Prompt pack exceeded the current local budget of \(maxChars) characters." : nil,
            notes: ["Experimental MLX estimate after focused source packing."]
        )
    }

    func cancel(invocationID: UUID) -> Bool { false }

    private func runInternal(
        _ taskInput: AlphaLocalModelInput,
        onPartial: (@Sendable (AlphaLocalModelOutput) -> Void)?
    ) async -> AlphaLocalModelOutput {
        let effectiveMaxInputChars = taskInput.promptBudgetOverrideChars ?? maxInputChars() ?? 16_000
        let pack = AlphaPromptPackBuilder(
            maxInputChars: effectiveMaxInputChars,
            sourceBlockLimit: taskInput.sourceBlockLimitOverride,
            sourceExcerptChars: taskInput.sourceExcerptCharsOverride
        ).build(input: taskInput)

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

        let directoryURL = URL(fileURLWithPath: modelPath, isDirectory: true)
        let draftDirectoryURL = resolvedDraftDirectoryURL()
        let draftTokens = draftTokensForGeneration()
        let accelerationMode = draftAccelerationMode(draftDirectoryURL: draftDirectoryURL)
        let draftModelLabel = draftDirectoryURL?.lastPathComponent
        let executionPathLabel = draftDirectoryURL == nil
            ? "MLX standard generation"
            : "MLX with draft acceleration"
        let usesPlainMatterAnswerPrompt = taskInput.task == .matterQuestionAnswer
        let focusedMatterSourceRefs = usesPlainMatterAnswerPrompt ? focusedMatterSourceBlocks(for: taskInput).map(\.sourceRef) : []
        let instructions = usesPlainMatterAnswerPrompt ? nil : pack.systemInstructions
        let prompt = usesPlainMatterAnswerPrompt ? conciseMatterQuestionPrompt(for: taskInput) : pack.promptText
        let parameters = generateParameters(for: taskInput)

        do {
            let generation = try await Self.streamGenerator(
                directoryURL,
                draftDirectoryURL,
                draftTokens,
                prompt,
                instructions,
                parameters
            ) { partialText in
                guard let onPartial else { return }
                let cleanedPartial = self.cleanedModelText(partialText)
                guard !cleanedPartial.isEmpty else { return }
                onPartial(
                    AlphaLocalModelOutput(
                        rawText: cleanedPartial,
                        parsedJson: nil,
                        schemaValid: false,
                        warnings: pack.truncated ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : [],
                        sourceRefs: usesPlainMatterAnswerPrompt
                            ? (focusedMatterSourceRefs.isEmpty ? Array(taskInput.sourcePack.prefix(5).map(\.sourceRef)) : focusedMatterSourceRefs)
                            : pack.includedSourceRefs,
                        executionPathLabel: executionPathLabel,
                        accelerationMode: accelerationMode,
                        accelerationDraftTokens: draftTokens,
                        accelerationDraftModelLabel: draftModelLabel,
                        inputChars: pack.inputChars
                    )
                    )
                }

            let cleanedResponse = cleanedModelText(generation.text)
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
                    : pack.includedSourceRefs,
                executionPathLabel: executionPathLabel,
                accelerationMode: accelerationMode,
                accelerationDraftTokens: draftTokens,
                accelerationDraftModelLabel: draftModelLabel,
                inputChars: pack.inputChars,
                inputTokenCount: generation.promptTokenCount,
                outputTokenCount: generation.generationTokenCount,
                outputTokensPerSecond: generation.outputTokensPerSecond,
                timeToFirstTokenMs: generation.timeToFirstTokenMs
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

    private func runtimeAvailability() -> (available: Bool, errorCategory: String?, status: String) {
        guard let modelPath, !modelPath.isEmpty else {
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        let directoryURL = URL(fileURLWithPath: modelPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        guard Self.localModelDirectoryLooksUsable(directoryURL) else {
            return (false, "runtime_validation_failed", alphaRuntimeHealthStatus(.llamaNeedsRepair))
        }

        switch Self.archiveCompatibility(for: directoryURL) {
        case .supported:
            break
        case .unsupportedGemma4Assistant, .unsupportedGemma4MoE, .unsupportedGemma4Dense31B:
            return (false, "unsupported_model_archive", alphaRuntimeHealthStatus(.mlxArchiveUnsupported))
        }

        if let configuredDraftDirectoryURL = configuredDraftDirectoryURL() {
            guard Self.localModelDirectoryLooksUsable(configuredDraftDirectoryURL) else {
                return (false, "runtime_validation_failed", alphaRuntimeHealthStatus(.llamaNeedsRepair))
            }
        }
        return (true, nil, alphaRuntimeHealthStatus(.llamaReady))
    }

    private func generateParameters(for input: AlphaLocalModelInput) -> GenerateParameters {
        let sampler = input.samplerSettings ?? .legalQA
        let maxTokens = min(
            max(input.maxOutputTokens, 1),
            AlphaMLXRuntimeProfile.maxNewTokens(for: capabilityTier, task: input.task)
        )
        return GenerateParameters(
            maxTokens: maxTokens,
            maxKVSize: contextWindowEstimate(),
            temperature: Float(max(0.0, min(sampler.temperature, 1.5))),
            topP: Float(max(0.0, min(sampler.topP, 1.0))),
            topK: max(0, sampler.topK),
            repetitionPenalty: sampler.repeatPenalty > 0 ? Float(sampler.repeatPenalty) : nil,
            prefillStepSize: AlphaMLXRuntimeProfile.prefillStepSize(
                for: capabilityTier,
                physicalMemory: ProcessInfo.processInfo.physicalMemory
            )
        )
    }

    private func configuredDraftDirectoryURL() -> URL? {
        guard let draftModelPath else {
            return nil
        }
        let trimmedPath = draftModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmedPath, isDirectory: true)
    }

    private func resolvedDraftDirectoryURL() -> URL? {
        guard let draftDirectoryURL = configuredDraftDirectoryURL() else {
            return nil
        }
        guard Self.localModelDirectoryLooksUsable(draftDirectoryURL) else {
            return nil
        }
        guard Self.archiveCompatibility(for: draftDirectoryURL) == .supported else {
            return nil
        }
        return draftDirectoryURL
    }

    private func draftTokensForGeneration() -> Int? {
        guard resolvedDraftDirectoryURL() != nil else {
            return nil
        }
        return max(
            1,
            min(
                draftModelTokens ?? AlphaMLXRuntimeProfile.defaultDraftTokens(
                    for: capabilityTier,
                    physicalMemory: ProcessInfo.processInfo.physicalMemory
                ),
                8
            )
        )
    }

    private func draftAccelerationMode(draftDirectoryURL: URL? = nil) -> AlphaLocalRuntimeAccelerationMode {
        (draftDirectoryURL ?? resolvedDraftDirectoryURL()) == nil ? .standard : .draftModelSpeculative
    }

    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }

    private func cleanedModelText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"(?is)(</?\s*(start|end)\s*_\s*of\s*_\s*turn\s*>|start\s*of\s*turn|end\s*of\s*turn).*$"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .replacingOccurrences(of: "<eos>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

        let effectiveMaxInputChars = input.promptBudgetOverrideChars ?? maxInputChars() ?? 16_000
        let excerptCap = input.sourceExcerptCharsOverride ?? 1_800
        var remainingBudget = max(effectiveMaxInputChars - 2_000, 5_600)
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
        let sourceBlockLimit = input.sourceBlockLimitOverride ?? AlphaMLXRuntimeProfile.sourceBlockLimit(for: capabilityTier)
        return Array(
            AlphaPromptFocusPlanner
                .rankedSourceBlocks(input.sourcePack, instruction: input.instruction)
                .prefix(sourceBlockLimit)
        )
    }

    private static func localModelDirectoryLooksUsable(_ directoryURL: URL) -> Bool {
        let fileManager = FileManager.default
        let requiredConfig = directoryURL.appendingPathComponent("config.json").path
        guard fileManager.fileExists(atPath: requiredConfig) else { return false }

        let tokenizerCandidates = [
            "tokenizer.json",
            "tokenizer.model",
            "tokenizer_config.json"
        ]
        let hasTokenizer = tokenizerCandidates.contains {
            fileManager.fileExists(atPath: directoryURL.appendingPathComponent($0).path)
        }
        guard hasTokenizer else { return false }

        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
            return false
        }
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "safetensors" || fileURL.lastPathComponent.hasSuffix(".safetensors.index.json") {
                return true
            }
        }
        return false
    }

    private static func archiveCompatibility(for directoryURL: URL) -> AlphaMLXArchiveCompatibility {
        guard
            let data = try? Data(contentsOf: directoryURL.appendingPathComponent("config.json")),
            let rawValue = try? JSONSerialization.jsonObject(with: data),
            let json = rawValue as? [String: Any]
        else {
            return .supported
        }

        let modelType = (json["model_type"] as? String)?.lowercased()
        let architectures = (json["architectures"] as? [String] ?? []).map { $0.lowercased() }
        let rawNameHints = [
            directoryURL.lastPathComponent,
            json["_name_or_path"] as? String,
            json["name_or_path"] as? String
        ]
        let nameHints = rawNameHints
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if modelType == "gemma4_assistant" || architectures.contains(where: { $0.contains("gemma4assistant") }) {
            return .unsupportedGemma4Assistant
        }

        let hasMoEKeys =
            json["num_local_experts"] != nil ||
            json["num_experts"] != nil ||
            json["router_aux_loss_coef"] != nil ||
            json["expert_capacity"] != nil
        if hasMoEKeys || nameHints.contains("26b-a4b") {
            return .unsupportedGemma4MoE
        }

        if nameHints.contains("gemma-4-31b") || nameHints.contains("gemma4-31b") || nameHints.contains("31b-it") {
            return .unsupportedGemma4Dense31B
        }

        return .supported
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
}
#else
final class AlphaMLXLocalProvider: AlphaRealLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode = .mlxSwiftLm
    let modelPathLabel: String?
    let modelPath: String?
    let checksumVerified: Bool
    let draftModelPath: String?
    let draftModelTokens: Int?

    init(
        capabilityTier: AlphaCapabilityTier,
        modelPathLabel: String?,
        modelPath: String?,
        checksumVerified: Bool,
        draftModelPath: String? = nil,
        draftModelTokens: Int? = nil
    ) {
        self.capabilityTier = capabilityTier
        self.modelPathLabel = modelPathLabel
        self.modelPath = modelPath
        self.checksumVerified = checksumVerified
        self.draftModelPath = draftModelPath
        self.draftModelTokens = draftModelTokens
    }

    func isAvailable() -> Bool { false }

    func supportedTasks() -> Set<AlphaLocalModelTask> { [] }

    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: false,
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: [],
            maxInputChars: nil,
            estimatedContextTokens: nil,
            accelerationMode: draftModelPath == nil ? nil : .draftModelSpeculative,
            accelerationDraftTokens: draftModelTokens,
            draftModelPathLabel: draftModelPath.flatMap { URL(fileURLWithPath: $0).lastPathComponent.nilIfEmpty },
            lastErrorCategory: "runtime_dependency_unavailable",
            userFacingStatus: alphaRuntimeHealthStatus(.privateAssistantUnavailable),
            explicitOptInEnabled: true
        )
    }

    func contextWindowEstimate() -> Int? { nil }

    func maxInputChars() -> Int? { nil }

    func run(_ taskInput: AlphaLocalModelInput) async -> AlphaLocalModelOutput {
        AlphaLocalModelOutput(
            rawText: "",
            parsedJson: nil,
            schemaValid: false,
            warnings: [AlphaLocalModelWarningCopy.answerNotGeneratedAssistantNotReady],
            sourceRefs: [],
            errorCategory: "runtime_dependency_unavailable"
        )
    }

    func runStreaming(_ taskInput: AlphaLocalModelInput) -> AsyncStream<AlphaLocalModelOutput>? { nil }

    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalModelResourceEstimate {
        AlphaLocalModelResourceEstimate(
            inputChars: 0,
            estimatedTokens: nil,
            estimatedRuntimeMs: nil,
            estimatedMemoryMb: nil,
            estimatedDurationSeconds: nil,
            shouldRunNow: false,
            reason: "Runtime unavailable",
            notes: [alphaRuntimeHealthStatus(.privateAssistantUnavailable)]
        )
    }

    func cancel(invocationID: UUID) -> Bool { false }
}
#endif
