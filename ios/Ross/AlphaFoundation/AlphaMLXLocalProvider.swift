import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(HuggingFace) && canImport(Tokenizers)
import HuggingFace
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

private final class AlphaUnsafeSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private func alphaLocalModelSmokeEnabled() -> Bool {
    ProcessInfo.processInfo.environment["ROSS_LOCAL_MODEL_SMOKE_PROFILE"] != nil
}

private func alphaLocalModelSmokeTechnicalFailure(_ stage: String, mode: String, error: any Error) {
    guard alphaLocalModelSmokeEnabled() else { return }
    let nsError = error as NSError
    let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    let message = detail.isEmpty ? "Unknown error." : detail
    print(
        "ROSS_LOCAL_MODEL_SMOKE_TECHNICAL_FAILURE stage=\(stage) mode=\(mode) domain=\(nsError.domain) code=\(nsError.code) detail=\(message)"
    )
}

private func alphaLocalModelSmokeMemoryLog(_ stage: String) {
    guard alphaLocalModelSmokeEnabled() else { return }
    #if canImport(Darwin)
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    var info = task_vm_info_data_t()
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        print("ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) status=unavailable kern=\(result)")
        return
    }
    let residentMb = Int(info.resident_size / 1_048_576)
    let footprintMb = Int(info.phys_footprint / 1_048_576)
    print("ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) resident_mb=\(residentMb) phys_footprint_mb=\(footprintMb)")
    #else
    print("ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) status=unsupported")
    #endif
}

private struct AlphaGemma4SharedKVShimConfig {
    let modelType: String
    let hiddenSize: Int
    let numHiddenLayers: Int
    let numKeyValueHeads: Int
    let numGlobalKeyValueHeads: Int?
    let headDim: Int
    let globalHeadDim: Int
    let numKvSharedLayers: Int
    let attentionKeqV: Bool
    let layerTypes: [String]
}

private struct AlphaGemma4SharedKVShimPlan {
    enum FillStyle {
        case zeros
        case ones
    }

    struct TensorSpec {
        let shape: [Int]
        let fillStyle: FillStyle
    }

    let tensors: [String: TensorSpec]
}

private func alphaGemma4SharedKVShimConfig(from directoryURL: URL) -> AlphaGemma4SharedKVShimConfig? {
    guard
        let data = try? Data(contentsOf: directoryURL.appendingPathComponent("config.json")),
        let rawValue = try? JSONSerialization.jsonObject(with: data),
        let json = rawValue as? [String: Any]
    else {
        return nil
    }

    let modelType = ((json["model_type"] as? String) ?? "").lowercased()
    guard modelType == "gemma4" else {
        return nil
    }

    let textConfig = (json["text_config"] as? [String: Any]) ?? json
    let hiddenSize = textConfig["hidden_size"] as? Int ?? 0
    let numHiddenLayers = textConfig["num_hidden_layers"] as? Int ?? 0
    let numKeyValueHeads = textConfig["num_key_value_heads"] as? Int ?? 0
    let numGlobalKeyValueHeads = textConfig["num_global_key_value_heads"] as? Int
    let headDim = textConfig["head_dim"] as? Int ?? 0
    let globalHeadDim = textConfig["global_head_dim"] as? Int ?? headDim
    let numKvSharedLayers = textConfig["num_kv_shared_layers"] as? Int ?? 0
    let attentionKeqV = textConfig["attention_k_eq_v"] as? Bool ?? false

    guard
        hiddenSize > 0,
        numHiddenLayers > 0,
        numKeyValueHeads > 0,
        headDim > 0,
        globalHeadDim > 0,
        numKvSharedLayers > 0
    else {
        return nil
    }

    let layerTypes: [String]
    if let explicitLayerTypes = textConfig["layer_types"] as? [String], !explicitLayerTypes.isEmpty {
        layerTypes = explicitLayerTypes
    } else {
        let slidingWindowPattern = textConfig["sliding_window_pattern"] as? Int ?? 5
        let pattern = (0 ..< max(slidingWindowPattern, 1)).map { index in
            index == max(slidingWindowPattern, 1) - 1 ? "full_attention" : "sliding_attention"
        }
        var derivedLayerTypes: [String] = []
        while derivedLayerTypes.count < numHiddenLayers {
            derivedLayerTypes.append(contentsOf: pattern)
        }
        layerTypes = Array(derivedLayerTypes.prefix(numHiddenLayers))
    }

    guard layerTypes.count == numHiddenLayers else {
        return nil
    }

    return AlphaGemma4SharedKVShimConfig(
        modelType: modelType,
        hiddenSize: hiddenSize,
        numHiddenLayers: numHiddenLayers,
        numKeyValueHeads: numKeyValueHeads,
        numGlobalKeyValueHeads: numGlobalKeyValueHeads,
        headDim: headDim,
        globalHeadDim: globalHeadDim,
        numKvSharedLayers: numKvSharedLayers,
        attentionKeqV: attentionKeqV,
        layerTypes: layerTypes
    )
}

private func alphaGemma4SharedKVWeightMap(from directoryURL: URL) -> [String: String]? {
    guard
        let data = try? Data(contentsOf: directoryURL.appendingPathComponent("model.safetensors.index.json")),
        let rawValue = try? JSONSerialization.jsonObject(with: data),
        let json = rawValue as? [String: Any],
        let weightMap = json["weight_map"] as? [String: String]
    else {
        return nil
    }
    return weightMap
}

private func alphaGemma4SharedKVShimPlan(for directoryURL: URL) -> AlphaGemma4SharedKVShimPlan? {
    guard
        let config = alphaGemma4SharedKVShimConfig(from: directoryURL),
        let weightMap = alphaGemma4SharedKVWeightMap(from: directoryURL)
    else {
        return nil
    }

    let firstKvSharedLayerIdx = config.numHiddenLayers - config.numKvSharedLayers
    guard firstKvSharedLayerIdx > 0, firstKvSharedLayerIdx < config.numHiddenLayers else {
        return nil
    }

    var tensors: [String: AlphaGemma4SharedKVShimPlan.TensorSpec] = [:]
    for layerIdx in firstKvSharedLayerIdx ..< config.numHiddenLayers {
        let layerType = config.layerTypes[layerIdx]
        let isSliding = layerType == "sliding_attention"
        let effectiveHeadDim = isSliding ? config.headDim : config.globalHeadDim
        let useKeqV = config.attentionKeqV && !isSliding
        let numKVHeads = useKeqV ? (config.numGlobalKeyValueHeads ?? config.numKeyValueHeads) : config.numKeyValueHeads
        let outputFeatures = max(numKVHeads * effectiveHeadDim, 1)
        let prefix = "language_model.model.layers.\(layerIdx).self_attn"

        if weightMap["\(prefix).k_proj.weight"] == nil {
            tensors["\(prefix).k_proj.weight"] = .init(
                shape: [outputFeatures, config.hiddenSize],
                fillStyle: .zeros
            )
        }

        if !useKeqV && weightMap["\(prefix).v_proj.weight"] == nil {
            tensors["\(prefix).v_proj.weight"] = .init(
                shape: [outputFeatures, config.hiddenSize],
                fillStyle: .zeros
            )
        }

        if weightMap["\(prefix).k_norm.weight"] == nil {
            tensors["\(prefix).k_norm.weight"] = .init(
                shape: [effectiveHeadDim],
                fillStyle: .ones
            )
        }
    }

    guard !tensors.isEmpty else {
        return nil
    }

    return AlphaGemma4SharedKVShimPlan(tensors: tensors)
}

private func alphaMirrorMLXRuntimeDirectory(
    from sourceDirectory: URL,
    to destinationDirectory: URL,
    fileManager: FileManager = .default
) throws {
    guard let enumerator = fileManager.enumerator(
        at: sourceDirectory,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [],
        errorHandler: nil
    ) else {
        return
    }

    for case let itemURL as URL in enumerator {
        let relativePath = itemURL.path.replacingOccurrences(
            of: sourceDirectory.path + "/",
            with: ""
        )
        let destinationURL = destinationDirectory.appendingPathComponent(relativePath)
        let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])

        if values.isDirectory == true {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            continue
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if values.isSymbolicLink == true {
            let symbolicDestination = try fileManager.destinationOfSymbolicLink(atPath: itemURL.path)
            try fileManager.createSymbolicLink(
                atPath: destinationURL.path,
                withDestinationPath: symbolicDestination
            )
        } else {
            try fileManager.createSymbolicLink(at: destinationURL, withDestinationURL: itemURL)
        }
    }
}

private func alphaPreparedMLXRuntimeDirectory(
    for sourceDirectory: URL,
    fileManager: FileManager = .default
) throws -> URL {
    let overlayMarkerURL = sourceDirectory.appendingPathComponent("ross-mlx-runtime-overlay.json")
    guard !fileManager.fileExists(atPath: overlayMarkerURL.path) else {
        return sourceDirectory
    }

    guard let shimPlan = alphaGemma4SharedKVShimPlan(for: sourceDirectory) else {
        return sourceDirectory
    }

    let overlaysRoot = alphaSupportRootURL()
        .appendingPathComponent("MLXRuntimeOverlays", isDirectory: true)
    try fileManager.createDirectory(at: overlaysRoot, withIntermediateDirectories: true)

    let overlayDirectory = overlaysRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: overlayDirectory, withIntermediateDirectories: true)
    do {
        try alphaMirrorMLXRuntimeDirectory(from: sourceDirectory, to: overlayDirectory, fileManager: fileManager)
        var arrays: [String: MLXArray] = [:]
        for (key, tensor) in shimPlan.tensors {
            switch tensor.fillStyle {
            case .zeros:
                arrays[key] = MLXArray.zeros(tensor.shape, dtype: .float16)
            case .ones:
                arrays[key] = MLXArray.ones(tensor.shape, dtype: .float16)
            }
        }
        let shimURL = overlayDirectory.appendingPathComponent("ross-shared-kv-shim.safetensors")
        try MLX.save(arrays: arrays, url: shimURL)
        let markerData = try JSONSerialization.data(
            withJSONObject: [
                "source_path": sourceDirectory.path,
                "shim_keys": Array(shimPlan.tensors.keys).sorted()
            ],
            options: [.sortedKeys]
        )
        try markerData.write(to: overlayDirectory.appendingPathComponent("ross-mlx-runtime-overlay.json"))
        return overlayDirectory
    } catch {
        try? fileManager.removeItem(at: overlayDirectory)
        throw error
    }
}

enum AlphaMLXRuntimeProfile {
    private enum IPhonePerformanceClass {
        case baseline
        case recent
        case recentPro
        case latest
    }

    static func contextWindowTokens(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
    ) -> Int {
        let baseContextWindowTokens: Int = switch tier {
        case .flash:
            physicalMemory >= 8_000_000_000 ? 8_192 : 6_144
        case .quickStart:
            physicalMemory >= 8_000_000_000 ? 16_384 : 12_288
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                40_960
            } else {
                physicalMemory >= 12_000_000_000 ? 24_576 : 20_480
            }
        case .seniorDraftingSupport:
            physicalMemory >= 18_000_000_000 ? 28_672 : 24_576
        }

        guard let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        ) else {
            return baseContextWindowTokens
        }

        switch tier {
        case .quickStart:
            guard physicalMemory >= 8_000_000_000 else { return baseContextWindowTokens }
            switch performanceClass {
            case .latest:
                return baseContextWindowTokens + 3_072
            case .recentPro:
                return baseContextWindowTokens + 2_048
            case .recent:
                return baseContextWindowTokens + 1_024
            case .baseline:
                return baseContextWindowTokens
            }
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                switch performanceClass {
                case .latest:
                    return baseContextWindowTokens + 8_192
                case .recentPro:
                    return baseContextWindowTokens + 4_096
                case .recent:
                    return baseContextWindowTokens + 2_048
                case .baseline:
                    return baseContextWindowTokens
                }
            }
            if physicalMemory >= 12_000_000_000 {
                switch performanceClass {
                case .latest:
                    return baseContextWindowTokens + 6_144
                case .recentPro:
                    return baseContextWindowTokens + 4_096
                case .recent:
                    return baseContextWindowTokens + 2_048
                case .baseline:
                    return baseContextWindowTokens
                }
            }
            return baseContextWindowTokens
        case .flash, .seniorDraftingSupport:
            return baseContextWindowTokens
        }
    }

    static func maxInputChars(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
    ) -> Int {
        let baseMaxInputChars: Int
        switch tier {
        case .flash:
            baseMaxInputChars = physicalMemory >= 8_000_000_000 ? 18_000 : 14_000
        case .quickStart:
            baseMaxInputChars = physicalMemory >= 8_000_000_000 ? 40_000 : 24_000
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                baseMaxInputChars = 72_000
            } else {
                baseMaxInputChars = physicalMemory >= 12_000_000_000 ? 56_000 : 40_000
            }
        case .seniorDraftingSupport:
            baseMaxInputChars = physicalMemory >= 18_000_000_000 ? 72_000 : 56_000
        }

        let multiplier = iPhoneInputBudgetMultiplier(
            physicalMemory: physicalMemory,
            deviceModelIdentifier: deviceModelIdentifier
        )
        guard multiplier > 1 else {
            return baseMaxInputChars
        }
        return Int((Double(baseMaxInputChars) * multiplier).rounded())
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
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
    ) -> Int {
        let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        )
        switch tier {
        case .flash:
            return 2
        case .quickStart:
            if physicalMemory >= 12_000_000_000,
               let performanceClass,
               performanceClass == .recentPro || performanceClass == .latest {
                return 7
            }
            return physicalMemory >= 12_000_000_000 ? 6 : 4
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                if let performanceClass,
                   performanceClass == .recentPro || performanceClass == .latest {
                    return 10
                }
                return 9
            }
            if physicalMemory >= 12_000_000_000 {
                if let performanceClass,
                   performanceClass == .recent || performanceClass == .recentPro || performanceClass == .latest {
                    return 7
                }
                return 6
            }
            return 4
        case .seniorDraftingSupport:
            return physicalMemory >= 12_000_000_000 ? 8 : 6
        }
    }

    static func prefillStepSize(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
    ) -> Int {
        let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        )
        switch tier {
        case .flash:
            return physicalMemory >= 8_000_000_000 ? 320 : 256
        case .quickStart:
            if physicalMemory >= 8_000_000_000,
               let performanceClass,
               performanceClass == .recentPro || performanceClass == .latest {
                return 512
            }
            return physicalMemory >= 8_000_000_000 ? 448 : 256
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                if let performanceClass,
                   performanceClass == .recentPro || performanceClass == .latest {
                    return 768
                }
                return 640
            }
            if physicalMemory >= 12_000_000_000 {
                if let performanceClass,
                   performanceClass == .recentPro || performanceClass == .latest {
                    return 448
                }
                return 384
            }
            return 320
        case .seniorDraftingSupport:
            return physicalMemory >= 18_000_000_000 ? 512 : 384
        }
    }

    static func estimatedAssistantTokensPerSecond(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier(),
        hasDraftCompanion: Bool
    ) -> Double {
        let baseSpeed: Double
        switch tier {
        case .flash:
            baseSpeed = physicalMemory >= 8_000_000_000 ? 12.0 : 10.0
        case .quickStart:
            if physicalMemory >= 16_000_000_000 {
                baseSpeed = 15.0
            } else if physicalMemory >= 12_000_000_000 {
                baseSpeed = 14.0
            } else if physicalMemory >= 8_000_000_000 {
                baseSpeed = 13.0
            } else {
                baseSpeed = 11.5
            }
        case .caseAssociate:
            if physicalMemory >= 16_000_000_000 {
                baseSpeed = 14.3
            } else if physicalMemory >= 12_000_000_000 {
                baseSpeed = 12.0
            } else {
                baseSpeed = 10.0
            }
        case .seniorDraftingSupport:
            if physicalMemory >= 18_000_000_000 {
                baseSpeed = 12.0
            } else if physicalMemory >= 16_000_000_000 {
                baseSpeed = 11.3
            } else if physicalMemory >= 12_000_000_000 {
                baseSpeed = 10.3
            } else {
                baseSpeed = 8.5
            }
        }

        let deviceAdjustedBaseSpeed = baseSpeed + iPhoneBaseSpeedBonus(
            for: tier,
            physicalMemory: physicalMemory,
            deviceModelIdentifier: deviceModelIdentifier
        )

        guard hasDraftCompanion else { return deviceAdjustedBaseSpeed }

        let draftTokens = defaultDraftTokens(
            for: tier,
            physicalMemory: physicalMemory,
            deviceModelIdentifier: deviceModelIdentifier
        )
        let draftBonus: Double
        switch draftTokens {
        case 9...:
            draftBonus = 1.5
        case 8:
            draftBonus = 1.0
        case 6...7:
            draftBonus = 0.8
        case 4...5:
            draftBonus = 0.5
        default:
            draftBonus = 0.25
        }

        let prefillBonus: Double
        switch prefillStepSize(
            for: tier,
            physicalMemory: physicalMemory,
            deviceModelIdentifier: deviceModelIdentifier
        ) {
        case 640...:
            prefillBonus = 0.5
        case 448...:
            prefillBonus = 0.25
        default:
            prefillBonus = 0
        }

        return deviceAdjustedBaseSpeed + draftBonus + prefillBonus
    }

    static func maximumSupportedDraftTokens(for tier: AlphaCapabilityTier) -> Int {
        switch tier {
        case .caseAssociate, .seniorDraftingSupport:
            return 10
        case .flash, .quickStart:
            return 8
        }
    }

    static func maximumAutomaticDraftTokens(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
    ) -> Int {
        let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        )
        switch tier {
        case .caseAssociate:
            if physicalMemory >= 12_000_000_000,
               let performanceClass,
               performanceClass == .recentPro || performanceClass == .latest {
                return physicalMemory >= 16_000_000_000 ? 10 : 9
            }
            return physicalMemory >= 16_000_000_000 ? 10 : 8
        case .seniorDraftingSupport:
            if physicalMemory >= 12_000_000_000,
               let performanceClass,
               performanceClass == .recentPro || performanceClass == .latest {
                return physicalMemory >= 16_000_000_000 ? 10 : 9
            }
            return physicalMemory >= 16_000_000_000 ? 10 : 8
        case .flash, .quickStart:
            return 8
        }
    }

    private static func iPhoneBaseSpeedBonus(
        for tier: AlphaCapabilityTier,
        physicalMemory: UInt64,
        deviceModelIdentifier: String
    ) -> Double {
        guard let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        ) else {
            return 0
        }

        switch performanceClass {
        case .baseline:
            switch tier {
            case .flash:
                return 0.2
            case .quickStart:
                return 0.3
            case .caseAssociate:
                return 0.35
            case .seniorDraftingSupport:
                return 0.25
            }
        case .recent:
            switch tier {
            case .flash:
                return 0.3
            case .quickStart:
                return 0.5
            case .caseAssociate:
                return 0.6
            case .seniorDraftingSupport:
                return 0.45
            }
        case .recentPro:
            switch tier {
            case .flash:
                return 0.45
            case .quickStart:
                return 0.8
            case .caseAssociate:
                return 0.9
            case .seniorDraftingSupport:
                return 0.75
            }
        case .latest:
            switch tier {
            case .flash:
                return 0.6
            case .quickStart:
                return 1.0
            case .caseAssociate:
                return 1.2
            case .seniorDraftingSupport:
                return 0.95
            }
        }
    }

    private static func iPhoneInputBudgetMultiplier(
        physicalMemory: UInt64,
        deviceModelIdentifier: String
    ) -> Double {
        guard let performanceClass = iPhonePerformanceClass(
            for: deviceModelIdentifier,
            physicalMemory: physicalMemory
        ) else {
            return 1
        }

        switch performanceClass {
        case .baseline:
            return 1.02
        case .recent:
            return 1.10
        case .recentPro:
            return 1.16
        case .latest:
            return 1.20
        }
    }

    private static func iPhonePerformanceClass(
        for deviceModelIdentifier: String,
        physicalMemory: UInt64
    ) -> IPhonePerformanceClass? {
        let normalizedIdentifier = deviceModelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedIdentifier.lowercased().hasPrefix("iphone") else {
            return nil
        }

        let majorMinor = normalizedIdentifier.dropFirst("iPhone".count).split(separator: ",", maxSplits: 1)
        guard let majorComponent = majorMinor.first,
              let major = Int(majorComponent) else {
            return physicalMemory >= 12_000_000_000 ? .recent : .baseline
        }
        let minor = majorMinor.count == 2 ? Int(majorMinor[1]) ?? 0 : 0

        switch (major, minor) {
        case (18..., _):
            return .latest
        case (17..., 1...2):
            return .recentPro
        case (17..., _):
            return .recent
        case (16..., 1...2):
            return physicalMemory >= 12_000_000_000 ? .recentPro : .recent
        case (16..., _):
            return .recent
        default:
            return physicalMemory >= 12_000_000_000 ? .recent : .baseline
        }
    }
}

private actor AlphaMLXModelContainerCache {
    static let shared = AlphaMLXModelContainerCache()

    private var cachedContainers: [String: ModelContainer] = [:]
    private var preparedDirectories: [String: URL] = [:]

    func container(for directory: URL) async throws -> ModelContainer {
        let preparedDirectory: URL
        if let cachedPreparedDirectory = preparedDirectories[directory.path] {
            preparedDirectory = cachedPreparedDirectory
        } else {
            preparedDirectory = try alphaPreparedMLXRuntimeDirectory(for: directory)
            preparedDirectories[directory.path] = preparedDirectory
        }

        if let cachedContainer = cachedContainers[preparedDirectory.path] {
            return cachedContainer
        }

        let container = try await loadModelContainer(
            from: preparedDirectory,
            using: AlphaMLXTokenizerLoader()
        )
        cachedContainers[preparedDirectory.path] = container
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
            alphaLocalModelSmokeMemoryLog("mlx_before_container")
            let container = try await AlphaMLXModelContainerCache.shared.container(for: directory)
            alphaLocalModelSmokeMemoryLog("mlx_after_container")
            let effectivePrompt: String
            if let instructions, !instructions.isEmpty {
                effectivePrompt = "\(instructions)\n\n\(prompt)"
            } else {
                effectivePrompt = prompt
            }
            let inputBox = AlphaUnsafeSendableBox(try await container.prepare(input: UserInput(prompt: effectivePrompt)))
            alphaLocalModelSmokeMemoryLog("mlx_after_prepare")
            let promptTokenCount = inputBox.value.text.tokens.size
            if let draftDirectory {
                alphaLocalModelSmokeMemoryLog("mlx_before_draft_container")
                let draftContainer = try await AlphaMLXModelContainerCache.shared.container(for: draftDirectory)
                alphaLocalModelSmokeMemoryLog("mlx_after_draft_container")
                let draftModelBox = await draftContainer.perform { draftContext in
                    AlphaUnsafeSendableBox(draftContext.model)
                }
                return try await container.perform { context in
                    alphaLocalModelSmokeMemoryLog("mlx_before_generate_draft")
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
                    alphaLocalModelSmokeMemoryLog("mlx_after_generate_draft")
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
                    alphaLocalModelSmokeMemoryLog("mlx_before_generate_standard")
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
                    alphaLocalModelSmokeMemoryLog("mlx_after_generate_standard")
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

    nonisolated(unsafe) static var physicalMemoryBytesProvider: () -> UInt64 = {
        ProcessInfo.processInfo.physicalMemory
    }

    nonisolated(unsafe) static var phoneFormFactorProvider: () -> Bool = {
        alphaAssistantUsesPhoneFormFactor()
    }

    func isAvailable() -> Bool {
        runtimeAvailability().available
    }

    func supportedTasks() -> Set<AlphaLocalModelTask> {
        Set(AlphaLocalModelTask.allCases)
    }

    static func preparedRuntimeDirectoryURL(
        for directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try alphaPreparedMLXRuntimeDirectory(for: directory, fileManager: fileManager)
    }

    static func gemma4SharedKVShimTensorShapes(for directory: URL) -> [String: [Int]] {
        let plan = alphaGemma4SharedKVShimPlan(for: directory)
        return plan?.tensors.mapValues(\.shape) ?? [:]
    }

    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        let availability = runtimeAvailability()
        let draftStatus = draftAccelerationStatus(
            runtimeAvailable: availability.available,
            unavailableReason: availability.errorCategory
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
            accelerationMode: draftStatus.mode,
            accelerationDraftTokens: draftStatus.tokens,
            draftModelPathLabel: draftStatus.label,
            draftAccelerationStatus: draftStatus.status,
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
            promptChars = conciseMatterQuestionPack(for: input).inputChars
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
                sourceRefs: pack.includedSourceRefs,
                packedSourceCount: pack.includedSourceRefs.count,
                omittedSourceCount: pack.omittedSourceRefs.count,
                omittedSourceLabels: pack.omittedSourceRefs.map(\.label),
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
        let matterPromptPack = usesPlainMatterAnswerPrompt ? conciseMatterQuestionPack(for: taskInput) : nil
        let activePromptPack = usesPlainMatterAnswerPrompt ? matterPromptPack : pack
        let instructions = usesPlainMatterAnswerPrompt ? nil : pack.systemInstructions
        let prompt = usesPlainMatterAnswerPrompt ? (matterPromptPack?.promptText ?? "") : pack.promptText
        let parameters = generateParameters(for: taskInput)

        func generationOutput(
            from generation: AlphaMLXGenerationSnapshot,
            executionPathLabel: String,
            accelerationMode: AlphaLocalRuntimeAccelerationMode,
            draftTokens: Int?,
            draftModelLabel: String?
        ) -> AlphaLocalModelOutput {
            let cleanedResponse = cleanedModelText(generation.text)
            let languagePreservingFallback = usesPlainMatterAnswerPrompt
                ? Self.sourceLanguageFallbackIfNeeded(for: taskInput, generatedText: cleanedResponse)
                : nil
            let finalResponse = languagePreservingFallback ?? cleanedResponse
            let jsonString = languagePreservingFallback == nil ? extractJSON(from: cleanedResponse) : nil
            let schemaValid = usesPlainMatterAnswerPrompt
                ? !finalResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                : jsonString != nil
            var warnings = activePromptPack?.truncated == true ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : []
            if languagePreservingFallback != nil {
                warnings.append(AlphaLocalModelWarningCopy.sourceLanguageFallback)
            }

            return AlphaLocalModelOutput(
                rawText: finalResponse,
                parsedJson: jsonString,
                schemaValid: schemaValid,
                warnings: warnings,
                sourceRefs: usesPlainMatterAnswerPrompt
                    ? (matterPromptPack?.includedSourceRefs.isEmpty == false
                        ? (matterPromptPack?.includedSourceRefs ?? [])
                        : Array(taskInput.sourcePack.prefix(5).map(\.sourceRef)))
                    : pack.includedSourceRefs,
                packedSourceCount: usesPlainMatterAnswerPrompt ? matterPromptPack?.includedSourceRefs.count : pack.includedSourceRefs.count,
                omittedSourceCount: usesPlainMatterAnswerPrompt ? matterPromptPack?.omittedSourceRefs.count : pack.omittedSourceRefs.count,
                omittedSourceLabels: usesPlainMatterAnswerPrompt
                    ? matterPromptPack?.omittedSourceRefs.map(\.label)
                    : pack.omittedSourceRefs.map(\.label),
                executionPathLabel: executionPathLabel,
                accelerationMode: accelerationMode,
                accelerationDraftTokens: draftTokens,
                accelerationDraftModelLabel: draftModelLabel,
                inputChars: activePromptPack?.inputChars,
                inputTokenCount: generation.promptTokenCount,
                outputTokenCount: generation.generationTokenCount,
                outputTokensPerSecond: generation.outputTokensPerSecond,
                timeToFirstTokenMs: generation.timeToFirstTokenMs
            )
        }

        do {
            let partialOutput: @Sendable (String, String, AlphaLocalRuntimeAccelerationMode, Int?, String?) -> Void = {
                partialText, executionPathLabel, accelerationMode, draftTokens, draftModelLabel in
                guard let onPartial else { return }
                let cleanedPartial = self.cleanedModelText(partialText)
                guard !cleanedPartial.isEmpty else { return }
                onPartial(
                    AlphaLocalModelOutput(
                        rawText: cleanedPartial,
                        parsedJson: nil,
                        schemaValid: false,
                        warnings: activePromptPack?.truncated == true ? [AlphaLocalModelWarningCopy.inputFocusedOnRelevantParts] : [],
                        sourceRefs: usesPlainMatterAnswerPrompt
                            ? (matterPromptPack?.includedSourceRefs.isEmpty == false
                                ? (matterPromptPack?.includedSourceRefs ?? [])
                                : Array(taskInput.sourcePack.prefix(5).map(\.sourceRef)))
                            : pack.includedSourceRefs,
                        packedSourceCount: usesPlainMatterAnswerPrompt ? matterPromptPack?.includedSourceRefs.count : pack.includedSourceRefs.count,
                        omittedSourceCount: usesPlainMatterAnswerPrompt ? matterPromptPack?.omittedSourceRefs.count : pack.omittedSourceRefs.count,
                        omittedSourceLabels: usesPlainMatterAnswerPrompt
                            ? matterPromptPack?.omittedSourceRefs.map(\.label)
                            : pack.omittedSourceRefs.map(\.label),
                        executionPathLabel: executionPathLabel,
                        accelerationMode: accelerationMode,
                        accelerationDraftTokens: draftTokens,
                        accelerationDraftModelLabel: draftModelLabel,
                        inputChars: activePromptPack?.inputChars
                    )
                )
            }

            do {
                let generation = try await Self.streamGenerator(
                    directoryURL,
                    draftDirectoryURL,
                    draftTokens,
                    prompt,
                    instructions,
                    parameters
                ) { partialText in
                    partialOutput(
                        partialText,
                        executionPathLabel,
                        accelerationMode,
                        draftTokens,
                        draftModelLabel
                    )
                }
                return generationOutput(
                    from: generation,
                    executionPathLabel: executionPathLabel,
                    accelerationMode: accelerationMode,
                    draftTokens: draftTokens,
                    draftModelLabel: draftModelLabel
                )
            } catch {
                alphaLocalModelSmokeTechnicalFailure(
                    "mlx_generation",
                    mode: draftDirectoryURL == nil ? "standard" : "draft",
                    error: error
                )
                guard draftDirectoryURL != nil else { throw error }
                let fallbackGeneration = try await Self.streamGenerator(
                    directoryURL,
                    nil,
                    nil,
                    prompt,
                    instructions,
                    parameters
                ) { partialText in
                    partialOutput(
                        partialText,
                        "MLX standard generation",
                        .standard,
                        nil,
                        nil
                    )
                }
                if alphaLocalModelSmokeEnabled() {
                    print("ROSS_LOCAL_MODEL_SMOKE_TRACE mlx_generation_recovered_without_draft")
                }
                return generationOutput(
                    from: fallbackGeneration,
                    executionPathLabel: "MLX standard generation",
                    accelerationMode: .standard,
                    draftTokens: nil,
                    draftModelLabel: nil
                )
            }
        } catch {
            return AlphaLocalModelOutput(
                rawText: "",
                parsedJson: nil,
                schemaValid: false,
                warnings: [AlphaLocalModelWarningCopy.assistantCouldNotFinish],
                sourceRefs: activePromptPack?.includedSourceRefs ?? [],
                packedSourceCount: activePromptPack?.includedSourceRefs.count,
                omittedSourceCount: activePromptPack?.omittedSourceRefs.count,
                omittedSourceLabels: activePromptPack?.omittedSourceRefs.map(\.label),
                errorCategory: "inference_failed"
            )
        }
    }

    private func runtimeAvailability() -> (available: Bool, errorCategory: String?, status: String) {
        guard let modelPath, !modelPath.isEmpty else {
            return (false, "missing_mlx_artifact", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        let physicalMemoryBytes = Self.physicalMemoryBytesProvider()
        guard alphaAssistantMLXRuntimeSupportedOnCurrentDevice(
            tier: capabilityTier,
            isPhoneFormFactor: Self.phoneFormFactorProvider(),
            physicalMemoryBytes: physicalMemoryBytes
        ) else {
            return (false, "insufficient_device_memory", alphaRuntimeHealthStatus(.llamaNeedsMoreMemory))
        }
        let directoryURL = URL(fileURLWithPath: modelPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (false, "missing_mlx_artifact", alphaRuntimeHealthStatus(.llamaMissingSetup))
        }
        guard Self.localModelDirectoryLooksUsable(directoryURL) else {
            return (false, "invalid_mlx_artifact", alphaRuntimeHealthStatus(.llamaNeedsRepair))
        }

        switch Self.archiveCompatibility(for: directoryURL) {
        case .supported:
            break
        case .unsupportedGemma4Assistant, .unsupportedGemma4MoE, .unsupportedGemma4Dense31B:
            return (false, "unsupported_model_archive", alphaRuntimeHealthStatus(.mlxArchiveUnsupported))
        }

        if let configuredDraftDirectoryURL = configuredDraftDirectoryURL() {
            guard Self.localModelDirectoryLooksUsable(configuredDraftDirectoryURL) else {
                return (false, "invalid_mlx_draft_artifact", alphaRuntimeHealthStatus(.llamaNeedsRepair))
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
        guard Self.archiveCanServeAsDraft(Self.archiveCompatibility(for: draftDirectoryURL)) else {
            return nil
        }
        return draftDirectoryURL
    }

    private func draftTokensForGeneration() -> Int? {
        guard resolvedDraftDirectoryURL() != nil else {
            return nil
        }
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let maximumDraftTokens: Int
        if draftModelTokens != nil {
            maximumDraftTokens = AlphaMLXRuntimeProfile.maximumSupportedDraftTokens(for: capabilityTier)
        } else {
            maximumDraftTokens = AlphaMLXRuntimeProfile.maximumAutomaticDraftTokens(
                for: capabilityTier,
                physicalMemory: physicalMemory
            )
        }
        return max(
            1,
            min(
                draftModelTokens ?? AlphaMLXRuntimeProfile.defaultDraftTokens(
                    for: capabilityTier,
                    physicalMemory: physicalMemory
                ),
                maximumDraftTokens
            )
        )
    }

    private func draftAccelerationMode(draftDirectoryURL: URL? = nil) -> AlphaLocalRuntimeAccelerationMode {
        (draftDirectoryURL ?? resolvedDraftDirectoryURL()) == nil ? .standard : .draftModelSpeculative
    }

    private func draftAccelerationStatus(
        runtimeAvailable: Bool,
        unavailableReason: String?
    ) -> (
        mode: AlphaLocalRuntimeAccelerationMode,
        tokens: Int?,
        label: String?,
        status: String
    ) {
        guard runtimeAvailable else {
            return (.standard, nil, nil, unavailableReason ?? "runtime_unavailable")
        }
        guard let draftDirectoryURL = configuredDraftDirectoryURL() else {
            return (.standard, nil, nil, "no_draft_configured")
        }
        guard FileManager.default.fileExists(atPath: draftDirectoryURL.path) else {
            return (.standard, nil, nil, "draft_file_unavailable")
        }
        guard Self.localModelDirectoryLooksUsable(draftDirectoryURL) else {
            return (.standard, nil, nil, "invalid_mlx_draft_artifact")
        }
        guard Self.archiveCanServeAsDraft(Self.archiveCompatibility(for: draftDirectoryURL)) else {
            return (.standard, nil, nil, "unsupported_mlx_draft_artifact")
        }
        return (
            .draftModelSpeculative,
            draftTokensForGeneration(),
            draftDirectoryURL.lastPathComponent,
            "active"
        )
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

    private func conciseMatterQuestionPack(for input: AlphaLocalModelInput) -> AlphaLocalPromptPack {
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
        var truncated = false
        var includedRefs: [AlphaSourceRef] = []
        var includedBlocks: [AlphaSourceTextBlock] = []
        var omittedRefs: [AlphaSourceRef] = []

        for block in sourceBlocks {
            guard remainingBudget > 120 else {
                truncated = true
                omittedRefs.append(block.sourceRef)
                continue
            }
            let label = block.sourceRef.label
            let excerpt = AlphaPromptFocusPlanner.focusedExcerpt(
                from: block.text,
                instruction: input.instruction,
                maxChars: min(remainingBudget, excerptCap)
            )
            prompt += "\n[\(label)] \(excerpt)\n"
            includedRefs.append(block.sourceRef)
            includedBlocks.append(block)
            if excerpt.count < block.text.count {
                truncated = true
            }
            remainingBudget -= excerpt.count + label.count + 8
        }

        if sourceBlocks.count < input.sourcePack.count {
            truncated = true
            let includedRefKeys = Set(sourceBlocks.map {
                [$0.sourceRef.documentId.uuidString, String($0.sourceRef.pageNumber), $0.sourceRef.label].joined(separator: "|")
            })
            omittedRefs.append(
                contentsOf: input.sourcePack
                    .map(\.sourceRef)
                    .filter { sourceRef in
                        let key = [sourceRef.documentId.uuidString, String(sourceRef.pageNumber), sourceRef.label].joined(separator: "|")
                        return !includedRefKeys.contains(key)
                    }
            )
        }

        prompt += "\nANSWER:"
        return AlphaLocalPromptPack(
            systemInstructions: "Ross local ask prompt",
            promptText: prompt,
            includedSourceRefs: includedRefs,
            includedSourceBlocks: includedBlocks,
            omittedSourceRefs: omittedRefs,
            inputChars: prompt.count,
            estimatedTokens: max(prompt.count / 4, 1),
            truncated: truncated
        )
    }

    private func conciseMatterQuestionPrompt(for input: AlphaLocalModelInput) -> String {
        conciseMatterQuestionPack(for: input).promptText
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

    private static func archiveCanServeAsDraft(_ compatibility: AlphaMLXArchiveCompatibility) -> Bool {
        switch compatibility {
        case .supported, .unsupportedGemma4Assistant:
            return true
        case .unsupportedGemma4MoE, .unsupportedGemma4Dense31B:
            return false
        }
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

    nonisolated(unsafe) static var physicalMemoryBytesProvider: () -> UInt64 = {
        ProcessInfo.processInfo.physicalMemory
    }

    nonisolated(unsafe) static var phoneFormFactorProvider: () -> Bool = {
        alphaAssistantUsesPhoneFormFactor()
    }

    func isAvailable() -> Bool { false }

    func supportedTasks() -> Set<AlphaLocalModelTask> { Set(AlphaLocalModelTask.allCases) }

    func runtimeHealth() -> AlphaLocalRuntimeHealth {
        AlphaLocalRuntimeHealth(
            runtimeMode: runtimeMode,
            available: false,
            modelPathPresent: modelPath != nil,
            modelPathLabel: modelPathLabel,
            checksumVerified: checksumVerified,
            supportedTasks: Array(supportedTasks()),
            maxInputChars: maxInputChars(),
            estimatedContextTokens: contextWindowEstimate(),
            accelerationMode: .standard,
            accelerationDraftTokens: nil,
            draftModelPathLabel: nil,
            draftAccelerationStatus: "runtime_dependency_unavailable",
            lastErrorCategory: "runtime_dependency_unavailable",
            userFacingStatus: alphaRuntimeHealthStatus(.privateAssistantUnavailable),
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
