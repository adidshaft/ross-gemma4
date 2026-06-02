import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

enum RossLaunchMode {
    case interactive
    case screenshotExport
    case localModelSmoke

    static var current: RossLaunchMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--generate-screenshots") {
            return .screenshotExport
        }
        if arguments.contains("--local-model-smoke") {
            return .localModelSmoke
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
        let activePack: AlphaInstalledModelPack?
        if let debugPack = debugLocalModelSmokePack() {
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

        RossLocalModelSmokeView.log(
            "ROSS_LOCAL_MODEL_SMOKE_HEALTH runtime=\(activePack.runtimeMode.rawValue) available=true model=\(URL(fileURLWithPath: activePack.installPath).lastPathComponent) checksum=\(activePack.checksumVerified)"
        )

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
        RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE provider_ready runtime=\(provider.runtimeMode.rawValue)")

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
            maxOutputTokens: 192,
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
            maxOutputTokens: 192,
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
        let bengaliOutputLength = (bengaliOutput.parsedJson ?? bengaliOutput.rawText).count
        let hindiOutputLength = (hindiOutput.parsedJson ?? hindiOutput.rawText).count
        let tamilOutputLength = (tamilOutput.parsedJson ?? tamilOutput.rawText).count
        let teluguOutputLength = (teluguOutput.parsedJson ?? teluguOutput.rawText).count
        let generalOutputLength = (generalOutput.parsedJson ?? generalOutput.rawText).count
        let sourceBoundText = sourceBoundOutput.parsedJson ?? sourceBoundOutput.rawText
        let bengaliText = bengaliOutput.parsedJson ?? bengaliOutput.rawText
        let hindiText = hindiOutput.parsedJson ?? hindiOutput.rawText
        let tamilText = tamilOutput.parsedJson ?? tamilOutput.rawText
        let teluguText = teluguOutput.parsedJson ?? teluguOutput.rawText
        let generalText = generalOutput.parsedJson ?? generalOutput.rawText
        let sourceUsedFileFact = RossLocalModelSmokeView.mentionsSmokeSourceFact(sourceBoundText)
        let bengaliUsedFileFact = RossLocalModelSmokeView.mentionsBengaliSmokeSourceFact(bengaliText)
        let hindiUsedFileFact = RossLocalModelSmokeView.mentionsHindiSmokeSourceFact(hindiText)
        let tamilUsedFileFact = RossLocalModelSmokeView.mentionsTamilSmokeSourceFact(tamilText)
        let teluguUsedFileFact = RossLocalModelSmokeView.mentionsTeluguSmokeSourceFact(teluguText)
        let sourceUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(sourceBoundOutput)
        let bengaliUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(bengaliOutput)
        let hindiUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(hindiOutput)
        let tamilUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(tamilOutput)
        let teluguUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(teluguOutput)
        let generalUsedLanguageFallback = RossLocalModelSmokeView.usedLanguagePreservingFallback(generalOutput)
        let sourceNativeModel = !sourceUsedLanguageFallback
        let bengaliNativeModel = !bengaliUsedLanguageFallback
        let hindiNativeModel = !hindiUsedLanguageFallback
        let tamilNativeModel = !tamilUsedLanguageFallback
        let teluguNativeModel = !teluguUsedLanguageFallback
        let generalNativeModel = !generalUsedLanguageFallback

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
           teluguUsedFileFact {
            status = RossLocalModelSmokeStatusCopy.passedStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_PASS runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_raw_chars=\(sourceRawLength) source_parsed_chars=\(sourceParsedLength) bengali_output_chars=\(bengaliOutputLength) hindi_output_chars=\(hindiOutputLength) tamil_output_chars=\(tamilOutputLength) telugu_output_chars=\(teluguOutputLength) general_output_chars=\(generalOutputLength) source_native_model=\(sourceNativeModel) bengali_native_model=\(bengaliNativeModel) hindi_native_model=\(hindiNativeModel) tamil_native_model=\(tamilNativeModel) telugu_native_model=\(teluguNativeModel) general_native_model=\(generalNativeModel)")
        } else {
            status = RossLocalModelSmokeStatusCopy.failedStatus
            RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_error=\(sourceBoundOutput.errorCategory ?? "nil") bengali_error=\(bengaliOutput.errorCategory ?? "nil") hindi_error=\(hindiOutput.errorCategory ?? "nil") tamil_error=\(tamilOutput.errorCategory ?? "nil") telugu_error=\(teluguOutput.errorCategory ?? "nil") general_error=\(generalOutput.errorCategory ?? "nil") source_grounded=\(sourceUsedFileFact) bengali_grounded=\(bengaliUsedFileFact) hindi_grounded=\(hindiUsedFileFact) tamil_grounded=\(tamilUsedFileFact) telugu_grounded=\(teluguUsedFileFact) source_native_model=\(sourceNativeModel) bengali_native_model=\(bengaliNativeModel) hindi_native_model=\(hindiNativeModel) tamil_native_model=\(tamilNativeModel) telugu_native_model=\(teluguNativeModel) general_native_model=\(generalNativeModel) source_warning_count=\(sourceBoundOutput.warnings.count) bengali_warning_count=\(bengaliOutput.warnings.count) hindi_warning_count=\(hindiOutput.warnings.count) tamil_warning_count=\(tamilOutput.warnings.count) telugu_warning_count=\(teluguOutput.warnings.count) general_warning_count=\(generalOutput.warnings.count) source_raw_chars=\(sourceRawLength) bengali_output_chars=\(bengaliOutputLength) hindi_output_chars=\(hindiOutputLength) tamil_output_chars=\(tamilOutputLength) telugu_output_chars=\(teluguOutputLength) general_output_chars=\(generalOutputLength)")
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

    nonisolated static func compactLogExcerpt(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(360))
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
                _ = gate.resumeIfNeeded(continuation, output: output)
            }
            Task {
                let nanoseconds = UInt64(max(1, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                if gate.resumeIfNeeded(continuation, output: timeoutOutput) {
                    providerTask.cancel()
                    RossLocalModelSmokeView.log("ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT stage=\(stage) timeout=\(Int(timeoutSeconds))s")
                }
            }
        }
    }

    nonisolated static func usedLanguagePreservingFallback(_ output: AlphaLocalModelOutput) -> Bool {
        output.warnings.contains { warning in
            warning.localizedCaseInsensitiveContains("Language-preserving source fallback used")
        }
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

    private func debugLocalModelSmokePack() -> AlphaInstalledModelPack? {
        let environment = AlphaLocalRuntimeEnvironment.fromEnvironment(ProcessInfo.processInfo.environment)
        guard environment.enableRealInference,
              let modelPath = environment.modelPath,
              FileManager.default.fileExists(atPath: modelPath) else {
            return nil
        }
        let runtimeMode = environment.runtimeModeOverride ?? .llamaCppGguf
        guard runtimeMode == .llamaCppGguf || runtimeMode == .appleFoundationModels else {
            return nil
        }
        let checksum = nonEmpty(environment.modelChecksum) ?? "debug-local-model-unverified"
        return AlphaInstalledModelPack(
            packId: "debug-local-smoke-\(runtimeMode.rawValue)",
            tier: .quickStart,
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

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
