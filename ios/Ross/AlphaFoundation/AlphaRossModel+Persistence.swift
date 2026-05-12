import CryptoKit
import Observation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension AlphaRossModel {

    func loadIfNeeded() async {
        guard !loaded else { return }
        do {
            let loadedState = try await store.load()
            persisted = normalizeLoadedState(loadedState)
            if persisted.installedPacks != loadedState.installedPacks ||
                persisted.modelJobs != loadedState.modelJobs ||
                persisted.settings.activeTier != loadedState.settings.activeTier {
                persist()
            }
            invalidateWorkspaceDerivedState()
            syncDerivedStateFromPersisted()
            loaded = true
        } catch {
            loaded = true
        }
    }

    func clearStaleAskState(for currentRoute: AlphaRoute?) {
        guard let latestAskResult else { return }

        let routeCaseID: UUID?
        switch currentRoute {
        case .caseWorkspace(let id), .askCase(let id):
            routeCaseID = id
        default:
            routeCaseID = nil
        }

        if latestAskResult.scopeCaseID != routeCaseID {
            self.latestAskResult = nil
        }
    }

    func syncWorkspaceForSession(_ session: RossAuthSession?) {
        guard loaded else { return }

        if recoverDownloadedAssistantArtifacts(from: &persisted) {
            persist()
        }

        if let session, session.subject.hasPrefix("local_demo_") {
            if shouldSeedDemoWorkspace(for: session.subject) {
                let preserved = preservedWorkspaceConfiguration()
                persisted = AlphaPersistedState.demoSeed(profileSubject: session.subject)
                applyPreservedWorkspaceConfiguration(preserved)
                _ = recoverDownloadedAssistantArtifacts(from: &persisted)
                persist(workspaceChanged: true)
            }
            return
        }

        if let session, session.subject.hasPrefix("local_fresh_") {
            if persisted.demoProfileSubject != nil || isLegacySeedWorkspace {
                let preserved = preservedWorkspaceConfiguration()
                persisted = AlphaPersistedState.empty()
                applyPreservedWorkspaceConfiguration(preserved)
                _ = recoverDownloadedAssistantArtifacts(from: &persisted)
                persist(workspaceChanged: true)
            }
            return
        }

        if persisted.demoProfileSubject != nil, isCurrentWorkspaceDemoOnly {
            let preserved = preservedWorkspaceConfiguration()
            persisted = AlphaPersistedState.empty()
            applyPreservedWorkspaceConfiguration(preserved)
            _ = recoverDownloadedAssistantArtifacts(from: &persisted)
            persist(workspaceChanged: true)
        }
    }

    func syncDerivedStateFromPersisted() {
        selectedCaseID = cases.first?.id
        selectedTier = persisted.settings.activeTier ?? recommendedOnDeviceTier()
        publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
        publicLawPreview = persisted.publicLawPreview
        publicLawResults = persisted.publicLawResults ?? []
        rebuildAskHistory()
    }

    func rebuildAskHistory() {
        askHistory = persisted.cases.flatMap { caseMatter in
            caseMatter.chatSessions.flatMap { session in
                session.turns.reversed().map { turn in
                    askResult(from: turn, in: caseMatter, chatSessionID: session.id)
                }
            }
        }
    }

    struct AlphaPreservedWorkspaceConfiguration {
        var settings: AlphaSettings
        var modelJobs: [AlphaModelDownloadJob]
        var installedPacks: [AlphaInstalledModelPack]
        var lastModelCatalogRefresh: Date?
    }

    func preservedWorkspaceConfiguration() -> AlphaPreservedWorkspaceConfiguration {
        AlphaPreservedWorkspaceConfiguration(
            settings: persisted.settings,
            modelJobs: persisted.modelJobs,
            installedPacks: persisted.installedPacks,
            lastModelCatalogRefresh: persisted.lastModelCatalogRefresh
        )
    }

    func applyPreservedWorkspaceConfiguration(_ preserved: AlphaPreservedWorkspaceConfiguration) {
        persisted.settings = preserved.settings
        persisted.modelJobs = preserved.modelJobs
        persisted.installedPacks = preserved.installedPacks
        persisted.lastModelCatalogRefresh = preserved.lastModelCatalogRefresh
        selectedTier = persisted.settings.activeTier ?? recommendedOnDeviceTier()
        publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
        publicLawPreview = persisted.publicLawPreview
        publicLawResults = persisted.publicLawResults ?? []
        syncDerivedStateFromPersisted()
    }

    var visibleCasesCount: Int {
        persisted.cases.filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }.count
    }

    var isLegacySeedWorkspace: Bool {
        let titles = Set(
            persisted.cases
                .filter { $0.id != alphaSharedWorkspaceID }
                .map(\.title)
        )
        return titles == [
            "Kaveri Developers v. South Ward Municipal Corporation",
            "Arun Textiles v. State Tax Officer"
        ]
    }

    var isCurrentWorkspaceDemoOnly: Bool {
        let visibleCases = persisted.cases.filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }
        guard visibleCases.count == 1 else { return false }
        guard visibleCases.first?.title == "Demo Matter: Sharma v. Rana" else { return false }
        let exportCount = persisted.exports.filter { $0.caseId == visibleCases.first?.id }.count
        return exportCount <= 1
    }

    func shouldSeedDemoWorkspace(for subject: String) -> Bool {
        if persisted.demoProfileSubject == subject {
            return false
        }
        if visibleCasesCount == 0 || isLegacySeedWorkspace {
            return true
        }
        if persisted.demoProfileSubject != nil && isCurrentWorkspaceDemoOnly {
            return true
        }
        return false
    }

    func invalidateWorkspaceDerivedState() {
        workspaceRevision &+= 1
    }

    func ensureWorkspaceDerivedState() {
        guard cachedWorkspaceRevision != workspaceRevision else { return }
        workspaceDerivedState = AlphaWorkspaceDerivedState.build(from: persisted)
        cachedWorkspaceRevision = workspaceRevision
    }

    struct AlphaWorkspaceDerivedState {
        var visibleCases: [AlphaCaseMatter] = []
        var activeCaseIDs: Set<UUID> = []
        var tasks: [AlphaTaskItem] = []
        var tasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var openTasks: [AlphaTaskItem] = []
        var openTaskCountByCase: [UUID: Int] = [:]
        var todayTasks: [AlphaTaskItem] = []
        var todayTasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var upcomingTasks: [AlphaTaskItem] = []
        var upcomingTasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var reviewQueue: [AlphaReviewQueueItem] = []
        var reviewQueueByCase: [UUID: [AlphaReviewQueueItem]] = [:]
        var availableAskDocumentsAll: [AlphaAskDocumentOption] = []
        var availableAskDocumentsByScope: [UUID: [AlphaAskDocumentOption]] = [:]
        var recentDocumentItems: [AlphaRecentDocumentItem] = []
        var recentDocumentItemsByCase: [UUID: [AlphaRecentDocumentItem]] = [:]
        var todayDateRows: [AlphaUpcomingDateRow] = []
        var upcomingDateRows: [AlphaUpcomingDateRow] = []

        static func build(from persisted: AlphaPersistedState) -> Self {
            let visibleCases = persisted.cases
                .filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }
                .sorted { $0.updatedAt > $1.updatedAt }
            let activeCaseIDs = Set(visibleCases.map(\.id))

            let allTasks = (persisted.tasks ?? [])
                .filter { task in
                    guard let caseId = task.caseId else { return true }
                    return activeCaseIDs.contains(caseId)
                }
                .sorted(by: sortTasks)

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: .now)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? .now

            var tasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var openTaskCountByCase: [UUID: Int] = [:]
            var todayTasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var upcomingTasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var openTasks: [AlphaTaskItem] = []
            var todayTasks: [AlphaTaskItem] = []
            var upcomingTasks: [AlphaTaskItem] = []

            for task in allTasks {
                if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                    tasksByCase[caseId, default: []].append(task)
                }

                guard task.status == .open else { continue }
                openTasks.append(task)

                if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                    openTaskCountByCase[caseId, default: 0] += 1
                }

                guard let dueDate = task.dueDate else { continue }
                if dueDate < startOfTomorrow {
                    todayTasks.append(task)
                    if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                        todayTasksByCase[caseId, default: []].append(task)
                    }
                } else if dueDate >= startOfTomorrow {
                    upcomingTasks.append(task)
                    if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                        upcomingTasksByCase[caseId, default: []].append(task)
                    }
                }
            }

            var reviewQueueByCase: [UUID: [AlphaReviewQueueItem]] = [:]
            var reviewQueue: [AlphaReviewQueueItem] = []
            var recentDocumentItemsByCase: [UUID: [AlphaRecentDocumentItem]] = [:]
            var recentDocumentItems: [AlphaRecentDocumentItem] = []
            var todayDateRows: [AlphaUpcomingDateRow] = []
            var upcomingDateRows: [AlphaUpcomingDateRow] = []

            for caseMatter in visibleCases {
                let caseReviewQueue = buildReviewQueue(for: caseMatter)
                reviewQueueByCase[caseMatter.id] = caseReviewQueue
                reviewQueue.append(contentsOf: caseReviewQueue)

                let caseRecentItems = caseMatter.documents
                    .map { document in
                        AlphaRecentDocumentItem(caseId: caseMatter.id, caseTitle: caseMatter.title, document: document)
                    }
                    .sorted { $0.document.importedAt > $1.document.importedAt }
                recentDocumentItemsByCase[caseMatter.id] = caseRecentItems
                recentDocumentItems.append(contentsOf: caseRecentItems)

                let scheduledDates = caseMatter.dates
                    .filter { $0.status == .scheduled }
                    .sorted { $0.date < $1.date }

                let dateRows: [AlphaUpcomingDateRow]
                if scheduledDates.isEmpty, let nextHearing = caseMatter.nextHearing {
                    dateRows = [
                        AlphaUpcomingDateRow(
                            title: caseMatter.title,
                            detail: nextHearing < startOfDay
                                ? "Overdue hearing from \(nextHearing.formatted(date: .abbreviated, time: .omitted))"
                                : calendar.isDateInToday(nextHearing)
                                    ? "Hearing today"
                                    : "Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))",
                            date: nextHearing
                        )
                    ]
                } else {
                    dateRows = scheduledDates.map { matterDate in
                        let prefix: String
                        if matterDate.date < startOfDay {
                            prefix = "Overdue"
                        } else if calendar.isDateInToday(matterDate.date) {
                            prefix = "Today"
                        } else {
                            prefix = matterDate.title
                        }
                        let detail = prefix == "Today"
                            ? "\(matterDate.title) today"
                            : "\(prefix): \(matterDate.date.formatted(date: .abbreviated, time: .omitted))"
                        return AlphaUpcomingDateRow(title: caseMatter.title, detail: detail, date: matterDate.date)
                    }
                }

                for row in dateRows {
                    if row.date < startOfTomorrow {
                        todayDateRows.append(row)
                    } else {
                        upcomingDateRows.append(row)
                    }
                }
            }

            recentDocumentItems.sort { $0.document.importedAt > $1.document.importedAt }
            todayDateRows.sort { $0.date < $1.date }
            upcomingDateRows.sort { $0.date < $1.date }

            var availableAskDocumentsByScope: [UUID: [AlphaAskDocumentOption]] = [:]
            for caseMatter in visibleCases {
                let scopedCases = persisted.cases.filter { $0.id == caseMatter.id || $0.id == alphaSharedWorkspaceID }
                availableAskDocumentsByScope[caseMatter.id] = buildAskDocumentOptions(from: scopedCases)
            }

            var state = AlphaWorkspaceDerivedState()
            state.visibleCases = visibleCases
            state.activeCaseIDs = activeCaseIDs
            state.tasks = allTasks
            state.tasksByCase = tasksByCase
            state.openTasks = openTasks
            state.openTaskCountByCase = openTaskCountByCase
            state.todayTasks = todayTasks
            state.todayTasksByCase = todayTasksByCase
            state.upcomingTasks = upcomingTasks
            state.upcomingTasksByCase = upcomingTasksByCase
            state.reviewQueue = reviewQueue
            state.reviewQueueByCase = reviewQueueByCase
            state.availableAskDocumentsAll = buildAskDocumentOptions(from: persisted.cases)
            state.availableAskDocumentsByScope = availableAskDocumentsByScope
            state.recentDocumentItems = recentDocumentItems
            state.recentDocumentItemsByCase = recentDocumentItemsByCase
            state.todayDateRows = todayDateRows
            state.upcomingDateRows = upcomingDateRows
            return state
        }

        static func sortTasks(lhs: AlphaTaskItem, rhs: AlphaTaskItem) -> Bool {
            if lhs.status != rhs.status {
                return lhs.status == .open
            }
            let lhsDate = lhs.dueDate ?? .distantFuture
            let rhsDate = rhs.dueDate ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        static func buildAskDocumentOptions(from cases: [AlphaCaseMatter]) -> [AlphaAskDocumentOption] {
            cases
                .flatMap { caseMatter in
                    caseMatter.documents.map { document in
                        AlphaAskDocumentOption(
                            id: document.id,
                            caseId: caseMatter.id,
                            caseTitle: caseMatter.title,
                            title: document.title,
                            fileName: document.fileName,
                            kind: document.kind,
                            isShared: caseMatter.id == alphaSharedWorkspaceID
                        )
                    }
                }
                .sorted { lhs, rhs in
                    if lhs.isShared != rhs.isShared {
                        return lhs.isShared && !rhs.isShared
                    }
                    if lhs.caseTitle != rhs.caseTitle {
                        return lhs.caseTitle.localizedCaseInsensitiveCompare(rhs.caseTitle) == .orderedAscending
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
        }

        static func buildReviewQueue(for caseMatter: AlphaCaseMatter) -> [AlphaReviewQueueItem] {
            let ignoredFieldIDs = Set(
                caseMatter.advocateCorrections
                    .filter { $0.correctionType == .ignoreField }
                    .compactMap(\.fieldId)
            )

            return caseMatter.documents.flatMap { document in
                let visibleFields = document.extractedFields
                    .filter { !ignoredFieldIDs.contains($0.id) }
                    .sorted { lhs, rhs in
                        let lhsRank = alphaFieldSortRank(lhs.fieldType)
                        let rhsRank = alphaFieldSortRank(rhs.fieldType)
                        if lhsRank == rhsRank {
                            return lhs.createdAt < rhs.createdAt
                        }
                        return lhsRank < rhsRank
                    }

                let fields = visibleFields
                    .filter(\.needsReview)
                    .map { field in
                        AlphaReviewQueueItem(
                            caseId: caseMatter.id,
                            documentId: document.id,
                            caseTitle: caseMatter.title,
                            title: reviewTitle(for: field.fieldType),
                            detail: field.value,
                            sourceRef: field.sourceRefs.first,
                            target: .extractedField(field.id)
                        )
                    }

                let findings = document.extractionFindings
                    .filter { !$0.resolved }
                    .map { finding in
                        AlphaReviewQueueItem(
                            caseId: caseMatter.id,
                            documentId: document.id,
                            caseTitle: caseMatter.title,
                            title: reviewTitle(for: finding.kind),
                            detail: finding.message,
                            sourceRef: finding.sourceRefs.first,
                            target: .finding(finding.id)
                        )
                    }

                return fields + findings
            }
        }

        static func reviewTitle(for fieldType: AlphaExtractedLegalFieldType) -> String {
            switch fieldType {
            case .nextDate:
                "Confirm next date"
            case .partyName:
                "Review party name"
            case .orderDirection:
                "Check order direction"
            default:
                "Please confirm"
            }
        }

        static func reviewTitle(for findingKind: AlphaExtractionFindingKind) -> String {
            switch findingKind {
            case .lowConfidenceOcr, .languageUncertain, .possibleHandwriting:
                "Low confidence scan"
            case .ambiguousOrderDirection:
                "Check order direction"
            case .dateConflict:
                "Confirm next date"
            case .partyConflict:
                "Review party name"
            default:
                "Please confirm"
            }
        }
    }

    func askResult(
        from turn: AlphaChatTurn,
        in caseMatter: AlphaCaseMatter,
        chatSessionID: UUID
    ) -> AlphaAskResult {
        let isSharedWorkspace = caseMatter.id == alphaSharedWorkspaceID
        return AlphaAskResult(
            chatSessionID: chatSessionID,
            chatTurnID: turn.id,
            kind: turn.kind,
            question: turn.question,
            scopeCaseID: isSharedWorkspace ? nil : caseMatter.id,
            scopeLabel: isSharedWorkspace ? "All work" : caseMatter.title,
            selectedDocumentTitles: turn.selectedDocumentTitles ?? [],
            answerTitle: turn.answerTitle,
            answerSections: turn.answerSections,
            caseFileSources: turn.sourceRefs,
            publicLawPreview: turn.publicLawPreview,
            publicLawResults: turn.publicLawResults,
            statusNote: turn.statusNote,
            needsReviewWarning: turn.needsReviewWarning
        )
    }

    var cases: [AlphaCaseMatter] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.visibleCases
    }

    func todayTasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.todayTasks }
        return workspaceDerivedState.todayTasksByCase[caseId] ?? []
    }

    var activePack: AlphaInstalledModelPack? {
        if let active = persisted.installedPacks.first(where: \.isActive),
           installedModelPackFileIsUsable(active) {
            return active
        }
        return recoveredInstalledPackFromDisk(preferredTier: persisted.settings.activeTier ?? selectedTier)
    }

    func submitDockInput(question: String, scopeCaseID: UUID?, webEnabled: Bool) async {
        let cleaned = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        setAskDraft("", for: scopeCaseID)

        if let command = dockCommandAction(for: cleaned) {
            await runDockCommand(command, rawInput: cleaned, scopeCaseID: scopeCaseID)
            return
        }

        submitAsk(question: cleaned, scopeCaseID: scopeCaseID, webEnabled: webEnabled)
    }

    func runLocalInferenceSmoke() {
        guard !localInferenceSmokeRunning else { return }
        localInferenceSmokeRunning = true
        localInferenceSmokeReport = nil

        Task {
            let runtimeHealth = activeRuntimeHealth
            guard let runtimeHealth, runtimeHealth.available else {
                localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                    ran: false,
                    runtimeUsed: runtimeHealth?.runtimeMode.rawValue ?? AlphaPackRuntimeMode.unavailable.rawValue,
                    schemaValid: false,
                    fieldsFound: 0,
                    fieldsVerified: 0,
                    fieldsNeedingReview: 0,
                    unsupportedAccepted: 0,
                    exportRelativePath: nil,
                    message: runtimeHealth?.userFacingStatus ?? "Real local inference is unavailable on this device right now."
                )
                localInferenceSmokeRunning = false
                return
            }

            let smokeCaseID = UUID()
            let smokeDocumentID = UUID()
            let smokeText = """
            IN THE HIGH COURT OF DELHI AT NEW DELHI
            CS(COMM) 245/2026
            Order dated 14 March 2026
            The matter concerns delay condonation and Section 138 of the Negotiable Instruments Act.
            The respondent shall file a written statement within two weeks.
            List on 28 April 2026.
            """
            let smokeDocument = AlphaCaseDocument(
                id: smokeDocumentID,
                title: "Case Associate Local Smoke",
                fileName: "case-associate-local-smoke.txt",
                kind: .text,
                storedRelativePath: "smoke/case-associate-local-smoke.txt",
                importedAt: .now,
                pageCount: 1,
                ocrStatus: .nativeText,
                indexingStatus: .indexed,
                extractedText: smokeText,
                dominantSourceSnippet: "Delay condonation and Section 138 written statement order.",
                lastIndexedAt: .now,
                pages: [
                    AlphaDocumentPage(
                        pageNumber: 1,
                        snippet: "Delay condonation and Section 138 written statement order.",
                        extractedText: smokeText,
                        anchorText: "Delay condonation and Section 138 written statement order.",
                        ocrConfidence: 0.99,
                        ocrStatus: .nativeText,
                        indexingStatus: .indexed
                    )
                ]
            )

            let result = await store.runLocalExtraction(
                caseId: smokeCaseID,
                document: smokeDocument,
                activePack: activePack
            )

            let export: AlphaExportedReport?
            do {
                export = try await store.createPDFExport(
                    title: "Local inference smoke",
                    kind: "case_note",
                    caseId: nil,
                    bodyLines: [
                        "Draft — please review",
                        "Synthetic local inference smoke run",
                        "Runtime: \(runtimeHealth.runtimeMode.rawValue)",
                        "Fields found: \(result.extractedFields.count)",
                        "Fields verified: \(result.extractedFields.filter { !$0.needsReview || $0.userCorrected }.count)",
                        "Fields needing review: \(result.extractedFields.filter { $0.needsReview && !$0.userCorrected }.count)"
                    ]
                )
            } catch {
                export = nil
            }

            if let export {
                persisted.exports.insert(export, at: 0)
                persist()
            }

            localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                ran: true,
                runtimeUsed: result.modelInvocations.last?.runtimeMode ?? runtimeHealth.runtimeMode.rawValue,
                schemaValid: !result.modelInvocations.contains { $0.errorCategory == "invalid_model_output" },
                fieldsFound: result.extractedFields.count,
                fieldsVerified: result.extractedFields.filter { !$0.needsReview || $0.userCorrected }.count,
                fieldsNeedingReview: result.extractedFields.filter { $0.needsReview && !$0.userCorrected }.count,
                unsupportedAccepted: 0,
                exportRelativePath: export?.relativePath,
                message: "Local inference smoke completed without logging prompt or source text."
            )
            localInferenceSmokeRunning = false
        }
    }

    func advanceOnboarding() {
        selectedTier = recommendedOnDeviceTier()
        finishPackSetup()
    }

    func importDocument(caseId: UUID?, from sourceURL: URL, openAfterImport: Bool = true) async {
        let targetCaseID = caseId ?? alphaSharedWorkspaceID
        do {
            let imported = try await store.importDocument(from: sourceURL, into: targetCaseID)
            guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == targetCaseID }) else { return }
            var document = imported.document
            document.indexingStatus = .extracting
            document.extractionRuns = [
                AlphaExtractionRun(
                    caseId: targetCaseID,
                    documentId: document.id,
                    mode: .fromInstalledPack(activePack),
                    status: .running,
                    progressState: .acquiringText,
                    startedAt: .now,
                    pagesProcessed: 0,
                    totalPages: document.pageCount,
                    fieldsExtracted: 0,
                    fieldsNeedingReview: 0,
                    warnings: []
                )
            ]

            var caseMatter = persisted.cases[caseIndex]
            caseMatter.documents.insert(document, at: 0)
            refreshCaseWorkspace(caseMatter: &caseMatter)
            completeImportFirstDocumentTask(caseId: targetCaseID)
            caseMatter.updatedAt = .now
            if targetCaseID != alphaSharedWorkspaceID {
                selectedCaseID = targetCaseID
                askSelectedScopeCaseID = targetCaseID
                setSelectedAskDocumentIDs([document.id], for: targetCaseID)
            } else {
                setSelectedAskDocumentIDs([document.id], for: nil)
            }

            let sourceRef = AlphaSourceRef(
                caseId: targetCaseID,
                documentId: document.id,
                documentTitle: document.title,
                pageNumber: 1,
                paragraphRange: nil,
                textSnippet: document.dominantSourceSnippet ?? document.extractedText ?? "Imported source reference",
                ocrConfidence: document.kind == .image ? nil : 0.92
            )
            caseMatter.sourceRefs.insert(sourceRef, at: 0)
            persisted.cases[caseIndex] = caseMatter

            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document imported locally",
                    detail: "\(document.title) was copied into app-private storage.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: true
                ),
                at: 0
            )
            persist(workspaceChanged: true)
            appendMatterThreadUpdate(
                caseId: targetCaseID == alphaSharedWorkspaceID ? nil : targetCaseID,
                title: "File added to this matter",
                sections: [
                    "\(document.title) was copied into private storage and linked to the current matter.",
                    "Ross is reading this file so the active chat can pick up dates, directions, and follow-up work."
                ],
                sourceRefs: [sourceRef],
                selectedDocumentIDs: [document.id],
                selectedDocumentTitles: [document.title],
                statusNote: "Matter chat updated · reading file"
            )
            if openAfterImport {
                path.append(.documentViewer(targetCaseID, document.id, 1))
            }

            let result = await store.runLocalExtraction(
                caseId: targetCaseID,
                document: document,
                activePack: activePack
            )
            applyExtractionResult(result, caseId: targetCaseID, documentId: document.id)
        } catch {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document import failed",
                    detail: "Ross could not copy the selected file into app-private storage.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: false
                ),
                at: 0
            )
            persist()
        }
    }

    func buildPublicLawPreview() {
        publicLawPreview = sanitizePublicLawPreview(rawQuery: publicLawDraft, caseMatter: selectedCase)
        publicLawResults = []
        publicLawSearchStatus = .reviewing
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = publicLawPreview
        persisted.publicLawResults = publicLawResults
        persist()
    }

    var activeExtractionMode: AlphaExtractionMode {
        .fromInstalledPack(activePack)
    }

    func suggestedPublicLawQuery(for caseMatter: AlphaCaseMatter?) -> String? {
        guard let caseMatter else { return nil }
        let verifiedFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let legalConcepts = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .section }
            .flatMap { publicLawKeywords(from: $0.value) }
        let documentFocusTerms: [String] = caseMatter.documents.compactMap { document -> String? in
            guard let classification = document.classification, !classification.needsReview else { return nil }
            return publicLawFocusTerm(for: classification.type)
        }
        let calendarTerms: [String] = {
            var terms: [String] = []
            if caseMatter.nextHearing != nil || caseMatter.dates.contains(where: { $0.kind == .hearing && $0.status == .scheduled }) {
                terms.append("court procedure and hearing dates")
            }
            if caseMatter.dates.contains(where: { $0.kind == .filingDeadline && $0.status == .scheduled }) {
                terms.append("filing compliance and limitation")
            }
            return terms
        }()
        var terms = Array(NSOrderedSet(array: calendarTerms + legalConcepts + documentFocusTerms))
            .compactMap { $0 as? String }
            .filter(isSafePublicLawTerm)
        if terms.isEmpty {
            terms = ["court procedure and filing compliance"]
        }
        return "Indian public law guidance on \(Array(terms.prefix(3)).joined(separator: ", "))"
    }

    func normalizeLoadedState(_ state: AlphaPersistedState) -> AlphaPersistedState {
        var normalized = state
        removeSystemAssistantShortcutState(from: &normalized)
        purgeDevelopmentModelArtifactsFromDisk()
        _ = recoverDownloadedAssistantArtifacts(from: &normalized)
        if shouldRestoreAssistantSetupFlow(for: normalized) {
            normalized.onboardingStage = looksLikePristineWorkspace(normalized) ? .onboarding : .privateAIPack
        }
        if !normalized.cases.contains(where: { $0.id == alphaSharedWorkspaceID }) {
            normalized.cases.append(sharedWorkspaceMatter())
        }
        if normalized.tasks == nil {
            normalized.tasks = initialTasks(from: normalized.cases)
        }
        return normalized
    }

    func removeSystemAssistantShortcutState(from state: inout AlphaPersistedState) {
        state.installedPacks.removeAll { pack in
            pack.artifactKind == "system_model" ||
                pack.runtimeMode == .appleFoundationModels ||
                (!alphaAllowsDevelopmentModelArtifacts() && pack.developmentOnly)
        }
        state.modelJobs.removeAll { job in
            job.artifactKind == "system_model" ||
                (job.runtimeMode == .appleFoundationModels && (job.state == .installed || job.totalBytes == 0)) ||
                (!alphaAllowsDevelopmentModelArtifacts() && job.developmentOnly)
        }
    }

    func purgeDevelopmentModelArtifactsFromDisk() {
        guard !alphaAllowsDevelopmentModelArtifacts() else { return }
        for tier in AlphaCapabilityTier.allCases {
            let tierDirectory = alphaAbsoluteURL(for: "model-packs/\(tier.rawValue)")
            let devPack = tierDirectory.appendingPathComponent("pack.dev")
            if FileManager.default.fileExists(atPath: devPack.path()) {
                try? FileManager.default.removeItem(at: devPack)
            }
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: tierDirectory.path()),
               contents.isEmpty {
                try? FileManager.default.removeItem(at: tierDirectory)
            }
        }
    }

    func recoverDownloadedAssistantArtifacts(from state: inout AlphaPersistedState) -> Bool {
        let invalidPackIDs = Set(state.installedPacks.filter { !installedModelPackFileIsUsable($0) }.map(\.id))
        if !invalidPackIDs.isEmpty {
            state.installedPacks.removeAll { invalidPackIDs.contains($0.id) }
        }

        var recoveredPacks: [AlphaInstalledModelPack] = []
        let existingPackPaths = Set(state.installedPacks.map(\.installPath))

        for tier in AlphaCapabilityTier.allCases {
            guard let recovered = recoveredInstalledPackFromDisk(tier: tier),
                  !existingPackPaths.contains(recovered.installPath) else { continue }
            recoveredPacks.append(recovered)
        }

        guard !recoveredPacks.isEmpty else { return !invalidPackIDs.isEmpty }

        let hadActivePack = state.installedPacks.contains(where: \.isActive)
        state.installedPacks.append(contentsOf: recoveredPacks)

        if !hadActivePack {
            let storedPreferredTier = state.settings.activeTier
            let preferredTier: AlphaCapabilityTier?
            if let storedPreferredTier,
               recoveredPacks.contains(where: { $0.tier == storedPreferredTier }) {
                preferredTier = storedPreferredTier
            } else {
                preferredTier = recoveredPacks.first?.tier
            }
            state.installedPacks = state.installedPacks.map { pack in
                var copy = pack
                copy.isActive = pack.tier == preferredTier
                return copy
            }
            state.settings.activeTier = preferredTier
        }

        let recoveredTitles = recoveredPacks.map(\.tier.title).joined(separator: ", ")
        state.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant model restored",
                detail: "Ross found and verified an existing private assistant file on this device: \(recoveredTitles).",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-verify",
                success: true
            ),
            at: 0
        )
        return true
    }

    func installedModelPackFileIsUsable(_ pack: AlphaInstalledModelPack) -> Bool {
        guard pack.runtimeMode != .appleFoundationModels,
              pack.artifactKind != "system_model" else {
            return false
        }

        guard !pack.developmentOnly || alphaAllowsDevelopmentModelArtifacts() else {
            return false
        }
        let fileURL = alphaAbsoluteURL(for: pack.installPath)
        guard !pack.developmentOnly else { return alphaFileByteCount(at: fileURL) > 0 }
        let artifact = alphaAssistantModelArtifact(for: pack.tier)
        guard alphaFileByteCount(at: fileURL) == artifact.sizeBytes else { return false }
        return alphaAssistantChecksumMatches(expected: artifact.sha256, actual: pack.checksumSha256)
    }

    func alphaFileByteCount(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
        if let size = attributes?[.size] as? NSNumber {
            return size.int64Value
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    func alphaSHA256Hex(forFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        do {
            while true {
                let data = try handle.read(upToCount: 1024 * 1024)
                guard let data, !data.isEmpty else { break }
                hasher.update(data: data)
            }
        } catch {
            return nil
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func recoveredInstalledPackFromDisk(preferredTier: AlphaCapabilityTier?) -> AlphaInstalledModelPack? {
        var seenTiers = Set<AlphaCapabilityTier>()
        let tiers = ([preferredTier].compactMap { $0 } + AlphaCapabilityTier.allCases).filter { tier in
            seenTiers.insert(tier).inserted
        }
        for tier in tiers {
            if let pack = recoveredInstalledPackFromDisk(tier: tier) {
                return pack
            }
        }
        return nil
    }

    func recoveredInstalledPackFromDisk(tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        let artifact = alphaAssistantModelArtifact(for: tier)
        let relativePath = "model-packs/\(tier.rawValue)/\(artifact.fileName)"
        let fileURL = alphaAbsoluteURL(for: relativePath)
        guard alphaFileByteCount(at: fileURL) == artifact.sizeBytes else { return nil }
        guard let checksum = alphaSHA256Hex(forFileAt: fileURL),
              alphaAssistantChecksumMatches(expected: artifact.sha256, actual: checksum) else {
            return nil
        }
        return AlphaInstalledModelPack(
            packId: artifact.packId,
            tier: tier,
            installPath: relativePath,
            checksumSha256: checksum,
            artifactKind: "local_model_artifact",
            runtimeMode: .llamaCppGguf,
            developmentOnly: false,
            checksumVerified: true,
            isActive: true
        )
    }

    func alphaAssistantChecksumMatches(expected: String, actual: String) -> Bool {
        let normalizedExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedActual = actual.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedActual.isEmpty else { return false }
        guard !normalizedExpected.isEmpty else {
            // Legacy catalogs shipped without a published checksum. Accept the
            // locally computed checksum so downloaded packs can still activate.
            return true
        }
        return normalizedActual.caseInsensitiveCompare(normalizedExpected) == .orderedSame
    }

    func shouldRestoreAssistantSetupFlow(for state: AlphaPersistedState) -> Bool {
        state.onboardingStage == .completed
            && state.demoProfileSubject == nil
            && state.settings.activeTier == nil
            && state.installedPacks.isEmpty
    }

    func looksLikePristineWorkspace(_ state: AlphaPersistedState) -> Bool {
        let nonSharedCases = state.cases.filter { $0.id != alphaSharedWorkspaceID }
        let hasCaseDocuments = nonSharedCases.contains { !$0.documents.isEmpty }
        let hasChatHistory = nonSharedCases.contains { !$0.chatSessions.isEmpty }
        let hasSourceRefs = nonSharedCases.contains { !$0.sourceRefs.isEmpty }
        let hasTasks = !(state.tasks ?? []).isEmpty
        let hasExports = !state.exports.isEmpty
        let hasPublicLawHistory = !state.publicLawCache.isEmpty || !((state.publicLawResults ?? []).isEmpty)
        let hasDownloadState = !state.modelJobs.isEmpty

        return nonSharedCases.isEmpty
            && !hasCaseDocuments
            && !hasChatHistory
            && !hasSourceRefs
            && !hasTasks
            && !hasExports
            && !hasPublicLawHistory
            && !hasDownloadState
    }

    func initialTasks(from cases: [AlphaCaseMatter]) -> [AlphaTaskItem] {
        cases.filter { $0.id != alphaSharedWorkspaceID }.flatMap { caseMatter in
            caseMatter.draftTasks.enumerated().map { offset, task in
                AlphaTaskItem(
                    caseId: caseMatter.id,
                    title: task,
                    dueDate: offset == 0 ? (caseMatter.nextHearing ?? Calendar.current.date(byAdding: .day, value: 2, to: .now)) : nil,
                    priority: offset == 0 ? .high : .normal,
                    source: .system
                )
            }
        }
    }

    func isRossSuggestedTask(_ task: AlphaTaskItem) -> Bool {
        task.notes?.hasPrefix(alphaRossSuggestedTaskNotePrefix) == true
    }

    func sharedWorkspaceMatter() -> AlphaCaseMatter {
        AlphaCaseMatter(
            id: alphaSharedWorkspaceID,
            title: "General files",
            forum: "Available across matters",
            stage: .intake,
            nextHearing: nil,
            summary: "Files placed here stay available anywhere on this device.",
            issueHighlights: ["Use shared files when a document should support more than one matter."],
            evidenceNotes: ["Ross keeps these files local and ready for device-wide questions."],
            draftTasks: [],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )
    }

    func recommendedOnDeviceTier() -> AlphaCapabilityTier {
        let totalMemoryGB = max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let freeStorageGB = max(4, alphaAvailableStorageInGigabytes())
        let lowPowerModeEnabled = alphaCurrentLowPowerMode()

        if lowPowerModeEnabled || totalMemoryGB < 6 || freeStorageGB < 6 {
            return .quickStart
        }
        if totalMemoryGB >= 12 && freeStorageGB >= 8 {
            return .seniorDraftingSupport
        }
        if totalMemoryGB >= 6 && freeStorageGB >= 6 {
            return .caseAssociate
        }
        return .caseAssociate
    }

    func clearCaseSelectionState(for caseID: UUID) {
        if selectedCaseID == caseID {
            selectedCaseID = cases.first(where: { $0.id != caseID })?.id
        }
        if askSelectedScopeCaseID == caseID {
            askSelectedScopeCaseID = nil
        }
        askDrafts.removeValue(forKey: caseID)
        askSelectedDocumentIDs.removeValue(forKey: caseID)
        path.removeAll { route in
            switch route {
            case .caseWorkspace(let id), .documentList(let id), .askCase(let id):
                return id == caseID
            case .documentViewer(let id, _, _):
                return id == caseID
            case .exports(let id):
                return id == caseID
            default:
                return false
            }
        }
    }
}
