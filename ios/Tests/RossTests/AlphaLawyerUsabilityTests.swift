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
            XCTAssertEqual("Web search off", status)
        }
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
                model.submitAsk(question: "Find law on delay condonation", scopeCaseID: nil, webEnabled: true)
            }

            let previewBeforeConfirm = await MainActor.run { model.publicLawPreview }
            let statusBeforeConfirm = await MainActor.run { model.latestAskResult?.statusNote }
            XCTAssertEqual(0, publicLawCalls.value)
            XCTAssertNotNil(previewBeforeConfirm)
            XCTAssertEqual("Web search preview ready", statusBeforeConfirm)

            await model.confirmPendingPublicLawSearch()

            let resultCount = await MainActor.run { model.publicLawResults.count }
            let statusAfterConfirm = await MainActor.run { model.latestAskResult?.statusNote }
            XCTAssertEqual(1, publicLawCalls.value)
            XCTAssertEqual(1, resultCount)
            XCTAssertEqual("Public-law results", statusAfterConfirm)
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
            XCTAssertEqual("I could not find this in your case files.", answerTitle)
            XCTAssertEqual(["I could not find this in your case files."], answerSections)
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
            XCTAssertEqual(sessions.count, 2)
            XCTAssertEqual(sessions[0].turns.first?.question, "What is the next hearing date?")
            XCTAssertEqual(sessions[1].turns.first?.question, "What should I do next for this matter?")

            let firstSessionID = try XCTUnwrap(sessions.last?.id)
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
            XCTAssertEqual(initialSessionCount, 0)

            await MainActor.run {
                model.openDocumentInChat(caseId: caseMatter.id, documentId: document.id, startNewThread: false)
            }

            let sessionCount = await MainActor.run { model.chatSessions(for: caseMatter.id).count }
            let maybeActiveSession = await MainActor.run { model.activeChatSession(for: caseMatter.id) }
            let activeSession = try XCTUnwrap(maybeActiveSession)
            let selectedDocumentIDs = await MainActor.run { model.selectedAskDocumentIDs(for: caseMatter.id) }
            let askDraft = await MainActor.run { model.askDraft(for: caseMatter.id) }
            let routeDescription = await MainActor.run { model.path.last }

            XCTAssertEqual(sessionCount, 1)
            XCTAssertEqual(Set(activeSession.contextDocumentIDs), Set([document.id]))
            XCTAssertEqual(selectedDocumentIDs, Set([document.id]))
            XCTAssertEqual(askDraft, "What should I note from \(document.title)?")
            XCTAssertEqual(routeDescription, .askCase(caseMatter.id))
        }
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

private final class SendableBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
