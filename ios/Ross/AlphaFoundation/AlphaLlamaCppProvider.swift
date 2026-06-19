import Foundation
import LlamaSwift

enum AlphaLlamaRuntimeProfile {
    private enum ArchiveProfile {
        case flash
        case e4b
        case gemma12b
        case gemma26bA4b
        case unknown
    }

    private static let constrainedE4BProfileMemoryCeilingBytes: UInt64 = 8_500_000_000
    private static let constrainedE4BDraftArtifactBudgetRatio = 0.72
    private static let constrainedE4BDraftTokenCeiling = 2

    private static func containsAny(_ value: String, fragments: [String]) -> Bool {
        let lowered = value.lowercased()
        return fragments.contains { lowered.contains($0.lowercased()) }
    }

    private static func archiveProfile(forModelPath path: String?) -> ArchiveProfile {
        guard let path else { return .unknown }
        if containsAny(path, fragments: ["E2B", "e2b"]) {
            return .flash
        }
        if containsAny(path, fragments: ["26B-A4B", "26b-a4b"]) {
            return .gemma26bA4b
        }
        if containsAny(path, fragments: ["12B", "12b"]) {
            return .gemma12b
        }
        if containsAny(path, fragments: ["E4B", "e4b"]) {
            return .e4b
        }
        return .unknown
    }

    private static func usesConstrainedE4BProfile(
        forModelPath path: String?,
        physicalMemory: UInt64
    ) -> Bool {
        archiveProfile(forModelPath: path) == .e4b &&
            physicalMemory < constrainedE4BProfileMemoryCeilingBytes
    }

    static func smokeContextOverrideTokens(environment: [String: String] = ProcessInfo.processInfo.environment) -> UInt32? {
        let rawProfile = environment["ROSS_LOCAL_MODEL_SMOKE_PROFILE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch rawProfile {
        case "mtp", "mtp-quick", "mtp_quick", "quick-low-context", "quick_low_context":
            return 1_024
        default:
            return nil
        }
    }

    static func effectiveContextWindowTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UInt32 {
        let baseline = contextWindowTokens(forModelPath: path, physicalMemory: physicalMemory)
        guard let smokeOverride = smokeContextOverrideTokens(environment: environment) else {
            return baseline
        }
        return min(baseline, smokeOverride)
    }

    static func effectivePromptBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UInt32 {
        let baseline = promptBatchTokens(forModelPath: path, physicalMemory: physicalMemory)
        guard smokeContextOverrideTokens(environment: environment) != nil else {
            return baseline
        }
        if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
            return min(baseline, 128)
        }
        return min(baseline, 256)
    }

    static func effectivePhysicalBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UInt32 {
        let baseline = physicalBatchTokens(forModelPath: path, physicalMemory: physicalMemory)
        guard smokeContextOverrideTokens(environment: environment) != nil else {
            return baseline
        }
        return min(baseline, 64)
    }

    static func minimumSupportedMemoryBytes(forModelPath path: String?) -> UInt64 {
        switch archiveProfile(forModelPath: path) {
        case .flash:
            return 4_000_000_000
        case .e4b:
            return 4_000_000_000
        case .gemma12b:
            return 12_000_000_000
        case .gemma26bA4b:
            return 12_000_000_000
        case .unknown:
            return 4_000_000_000
        }
    }

    static func contextWindowTokens(forModelPath path: String?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> UInt32 {
        if physicalMemory < 6_000_000_000 {
            return 4_096
        }

        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 8_192 : 6_144
        case .e4b:
            if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
                return 4_096
            }
            if physicalMemory >= 12_000_000_000 {
                return 24_576
            }
            return physicalMemory >= 8_000_000_000 ? 18_432 : 10_240
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 40_960
            }
            if physicalMemory >= 12_000_000_000 {
                return 28_672
            }
            return 20_480
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 28_672
            }
            return physicalMemory >= 16_000_000_000 ? 20_480 : 12_288
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 14_336 : 10_240
        }
    }

    static func gpuLayerCount(forModelPath path: String?, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Int32 {
        if physicalMemory < 6_000_000_000 {
            return 0
        }

        switch archiveProfile(forModelPath: path) {
        case .flash:
            if physicalMemory < 8_000_000_000 {
                return 20
            }
            return 40
        case .e4b:
            // Real device proof on 7 GB-class A17 Pro phones showed the aggressive
            // all-GPU E4B profile crashing during Metal allocation, and the later
            // patched-scheduler proof plus the 12-layer / 4096-token follow-up
            // still ran out of GPU memory during decode. Keep this lane on the
            // smallest residency budget until a stable physical-device proof says
            // otherwise.
            if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
                return 0
            }
            if physicalMemory < 8_000_000_000 {
                return 32
            }
            return 99
        case .gemma12b:
            if physicalMemory < 8_000_000_000 {
                return 24
            }
            if physicalMemory < 12_000_000_000 {
                return 56
            }
            return 99
        case .gemma26bA4b:
            if physicalMemory < 12_000_000_000 {
                return 0
            }
            if physicalMemory < 18_000_000_000 {
                return 24
            }
            return 40
        case .unknown:
            return physicalMemory < 10_000_000_000 ? 32 : 99
        }
    }

    static func shouldOffloadKQV(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Bool {
        // Keep the constrained 7 GB-class E4B lane off GPU-backed KQV/KV
        // scheduling as well, because the current upstream runtime still
        // converges on the same split-input assertion on device.
        if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
            return false
        }
        return gpuLayerCount(forModelPath: path, physicalMemory: physicalMemory) > 0
    }

    static func shouldOffloadHostOperations(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Bool {
        // Keep the constrained 7 GB-class E4B lane off the extra host-op
        // offload path because the current upstream scheduler still hits the
        // split-input assertion there during physical-device setup.
        if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
            return false
        }
        return gpuLayerCount(forModelPath: path, physicalMemory: physicalMemory) > 0
    }

    static func maxInputChars(for tier: AlphaCapabilityTier, physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> Int {
        switch tier {
        case .flash:
            return 12_000
        case .quickStart:
            return physicalMemory >= constrainedE4BProfileMemoryCeilingBytes ? 36_000 : 22_000
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                return 72_000
            }
            return physicalMemory >= 12_000_000_000 ? 56_000 : 40_000
        case .seniorDraftingSupport:
            if physicalMemory >= 20_000_000_000 {
                return 72_000
            }
            return physicalMemory >= 16_000_000_000 ? 60_000 : 44_000
        }
    }

    static func maxNewTokens(for tier: AlphaCapabilityTier, task: AlphaLocalModelTask) -> Int32 {
        switch task {
        case .matterQuestionAnswer, .orderSummary, .chronologyGeneration, .issueExtraction, .caseMemorySynthesis:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 224
            case .caseAssociate:
                return 320
            case .seniorDraftingSupport:
                return 384
            }
        default:
            switch tier {
            case .flash:
                return 128
            case .quickStart:
                return 224
            case .caseAssociate:
                return 320
            case .seniorDraftingSupport:
                return 384
            }
        }
    }

    static func sourceBlockLimit(for tier: AlphaCapabilityTier) -> Int {
        switch tier {
        case .flash:
            return 4
        case .quickStart:
            return 7
        case .caseAssociate:
            return 9
        case .seniorDraftingSupport:
            return 12
        }
    }

    static func promptBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> UInt32 {
        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 1_024 : 768
        case .e4b:
            if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
                return 512
            }
            if physicalMemory >= 12_000_000_000 {
                return 2_048
            }
            return physicalMemory >= 8_000_000_000 ? 1_536 : 1_024
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 2_560
            }
            return physicalMemory >= 12_000_000_000 ? 2_048 : 1_280
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 1_792
            }
            return physicalMemory >= 16_000_000_000 ? 1_280 : 896
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 1_536 : 1_024
        }
    }

    static func physicalBatchTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> UInt32 {
        switch archiveProfile(forModelPath: path) {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 768 : 512
        case .e4b:
            if usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) {
                return 128
            }
            if physicalMemory >= 12_000_000_000 {
                return 1_536
            }
            return physicalMemory >= 8_000_000_000 ? 1_024 : 768
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                return 2_048
            }
            return physicalMemory >= 12_000_000_000 ? 1_536 : 1_024
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                return 1_280
            }
            return physicalMemory >= 16_000_000_000 ? 1_024 : 640
        case .unknown:
            return physicalMemory >= 10_000_000_000 ? 1_024 : 768
        }
    }

    static func defaultDraftTokens(
        for tier: AlphaCapabilityTier,
        modelPath: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        let suggestedTokens: Int
        switch archiveProfile(forModelPath: modelPath) {
        case .flash:
            suggestedTokens = physicalMemory >= 8_000_000_000 ? 4 : 2
        case .e4b:
            if usesConstrainedE4BProfile(forModelPath: modelPath, physicalMemory: physicalMemory) {
                suggestedTokens = 2
            } else {
                suggestedTokens = physicalMemory >= 12_000_000_000 ? 6 : 4
            }
        case .gemma12b:
            if physicalMemory >= 16_000_000_000 {
                suggestedTokens = 8
            } else {
                suggestedTokens = physicalMemory >= 12_000_000_000 ? 6 : 4
            }
        case .gemma26bA4b:
            if physicalMemory >= 20_000_000_000 {
                suggestedTokens = 8
            } else if physicalMemory >= 16_000_000_000 {
                suggestedTokens = 6
            } else {
                suggestedTokens = 4
            }
        case .unknown:
            switch tier {
            case .flash:
                suggestedTokens = 2
            case .quickStart:
                suggestedTokens = physicalMemory >= 12_000_000_000 ? 6 : 4
            case .caseAssociate:
                if physicalMemory >= 16_000_000_000 {
                    suggestedTokens = 8
                } else {
                    suggestedTokens = physicalMemory >= 12_000_000_000 ? 6 : 4
                }
            case .seniorDraftingSupport:
                suggestedTokens = physicalMemory >= 16_000_000_000 ? 6 : 4
            }
        }
        return max(1, min(suggestedTokens, 8))
    }

    static func supportsDraftAcceleration(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        draftTokens: Int? = nil
    ) -> Bool {
        guard usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) else {
            return true
        }
        guard let draftTokens else { return false }
        return max(1, min(draftTokens, 8)) <= constrainedE4BDraftTokenCeiling
    }

    static func maximumSupportedDraftTokens(
        forModelPath path: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Int {
        usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory)
            ? constrainedE4BDraftTokenCeiling
            : 8
    }

    static func draftArtifactMemoryPolicy(
        forModelPath path: String?,
        draftPath: String?,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> (allowed: Bool, mainBytes: UInt64?, draftBytes: UInt64?, maxCombinedBytes: UInt64?) {
        guard usesConstrainedE4BProfile(forModelPath: path, physicalMemory: physicalMemory) else {
            return (true, nil, nil, nil)
        }
        guard let path, let draftPath else {
            return (true, nil, nil, nil)
        }
        guard
            let mainBytes = fileSizeBytes(atPath: path),
            let draftBytes = fileSizeBytes(atPath: draftPath)
        else {
            return (true, nil, nil, nil)
        }

        let maxCombinedBytes = UInt64(Double(physicalMemory) * constrainedE4BDraftArtifactBudgetRatio)
        return (
            mainBytes <= UInt64.max - draftBytes && mainBytes + draftBytes <= maxCombinedBytes,
            mainBytes,
            draftBytes,
            maxCombinedBytes
        )
    }

    private static func fileSizeBytes(atPath path: String) -> UInt64? {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.uint64Value else {
            return nil
        }
        return size > 0 ? size : nil
    }

}

final class AlphaLlamaCppProvider: AlphaRealLocalModelProvider {
    let capabilityTier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode = .llamaCppGguf
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
    
    func isAvailable() -> Bool {
        runtimeAvailability().available
    }

    private func runtimeAvailability() -> (available: Bool, errorCategory: String?, status: String) {
        guard let modelPath, !modelPath.isEmpty else {
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        let physicalMemoryBytes = Self.physicalMemoryBytesProvider()
        let minimumSupportedMemoryBytes = AlphaLlamaRuntimeProfile.minimumSupportedMemoryBytes(forModelPath: modelPath)
        guard physicalMemoryBytes >= minimumSupportedMemoryBytes else {
            return (false, "insufficient_device_memory", alphaRuntimeHealthStatus(.llamaNeedsMoreMemory))
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
            return (false, "missing_model_file", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        do {
            // Reuse the same prepared context across repeated runtime-health
            // probes and the first real run so constrained phones do not pay
            // for multiple full GGUF loads back to back.
            _ = try getOrContext(path: modelPath, includeDraft: false)
            return (true, nil, alphaRuntimeHealthStatus(.llamaReady))
        } catch {
            return (false, "runtime_validation_failed", alphaRuntimeHealthStatus(.llamaNeedsRepair))
        }
    }

    nonisolated(unsafe) static var modelLoadValidator: (String) throws -> Void = { path in
        _ = try LlamaContext.create_context(path: path)
    }

    nonisolated(unsafe) static var physicalMemoryBytesProvider: () -> UInt64 = {
        ProcessInfo.processInfo.physicalMemory
    }

    nonisolated(unsafe) static var contextFactory: (String, String?, Int?) throws -> any AlphaLlamaCompletionContext = {
        path, draftPath, draftTokens in
        try LlamaContext.create_context(
            path: path,
            draftPath: draftPath,
            draftTokens: draftTokens
        )
    }

    nonisolated(unsafe) static var strictDraftContextFactory: (String, String, Int?) throws -> any AlphaLlamaCompletionContext = {
        path, draftPath, draftTokens in
        try LlamaContext.create_context(
            path: path,
            draftPath: draftPath,
            draftTokens: draftTokens,
            strictDraftSetup: true
        )
    }

    nonisolated(unsafe) static var draftAccelerationValidator: (String, String, Int?) throws -> Bool = {
        path, draftPath, draftTokens in
        try LlamaContext.create_context(
            path: path,
            draftPath: draftPath,
            draftTokens: draftTokens,
            strictDraftSetup: true
        ).configuredAccelerationMode == .draftModelSpeculative
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
        let draftValidation = validatedDraftMetadata(runtimeAvailable: availability.available)
        let accelerationMode: AlphaLocalRuntimeAccelerationMode =
            availability.available && draftValidation.status == "active"
            ? .draftModelSpeculative
            : .standard
        let activeDraftMetadata = draftValidation.status == "active" ? draftValidation.metadata : nil
        let candidateDraftMetadata = draftValidation.metadata
        let draftErrorCategory = Self.draftAccelerationErrorCategory(
            for: draftValidation.status,
            runtimeAvailable: availability.available
        )
        return AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: availability.available,
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: Array(supportedTasks()),
            maxInputChars: maxInputChars(),
            estimatedContextTokens: contextWindowEstimate(),
            accelerationMode: accelerationMode,
            accelerationDraftTokens: activeDraftMetadata?.tokens,
            draftModelPathLabel: activeDraftMetadata?.label,
            draftModelPathType: draftModelPathType(),
            draftCandidateTokens: candidateDraftMetadata?.tokens,
            draftCandidatePathLabel: candidateDraftMetadata?.label,
            draftAccelerationStatus: draftValidation.status,
            draftAccelerationDetail: draftValidation.detail,
            runtimeErrorDetail: availability.errorCategory,
            lastErrorCategory: availability.errorCategory ?? draftErrorCategory,
            userFacingStatus: availability.status,
            explicitOptInEnabled: true
        )
    }
    
    func contextWindowEstimate() -> Int? {
        Int(AlphaLlamaRuntimeProfile.effectiveContextWindowTokens(forModelPath: modelPath))
    }
    
    func maxInputChars() -> Int? {
        AlphaLlamaRuntimeProfile.maxInputChars(for: capabilityTier)
    }
    
    nonisolated(unsafe) private static var cachedContext: (any AlphaLlamaCompletionContext)?
    nonisolated(unsafe) private static var cachedKey: String?
    nonisolated(unsafe) private static var degenerateDraftKeys: Set<String> = []
    private static let cacheLock = NSLock()
    private static let degenerateDraftLock = NSLock()

    private func draftHealthKey(path: String, draftPath: String, draftTokens: Int?) -> String {
        [path, draftPath, draftTokens.map(String.init) ?? "nil"].joined(separator: "|")
    }

    private func activeDraftHealthKey(path: String) -> String? {
        guard let draftPath = stagedDraftModelPath() else {
            return nil
        }
        return draftHealthKey(path: path, draftPath: draftPath, draftTokens: effectiveDraftTokenCount())
    }

    private static func draftOutputPreviouslyDegenerated(_ key: String?) -> Bool {
        guard let key else { return false }
        degenerateDraftLock.lock()
        defer { degenerateDraftLock.unlock() }
        return degenerateDraftKeys.contains(key)
    }

    private static func markDraftOutputDegenerated(_ key: String?) {
        guard let key else { return }
        degenerateDraftLock.lock()
        degenerateDraftKeys.insert(key)
        degenerateDraftLock.unlock()

        cacheLock.lock()
        cachedContext = nil
        cachedKey = nil
        cacheLock.unlock()
    }

    private func contextCacheKey(path: String, includeDraft: Bool = true) -> String {
        let draftKey = includeDraft ? (effectiveDraftModelPath() ?? "") : ""
        let tokenKey = draftKey.isEmpty ? "" : (effectiveDraftTokenCount().map(String.init) ?? "")
        let smokeContextKey = AlphaLlamaRuntimeProfile.smokeContextOverrideTokens()
            .map { "smoke_ctx:\($0)" } ?? "smoke_ctx:none"
        return [path, draftKey, tokenKey, smokeContextKey].joined(separator: "|")
    }

    private func getOrContext(path: String, includeDraft: Bool = true) throws -> any AlphaLlamaCompletionContext {
        AlphaLlamaCppProvider.cacheLock.lock()
        defer { AlphaLlamaCppProvider.cacheLock.unlock() }

        let cacheKey = contextCacheKey(path: path, includeDraft: includeDraft)
        if let cached = AlphaLlamaCppProvider.cachedContext, AlphaLlamaCppProvider.cachedKey == cacheKey {
            return cached
        }

        AlphaLlamaCppProvider.cachedContext = nil

        let draftPath = includeDraft ? effectiveDraftModelPath() : nil
        let draftTokens = draftPath == nil ? nil : effectiveDraftTokenCount()
        let newContext: any AlphaLlamaCompletionContext
        if includeDraft,
           let draftPath,
           AlphaLlamaCppProvider.smokeRequiresDraftAcceleration() {
            newContext = try AlphaLlamaCppProvider.strictDraftContextFactory(
                path,
                draftPath,
                draftTokens
            )
        } else {
            newContext = try AlphaLlamaCppProvider.contextFactory(
                path,
                draftPath,
                draftTokens
            )
        }
        AlphaLlamaCppProvider.cachedContext = newContext
        AlphaLlamaCppProvider.cachedKey = cacheKey
        return newContext
    }

    private static func smokeRequiresDraftAcceleration(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let rawValue = environment["ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return ["1", "true", "yes", "on"].contains(rawValue)
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
        let effectiveMaxInputChars = taskInput.promptBudgetOverrideChars ?? maxInputChars() ?? 7_000
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
                sourceRefs: pack.includedSourceRefs,
                packedSourceCount: pack.includedSourceRefs.count,
                omittedSourceCount: pack.omittedSourceRefs.count,
                omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                errorCategory: "model_path_missing"
            )
        }
        
        do {
            let context: any AlphaLlamaCompletionContext
            do {
                context = try getOrContext(path: modelPath)
            } catch {
                return AlphaLocalModelOutput(
                    rawText: "",
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: [AlphaLocalModelWarningCopy.assistantCouldNotFinish],
                    sourceRefs: pack.includedSourceRefs,
                    packedSourceCount: pack.includedSourceRefs.count,
                    omittedSourceCount: pack.omittedSourceRefs.count,
                    omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                    errorCategory: inferenceFailureCategory(contextCreationFailed: true),
                    runtimeErrorDetail: alphaRuntimeSafeErrorDetail(error)
                )
            }
            await context.clear()
            let runStartedAt = Date()
            
            let usesPlainMatterAnswerPrompt = taskInput.task == .matterQuestionAnswer
            let systemPrompt = usesPlainMatterAnswerPrompt ? "" : pack.systemInstructions
            let userPrompt = pack.promptText
            let combinedPrompt: String
            if usesPlainMatterAnswerPrompt {
                // Matter chat is free-form text, and some GGUF exports already
                // carry Gemma chat-template behavior. Plain prompting avoids
                // the model echoing <start_of_turn>/<end_of_turn> markers.
                combinedPrompt = "\(userPrompt)\n"
            } else if systemPrompt.isEmpty {
                combinedPrompt = "<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            } else {
                combinedPrompt = "<start_of_turn>user\n\(systemPrompt)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            }
            
            let maxNewTokens = min(
                Int32(max(taskInput.maxOutputTokens, 1)),
                AlphaLlamaRuntimeProfile.maxNewTokens(for: capabilityTier, task: taskInput.task)
            )
            try await context.completionInit(
                text: combinedPrompt,
                maxNewTokens: maxNewTokens,
                samplerSettings: taskInput.samplerSettings ?? .legalQA
            )
            let promptTokenCount = await context.promptTokenCount()
            if Self.smokeRequiresDraftAcceleration(),
               stagedDraftModelPath() != nil {
                let initialAccelerationMode = await context.accelerationMode()
                guard initialAccelerationMode == .draftModelSpeculative else {
                    return draftAccelerationInactiveOutput(
                        pack: pack,
                        promptTokenCount: promptTokenCount,
                        outputTokenCount: await context.generatedTokenCount(),
                        activeAccelerationMode: initialAccelerationMode
                    )
                }
            }
            
            var generatedResponse = ""
            var lastEmittedPartialText: String?
            var timeToFirstTokenMs: Int?
            let generationLoopStartedAt = Date()
            while await !context.isDone() {
                let tokenStr = await context.completionLoop()
                if Self.smokeRequiresDraftAcceleration(),
                   stagedDraftModelPath() != nil {
                    let loopAccelerationMode = await context.accelerationMode()
                    guard loopAccelerationMode == .draftModelSpeculative else {
                        return draftAccelerationInactiveOutput(
                            pack: pack,
                            promptTokenCount: promptTokenCount,
                            outputTokenCount: await context.generatedTokenCount(),
                            activeAccelerationMode: loopAccelerationMode
                        )
                    }
                }
                generatedResponse += tokenStr
                let generatedTokenCount = await context.generatedTokenCount()
                if generatedTokenCount > 0, timeToFirstTokenMs == nil {
                    timeToFirstTokenMs = max(Int(Date().timeIntervalSince(runStartedAt) * 1_000), 0)
                }
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
                    if Self.shouldEmitStreamingPartial(
                        cleanedPartial: cleanedPartial,
                        lastEmittedPartialText: lastEmittedPartialText,
                        latestToken: tokenStr
                    ) {
                        lastEmittedPartialText = cleanedPartial
                        let activeExecutionPathLabel = await context.executionPathLabel()
                        let activeAccelerationMode = await context.accelerationMode()
                        let surfacedDraftMetadata = surfacedDraftMetadata(for: activeAccelerationMode)
                        let partialOutput = AlphaLocalModelOutput(
                            rawText: cleanedPartial,
                            parsedJson: nil,
                            schemaValid: false,
                            warnings: pack.truncated ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : [],
                            sourceRefs: pack.includedSourceRefs,
                            packedSourceCount: pack.includedSourceRefs.count,
                            omittedSourceCount: pack.omittedSourceRefs.count,
                            omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                            executionPathLabel: activeExecutionPathLabel,
                            accelerationMode: activeAccelerationMode,
                            accelerationDraftTokens: surfacedDraftMetadata?.tokens,
                            accelerationDraftModelLabel: surfacedDraftMetadata?.label,
                            inputChars: pack.inputChars
                        )
                        onPartial(partialOutput)
                    }
                }
                
                // Safety cutoff for runaway generation
                if generatedResponse.count > max(effectiveMaxInputChars, 12_000) { break }
            }
            let generationLoopEndedAt = Date()
            let outputTokenCount = await context.generatedTokenCount()
            let outputTokensPerSecond: Double?
            if outputTokenCount > 0 {
                let elapsedSeconds = max(generationLoopEndedAt.timeIntervalSince(generationLoopStartedAt), 0.001)
                outputTokensPerSecond = Double(outputTokenCount) / elapsedSeconds
            } else {
                outputTokensPerSecond = nil
            }
            let activeExecutionPathLabel = await context.executionPathLabel()
            let activeAccelerationMode = await context.accelerationMode()
            let surfacedDraftMetadata = surfacedDraftMetadata(for: activeAccelerationMode)
            let speculativeDraftMetrics = await context.speculativeDraftMetrics()
            
            let cleanedResponse = stripTurnMarkerFragments(from: generatedResponse)
            if activeAccelerationMode == .draftModelSpeculative,
               Self.isDegenerateDraftOutput(cleanedResponse) {
                Self.markDraftOutputDegenerated(activeDraftHealthKey(path: modelPath))
                var warnings = pack.truncated ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : []
                warnings.append("Draft acceleration produced degenerate output; rerun with draft disabled.")
                return AlphaLocalModelOutput(
                    rawText: cleanedResponse,
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: warnings,
                    sourceRefs: pack.includedSourceRefs,
                    packedSourceCount: pack.includedSourceRefs.count,
                    omittedSourceCount: pack.omittedSourceRefs.count,
                    omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                    executionPathLabel: activeExecutionPathLabel,
                    accelerationMode: activeAccelerationMode,
                    accelerationDraftTokens: surfacedDraftMetadata?.tokens,
                    accelerationDraftModelLabel: surfacedDraftMetadata?.label,
                    speculativeDraftTokenAttempts: speculativeDraftMetrics?.attemptedTokens,
                    speculativeDraftTokenAccepts: speculativeDraftMetrics?.acceptedTokens,
                    speculativeDraftFailureReason: speculativeDraftMetrics?.lastFailureReason,
                    inputChars: pack.inputChars,
                    inputTokenCount: promptTokenCount,
                    outputTokenCount: outputTokenCount,
                    outputTokensPerSecond: outputTokensPerSecond,
                    timeToFirstTokenMs: timeToFirstTokenMs,
                    errorCategory: "draft_output_degenerate"
                )
            }
            let languagePreservingFallback = usesPlainMatterAnswerPrompt
                ? Self.sourceLanguageFallbackIfNeeded(
                    for: taskInput,
                    sourcePack: pack.includedSourceBlocks,
                    generatedText: cleanedResponse
                )
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
                sourceRefs: pack.includedSourceRefs,
                packedSourceCount: pack.includedSourceRefs.count,
                omittedSourceCount: pack.omittedSourceRefs.count,
                omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                executionPathLabel: activeExecutionPathLabel,
                accelerationMode: activeAccelerationMode,
                accelerationDraftTokens: surfacedDraftMetadata?.tokens,
                accelerationDraftModelLabel: surfacedDraftMetadata?.label,
                speculativeDraftTokenAttempts: speculativeDraftMetrics?.attemptedTokens,
                speculativeDraftTokenAccepts: speculativeDraftMetrics?.acceptedTokens,
                speculativeDraftFailureReason: speculativeDraftMetrics?.lastFailureReason,
                inputChars: pack.inputChars,
                inputTokenCount: promptTokenCount,
                outputTokenCount: outputTokenCount,
                outputTokensPerSecond: outputTokensPerSecond,
                timeToFirstTokenMs: timeToFirstTokenMs
            )
        } catch {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: [AlphaLocalModelWarningCopy.assistantCouldNotFinish],
                sourceRefs: pack.includedSourceRefs,
                packedSourceCount: pack.includedSourceRefs.count,
                omittedSourceCount: pack.omittedSourceRefs.count,
                omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
                errorCategory: inferenceFailureCategory(contextCreationFailed: false),
                runtimeErrorDetail: alphaRuntimeSafeErrorDetail(error)
            )
        }
    }

    private func inferenceFailureCategory(contextCreationFailed: Bool) -> String {
        guard Self.smokeRequiresDraftAcceleration() else {
            return "inference_failed"
        }
        guard stagedDraftModelPath() != nil else {
            return "draft_acceleration_required"
        }
        return contextCreationFailed ? "draft_context_failed" : "draft_generation_failed"
    }

    private func draftAccelerationInactiveOutput(
        pack: AlphaLocalPromptPack,
        promptTokenCount: Int,
        outputTokenCount: Int,
        activeAccelerationMode: AlphaLocalRuntimeAccelerationMode
    ) -> AlphaLocalModelOutput {
        AlphaLocalModelOutput(
            rawText: "",
            parsedJson: nil,
            schemaValid: false,
            warnings: [AlphaLocalModelWarningCopy.assistantCouldNotFinish],
            sourceRefs: pack.includedSourceRefs,
            packedSourceCount: pack.includedSourceRefs.count,
            omittedSourceCount: pack.omittedSourceRefs.count,
            omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
            executionPathLabel: activeAccelerationMode == .draftModelSpeculative
                ? "Gemma GGUF with draft acceleration"
                : "Gemma GGUF via llama.cpp",
            accelerationMode: activeAccelerationMode,
            accelerationDraftTokens: nil,
            accelerationDraftModelLabel: nil,
            inputChars: pack.inputChars,
            inputTokenCount: promptTokenCount,
            outputTokenCount: outputTokenCount,
            errorCategory: "draft_acceleration_inactive",
            runtimeErrorDetail: "draft_acceleration_inactive"
        )
    }
    
    func estimateCostOrResourceUse(_ input: AlphaLocalModelInput) -> AlphaLocalModelResourceEstimate {
        let maxChars = input.promptBudgetOverrideChars ?? maxInputChars() ?? 12_000
        let promptChars = AlphaPromptPackBuilder(
            maxInputChars: maxChars,
            sourceBlockLimit: input.sourceBlockLimitOverride,
            sourceExcerptChars: input.sourceExcerptCharsOverride
        ).build(input: input).inputChars
        let estimatedTokens = max(promptChars / 4, 1)
        let estimatedRuntimeMs = max(900, min(12_000, estimatedTokens * 6))
        let estimatedMemoryMb: Int
        switch capabilityTier {
        case .flash:
            estimatedMemoryMb = 3_500
        case .quickStart:
            estimatedMemoryMb = 5_500
        case .caseAssociate:
            estimatedMemoryMb = 8_000
        case .seniorDraftingSupport:
            estimatedMemoryMb = 14_000
        }
        return AlphaLocalModelResourceEstimate(
            inputChars: promptChars,
            estimatedTokens: estimatedTokens,
            estimatedRuntimeMs: estimatedRuntimeMs,
            estimatedMemoryMb: estimatedMemoryMb,
            estimatedDurationSeconds: max(1, estimatedRuntimeMs / 1_000),
            shouldRunNow: promptChars <= maxChars,
            reason: promptChars > maxChars ? "Prompt pack exceeded the current local budget of \(maxChars) characters." : nil,
            notes: ["Llama.cpp estimate after focused source packing."]
        )
    }
    
    func cancel(invocationID: UUID) -> Bool {
        return false // Not supported in this simplified wrapper
    }
    
    private func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }

    nonisolated static func sourceLanguageFallbackIfNeeded(
        for input: AlphaLocalModelInput,
        sourcePack: [AlphaSourceTextBlock]? = nil,
        generatedText: String
    ) -> String? {
        let effectiveSourcePack = (sourcePack?.isEmpty == false ? sourcePack : nil) ?? input.sourcePack
        guard !effectiveSourcePack.isEmpty else { return nil }
        let language = input.languageProfile?.primaryLanguage
        let hints = Set(effectiveSourcePack.compactMap { $0.languageHint?.lowercased() })
        if language == .bengali || hints.contains("bn") || hints.contains("bengali") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0980...0x09FF) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0980...0x09FF, heading: "উৎসভিত্তিক উত্তর")
        }
        if language == .hindi || hints.contains("hi") || hints.contains("hindi") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0900...0x097F) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0900...0x097F, heading: "स्रोत-आधारित उत्तर")
        }
        if language == .tamil || hints.contains("ta") || hints.contains("tamil") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0B80...0x0BFF) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0B80...0x0BFF, heading: "மூலத்தின் அடிப்படையிலான பதில்")
        }
        if language == .telugu || hints.contains("te") || hints.contains("telugu") {
            guard !containsUnicodeScalar(in: generatedText, range: 0x0C00...0x0C7F) else { return nil }
            return extractiveMatterAnswer(from: effectiveSourcePack, scriptRange: 0x0C00...0x0C7F, heading: "మూలాల ఆధారిత సమాధానం")
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

    nonisolated static func shouldEmitStreamingPartial(
        cleanedPartial: String,
        lastEmittedPartialText: String?,
        latestToken: String
    ) -> Bool {
        guard cleanedPartial.count >= 16 else { return false }
        guard let lastEmittedPartialText, !lastEmittedPartialText.isEmpty else { return true }

        let growth = cleanedPartial.count - lastEmittedPartialText.count
        guard growth > 0 else { return false }

        if latestToken.contains("\n"), growth >= 8 {
            return true
        }
        return growth >= 24
    }

    nonisolated static func isDegenerateDraftOutput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        if trimmed.localizedCaseInsensitiveContains("<|channel>") {
            return true
        }

        let scalars = trimmed.unicodeScalars.filter { scalar in
            scalar.properties.isWhitespace == false
        }
        guard scalars.count >= 12 else { return false }

        var counts: [UnicodeScalar: Int] = [:]
        for scalar in scalars {
            counts[scalar, default: 0] += 1
        }
        let mostRepeatedScalarCount = counts.values.max() ?? 0
        if mostRepeatedScalarCount >= max(10, scalars.count * 3 / 4) {
            return true
        }

        if scalars.count >= 20, counts.count <= 3 {
            return true
        }
        return false
    }

    private func shouldStopGeneration(afterAppending token: String, fullText: String) -> Bool {
        let stopSequences = [
            "<end_of_turn>",
            "<start_of_turn>",
            "<|channel>",
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

    private func stagedDraftMetadata() -> (tokens: Int?, label: String?)? {
        guard let draftPath = stagedDraftModelPath(),
              draftPath.isEmpty == false else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: draftPath, isDirectory: &isDirectory),
              isDirectory.boolValue == false else {
            return nil
        }

        let bytes = ((try? FileManager.default.attributesOfItem(atPath: draftPath))?[.size] as? NSNumber)?.int64Value ?? 0
        guard bytes > 0 else { return nil }

        let draftLabel = URL(fileURLWithPath: draftPath)
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDraftLabel = draftLabel.isEmpty ? nil : draftLabel

        return (
            tokens: effectiveDraftTokenCount(),
            label: cleanedDraftLabel
        )
    }

    private func stagedDraftLooksLikeGGUFFile(_ draftPath: String) -> Bool {
        guard draftPath.lowercased().hasSuffix(".gguf") else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: draftPath, isDirectory: &isDirectory) &&
            isDirectory.boolValue == false
    }

    private func surfacedDraftMetadata(
        for accelerationMode: AlphaLocalRuntimeAccelerationMode
    ) -> (tokens: Int?, label: String?)? {
        guard accelerationMode == .draftModelSpeculative else {
            return nil
        }
        return stagedDraftMetadata()
    }

    private func effectiveDraftTokenCount() -> Int? {
        guard let _ = stagedDraftModelPath() else {
            return nil
        }
        if let draftModelTokens {
            return max(1, min(draftModelTokens, 8))
        }
        return AlphaLlamaRuntimeProfile.defaultDraftTokens(
            for: capabilityTier,
            modelPath: modelPath
        )
    }

    private func stagedDraftModelPath() -> String? {
        guard
            let draftPath = draftModelPath?.trimmingCharacters(in: .whitespacesAndNewlines),
            draftPath.isEmpty == false
        else {
            return nil
        }
        return draftPath
    }

    private func draftModelPathType() -> String? {
        guard let draftPath = stagedDraftModelPath() else {
            return nil
        }
        let draftURL = URL(fileURLWithPath: draftPath)
        if (try? draftURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return "directory"
        }
        if FileManager.default.fileExists(atPath: draftURL.path) {
            return "file"
        }
        return "missing"
    }

    private func effectiveDraftModelPath() -> String? {
        let degenerateDraftKey = modelPath.flatMap { activeDraftHealthKey(path: $0) }
        guard
            let draftPath = stagedDraftModelPath(),
            stagedDraftMetadata() != nil,
            stagedDraftLooksLikeGGUFFile(draftPath),
            AlphaLlamaRuntimeProfile.supportsDraftAcceleration(
                forModelPath: modelPath,
                physicalMemory: Self.physicalMemoryBytesProvider(),
                draftTokens: effectiveDraftTokenCount()
            ),
            draftMemoryPolicyAllows(draftPath: draftPath),
            !Self.draftOutputPreviouslyDegenerated(degenerateDraftKey)
        else {
            return nil
        }
        return draftPath
    }

    private func draftAccelerationStatus(
        runtimeAvailable: Bool
    ) -> (status: String, draftPath: String?, metadata: (tokens: Int?, label: String?)?) {
        guard runtimeAvailable else {
            return ("runtime_unavailable", nil, nil)
        }
        guard let draftPath = stagedDraftModelPath() else {
            return ("no_draft_configured", nil, nil)
        }
        guard let metadata = stagedDraftMetadata() else {
            return ("draft_file_unavailable", draftPath, nil)
        }
        guard stagedDraftLooksLikeGGUFFile(draftPath) else {
            return ("draft_format_unsupported", draftPath, metadata)
        }
        guard AlphaLlamaRuntimeProfile.supportsDraftAcceleration(
            forModelPath: modelPath,
            physicalMemory: Self.physicalMemoryBytesProvider(),
            draftTokens: effectiveDraftTokenCount()
        ) else {
            return ("draft_token_policy_blocked", draftPath, metadata)
        }
        guard draftMemoryPolicyAllows(draftPath: draftPath) else {
            return ("draft_memory_policy_blocked", draftPath, metadata)
        }
        if Self.draftOutputPreviouslyDegenerated(
            modelPath.map { draftHealthKey(path: $0, draftPath: draftPath, draftTokens: metadata.tokens) }
        ) {
            return ("draft_output_degenerate", draftPath, metadata)
        }
        return ("candidate", draftPath, metadata)
    }

    private func validatedDraftMetadata(
        runtimeAvailable: Bool
    ) -> (metadata: (tokens: Int?, label: String?)?, status: String, detail: String?) {
        let draftStatus = draftAccelerationStatus(runtimeAvailable: runtimeAvailable)
        guard
            draftStatus.status == "candidate",
            let modelPath,
            let draftPath = draftStatus.draftPath,
            let stagedDraft = draftStatus.metadata
        else {
            let detail: String
            if draftStatus.status == "draft_token_policy_blocked" {
                detail = draftTokenPolicyBlockedDetail(tokens: draftStatus.metadata?.tokens)
            } else if draftStatus.status == "draft_memory_policy_blocked" {
                detail = draftMemoryPolicyBlockedDetail(draftPath: draftStatus.draftPath)
            } else {
                detail = draftStatus.status
            }
            return (draftStatus.metadata, draftStatus.status, detail)
        }

        do {
            let draftTokens = effectiveDraftTokenCount()
            let supportsDraftAcceleration = try Self.draftAccelerationValidator(
                modelPath,
                draftPath,
                draftTokens
            )
            return supportsDraftAcceleration
                ? (stagedDraft, "active", "configured_acceleration=draftModelSpeculative")
                : (stagedDraft, "validator_rejected", "configured_acceleration=standard")
        } catch {
            return (stagedDraft, "validator_failed", Self.safeDraftValidationErrorDetail(error))
        }
    }

    private static func safeDraftValidationErrorDetail(_ error: Error) -> String {
        let rawDescription = String(describing: error)
        if rawDescription.isEmpty == false,
           !rawDescription.contains("Error Domain=") {
            return "validator_error=\(redactedDraftValidationDetail(rawDescription))"
        }
        let nsError = error as NSError
        if nsError.domain.isEmpty == false {
            return "validator_error=\(nsError.domain):\(nsError.code)"
        }
        return "validator_error=\(String(describing: type(of: error)))"
    }

    private func draftTokenPolicyBlockedDetail(tokens: Int?) -> String {
        let requestedTokens = tokens.map(String.init) ?? "nil"
        let maximumTokens = AlphaLlamaRuntimeProfile.maximumSupportedDraftTokens(
            forModelPath: modelPath,
            physicalMemory: Self.physicalMemoryBytesProvider()
        )
        return "requested_draft_tokens=\(requestedTokens),max_supported_draft_tokens=\(maximumTokens)"
    }

    private func draftMemoryPolicyAllows(draftPath: String) -> Bool {
        AlphaLlamaRuntimeProfile.draftArtifactMemoryPolicy(
            forModelPath: modelPath,
            draftPath: draftPath,
            physicalMemory: Self.physicalMemoryBytesProvider()
        ).allowed
    }

    private func draftMemoryPolicyBlockedDetail(draftPath: String?) -> String {
        let policy = AlphaLlamaRuntimeProfile.draftArtifactMemoryPolicy(
            forModelPath: modelPath,
            draftPath: draftPath,
            physicalMemory: Self.physicalMemoryBytesProvider()
        )
        let mainBytes = policy.mainBytes.map(String.init) ?? "nil"
        let draftBytes = policy.draftBytes.map(String.init) ?? "nil"
        let maxCombinedBytes = policy.maxCombinedBytes.map(String.init) ?? "nil"
        return "main_bytes=\(mainBytes),draft_bytes=\(draftBytes),max_combined_bytes=\(maxCombinedBytes)"
    }

    private static func redactedDraftValidationDetail(_ value: String) -> String {
        let redacted = value
            .replacingOccurrences(
                of: #"/[^\s]+"#,
                with: "<path>",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return redacted.isEmpty ? "unknown" : redacted
    }

    private static func draftAccelerationErrorCategory(
        for status: String,
        runtimeAvailable: Bool
    ) -> String? {
        guard runtimeAvailable else { return nil }
        switch status {
        case "draft_file_unavailable":
            return "draft_file_unavailable"
        case "draft_token_policy_blocked":
            return "draft_token_policy_blocked"
        case "draft_memory_policy_blocked":
            return "draft_memory_policy_blocked"
        case "draft_format_unsupported":
            return "draft_format_unsupported"
        case "validator_rejected":
            return "draft_validator_rejected"
        case "validator_failed":
            return "draft_validator_failed"
        case "draft_output_degenerate":
            return "draft_output_degenerate"
        default:
            return nil
        }
    }
}
