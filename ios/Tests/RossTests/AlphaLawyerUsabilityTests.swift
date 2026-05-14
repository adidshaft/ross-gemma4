import LocalAuthentication
import SwiftUI
import XCTest
@testable import Ross

final class AlphaLawyerUsabilityTests: XCTestCase {
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
            XCTAssertEqual("Gemma 4 E2B Q2_K running locally", pending.statusNote)
            XCTAssertTrue(
                pending.answerSections.joined(separator: " ").contains("replace this with the local answer")
            )
            XCTAssertTrue(
                pending.answerSections.joined(separator: " ").contains("Tagged files: Demo affidavit, Demo order.")
            )
            XCTAssertEqual(["Demo affidavit", "Demo order"], pending.selectedDocumentTitles)
            XCTAssertEqual([], pending.caseFileSources)
        }
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
                userFacingStatus: "Gemma 4 (Llama.cpp) Ready",
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
            XCTAssertEqual("Ross assistant is ready", status.title)
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

            XCTAssertEqual("Ross answered locally", payload?.headline)
            XCTAssertTrue(payload?.sections.first?.contains("FMLS") == true)
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
            XCTAssertEqual("Review required", statusBeforeConfirm)
            XCTAssertEqual(0, publicLawCalls.value)

            await model.confirmPendingPublicLawSearch()

            let resultCount = await MainActor.run { model.publicLawResults.count }
            let statusAfterConfirm = await MainActor.run { model.latestAskResult?.statusNote }
            let ledgerTitles = await MainActor.run { model.persisted.ledgerEntries.map(\.title) }
            XCTAssertEqual(1, publicLawCalls.value)
            XCTAssertEqual(1, resultCount)
            XCTAssertEqual("Public-law results", statusAfterConfirm)
            XCTAssertTrue(ledgerTitles.contains("Public-law search reviewed by user"))
            XCTAssertTrue(ledgerTitles.contains("Public-law query sent"))
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
            XCTAssertNil(preview)
            XCTAssertNil(latestPreview)
            XCTAssertNil(latestResult)
            XCTAssertTrue(results.isEmpty)
            XCTAssertEqual(0, publicLawCalls.value)
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
            XCTAssertFalse(preview?.removed.contains("No private case data detected") == true)
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
                "Choose and download a private assistant before asking legal questions.",
                "Ross did not generate a legal answer because a real local model is required."
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
        XCTAssertTrue(normalized.ledgerEntries.contains { $0.title == "Assistant model paused" })
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
            try Data("basic-real-artifact".utf8).write(to: basicURL)
            try Data("standard-real-artifact".utf8).write(to: standardURL)

            let basicPack = AlphaInstalledModelPack(
                packId: "gemma-4-e2b-q4",
                tier: .quickStart,
                installPath: basicPath,
                checksumSha256: String(repeating: "a", count: 64),
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
                checksumSha256: String(repeating: "b", count: 64),
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

            await MainActor.run {
                model.activateInstalledPack(standardPack)
            }
            var snapshot = await MainActor.run { model.persisted }
            XCTAssertEqual(.caseAssociate, snapshot.settings.activeTier)
            XCTAssertTrue(snapshot.installedPacks.first { $0.id == standardPack.id }?.isActive == true)

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
        }
    }

    func testPublicLawRoutinePreparesPreviewWithoutNetworkUntilApproval() async throws {
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
                model.runWorkbenchRoutine(.publicLawPreview)
            }

            let status = await MainActor.run { model.publicLawSearchStatus }
            let prepared = await MainActor.run { model.preparedWorkItems().first { $0.type == .publicLawQueryAwaitingApproval } }
            XCTAssertEqual(status, .reviewing)
            XCTAssertEqual(publicLawCalls.value, 0)
            XCTAssertEqual(prepared?.badge, .approvalRequired)

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

        do {
            try await body(store)
            if let originalState {
                try? await store.replace(with: originalState)
            }
        } catch {
            if let originalState {
                try? await store.replace(with: originalState)
            }
            throw error
        }
    }

    private func makeTemporaryTextFile(name: String, contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString)-\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
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
