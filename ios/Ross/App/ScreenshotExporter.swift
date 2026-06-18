import Foundation
import SwiftUI
#if canImport(Darwin)
import Darwin
#endif

#if canImport(AppKit)
import AppKit
#endif

enum RossLaunchMode {
    case interactive
    case screenshotExport
    case localModelSmoke
    case assistantDownloadSmoke

    static var current: RossLaunchMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--generate-screenshots") {
            return .screenshotExport
        }
        if arguments.contains("--local-model-smoke") {
            return .localModelSmoke
        }
        if arguments.contains("--assistant-download-smoke") {
            return .assistantDownloadSmoke
        }
        return .interactive
    }
}

enum RossLocalModelSmokeStatusCopy {
    static let runningStatus = "Checking private assistant with sample files..."
    static let missingAssistantStatus = "No private assistant is set up."
    static let unavailableAssistantStatus = "Private assistant sample-file check is unavailable."
    static let passedStatus = "Private assistant sample-file check passed."
    static let failedStatus = "Private assistant sample-file check failed."
}

enum RossAssistantDownloadSmokeStatusCopy {
    static let runningStatus = "Checking assistant download flow..."
    static let failedStatus = "Assistant download flow failed."
    static let passedStatus = "Assistant download flow passed."
}

private func rossLocalModelSmokeMemoryUsageLine(stage: String) -> String {
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
        return "ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) status=unavailable kern=\(result)"
    }
    let residentMb = Int(info.resident_size / 1_048_576)
    let footprintMb = Int(info.phys_footprint / 1_048_576)
    return "ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) resident_mb=\(residentMb) phys_footprint_mb=\(footprintMb)"
    #else
    return "ROSS_LOCAL_MODEL_SMOKE_MEMORY stage=\(stage) status=unsupported"
    #endif
}

struct RossAssistantDownloadSmokeConfig: Equatable {
    let tier: AlphaCapabilityTier
    let runtimeMode: AlphaPackRuntimeMode?
    let mobileAllowed: Bool
    let forceRefreshInstalledPack: Bool
    let waitSeconds: TimeInterval

    static func fromEnvironment(_ environment: [String: String]) -> RossAssistantDownloadSmokeConfig? {
        func trimmed(_ key: String) -> String? {
            let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        }

        func parseTier(_ raw: String?) -> AlphaCapabilityTier? {
            guard let raw else { return nil }
            switch raw {
            case AlphaCapabilityTier.flash.rawValue, "flash":
                return .flash
            case AlphaCapabilityTier.quickStart.rawValue, "quickStart":
                return .quickStart
            case AlphaCapabilityTier.caseAssociate.rawValue, "caseAssociate":
                return .caseAssociate
            case AlphaCapabilityTier.seniorDraftingSupport.rawValue, "seniorDraftingSupport":
                return .seniorDraftingSupport
            default:
                return nil
            }
        }

        func parseRuntime(_ raw: String?) -> AlphaPackRuntimeMode? {
            AlphaPackRuntimeMode(runtimeAlias: raw)
        }

        func parseBool(_ raw: String?, default fallback: Bool) -> Bool {
            guard let raw else { return fallback }
            switch raw.lowercased() {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off":
                return false
            default:
                return fallback
            }
        }

        func parsePositiveSeconds(_ raw: String?, default fallback: TimeInterval) -> TimeInterval {
            guard let raw, let seconds = TimeInterval(raw), seconds > 0 else { return fallback }
            return seconds
        }

        guard let tier = parseTier(trimmed("ROSS_ASSISTANT_DOWNLOAD_SMOKE_TIER")) else {
            return nil
        }
        return RossAssistantDownloadSmokeConfig(
            tier: tier,
            runtimeMode: parseRuntime(trimmed("ROSS_ASSISTANT_DOWNLOAD_SMOKE_RUNTIME")),
            mobileAllowed: parseBool(trimmed("ROSS_ASSISTANT_DOWNLOAD_SMOKE_MOBILE_ALLOWED"), default: false),
            forceRefreshInstalledPack: parseBool(trimmed("ROSS_ASSISTANT_DOWNLOAD_SMOKE_FORCE_REFRESH"), default: false),
            waitSeconds: parsePositiveSeconds(trimmed("ROSS_ASSISTANT_DOWNLOAD_SMOKE_WAIT_SECONDS"), default: 900)
        )
    }
}

func rossAssistantDownloadSmokeJob(
    from jobs: [AlphaModelDownloadJob],
    config: RossAssistantDownloadSmokeConfig
) -> AlphaModelDownloadJob? {
    func mostRecentMatch(in candidates: [AlphaModelDownloadJob]) -> AlphaModelDownloadJob? {
        candidates.max { lhs, rhs in
            let lhsDate = lhs.completedAt ?? lhs.updatedAt
            let rhsDate = rhs.completedAt ?? rhs.updatedAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if lhs.bytesDownloaded != rhs.bytesDownloaded {
                return lhs.bytesDownloaded < rhs.bytesDownloaded
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    let matchingRuntime = jobs.filter {
        AlphaCapabilityTier.assistantSelectionsMatch($0.tier, config.tier) &&
            (config.runtimeMode == nil || $0.runtimeMode == config.runtimeMode)
    }
    if let exactMatch = mostRecentMatch(in: matchingRuntime) {
        return exactMatch
    }

    return mostRecentMatch(
        in: jobs.filter {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, config.tier)
        }
    )
}

enum RossLocalModelSmokeProfile: String {
    case full
    case quick
    case mtpQuick = "mtp_quick"

    var isShortGenerationProfile: Bool {
        switch self {
        case .quick, .mtpQuick:
            return true
        case .full:
            return false
        }
    }

    static func fromEnvironment(_ environment: [String: String]) -> RossLocalModelSmokeProfile {
        let rawValue = environment["ROSS_LOCAL_MODEL_SMOKE_PROFILE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        switch rawValue {
        case "mtp", "mtp-quick", "mtp_quick":
            return .mtpQuick
        case "quick", "source", "source-only":
            return .quick
        default:
            return .full
        }
    }
}

func alphaDebugLocalModelSmokePack(
    environment: AlphaLocalRuntimeEnvironment,
    fileManager: FileManager = .default
) -> AlphaInstalledModelPack? {
    func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    guard environment.enableRealInference,
          let modelPath = environment.modelPath else {
        return nil
    }
    let runtimeMode = environment.runtimeModeOverride ?? .llamaCppGguf
    guard runtimeMode == .llamaCppGguf || runtimeMode == .mlxSwiftLm || runtimeMode == .appleFoundationModels else {
        return nil
    }
    let usesSystemFoundationModel = runtimeMode == .appleFoundationModels && modelPath == "system-model"
    guard usesSystemFoundationModel || fileManager.fileExists(atPath: modelPath) else {
        return nil
    }
    let checksum = nonEmpty(environment.modelChecksum) ?? "debug-local-model-unverified"
    return AlphaInstalledModelPack(
        packId: nonEmpty(environment.packIDOverride) ?? "debug-local-smoke-\(runtimeMode.rawValue)",
        tier: environment.tierOverride ?? .quickStart,
        installPath: modelPath,
        checksumSha256: checksum,
        artifactKind: nonEmpty(environment.modelKind) ?? "debug_local_model",
        runtimeMode: runtimeMode,
        developmentOnly: false,
        checksumVerified: nonEmpty(environment.modelChecksum) != nil,
        minimumAppVersion: "0.1.0-alpha",
        isActive: true
    )
}

struct RossLocalModelSmokeView: View {
    @State private var status = RossLocalModelSmokeStatusCopy.runningStatus

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .task {
            await runSmoke()
        }
    }

    @MainActor
    private func runSmoke() async {
        let model = AlphaRossModel()
        let environment = ProcessInfo.processInfo.environment
        let smokeProfile = RossLocalModelSmokeProfile.fromEnvironment(ProcessInfo.processInfo.environment)
        let runtimeEnvironment = AlphaLocalRuntimeEnvironment.fromEnvironment(environment)
        let requireDraftAcceleration = RossLocalModelSmokeView.requiresDraftAcceleration(environment)
        let debugModelPath = runtimeEnvironment.modelPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        RossLocalModelSmokeView.log(
            "ROSS_LOCAL_MODEL_SMOKE_DEBUG env_real_inference=\(runtimeEnvironment.enableRealInference) runtime=\(runtimeEnvironment.runtimeModeOverride?.rawValue ?? "nil") tier=\(runtimeEnvironment.tierOverride?.rawValue ?? "nil") pack_id=\(runtimeEnvironment.packIDOverride ?? "nil") model_path_present=\(debugModelPath?.isEmpty == false) model_path_exists=\(debugModelPath.map { FileManager.default.fileExists(atPath: $0) } ?? false) draft_disabled=\(runtimeEnvironment.disableDraftAcceleration) draft_path_present=\(runtimeEnvironment.draftModelPath?.isEmpty == false)"
        )
        RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "launch"))
        let activePack: AlphaInstalledModelPack?
        if let debugPack = debugLocalModelSmokePack(environment: runtimeEnvironment) {
            activePack = debugPack
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE using_debug_pack")
        } else {
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE load_model_state")
            await model.loadIfNeeded()
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE loaded_model_state")
            activePack = model.activePack
        }

        guard let activePack else {
            status = RossLocalModelSmokeStatusCopy.missingAssistantStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_FAIL no_active_pack")
            return
        }

        let activePackHealth = AlphaLocalModelRuntime.runtimeHealth(
            activePack: activePack,
            requestedTier: activePack.tier,
            runtimeEnvironment: runtimeEnvironment
        )
        RossLocalModelSmokeView.log(
            "ROSS_LOCAL_MODEL_SMOKE_HEALTH runtime=\(activePack.runtimeMode.rawValue) available=\(activePackHealth?.available == true) model=\(URL(fileURLWithPath: activePack.installPath).lastPathComponent) checksum=\(activePack.checksumVerified) error=\(activePackHealth?.lastErrorCategory ?? "nil")"
        )
        RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "active_pack"))
        guard activePackHealth?.available == true else {
            if let activePackHealth {
                RossLocalModelSmokeView.logRuntimeIdentity(
                    activePack: activePack,
                    providerName: RossLocalModelSmokeView.preflightProviderName(for: activePack.runtimeMode),
                    actualRuntime: activePack.runtimeMode,
                    providerHealth: activePackHealth,
                    requestedRuntime: runtimeEnvironment.runtimeModeOverride
                )
            }
            status = RossLocalModelSmokeStatusCopy.unavailableAssistantStatus
            RossLocalModelSmokeView.log(
                "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(activePack.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) stage=active_pack error=\(activePackHealth?.lastErrorCategory ?? "runtime_unavailable")"
            )
            return
        }

        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE resolve_provider")
        guard let provider = AlphaLocalModelRuntime.resolveProvider(
            activePack: activePack,
            requestedTier: activePack.tier,
            executor: { _ in
                AlphaLocalModelOutput(
                    rawText: "",
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: ["Smoke fallback should not run."],
                    sourceRefs: [],
                    errorCategory: "smoke_fallback_used"
                )
            }
        ), provider.runtimeMode != .deterministicDev else {
            status = RossLocalModelSmokeStatusCopy.unavailableAssistantStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_FAIL provider_unavailable runtime=\(activePack.runtimeMode.rawValue)")
            return
        }
        let providerHealth = provider.runtimeHealth()
        RossLocalModelSmokeView.logRuntimeIdentity(
            activePack: activePack,
            provider: provider,
            providerHealth: providerHealth,
            requestedRuntime: runtimeEnvironment.runtimeModeOverride
        )
        if let requestedRuntime = runtimeEnvironment.runtimeModeOverride,
           requestedRuntime != provider.runtimeMode {
            status = RossLocalModelSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log(
                "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) requested_runtime=\(requestedRuntime.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) stage=runtime_identity error=runtime_identity_mismatch"
            )
            return
        }
        if requireDraftAcceleration,
           providerHealth.accelerationMode != .draftModelSpeculative ||
            providerHealth.accelerationDraftTokens == nil ||
            providerHealth.draftModelPathLabel == nil {
            status = RossLocalModelSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log(
                "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) stage=runtime_identity error=draft_acceleration_required acceleration=\(providerHealth.accelerationMode?.rawValue ?? "nil") draft_tokens=\(providerHealth.accelerationDraftTokens.map(String.init) ?? "nil") draft_model=\(providerHealth.draftModelPathLabel ?? "nil")"
            )
            return
        }
        guard providerHealth.available else {
            status = RossLocalModelSmokeStatusCopy.unavailableAssistantStatus
            RossLocalModelSmokeView.log(
                "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) stage=provider_health error=\(providerHealth.lastErrorCategory ?? "runtime_unavailable")"
            )
            return
        }
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE provider_ready runtime=\(provider.runtimeMode.rawValue)")
        RossLocalModelSmokeView.log(
            "ROSS_LOCAL_MODEL_SMOKE_RUNTIME context_tokens=\(providerHealth.estimatedContextTokens.map(String.init) ?? "nil") max_input_chars=\(providerHealth.maxInputChars.map(String.init) ?? "nil") acceleration=\(providerHealth.accelerationMode?.rawValue ?? "nil") draft_tokens=\(providerHealth.accelerationDraftTokens.map(String.init) ?? "nil") draft_model=\(providerHealth.draftModelPathLabel ?? "nil")"
        )
        RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "provider_ready"))
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_PROFILE mode=\(smokeProfile.rawValue)")

        let sourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: UUID(),
            documentTitle: "Local Smoke Source",
            pageNumber: 1,
            textSnippet: "Article 417 requires the advocate to verify citations before filing."
        )
        let sourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "Answer from the supplied source. What does Article 417 require? Return JSON with headline, sections, and statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: sourceRef,
                    text: "Local smoke source: Article 417 requires the advocate to verify citations before filing. It does not authorize automatic legal advice.",
                    pageNumber: 1,
                    languageHint: "en",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short string","sections":["one concise string"],"statusNote":"short string"}"#,
            maxOutputTokens: smokeProfile == .mtpQuick ? 64 : 192,
            languageProfile: nil,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let bengaliDocumentId = UUID()
        let bengaliSourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: bengaliDocumentId,
            documentTitle: "Bangla Local Smoke Source",
            pageNumber: 1,
            textSnippet: "ধারা ৪১৭ অনুযায়ী আইনজীবীকে দাখিলের আগে উদ্ধৃতি যাচাই করতে হবে।"
        )
        let bengaliLanguageProfile = AlphaDocumentLanguageProfile(
            documentId: bengaliDocumentId,
            primaryLanguage: .bengali,
            scriptsDetected: ["bengali"],
            confidence: 0.98,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(
                    pageNumber: 1,
                    language: .bengali,
                    script: .bengali,
                    confidence: 0.98
                )
            ]
        )
        let bengaliSourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "বাংলা স্ক্রিপ্টে উত্তর দিন। দেওয়া উৎস অনুযায়ী ধারা ৪১৭ কী করতে বলে? JSON ফিরিয়ে দিন: headline, sections, statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: bengaliSourceRef,
                    text: "বাংলা লোকাল স্মোক উৎস: ধারা ৪১৭ অনুযায়ী আইনজীবীকে দাখিলের আগে উদ্ধৃতি যাচাই করতে হবে। এটি স্বয়ংক্রিয় আইনি পরামর্শ অনুমোদন করে না।",
                    pageNumber: 1,
                    languageHint: "bn",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short Bengali string","sections":["one concise Bengali string"],"statusNote":"short Bengali string"}"#,
            maxOutputTokens: 192,
            languageProfile: bengaliLanguageProfile,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let hindiDocumentId = UUID()
        let hindiSourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: hindiDocumentId,
            documentTitle: "Hindi Local Smoke Source",
            pageNumber: 1,
            textSnippet: "धारा ४१७ के अनुसार अधिवक्ता को दाखिल करने से पहले उद्धरण सत्यापित करना होगा।"
        )
        let hindiLanguageProfile = AlphaDocumentLanguageProfile(
            documentId: hindiDocumentId,
            primaryLanguage: .hindi,
            scriptsDetected: ["devanagari"],
            confidence: 0.98,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(
                    pageNumber: 1,
                    language: .hindi,
                    script: .devanagari,
                    confidence: 0.98
                )
            ]
        )
        let hindiSourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "देवनागरी हिंदी में उत्तर दें। दिए गए स्रोत के अनुसार धारा ४१७ क्या करने को कहती है? JSON लौटाएं: headline, sections, statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: hindiSourceRef,
                    text: "हिंदी लोकल स्मोक स्रोत: धारा ४१७ के अनुसार अधिवक्ता को दाखिल करने से पहले उद्धरण सत्यापित करना होगा। यह स्वचालित कानूनी सलाह की अनुमति नहीं देता।",
                    pageNumber: 1,
                    languageHint: "hi",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short Hindi string","sections":["one concise Hindi string"],"statusNote":"short Hindi string"}"#,
            maxOutputTokens: 192,
            languageProfile: hindiLanguageProfile,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let tamilDocumentId = UUID()
        let tamilSourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: tamilDocumentId,
            documentTitle: "Tamil Local Smoke Source",
            pageNumber: 1,
            textSnippet: "பிரிவு 417 படி வழக்கறிஞர் தாக்கலுக்கு முன் மேற்கோளை சரிபார்க்க வேண்டும்."
        )
        let tamilLanguageProfile = AlphaDocumentLanguageProfile(
            documentId: tamilDocumentId,
            primaryLanguage: .tamil,
            scriptsDetected: ["tamil"],
            confidence: 0.98,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(
                    pageNumber: 1,
                    language: .tamil,
                    script: .tamil,
                    confidence: 0.98
                )
            ]
        )
        let tamilSourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "தமிழ் எழுத்தில் பதிலளிக்கவும். கொடுக்கப்பட்ட மூலத்தின் படி பிரிவு 417 என்ன செய்ய சொல்கிறது? JSON திருப்புங்கள்: headline, sections, statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: tamilSourceRef,
                    text: "தமிழ் உள்ளூர் சோதனை மூலம்: பிரிவு 417 படி வழக்கறிஞர் தாக்கலுக்கு முன் மேற்கோளை சரிபார்க்க வேண்டும். இது தானியங்கி சட்ட ஆலோசனையை அனுமதிக்காது.",
                    pageNumber: 1,
                    languageHint: "ta",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short Tamil string","sections":["one concise Tamil string"],"statusNote":"short Tamil string"}"#,
            maxOutputTokens: 192,
            languageProfile: tamilLanguageProfile,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let teluguDocumentId = UUID()
        let teluguSourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: teluguDocumentId,
            documentTitle: "Telugu Local Smoke Source",
            pageNumber: 1,
            textSnippet: "సెక్షన్ 417 ప్రకారం న్యాయవాది దాఖలు చేసే ముందు ఉదాహరణను ధృవీకరించాలి."
        )
        let teluguLanguageProfile = AlphaDocumentLanguageProfile(
            documentId: teluguDocumentId,
            primaryLanguage: .telugu,
            scriptsDetected: ["telugu"],
            confidence: 0.98,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(
                    pageNumber: 1,
                    language: .telugu,
                    script: .telugu,
                    confidence: 0.98
                )
            ]
        )
        let teluguSourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "తెలుగు లిపిలో సమాధానం ఇవ్వండి. ఇచ్చిన మూలం ప్రకారం సెక్షన్ 417 ఏమి చేయమంటుంది? JSON ఇవ్వండి: headline, sections, statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: teluguSourceRef,
                    text: "తెలుగు స్థానిక స్మోక్ మూలం: సెక్షన్ 417 ప్రకారం న్యాయవాది దాఖలు చేసే ముందు ఉదాహరణను ధృవీకరించాలి. ఇది ఆటోమేటిక్ న్యాయ సలహాను అనుమతించదు.",
                    pageNumber: 1,
                    languageHint: "te",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short Telugu string","sections":["one concise Telugu string"],"statusNote":"short Telugu string"}"#,
            maxOutputTokens: 192,
            languageProfile: teluguLanguageProfile,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let generalInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "No matter document is supplied. Answer cautiously: what should an advocate know when someone asks 'What is Article 417?' Return JSON with headline, sections, and statusNote.",
            sourcePack: [],
            expectedSchema: #"{"headline":"short string","sections":["one concise string"],"statusNote":"short string"}"#,
            maxOutputTokens: smokeProfile == .mtpQuick ? 64 : 192,
            languageProfile: nil,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: false
        )

        let started = Date()
        let perStageTimeoutSeconds = RossLocalModelSmokeView.stageTimeoutSeconds()
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE source timeout=\(Int(perStageTimeoutSeconds))s")
        let sourceBoundOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: sourceBoundInput,
            stage: "source",
            timeoutSeconds: perStageTimeoutSeconds
        )
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE general timeout=\(Int(perStageTimeoutSeconds))s")
        let generalOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: generalInput,
            stage: "general",
            timeoutSeconds: perStageTimeoutSeconds
        )
        let elapsed = Date().timeIntervalSince(started)
        let sourceRawLength = sourceBoundOutput.rawText.count
        let sourceParsedLength = sourceBoundOutput.parsedJson?.count ?? 0
        let generalOutputLength = (generalOutput.parsedJson ?? generalOutput.rawText).count
        let sourceBoundText = sourceBoundOutput.parsedJson ?? sourceBoundOutput.rawText
        let generalText = generalOutput.parsedJson ?? generalOutput.rawText
        let sourceUsedFileFact = RossLocalModelSmokeView.mentionsSmokeSourceFact(sourceBoundText)
        let sourceKeptRefs = RossLocalModelSmokeView.outputKeepsSourceRefs(sourceBoundOutput, for: sourceBoundInput)
        let sourceUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(sourceBoundOutput)
        let generalUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(generalOutput)
        let sourceNativeModel = !sourceUsedLanguageFallback
        let generalNativeModel = !generalUsedLanguageFallback
        let sourceBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "source", output: sourceBoundOutput)
        let generalBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "general", output: generalOutput)

        if smokeProfile.isShortGenerationProfile {
            if sourceBoundOutput.schemaValid,
               sourceBoundOutput.errorCategory == nil,
               generalOutput.schemaValid,
               generalOutput.errorCategory == nil,
               sourceUsedFileFact,
               sourceKeptRefs {
                status = RossLocalModelSmokeStatusCopy.passedStatus
                RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_PASS runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_raw_chars=\(sourceRawLength) source_parsed_chars=\(sourceParsedLength) general_output_chars=\(generalOutputLength) source_refs=\(sourceBoundOutput.sourceRefs.count) source_native_model=\(sourceNativeModel) general_native_model=\(generalNativeModel) \(sourceBenchmarkFields) \(generalBenchmarkFields)")
            } else {
                status = RossLocalModelSmokeStatusCopy.failedStatus
                RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_error=\(sourceBoundOutput.errorCategory ?? "nil") general_error=\(generalOutput.errorCategory ?? "nil") source_grounded=\(sourceUsedFileFact) source_refs_kept=\(sourceKeptRefs) source_refs=\(sourceBoundOutput.sourceRefs.count) source_native_model=\(sourceNativeModel) general_native_model=\(generalNativeModel) source_warning_count=\(sourceBoundOutput.warnings.count) general_warning_count=\(generalOutput.warnings.count) source_raw_chars=\(sourceRawLength) general_output_chars=\(generalOutputLength) \(sourceBenchmarkFields) \(generalBenchmarkFields)")
                RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT source=\(RossLocalModelSmokeView.compactLogExcerpt(sourceBoundText))")
                RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT general=\(RossLocalModelSmokeView.compactLogExcerpt(generalText))")
            }
            return
        }

        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE bengali timeout=\(Int(perStageTimeoutSeconds))s")
        let bengaliOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: bengaliSourceBoundInput,
            stage: "bengali",
            timeoutSeconds: perStageTimeoutSeconds
        )
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE hindi timeout=\(Int(perStageTimeoutSeconds))s")
        let hindiOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: hindiSourceBoundInput,
            stage: "hindi",
            timeoutSeconds: perStageTimeoutSeconds
        )
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE tamil timeout=\(Int(perStageTimeoutSeconds))s")
        let tamilOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: tamilSourceBoundInput,
            stage: "tamil",
            timeoutSeconds: perStageTimeoutSeconds
        )
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE telugu timeout=\(Int(perStageTimeoutSeconds))s")
        let teluguOutput = await RossLocalModelSmokeView.runProviderStage(
            provider: provider,
            input: teluguSourceBoundInput,
            stage: "telugu",
            timeoutSeconds: perStageTimeoutSeconds
        )
        let bengaliOutputLength = (bengaliOutput.parsedJson ?? bengaliOutput.rawText).count
        let hindiOutputLength = (hindiOutput.parsedJson ?? hindiOutput.rawText).count
        let tamilOutputLength = (tamilOutput.parsedJson ?? tamilOutput.rawText).count
        let teluguOutputLength = (teluguOutput.parsedJson ?? teluguOutput.rawText).count
        let bengaliText = bengaliOutput.parsedJson ?? bengaliOutput.rawText
        let hindiText = hindiOutput.parsedJson ?? hindiOutput.rawText
        let tamilText = tamilOutput.parsedJson ?? tamilOutput.rawText
        let teluguText = teluguOutput.parsedJson ?? teluguOutput.rawText
        let bengaliUsedFileFact = RossLocalModelSmokeView.mentionsBengaliSmokeSourceFact(bengaliText)
        let hindiUsedFileFact = RossLocalModelSmokeView.mentionsHindiSmokeSourceFact(hindiText)
        let tamilUsedFileFact = RossLocalModelSmokeView.mentionsTamilSmokeSourceFact(tamilText)
        let teluguUsedFileFact = RossLocalModelSmokeView.mentionsTeluguSmokeSourceFact(teluguText)
        let bengaliKeptRefs = RossLocalModelSmokeView.outputKeepsSourceRefs(bengaliOutput, for: bengaliSourceBoundInput)
        let hindiKeptRefs = RossLocalModelSmokeView.outputKeepsSourceRefs(hindiOutput, for: hindiSourceBoundInput)
        let tamilKeptRefs = RossLocalModelSmokeView.outputKeepsSourceRefs(tamilOutput, for: tamilSourceBoundInput)
        let teluguKeptRefs = RossLocalModelSmokeView.outputKeepsSourceRefs(teluguOutput, for: teluguSourceBoundInput)
        let bengaliUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(bengaliOutput)
        let hindiUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(hindiOutput)
        let tamilUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(tamilOutput)
        let teluguUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(teluguOutput)
        let bengaliNativeModel = !bengaliUsedLanguageFallback
        let hindiNativeModel = !hindiUsedLanguageFallback
        let tamilNativeModel = !tamilUsedLanguageFallback
        let teluguNativeModel = !teluguUsedLanguageFallback
        let bengaliBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "bengali", output: bengaliOutput)
        let hindiBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "hindi", output: hindiOutput)
        let tamilBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "tamil", output: tamilOutput)
        let teluguBenchmarkFields = RossLocalModelSmokeView.benchmarkFields(stage: "telugu", output: teluguOutput)

        if sourceBoundOutput.schemaValid,
           sourceBoundOutput.errorCategory == nil,
           bengaliOutput.schemaValid,
           bengaliOutput.errorCategory == nil,
           hindiOutput.schemaValid,
           hindiOutput.errorCategory == nil,
           tamilOutput.schemaValid,
           tamilOutput.errorCategory == nil,
           teluguOutput.schemaValid,
           teluguOutput.errorCategory == nil,
           generalOutput.schemaValid,
           generalOutput.errorCategory == nil,
           sourceUsedFileFact,
           bengaliUsedFileFact,
           hindiUsedFileFact,
           tamilUsedFileFact,
           teluguUsedFileFact,
           sourceKeptRefs,
           bengaliKeptRefs,
           hindiKeptRefs,
           tamilKeptRefs,
           teluguKeptRefs {
            status = RossLocalModelSmokeStatusCopy.passedStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_PASS runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_raw_chars=\(sourceRawLength) source_parsed_chars=\(sourceParsedLength) bengali_output_chars=\(bengaliOutputLength) hindi_output_chars=\(hindiOutputLength) tamil_output_chars=\(tamilOutputLength) telugu_output_chars=\(teluguOutputLength) general_output_chars=\(generalOutputLength) source_refs=\(sourceBoundOutput.sourceRefs.count) bengali_source_refs=\(bengaliOutput.sourceRefs.count) hindi_source_refs=\(hindiOutput.sourceRefs.count) tamil_source_refs=\(tamilOutput.sourceRefs.count) telugu_source_refs=\(teluguOutput.sourceRefs.count) source_native_model=\(sourceNativeModel) bengali_native_model=\(bengaliNativeModel) hindi_native_model=\(hindiNativeModel) tamil_native_model=\(tamilNativeModel) telugu_native_model=\(teluguNativeModel) general_native_model=\(generalNativeModel) \(sourceBenchmarkFields) \(bengaliBenchmarkFields) \(hindiBenchmarkFields) \(tamilBenchmarkFields) \(teluguBenchmarkFields) \(generalBenchmarkFields)")
        } else {
            status = RossLocalModelSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) profile=\(smokeProfile.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_error=\(sourceBoundOutput.errorCategory ?? "nil") bengali_error=\(bengaliOutput.errorCategory ?? "nil") hindi_error=\(hindiOutput.errorCategory ?? "nil") tamil_error=\(tamilOutput.errorCategory ?? "nil") telugu_error=\(teluguOutput.errorCategory ?? "nil") general_error=\(generalOutput.errorCategory ?? "nil") source_grounded=\(sourceUsedFileFact) bengali_grounded=\(bengaliUsedFileFact) hindi_grounded=\(hindiUsedFileFact) tamil_grounded=\(tamilUsedFileFact) telugu_grounded=\(teluguUsedFileFact) source_refs_kept=\(sourceKeptRefs) bengali_refs_kept=\(bengaliKeptRefs) hindi_refs_kept=\(hindiKeptRefs) tamil_refs_kept=\(tamilKeptRefs) telugu_refs_kept=\(teluguKeptRefs) source_refs=\(sourceBoundOutput.sourceRefs.count) bengali_source_refs=\(bengaliOutput.sourceRefs.count) hindi_source_refs=\(hindiOutput.sourceRefs.count) tamil_source_refs=\(tamilOutput.sourceRefs.count) telugu_source_refs=\(teluguOutput.sourceRefs.count) source_native_model=\(sourceNativeModel) bengali_native_model=\(bengaliNativeModel) hindi_native_model=\(hindiNativeModel) tamil_native_model=\(tamilNativeModel) telugu_native_model=\(teluguNativeModel) general_native_model=\(generalNativeModel) source_warning_count=\(sourceBoundOutput.warnings.count) bengali_warning_count=\(bengaliOutput.warnings.count) hindi_warning_count=\(hindiOutput.warnings.count) tamil_warning_count=\(tamilOutput.warnings.count) telugu_warning_count=\(teluguOutput.warnings.count) general_warning_count=\(generalOutput.warnings.count) source_raw_chars=\(sourceRawLength) bengali_output_chars=\(bengaliOutputLength) hindi_output_chars=\(hindiOutputLength) tamil_output_chars=\(tamilOutputLength) telugu_output_chars=\(teluguOutputLength) general_output_chars=\(generalOutputLength) \(sourceBenchmarkFields) \(bengaliBenchmarkFields) \(hindiBenchmarkFields) \(tamilBenchmarkFields) \(teluguBenchmarkFields) \(generalBenchmarkFields)")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT source=\(RossLocalModelSmokeView.compactLogExcerpt(sourceBoundText))")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT bengali=\(RossLocalModelSmokeView.compactLogExcerpt(bengaliText))")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT hindi=\(RossLocalModelSmokeView.compactLogExcerpt(hindiText))")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT tamil=\(RossLocalModelSmokeView.compactLogExcerpt(tamilText))")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT telugu=\(RossLocalModelSmokeView.compactLogExcerpt(teluguText))")
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_OUTPUT general=\(RossLocalModelSmokeView.compactLogExcerpt(generalText))")
        }
    }

    nonisolated static func log(_ message: String) {
        let line = "\(message)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        } else {
            fputs(line, stderr)
        }
        fflush(stderr)
    }

    nonisolated static func requiresDraftAcceleration(_ environment: [String: String]) -> Bool {
        let rawValue = environment["ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return ["1", "true", "yes", "on"].contains(rawValue)
    }

    nonisolated static func logRuntimeIdentity(
        activePack: AlphaInstalledModelPack,
        provider: any AlphaLocalModelProvider,
        providerHealth: AlphaLocalRuntimeHealth,
        requestedRuntime: AlphaPackRuntimeMode?
    ) {
        logRuntimeIdentity(
            activePack: activePack,
            providerName: String(describing: type(of: provider)),
            actualRuntime: provider.runtimeMode,
            providerHealth: providerHealth,
            requestedRuntime: requestedRuntime
        )
    }

    nonisolated static func logRuntimeIdentity(
        activePack: AlphaInstalledModelPack,
        providerName: String,
        actualRuntime: AlphaPackRuntimeMode,
        providerHealth: AlphaLocalRuntimeHealth,
        requestedRuntime: AlphaPackRuntimeMode?
    ) {
        log("ROSS_RUNTIME_IDENTITY \(runtimeIdentityLine(activePack: activePack, providerName: providerName, actualRuntime: actualRuntime, providerHealth: providerHealth, requestedRuntime: requestedRuntime))")
    }

    nonisolated static func runtimeIdentityLine(
        activePack: AlphaInstalledModelPack,
        provider: any AlphaLocalModelProvider,
        providerHealth: AlphaLocalRuntimeHealth,
        requestedRuntime: AlphaPackRuntimeMode?
    ) -> String {
        runtimeIdentityLine(
            activePack: activePack,
            providerName: String(describing: type(of: provider)),
            actualRuntime: provider.runtimeMode,
            providerHealth: providerHealth,
            requestedRuntime: requestedRuntime
        )
    }

    nonisolated static func runtimeIdentityLine(
        activePack: AlphaInstalledModelPack,
        providerName: String,
        actualRuntime: AlphaPackRuntimeMode,
        providerHealth: AlphaLocalRuntimeHealth,
        requestedRuntime: AlphaPackRuntimeMode?
    ) -> String {
        let artifactURL = URL(fileURLWithPath: activePack.installPath)
        let artifactPathType: String
        if (try? artifactURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            artifactPathType = "directory"
        } else if FileManager.default.fileExists(atPath: activePack.installPath) {
            artifactPathType = "file"
        } else if activePack.runtimeMode == .appleFoundationModels && activePack.installPath == "system-model" {
            artifactPathType = "system"
        } else {
            artifactPathType = "missing"
        }

        let gpuOffloadInfo: String
        switch actualRuntime {
        case .llamaCppGguf:
            let gpuLayers = AlphaLlamaRuntimeProfile.gpuLayerCount(forModelPath: activePack.installPath)
            let offloadKQV = AlphaLlamaRuntimeProfile.shouldOffloadKQV(forModelPath: activePack.installPath)
            let opOffload = AlphaLlamaRuntimeProfile.shouldOffloadHostOperations(forModelPath: activePack.installPath)
            gpuOffloadInfo = "n_gpu_layers:\(gpuLayers),offload_kqv:\(offloadKQV),op_offload:\(opOffload)"
        case .mlxSwiftLm:
            gpuOffloadInfo = "mlx_default"
        case .appleFoundationModels:
            gpuOffloadInfo = "system_managed"
        case .deterministicDev, .mediapipeLlm, .unavailable:
            gpuOffloadInfo = "unavailable"
        }

        let fields: [(String, String)] = [
            ("provider", providerName),
            ("requested_runtime", requestedRuntime?.rawValue ?? "nil"),
            ("actual_runtime", actualRuntime.rawValue),
            ("pack_runtime", activePack.runtimeMode.rawValue),
            ("model_format", activePack.artifactKind),
            ("artifact_path_type", artifactPathType),
            ("artifact_path", artifactURL.lastPathComponent.isEmpty ? activePack.installPath : artifactURL.lastPathComponent),
            ("acceleration", providerHealth.accelerationMode?.rawValue ?? "nil"),
            ("draft_tokens", providerHealth.accelerationDraftTokens.map(String.init) ?? "nil"),
            ("draft_model", providerHealth.draftModelPathLabel ?? "nil"),
            ("context_tokens", providerHealth.estimatedContextTokens.map(String.init) ?? "nil"),
            ("gpu_offload", gpuOffloadInfo),
            ("fallback", actualRuntime == .deterministicDev ? "deterministic_dev" : "none"),
            ("available", String(providerHealth.available)),
            ("error", providerHealth.lastErrorCategory ?? "nil"),
        ]
        let line = fields
            .map { "\($0.0)=\(stableSmokeValue($0.1))" }
            .joined(separator: " ")
        return line
    }

    nonisolated static func preflightProviderName(for runtimeMode: AlphaPackRuntimeMode) -> String {
        switch runtimeMode {
        case .llamaCppGguf:
            return "AlphaLlamaCppProvider"
        case .mlxSwiftLm:
            return "AlphaMLXLocalProvider"
        case .appleFoundationModels:
            return "AlphaFoundationModelsLocalProvider"
        case .deterministicDev:
            return "DeterministicDevLocalModelProvider"
        case .mediapipeLlm, .unavailable:
            return "AlphaUnavailableRealLocalModelProvider"
        }
    }

    nonisolated private static func stableSmokeValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    nonisolated static func compactLogExcerpt(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(360))
    }

    nonisolated static func benchmarkFields(stage: String, output: AlphaLocalModelOutput) -> String {
        let prefix = stableSmokeValue(stage)
        let tokenSpeed = output.outputTokensPerSecond.map { String(format: "%.2f", $0) } ?? "nil"
        let fields: [(String, String)] = [
            ("\(prefix)_input_tokens", output.inputTokenCount.map(String.init) ?? "nil"),
            ("\(prefix)_output_tokens", output.outputTokenCount.map(String.init) ?? "nil"),
            ("\(prefix)_token_speed", tokenSpeed),
            ("\(prefix)_first_token_ms", output.timeToFirstTokenMs.map(String.init) ?? "nil"),
            ("\(prefix)_measured_tokens", String(output.usesMeasuredTokenCounts)),
        ]
        return fields
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: " ")
    }

    nonisolated static func stageTimeoutSeconds() -> TimeInterval {
        let rawValue = ProcessInfo.processInfo.environment["ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS"] ?? ""
        guard let seconds = TimeInterval(rawValue), seconds > 0 else {
            return 180
        }
        return seconds
    }

    nonisolated static func runProviderStage(
        provider: any AlphaLocalModelProvider,
        input: AlphaLocalModelInput,
        stage: String,
        timeoutSeconds: TimeInterval
    ) async -> AlphaLocalModelOutput {
        let startedAt = Date.now
        RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "\(stage)_start"))
        let timeoutOutput = AlphaLocalModelOutput(
            rawText: "",
            parsedJson: nil,
            schemaValid: false,
            warnings: ["Smoke stage \(stage) timed out after \(Int(timeoutSeconds)) seconds."],
            sourceRefs: [],
            errorCategory: "smoke_stage_timeout_\(stage)"
        )
        let providerTask = Task {
            await provider.run(input)
        }

        return await withCheckedContinuation { continuation in
            let gate = RossLocalModelSmokeContinuationGate()
            Task {
                let output = await providerTask.value
                let durationMs = max(Int(Date.now.timeIntervalSince(startedAt) * 1_000), 0)
                RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "\(stage)_done"))
                RossLocalModelSmokeView.log(
                    "ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=\(stage) duration_ms=\(durationMs) schema_valid=\(output.schemaValid) error=\(output.errorCategory ?? "nil")"
                )
                _ = gate.resumeIfNeeded(continuation, output: output)
            }
            Task {
                let nanoseconds = UInt64(max(1, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                if gate.resumeIfNeeded(continuation, output: timeoutOutput) {
                    providerTask.cancel()
                    RossLocalModelSmokeView.log(rossLocalModelSmokeMemoryUsageLine(stage: "\(stage)_timeout"))
                    RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT stage=\(stage) timeout=\(Int(timeoutSeconds))s")
                }
            }
        }
    }

    nonisolated static func usedLanguagePreservingFallback(_ output: AlphaLocalModelOutput) -> Bool {
        output.warnings.contains { warning in
            warning.localizedCaseInsensitiveContains(AlphaLocalModelWarningCopy.sourceLanguageFallback) ||
                warning.localizedCaseInsensitiveContains("Language-preserving source fallback used")
        }
    }

    nonisolated static func outputKeepsSourceRefs(_ output: AlphaLocalModelOutput, for input: AlphaLocalModelInput) -> Bool {
        guard input.sourceRefsRequired else { return true }
        let expectedRefs = Set(input.sourcePack.map(\.sourceRef))
        guard !expectedRefs.isEmpty else { return true }
        let returnedRefs = Set(output.sourceRefs)
        return !returnedRefs.isEmpty && expectedRefs.isSubset(of: returnedRefs)
    }

    nonisolated static func mentionsSmokeSourceFact(_ text: String) -> Bool {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.contains("article 417")
            && folded.contains("citation")
            && (folded.contains("verify") || folded.contains("verification"))
    }

    nonisolated static func mentionsBengaliSmokeSourceFact(_ text: String) -> Bool {
        let hasBengaliScript = text.unicodeScalars.contains { scalar in
            (0x0980...0x09FF).contains(Int(scalar.value))
        }
        return hasBengaliScript
            && (text.contains("৪১৭") || text.contains("417"))
            && text.contains("উদ্ধৃতি")
            && (text.contains("যাচাই") || text.contains("যাচাই করতে"))
    }

    nonisolated static func mentionsHindiSmokeSourceFact(_ text: String) -> Bool {
        let hasDevanagariScript = text.unicodeScalars.contains { scalar in
            (0x0900...0x097F).contains(Int(scalar.value))
        }
        return hasDevanagariScript
            && (text.contains("४१७") || text.contains("417"))
            && text.contains("उद्धरण")
            && (text.contains("सत्यापित") || text.contains("जांच"))
    }

    nonisolated static func mentionsTamilSmokeSourceFact(_ text: String) -> Bool {
        let hasTamilScript = text.unicodeScalars.contains { scalar in
            (0x0B80...0x0BFF).contains(Int(scalar.value))
        }
        return hasTamilScript
            && text.contains("417")
            && text.contains("மேற்கோ")
            && text.contains("சரிபா")
    }

    nonisolated static func mentionsTeluguSmokeSourceFact(_ text: String) -> Bool {
        let hasTeluguScript = text.unicodeScalars.contains { scalar in
            (0x0C00...0x0C7F).contains(Int(scalar.value))
        }
        return hasTeluguScript
            && text.contains("417")
            && text.contains("ఉదాహరణ")
            && text.contains("ధృవీక")
    }

    private func debugLocalModelSmokePack(environment: AlphaLocalRuntimeEnvironment) -> AlphaInstalledModelPack? {
        alphaDebugLocalModelSmokePack(
            environment: environment
        )
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct RossAssistantDownloadSmokeView: View {
    @State private var status = RossAssistantDownloadSmokeStatusCopy.runningStatus

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .task {
            await runSmoke()
        }
    }

    @MainActor
    private func runSmoke() async {
        let environment = ProcessInfo.processInfo.environment
        guard let config = RossAssistantDownloadSmokeConfig.fromEnvironment(environment) else {
            status = RossAssistantDownloadSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log("ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL invalid_config")
            return
        }

        let model = AlphaRossModel()
        RossLocalModelSmokeView.log(
            "ROSS_ASSISTANT_DOWNLOAD_SMOKE_STAGE load_model_state tier=\(config.tier.rawValue) runtime=\(config.runtimeMode?.rawValue ?? "auto") mobile_allowed=\(config.mobileAllowed) force_refresh=\(config.forceRefreshInstalledPack) wait_seconds=\(Int(config.waitSeconds))"
        )
        await model.loadIfNeeded()
        RossLocalModelSmokeView.log("ROSS_ASSISTANT_DOWNLOAD_SMOKE_STAGE loaded_model_state")

        let startTime = Date()
        let downloadTask = Task {
            await model.startPackDownload(
                for: config.tier,
                mobileAllowed: config.mobileAllowed,
                existingJobID: nil,
                forceRefreshInstalledPack: config.forceRefreshInstalledPack,
                targetPackId: nil,
                requestedRuntimeMode: config.runtimeMode
            )
        }

        var lastProgressSignature = ""
        while Date().timeIntervalSince(startTime) < config.waitSeconds {
            if let job = latestAssistantDownloadSmokeJob(in: model, config: config) {
                let signature = [
                    job.state.rawValue,
                    String(job.bytesDownloaded),
                    String(job.totalBytes),
                    job.packId,
                    job.runtimeMode.rawValue
                ].joined(separator: "|")
                if signature != lastProgressSignature {
                    RossLocalModelSmokeView.log(
                        "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PROGRESS state=\(job.state.rawValue) bytes=\(job.bytesDownloaded) total=\(job.totalBytes) pack=\(job.packId) runtime=\(job.runtimeMode.rawValue)"
                    )
                    lastProgressSignature = signature
                }
                if RossAssistantDownloadSmokeView.isTerminal(job.state) {
                    break
                }
            }
            try? await Task.sleep(for: .seconds(1))
        }

        let elapsed = Date().timeIntervalSince(startTime)

        guard let job = latestAssistantDownloadSmokeJob(in: model, config: config) else {
            downloadTask.cancel()
            _ = await downloadTask.result
            status = RossAssistantDownloadSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log("ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL missing_job elapsed=\(String(format: "%.2f", elapsed))s")
            return
        }

        if !RossAssistantDownloadSmokeView.isTerminal(job.state) {
            downloadTask.cancel()
            _ = await downloadTask.result
            status = RossAssistantDownloadSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log(
                "ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL timeout elapsed=\(String(format: "%.2f", elapsed))s tier=\(config.tier.rawValue) state=\(job.state.rawValue) pack=\(job.packId) runtime=\(job.runtimeMode.rawValue) bytes=\(job.bytesDownloaded) total=\(job.totalBytes)"
            )
            return
        }

        _ = await downloadTask.result

        if job.state == .installed,
           let installedPack = model.installedPack(for: config.tier) {
            status = RossAssistantDownloadSmokeStatusCopy.passedStatus
            RossLocalModelSmokeView.log(
                "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=\(String(format: "%.2f", elapsed))s tier=\(config.tier.rawValue) runtime=\(installedPack.runtimeMode.rawValue) pack=\(installedPack.packId) install_path=\(installedPack.installPath) checksum=\(installedPack.checksumVerified)"
            )
            return
        }

        status = RossAssistantDownloadSmokeStatusCopy.failedStatus
        RossLocalModelSmokeView.log(
            "ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL elapsed=\(String(format: "%.2f", elapsed))s tier=\(config.tier.rawValue) state=\(job.state.rawValue) pack=\(job.packId) runtime=\(job.runtimeMode.rawValue) reason=\(job.failureReason ?? "nil") bytes=\(job.bytesDownloaded) total=\(job.totalBytes)"
        )
    }

    @MainActor
    private func latestAssistantDownloadSmokeJob(
        in model: AlphaRossModel,
        config: RossAssistantDownloadSmokeConfig
    ) -> AlphaModelDownloadJob? {
        rossAssistantDownloadSmokeJob(from: model.persisted.modelJobs, config: config)
    }

    private static func isTerminal(_ state: AlphaDownloadState) -> Bool {
        switch state {
        case .installed, .failed, .cancelled, .pausedError, .pausedNoStorage, .pausedUser, .pausedWaitingForWifi:
            return true
        case .notStarted, .queued, .downloading, .verifying:
            return false
        }
    }
}

private final class RossLocalModelSmokeContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resumeIfNeeded(
        _ continuation: CheckedContinuation<AlphaLocalModelOutput, Never>,
        output: AlphaLocalModelOutput
    ) -> Bool {
        lock.lock()
        if didResume {
            lock.unlock()
            return false
        }
        didResume = true
        lock.unlock()

        continuation.resume(returning: output)
        return true
    }
}

struct ScreenshotExportView: View {
    @State private var status = "Rendering screenshots..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 320, minHeight: 180)
        .task {
            await export()
        }
    }

    @MainActor
    private func export() async {
        do {
            let exported = try await RossScreenshotExporter().export()
            status = "Exported \(exported) screenshot(s) to tmp/ui-screenshots"
            terminateSoon()
        } catch {
            status = "Screenshot export failed: \(error.localizedDescription)"
            terminateSoon()
        }
    }

    private func terminateSoon() {
        #if canImport(AppKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApplication.shared.terminate(nil)
        }
        #endif
    }
}

@MainActor
private struct RossScreenshotExporter {
    private let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appending(path: "tmp/ui-screenshots", directoryHint: .isDirectory)

    func export() async throws -> Int {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try clearExistingScreenshots(using: fileManager)

        let onboardingState = makePreviewState(stage: .onboarding)
        let assistantSetupState = makePreviewState(stage: .privateAIPack)
        let homeState = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        let importState = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        let workspaceState = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        let reviewFixture = makeReviewFixtureState()

        var exportedCount = 0

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: onboardingState)),
            name: "ios-onboarding",
            size: CGSize(width: 430, height: 932)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: assistantSetupState)),
            name: "ios-private-assistant",
            size: CGSize(width: 430, height: 932)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: homeState)),
            name: "ios-home",
            size: CGSize(width: 430, height: 1180)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: importState)),
            name: "ios-import",
            size: CGSize(width: 430, height: 1180)
        )
        exportedCount += 1

        if let workspaceCaseID = workspaceState.cases.first?.id {
            try render(
                AlphaRossRootView(
                    initialModel: AlphaRossModel(
                        previewState: workspaceState,
                        previewPath: [.caseWorkspace(workspaceCaseID)]
                    )
                ),
                name: "ios-case-workspace",
                size: CGSize(width: 430, height: 1180)
            )
            exportedCount += 1
        }

        try render(
            AlphaRossRootView(
                initialModel: AlphaRossModel(
                    previewState: reviewFixture.state,
                    previewPath: [.documentViewer(reviewFixture.caseID, reviewFixture.documentID, 4)]
                )
            ),
            name: "ios-document-review",
            size: CGSize(width: 430, height: 1320)
        )
        exportedCount += 1

        return exportedCount
    }

    private func clearExistingScreenshots(using fileManager: FileManager) throws {
        let existingFiles = try fileManager.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)
        for file in existingFiles where file.pathExtension.lowercased() == "png" {
            try fileManager.removeItem(at: file)
        }
    }

    private func makePreviewState(
        stage: AlphaOnboardingStage,
        selectedTab: AlphaAppTab = .home,
        activePack: AlphaCapabilityTier? = nil
    ) -> AlphaPersistedState {
        var state = AlphaPersistedState.seed()
        state.onboardingStage = stage
        state.selectedTab = selectedTab

        if let activePack {
            state.settings.activeTier = activePack
            state.installedPacks = [
                AlphaInstalledModelPack(
                    packId: "\(activePack.rawValue)-pack",
                    tier: activePack,
                    installPath: "preview/\(activePack.rawValue).pack",
                    checksumSha256: String(repeating: "a", count: 64),
                    isActive: true
                )
            ]
            state.modelJobs = []
        }

        return state
    }

    private func makeReviewFixtureState() -> (state: AlphaPersistedState, caseID: UUID, documentID: UUID) {
        var state = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        guard var caseMatter = state.cases.first, var document = state.cases.first?.documents.first else {
            return (state, UUID(), UUID())
        }

        let reviewDateSource = AlphaSourceRef(
            caseId: caseMatter.id,
            documentId: document.id,
            documentTitle: document.title,
            pageNumber: 4,
            paragraphRange: "¶2",
            textSnippet: "List the matter on 28 April 2026 for compliance and hearing directions.",
            ocrConfidence: 0.94
        )
        let reviewDirectionSource = AlphaSourceRef(
            caseId: caseMatter.id,
            documentId: document.id,
            documentTitle: document.title,
            pageNumber: 6,
            paragraphRange: "¶4",
            textSnippet: "Reply shall be filed within two weeks with indexed annexures.",
            ocrConfidence: 0.91
        )

        document.languageProfile = AlphaDocumentLanguageProfile(
            documentId: document.id,
            primaryLanguage: .english,
            scriptsDetected: ["latin"],
            confidence: 0.97,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(pageNumber: 4, language: .english, script: .latin, confidence: 0.97),
                AlphaDocumentLanguageProfilePage(pageNumber: 6, language: .english, script: .latin, confidence: 0.95)
            ]
        )
        document.classification = AlphaLegalDocumentClassification(
            documentId: document.id,
            type: .order,
            subtype: "interim order",
            confidence: 0.73,
            sourceRefs: [reviewDateSource],
            needsReview: true
        )
        document.extractedFields = [
            AlphaExtractedLegalField(
                caseId: caseMatter.id,
                documentId: document.id,
                fieldType: .nextDate,
                label: "Next date",
                value: "28 April 2026",
                sourceRefs: [reviewDateSource],
                confidence: 0.58,
                extractionMode: .caseAssociate,
                extractionPass: .llmExtract,
                needsReview: true
            ),
            AlphaExtractedLegalField(
                caseId: caseMatter.id,
                documentId: document.id,
                fieldType: .orderDirection,
                label: "Order direction",
                value: "Reply to be filed within two weeks with indexed annexures.",
                sourceRefs: [reviewDirectionSource],
                confidence: 0.86,
                extractionMode: .caseAssociate,
                extractionPass: .llmVerify,
                needsReview: false
            )
        ]
        document.extractionFindings = [
            AlphaExtractionFinding(
                caseId: caseMatter.id,
                documentId: document.id,
                kind: .dateConflict,
                message: "The next date should be confirmed against the signed order page before final use.",
                sourceRefs: [reviewDateSource],
                severity: .warning
            )
        ]
        document.extractionRuns = [
            AlphaExtractionRun(
                caseId: caseMatter.id,
                documentId: document.id,
                mode: .caseAssociate,
                status: .needsReview,
                progressState: .needsReview,
                startedAt: .now.addingTimeInterval(-420),
                completedAt: .now.addingTimeInterval(-120),
                pagesProcessed: document.pageCount,
                totalPages: document.pageCount,
                fieldsExtracted: document.extractedFields.count,
                fieldsNeedingReview: 1,
                warnings: ["Next date still needs advocate confirmation."]
            )
        ]
        document.extractedText = """
        Interim order. Reply shall be filed within two weeks with indexed annexures.
        List the matter on 28 April 2026 for compliance and further hearing.
        """
        document.indexingStatus = .indexed
        document.ocrStatus = .nativeText
        document.lastIndexedAt = .now.addingTimeInterval(-120)
        document.dominantSourceSnippet = "Reply shall be filed within two weeks with indexed annexures."

        caseMatter.documents[0] = document
        caseMatter.sourceRefs = [reviewDateSource, reviewDirectionSource] + caseMatter.sourceRefs.filter { $0.documentId != document.id }
        caseMatter.issueHighlights = [
            "Confirm the next date directly from the signed order page.",
            "Use the order direction when preparing the short compliance note."
        ]
        caseMatter.draftTasks = [
            "Confirm the next date in the signed order.",
            "Prepare a short compliance note for reply filing."
        ]
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseMatter.id,
                source: .extractionRun,
                summary: "Ross found an order direction and a next date that still needs advocate confirmation.",
                affectedDocuments: [document.id]
            ),
            at: 0
        )
        caseMatter.updatedAt = .now
        state.cases[0] = caseMatter
        state.tasks = (state.tasks ?? []) + [
            AlphaTaskItem(
                caseId: caseMatter.id,
                title: "Confirm next date in order",
                notes: "Verify the next date from the signed order page before sharing it.",
                dueDate: .now,
                priority: .high,
                source: .extraction
            )
        ]

        return (state, caseMatter.id, document.id)
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        size: CGSize
    ) throws {
        #if canImport(AppKit)
        let hostingView = NSHostingView(
            rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color.rossGroupedBackground)
                .environment(\.colorScheme, .light)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ScreenshotExportError.renderFailed(name)
        }

        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotExportError.renderFailed(name)
        }

        try pngData.write(to: outputDirectory.appending(path: "\(name).png"))
        #else
        throw ScreenshotExportError.unsupportedPlatform
        #endif
    }
}

private enum ScreenshotExportError: LocalizedError {
    case renderFailed(String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case let .renderFailed(name):
            "Could not render screenshot \(name)."
        case .unsupportedPlatform:
            "Screenshot export is only configured for the macOS package host."
        }
    }
}
