import LocalAuthentication
import llama
import SwiftUI
import XCTest
@testable import Ross

final class AlphaLawyerUsabilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AlphaLlamaCppProvider.modelLoadValidator = { _ in }
    }

    override func tearDown() {
        AlphaLlamaCppProvider.modelLoadValidator = { path in
            _ = try LlamaContext.create_context(path: path)
        }
        AlphaLlamaCppProvider.contextFactory = { path in
            try LlamaContext.create_context(path: path)
        }
        LlamaContext.samplerFactory = { params in
            llama_sampler_chain_init(params)
        }
        super.tearDown()
    }

    func testLegacyChatTurnsDecodeIntoChatSessions() throws {
        let caseID = UUID()
        let turnID = UUID()
        let askedAt = Date(timeIntervalSince1970: 1_713_700_000)
        let updatedAt = Date(timeIntervalSince1970: 1_713_700_360)

        let json = """
        {
          "id": "\(caseID.uuidString)",
          "title": "Legacy Matter",
          "forum": "Delhi High Court",
          "stage": "intake",
          "folderTint": "indigo",
          "localNotice": "Case files stay on this device",
          "summary": "summary",
          "issueHighlights": [],
          "evidenceNotes": [],
          "draftTasks": [],
          "documents": [],
          "sourceRefs": [],
          "chatTurns": [
            {
              "id": "\(turnID.uuidString)",
              "askedAt": "\(ISO8601DateFormatter().string(from: askedAt))",
              "question": "What should I prepare?",
              "answerTitle": "Draft answer",
              "answerSections": ["Prepare the chronology."],
              "sourceRefs": []
            }
          ],
          "advocateCorrections": [],
          "caseMemoryUpdates": [],
          "updatedAt": "\(ISO8601DateFormatter().string(from: updatedAt))"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AlphaCaseMatter.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.chatSessions.count, 1)
        XCTAssertEqual(decoded.activeChatSessionID, decoded.chatSessions.first?.id)
        XCTAssertEqual(decoded.chatSessions.first?.turns.count, 1)
        XCTAssertEqual(decoded.chatSessions.first?.turns.first?.id, turnID)
        XCTAssertEqual(decoded.chatSessions.first?.turns.first?.question, "What should I prepare?")
    }

    func testLlamaSamplerSetupFailureReturnsRuntimeErrorInsteadOfCrashing() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ross-sampler-failure-\(UUID().uuidString).gguf")
        try Data([0x52, 0x4f, 0x53, 0x53]).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        AlphaLlamaCppProvider.contextFactory = { _ in
            throw LlamaError.couldNotInitializeSampler
        }

        let provider = AlphaLlamaCppProvider(
            capabilityTier: .quickStart,
            modelPathLabel: "Test GGUF",
            modelPath: tempURL.path,
            checksumVerified: true
        )
        let input = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "Summarise the selected file.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: AlphaSourceRef(
                        caseId: UUID(),
                        documentId: UUID(),
                        documentTitle: "Order",
                        pageNumber: 1,
                        textSnippet: "Court listed the matter next week."
                    ),
                    text: "Court listed the matter next week.",
                    pageNumber: 1,
                    languageHint: "en",
                    ocrConfidence: 0.96
                )
            ],
            expectedSchema: "plain_text",
            maxOutputTokens: 64,
            languageProfile: nil,
            documentClassification: nil,
            extractionMode: .quickStart
        )

        let output = await provider.run(input)

        XCTAssertFalse(output.schemaValid)
        XCTAssertEqual(output.errorCategory, "inference_failed")
        XCTAssertEqual(output.warnings, [AlphaLocalModelWarningCopy.assistantCouldNotFinish])
    }

    func testTaskAdditionUpdatesLocalState() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let title = "Prepare chronology for mention"

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.addTask(title: title, caseId: nil, dueDate: .now)
            }
            let snapshot = await MainActor.run { model.persisted }
            let taskTitles = snapshot.tasks?.map(\.title) ?? []
            XCTAssertTrue(taskTitles.contains(title))
        }
    }

    func testWebOffKeepsPublicLawSearchIdle() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let publicLawCalls = SendableBox(0)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in
                    publicLawCalls.value += 1
                    return []
                })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.submitAsk(question: "Find law on delay condonation", scopeCaseID: nil, webEnabled: false)
            }

            let status = await MainActor.run { model.latestAskResult?.statusNote }
            let preview = await MainActor.run { model.publicLawPreview }

            XCTAssertEqual(0, publicLawCalls.value)
            XCTAssertNil(preview)
            XCTAssertEqual("Private assistant setup required", status)
        }
    }

    func testAskRossExplainsPrivateAssistantSetupBeforeDownload() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.empty())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.submitAsk(
                    question: "What can I do before setting up the private assistant?",
                    scopeCaseID: nil,
                    webEnabled: false
                )
            }

            let result = await MainActor.run { model.latestAskResult }
            XCTAssertEqual("Private assistant setup", result?.answerTitle)
            XCTAssertEqual("Private assistant", result?.statusNote)
            XCTAssertTrue(result?.answerSections.joined(separator: " ").contains("organize matters") == true)
            XCTAssertTrue(alphaAskQuestionTargetsAssistantSetup(result?.question ?? ""))
            XCTAssertEqual([], result?.selectedDocumentTitles)
            XCTAssertEqual([], result?.caseFileSources)
        }
    }

    func testPendingLocalAskResultMakesDownloadedModelVisible() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            model.privateAISnapshot.activePack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q2",
                tier: .flash,
                installPath: "model-packs/flash/google_gemma-4-E2B-it-Q2_K.gguf",
                checksumSha256: "local-test-checksum",
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )

            let baseResult = AlphaAskResult(
                kind: .userAsk,
                question: "Give me summaries from selected files.",
                scopeCaseID: nil,
                scopeLabel: "All work",
                selectedDocumentTitles: ["Demo affidavit", "Demo order"],
                answerTitle: "Ross drafted this from your files",
                answerSections: ["Demo affidavit: included for this answer."],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: nil,
                needsReviewWarning: nil
            )

            let pending = model.buildPendingLocalModelAskResult(
                question: "Give me summaries from selected files.",
                scopeCaseID: nil,
                baseResult: baseResult
            )

            XCTAssertEqual("Ross is answering...", pending.answerTitle)
            XCTAssertEqual("Flash assistant is preparing a private answer", pending.statusNote)
            XCTAssertTrue(pending.isPendingLocalModelResponse)
            XCTAssertEqual("Flash assistant", pending.pendingLocalModelLabel)
            XCTAssertTrue(
                pending.answerSections.joined(separator: " ").contains("replace this with the private answer")
            )
            XCTAssertTrue(
                pending.answerSections.joined(separator: " ").contains("Tagged files: Demo affidavit, Demo order")
            )
            XCTAssertEqual(["Demo affidavit", "Demo order"], pending.selectedDocumentTitles)
            XCTAssertEqual([], pending.caseFileSources)

            let visibleCopy = ([pending.statusNote ?? ""] + pending.answerSections).joined(separator: " ")
            for forbidden in ["Gemma", "Q2", "Q4", "GGUF", "runtime", "llama", "checksum", "artifact"] {
                XCTAssertNil(
                    visibleCopy.range(of: forbidden, options: [.caseInsensitive]),
                    "\(forbidden) leaked into pending private-answer copy"
                )
            }

            let previousLanguageCode = rossSelectedLanguageCode()
            rossSaveLanguageSelection(code: "hi")
            defer { rossSaveLanguageSelection(code: previousLanguageCode) }

            let localizedPending = model.buildPendingLocalModelAskResult(
                question: "Give me summaries from selected files.",
                scopeCaseID: nil,
                baseResult: baseResult
            )

            XCTAssertEqual("Ross जवाब तैयार कर रहा है...", localizedPending.answerTitle)
            XCTAssertEqual("Flash assistant private answer तैयार कर रहा है", localizedPending.statusNote)
            XCTAssertTrue(localizedPending.isPendingLocalModelResponse)
            XCTAssertEqual("Flash assistant", localizedPending.pendingLocalModelLabel)
        }
    }

    @MainActor
    func testHindiSelectedFileSummaryBuildsDocumentAskResult() {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        let caseID = UUID()
        let documentID = UUID()
        let sourceRef = AlphaSourceRef(
            caseId: caseID,
            documentId: documentID,
            documentTitle: "Hindi leave application",
            pageNumber: 1,
            textSnippet: "कर्मचारी ने छुट्टी के लिए आवेदन किया।"
        )
        let nextDateField = AlphaExtractedLegalField(
            caseId: caseID,
            documentId: documentID,
            fieldType: .nextDate,
            label: "Next date",
            value: "12 March 2026",
            sourceRefs: [sourceRef],
            confidence: 0.91,
            extractionMode: .basic,
            extractionPass: .regex,
            needsReview: false
        )
        var state = AlphaPersistedState.seed()
        state.cases = [
            AlphaCaseMatter(
                id: caseID,
                title: "Hindi matter",
                forum: "Labour Court",
                stage: .pleadings,
                summary: "Hindi document imported.",
                issueHighlights: [],
                evidenceNotes: [],
                draftTasks: [],
                documents: [
                    AlphaCaseDocument(
                        id: documentID,
                        title: "Hindi leave application",
                        fileName: "leave.txt",
                        kind: .text,
                        storedRelativePath: "docs/leave.txt",
                        importedAt: .now,
                        pageCount: 1,
                        ocrStatus: .nativeText,
                        indexingStatus: .indexed,
                        extractedText: "कर्मचारी ने छुट्टी के लिए आवेदन किया और नियोक्ता ने जवाब नहीं दिया।",
                        pages: [
                            AlphaDocumentPage(
                                pageNumber: 1,
                                snippet: "कर्मचारी ने छुट्टी के लिए आवेदन किया।",
                                extractedText: "कर्मचारी ने छुट्टी के लिए आवेदन किया और नियोक्ता ने जवाब नहीं दिया।"
                            )
                        ],
                        extractedFields: [nextDateField]
                    )
                ],
                sourceRefs: [sourceRef]
            )
        ]

        let model = AlphaRossModel(previewState: state)
        model.setSelectedAskDocumentIDs([documentID], for: caseID)

        let result = model.buildLocalAskResult(
            question: "इस दस्तावेज़ का सारांश दें",
            scopeCaseID: caseID
        )

        XCTAssertEqual(result.answerTitle, "दस्तावेज़ सारांश")
        XCTAssertEqual(result.selectedDocumentTitles, ["Hindi leave application"])
        XCTAssertTrue(result.answerSections.joined(separator: " ").contains("कर्मचारी ने छुट्टी"))
        XCTAssertEqual(result.statusNote, "selected files से जवाब")

        let englishTriggerResult = model.buildLocalAskResult(
            question: "summarize this document",
            scopeCaseID: caseID
        )
        let englishTriggerText = englishTriggerResult.answerSections.joined(separator: " ")
        XCTAssertTrue(englishTriggerText.contains("Next date मिली: 12 March 2026."), englishTriggerText)
        XCTAssertFalse(englishTriggerText.contains("Next date found: 12 March 2026."), englishTriggerText)
    }

    @MainActor
    func testBanglaSelectedFileSummaryBuildsDocumentAskResult() {
        let caseID = UUID()
        let documentID = UUID()
        let sourceRef = AlphaSourceRef(
            caseId: caseID,
            documentId: documentID,
            documentTitle: "Bangla leave application",
            pageNumber: 1,
            textSnippet: "কর্মী ছুটির জন্য আবেদন করেছিলেন।"
        )
        var state = AlphaPersistedState.seed()
        state.cases = [
            AlphaCaseMatter(
                id: caseID,
                title: "Bangla matter",
                forum: "Labour Court",
                stage: .pleadings,
                summary: "Bangla document imported.",
                issueHighlights: [],
                evidenceNotes: [],
                draftTasks: [],
                documents: [
                    AlphaCaseDocument(
                        id: documentID,
                        title: "Bangla leave application",
                        fileName: "leave.txt",
                        kind: .text,
                        storedRelativePath: "docs/leave.txt",
                        importedAt: .now,
                        pageCount: 1,
                        ocrStatus: .nativeText,
                        indexingStatus: .indexed,
                        extractedText: "কর্মী ছুটির জন্য আবেদন করেছিলেন এবং নিয়োগকর্তা উত্তর দেননি।",
                        pages: [
                            AlphaDocumentPage(
                                pageNumber: 1,
                                snippet: "কর্মী ছুটির জন্য আবেদন করেছিলেন।",
                                extractedText: "কর্মী ছুটির জন্য আবেদন করেছিলেন এবং নিয়োগকর্তা উত্তর দেননি।"
                            )
                        ]
                    )
                ],
                sourceRefs: [sourceRef]
            )
        ]

        let model = AlphaRossModel(previewState: state)
        model.setSelectedAskDocumentIDs([documentID], for: caseID)

        let result = model.buildLocalAskResult(
            question: "এই ফাইলটি সারাংশ করুন",
            scopeCaseID: caseID
        )

        XCTAssertEqual(result.answerTitle, "নথির সারাংশ")
        XCTAssertEqual(result.selectedDocumentTitles, ["Bangla leave application"])
        XCTAssertTrue(result.answerSections.joined(separator: " ").contains("কর্মী ছুটির"))
        XCTAssertEqual(result.statusNote, "selected files থেকে উত্তর")
    }

    @MainActor
    func testSelectedFileSourcePackIncludesConfirmedReviewDetails() {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        let caseID = UUID()
        let documentID = UUID()
        let confirmedSource = AlphaSourceRef(
            caseId: caseID,
            documentId: documentID,
            documentTitle: "Order sheet",
            pageNumber: 4,
            textSnippet: "Next hearing: 17 June 2026"
        )
        let confirmedField = AlphaExtractedLegalField(
            caseId: caseID,
            documentId: documentID,
            fieldType: .nextDate,
            label: "Next hearing",
            value: "17 June 2026",
            sourceRefs: [confirmedSource],
            confidence: 0.94,
            extractionMode: .basic,
            extractionPass: .userCorrected,
            needsReview: false,
            userCorrected: true
        )
        let unconfirmedField = AlphaExtractedLegalField(
            caseId: caseID,
            documentId: documentID,
            fieldType: .amount,
            label: "Claim amount",
            value: "Rs. 99,99,999",
            sourceRefs: [confirmedSource],
            confidence: 0.42,
            extractionMode: .basic,
            extractionPass: .llmExtract,
            needsReview: true
        )
        var state = AlphaPersistedState.seed()
        state.cases = [
            AlphaCaseMatter(
                id: caseID,
                title: "Sparse reviewed matter",
                forum: "District Court",
                stage: .evidence,
                summary: "Reviewed order with sparse text.",
                issueHighlights: [],
                evidenceNotes: [],
                draftTasks: [],
                documents: [
                    AlphaCaseDocument(
                        id: documentID,
                        title: "Order sheet",
                        fileName: "order.txt",
                        kind: .text,
                        storedRelativePath: "docs/order.txt",
                        importedAt: .now,
                        pageCount: 1,
                        ocrStatus: .nativeText,
                        indexingStatus: .indexed,
                        extractedText: nil,
                        pages: [],
                        extractedFields: [unconfirmedField, confirmedField]
                    )
                ],
                sourceRefs: [confirmedSource]
            )
        ]

        let model = AlphaRossModel(previewState: state)
        model.setSelectedAskDocumentIDs([documentID], for: caseID)

        let sourcePack = model.askRuntimeSourcePack(
            question: "What is the next hearing in the selected file?",
            scopeCaseID: caseID,
            selectedDocuments: model.selectedAskDocuments(for: caseID)
        )
        let combinedText = sourcePack.map(\.text).joined(separator: "\n")

        XCTAssertTrue(combinedText.contains("Order sheet से confirmed details"))
        XCTAssertFalse(combinedText.contains("Confirmed details from Order sheet"))
        XCTAssertTrue(combinedText.contains("Next hearing: 17 June 2026"))
        XCTAssertFalse(combinedText.contains("Rs. 99,99,999"))
        let confirmedBlock = sourcePack.first { $0.text.contains("Order sheet से confirmed details") }
        XCTAssertEqual(confirmedBlock?.sourceRef.pageNumber, 4)
    }

    @MainActor
    func testMatterMemorySourcePackUsesSelectedLanguageLabels() {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        let caseID = UUID()
        let nextHearing = Date(timeIntervalSince1970: 1_777_248_000)
        var state = AlphaPersistedState.seed()
        state.cases = [
            AlphaCaseMatter(
                id: caseID,
                title: "Hindi source-pack matter",
                forum: "District Court",
                stage: .arguments,
                nextHearing: nextHearing,
                summary: "Matter summary for local assistant context.",
                issueHighlights: ["Delay condonation"],
                evidenceNotes: [],
                draftTasks: [],
                documents: [],
                sourceRefs: []
            )
        ]

        let model = AlphaRossModel(previewState: state)
        let combinedText = model.askRuntimeMatterMemorySourcePack(scopeCaseID: caseID)
            .map(\.text)
            .joined(separator: "\n")

        XCTAssertTrue(combinedText.contains("अगली hearing:"), combinedText)
        XCTAssertFalse(combinedText.contains("Next hearing:"), combinedText)
    }

    @MainActor
    func testSelectedFileWaitingResultUsesPlainLanguage() {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        let caseID = UUID()
        let documentID = UUID()
        var state = AlphaPersistedState.seed()
        state.cases = [
            AlphaCaseMatter(
                id: caseID,
                title: "Reading matter",
                forum: "District Court",
                stage: .evidence,
                summary: "A selected file is still being read.",
                issueHighlights: [],
                evidenceNotes: [],
                draftTasks: [],
                documents: [
                    AlphaCaseDocument(
                        id: documentID,
                        title: "Reading scan",
                        fileName: "reading-scan.pdf",
                        kind: .pdf,
                        storedRelativePath: "docs/reading-scan.pdf",
                        importedAt: .now,
                        pageCount: 1,
                        ocrStatus: .placeholder,
                        indexingStatus: .extracting,
                        pages: []
                    )
                ],
                sourceRefs: []
            )
        ]

        let model = AlphaRossModel(previewState: state)
        model.setSelectedAskDocumentIDs([documentID], for: caseID)

        let result = model.buildLocalAskResult(
            question: "What does this selected file say?",
            scopeCaseID: caseID
        )
        let answerText = result.answerSections.joined(separator: " ")

        XCTAssertEqual(result.answerTitle, "Ross अभी यह file पढ़ रहा है")
        XCTAssertEqual(result.statusNote, rossLocalized("reading", languageCode: "hi"))
        XCTAssertTrue(answerText.contains("Reading scan"))
        XCTAssertTrue(answerText.contains("ready होने"))
        XCTAssertFalse(answerText.contains("selected files are ready"), answerText)
        XCTAssertFalse(answerText.localizedCaseInsensitiveContains("placeholder"), answerText)
        XCTAssertFalse(answerText.localizedCaseInsensitiveContains("incomplete text"), answerText)
    }

    func testReadyAssistantStatusWinsOverFailedInactiveDownload() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            let activePack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q2",
                tier: .flash,
                installPath: "model-packs/flash/google_gemma-4-E2B-it-Q2_K.gguf",
                checksumSha256: "local-test-checksum",
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            model.privateAISnapshot.activePack = activePack
            model.privateAISnapshot.installedPacks = [activePack]
            model.privateAISnapshot.activeRuntimeHealth = AlphaLocalRuntimeHealth(
                runtimeMode: .llamaCppGguf,
                available: true,
                modelPathPresent: true,
                modelPathLabel: "google_gemma-4-E2B-it-Q2_K.gguf",
                checksumVerified: true,
                supportedTasks: [.matterQuestionAnswer],
                maxInputChars: 5000,
                estimatedContextTokens: 2048,
                lastErrorCategory: nil,
                userFacingStatus: "Private assistant is ready on this iPhone.",
                explicitOptInEnabled: true
            )
            model.persisted.modelJobs = [
                AlphaModelDownloadJob(
                    sessionId: "failed-optional-download",
                    packId: "gemma-4-e2b-q4",
                    tier: .quickStart,
                    state: .failed,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: 0,
                    totalBytes: 3_462_678_272,
                    checksumSha256: "",
                    artifactKind: "local_model_artifact",
                    runtimeMode: .llamaCppGguf,
                    developmentOnly: false,
                    failureReason: "NSURLErrorDomain -1"
                )
            ]

            let status = alphaAssistantStatusSnapshot(model)
            XCTAssertEqual("My assistant is ready", status.title)
        }
    }

    func testAssistantStatusShowsUsefulRecoveryReason() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            model.persisted.modelJobs = [
                AlphaModelDownloadJob(
                    sessionId: "needs-space",
                    packId: "gemma-4-e2b-q4",
                    tier: .quickStart,
                    state: .pausedNoStorage,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: 0,
                    totalBytes: 3_462_678_272,
                    checksumSha256: "",
                    artifactKind: "local_model_artifact",
                    runtimeMode: .llamaCppGguf,
                    developmentOnly: false,
                    failureReason: "Free up 4 GB to finish assistant setup."
                )
            ]

            let status = alphaAssistantStatusSnapshot(model)
            XCTAssertEqual("My assistant needs attention", status.title)
            XCTAssertEqual("Free up 4 GB to finish assistant setup.", status.detail)

            let localizedStatus = alphaAssistantStatusSnapshot(model, languageCode: "hi")
            XCTAssertTrue(localizedStatus.title.contains("attention"))
            XCTAssertEqual("Free up 4 GB to finish assistant setup.", localizedStatus.detail)
        }
    }

    func testAssistantStatusHidesTechnicalRecoveryReason() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            model.persisted.modelJobs = [
                AlphaModelDownloadJob(
                    sessionId: "technical-failure",
                    packId: "gemma-4-e2b-q4",
                    tier: .quickStart,
                    state: .failed,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: 0,
                    totalBytes: 3_462_678_272,
                    checksumSha256: "",
                    artifactKind: "local_model_artifact",
                    runtimeMode: .llamaCppGguf,
                    developmentOnly: false,
                    failureReason: "Model provider byte-range check failed."
                )
            ]

            let status = alphaAssistantStatusSnapshot(model)
            XCTAssertEqual("My assistant needs attention", status.title)
            XCTAssertEqual("Setup could not finish. Open My assistant to retry or repair setup.", status.detail)
            XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("NSURLErrorDomain"))
            XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("model"))
            XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("provider"))
            XCTAssertFalse(status.detail.localizedCaseInsensitiveContains("byte-range"))

            let localizedStatus = alphaAssistantStatusSnapshot(model, languageCode: "ta")
            XCTAssertTrue(localizedStatus.title.contains("attention"))
            XCTAssertTrue(localizedStatus.detail.contains("Repair setup"))
            XCTAssertFalse(localizedStatus.detail.localizedCaseInsensitiveContains("model"))
            XCTAssertFalse(localizedStatus.detail.localizedCaseInsensitiveContains("provider"))
        }
    }

    func testAssistantVerificationSummaryUsesProductLanguage() {
        let activePack = AlphaInstalledModelPack(
            packId: "gemma-4-e2b-q4",
            tier: .quickStart,
            installPath: "model-packs/quick_start/google_gemma-4-E2B-it-Q4_K_M.gguf",
            checksumSha256: String(repeating: "a", count: 64),
            artifactKind: "local_model_artifact",
            runtimeMode: .llamaCppGguf,
            developmentOnly: false,
            checksumVerified: true,
            isActive: true
        )
        let readyHealth = AlphaLocalRuntimeHealth(
            runtimeMode: .llamaCppGguf,
            available: true,
            modelPathPresent: true,
            modelPathLabel: "google_gemma-4-E2B-it-Q4_K_M.gguf",
            checksumVerified: true,
            supportedTasks: [.matterQuestionAnswer],
            maxInputChars: 5000,
            estimatedContextTokens: 2048,
            lastErrorCategory: nil,
            userFacingStatus: "Private assistant is ready on this iPhone.",
            explicitOptInEnabled: true
        )
        let repairHealth = AlphaLocalRuntimeHealth(
            runtimeMode: .llamaCppGguf,
            available: false,
            modelPathPresent: true,
            modelPathLabel: "google_gemma-4-E2B-it-Q4_K_M.gguf",
            checksumVerified: false,
            supportedTasks: [],
            maxInputChars: nil,
            estimatedContextTokens: nil,
            lastErrorCategory: "runtime_validation_failed",
            userFacingStatus: "Ross could not open the downloaded assistant file.",
            explicitOptInEnabled: true
        )

        let summaries = [
            alphaAssistantVerificationSummary(runtimeHealth: nil, activePack: nil),
            alphaAssistantVerificationSummary(runtimeHealth: nil, activePack: activePack),
            alphaAssistantVerificationSummary(runtimeHealth: readyHealth, activePack: activePack),
            alphaAssistantVerificationSummary(runtimeHealth: repairHealth, activePack: activePack)
        ]

        XCTAssertTrue(summaries[0].contains("No assistant setup"))
        XCTAssertTrue(summaries[1].contains("verify assistant setup"))
        XCTAssertTrue(summaries[2].contains("Assistant setup opened and verified"))
        XCTAssertTrue(summaries[3].contains("Repair setup"))

        let hindiSummaries = [
            alphaAssistantVerificationSummary(runtimeHealth: nil, activePack: nil, languageCode: "hi"),
            alphaAssistantVerificationSummary(runtimeHealth: nil, activePack: activePack, languageCode: "hi"),
            alphaAssistantVerificationSummary(runtimeHealth: readyHealth, activePack: activePack, languageCode: "hi"),
            alphaAssistantVerificationSummary(runtimeHealth: repairHealth, activePack: activePack, languageCode: "hi")
        ]
        XCTAssertTrue(hindiSummaries[0].contains("active नहीं"))
        XCTAssertTrue(hindiSummaries[1].contains("verify करेगा"))
        XCTAssertTrue(hindiSummaries[2].contains("verify हुआ"))
        XCTAssertTrue(hindiSummaries[3].contains("Repair setup"))

        for summary in summaries + hindiSummaries {
            for forbidden in ["Gemma", "GGUF", "Q4", "runtime", "checksum", "artifact"] {
                XCTAssertFalse(
                    summary.localizedCaseInsensitiveContains(forbidden),
                    "\(forbidden) leaked into assistant verification summary: \(summary)"
                )
            }
            XCTAssertFalse(summary.localizedCaseInsensitiveContains("downloaded file"), summary)
            XCTAssertFalse(summary.localizedCaseInsensitiveContains("assistant file"), summary)
        }
    }

    func testPlainTextModelAnswerUsesNeutralLocalHeadline() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            let baseResult = AlphaAskResult(
                kind: .userAsk,
                question: "What is FMLS?",
                scopeCaseID: nil,
                scopeLabel: "All work",
                selectedDocumentTitles: [],
                answerTitle: "Ross drafted this from your files",
                answerSections: [],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: "Answered from your files",
                needsReviewWarning: nil
            )
            let payload = model.matterAskPayload(
                from: AlphaLocalModelOutput(
                    rawText: "FMLS usually means a filing or case-listing system, but confirm the exact local court context before relying on it.",
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: [],
                    sourceRefs: []
                ),
                baseResult: model.localModelAnswerBaseResult(from: baseResult)
            )

            XCTAssertEqual(rossLocalized("ask_local_answered_locally_title"), payload?.headline)
            XCTAssertTrue(payload?.sections.first?.contains("FMLS") == true)
        }
    }

    func testAskRuntimeFailurePresentationExplainsRepairInsteadOfInvalidOutput() async {
        let model = await MainActor.run {
            AlphaRossModel(previewState: AlphaPersistedState.demoSeed())
        }

        await MainActor.run {
            let presentation = model.askRuntimeFailurePresentation(
                for: AlphaLocalModelOutput(
                    rawText: "",
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: ["Inference failed: llama sampler chain failed to initialize"],
                    sourceRefs: [],
                    errorCategory: "inference_failed"
                )
            )

            XCTAssertEqual("Private assistant needs repair", presentation?.title)
            XCTAssertEqual("Private assistant needs repair", presentation?.statusNote)
            XCTAssertTrue(presentation?.sections.joined(separator: " ").contains("Repair setup") == true)
            XCTAssertTrue(presentation?.sections.joined(separator: " ").contains("My assistant") == true)
            XCTAssertFalse(presentation?.sections.joined(separator: " ").contains("Private AI") == true)
            XCTAssertTrue(presentation?.needsReviewWarning?.contains("needs repair") == true)

            let unavailable = model.askRuntimeUnavailablePresentation()
            XCTAssertEqual("Private assistant could not answer", unavailable.title)
            XCTAssertEqual("Private assistant answer unavailable", unavailable.statusNote)
            XCTAssertTrue(unavailable.sections.joined(separator: " ").contains("did not return a usable response"))
            XCTAssertTrue(unavailable.needsReviewWarning?.contains("did not guess") == true)
        }
    }

    func testEmptyStateStartsAtOnboarding() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.empty())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let snapshot = await MainActor.run { model.persisted }
            XCTAssertEqual(.onboarding, snapshot.onboardingStage)
            XCTAssertNil(snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.isEmpty)
        }
    }

    func testCompletedStateWithoutAssistantRestoresSetupFlow() async throws {
        try await withRestoredStore { store in
            var state = AlphaPersistedState.seed()
            state.demoProfileSubject = nil
            state.onboardingStage = .completed
            state.settings.activeTier = nil
            state.installedPacks = []
            state.modelJobs = []
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let snapshot = await MainActor.run { model.persisted }
            XCTAssertEqual(.privateAIPack, snapshot.onboardingStage)
            XCTAssertNil(snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.isEmpty)
        }
    }

    @MainActor
    func testQuickUnlockKeepsWorkspaceCoveredUntilReturn() {
        let localAuth = RossLocalAuthStub()
        let controller = RossAuthController(
            canEvaluateDeviceUnlock: { localAuth.canEvaluate },
            biometryTypeProvider: { localAuth.biometryType },
            evaluateDeviceUnlock: localAuth.evaluate
        )
        let session = makeAuthSession()

        controller.phase = .signedIn(session)
        controller.quickUnlockEnabled = true

        controller.handleScenePhase(.inactive)
        XCTAssertTrue(controller.privacyShieldVisible)
        XCTAssertEqual(.signedIn(session), controller.phase)
        XCTAssertEqual(0, localAuth.evaluateCallCount)

        controller.handleScenePhase(.background)
        XCTAssertEqual(.signedIn(session), controller.phase)
        XCTAssertTrue(controller.privacyShieldVisible)
        XCTAssertEqual(0, localAuth.evaluateCallCount)

        controller.handleScenePhase(.active)
        XCTAssertEqual(.unlockRequired(session), controller.phase)
        XCTAssertTrue(controller.isUnlocking)
        XCTAssertTrue(controller.privacyShieldVisible)
        XCTAssertEqual(1, localAuth.evaluateCallCount)
    }

    @MainActor
    func testAutomaticQuickUnlockSuccessRestoresSignedInState() async {
        let localAuth = RossLocalAuthStub()
        let controller = RossAuthController(
            canEvaluateDeviceUnlock: { localAuth.canEvaluate },
            biometryTypeProvider: { localAuth.biometryType },
            evaluateDeviceUnlock: localAuth.evaluate
        )
        let session = makeAuthSession()

        controller.phase = .signedIn(session)
        controller.quickUnlockEnabled = true
        controller.handleScenePhase(.background)
        controller.handleScenePhase(.active)
        localAuth.finishNext(success: true)
        await Task.yield()

        XCTAssertEqual(.signedIn(session), controller.phase)
        XCTAssertFalse(controller.isUnlocking)
        XCTAssertFalse(controller.privacyShieldVisible)
        XCTAssertNil(controller.authErrorMessage)
    }

    @MainActor
    func testCancelledAutomaticQuickUnlockFallsBackToManualScreen() async {
        let localAuth = RossLocalAuthStub()
        let controller = RossAuthController(
            canEvaluateDeviceUnlock: { localAuth.canEvaluate },
            biometryTypeProvider: { localAuth.biometryType },
            evaluateDeviceUnlock: localAuth.evaluate
        )
        let session = makeAuthSession()

        controller.phase = .signedIn(session)
        controller.quickUnlockEnabled = true
        controller.handleScenePhase(.background)
        controller.handleScenePhase(.active)
        localAuth.finishNext(
            success: false,
            error: NSError(domain: LAError.errorDomain, code: LAError.Code.userCancel.rawValue)
        )
        await Task.yield()

        XCTAssertEqual(.unlockRequired(session), controller.phase)
        XCTAssertFalse(controller.isUnlocking)
        XCTAssertFalse(controller.privacyShieldVisible)
        XCTAssertNil(controller.authErrorMessage)
    }

    func testWebOnRequiresPreviewBeforeSearch() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let publicLawCalls = SendableBox(0)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in
                    publicLawCalls.value += 1
                    return [
                        AlphaPublicLawResult(
                            title: "Delay condonation and documented diligence",
                            citation: "(2024) 7 SCC 112",
                            snippet: "Diligence and chronology remain central to condonation review.",
                            sourceName: "Official source"
                        )
                    ]
                })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(question: "Find law on delay condonation", scopeCaseID: nil, webEnabled: true)
            }

            let preview = await MainActor.run { model.publicLawPreview }
            let statusBeforeConfirm = await MainActor.run { model.latestAskResult?.statusNote }
            XCTAssertNotNil(preview)
            XCTAssertEqual(alphaPublicLawReviewRequiredStatus(languageCode: "en"), statusBeforeConfirm)
            XCTAssertEqual(0, publicLawCalls.value)

            await model.confirmPendingPublicLawSearch()

            let resultCount = await MainActor.run { model.publicLawResults.count }
            let statusAfterConfirm = await MainActor.run { model.latestAskResult?.statusNote }
            let ledgerTitles = await MainActor.run { model.persisted.ledgerEntries.map(\.title) }
            XCTAssertEqual(1, publicLawCalls.value)
            XCTAssertEqual(1, resultCount)
            XCTAssertEqual(alphaPublicLawResultsStatus(languageCode: "en"), statusAfterConfirm)
            XCTAssertTrue(ledgerTitles.contains(rossLocalized("privacy_ledger_public_law_reviewed_title")))
            XCTAssertTrue(ledgerTitles.contains(rossLocalized("privacy_ledger_public_law_sent_title")))
        }
    }

    func testCancelPublicLawReviewPreventsNetworkCall() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let publicLawCalls = SendableBox(0)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in
                    publicLawCalls.value += 1
                    return []
                })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(question: "Find cases on interim injunction", scopeCaseID: nil, webEnabled: true)
                model.cancelPendingPublicLawSearch()
            }

            let preview = await MainActor.run { model.publicLawPreview }
            let results = await MainActor.run { model.publicLawResults }
            let latestPreview = await MainActor.run { model.latestAskResult?.publicLawPreview }
            let latestResult = await MainActor.run { model.latestAskResult }
            let storedTurn = await MainActor.run {
                model.persisted.cases
                    .first(where: { $0.id == alphaSharedWorkspaceID })?
                    .chatSessions
                    .flatMap(\.turns)
                    .last
            }
            XCTAssertNil(preview)
            XCTAssertNil(latestPreview)
            XCTAssertNil(latestResult)
            XCTAssertTrue(results.isEmpty)
            XCTAssertEqual(0, publicLawCalls.value)
            XCTAssertEqual(rossLocalized("legal_search_canceled_title"), storedTurn?.answerTitle)
            XCTAssertEqual(rossLocalized("legal_search_canceled_detail"), storedTurn?.answerSections.first)
            XCTAssertEqual(rossLocalized("canceled"), storedTurn?.statusNote)
        }
    }

    func testSanitizedPreviewStripsFakeSecrets() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(
                    question: "Find guidance for Raghav Fakepriv on 9876501234 using fakepriv@example.com and private-bundle.pdf in FAKE/123/2026",
                    scopeCaseID: nil,
                    webEnabled: true
                )
            }

            let preview = await MainActor.run { model.publicLawPreview }
            XCTAssertNotNil(preview)
            XCTAssertNil(preview?.query.range(of: "Raghav Fakepriv", options: .caseInsensitive))
            XCTAssertFalse(preview?.query.contains("9876501234") == true)
            XCTAssertNil(preview?.query.range(of: "fakepriv@example.com", options: .caseInsensitive))
            XCTAssertNil(preview?.query.range(of: "private-bundle.pdf", options: .caseInsensitive))
            XCTAssertNil(preview?.query.range(of: "FAKE/123/2026", options: .caseInsensitive))
        }
    }

    func testGenericMorningQuestionFallsBackToResearchAnchoredPublicLawPreview() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let caseID = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id
            }
            XCTAssertNotNil(caseID)

            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(
                    question: "What needs my attention today?",
                    scopeCaseID: caseID,
                    webEnabled: true
                )
            }

            let preview = await MainActor.run { model.publicLawPreview }
            XCTAssertNotNil(preview)
            XCTAssertTrue(preview?.query.range(of: "public law", options: .caseInsensitive) != nil)
            XCTAssertTrue(
                preview?.query.range(of: "court procedure", options: .caseInsensitive) != nil ||
                preview?.query.range(of: "filing compliance", options: .caseInsensitive) != nil ||
                preview?.query.range(of: "hearing dates", options: .caseInsensitive) != nil
            )
            XCTAssertNotEqual("order affidavit notice India", preview?.query.lowercased())
        }
    }

    func testSanitizedPreviewPreservesLegalCitationsAndTimeLimits() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(
                    question: "Order 39 Rules 1 and 2 CPC temporary injunction, Section 138 NI Act notice limitation, Section 482 CrPC quashing FIR, Article 226 Constitution of India writ mandamus",
                    scopeCaseID: nil,
                    webEnabled: true
                )
            }

            let preview = await MainActor.run { model.publicLawPreview }
            XCTAssertNotNil(preview)
            XCTAssertTrue(preview?.query.contains("Order 39 Rules 1 and 2 CPC") == true)
            XCTAssertTrue(preview?.query.contains("Section 138 NI Act") == true)
            XCTAssertTrue(preview?.query.contains("Section 482 CrPC") == true)
            XCTAssertTrue(preview?.query.contains("Article 226 Constitution of India") == true)

            await MainActor.run {
                model.submitAsk(
                    question: "delay filing written statement 120 days Commercial Courts Act",
                    scopeCaseID: nil,
                    webEnabled: true
                )
            }

            let deadlinePreview = await MainActor.run { model.publicLawPreview }
            XCTAssertTrue(deadlinePreview?.query.contains("120 days Commercial Courts Act") == true)
        }
    }

    func testConfirmedPublicLawSearchUsesApprovedPreviewQuery() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let sentQuery = SendableBox<String?>(nil)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { preview in
                    sentQuery.value = preview.query
                    return []
                })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(
                    question: "Order 39 Rules 1 and 2 CPC temporary injunction",
                    scopeCaseID: nil,
                    webEnabled: true
                )
            }

            let approvedQuery = await MainActor.run { model.publicLawPreview?.query }
            await model.confirmPendingPublicLawSearch()

            XCTAssertEqual(approvedQuery, sentQuery.value)
        }
    }

    func testMarkingMatterDateDoneDoesNotSilentlyInflateOpenTasks() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let snapshot = await MainActor.run { model.persisted }
            guard let caseID = snapshot.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id else {
                XCTFail("Missing demo matter")
                return
            }
            guard let dateID = await MainActor.run(body: { model.scheduledMatterDates(for: caseID).first?.id }) else {
                XCTFail("Missing scheduled matter date")
                return
            }

            let initialOpenTaskCount = await MainActor.run { model.openTaskCount(for: caseID) }
            let initialDateCount = await MainActor.run { model.scheduledMatterDates(for: caseID).count }

            await MainActor.run {
                model.setMatterDateStatus(caseId: caseID, dateId: dateID, status: .done)
            }

            let finalOpenTaskCount = await MainActor.run { model.openTaskCount(for: caseID) }
            let finalDateCount = await MainActor.run { model.scheduledMatterDates(for: caseID).count }

            XCTAssertEqual(initialOpenTaskCount, finalOpenTaskCount)
            XCTAssertEqual(initialDateCount - 1, finalDateCount)
        }
    }

    func testSanitizedPreviewRemovesMatterScopedWordingBeforeWebSearch() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.updateSettings { settings in
                    settings.requirePublicLawApproval = true
                }
                model.submitAsk(
                    question: "What should I do next for this matter about delay condonation and sufficient cause?",
                    scopeCaseID: nil,
                    webEnabled: true
                )
            }

            let preview = await MainActor.run { model.publicLawPreview }
            XCTAssertNotNil(preview)
            XCTAssertNil(preview?.query.range(of: "what should i", options: .caseInsensitive))
            XCTAssertNil(preview?.query.range(of: "this matter", options: .caseInsensitive))
            XCTAssertTrue(preview?.query.range(of: "delay condonation", options: .caseInsensitive) != nil)
            XCTAssertFalse(preview?.removed.contains(alphaPublicLawNoPrivateDataReason()) == true)
            XCTAssertTrue(preview?.removed.contains(alphaPublicLawPrivacyReason("case_detail_phrasing_and_private_drafting_cues")) == true)
        }
    }

    func testLocalAskReturnsSafeNotFoundAnswer() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.submitAsk(
                    question: "What does the blue suitcase near temple note say?",
                    scopeCaseID: nil,
                    webEnabled: false
                )
            }

            let answerTitle = await MainActor.run { model.latestAskResult?.answerTitle }
            let answerSections = await MainActor.run { model.latestAskResult?.answerSections }
            XCTAssertEqual("Private assistant not ready", answerTitle)
            XCTAssertEqual([
                "Open My assistant and set up a private assistant on this iPhone before asking legal questions.",
                "Ross did not generate a legal answer because the private assistant is not ready."
            ], answerSections)
        }
    }

    func testDockCommandAddsTaskWithoutTriggeringWebPreview() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let maybeCaseID = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id
            }
            let caseID = try XCTUnwrap(maybeCaseID)

            await model.submitDockInput(
                question: "add task prepare hearing note tomorrow",
                scopeCaseID: caseID,
                webEnabled: true
            )

            let latestResult = await MainActor.run { model.latestAskResult }
            let tasks = await MainActor.run { model.tasks(for: caseID) }
            let preview = await MainActor.run { model.publicLawPreview }

            XCTAssertTrue(tasks.contains(where: { $0.title == "prepare hearing note" }))
            XCTAssertEqual("Task added.", latestResult?.answerTitle)
            XCTAssertEqual("Saved locally", latestResult?.statusNote)
            XCTAssertNil(preview)
        }
    }

    func testDockCommandGuidanceUsesSelectedProductLanguage() async throws {
        let previousLanguageCode = rossSelectedLanguageCode()
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }
        rossSaveLanguageSelection(code: "hi")

        try await withRestoredStore { store in
            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }

            let taskGuidance = await MainActor.run {
                model.dockCommandAction(for: "add task on 1 May 2026")
            }
            guard case let .guidance(taskTitle, taskDetail) = taskGuidance else {
                return XCTFail("Expected missing task title guidance")
            }
            XCTAssertEqual(taskTitle, "Task title जोड़ें")
            XCTAssertTrue(taskDetail.contains("prepare hearing note"))

            let completeGuidance = await MainActor.run {
                model.dockCommandAction(for: "mark task done")
            }
            guard case let .guidance(completeTitle, _) = completeGuidance else {
                return XCTFail("Expected missing task name guidance")
            }
            XCTAssertEqual(completeTitle, "Task का नाम लिखें")

            let dateGuidance = await MainActor.run {
                model.dockCommandAction(for: "save date filing reminder")
            }
            guard case let .guidance(dateTitle, dateDetail) = dateGuidance else {
                return XCTFail("Expected missing date guidance")
            }
            XCTAssertEqual(dateTitle, "Date जोड़ें")
            XCTAssertTrue(dateDetail.contains("1 May 2026"))

            let chronologyCommand = await MainActor.run {
                model.dockCommandAction(for: "generate chronology")
            }
            guard case let .generateExport(_, chronologyLabel) = chronologyCommand else {
                return XCTFail("Expected chronology export command")
            }
            XCTAssertEqual(chronologyLabel, "कालक्रम")

            let hearingCommand = await MainActor.run {
                model.dockCommandAction(for: "generate hearing note")
            }
            guard case let .generateExport(_, hearingLabel) = hearingCommand else {
                return XCTFail("Expected hearing note export command")
            }
            XCTAssertEqual(hearingLabel, "सुनवाई नोट")

            let orderCommand = await MainActor.run {
                model.dockCommandAction(for: "generate order summary")
            }
            guard case let .generateExport(_, orderLabel) = orderCommand else {
                return XCTFail("Expected order summary export command")
            }
            XCTAssertEqual(orderLabel, "आदेश सारांश")

            let transcriptCommand = await MainActor.run {
                model.dockCommandAction(for: "generate transcript")
            }
            guard case let .generateExport(_, transcriptLabel) = transcriptCommand else {
                return XCTFail("Expected transcript export command")
            }
            XCTAssertEqual(transcriptLabel, rossLocalized("export_thread_transcript"))
        }
    }

    func testDockCommandAddsMatterDateToScopedMatter() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let maybeCaseID = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id
            }
            let caseID = try XCTUnwrap(maybeCaseID)

            await model.submitDockInput(
                question: "save next hearing on 1 May 2026",
                scopeCaseID: caseID,
                webEnabled: false
            )

            let savedDates = await MainActor.run { model.scheduledMatterDates(for: caseID) }
            let latestResult = await MainActor.run { model.latestAskResult }

            XCTAssertTrue(savedDates.contains(where: {
                $0.kind == .hearing &&
                    $0.title == "Next hearing" &&
                    Calendar.current.isDate($0.date, inSameDayAs: DateComponents(calendar: .current, year: 2026, month: 5, day: 1).date!)
            }))
            XCTAssertEqual("Date saved.", latestResult?.answerTitle)
        }
    }

    func testDockCommandSaveHearingRequiresMatterScope() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let initialDateCount = await MainActor.run {
                model.persisted.cases.flatMap(\.dates).count
            }

            await model.submitDockInput(
                question: "save next hearing on 1 May 2026",
                scopeCaseID: nil,
                webEnabled: true
            )

            let latestResult = await MainActor.run { model.latestAskResult }
            let finalDateCount = await MainActor.run {
                model.persisted.cases.flatMap(\.dates).count
            }
            let preview = await MainActor.run { model.publicLawPreview }

            XCTAssertEqual(initialDateCount, finalDateCount)
            XCTAssertEqual("Choose a matter first", latestResult?.answerTitle)
            XCTAssertEqual("No change made", latestResult?.statusNote)
            XCTAssertNil(preview)
        }
    }

    func testUnsupportedDockCommandMakesNoMatterMutation() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let maybeCaseID = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id
            }
            let caseID = try XCTUnwrap(maybeCaseID)
            let initialOpenTaskCount = await MainActor.run { model.openTaskCount(for: caseID) }

            await model.submitDockInput(
                question: "complete task \(UUID().uuidString)",
                scopeCaseID: caseID,
                webEnabled: false
            )

            let finalOpenTaskCount = await MainActor.run { model.openTaskCount(for: caseID) }
            let latestResult = await MainActor.run { model.latestAskResult }

            XCTAssertEqual(initialOpenTaskCount, finalOpenTaskCount)
            XCTAssertEqual("Task not found.", latestResult?.answerTitle)
            XCTAssertEqual("No change made", latestResult?.statusNote)
        }
    }

    func testDockCommandGeneratesScopedExport() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let maybeCaseID = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })?.id
            }
            let caseID = try XCTUnwrap(maybeCaseID)

            await model.submitDockInput(
                question: "prepare hearing note",
                scopeCaseID: caseID,
                webEnabled: false
            )

            let exports = await MainActor.run { model.persisted.exports.filter { $0.caseId == caseID } }
            let latestResult = await MainActor.run { model.latestAskResult }

            XCTAssertFalse(exports.isEmpty)
            XCTAssertEqual("Hearing note ready", latestResult?.answerTitle)
            XCTAssertEqual("Draft ready", latestResult?.statusNote)
        }
    }

    func testIgnoredFieldDoesNotAppearInExportDraftBody() async throws {
        try await withRestoredStore { store in
            var state = AlphaPersistedState.demoSeed()
            guard
                let caseIndex = state.cases.firstIndex(where: { $0.title == "Demo Matter: Sharma v. Rana" }),
                let documentIndex = state.cases[caseIndex].documents.indices.first
            else {
                XCTFail("Missing demo matter")
                return
            }

            let caseID = state.cases[caseIndex].id
            let documentID = state.cases[caseIndex].documents[documentIndex].id
            let uniqueValue = "Ignored unique export field"
            let sourceRef = AlphaSourceRef(
                caseId: caseID,
                documentId: documentID,
                documentTitle: state.cases[caseIndex].documents[documentIndex].title,
                pageNumber: 1,
                textSnippet: "Ignored unique export field source"
            )
            let field = AlphaExtractedLegalField(
                caseId: caseID,
                documentId: documentID,
                fieldType: .relief,
                label: "Relief",
                value: uniqueValue,
                sourceRefs: [sourceRef],
                confidence: 0.52,
                extractionMode: .basic,
                extractionPass: .regex,
                needsReview: true
            )
            state.cases[caseIndex].documents[documentIndex].extractedFields.insert(field, at: 0)
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.ignoreExtractedField(caseId: caseID, documentId: documentID, fieldId: field.id)
            }

            let exportLines = await MainActor.run {
                let caseMatter = model.persisted.cases.first(where: { $0.id == caseID })
                return model.exportBodyLines(kind: "case_note", caseMatter: caseMatter)
            }

            XCTAssertFalse(exportLines.joined(separator: "\n").contains(uniqueValue))
        }
    }

    @MainActor
    func testExportDraftMissingSourceFallbackFollowsSelectedLanguage() {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        let caseID = UUID()
        let documentID = UUID()
        let sourceRef = AlphaSourceRef(
            caseId: caseID,
            documentId: documentID,
            documentTitle: "Order",
            pageNumber: 1,
            textSnippet: "Order lists the next hearing date."
        )
        let field = AlphaExtractedLegalField(
            caseId: caseID,
            documentId: documentID,
            fieldType: .date,
            label: "Hearing date",
            value: "12 March 2026",
            sourceRefs: [],
            confidence: 0.81,
            extractionMode: .basic,
            extractionPass: .regex,
            needsReview: false
        )
        let matter = AlphaCaseMatter(
            id: caseID,
            title: "Hindi export matter",
            forum: "District Court",
            stage: .reserved,
            summary: "Summary",
            issueHighlights: [],
            evidenceNotes: [],
            draftTasks: [],
            documents: [
                AlphaCaseDocument(
                    id: documentID,
                    title: "Order",
                    fileName: "order.pdf",
                    kind: .pdf,
                    storedRelativePath: "order.pdf",
                    importedAt: .now,
                    pageCount: 1,
                    ocrStatus: .nativeText,
                    indexingStatus: .indexed,
                    pages: [
                        AlphaDocumentPage(pageNumber: 1, snippet: "Order lists the next hearing date.")
                    ],
                    extractedFields: [field]
                )
            ],
            sourceRefs: [],
            chatSessions: [
                AlphaChatSession(
                    turns: [
                        AlphaChatTurn(
                            askedAt: Date(timeIntervalSince1970: 1_713_700_000),
                            question: "What is the next date?",
                            answerTitle: "Answered from your files",
                            answerSections: ["The matter is listed on 12 March 2026."],
                            sourceRefs: [sourceRef]
                        )
                    ]
                )
            ]
        )
        var state = AlphaPersistedState.empty()
        state.cases = [matter]
        let model = AlphaRossModel(previewState: state)
        let emptyMatter = AlphaCaseMatter(
            id: UUID(),
            title: "Empty Hindi export matter",
            forum: "District Court",
            stage: .intake,
            summary: "Summary",
            issueHighlights: [],
            evidenceNotes: [],
            draftTasks: [],
            documents: [],
            sourceRefs: []
        )

        let exportText = model.exportBodyLines(kind: "chronology_report", caseMatter: matter).joined(separator: "\n")
        let emptyChronologyText = model.exportBodyLines(kind: "chronology_report", caseMatter: emptyMatter).joined(separator: "\n")
        let caseNoteText = model.exportBodyLines(kind: "case_note", caseMatter: matter).joined(separator: "\n")
        let emptyCaseNoteText = model.exportBodyLines(kind: "case_note", caseMatter: emptyMatter).joined(separator: "\n")
        let chatTranscriptText = model.exportBodyLines(kind: "chat_transcript", caseMatter: matter).joined(separator: "\n")

        XCTAssertTrue(exportText.contains("Draft - कृपया review करें"), exportText)
        XCTAssertTrue(exportText.contains("Advocate review के लिए locally generated."), exportText)
        XCTAssertTrue(emptyChronologyText.contains("- अभी verified chronology candidates नहीं मिले."), emptyChronologyText)
        XCTAssertTrue(exportText.contains("- अभी linked source नहीं"), exportText)
        XCTAssertTrue(caseNoteText.contains("Court: नहीं मिला"), caseNoteText)
        XCTAssertTrue(caseNoteText.contains("- कोई pending review fields नहीं."), caseNoteText)
        XCTAssertTrue(emptyCaseNoteText.contains("- अभी imported documents नहीं हैं."), emptyCaseNoteText)
        XCTAssertTrue(chatTranscriptText.contains("सवाल: What is the next date?"), chatTranscriptText)
        XCTAssertTrue(chatTranscriptText.contains("जवाब: The matter is listed on 12 March 2026."), chatTranscriptText)
        XCTAssertTrue(chatTranscriptText.contains("स्रोत: Order · p. 1"), chatTranscriptText)
        XCTAssertFalse(exportText.contains("Draft — please review"), exportText)
        XCTAssertFalse(exportText.contains("Generated locally for advocate review."), exportText)
        XCTAssertFalse(exportText.contains("No source references available yet."), exportText)
        XCTAssertFalse(exportText.contains("Source pending"), exportText)
        XCTAssertFalse(caseNoteText.contains("Not found"), caseNoteText)
        XCTAssertFalse(emptyCaseNoteText.contains("No imported documents yet."), emptyCaseNoteText)
        XCTAssertFalse(chatTranscriptText.contains("Q: What is the next date?"), chatTranscriptText)
        XCTAssertFalse(chatTranscriptText.contains("A: The matter is listed on 12 March 2026."), chatTranscriptText)
        XCTAssertFalse(chatTranscriptText.contains("Sources: Order · p. 1"), chatTranscriptText)
    }

    func testDockCommandCreatesTasksFromSelectedDocument() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let identifiers = await MainActor.run {
                let caseMatter = model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })
                return (caseMatter?.id, caseMatter?.documents.first?.id)
            }
            let caseID = try XCTUnwrap(identifiers.0)
            let documentID = try XCTUnwrap(identifiers.1)

            await MainActor.run {
                model.setSelectedAskDocumentIDs([documentID], for: caseID)
            }

            let initialTaskCount = await MainActor.run { model.tasks(for: caseID).count }
            await model.submitDockInput(
                question: "create tasks from this document",
                scopeCaseID: caseID,
                webEnabled: false
            )

            let finalTaskCount = await MainActor.run { model.tasks(for: caseID).count }
            let latestResult = await MainActor.run { model.latestAskResult }

            XCTAssertTrue(finalTaskCount >= initialTaskCount)
            XCTAssertNotNil(latestResult)
            XCTAssertTrue(["Tasks added.", "No new tasks needed."].contains(latestResult?.answerTitle ?? ""))
        }
    }

    func testDockCommandCanRerunSelectedDocumentReview() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let identifiers = await MainActor.run {
                let caseMatter = model.persisted.cases.first(where: { $0.title == "Demo Matter: Sharma v. Rana" })
                return (caseMatter?.id, caseMatter?.documents.first?.id)
            }
            let caseID = try XCTUnwrap(identifiers.0)
            let documentID = try XCTUnwrap(identifiers.1)

            await MainActor.run {
                model.setSelectedAskDocumentIDs([documentID], for: caseID)
            }

            await model.submitDockInput(
                question: "review this document",
                scopeCaseID: caseID,
                webEnabled: false
            )

            let latestResult = await MainActor.run { model.latestAskResult }
            XCTAssertEqual("Review updated.", latestResult?.answerTitle)
            XCTAssertEqual("Review updated", latestResult?.statusNote)
        }
    }

    func testDockCommandResultsFollowSelectedAppLanguage() async throws {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            await model.submitDockInput(
                question: "review this document",
                scopeCaseID: nil,
                webEnabled: false
            )

            let latestResult = await MainActor.run { model.latestAskResult }
            XCTAssertEqual("पहले document चुनें", latestResult?.answerTitle)
            XCTAssertEqual("कोई बदलाव नहीं", latestResult?.statusNote)
            XCTAssertTrue(latestResult?.answerSections.joined(separator: " ").contains("file tag करें") == true)

            await model.submitDockInput(
                question: "add task Prepare translated chronology",
                scopeCaseID: nil,
                webEnabled: false
            )

            let taskResult = await MainActor.run { model.latestAskResult }
            XCTAssertEqual("Task added.", taskResult?.answerTitle)
            XCTAssertEqual("locally saved", taskResult?.statusNote)
            XCTAssertTrue(taskResult?.answerSections.joined(separator: " ").contains("इस device पर added हुआ") == true)
        }
    }

    func testDockQuestionStillFallsBackToStandardAskFlow() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            await model.submitDockInput(
                question: "What needs my attention today?",
                scopeCaseID: nil,
                webEnabled: false
            )

            let latestResult = await MainActor.run { model.latestAskResult }
            XCTAssertEqual(.userAsk, latestResult?.kind)
            XCTAssertEqual("Private assistant not ready", latestResult?.answerTitle)
            XCTAssertEqual("Private assistant setup required", latestResult?.statusNote)
        }
    }

    func testReviewCountUpdatesAfterFieldCorrection() async throws {
        try await withRestoredStore { store in
            let caseID = UUID()
            let documentID = UUID()
            let fieldID = UUID()
            let sourceRef = AlphaSourceRef(
                caseId: caseID,
                documentId: documentID,
                documentTitle: "Order",
                pageNumber: 1,
                textSnippet: "Listed on 15/05/2026"
            )
            var state = AlphaPersistedState.seed()
            state.onboardingStage = .completed
            state.selectedTab = .home
            state.settings = .default
            state.cases = [
                    AlphaCaseMatter(
                        id: caseID,
                        title: "Review Matter",
                        forum: "Delhi High Court",
                        stage: .pleadings,
                        summary: "summary",
                        issueHighlights: [],
                        evidenceNotes: [],
                        draftTasks: [],
                        documents: [
                            AlphaCaseDocument(
                                id: documentID,
                                title: "Order",
                                fileName: "order.pdf",
                                kind: .pdf,
                                storedRelativePath: "docs/order.pdf",
                                importedAt: .now,
                                pageCount: 1,
                                ocrStatus: .indexed,
                                indexingStatus: .indexed,
                                pages: [
                                    AlphaDocumentPage(pageNumber: 1, snippet: "Listed on 15/05/2026")
                                ],
                                extractedFields: [
                                    AlphaExtractedLegalField(
                                        id: fieldID,
                                        caseId: caseID,
                                        documentId: documentID,
                                        fieldType: .nextDate,
                                        label: "Next date",
                                        value: "15/05/2026",
                                        sourceRefs: [sourceRef],
                                        confidence: 0.52,
                                        extractionMode: .caseAssociate,
                                        extractionPass: .llmExtract,
                                        needsReview: true
                                    )
                                ]
                            )
                        ],
                        sourceRefs: [sourceRef]
                    )
                ]
            state.tasks = []
            state.ledgerEntries = []
            state.modelJobs = []
            state.installedPacks = []
            state.lastModelCatalogRefresh = nil
            state.publicLawCache = []
            state.publicLawDraft = nil
            state.publicLawPreview = nil
            state.publicLawResults = nil
            state.exports = []

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.persisted = state
            }

            let beforeCount = await MainActor.run { model.reviewQueue(caseId: caseID).count }
            XCTAssertEqual(1, beforeCount)

            await MainActor.run {
                model.applyFieldCorrection(caseId: caseID, documentId: documentID, fieldId: fieldID, newValue: "15/05/2026")
            }

            let afterCount = await MainActor.run { model.reviewQueue(caseId: caseID).count }
            let nextHearing = await MainActor.run { model.persisted.cases.first?.nextHearing }
            let memoryUpdates = await MainActor.run { model.persisted.cases.first?.caseMemoryUpdates.count ?? 0 }

            XCTAssertEqual(0, afterCount)
            XCTAssertNotNil(nextHearing)
            XCTAssertTrue(memoryUpdates > 0)
        }
    }

    func testFinishPackSetupUsesExplicitlySelectedNonRecommendedTier() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            let recommendedTier = await MainActor.run { model.recommendedOnDeviceTier() }
            let selectedTier = assistantSetupRegressionTier(recommendedTier: recommendedTier)

            await MainActor.run {
                model.selectedTier = selectedTier
                model.finishPackSetup()
            }

            let snapshot = try await waitForAssistantSetupState(model: model, tier: selectedTier)
            let hasAssistantSetupState = snapshot.modelJobs.contains(where: { $0.tier == selectedTier })
                || snapshot.installedPacks.contains(where: { $0.tier == selectedTier })

            XCTAssertNotEqual(selectedTier, recommendedTier)
            XCTAssertEqual(snapshot.settings.activeTier, selectedTier)
            XCTAssertEqual(snapshot.onboardingStage, .completed)
            XCTAssertEqual(snapshot.selectedTab, .home)
            XCTAssertTrue(hasAssistantSetupState)
            XCTAssertFalse(snapshot.modelJobs.contains(where: { $0.tier == recommendedTier }))
            XCTAssertFalse(snapshot.installedPacks.contains(where: { $0.tier == recommendedTier }))
        }
    }

    func testAssistantSetupCanUseExplicitDevelopmentArtifactInTestHarness() async throws {
        rossSetBackendBaseURLOverride("http://127.0.0.1:9")
        defer { rossSetBackendBaseURLOverride(nil) }

        try await withRestoredStore { store in
            var state = AlphaPersistedState.seed()
            state.installedPacks = []
            state.modelJobs = []
            state.settings.activeTier = nil
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await model.startPackDownload(for: .caseAssociate, mobileAllowed: true)

            let snapshot = await MainActor.run { model.persisted }
            let installedPack = snapshot.installedPacks.first { $0.tier == .caseAssociate }
            let installedJob = snapshot.modelJobs.first { $0.tier == .caseAssociate }

            XCTAssertNotNil(installedPack)
            if let runtimeMode = installedPack?.runtimeMode {
                XCTAssertTrue([.appleFoundationModels, .deterministicDev].contains(runtimeMode))
            }
            XCTAssertEqual(installedJob?.state, .installed)
            XCTAssertEqual(snapshot.settings.activeTier, .caseAssociate)
        }
    }

    func testRetryAssistantSetupClearsStaleResumeProgressBeforeRestart() async throws {
        rossSetBackendBaseURLOverride("http://127.0.0.1:9")
        defer { rossSetBackendBaseURLOverride(nil) }

        try await withRestoredStore { store in
            let artifact = alphaAssistantModelArtifact(for: .caseAssociate)
            let job = AlphaModelDownloadJob(
                sessionId: "retry-stale-resume",
                packId: artifact.packId,
                tier: .caseAssociate,
                state: .pausedUser,
                networkPolicy: .wifiOnly,
                bytesDownloaded: 99_000_000,
                totalBytes: artifact.sizeBytes,
                checksumSha256: artifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                failureReason: "Previous retry could not continue.",
                resumeDataRelativePath: "model-resume-data/missing-\(UUID().uuidString).resume"
            )
            var state = AlphaPersistedState.seed()
            state.installedPacks = []
            state.modelJobs = [job]
            state.settings.activeTier = nil
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await model.startPackDownload(for: .caseAssociate, mobileAllowed: false, existingJobID: job.id)

            let snapshot = await MainActor.run { model.persisted }
            let restartedJob = snapshot.modelJobs.first { $0.id == job.id }
            XCTAssertNil(restartedJob?.resumeDataRelativePath)
            XCTAssertNil(restartedJob?.failureReason)
            XCTAssertEqual(restartedJob?.state, .installed)
            XCTAssertEqual(restartedJob?.bytesDownloaded, restartedJob?.totalBytes)
        }
    }

    func testLaunchRecoveryPausesActiveDownloadedModelAfterUnfinishedValidation() async throws {
        let startupValidationKey = "ross.private_ai.startup_validation_started_at"
        let model = await MainActor.run {
            AlphaRossModel()
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: startupValidationKey)
        defer { UserDefaults.standard.removeObject(forKey: startupValidationKey) }

        let pack = AlphaInstalledModelPack(
            packId: "gemma-4-e4b-q4",
            tier: .caseAssociate,
            installPath: "model-packs/case_associate/gemma-4-e4b-q4.gguf",
            checksumSha256: String(repeating: "b", count: 64),
            artifactKind: "local_model_artifact",
            runtimeMode: .llamaCppGguf,
            developmentOnly: false,
            checksumVerified: true,
            isActive: true
        )
        var state = AlphaPersistedState.seed()
        state.installedPacks = [pack]
        state.modelJobs = [
            AlphaModelDownloadJob(
                sessionId: "installed-pack",
                packId: pack.packId,
                tier: pack.tier,
                state: .installed,
                networkPolicy: .wifiOnly,
                bytesDownloaded: 1,
                totalBytes: 1,
                checksumSha256: pack.checksumSha256,
                artifactKind: pack.artifactKind,
                runtimeMode: pack.runtimeMode,
                developmentOnly: false
            )
        ]
        state.settings.activeTier = .caseAssociate

        let normalized = await MainActor.run {
            model.normalizeLoadedState(state)
        }

        XCTAssertNil(normalized.settings.activeTier)
        XCTAssertFalse(normalized.installedPacks.first?.isActive ?? true)
        XCTAssertTrue(normalized.ledgerEntries.contains { $0.title == "Assistant paused" })
        let pausedEntry = normalized.ledgerEntries.first { $0.title == "Assistant paused" }
        XCTAssertTrue(pausedEntry?.detail.contains("assistant setup file") == true)
        XCTAssertTrue(pausedEntry?.detail.contains("My assistant") == true)
        XCTAssertTrue(pausedEntry?.detail.contains("Repair setup") == true)
        XCTAssertFalse(pausedEntry?.detail.localizedCaseInsensitiveContains("downloaded assistant file") == true)
        XCTAssertTrue(pausedEntry?.detail.contains("this device") == true)
        XCTAssertFalse(pausedEntry?.detail.localizedCaseInsensitiveContains("Settings") == true)
    }

    func testModelResumeDataPersistsLoadsAndRemovesAcrossStoreCalls() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let jobID = UUID()
            let resumeData = Data("partial model download resume blob".utf8)

            let relativePath = try await store.saveModelResumeData(resumeData, for: jobID)
            let loaded = try await store.loadModelResumeData(relativePath: relativePath)
            await store.removeModelResumeData(relativePath: relativePath)
            let removed = try await store.loadModelResumeData(relativePath: relativePath)

            XCTAssertTrue(relativePath.hasSuffix("\(jobID.uuidString).resume"))
            XCTAssertEqual(loaded, resumeData)
            XCTAssertNil(removed)
        }
    }

    func testModelResumeDataSweepKeepsOnlyReferencedPaths() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let keptPath = try await store.saveModelResumeData(Data("keep".utf8), for: UUID())
            let stalePath = try await store.saveModelResumeData(Data("stale".utf8), for: UUID())

            await store.sweepModelResumeData(keeping: [keptPath])

            let kept = try await store.loadModelResumeData(relativePath: keptPath)
            let stale = try await store.loadModelResumeData(relativePath: stalePath)
            XCTAssertEqual(kept, Data("keep".utf8))
            XCTAssertNil(stale)
        }
    }

    func testRemovingDownloadedPackArtifactAlsoRemovesManifest() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let relativePath = "model-packs/quick_start/broken-local.gguf"
            let artifactURL = alphaAbsoluteURL(for: relativePath)
            let manifestURL = artifactURL.deletingPathExtension().appendingPathExtension("manifest.json")
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("bad local model".utf8).write(to: artifactURL)
            try Data("bad manifest".utf8).write(to: manifestURL)

            await store.removeDownloadedPackArtifact(relativePath: relativePath)

            XCTAssertFalse(FileManager.default.fileExists(atPath: artifactURL.path()))
            XCTAssertFalse(FileManager.default.fileExists(atPath: manifestURL.path()))
        }
    }

    func testRemoveAllDownloadedModelFilesDeletesArtifactsResumeDataAndClearsStaleInstalledState() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let artifact = alphaAssistantModelArtifact(for: .quickStart)
            let artifactPath = "model-packs/quick_start/delete-all-local.gguf"
            let artifactURL = alphaAbsoluteURL(for: artifactPath)
            let manifestURL = artifactURL.deletingPathExtension().appendingPathExtension("manifest.json")
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("downloaded local assistant".utf8).write(to: artifactURL)
            try Data("manifest".utf8).write(to: manifestURL)

            let jobID = UUID()
            let resumePath = try await store.saveModelResumeData(Data("resume data".utf8), for: jobID)
            var state = AlphaPersistedState.seed()
            state.installedPacks = [
                AlphaInstalledModelPack(
                    packId: artifact.packId,
                    tier: .quickStart,
                    installPath: artifactPath,
                    checksumSha256: String(repeating: "a", count: 64),
                    artifactKind: "local_model_artifact",
                    runtimeMode: .llamaCppGguf,
                    developmentOnly: false,
                    checksumVerified: true,
                    isActive: true
                )
            ]
            state.modelJobs = [
                AlphaModelDownloadJob(
                    id: jobID,
                    sessionId: "delete-all",
                    packId: artifact.packId,
                    tier: .quickStart,
                    state: .pausedUser,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: 4096,
                    totalBytes: artifact.sizeBytes,
                    checksumSha256: String(repeating: "a", count: 64),
                    artifactKind: "local_model_artifact",
                    runtimeMode: .llamaCppGguf,
                    developmentOnly: false,
                    resumeDataRelativePath: resumePath
                )
            ]
            state.settings.activeTier = .quickStart
            state.modelUpdateCandidates = [
                AlphaModelUpdateCandidate(
                    tier: .quickStart,
                    installedPackId: artifact.packId,
                    availablePackId: "new-pack",
                    availableSizeBytes: artifact.sizeBytes
                )
            ]
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.removeAllDownloadedModelFiles()
            }

            let snapshot = await MainActor.run { model.persisted }
            XCTAssertTrue(snapshot.installedPacks.isEmpty)
            XCTAssertFalse(snapshot.modelJobs.contains { $0.tier == .quickStart })
            XCTAssertNil(snapshot.settings.activeTier)
            XCTAssertEqual(snapshot.modelUpdateCandidates ?? [], [])
            XCTAssertEqual(snapshot.ledgerEntries.first?.title, "Assistant setup removed")
            XCTAssertFalse(snapshot.ledgerEntries.first?.detail.localizedCaseInsensitiveContains("downloaded private assistant files") == true)

            try await eventually(timeoutNanoseconds: 2_000_000_000) {
                let resumeData = try? await store.loadModelResumeData(relativePath: resumePath)
                return !FileManager.default.fileExists(atPath: artifactURL.path()) &&
                    !FileManager.default.fileExists(atPath: manifestURL.path()) &&
                    resumeData == nil
            }
        }
    }

    func testRecoveredDownloadedPackRequiresPinnedCatalogChecksumMatch() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let artifact = alphaAssistantModelArtifact(for: .quickStart)
            let relativePath = "model-packs/quick_start/\(artifact.fileName)"
            let artifactURL = alphaAbsoluteURL(for: relativePath)
            let manifestURL = artifactURL.deletingPathExtension().appendingPathExtension("manifest.json")
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try makeSparseFile(at: artifactURL, bytes: artifact.sizeBytes)
            try? FileManager.default.removeItem(at: manifestURL)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }

            let recovered = await MainActor.run {
                model.recoveredInstalledPackFromDisk(tier: .quickStart)
            }

            XCTAssertNil(recovered)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let manifest = AlphaModelArtifactManifest(
                packId: artifact.packId,
                tier: .quickStart,
                fileName: artifact.fileName,
                relativePath: relativePath,
                checksumSha256: "",
                bytes: artifact.sizeBytes,
                verifiedAt: .now
            )
            try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

            let recoveredWithBlankManifestChecksum = await MainActor.run {
                model.recoveredInstalledPackFromDisk(tier: .quickStart)
            }

            XCTAssertNil(recoveredWithBlankManifestChecksum)

            await store.removeAllModelArtifacts()
        }
    }

    func testInstalledPackUsabilityRejectsSizeOnlyAssistantVerification() async throws {
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let artifact = alphaAssistantModelArtifact(for: .quickStart)
            let relativePath = "model-packs/quick_start/\(artifact.fileName)"
            let artifactURL = alphaAbsoluteURL(for: relativePath)
            try FileManager.default.createDirectory(
                at: artifactURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try makeSparseFile(at: artifactURL, bytes: artifact.sizeBytes)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }

            let sizeOnlyPack = AlphaInstalledModelPack(
                packId: artifact.packId,
                tier: .quickStart,
                installPath: relativePath,
                checksumSha256: "catalog-size:\(artifact.fileName):\(artifact.sizeBytes)",
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            let arbitraryTokenPack = AlphaInstalledModelPack(
                packId: artifact.packId,
                tier: .quickStart,
                installPath: relativePath,
                checksumSha256: "downloaded-local-assistant",
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            let catalogChecksumPack = AlphaInstalledModelPack(
                packId: artifact.packId,
                tier: .quickStart,
                installPath: relativePath,
                checksumSha256: artifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )

            let sizeOnlyUsable = await MainActor.run { model.installedModelPackFileIsUsable(sizeOnlyPack) }
            let arbitraryTokenUsable = await MainActor.run { model.installedModelPackFileIsUsable(arbitraryTokenPack) }
            let catalogChecksumUsable = await MainActor.run { model.installedModelPackFileIsUsable(catalogChecksumPack) }

            XCTAssertFalse(sizeOnlyUsable)
            XCTAssertFalse(arbitraryTokenUsable)
            XCTAssertTrue(catalogChecksumUsable)

            await store.removeAllModelArtifacts()
        }
    }

    func testResumeJobClearsStaleResumeDataAndRecordsRestart() async throws {
        rossSaveLanguageSelection(code: "te")
        try await withRestoredStore { store in
            await store.removeAllModelArtifacts()
            let artifact = alphaAssistantModelArtifact(for: .quickStart)
            let job = AlphaModelDownloadJob(
                sessionId: "stale-resume",
                packId: artifact.packId,
                tier: .quickStart,
                state: .pausedUser,
                networkPolicy: .wifiOnly,
                bytesDownloaded: 512,
                totalBytes: artifact.sizeBytes,
                checksumSha256: artifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                resumeDataRelativePath: "model-resume-data/missing-\(UUID().uuidString).resume"
            )
            var state = AlphaPersistedState.empty()
            state.modelJobs = [job]
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.resumeJob(job)
            }
            try await Task.sleep(for: .milliseconds(350))

            let snapshot = await MainActor.run { model.persisted }
            let restartedJob = snapshot.modelJobs.first(where: { $0.id == job.id })
            XCTAssertNil(restartedJob?.resumeDataRelativePath)
            XCTAssertTrue(snapshot.ledgerEntries.contains {
                $0.title == "Assistant download resume restarted" &&
                $0.detail.localizedCaseInsensitiveContains("assistant download") &&
                $0.detail.contains("Case files ఏవీ చదవబడలేదు") &&
                !$0.detail.localizedCaseInsensitiveContains("model download") &&
                $0.purpose == .model_download &&
                $0.payloadClass == .no_case_data
            })
        }
    }

    func testLocalSmokeUnavailableReportUsesAssistantLanguage() async {
        rossSaveLanguageSelection(code: "hi")
        let model = await MainActor.run {
            AlphaRossModel()
        }

        await MainActor.run {
            model.runLocalInferenceSmoke()
        }
        try? await Task.sleep(for: .milliseconds(120))

        let report = await MainActor.run { model.localInferenceSmokeReport }
        XCTAssertEqual(report?.ran, false)
        XCTAssertEqual(report?.message, "Private assistant अभी इस device पर unavailable है।")
        XCTAssertFalse(report?.message.localizedCaseInsensitiveContains("real local inference") == true)
    }

    func testPrivateAssistantSampleCheckReportUsesProductLanguage() async throws {
        rossSetBackendBaseURLOverride("http://127.0.0.1:9")
        defer { rossSetBackendBaseURLOverride(nil) }

        try await withRestoredStore { store in
            var state = AlphaPersistedState.seed()
            state.installedPacks = []
            state.modelJobs = []
            state.settings.activeTier = nil
            state.exports = []
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await model.startPackDownload(for: .caseAssociate, mobileAllowed: true)
            await MainActor.run {
                model.runLocalInferenceSmoke()
            }

            try await eventually(timeoutNanoseconds: 2_000_000_000) {
                await MainActor.run {
                    model.localInferenceSmokeReport?.ran == true
                }
            }

            let report = await MainActor.run { model.localInferenceSmokeReport }
            let exportTitle = await MainActor.run { model.persisted.exports.first?.title }
            XCTAssertEqual(report?.message, rossLocalized("private_assistant_sample_file_check_completed_private"))
            XCTAssertEqual(exportTitle, rossLocalized("private_assistant_sample_file_check_report_title"))

            let visibleCopy = [report?.message, exportTitle].compactMap(\.self).joined(separator: "\n")
            XCTAssertTrue(visibleCopy.localizedCaseInsensitiveContains("private assistant"))
            XCTAssertTrue(visibleCopy.localizedCaseInsensitiveContains("sample file"))
            XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("local inference smoke"))
            XCTAssertFalse(visibleCopy.localizedCaseInsensitiveContains("real local inference"))
        }
    }

    func testAssistantDownloadFailureMessagesUseProductLanguage() async {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "en")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        struct TechnicalLocalizedDownloadError: LocalizedError {
            var errorDescription: String? {
                "Model provider checksum validation failed in RossAlphaPack runtime."
            }
        }

        let messages = await MainActor.run {
            let model = AlphaRossModel()
            return [
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)),
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)),
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)),
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: -123_456)),
                model.assistantDownloadFailureMessage(NSError(domain: "RossAlphaPack", code: 99)),
                model.assistantDownloadFailureMessage(NSError(domain: "RossAlphaPack", code: 2, userInfo: [NSLocalizedDescriptionKey: "Checksum verification failed."])),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.preflightMissingSize),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.preflightSizeMismatch(expected: 3_020_052_224, reported: 3_021_000_000)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.preflightNotResumable),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.preflightChecksumMismatch(catalog: "abc", provider: "def")),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.rangeProbeInvalidStatus(200)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.rangeProbeInvalidLength(expected: 256, received: 128)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.rangeProbeInvalidContentRange("bytes 0-10/*")),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.insufficientStorage(requiredGB: 12, availableGB: 3)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.missingDownloadedFile),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.pausedByUser),
                model.assistantDownloadFailureMessage(TechnicalLocalizedDownloadError())
            ]
        }

        XCTAssertFalse(messages.isEmpty)
        for message in messages {
            XCTAssertTrue(
                message.localizedCaseInsensitiveContains("assistant download") ||
                    message.localizedCaseInsensitiveContains("assistant setup"),
                message
            )
            XCTAssertFalse(message.localizedCaseInsensitiveContains("model download"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("runtime"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("artifact"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("checksum"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("NSURLErrorDomain"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("RossAlphaPack"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("provider"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("catalog"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("HTTP"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("Content-Range"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("bytes"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("saved position"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("Error 99"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("downloaded assistant file"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("private assistant file"), message)
        }

        let hindiMessages = await MainActor.run {
            rossSaveLanguageSelection(code: "hi")
            let model = AlphaRossModel()
            return [
                model.assistantDownloadFailureMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.preflightMissingSize),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.insufficientStorage(requiredGB: 12, availableGB: 3)),
                model.assistantDownloadFailureMessage(AlphaAssistantDownloadError.missingDownloadedFile)
            ]
        }

        XCTAssertTrue(hindiMessages[0].contains("नहीं पहुँच"))
        XCTAssertTrue(hindiMessages[1].contains("confirm नहीं"))
        XCTAssertTrue(hindiMessages[2].contains("12 GB"))
        XCTAssertTrue(hindiMessages[3].contains("Repair setup"))
        for message in hindiMessages {
            XCTAssertFalse(message.localizedCaseInsensitiveContains("NSURLErrorDomain"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("checksum"), message)
            XCTAssertFalse(message.localizedCaseInsensitiveContains("artifact"), message)
        }
    }

    func testAssistantDownloadRestartsWhenSavedResumeDataCannotContinue() async {
        let restartableErrors = await MainActor.run {
            let model = AlphaRossModel()
            return [
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeRawData)),
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeContentData)),
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)),
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
            ]
        }

        XCTAssertEqual(restartableErrors, [true, true, true, true])

        let nonRestartableErrors = await MainActor.run {
            let model = AlphaRossModel()
            return [
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
                model.shouldRestartAssistantDownloadWithoutResumeData(NSError(domain: "RossAlphaPack", code: 2))
            ]
        }

        XCTAssertEqual(nonRestartableErrors, [false, false, false])
    }

    func testInstalledPackActivationAndRemovalDeleteLocalArtifact() async throws {
        try await withRestoredStore { store in
            let basicPath = "model-packs/quick_start/lifecycle-basic.gguf"
            let standardPath = "model-packs/case_associate/lifecycle-standard.gguf"
            let basicURL = alphaAbsoluteURL(for: basicPath)
            let standardURL = alphaAbsoluteURL(for: standardPath)
            try FileManager.default.createDirectory(
                at: basicURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: standardURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let basicArtifact = alphaAssistantModelArtifact(for: .quickStart)
            let standardArtifact = alphaAssistantModelArtifact(for: .caseAssociate)
            try makeSparseFile(at: basicURL, bytes: basicArtifact.sizeBytes)
            try makeSparseFile(at: standardURL, bytes: standardArtifact.sizeBytes)

            let basicPack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q4",
                tier: .quickStart,
                installPath: basicPath,
                checksumSha256: basicArtifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            let standardPack = AlphaInstalledModelPack(
                packId: "gemma-4-e4b-q4",
                tier: .caseAssociate,
                installPath: standardPath,
                checksumSha256: standardArtifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: false
            )

            var state = AlphaPersistedState.seed()
            state.installedPacks = [basicPack, standardPack]
            state.settings.activeTier = .quickStart

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.persisted = state
            }

            let validatedPaths = SendableBox<[String]>([])
            AlphaLlamaCppProvider.modelLoadValidator = { path in
                validatedPaths.value.append(path)
            }

            await MainActor.run {
                model.activateInstalledPack(standardPack)
            }
            var snapshot = await MainActor.run { model.persisted }
            XCTAssertEqual(.caseAssociate, snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.first { $0.id == standardPack.id }?.isActive == true)
            XCTAssertTrue(validatedPaths.value.contains(standardURL.path()))

            await MainActor.run {
                model.removeInstalledPack(standardPack)
            }
            snapshot = await MainActor.run { model.persisted }
            XCTAssertFalse(FileManager.default.fileExists(atPath: standardURL.path()))
            XCTAssertFalse(snapshot.installedPacks.contains { $0.id == standardPack.id })
            XCTAssertEqual(.quickStart, snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.first { $0.id == basicPack.id }?.isActive == true)
        }
    }

    func testInstalledPackActivationRejectsRuntimeInvalidArtifact() async throws {
        rossSaveLanguageSelection(code: "hi")
        try await withRestoredStore { store in
            let activePath = "model-packs/quick_start/current.gguf"
            let brokenPath = "model-packs/case_associate/broken.gguf"
            let activeURL = alphaAbsoluteURL(for: activePath)
            let brokenURL = alphaAbsoluteURL(for: brokenPath)
            try FileManager.default.createDirectory(
                at: activeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: brokenURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try makeSparseFile(at: activeURL, bytes: alphaAssistantModelArtifact(for: .quickStart).sizeBytes)
            try makeSparseFile(at: brokenURL, bytes: alphaAssistantModelArtifact(for: .caseAssociate).sizeBytes)

            let activePack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q4",
                tier: .quickStart,
                installPath: activePath,
                checksumSha256: String(repeating: "a", count: 64),
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            let brokenPack = AlphaInstalledModelPack(
                packId: "gemma-4-e4b-q4",
                tier: .caseAssociate,
                installPath: brokenPath,
                checksumSha256: String(repeating: "b", count: 64),
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: false
            )
            var state = AlphaPersistedState.seed()
            state.installedPacks = [activePack, brokenPack]
            state.settings.activeTier = .quickStart
            state.modelJobs = [
                AlphaModelDownloadJob(
                    sessionId: "installed-broken",
                    packId: brokenPack.packId,
                    tier: brokenPack.tier,
                    state: .installed,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: alphaAssistantModelArtifact(for: .caseAssociate).sizeBytes,
                    totalBytes: alphaAssistantModelArtifact(for: .caseAssociate).sizeBytes,
                    checksumSha256: brokenPack.checksumSha256,
                    artifactKind: brokenPack.artifactKind,
                    runtimeMode: brokenPack.runtimeMode,
                    developmentOnly: false
                )
            ]

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.persisted = state
            }
            AlphaLlamaCppProvider.modelLoadValidator = { path in
                if path == brokenURL.path() {
                    throw NSError(
                        domain: "RossLlamaCppValidationTest",
                        code: 42,
                        userInfo: [NSLocalizedDescriptionKey: "broken test model"]
                    )
                }
            }

            await MainActor.run {
                model.activateInstalledPack(brokenPack)
            }

            let snapshot = await MainActor.run { model.persisted }
            XCTAssertEqual(.quickStart, snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.first { $0.id == activePack.id }?.isActive == true)
            XCTAssertFalse(snapshot.installedPacks.first { $0.id == brokenPack.id }?.isActive == true)
            XCTAssertEqual(.failed, snapshot.modelJobs.first?.state)
            XCTAssertTrue(snapshot.modelJobs.first?.failureReason?.contains("खोल नहीं पाया") == true)
            XCTAssertTrue(snapshot.modelJobs.first?.failureReason?.contains("My assistant") == true)
            XCTAssertTrue(snapshot.modelJobs.first?.failureReason?.contains("Repair setup") == true)
            XCTAssertFalse(snapshot.modelJobs.first?.failureReason?.localizedCaseInsensitiveContains("download") == true)
            XCTAssertEqual("Assistant activation failed", snapshot.ledgerEntries.first?.title)
        }
    }

    func testRuntimeHealthRejectsExactSizePackWhenLlamaCannotOpenIt() async throws {
        try await withRestoredStore { _ in
            let brokenPath = "model-packs/quick_start/health-broken.gguf"
            let brokenURL = alphaAbsoluteURL(for: brokenPath)
            try FileManager.default.createDirectory(
                at: brokenURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try makeSparseFile(at: brokenURL, bytes: alphaAssistantModelArtifact(for: .quickStart).sizeBytes)

            let pack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q4",
                tier: .quickStart,
                installPath: brokenPath,
                checksumSha256: "catalog-size:\(alphaAssistantModelArtifact(for: .quickStart).fileName):\(alphaAssistantModelArtifact(for: .quickStart).sizeBytes)",
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            AlphaLlamaCppProvider.modelLoadValidator = { path in
                if path == brokenURL.path() {
                    throw NSError(
                        domain: "RossLlamaCppHealthTest",
                        code: 7,
                        userInfo: [NSLocalizedDescriptionKey: "cannot open sparse test model"]
                    )
                }
            }

            let health = AlphaLocalModelRuntime.runtimeHealth(
                activePack: pack,
                requestedTier: .quickStart
            )

            XCTAssertEqual(health?.available, false)
            XCTAssertEqual(health?.lastErrorCategory, "runtime_validation_failed")
            XCTAssertTrue(health?.userFacingStatus.localizedCaseInsensitiveContains("could not open") == true)
            XCTAssertTrue(health?.userFacingStatus.contains("My assistant") == true)
            XCTAssertTrue(health?.userFacingStatus.contains("Repair setup") == true)
            XCTAssertFalse(health?.userFacingStatus.localizedCaseInsensitiveContains("download") == true)
        }
    }

    func testRepairAssistantPackRemovesBrokenArtifactAndRestartsSetup() async throws {
        try await withRestoredStore { store in
            let brokenPath = "model-packs/case_associate/broken-repair.gguf"
            let brokenURL = alphaAbsoluteURL(for: brokenPath)
            try FileManager.default.createDirectory(
                at: brokenURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("broken model artifact".utf8).write(to: brokenURL)

            let brokenPack = AlphaInstalledModelPack(
                packId: "gemma-4-e4b-q4",
                tier: .caseAssociate,
                installPath: brokenPath,
                checksumSha256: String(repeating: "b", count: 64),
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
                isActive: true
            )
            var state = AlphaPersistedState.seed()
            state.installedPacks = [brokenPack]
            state.settings.activeTier = .caseAssociate
            state.modelJobs = [
                AlphaModelDownloadJob(
                    sessionId: "installed-broken-repair",
                    packId: brokenPack.packId,
                    tier: brokenPack.tier,
                    state: .failed,
                    networkPolicy: .wifiOnly,
                    bytesDownloaded: 0,
                    totalBytes: alphaAssistantModelArtifact(for: .caseAssociate).sizeBytes,
                    checksumSha256: brokenPack.checksumSha256,
                    artifactKind: brokenPack.artifactKind,
                    runtimeMode: brokenPack.runtimeMode,
                    developmentOnly: false,
                    failureReason: "Could not open model"
                )
            ]

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.persisted = state
            }

            await model.repairAssistantPack(for: .caseAssociate, mobileAllowed: false)

            let snapshot = await MainActor.run { model.persisted }
            XCTAssertFalse(FileManager.default.fileExists(atPath: brokenURL.path()))
            XCTAssertFalse(snapshot.installedPacks.contains { $0.id == brokenPack.id })
            XCTAssertEqual(.installed, snapshot.modelJobs.first(where: { $0.tier == .caseAssociate })?.state)
            XCTAssertEqual(.caseAssociate, snapshot.settings.activeTier)
            XCTAssertEqual(.deterministicDev, snapshot.installedPacks.first(where: { $0.tier == .caseAssociate })?.runtimeMode)
        }
    }

    func testDocumentAdvocateNotePersistsOnDocument() async throws {
        try await withRestoredStore { store in
            let state = AlphaPersistedState.demoSeed()
            try await store.replace(with: state)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let ids = await MainActor.run { () -> (UUID, UUID)? in
                guard let caseMatter = model.cases.first,
                      let document = caseMatter.documents.first else { return nil }
                return (caseMatter.id, document.id)
            }
            XCTAssertNotNil(ids)
            let note = "Manual advocate note: confirm next date from signed order."

            await MainActor.run {
                if let ids {
                    model.updateDocumentAdvocateNote(caseId: ids.0, documentId: ids.1, note: note)
                }
            }

            let savedNote = await MainActor.run { () -> String? in
                guard let ids else { return nil }
                return model.persisted.cases
                    .first(where: { $0.id == ids.0 })?
                    .documents
                    .first(where: { $0.id == ids.1 })?
                    .advocateNote
            }

            XCTAssertEqual(savedNote, note)
        }
    }

    func testLoadIfNeededKeepsPersistedAssistantTierSelection() async throws {
        try await withRestoredStore { store in
            var state = AlphaPersistedState.seed()
            let referenceModel = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            let recommendedTier = await MainActor.run { referenceModel.recommendedOnDeviceTier() }
            let selectedTier = assistantSetupRegressionTier(recommendedTier: recommendedTier)
            state.settings.activeTier = selectedTier
            try await store.replace(with: state)
            let storedState = try await store.load()
            XCTAssertEqual(storedState.settings.activeTier, selectedTier)

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let restoredSelectedTier = await MainActor.run { model.selectedTier }
            let persistedTier = await MainActor.run { model.persisted.settings.activeTier }

            XCTAssertNotEqual(selectedTier, recommendedTier)
            XCTAssertEqual(restoredSelectedTier, selectedTier)
            XCTAssertEqual(persistedTier, selectedTier)
        }
    }

    func testMatterChatThreadsStayScopedToSelectedSession() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)

            await MainActor.run {
                model.startNewChat(for: caseID, openConversation: false)
                model.submitAsk(question: "What should I do next for this matter?", scopeCaseID: caseID, webEnabled: false)
                model.startNewChat(for: caseID, openConversation: false)
                model.submitAsk(question: "What is the next hearing date?", scopeCaseID: caseID, webEnabled: false)
            }

            let sessions = await MainActor.run { model.chatSessions(for: caseID) }
            let userAskSessions = sessions.filter { $0.turns.first?.kind == .userAsk }
            XCTAssertEqual(userAskSessions.count, 2)
            XCTAssertEqual(userAskSessions[0].turns.first?.question, "What is the next hearing date?")
            XCTAssertEqual(userAskSessions[1].turns.first?.question, "What should I do next for this matter?")

            let firstSessionID = try XCTUnwrap(userAskSessions.last?.id)
            await MainActor.run {
                model.setActiveChatSession(firstSessionID, for: caseID)
            }

            let conversation = await MainActor.run { model.askConversation(for: caseID) }
            XCTAssertEqual(conversation.count, 1)
            XCTAssertEqual(conversation.first?.question, "What should I do next for this matter?")
        }
    }

    func testImportDocumentAddsMatterUpdateToActiveChat() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let tempURL = try makeTemporaryTextFile(
                name: "hearing-note.txt",
                contents: "Order dated 10/05/2026. Matter listed for compliance review and chronology update."
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)
            await MainActor.run {
                model.startNewChat(for: caseID, openConversation: false)
            }

            await model.importDocument(caseId: caseID, from: tempURL)

            let maybeActiveSession = await MainActor.run { model.activeChatSession(for: caseID) }
            let activeSession = try XCTUnwrap(maybeActiveSession)
            let importedDocumentID = try XCTUnwrap(activeSession.contextDocumentIDs.first)
            let maybeImportedDocument = await MainActor.run {
                model.persisted.cases
                    .first(where: { $0.id == caseID })?
                    .documents
                    .first(where: { $0.id == importedDocumentID })
            }
            let importedDocument = try XCTUnwrap(maybeImportedDocument)
            let updateTurns = activeSession.turns.filter { $0.kind == .matterUpdate }
            let selectedDocumentIDs = await MainActor.run { model.selectedAskDocumentIDs(for: caseID) }
            let selectedScopeCaseID = await MainActor.run { model.askSelectedScopeCaseID }

            XCTAssertGreaterThanOrEqual(updateTurns.count, 1)
            XCTAssertTrue(updateTurns.contains(where: { ($0.selectedDocumentTitles ?? []).contains(importedDocument.title) }))
            XCTAssertEqual(Set(activeSession.contextDocumentIDs), Set([importedDocument.id]))
            XCTAssertEqual(selectedDocumentIDs, Set([importedDocument.id]))
            XCTAssertEqual(selectedScopeCaseID, caseID)
        }
    }

    func testImportedBanglaDocumentBecomesAskUsableWithLanguageHint() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let tempURL = try makeTemporaryTextFile(
                name: "bangla-order.txt",
                contents: "ধারা ৪১৭ অনুযায়ী আইনজীবীকে দাখিলের আগে উদ্ধৃতি যাচাই করতে হবে। পরবর্তী শুনানি ১০ জুন ২০২৬।"
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)
            await model.importDocument(caseId: caseID, from: tempURL)

            let importedDocument = try await MainActor.run {
                try XCTUnwrap(
                    model.persisted.cases
                        .first(where: { $0.id == caseID })?
                        .documents
                        .first(where: { $0.title.hasSuffix("bangla-order") })
                )
            }
            let sourcePack = await MainActor.run {
                model.askRuntimeSourcePack(
                    question: "বাংলা স্ক্রিপ্টে বলুন, ধারা ৪১৭ কী করতে বলে?",
                    scopeCaseID: caseID,
                    selectedDocuments: [
                        AlphaAskDocumentOption(
                            id: importedDocument.id,
                            caseId: caseID,
                            caseTitle: "Test matter",
                            title: importedDocument.title,
                            fileName: importedDocument.fileName,
                            kind: importedDocument.kind,
                            isShared: false
                        )
                    ]
                )
            }

            XCTAssertTrue(importedDocument.hasAskUsableExtractedText)
            XCTAssertEqual(importedDocument.languageProfile?.primaryLanguage, .bengali)
            XCTAssertTrue(sourcePack.contains { block in
                block.sourceRef.documentId == importedDocument.id &&
                    block.languageHint == "bengali" &&
                    block.text.contains("উদ্ধৃতি যাচাই")
            })
        }
    }

    func testImportedPDFBecomesAskUsableWithPageSource() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let maybeCaseID = try await store.load().cases.first?.id
            let caseID = try XCTUnwrap(maybeCaseID)
            let report = try await store.createPDFExport(
                title: "Article 417 Filing Note",
                kind: "Local Review",
                caseId: caseID,
                bodyLines: [
                    "IN THE HIGH COURT OF DELHI",
                    "CS No. 45/2026",
                    "Article 417 requires the advocate to verify citations before filing.",
                    "Next date: 12/05/2026"
                ]
            )

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await model.importDocument(caseId: caseID, from: alphaAbsoluteURL(for: report.relativePath))

            let importedDocument = try await MainActor.run {
                try XCTUnwrap(
                    model.persisted.cases
                        .first(where: { $0.id == caseID })?
                        .documents
                        .first(where: { $0.title.contains("article-417-filing-note") || $0.title.contains("Article 417 Filing Note") })
                )
            }
            let sourcePack = await MainActor.run {
                model.askRuntimeSourcePack(
                    question: "What does Article 417 require?",
                    scopeCaseID: caseID,
                    selectedDocuments: [
                        AlphaAskDocumentOption(
                            id: importedDocument.id,
                            caseId: caseID,
                            caseTitle: "Test matter",
                            title: importedDocument.title,
                            fileName: importedDocument.fileName,
                            kind: importedDocument.kind,
                            isShared: false
                        )
                    ]
                )
            }

            XCTAssertEqual(importedDocument.kind, .pdf)
            XCTAssertTrue(importedDocument.hasAskUsableExtractedText)
            XCTAssertTrue(sourcePack.contains { block in
                block.sourceRef.documentId == importedDocument.id &&
                    block.sourceRef.pageNumber == 1 &&
                    block.text.contains("Article 417 requires the advocate to verify citations")
            })
        }
    }

    func testUnreadableImportedImageDoesNotBecomeAskSource() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("\(UUID().uuidString)-unreadable-evidence.png")
            try Data("not a real image".utf8).write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)
            await model.importDocument(caseId: caseID, from: tempURL)

            let importedDocument = try await MainActor.run {
                try XCTUnwrap(
                    model.persisted.cases
                        .first(where: { $0.id == caseID })?
                        .documents
                        .first(where: { $0.fileName.hasSuffix("unreadable-evidence.png") })
                )
            }
            let sourcePack = await MainActor.run {
                model.askRuntimeSourcePack(
                    question: "What does this image say?",
                    scopeCaseID: caseID,
                    selectedDocuments: [
                        AlphaAskDocumentOption(
                            id: importedDocument.id,
                            caseId: caseID,
                            caseTitle: "Test matter",
                            title: importedDocument.title,
                            fileName: importedDocument.fileName,
                            kind: importedDocument.kind,
                            isShared: false
                        )
                    ]
                )
            }

            XCTAssertEqual(importedDocument.kind, .image)
            XCTAssertFalse(importedDocument.hasAskUsableExtractedText)
            XCTAssertTrue(sourcePack.isEmpty)
        }
    }

    func testTaggedUnreadableFileDoesNotFallBackToMatterMemoryAnswer() async throws {
        let previousLanguageCode = rossSelectedLanguageCode()
        rossSaveLanguageSelection(code: "hi")
        defer { rossSaveLanguageSelection(code: previousLanguageCode) }

        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)
            let unreadableDocument = AlphaCaseDocument(
                title: "Unreadable scan",
                fileName: "unreadable-scan.pdf",
                kind: .pdf,
                storedRelativePath: "docs/unreadable-scan.pdf",
                importedAt: .now,
                pageCount: 1,
                ocrStatus: .placeholder,
                indexingStatus: .notStarted,
                pages: []
            )
            await MainActor.run {
                let testPack = AlphaInstalledModelPack(
                    packId: "case-associate-test-pack",
                    tier: .caseAssociate,
                    installPath: "model-packs/case_associate/pack.dev",
                    checksumSha256: String(repeating: "a", count: 64),
                    artifactKind: "tiny_dev_artifact",
                    runtimeMode: .deterministicDev,
                    developmentOnly: true,
                    isActive: true
                )
                model.privateAISnapshot.activePack = testPack
                model.persisted.installedPacks = [testPack]
                model.persisted.settings.activeTier = .caseAssociate
                if let caseIndex = model.persisted.cases.firstIndex(where: { $0.id == caseID }) {
                    model.persisted.cases[caseIndex].documents.append(unreadableDocument)
                }
                model.invalidateWorkspaceDerivedState()
                model.setSelectedAskDocumentIDs([unreadableDocument.id], for: caseID)
                model.submitAsk(question: "What does this selected file say?", scopeCaseID: caseID, webEnabled: false)
            }

            let latest = await MainActor.run { model.latestAskResult }
            XCTAssertEqual(latest?.answerTitle, "Selected file में readable text नहीं है")
            XCTAssertEqual(latest?.statusNote, "File text उपलब्ध नहीं")
            let answerText = try XCTUnwrap(latest?.answerSections.joined(separator: " "))
            XCTAssertTrue(answerText.contains("Ross को tagged file में readable source text नहीं मिला।"), answerText)
            XCTAssertTrue(answerText.contains("file फिर import करें"), answerText)
            XCTAssertFalse(answerText.contains("could not find readable source text"), answerText)
            XCTAssertTrue(latest?.caseFileSources.isEmpty == true)
        }
    }

    func testTaggedFileWithActiveExtractionReportsStillReading() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseID = await MainActor.run { model.cases.first?.id }
            let caseID = try XCTUnwrap(maybeCaseID)
            let documentID = UUID()
            let readingDocument = AlphaCaseDocument(
                id: documentID,
                title: "Reading scan",
                fileName: "reading-scan.pdf",
                kind: .pdf,
                storedRelativePath: "docs/reading-scan.pdf",
                importedAt: .now,
                pageCount: 1,
                ocrStatus: .placeholder,
                indexingStatus: .extracting,
                pages: [],
                extractionRuns: [
                    AlphaExtractionRun(
                        caseId: caseID,
                        documentId: documentID,
                        mode: .caseAssociate,
                        status: .running,
                        progressState: .acquiringText,
                        startedAt: .now,
                        pagesProcessed: 0,
                        totalPages: 1,
                        fieldsExtracted: 0,
                        fieldsNeedingReview: 0,
                        warnings: []
                    )
                ]
            )
            await MainActor.run {
                let testPack = AlphaInstalledModelPack(
                    packId: "case-associate-test-pack",
                    tier: .caseAssociate,
                    installPath: "model-packs/case_associate/pack.dev",
                    checksumSha256: String(repeating: "a", count: 64),
                    artifactKind: "tiny_dev_artifact",
                    runtimeMode: .deterministicDev,
                    developmentOnly: true,
                    isActive: true
                )
                model.privateAISnapshot.activePack = testPack
                model.persisted.installedPacks = [testPack]
                model.persisted.settings.activeTier = .caseAssociate
                if let caseIndex = model.persisted.cases.firstIndex(where: { $0.id == caseID }) {
                    model.persisted.cases[caseIndex].documents.append(readingDocument)
                }
                model.invalidateWorkspaceDerivedState()
                model.setSelectedAskDocumentIDs([readingDocument.id], for: caseID)
                model.submitAsk(question: "What does this selected file say?", scopeCaseID: caseID, webEnabled: false)
            }

            let latest = await MainActor.run { model.latestAskResult }
            XCTAssertEqual(latest?.answerTitle, "Selected file is still being read")
            XCTAssertEqual(latest?.statusNote, "File text not ready")
            XCTAssertTrue(latest?.answerSections.joined(separator: " ").contains("extracting readable text") == true)
            XCTAssertTrue(latest?.caseFileSources.isEmpty == true)
        }
    }

    func testPlaceholderPageSnippetIsNotAskUsableText() {
        let document = AlphaCaseDocument(
            title: "Scanned placeholder",
            fileName: "scanned-placeholder.pdf",
            kind: .pdf,
            storedRelativePath: "docs/scanned-placeholder.pdf",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .placeholder,
            indexingStatus: .notStarted,
            pages: [
                AlphaDocumentPage(
                    pageNumber: 1,
                    snippet: "Imported page 1.",
                    extractedText: nil,
                    anchorText: nil,
                    ocrStatus: .failed,
                    indexingStatus: .failed
                )
            ]
        )

        XCTAssertFalse(document.hasAskUsableExtractedText)
    }

    func testDocumentReadinessMessageReflectsReviewStateWhenAskIsUsable() {
        let readyDocument = AlphaCaseDocument(
            title: "Ready order",
            fileName: "ready-order.txt",
            kind: .text,
            storedRelativePath: "docs/ready-order.txt",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            pages: [
                AlphaDocumentPage(pageNumber: 1, snippet: "Order text", extractedText: "Order dated 14 May 2026.")
            ],
            extractionRuns: [
                AlphaExtractionRun(
                    caseId: UUID(),
                    documentId: UUID(),
                    mode: .caseAssociate,
                    status: .complete,
                    progressState: .complete,
                    startedAt: .now,
                    completedAt: .now,
                    pagesProcessed: 1,
                    totalPages: 1,
                    fieldsExtracted: 1,
                    fieldsNeedingReview: 0,
                    warnings: []
                )
            ]
        )

        let failedReviewDocument = AlphaCaseDocument(
            title: "Readable but failed review",
            fileName: "failed-review.txt",
            kind: .text,
            storedRelativePath: "docs/failed-review.txt",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            pages: [
                AlphaDocumentPage(pageNumber: 1, snippet: "Order text", extractedText: "Order dated 14 May 2026.")
            ],
            extractionRuns: [
                AlphaExtractionRun(
                    caseId: UUID(),
                    documentId: UUID(),
                    mode: .caseAssociate,
                    status: .failed,
                    progressState: .failed,
                    startedAt: .now,
                    completedAt: .now,
                    pagesProcessed: 1,
                    totalPages: 1,
                    fieldsExtracted: 0,
                    fieldsNeedingReview: 0,
                    warnings: ["Review failed"]
                )
            ]
        )

        let readingDocument = AlphaCaseDocument(
            title: "Still reading",
            fileName: "still-reading.pdf",
            kind: .pdf,
            storedRelativePath: "docs/still-reading.pdf",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .notStarted,
            indexingStatus: .extracting,
            pages: []
        )

        let unreadableDocument = AlphaCaseDocument(
            title: "Unreadable scan",
            fileName: "unreadable.jpg",
            kind: .image,
            storedRelativePath: "docs/unreadable.jpg",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .failed,
            indexingStatus: .failed,
            pages: []
        )

        XCTAssertTrue(alphaDocumentReadinessMessage(readyDocument).contains("Verified details are ready"))
        XCTAssertTrue(alphaDocumentReadinessMessage(failedReviewDocument).contains("full review did not finish"))
        XCTAssertTrue(alphaDocumentReadinessMessage(readingDocument).contains("Ask from this file as soon as readable text appears"))
        XCTAssertTrue(alphaDocumentReadinessMessage(unreadableDocument).contains("Re-import a clearer PDF, image, or text file"))
        XCTAssertFalse(alphaDocumentReadinessMessage(readyDocument).contains("still running"))

        let readyItems = alphaDocumentReadinessItems(readyDocument)
        XCTAssertEqual(readyItems.map(\.title), ["Ask is ready", "Review complete", "Language pending"])
        XCTAssertTrue(readyItems[0].detail.contains("cite its pages"))
        XCTAssertTrue(readyItems[1].detail.contains("notes, tasks, and exports"))

        let failedItems = alphaDocumentReadinessItems(failedReviewDocument)
        XCTAssertEqual(failedItems[0].title, "Ask is ready")
        XCTAssertEqual(failedItems[1].title, "Review needs attention")
        XCTAssertTrue(failedItems[1].detail.contains("deeper review did not finish"))

        let readingItems = alphaDocumentReadinessItems(readingDocument)
        XCTAssertEqual(readingItems[0].title, "Still reading")
        XCTAssertTrue(readingItems[0].detail.contains("readable text appears"))

        let unreadableItems = alphaDocumentReadinessItems(unreadableDocument)
        XCTAssertEqual(unreadableItems[0].title, "Needs clearer text")
        XCTAssertTrue(unreadableItems[0].detail.contains("Re-import a clearer PDF"))

        var bengaliDocument = readyDocument
        bengaliDocument.languageProfile = AlphaDocumentLanguageProfile(
            documentId: bengaliDocument.id,
            primaryLanguage: .bengali,
            scriptsDetected: ["bengali"],
            confidence: 0.97,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(
                    pageNumber: 1,
                    language: .bengali,
                    script: .bengali,
                    confidence: 0.97
                )
            ]
        )
        let bengaliItems = alphaDocumentReadinessItems(bengaliDocument)
        XCTAssertEqual(bengaliItems[2].title, "Bengali")
        XCTAssertTrue(bengaliItems[2].detail.contains("bengali"))
    }

    func testQueuedIncomingDocumentsCreateMatterAndImportFiles() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let tempURL = try makeTemporaryTextFile(
                name: "shared-order.txt",
                contents: "Shared order dated 14/05/2026. Matter listed for evidence filing."
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()
            await MainActor.run {
                model.queueIncomingDocumentURL(tempURL)
                model.createMatterForQueuedIncomingDocuments(title: "Incoming Shared Matter")
            }

            try await Task.sleep(nanoseconds: 250_000_000)

            let createdMatter = await MainActor.run {
                model.persisted.cases.first(where: { $0.title == "Incoming Shared Matter" })
            }
            let matter = try XCTUnwrap(createdMatter)
            XCTAssertEqual(matter.documents.count, 1)
            XCTAssertEqual(matter.documents.first?.kind, .text)
            XCTAssertTrue(matter.documents.first?.extractedText?.contains("evidence filing") == true)

            let selectedScopeCaseID = await MainActor.run { model.askSelectedScopeCaseID }
            let selectedDocumentIDs = await MainActor.run { model.selectedAskDocumentIDs(for: matter.id) }
            XCTAssertEqual(selectedScopeCaseID, matter.id)
            XCTAssertEqual(selectedDocumentIDs, Set(matter.documents.map(\.id)))
        }
    }

    func testSwitchingMatterChatsRestoresPerThreadDocumentContext() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseMatter = await MainActor.run { model.cases.first }
            let caseMatter = try XCTUnwrap(maybeCaseMatter)
            XCTAssertGreaterThanOrEqual(caseMatter.documents.count, 2)
            let firstDocument = caseMatter.documents[0]
            let secondDocument = caseMatter.documents[1]

            await MainActor.run {
                model.startNewChat(for: caseMatter.id, openConversation: false)
                model.openDocumentInChat(caseId: caseMatter.id, documentId: firstDocument.id, startNewThread: false)
            }
            let maybeFirstSessionID = await MainActor.run { model.activeChatSessionID(for: caseMatter.id) }
            let firstSessionID = try XCTUnwrap(maybeFirstSessionID)

            await MainActor.run {
                model.startNewChat(for: caseMatter.id, openConversation: false)
            }
            let clearedSelection = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let clearedDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            XCTAssertTrue(clearedSelection.isEmpty)
            XCTAssertEqual(clearedDraft, "")

            await MainActor.run {
                model.openDocumentInChat(caseId: caseMatter.id, documentId: secondDocument.id, startNewThread: false)
            }
            let maybeSecondSessionID = await MainActor.run { model.activeChatSessionID(for: caseMatter.id) }
            let secondSessionID = try XCTUnwrap(maybeSecondSessionID)
            XCTAssertNotEqual(firstSessionID, secondSessionID)

            await MainActor.run {
                model.setActiveChatSession(firstSessionID, for: caseMatter.id)
            }
            let restoredFirstSelection = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let restoredFirstDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            XCTAssertEqual(restoredFirstSelection, Set([firstDocument.id]))
            XCTAssertEqual(restoredFirstDraft, "What should I note from \(firstDocument.title)?")

            await MainActor.run {
                model.setActiveChatSession(secondSessionID, for: caseMatter.id)
            }
            let restoredSecondSelection = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let restoredSecondDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            XCTAssertEqual(restoredSecondSelection, Set([secondDocument.id]))
            XCTAssertEqual(restoredSecondDraft, "What should I note from \(secondDocument.title)?")
        }
    }

    func testOpenDocumentInChatCreatesFirstMatterThread() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseMatter = await MainActor.run { model.cases.first }
            let caseMatter = try XCTUnwrap(maybeCaseMatter)
            let document = try XCTUnwrap(caseMatter.documents.first)

            let initialSessionCount = await MainActor.run { model.chatSessions(for: caseMatter.id).count }
            XCTAssertEqual(initialSessionCount, 1)

            await MainActor.run {
                model.openDocumentInChat(caseId: caseMatter.id, documentId: document.id, startNewThread: false)
            }

            let sessionCount = await MainActor.run { model.chatSessions(for: caseMatter.id).count }
            let maybeActiveSession = await MainActor.run { model.activeChatSession(for: caseMatter.id) }
            let activeSession = try XCTUnwrap(maybeActiveSession)
            let selectedDocumentIDs = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let askDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            let routeDescription = await MainActor.run { model.path.last }

            XCTAssertEqual(sessionCount, initialSessionCount)
            XCTAssertEqual(Set(activeSession.contextDocumentIDs), Set([document.id]))
            XCTAssertEqual(selectedDocumentIDs, Set([document.id]))
            XCTAssertEqual(askDraft, "What should I note from \(document.title)?")
            XCTAssertEqual(routeDescription, .askCase(caseMatter.id))
        }
    }

    func testPrepareDocumentTranslationSelectsDocumentAndSetsLocalizedDraft() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())

            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            let maybeCaseMatter = await MainActor.run { model.cases.first }
            let caseMatter = try XCTUnwrap(maybeCaseMatter)
            let document = try XCTUnwrap(caseMatter.documents.first)

            await MainActor.run {
                model.prepareDocumentTranslation(caseId: caseMatter.id, documentId: document.id, targetLanguageCode: "ta")
            }

            let selectedDocumentIDs = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let askDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            let routeDescription = await MainActor.run { model.path.last }

            XCTAssertEqual(selectedDocumentIDs, Set([document.id]))
            XCTAssertTrue(askDraft.contains("Translate \"\(document.title)\" into Tamil"))
            XCTAssertTrue(askDraft.contains("cite source pages"))
            XCTAssertEqual(routeDescription, .askCase(caseMatter.id))
        }
    }

    func testPreparedWorkUsesOnlyPersistedMatterState() async throws {
        try await withRestoredStore { store in
            defer { rossSaveLanguageSelection(code: "en") }
            var state = AlphaPersistedState.empty()
            state.onboardingStage = .completed
            try await store.replace(with: state)

            let emptyModel = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await emptyModel.loadIfNeeded()
            await MainActor.run {
                emptyModel.runWorkbenchRoutine(.morningBrief)
            }

            let emptyItems = await MainActor.run { emptyModel.preparedWorkItems() }
            XCTAssertTrue(emptyItems.isEmpty)

            try await store.replace(with: AlphaPersistedState.seed())
            rossSaveLanguageSelection(code: "hi")
            let seededModel = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await seededModel.loadIfNeeded()
            await MainActor.run {
                seededModel.runWorkbenchRoutine(.morningBrief)
            }

            let items = await MainActor.run { seededModel.preparedWorkItems() }
            XCTAssertFalse(items.isEmpty)
            XCTAssertTrue(items.allSatisfy { $0.caseId != nil && !$0.matterName.isEmpty })
            XCTAssertTrue(items.contains { $0.primaryAction == "खोलें" || $0.primaryAction == "Review" })
            XCTAssertTrue(items.flatMap(\.secondaryActions).contains("हटाएं"))
            XCTAssertTrue(items.contains { $0.title.contains("review updated") })
            XCTAssertTrue(items.contains { $0.summary.contains("matter memory update") || $0.summary.contains("review चाहिए") })
            let routineRun = await MainActor.run { seededModel.persisted.routineRuns?.first }
            XCTAssertTrue(routineRun?.summary.contains("local रूप से update") == true)
            let ledgerEntry = await MainActor.run { seededModel.persisted.ledgerEntries.first }
            XCTAssertEqual(ledgerEntry?.title, "Morning brief local रूप से चला")
            XCTAssertTrue(ledgerEntry?.detail.contains("saved matters") == true)
        }
    }

    func testPublicLawRoutinePreparesPreviewWithoutNetworkUntilApproval() async throws {
        try await withRestoredStore { store in
            defer { rossSaveLanguageSelection(code: "en") }
            try await store.replace(with: AlphaPersistedState.seed())
            rossSaveLanguageSelection(code: "ta")
            let publicLawCalls = SendableBox(0)
            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in
                    publicLawCalls.value += 1
                    return []
                })
            }
            await model.loadIfNeeded()

            await MainActor.run {
                model.runWorkbenchRoutine(.publicLawPreview)
            }

            let status = await MainActor.run { model.publicLawSearchStatus }
            let prepared = await MainActor.run { model.preparedWorkItems().first { $0.type == .publicLawQueryAwaitingApproval } }
            XCTAssertEqual(status, .reviewing)
            XCTAssertEqual(publicLawCalls.value, 0)
            XCTAssertEqual(prepared?.badge, .approvalRequired)
            XCTAssertEqual(prepared?.matterName, "Workspace")
            XCTAssertEqual(prepared?.title, "Public-law query review செய்யவும்")
            XCTAssertEqual(prepared?.primaryAction, "ஒப்புதல் அளிக்கவும்")
            XCTAssertEqual(prepared?.secondaryActions, ["திருத்தவும்", "நீக்கவும்"])
            let routineRun = await MainActor.run { model.persisted.routineRuns?.first }
            XCTAssertEqual(routineRun?.summary, "Sanitized query preview local-ஆக தயார் ஆனது.")

            await model.confirmPendingPublicLawSearch()
            XCTAssertEqual(publicLawCalls.value, 1)
        }
    }

    func testDismissedPreparedWorkStaysDismissedUntilSourceChanges() async throws {
        try await withRestoredStore { store in
            try await store.replace(with: AlphaPersistedState.seed())
            let model = await MainActor.run {
                AlphaRossModel(store: store, publicLawSearchAction: { _ in [] })
            }
            await model.loadIfNeeded()

            guard let caseID = await MainActor.run(body: { model.cases.first { $0.id != alphaSharedWorkspaceID }?.id }) else {
                XCTFail("Expected seeded matter")
                return
            }
            await MainActor.run {
                model.runWorkbenchRoutine(.morningBrief, caseId: caseID)
            }
            guard let item = await MainActor.run(body: { model.preparedWorkItems(caseId: caseID).first { $0.type == .suggestedTasks } }) else {
                XCTFail("Expected suggested task prepared work")
                return
            }

            await MainActor.run {
                model.setPreparedWorkStatus(item.id, status: .dismissed)
                model.runWorkbenchRoutine(.morningBrief, caseId: caseID)
            }
            let stillDismissed = await MainActor.run {
                model.preparedWorkItems(caseId: caseID, includeDismissed: true).first { $0.id == item.id }?.status
            }
            XCTAssertEqual(stillDismissed, .dismissed)

            await MainActor.run {
                model.addTask(title: "Review updated source bundle", caseId: caseID, dueDate: nil)
                model.runWorkbenchRoutine(.morningBrief, caseId: caseID)
            }
            let regenerated = await MainActor.run {
                model.preparedWorkItems(caseId: caseID, includeDismissed: true).first { $0.stableKey == item.stableKey }?.status
            }
            XCTAssertEqual(regenerated, .new)
        }
    }

    func testLegacyPersistedStateDecodesWithoutWorkbenchFields() throws {
        var state = AlphaPersistedState.empty()
        state.preparedWorkItems = nil
        state.routineRuns = nil
        state.routineSettings = nil
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "preparedWorkItems")
        object.removeValue(forKey: "routineRuns")
        object.removeValue(forKey: "routineSettings")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AlphaPersistedState.self, from: legacyData)
        XCTAssertNil(decoded.preparedWorkItems)
        XCTAssertNil(decoded.routineRuns)
        XCTAssertNil(decoded.routineSettings)
    }

    private func withRestoredStore(
        _ body: (AlphaRossStore) async throws -> Void
    ) async throws {
        let store = AlphaRossStore()
        let originalState = try? await store.load()

        func restoreOriginalState() async {
            // AlphaRossModel persists through a short debounce. Let any save the
            // test body already scheduled finish before restoring the shared
            // plaintext test store, otherwise a delayed save can leak into the
            // next test's setup.
            try? await Task.sleep(for: .milliseconds(300))
            if let originalState {
                try? await store.replace(with: originalState)
            }
        }

        do {
            try await body(store)
            await restoreOriginalState()
        } catch {
            await restoreOriginalState()
            throw error
        }
    }

    private func makeTemporaryTextFile(name: String, contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString)-\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeSparseFile(at url: URL, bytes: Int64) throws {
        FileManager.default.createFile(atPath: url.path(), contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(bytes))
        try handle.close()
    }

    private func eventually(
        timeoutNanoseconds: UInt64,
        intervalNanoseconds: UInt64 = 50_000_000,
        _ condition: () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutNanoseconds) / 1_000_000_000)
        while true {
            if await condition() {
                return
            }
            if Date() >= deadline {
                XCTFail("Condition was not met before timeout")
                return
            }
            try await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }

    private func assistantSetupRegressionTier(recommendedTier: AlphaCapabilityTier) -> AlphaCapabilityTier {
        if recommendedTier != .quickStart {
            return .quickStart
        }
        return .caseAssociate
    }

    private func waitForAssistantSetupState(
        model: AlphaRossModel,
        tier: AlphaCapabilityTier,
        attempts: Int = 20,
        intervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> AlphaPersistedState {
        for attempt in 0..<attempts {
            let snapshot = await MainActor.run { model.persisted }
            let hasAssistantSetupState = snapshot.modelJobs.contains(where: { $0.tier == tier })
                || snapshot.installedPacks.contains(where: { $0.tier == tier })
            if hasAssistantSetupState {
                return snapshot
            }
            if attempt < attempts - 1 {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            }
        }

        return await MainActor.run { model.persisted }
    }

}

private final class RossLocalAuthStub {
    var canEvaluate = true
    var biometryType: LABiometryType = .faceID
    private(set) var evaluateCallCount = 0
    private var completions: [@Sendable (Bool, Error?) -> Void] = []

    func evaluate(
        _ localizedReason: String,
        _ completion: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        _ = localizedReason
        evaluateCallCount += 1
        completions.append(completion)
    }

    func finishNext(success: Bool, error: Error? = nil) {
        guard !completions.isEmpty else { return }
        let completion = completions.removeFirst()
        completion(success, error)
    }
}

private func makeAuthSession() -> RossAuthSession {
    RossAuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        accountToken: "account",
        email: "fresh@ross.ai",
        displayName: "Fresh Ross Account",
        subject: "fresh_user",
        expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

private final class SendableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
