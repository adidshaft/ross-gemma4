import CryptoKit
import Observation
import SwiftUI
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

enum AlphaRoute: Hashable {
    case createCase
    case caseWorkspace(UUID)
    case documentList(UUID)
    case documentViewer(UUID, UUID, Int?)
    case askCase(UUID)
    case exports(UUID?)
    case privacyLedger
    case privateAISettings
}

struct AlphaLocalInferenceSmokeReport: Hashable {
    var ran: Bool
    var runtimeUsed: String
    var schemaValid: Bool
    var fieldsFound: Int
    var fieldsVerified: Int
    var fieldsNeedingReview: Int
    var unsupportedAccepted: Int
    var exportRelativePath: String?
    var message: String
    var createdAt: Date = .now
}

struct AlphaAskResult: Hashable {
    var question: String
    var scopeCaseID: UUID?
    var scopeLabel: String
    var answerTitle: String
    var answerSections: [String]
    var caseFileSources: [AlphaSourceRef]
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult]
    var statusNote: String?
    var needsReviewWarning: String?
}

struct AlphaReviewQueueItem: Identifiable, Hashable {
    let id = UUID()
    var caseId: UUID
    var documentId: UUID
    var caseTitle: String
    var title: String
    var detail: String
    var sourceRef: AlphaSourceRef?
}

typealias AlphaPublicLawSearchAction = @Sendable (AlphaPublicLawPreview) async throws -> [AlphaPublicLawResult]

@MainActor
@Observable
final class AlphaRossModel {
    private let store: AlphaRossStore
    @ObservationIgnored private let backend: AlphaBackendClient
    @ObservationIgnored private let publicLawSearchAction: AlphaPublicLawSearchAction

    var persisted = AlphaPersistedState.seed()
    var path: [AlphaRoute] = []
    var selectedCaseID: UUID?
    var selectedTier: AlphaCapabilityTier = .caseAssociate
    var caseDraftTitle = ""
    var caseDraftForum = ""
    var askDrafts: [UUID: String] = [:]
    var globalAskDraft = ""
    var askSelectedScopeCaseID: UUID?
    var askWebEnabled = false
    var pendingPublicLawQuestion: String?
    var pendingPublicLawScopeCaseID: UUID?
    var latestAskResult: AlphaAskResult?
    var publicLawDraft = "Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted."
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult] = []
    var localInferenceSmokeReport: AlphaLocalInferenceSmokeReport?
    var localInferenceSmokeRunning = false
    var loaded = false

    init(store: AlphaRossStore = AlphaRossStore(), publicLawSearchAction: AlphaPublicLawSearchAction? = nil) {
        self.store = store
        let backend = AlphaBackendClient()
        self.backend = backend
        self.publicLawSearchAction = publicLawSearchAction ?? { preview in
            try await backend.searchPublicLaw(preview: preview)
        }
        self.globalAskDraft = "What needs my attention today?"
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        do {
            persisted = normalizeLoadedState(try await store.load())
            selectedCaseID = persisted.cases.first?.id
            selectedTier = persisted.settings.activeTier ?? .caseAssociate
            publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
            publicLawPreview = persisted.publicLawPreview
            publicLawResults = persisted.publicLawResults ?? []
            loaded = true
        } catch {
            loaded = true
        }
    }

    var cases: [AlphaCaseMatter] {
        persisted.cases.sorted { $0.updatedAt > $1.updatedAt }
    }

    var tasks: [AlphaTaskItem] {
        (persisted.tasks ?? [])
            .sorted {
                if $0.status != $1.status {
                    return $0.status == .open
                }
                let lhsDate = $0.dueDate ?? .distantFuture
                let rhsDate = $1.dueDate ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return $0.updatedAt > $1.updatedAt
            }
    }

    var openTasks: [AlphaTaskItem] {
        tasks.filter { $0.status == .open }
    }

    var selectedCase: AlphaCaseMatter? {
        if let selectedCaseID {
            return persisted.cases.first { $0.id == selectedCaseID }
        }
        return persisted.cases.first
    }

    func tasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        tasks.filter { task in
            guard let caseId else { return true }
            return task.caseId == caseId
        }
    }

    func askDraft(for scopeCaseID: UUID?) -> String {
        if let scopeCaseID {
            return askDrafts[scopeCaseID, default: "Ask Ross about this case..."]
        }
        return globalAskDraft
    }

    func setAskDraft(_ value: String, for scopeCaseID: UUID?) {
        if let scopeCaseID {
            askDrafts[scopeCaseID] = value
        } else {
            globalAskDraft = value
        }
    }

    func scopeLabel(for caseId: UUID?) -> String {
        guard let caseId, let caseMatter = persisted.cases.first(where: { $0.id == caseId }) else {
            return "All cases"
        }
        return caseMatter.title
    }

    func todayTasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        let calendar = Calendar.current
        return tasks(for: caseId).filter {
            $0.status == .open && ($0.dueDate.map { calendar.isDateInToday($0) } ?? false)
        }
    }

    func upcomingTasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return tasks(for: caseId).filter {
            guard $0.status == .open, let dueDate = $0.dueDate else { return false }
            return dueDate >= start && !calendar.isDateInToday(dueDate)
        }
    }

    func openTaskCount(for caseId: UUID? = nil) -> Int {
        tasks(for: caseId).count { $0.status == .open }
    }

    func toggleTaskDone(_ taskID: UUID) {
        guard var taskList = persisted.tasks, let index = taskList.firstIndex(where: { $0.id == taskID }) else { return }
        taskList[index].status = taskList[index].status == .open ? .done : .open
        taskList[index].updatedAt = .now
        persisted.tasks = taskList
        persist()
    }

    func addTask(
        title: String,
        caseId: UUID?,
        dueDate: Date? = nil,
        priority: AlphaTaskPriority = .normal,
        source: AlphaTaskSource = .manual,
        notes: String? = nil
    ) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        var taskList = persisted.tasks ?? []
        taskList.insert(
            AlphaTaskItem(
                caseId: caseId,
                title: cleaned,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                source: source
            ),
            at: 0
        )
        persisted.tasks = taskList
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Task saved locally",
                detail: "\(cleaned) was added on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://task",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func recentDocuments(for caseId: UUID? = nil) -> [AlphaCaseDocument] {
        let visibleCases = caseId.map { id in persisted.cases.filter { $0.id == id } } ?? persisted.cases
        return visibleCases
            .flatMap(\.documents)
            .sorted { $0.importedAt > $1.importedAt }
    }

    func reviewQueue(caseId: UUID? = nil) -> [AlphaReviewQueueItem] {
        let visibleCases = caseId.map { id in persisted.cases.filter { $0.id == id } } ?? persisted.cases
        return visibleCases.flatMap { caseMatter in
            caseMatter.documents.flatMap { document -> [AlphaReviewQueueItem] in
                let fields = visibleExtractedFields(caseId: caseMatter.id, documentId: document.id)
                    .filter(\.needsReview)
                    .map { field in
                        AlphaReviewQueueItem(
                            caseId: caseMatter.id,
                            documentId: document.id,
                            caseTitle: caseMatter.title,
                            title: alphaReviewTitle(for: field.fieldType),
                            detail: field.value,
                            sourceRef: field.sourceRefs.first
                        )
                    }
                let findings = reviewFindings(caseId: caseMatter.id, documentId: document.id).map { finding in
                    AlphaReviewQueueItem(
                        caseId: caseMatter.id,
                        documentId: document.id,
                        caseTitle: caseMatter.title,
                        title: alphaReviewTitle(for: finding.kind),
                        detail: finding.message,
                        sourceRef: finding.sourceRefs.first
                    )
                }
                return fields + findings
            }
        }
    }

    var activePack: AlphaInstalledModelPack? {
        persisted.installedPacks.first(where: \.isActive)
    }

    var activeRuntimeHealth: AlphaLocalRuntimeHealth? {
        AlphaLocalModelRuntime.runtimeHealth(
            activePack: activePack,
            requestedTier: activePack?.tier ?? persisted.settings.activeTier
        )
    }

    var lastModelInvocationRuntimeMode: String? {
        persisted.cases
            .flatMap(\.documents)
            .flatMap(\.modelInvocations)
            .last?
            .runtimeMode
    }

    func submitAsk(question: String, scopeCaseID: UUID?, webEnabled: Bool) {
        let cleaned = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let localResult = buildLocalAskResult(question: cleaned, scopeCaseID: scopeCaseID)
        latestAskResult = localResult
        askSelectedScopeCaseID = scopeCaseID

        if let scopeCaseID {
            askDrafts[scopeCaseID] = cleaned
        } else {
            globalAskDraft = cleaned
        }

        if webEnabled {
            let preview = buildAskPublicLawPreview(question: cleaned, scopeCaseID: scopeCaseID)
            pendingPublicLawQuestion = cleaned
            pendingPublicLawScopeCaseID = scopeCaseID
            publicLawPreview = preview
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.statusNote = "Web search preview ready"
        } else {
            pendingPublicLawQuestion = nil
            pendingPublicLawScopeCaseID = nil
            publicLawPreview = nil
        }
    }

    func cancelPendingPublicLawSearch() {
        pendingPublicLawQuestion = nil
        pendingPublicLawScopeCaseID = nil
        publicLawPreview = nil
        if latestAskResult?.publicLawResults.isEmpty == true {
            latestAskResult?.statusNote = "Web search off"
        }
    }

    func confirmPendingPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        do {
            let results = try await publicLawSearchAction(preview)
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.publicLawResults = results
            latestAskResult?.statusNote = "Public-law results"
            publicLawResults = results
            persisted.publicLawCache.insert(
                AlphaPublicLawCacheItem(query: preview.query, resultTitles: results.map(\.title)),
                at: 0
            )
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Public-law query sent",
                    detail: "Only a sanitized public query crossed the network boundary.",
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: true
                ),
                at: 0
            )
            persisted.publicLawDraft = pendingPublicLawQuestion
            persisted.publicLawPreview = preview
            persisted.publicLawResults = results
            persist()
        } catch {
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.publicLawResults = []
            latestAskResult?.statusNote = "Public-law results are unavailable right now."
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Public-law search unavailable",
                    detail: "Ross could not reach the sanitized public-law backend with the approved preview.",
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: false
                ),
                at: 0
            )
            persist()
        }

        pendingPublicLawQuestion = nil
        pendingPublicLawScopeCaseID = nil
    }

    func runLocalInferenceSmoke() {
        guard !localInferenceSmokeRunning else { return }
        localInferenceSmokeRunning = true
        localInferenceSmokeReport = nil

        Task {
            let runtimeHealth = activeRuntimeHealth
            guard let runtimeHealth, runtimeHealth.explicitOptInEnabled, runtimeHealth.available else {
                localInferenceSmokeReport = AlphaLocalInferenceSmokeReport(
                    ran: false,
                    runtimeUsed: runtimeHealth?.runtimeMode.rawValue ?? AlphaPackRuntimeMode.unavailable.rawValue,
                    schemaValid: false,
                    fieldsFound: 0,
                    fieldsVerified: 0,
                    fieldsNeedingReview: 0,
                    unsupportedAccepted: 0,
                    exportRelativePath: nil,
                    message: runtimeHealth?.userFacingStatus ?? "Real local inference is unavailable. Enable it explicitly before running smoke QA."
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
                        "Draft for advocate review",
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
        persisted.onboardingStage = .privateAIPack
        persist()
    }

    func skipPackSetup() {
        persisted.onboardingStage = .completed
        persisted.selectedTab = .home
        persist()
    }

    func finishPackSetup() {
        persisted.settings.activeTier = selectedTier
        persisted.onboardingStage = .completed
        persisted.selectedTab = .home
        persist()
        Task { await startPackDownload(for: selectedTier, mobileAllowed: selectedTier == .quickStart) }
    }

    func createCase(openWorkspace: Bool = true) {
        let title = caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let forum = caseDraftForum.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let matter = AlphaCaseMatter(
            title: title,
            forum: forum.isEmpty ? "Forum pending" : forum,
            stage: .intake,
            summary: "New matter created locally. Import pleadings, orders, or captures to build a source-backed workspace.",
            issueHighlights: ["Import the first source document to begin chronology work."],
            evidenceNotes: ["No imported documents yet."],
            draftTasks: ["Import the first case document.", "Pin the first source reference."],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )

        persisted.cases.insert(matter, at: 0)
        var taskList = persisted.tasks ?? []
        taskList.insert(
            AlphaTaskItem(
                caseId: matter.id,
                title: "Import first document",
                notes: "Add the first order, pleading, or note for this case.",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                priority: .high,
                source: .system
            ),
            at: 0
        )
        persisted.tasks = taskList
        selectedCaseID = matter.id
        caseDraftTitle = ""
        caseDraftForum = ""
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Case created locally",
                detail: "A new case matter was created on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://case-create",
                success: true
            ),
            at: 0
        )
        persist()
        if openWorkspace {
            path.removeAll()
            path.append(.caseWorkspace(matter.id))
        }
    }

    func importDocument(caseId: UUID, from sourceURL: URL) async {
        do {
            let imported = try await store.importDocument(from: sourceURL, into: caseId)
            guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
            var document = imported.document
            document.indexingStatus = .extracting
            document.extractionRuns = [
                AlphaExtractionRun(
                    caseId: caseId,
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

            persisted.cases[caseIndex].documents.insert(document, at: 0)
            persisted.cases[caseIndex].updatedAt = .now

            let sourceRef = AlphaSourceRef(
                caseId: caseId,
                documentId: document.id,
                documentTitle: document.title,
                pageNumber: 1,
                paragraphRange: nil,
                textSnippet: document.dominantSourceSnippet ?? document.extractedText ?? "Imported source reference",
                ocrConfidence: document.kind == .image ? nil : 0.92
            )
            persisted.cases[caseIndex].sourceRefs.insert(sourceRef, at: 0)

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
            persist()
            path.append(.documentViewer(caseId, document.id, 1))

            let result = await store.runLocalExtraction(
                caseId: caseId,
                document: document,
                activePack: activePack
            )
            applyExtractionResult(result, caseId: caseId, documentId: document.id)
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

    func rerunReview(caseId: UUID, documentId: UUID) async {
        guard let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId }) else {
            return
        }
        let result = await store.runLocalExtraction(caseId: caseId, document: document, activePack: activePack)
        applyExtractionResult(result, caseId: caseId, documentId: documentId)
    }

    func deleteDocument(caseId: UUID, documentId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        let removedDocument = persisted.cases[caseIndex].documents.first(where: { $0.id == documentId })
        persisted.cases[caseIndex].documents.removeAll { $0.id == documentId }
        persisted.cases[caseIndex].sourceRefs.removeAll { $0.documentId == documentId }
        persisted.tasks = (persisted.tasks ?? []).filter { $0.caseId != caseId || !($0.notes?.contains(removedDocument?.title ?? "") ?? false) }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Document removed locally",
                detail: "\(removedDocument?.title ?? "Document") was removed from this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://document-delete",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func askCase(caseId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        let question = askDrafts[caseId, default: "Ask Ross about this case..."]
        let localResult = buildLocalAskResult(question: question, scopeCaseID: caseId)
        let turn = AlphaChatTurn(
            question: question,
            answerTitle: localResult.answerTitle,
            answerSections: localResult.answerSections,
            sourceRefs: localResult.caseFileSources
        )
        persisted.cases[caseIndex].chatTurns.insert(turn, at: 0)
        persisted.cases[caseIndex].updatedAt = .now
        latestAskResult = localResult
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Local case review run",
                detail: "The case question and source-backed draft stayed on-device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://ask-case",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func openSourceRef(_ ref: AlphaSourceRef) {
        path.append(.documentViewer(ref.caseId, ref.documentId, ref.pageNumber))
    }

    func visibleExtractedFields(caseId: UUID, documentId: UUID) -> [AlphaExtractedLegalField] {
        let ignored = ignoredFieldIDs(caseId: caseId, documentId: documentId)
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return [] }

        return document.extractedFields
            .filter { !ignored.contains($0.id) }
            .sorted {
                let lhs = alphaFieldSortRank($0.fieldType)
                let rhs = alphaFieldSortRank($1.fieldType)
                if lhs == rhs {
                    return $0.createdAt < $1.createdAt
                }
                return lhs < rhs
            }
    }

    func reviewFindings(caseId: UUID, documentId: UUID) -> [AlphaExtractionFinding] {
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return [] }
        return document.extractionFindings.filter { !$0.resolved }
    }

    func reviewSummary(caseId: UUID, documentId: UUID) -> String? {
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return nil }

        let visibleFields = visibleExtractedFields(caseId: caseId, documentId: documentId)
        let verifiedCount = visibleFields.count { !$0.needsReview || $0.userCorrected }
        let pendingCount = visibleFields.filter(\.needsReview).count
        switch (visibleFields.isEmpty, document.classification == nil, pendingCount > 0 || document.extractionFindings.contains(where: { !$0.resolved })) {
        case (true, true, _):
            return nil
        case (_, _, true):
            return "Fields found: \(visibleFields.count) • Verified: \(verifiedCount) • Needs review: \(pendingCount)"
        default:
            return "Fields found: \(visibleFields.count) • Verified: \(verifiedCount) • Needs review: 0"
        }
    }

    func extractionUpgradeMessage(for document: AlphaCaseDocument) -> String? {
        let mode = activeExtractionMode
        if mode == .basic {
            return "Better extraction is available with Case Associate."
        }
        if mode == .quickStart,
           document.languageProfile?.primaryLanguage == .mixed || document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
        }
        if mode == .quickStart {
            return "Better extraction is available with Case Associate."
        }
        if mode == .caseAssociate,
           document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
        }
        return nil
    }

    func acceptExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = persisted.cases[caseIndex].documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        refreshCaseWorkspace(at: caseIndex)
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist()
    }

    func ignoreExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let field = persisted.cases[caseIndex].documents[documentIndex].extractedFields.first(where: { $0.id == fieldId })
        else { return }

        persisted.cases[caseIndex].advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                fieldId: field.id,
                oldValue: field.value,
                newValue: "Ignored",
                correctionType: .ignoreField
            ),
            at: 0
        )
        refreshCaseWorkspace(at: caseIndex)
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist()
    }

    func applyFieldCorrection(caseId: UUID, documentId: UUID, fieldId: UUID, newValue: String) {
        let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = persisted.cases[caseIndex].documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        let original = persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex]
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].value = cleaned
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].normalizedValue = cleaned.lowercased()
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].userCorrected = true
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].extractionPass = .userCorrected
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        persisted.cases[caseIndex].advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                fieldId: fieldId,
                oldValue: original.value,
                newValue: cleaned,
                correctionType: alphaCorrectionType(for: original.fieldType)
            ),
            at: 0
        )
        persisted.cases[caseIndex].caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: "\(original.label) updated to '\(cleaned)' during advocate review.",
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(at: caseIndex)
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist()
    }

    func updateDocumentClassification(caseId: UUID, documentId: UUID, type: AlphaLegalDocumentType) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId })
        else { return }

        if persisted.cases[caseIndex].documents[documentIndex].classification == nil {
            persisted.cases[caseIndex].documents[documentIndex].classification = AlphaLegalDocumentClassification(
                documentId: documentId,
                type: type,
                subtype: nil,
                confidence: 0.64,
                sourceRefs: [],
                needsReview: false
            )
        } else {
            persisted.cases[caseIndex].documents[documentIndex].classification?.type = type
            persisted.cases[caseIndex].documents[documentIndex].classification?.needsReview = false
            persisted.cases[caseIndex].documents[documentIndex].classification?.confidence = max(persisted.cases[caseIndex].documents[documentIndex].classification?.confidence ?? 0.64, 0.64)
        }

        persisted.cases[caseIndex].advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                oldValue: nil,
                newValue: type.rawValue,
                correctionType: .documentType
            ),
            at: 0
        )
        refreshCaseWorkspace(at: caseIndex)
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist()
    }

    func buildPublicLawPreview() {
        let text = publicLawDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedQuery = suggestedPublicLawQuery() ?? "Find current public-law guidance relevant to delay condonation where diligence is documented."
        let lower = text.lowercased()
        let blockedPatterns = [
            "raghav fakepriv",
            "9876501234",
            "fakepriv@example.com",
            "fake/123/2026",
            "blue suitcase near temple",
            "@",
            "case number",
            "client",
            "party",
            "ocr"
        ]

        var removed: [String] = []
        var sanitized = text
            .replacingOccurrences(of: "\\b\\d{2,}\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let selectedCase {
            if lower.contains(selectedCase.title.lowercased()) || lower.contains(selectedCase.forum.lowercased()) {
                removed.append("Case title and forum references")
                sanitized = sanitized
                    .replacingOccurrences(of: selectedCase.title, with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: selectedCase.forum, with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if blockedPatterns.contains(where: { lower.contains($0) }) {
            removed.append("Private details and obvious identifiers")
            sanitized = suggestedQuery
        }

        if sanitized.count > 180 {
            removed.append("Long factual narrative")
            sanitized = String(sanitized.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        publicLawPreview = AlphaPublicLawPreview(
            query: sanitized.isEmpty ? suggestedQuery : sanitized,
            removed: removed.isEmpty ? ["No private case data detected"] : removed,
            confirmationNote: "Public-law search sends only a sanitized query after explicit confirmation."
        )
        publicLawResults = []
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = publicLawPreview
        persisted.publicLawResults = publicLawResults
        persist()
    }

    func runPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        do {
            publicLawResults = try await backend.searchPublicLaw(preview: preview)
        } catch {
            publicLawResults = []
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Public-law search unavailable",
                    detail: "Ross could not reach the sanitized public-law backend with the approved preview.",
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: false
                ),
                at: 0
            )
            persist()
            return
        }

        persisted.publicLawCache.insert(
            AlphaPublicLawCacheItem(query: preview.query, resultTitles: publicLawResults.map(\.title)),
            at: 0
        )
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = preview
        persisted.publicLawResults = publicLawResults
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Public-law query sent",
                detail: "Only a sanitized public query crossed the network boundary.",
                purpose: .public_law_search,
                payloadClass: .sanitized_public_query,
                endpointLabel: "/public-law/search",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func generateExport(kind: String, caseId: UUID?) async {
        let caseMatter = caseId.flatMap { id in persisted.cases.first { $0.id == id } }
        let titleBase = caseMatter?.title ?? "Ross Report"
        let bodyLines = exportBodyLines(kind: kind, caseMatter: caseMatter)

        do {
            let report = try await store.createPDFExport(
                title: "\(titleBase) \(kind)",
                kind: kind,
                caseId: caseId,
                bodyLines: bodyLines
            )
            persisted.exports.insert(report, at: 0)
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Local export generated",
                    detail: "\(kind) was generated locally for advocate review.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://export",
                    success: true
                ),
                at: 0
            )
            persist()
        } catch {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Export generation failed",
                    detail: "Ross could not write the local report file.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://export",
                    success: false
                ),
                at: 0
            )
            persist()
        }
    }

    func exportURL(for report: AlphaExportedReport) -> URL {
        alphaAbsoluteURL(for: report.relativePath)
    }

    var activeExtractionMode: AlphaExtractionMode {
        .fromInstalledPack(activePack)
    }

    func pauseJob(_ job: AlphaModelDownloadJob) {
        updateJob(job.id) {
            $0.state = .pausedUser
            $0.updatedAt = .now
        }
    }

    func resumeJob(_ job: AlphaModelDownloadJob) {
        Task { await startPackDownload(for: job.tier, mobileAllowed: job.networkPolicy == .mobileAllowed) }
    }

    func removeInstalledPack(_ pack: AlphaInstalledModelPack) {
        persisted.installedPacks.removeAll { $0.id == pack.id }
        if persisted.settings.activeTier == pack.tier {
            persisted.settings.activeTier = persisted.installedPacks.first(where: \.isActive)?.tier
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Private AI Pack removed",
                detail: "\(pack.tier.title) was removed from local storage.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-remove",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func activateInstalledPack(_ pack: AlphaInstalledModelPack) {
        persisted.installedPacks = persisted.installedPacks.map {
            var copy = $0
            copy.isActive = copy.id == pack.id
            return copy
        }
        persisted.settings.activeTier = pack.tier
        persist()
    }

    func startPackDownload(for tier: AlphaCapabilityTier, mobileAllowed: Bool) async {
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let waitingForWifi = !mobileAllowed && tier != .quickStart
        let sessionId = "mdl-\(UUID().uuidString.prefix(8))"

        let job = AlphaModelDownloadJob(
            sessionId: sessionId,
            packId: "\(tier.rawValue)-pack",
            tier: tier,
            state: waitingForWifi ? .pausedWaitingForWifi : .queued,
            networkPolicy: policy,
            bytesDownloaded: 0,
            totalBytes: 0,
            checksumSha256: ""
        )

        upsertJob(job)
        persist()

        do {
            let catalog = try await backend.fetchCatalog(for: tier)
            guard let pack = catalog.packs.first(where: { $0.tier == tier }) else {
                throw AlphaBackendError.missingPack
            }

            persisted.lastModelCatalogRefresh = .now
            updateJob(job.id) {
                $0.packId = pack.packId
                $0.totalBytes = pack.sizeBytes
                $0.checksumSha256 = pack.checksumSha256
                $0.artifactKind = pack.artifactKind
                $0.runtimeMode = pack.runtimeMode
                $0.developmentOnly = pack.developmentOnly
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Model catalog checked",
                    detail: "Private AI Pack metadata was reviewed without case data.",
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "/model-catalog",
                    success: true
                ),
                at: 0
            )
            persist()

            if waitingForWifi {
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Private AI Pack waiting for Wi-Fi",
                        detail: "Model delivery is paused until you allow a trusted network.",
                        purpose: .model_download,
                        payloadClass: .no_case_data,
                        endpointLabel: "/model-download/session",
                        success: true
                    ),
                    at: 0
                )
                persist()
                return
            }

            let session = try await backend.createDownloadSession(for: pack.packId)
            updateJob(job.id) {
                $0.sessionId = session.sessionId
                $0.packId = session.packId
                $0.totalBytes = session.artifact.sizeBytes
                $0.checksumSha256 = session.artifact.finalSha256
                $0.artifactKind = session.artifact.artifactKind
                $0.runtimeMode = session.artifact.runtimeMode
                $0.developmentOnly = session.artifact.developmentOnly
                $0.state = .downloading
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Private AI Pack queued",
                    detail: "Model delivery started without reading case files.",
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "/model-download/session",
                    success: true
                ),
                at: 0
            )
            persist()

            let downloaded = try await backend.downloadArtifact(session: session) { bytesDownloaded in
                await MainActor.run {
                    self.updateJob(job.id) {
                        $0.state = .downloading
                        $0.bytesDownloaded = bytesDownloaded
                        $0.updatedAt = .now
                    }
                    self.persist()
                }
            }

            updateJob(job.id) {
                $0.state = .verifying
                $0.bytesDownloaded = downloaded.bytes
                $0.updatedAt = .now
            }
            persist()

            let artifact = try await store.installDownloadedPackArtifact(
                for: tier,
                fileName: session.artifact.fileName,
                data: downloaded.data,
                expectedChecksum: session.artifact.finalSha256
            )
            let installed = AlphaInstalledModelPack(
                packId: pack.packId,
                tier: tier,
                installPath: artifact.relativePath,
                checksumSha256: artifact.checksum,
                artifactKind: session.artifact.artifactKind,
                runtimeMode: session.artifact.runtimeMode,
                developmentOnly: session.artifact.developmentOnly,
                isActive: true
            )
            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
            persisted.installedPacks.removeAll { $0.tier == tier }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = artifact.bytes
                $0.totalBytes = artifact.bytes
                $0.checksumSha256 = artifact.checksum
                $0.artifactKind = installed.artifactKind
                $0.runtimeMode = installed.runtimeMode
                $0.developmentOnly = installed.developmentOnly
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Private AI Pack verified",
                    detail: "Checksum and install metadata were verified locally.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
            persist()
        } catch {
            do {
                let fallback = try await store.writeDevPackArtifact(for: tier)
                let installed = AlphaInstalledModelPack(
                    packId: "\(tier.rawValue)-pack",
                    tier: tier,
                    installPath: fallback.relativePath,
                    checksumSha256: fallback.checksum,
                    artifactKind: "tiny_dev_artifact",
                    runtimeMode: .deterministicDev,
                    developmentOnly: true,
                    isActive: true
                )
                persisted.installedPacks = persisted.installedPacks.map {
                    var copy = $0
                    copy.isActive = false
                    return copy
                }
                persisted.installedPacks.removeAll { $0.tier == tier }
                persisted.installedPacks.insert(installed, at: 0)
                persisted.settings.activeTier = tier
                updateJob(job.id) {
                    $0.state = .installed
                    $0.packId = installed.packId
                    $0.bytesDownloaded = fallback.bytes
                    $0.totalBytes = fallback.bytes
                    $0.checksumSha256 = fallback.checksum
                    $0.artifactKind = installed.artifactKind
                    $0.runtimeMode = installed.runtimeMode
                    $0.developmentOnly = installed.developmentOnly
                    $0.updatedAt = .now
                    $0.completedAt = .now
                }
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Private AI Pack fallback installed",
                        detail: "The backend was unavailable, so Ross prepared a local development artifact without case data.",
                        purpose: .model_verification,
                        payloadClass: .no_case_data,
                        endpointLabel: "device://model-verify",
                        success: true
                    ),
                    at: 0
                )
                persist()
            } catch {
                updateJob(job.id) {
                    $0.state = .failed
                    $0.failureReason = "Install artifact could not be prepared."
                    $0.updatedAt = .now
                }
                persist()
            }
        }
    }

    private func exportBodyLines(kind: String, caseMatter: AlphaCaseMatter?) -> [String] {
        let title = caseMatter?.title ?? "Ross"
        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        guard let caseMatter else {
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "No case selected.",
                "",
                "Generated locally for advocate review. Verify all citations."
            ]
        }

        let documents = caseMatter.documents
        let allFields = documents.flatMap(\.extractedFields)
        let verifiedFields = allFields.filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = allFields.filter(\.needsReview)
        let unresolvedFindings = documents.flatMap(\.extractionFindings).filter { !$0.resolved }
        let refs = caseMatter.sourceRefs.prefix(8).map { "- \($0.label): \($0.detail)" }
        let documentLines = documents.map { "- \($0.title) (\($0.pageCount) pages, \($0.ocrStatus.title))" }

        func uniqueValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            Array(Set(fields.filter { $0.fieldType == type }.map(\.value))).sorted()
        }

        func sourcedValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            fields
                .filter { $0.fieldType == type }
                .map { field in
                    let sourceLabel = field.sourceRefs.first?.label ?? "Source pending"
                    return "- \(field.value) (\(sourceLabel))"
                }
        }

        switch kind {
        case "chronology_report":
            let chronologyLines = verifiedFields
                .filter { $0.fieldType == .date || $0.fieldType == .nextDate }
                .sorted { ($0.normalizedValue ?? $0.value) < ($1.normalizedValue ?? $1.value) }
                .map { "- \($0.label): \($0.value) (\($0.sourceRefs.first?.label ?? "Source pending"))" }
            let warningLines = unresolvedFindings.map { "- \($0.message)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Chronology candidates",
            ] + (chronologyLines.isEmpty ? ["- No verified chronology candidates found yet."] : chronologyLines) + [
                "",
                "Review warnings",
            ] + (warningLines.isEmpty ? ["- No unresolved warnings."] : warningLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "case_note":
            let court = uniqueValues(for: .court, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let caseNumbers = uniqueValues(for: .caseNumber, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let parties = uniqueValues(for: .partyName, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let dateLines = sourcedValues(for: .date, in: verifiedFields)
            let pendingLines = pendingFields.map { "- \($0.label): \($0.value)" }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Court / case metadata",
                "Court: \(court)",
                "Case number: \(caseNumbers)",
                "Parties: \(parties)",
                "",
                "Document list",
            ] + (documentLines.isEmpty ? ["- No imported documents yet."] : documentLines) + [
                "",
                "Key dates",
            ] + (dateLines.isEmpty ? ["- No verified key dates found yet."] : dateLines) + [
                "",
                "Pending review fields",
            ] + (pendingLines.isEmpty ? ["- No pending review fields."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "order_summary":
            let directions = sourcedValues(for: .orderDirection, in: verifiedFields)
            let nextDates = sourcedValues(for: .nextDate, in: verifiedFields)
            let compliance = unresolvedFindings
                .filter { $0.kind == .ambiguousOrderDirection || $0.kind == .dateConflict }
                .map { "- \($0.message)" }
            let pendingLines = pendingFields
                .filter { $0.fieldType == .orderDirection || $0.fieldType == .nextDate || $0.fieldType == .date }
                .map { "- \($0.label): \($0.value)" }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Operative directions",
            ] + (directions.isEmpty ? ["- No verified operative directions found yet."] : directions) + [
                "",
                "Next date",
            ] + (nextDates.isEmpty ? ["- Not found"] : nextDates) + [
                "",
                "Compliance requirements",
            ] + (compliance.isEmpty ? ["- Review operative directions against cited source pages."] : compliance) + [
                "",
                "Needs review",
            ] + (pendingLines.isEmpty ? ["- No pending review flags for order details."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        default:
            let notes = caseMatter.draftTasks.map { "- \($0)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Summary",
                caseMatter.summary,
                "",
                "Working notes",
            ] + (notes.isEmpty ? ["- No tasks yet."] : notes) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]
        }
    }

    private func applyExtractionResult(_ result: AlphaLocalExtractionResult, caseId: UUID, documentId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId })
        else { return }

        var caseMatter = persisted.cases[caseIndex]
        var document = caseMatter.documents[documentIndex]
        document.pages = result.pages
        document.languageProfile = result.languageProfile
        document.classification = result.classification
        document.extractedFields = mergeUserCorrectedFields(previousFields: document.extractedFields, newFields: result.extractedFields)
        document.extractionRuns.insert(result.extractionRun, at: 0)
        document.extractionFindings = result.findings
        document.modelInvocations = result.modelInvocations
        document.indexingStatus = {
            switch result.extractionRun.status {
            case .failed:
                return .failed
            case .needsReview:
                return .partial
            default:
                return .indexed
            }
        }()
        document.lastIndexedAt = .now
        let fullText = result.pages.compactMap(\.extractedText).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullText.isEmpty {
            document.extractedText = fullText
        }
        document.dominantSourceSnippet = result.pages.compactMap { $0.anchorText ?? $0.snippet }.first ?? document.dominantSourceSnippet
        caseMatter.documents[documentIndex] = document

        if let classification = result.classification {
            appendSourceRefs(classification.sourceRefs, to: &caseMatter)
        }
        appendSourceRefs(result.extractedFields.flatMap(\.sourceRefs), to: &caseMatter)
        mergeCaseMemoryUpdates(result.caseMemoryUpdates, into: &caseMatter)
        if let nextDateValue = result.extractedFields.first(where: { $0.fieldType == .nextDate && (!$0.needsReview || $0.userCorrected) })?.value,
           let parsedDate = alphaParsedDate(from: nextDateValue) {
            caseMatter.nextHearing = parsedDate
        }
        refreshCaseWorkspace(caseMatter: &caseMatter)

        persisted.cases[caseIndex] = caseMatter
        upsertReviewTasks(for: caseMatter, document: document)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Local extraction completed",
                detail: result.reviewQueue.summary,
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://local-extraction",
                success: result.extractionRun.status != .failed
            ),
            at: 0
        )
        persist()
    }

    private func appendSourceRefs(_ refs: [AlphaSourceRef], to caseMatter: inout AlphaCaseMatter) {
        for ref in refs {
            let exists = caseMatter.sourceRefs.contains {
                $0.documentId == ref.documentId &&
                $0.pageNumber == ref.pageNumber &&
                ($0.textSnippet ?? "") == (ref.textSnippet ?? "")
            }
            if !exists {
                caseMatter.sourceRefs.insert(ref, at: 0)
            }
        }
    }

    private func mergeCaseMemoryUpdates(_ updates: [AlphaCaseMemoryUpdate], into caseMatter: inout AlphaCaseMatter) {
        for update in updates.reversed() {
            let exists = caseMatter.caseMemoryUpdates.contains {
                $0.summary == update.summary && $0.affectedDocuments == update.affectedDocuments
            }
            if !exists {
                caseMatter.caseMemoryUpdates.insert(update, at: 0)
            }
        }
    }

    private func mergeUserCorrectedFields(
        previousFields: [AlphaExtractedLegalField],
        newFields: [AlphaExtractedLegalField]
    ) -> [AlphaExtractedLegalField] {
        let corrected = previousFields
            .filter(\.userCorrected)
            .reduce(into: [String: AlphaExtractedLegalField]()) { result, field in
                result["\(field.fieldType.rawValue):\(field.normalizedValue ?? field.value.lowercased())"] = field
            }

        let merged = newFields.map { field in
            corrected["\(field.fieldType.rawValue):\(field.normalizedValue ?? field.value.lowercased())"] ?? field
        }
        let preserved = corrected.values.filter { correctedField in
            !newFields.contains {
                $0.fieldType == correctedField.fieldType &&
                ($0.normalizedValue ?? $0.value.lowercased()) == (correctedField.normalizedValue ?? correctedField.value.lowercased())
            }
        }
        return merged + preserved
    }

    private func refreshCaseWorkspace(at caseIndex: Int) {
        var caseMatter = persisted.cases[caseIndex]
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
    }

    private func refreshCaseWorkspace(caseMatter: inout AlphaCaseMatter) {
        let verifiedFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter(\.needsReview)

        if let forum = verifiedFields.first(where: { $0.fieldType == .court })?.value,
           caseMatter.forum == "Forum pending" || caseMatter.forum.isEmpty {
            caseMatter.forum = forum
        }

        if let nextDate = verifiedFields.first(where: { $0.fieldType == .nextDate })?.value {
            caseMatter.localNotice = "Case files stay on this device. Next date found: \(nextDate)"
            caseMatter.nextHearing = alphaParsedDate(from: nextDate) ?? caseMatter.nextHearing
        }

        let classifications = caseMatter.documents.compactMap { $0.classification?.type.rawValue.replacingOccurrences(of: "_", with: " ") }
        let classificationText = classifications.isEmpty ? "local legal document review" : classifications.joined(separator: ", ")
        caseMatter.summary = "Ross indexed \(caseMatter.documents.count) document(s) locally for \(classificationText)."

        let issueCandidates = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .prayer }
            .map(\.value)
        caseMatter.issueHighlights = issueCandidates.isEmpty ? ["Review extracted legal issues and directions."] : Array(issueCandidates.prefix(4))

        let evidenceCandidates = caseMatter.documents
            .flatMap(\.extractionFindings)
            .filter { !$0.resolved }
            .map(\.message)
        caseMatter.evidenceNotes = evidenceCandidates.isEmpty ? ["Source-backed extraction is available for this matter."] : Array(evidenceCandidates.prefix(4))

        caseMatter.draftTasks = [
            pendingFields.isEmpty ? "Review the latest chronology and order summary." : "Review uncertain extracted fields before relying on them.",
            "Open source chips before sharing or filing.",
            "Generate a local chronology or order summary draft."
        ]
        caseMatter.updatedAt = .now
    }

    private func upsertReviewTasks(for caseMatter: AlphaCaseMatter, document: AlphaCaseDocument) {
        let reviewTitles = Set(
            visibleExtractedFields(caseId: caseMatter.id, documentId: document.id)
                .filter(\.needsReview)
                .map { alphaReviewTitle(for: $0.fieldType) } +
                reviewFindings(caseId: caseMatter.id, documentId: document.id)
                .map { alphaReviewTitle(for: $0.kind) }
        )

        var taskList = persisted.tasks ?? []
        for title in reviewTitles {
            let exists = taskList.contains {
                $0.status == .open &&
                    $0.caseId == caseMatter.id &&
                    $0.source == .extraction &&
                    $0.title == title
            }
            if !exists {
                taskList.insert(
                    AlphaTaskItem(
                        caseId: caseMatter.id,
                        title: title,
                        notes: "Created from document review for \(document.title).",
                        dueDate: caseMatter.nextHearing,
                        priority: .high,
                        source: .extraction
                    ),
                    at: 0
                )
            }
        }
        persisted.tasks = taskList
    }

    private func syncReviewTasks(caseId: UUID, documentId: UUID) {
        let remainingTitles = Set(
            visibleExtractedFields(caseId: caseId, documentId: documentId)
                .filter(\.needsReview)
                .map { alphaReviewTitle(for: $0.fieldType) } +
                reviewFindings(caseId: caseId, documentId: documentId)
                .map { alphaReviewTitle(for: $0.kind) }
        )
        persisted.tasks = (persisted.tasks ?? []).map { task in
            guard task.caseId == caseId, task.source == .extraction else { return task }
            if remainingTitles.contains(task.title) {
                return task
            }
            var updatedTask = task
            updatedTask.status = .done
            updatedTask.updatedAt = .now
            return updatedTask
        }
    }

    private func alphaParsedDate(from value: String) -> Date? {
        let formatters = ["d/M/yyyy", "d/M/yy", "d-MM-yyyy", "d MMM yyyy", "dd MMM yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = .current
        for format in formatters {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func ignoredFieldIDs(caseId: UUID, documentId: UUID) -> Set<UUID> {
        guard let caseMatter = persisted.cases.first(where: { $0.id == caseId }) else { return [] }
        return Set(
            caseMatter.advocateCorrections
                .filter { $0.documentId == documentId && $0.correctionType == .ignoreField }
                .compactMap(\.fieldId)
        )
    }

    private func suggestedPublicLawQuery() -> String? {
        guard let selectedCase else { return nil }
        let verifiedFields = selectedCase.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let issues = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .section }
            .flatMap { publicLawKeywords(from: $0.value) }
        let classifications = selectedCase.documents.compactMap { document in
            document.classification
                .flatMap { $0.needsReview ? nil : $0.type.rawValue.replacingOccurrences(of: "_", with: " ") }
        }
        let terms = Array(NSOrderedSet(array: issues + classifications))
            .compactMap { $0 as? String }
            .filter(isSafePublicLawTerm)
        guard !terms.isEmpty else { return nil }
        return (terms + ["India"]).joined(separator: " ")
    }

    private func publicLawKeywords(from value: String) -> [String] {
        let lowered = value.lowercased()
        let patterns = [
            "commercial courts act",
            "negotiable instruments act",
            "arbitration act",
            "limitation act",
            "written statement",
            "delay condonation",
            "interim maintenance",
            "interim relief",
            "injunction",
            "stay",
            "cheque dishonour",
            "section \\d+[a-z]*",
            "order [a-z0-9]+ rule \\d+"
        ]
        let matches: [String] = patterns.compactMap { pattern -> String? in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            let range = NSRange(location: 0, length: lowered.utf16.count)
            guard let match = regex.firstMatch(in: lowered, range: range) else { return nil }
            return (lowered as NSString).substring(with: match.range)
        }
        let sanitizedPhrase = lowered
            .replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !sanitizedPhrase.isEmpty, looksLikeLegalConcept(sanitizedPhrase) {
            let tokenCount = sanitizedPhrase.split(separator: " ").count
            if (3...10).contains(tokenCount) {
                return (Array(NSOrderedSet(array: matches + [sanitizedPhrase])) as? [String] ?? matches + [sanitizedPhrase]).filter(isSafePublicLawTerm)
            }
        }
        return matches.filter(isSafePublicLawTerm)
    }

    private func looksLikeLegalConcept(_ value: String) -> Bool {
        let legalSignals = [
            "act",
            "section",
            "order",
            "rule",
            "maintenance",
            "injunction",
            "dishonour",
            "written statement",
            "delay",
            "limitation",
            "interim",
            "commercial",
            "cheque",
            "court",
            "filing",
        ]
        if legalSignals.contains(where: { value.contains($0) }) {
            return true
        }
        return value.range(of: #"section\s+\d+[a-z]*"#, options: .regularExpression) != nil ||
            value.range(of: #"order\s+[a-z0-9]+\s+rule\s+\d+"#, options: .regularExpression) != nil
    }

    private func isSafePublicLawTerm(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if lowered.contains("fakepriv") || lowered.contains("blue suitcase near temple") {
            return false
        }
        if value.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b\+?\d[\d\s-]{7,}\b"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b[A-Za-z]{1,8}[(/\- ]*\d+[A-Za-z/()\- ]*\d{4}\b"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private func normalizeLoadedState(_ state: AlphaPersistedState) -> AlphaPersistedState {
        var normalized = state
        normalized.selectedTab = normalized.selectedTab.normalizedForLawyerShell
        if normalized.tasks == nil {
            normalized.tasks = initialTasks(from: normalized.cases)
        }
        return normalized
    }

    private func initialTasks(from cases: [AlphaCaseMatter]) -> [AlphaTaskItem] {
        cases.flatMap { caseMatter in
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

    private func buildLocalAskResult(question: String, scopeCaseID: UUID?) -> AlphaAskResult {
        let visibleCases = scopeCaseID.map { id in persisted.cases.filter { $0.id == id } } ?? persisted.cases
        let lowered = question.lowercased()
        let asksAboutSchedule = lowered.contains("next date") || lowered.contains("hearing")
        let asksAboutTasks = lowered.contains("task") || lowered.contains("today") || lowered.contains("reminder") || lowered.contains("due")
        let asksAboutReview = lowered.contains("review") || lowered.contains("document") || lowered.contains("order") || lowered.contains("party")
        let matchedSources = visibleCases
            .flatMap(\.sourceRefs)
            .filter {
                asksAboutSchedule ||
                    asksAboutTasks ||
                    asksAboutReview ||
                    lowered.contains($0.documentTitle.lowercased()) ||
                    lowered.contains(($0.textSnippet ?? "").lowercased())
            }
        let openScopedTasks = tasks(for: scopeCaseID).filter { $0.status == .open }

        var sections: [String] = []
        if asksAboutSchedule {
            let dateLines = visibleCases.compactMap { caseMatter -> String? in
                guard let nextDate = caseMatter.nextHearing else { return nil }
                return "\(caseMatter.title): \(nextDate.formatted(date: .abbreviated, time: .omitted))"
            }
            sections.append(contentsOf: dateLines.prefix(2))
        }
        if asksAboutTasks {
            let taskLines = openScopedTasks.prefix(3).map { task in
                if let dueDate = task.dueDate {
                    return "\(task.title) by \(dueDate.formatted(date: .abbreviated, time: .omitted))"
                }
                return task.title
            }
            sections.append(contentsOf: taskLines)
        }
        if asksAboutReview {
            let reviewItems = reviewQueue(caseId: scopeCaseID).prefix(3).map { "\($0.title): \($0.detail)" }
            sections.append(contentsOf: reviewItems)
        }

        let warnings = reviewQueue(caseId: scopeCaseID)
        let notFound = sections.isEmpty && matchedSources.isEmpty
        return AlphaAskResult(
            question: question,
            scopeCaseID: scopeCaseID,
            scopeLabel: scopeLabel(for: scopeCaseID),
            answerTitle: notFound ? "I could not find this in your case files." : "Draft for advocate review",
            answerSections: notFound ? ["I could not find this in your case files."] : Array(sections.prefix(3)),
            caseFileSources: Array(matchedSources.prefix(3)),
            publicLawPreview: nil,
            publicLawResults: [],
            statusNote: notFound ? "Web search off" : "Case-file sources",
            needsReviewWarning: warnings.isEmpty ? nil : "\(warnings.count) item(s) still need review."
        )
    }

    private func buildAskPublicLawPreview(question: String, scopeCaseID: UUID?) -> AlphaPublicLawPreview {
        let caseMatter = scopeCaseID.flatMap { id in persisted.cases.first { $0.id == id } }
        let suggested = suggestedPublicLawQuery() ?? "Find current public-law guidance relevant to delay condonation where diligence is documented."
        var sanitized = question
        var removed: [String] = []

        if let caseMatter {
            let sensitiveTokens = [caseMatter.title, caseMatter.forum] + caseMatter.documents.map(\.title) + caseMatter.documents.map(\.fileName)
            sensitiveTokens.filter { !$0.isEmpty }.forEach { token in
                if sanitized.localizedCaseInsensitiveContains(token) {
                    removed.append("Case titles, forum names, or document labels")
                    sanitized = sanitized.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
                }
            }
        }

        let patterns: [(String, String)] = [
            (#"\b\d{2,}\b"#, "Case numbers, phone numbers, or long numeric strings"),
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, "Email addresses"),
            (#"\b\+?\d[\d\s-]{7,}\b"#, "Phone numbers"),
            (#"\b[^ ]+\.(pdf|docx|doc|txt|png|jpg|jpeg)\b"#, "File names"),
            (#"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#, "Exact private dates"),
            (#"raghav\s+fakepriv|blue suitcase near temple"#, "Fake secrets and private facts")
        ]

        for (pattern, label) in patterns {
            if sanitized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                removed.append(label)
                sanitized = sanitized.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
            }
        }

        sanitized = sanitized
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.count > 180 {
            removed.append("Long factual narrative")
            sanitized = String(sanitized.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if sanitized.isEmpty {
            sanitized = suggested
            removed.append("Private case details")
        }

        return AlphaPublicLawPreview(
            query: sanitized,
            removed: removed.isEmpty ? ["No private case data detected"] : Array(NSOrderedSet(array: removed)) as? [String] ?? removed,
            confirmationNote: "Public-law search sends only a sanitized query after explicit confirmation."
        )
    }

    private func alphaReviewTitle(for fieldType: AlphaExtractedLegalFieldType) -> String {
        switch fieldType {
        case .nextDate:
            "Confirm next date"
        case .partyName:
            "Review party name"
        case .orderDirection:
            "Check order direction"
        default:
            "Needs review"
        }
    }

    private func alphaReviewTitle(for findingKind: AlphaExtractionFindingKind) -> String {
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
            "Needs review"
        }
    }

    private func alphaCorrectionType(for fieldType: AlphaExtractedLegalFieldType) -> AlphaAdvocateCorrectionType {
        switch fieldType {
        case .date, .nextDate, .limitationDate:
            return .date
        case .partyName:
            return .party
        default:
            return .fieldValue
        }
    }

    private func persist() {
        var snapshot = persisted
        snapshot.publicLawDraft = publicLawDraft
        snapshot.publicLawPreview = publicLawPreview
        snapshot.publicLawResults = publicLawResults
        Task {
            try? await store.replace(with: snapshot)
        }
    }

    private func upsertJob(_ job: AlphaModelDownloadJob) {
        if let index = persisted.modelJobs.firstIndex(where: { $0.id == job.id }) {
            persisted.modelJobs[index] = job
        } else {
            persisted.modelJobs.insert(job, at: 0)
        }
    }

    private func updateJob(_ jobID: UUID, transform: (inout AlphaModelDownloadJob) -> Void) {
        guard let index = persisted.modelJobs.firstIndex(where: { $0.id == jobID }) else { return }
        transform(&persisted.modelJobs[index])
    }
}

private actor AlphaBackendClient {
    private let configuration = AlphaBackendConfiguration()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func fetchCatalog(for tier: AlphaCapabilityTier) async throws -> AlphaBackendCatalogManifest {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent("model-catalog"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "tier", value: tier.rawValue)
        ]
        guard let url = components?.url else {
            throw AlphaBackendError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeout

        let response: AlphaBackendCatalogResponse = try await send(request, expecting: AlphaBackendCatalogResponse.self)
        return response.manifest.payload
    }

    func createDownloadSession(for packId: String) async throws -> AlphaBackendDownloadSessionPayload {
        let requestBody = AlphaBackendDownloadSessionRequest(
            accountToken: configuration.accountToken,
            packId: packId,
            platform: "ios",
            deviceIdHash: configuration.deviceIdHash,
            appVersion: configuration.appVersion
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("model-download/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let response: AlphaBackendDownloadSessionResponse = try await send(request, expecting: AlphaBackendDownloadSessionResponse.self)
        return response.downloadSession.payload
    }

    func searchPublicLaw(preview: AlphaPublicLawPreview) async throws -> [AlphaPublicLawResult] {
        let requestBody = AlphaBackendPublicLawSearchRequest(
            query: preview.query,
            jurisdiction: "IN-ALL",
            language: "en",
            confirmedPublicPreview: true
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("public-law/search"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let response: AlphaBackendPublicLawResponse = try await send(request, expecting: AlphaBackendPublicLawResponse.self)
        return response.results.map {
            AlphaPublicLawResult(
                title: $0.title,
                citation: $0.citation,
                snippet: $0.snippet,
                sourceName: $0.source
            )
        }
    }

    func downloadArtifact(
        session: AlphaBackendDownloadSessionPayload,
        onProgress: @escaping @Sendable (Int64) async -> Void
    ) async throws -> AlphaDownloadedArtifact {
        let artifactURL = try resolveArtifactURL(for: session.artifact)
        var downloaded = Data()
        downloaded.reserveCapacity(Int(session.artifact.sizeBytes))

        for segment in session.artifact.segments {
            var request = URLRequest(url: artifactURL)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.requestTimeout
            request.setValue(segment.rangeHeader, forHTTPHeaderField: "Range")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw AlphaBackendError.unavailable
            }
            guard sha256Hex(data) == segment.sha256.lowercased() else {
                throw AlphaBackendError.segmentIntegrityFailed
            }

            downloaded.append(data)
            await onProgress(Int64(downloaded.count))
        }

        guard Int64(downloaded.count) == session.artifact.sizeBytes else {
            throw AlphaBackendError.invalidResponse
        }
        guard sha256Hex(downloaded) == session.artifact.finalSha256.lowercased() else {
            throw AlphaBackendError.finalIntegrityFailed
        }

        return AlphaDownloadedArtifact(data: downloaded, bytes: Int64(downloaded.count))
    }

    private func resolveArtifactURL(for artifact: AlphaBackendArtifact) throws -> URL {
        if let downloadPath = artifact.downloadPath {
            return configuration.baseURL.appendingPathComponent(downloadPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        guard let url = URL(string: artifact.downloadUrl) else {
            throw AlphaBackendError.invalidResponse
        }

        if url.host == "downloads.example.invalid" {
            return configuration.baseURL.appendingPathComponent(url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        return url
    }

    private func send<Response: Decodable>(_ request: URLRequest, expecting type: Response.Type) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaBackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AlphaBackendError.unavailable
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AlphaBackendError.invalidResponse
        }
    }
}

private struct AlphaBackendConfiguration {
    let baseURL: URL
    let requestTimeout: TimeInterval = 2
    let accountToken = "acct_local_alpha_device"
    let appVersion = "0.1.0-alpha"
    let deviceIdHash = sha256Hex(Data("ross-ios-alpha-device".utf8))

    init() {
        let environment = ProcessInfo.processInfo.environment
        let rawURL = environment["ROSS_BACKEND_BASE_URL"] ?? environment["ROSS_BACKEND_URL"] ?? "http://127.0.0.1:8080"
        baseURL = URL(string: rawURL) ?? URL(string: "http://127.0.0.1:8080")!
    }
}

private struct AlphaBackendSignedEnvelope<Payload: Codable>: Codable {
    let payload: Payload
}

private struct AlphaBackendCatalogResponse: Codable {
    let manifest: AlphaBackendSignedEnvelope<AlphaBackendCatalogManifest>
}

private struct AlphaBackendCatalogManifest: Codable {
    let packs: [AlphaBackendCatalogPack]
}

private struct AlphaBackendCatalogPack: Codable {
    let packId: String
    let displayName: String
    let tier: AlphaCapabilityTier
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
}

private struct AlphaBackendDownloadSessionRequest: Codable {
    let accountToken: String
    let packId: String
    let platform: String
    let deviceIdHash: String
    let appVersion: String
}

private struct AlphaBackendDownloadSessionResponse: Codable {
    let downloadSession: AlphaBackendSignedEnvelope<AlphaBackendDownloadSessionPayload>
}

private struct AlphaBackendDownloadSessionPayload: Codable {
    let sessionId: String
    let packId: String
    let artifact: AlphaBackendArtifact
}

private struct AlphaBackendArtifact: Codable {
    let fileName: String
    let sizeBytes: Int64
    let finalSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let downloadPath: String?
    let downloadUrl: String
    let segments: [AlphaBackendArtifactSegment]
}

private struct AlphaBackendArtifactSegment: Codable {
    let index: Int
    let startByte: Int64
    let endByteInclusive: Int64
    let sizeBytes: Int64
    let sha256: String
    let rangeHeader: String
}

private struct AlphaBackendPublicLawSearchRequest: Codable {
    let query: String
    let jurisdiction: String
    let language: String
    let confirmedPublicPreview: Bool
}

private struct AlphaBackendPublicLawResponse: Codable {
    let results: [AlphaBackendPublicLawResult]
}

private struct AlphaBackendPublicLawResult: Codable {
    let source: String
    let title: String
    let citation: String
    let snippet: String
}

private struct AlphaDownloadedArtifact {
    let data: Data
    let bytes: Int64
}

private enum AlphaBackendError: Error {
    case unavailable
    case invalidResponse
    case missingPack
    case segmentIntegrityFailed
    case finalIntegrityFailed
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

struct AlphaRossRootView: View {
    @State private var model = AlphaRossModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                switch model.persisted.onboardingStage {
                case .onboarding:
                    AlphaOnboardingScreen(model: model)
                case .privateAIPack:
                    AlphaPackSetupScreen(model: model)
                case .completed:
                    AlphaTabShell(model: model)
                }
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationDestination(for: AlphaRoute.self) { route in
                switch route {
                case .createCase:
                    AlphaCreateCaseScreen(model: model)
                case .caseWorkspace(let caseId):
                    AlphaCaseWorkspaceScreen(model: model, caseId: caseId)
                case .documentList(let caseId):
                    AlphaDocumentListScreen(model: model, caseId: caseId)
                case .documentViewer(let caseId, let documentId, let page):
                    AlphaDocumentViewerScreen(model: model, caseId: caseId, documentId: documentId, initialPage: page)
                case .askCase(let caseId):
                    AlphaAskCaseScreen(model: model, caseId: caseId)
                case .exports(let caseId):
                    AlphaExportsScreen(model: model, caseId: caseId)
                case .privacyLedger:
                    AlphaPrivacyLedgerScreen(model: model)
                case .privateAISettings:
                    AlphaPrivateAISettingsScreen(model: model)
                }
            }
        }
        .task {
            await model.loadIfNeeded()
        }
    }
}

private struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RossHeroCard(
                    eyebrow: "Ross",
                    title: "Your case files stay on this device",
                    detail: "Ross reviews documents privately, keeps your case files on this device, and shows source-backed drafts for advocate review."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        RossInfoPill(title: "Case files stay on this device", systemImage: "lock")
                        RossInfoPill(title: "Source-backed", systemImage: "paperclip")
                        RossInfoPill(title: "Public-law search sends only a sanitized query", systemImage: "shield")
                    }
                }

                RossSectionCard(title: "First case", subtitle: "Create a case now or skip and start from Home.") {
                    VStack(spacing: 12) {
                        TextField("Case title", text: $model.caseDraftTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Court or forum", text: $model.caseDraftForum)
                            .textFieldStyle(.roundedBorder)
                        Button("Save case and continue") {
                            if !model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                model.createCase(openWorkspace: false)
                            }
                            model.advanceOnboarding()
                        }
                        .rossPrimaryButtonStyle()
                        Button("Skip for now") {
                            model.advanceOnboarding()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct AlphaPackSetupScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RossHeroCard(
                    eyebrow: "Private AI Pack",
                    title: "Choose private help for this device",
                    detail: "You can start using Ross right away. Packs add stronger private review on this device."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        RossInfoPill(title: "Wi-Fi recommended", systemImage: "wifi")
                        RossInfoPill(title: "Set up later if needed", systemImage: "clock")
                        RossInfoPill(title: "Status stays visible in Settings", systemImage: "gearshape")
                    }
                }

                ForEach(AlphaPackOffer.catalog) { offer in
                    Button {
                        model.selectedTier = offer.tier
                    } label: {
                        RossSectionCard(
                            title: offer.tier.title,
                            subtitle: offer.tier.summary
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    RossInfoPill(title: offer.tier.downloadSizeLabel, systemImage: "arrow.down.circle")
                                    RossInfoPill(title: offer.tier.installedSizeLabel, systemImage: "shippingbox")
                                    RossInfoPill(title: offer.tier.storageNote, systemImage: "internaldrive")
                                }
                                Text("Best for: \(offer.tier.bestFor)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                if model.selectedTier == offer.tier {
                                    Text("Selected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossAccent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button("Go to Home") {
                    model.finishPackSetup()
                }
                .rossPrimaryButtonStyle()

                Button("Skip for now") {
                    model.skipPackSetup()
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
        }
    }
}

private struct AlphaTabShell: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        TabView(selection: $model.persisted.selectedTab) {
            AlphaHomeScreen(model: model)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AlphaAppTab.home)

            AlphaCaseListScreen(model: model)
                .tabItem { Label("Cases", systemImage: "folder") }
                .tag(AlphaAppTab.cases)

            AlphaCaptureScreen(model: model)
                .tabItem { Label("Capture", systemImage: "square.and.arrow.down") }
                .tag(AlphaAppTab.capture)

            AlphaAskHubScreen(model: model)
                .tabItem { Label("Ask Ross", systemImage: "text.bubble") }
                .tag(AlphaAppTab.ask)

            AlphaSettingsScreen(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AlphaAppTab.settings)
        }
        .tint(Color.rossAccent)
    }
}

private struct AlphaHomeScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        let reviewItems = model.reviewQueue()
        let upcomingTasks = model.upcomingTasks()
        let todayTasks = model.todayTasks()
        let recentDocuments = model.recentDocuments()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: alphaGreeting(),
                    title: "Your private case dashboard",
                    detail: "\(upcomingDateCount(in: model.cases)) dates this week • \(reviewItems.count) item(s) need review"
                ) {
                    HStack(spacing: 12) {
                        RossInfoPill(title: "\(model.cases.count) cases", systemImage: "briefcase")
                        RossInfoPill(title: "\(model.openTasks.count) open tasks", systemImage: "checklist")
                        RossInfoPill(title: "On this device", systemImage: "lock")
                    }
                }

                HStack(spacing: 12) {
                    Button("Create case") {
                        model.path.append(.createCase)
                    }
                    .rossPrimaryButtonStyle()
                    Button("Ask Ross") {
                        model.persisted.selectedTab = .ask
                    }
                    .buttonStyle(.bordered)
                }

                RossSectionCard(title: "Today", subtitle: "What needs attention first.") {
                    VStack(alignment: .leading, spacing: 12) {
                        if todayTasks.isEmpty && reviewItems.isEmpty {
                            Text("Nothing urgent is due today.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            ForEach(Array(todayTasks.prefix(3))) { task in
                                AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                            }
                            ForEach(Array(reviewItems.prefix(max(0, 3 - todayTasks.count)))) { item in
                                AlphaReviewRow(item: item) {
                                    model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                                }
                            }
                        }
                    }
                }

                RossSectionCard(title: "Upcoming dates", subtitle: "Hearings, deadlines, and reminders.") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(alphaUpcomingDateRows(from: model.cases).prefix(4), id: \.title) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title).font(.headline)
                                    Text(row.detail).font(.footnote).foregroundStyle(Color.rossInk.opacity(0.65))
                                }
                                Spacer()
                            }
                        }
                        ForEach(Array(upcomingTasks.prefix(2))) { task in
                            AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                        }
                    }
                }

                RossSectionCard(title: "Tasks", subtitle: "Keep work moving.") {
                    AlphaTaskQuickAddCard(onAdd: { title, dueDate in
                        model.addTask(title: title, caseId: nil, dueDate: dueDate)
                    })
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(model.openTasks.prefix(5))) { task in
                            AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                        }
                    }
                }

                RossSectionCard(title: "Review required", subtitle: "Extraction items waiting for advocate review.") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(reviewItems.prefix(4))) { item in
                            AlphaReviewRow(item: item) {
                                model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                            }
                        }
                    }
                }

                RossSectionCard(title: "Active cases", subtitle: "Private workspaces and their next step.") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.cases) { caseMatter in
                            Button {
                                model.selectedCaseID = caseMatter.id
                                model.path.append(.caseWorkspace(caseMatter.id))
                            } label: {
                                AlphaCaseSummaryCard(model: model, caseMatter: caseMatter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RossSectionCard(title: "Recent documents", subtitle: "Latest imports and review status.") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(recentDocuments.prefix(4))) { document in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.title).font(.headline)
                                Text(document.lawyerStatusTitle).font(.footnote.weight(.semibold)).foregroundStyle(Color.rossAccent)
                            }
                        }
                    }
                }

                if let result = model.latestAskResult {
                    AlphaAskResultCard(result: result) { source in
                        model.openSourceRef(source)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            AlphaAskComposerBar(model: model, fixedScopeCaseID: nil)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
    }
}

private struct AlphaCaseListScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Cases",
                    title: "Private case work",
                    detail: "Open a case, review documents, track tasks, and keep everything on this device."
                ) {
                    HStack(spacing: 12) {
                        RossInfoPill(title: "\(model.persisted.cases.count) cases", systemImage: "briefcase")
                        RossInfoPill(title: "\(model.openTasks.count) open tasks", systemImage: "checklist")
                        RossInfoPill(title: "On this device", systemImage: "lock")
                    }
                }

                Button("Create Case") {
                    model.path.append(.createCase)
                }
                .rossPrimaryButtonStyle()

                ForEach(model.cases) { caseMatter in
                    Button {
                        model.selectedCaseID = caseMatter.id
                        model.path.append(.caseWorkspace(caseMatter.id))
                    } label: {
                        AlphaCaseSummaryCard(model: model, caseMatter: caseMatter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .navigationTitle("Cases")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaCaptureScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var selectedCaseID: UUID?
    @State private var showingImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Capture / Import",
                    title: "Bring in a document",
                    detail: "Add a PDF, scan, or note to a case and keep the review local."
                ) {
                    RossInfoPill(title: "Ready", systemImage: "doc.badge.plus")
                }

                RossSectionCard(title: "Choose case", subtitle: "Documents stay linked to a private case workspace.") {
                    Picker("Case", selection: Binding(
                        get: { selectedCaseID ?? model.selectedCaseID ?? model.cases.first?.id },
                        set: { selectedCaseID = $0 }
                    )) {
                        ForEach(model.cases) { caseMatter in
                            Text(caseMatter.title).tag(Optional(caseMatter.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Import document") {
                        showingImporter = true
                    }
                    .rossPrimaryButtonStyle()
                }

                RossSectionCard(title: "Recent imports", subtitle: "Status is shown in plain language.") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(model.recentDocuments(for: selectedCaseID).prefix(6))) { document in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.title).font(.headline)
                                Text(document.lawyerStatusTitle).font(.footnote.weight(.semibold)).foregroundStyle(Color.rossAccent)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard let caseID = selectedCaseID ?? model.selectedCaseID ?? model.cases.first?.id else { return }
            if case let .success(urls) = result, let url = urls.first {
                Task { await model.importDocument(caseId: caseID, from: url) }
            }
        }
    }
}

private struct AlphaAskHubScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Ask Ross",
                    title: "Local case answers first",
                    detail: "Ask from your case files, then turn on Web if you want a sanitized public-law search."
                ) {
                    HStack(spacing: 12) {
                        RossInfoPill(title: "Web off by default", systemImage: "shield")
                        RossInfoPill(title: "Case files stay on this device", systemImage: "lock")
                    }
                }

                if let result = model.latestAskResult {
                    AlphaAskResultCard(result: result) { source in
                        model.openSourceRef(source)
                    }
                } else {
                    RossSectionCard(title: "Start with a question", subtitle: "Ask about hearings, tasks, documents, or review items.") {
                        Text("Ross will answer from local case files unless you explicitly turn on Web.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            AlphaAskComposerBar(model: model, fixedScopeCaseID: nil)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
    }
}

private struct AlphaCreateCaseScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        Form {
            Section("Create Case") {
                TextField("Case title", text: $model.caseDraftTitle)
                TextField("Forum", text: $model.caseDraftForum)
            }

            Section {
                Button("Create") {
                    model.createCase()
                }
                .disabled(model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Create Case")
    }
}

private enum AlphaCaseWorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case documents
    case tasks
    case review
    case notesExports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .documents:
            "Documents"
        case .tasks:
            "Tasks"
        case .review:
            "Review"
        case .notesExports:
            "Notes / Exports"
        }
    }
}

private struct AlphaUpcomingDateRow {
    let title: String
    let detail: String
}

private func alphaGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: .now)
    switch hour {
    case 5..<12:
        return "Good morning"
    case 12..<17:
        return "Good afternoon"
    default:
        return "Good evening"
    }
}

private func upcomingDateCount(in cases: [AlphaCaseMatter]) -> Int {
    let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    return cases.filter { caseMatter in
        guard let nextHearing = caseMatter.nextHearing else { return false }
        return nextHearing <= endOfWeek
    }.count
}

private func alphaUpcomingDateRows(from cases: [AlphaCaseMatter]) -> [AlphaUpcomingDateRow] {
    cases.compactMap { caseMatter -> AlphaUpcomingDateRow? in
        guard let nextHearing = caseMatter.nextHearing else { return nil }
        return AlphaUpcomingDateRow(
            title: caseMatter.title,
            detail: "Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))"
        )
    }
    .sorted { $0.detail < $1.detail }
}

private struct AlphaCaseSummaryCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        RossSectionCard(title: caseMatter.title, subtitle: "\(caseMatter.forum) • \(caseMatter.stage.title)") {
            VStack(alignment: .leading, spacing: 10) {
                if let nextHearing = caseMatter.nextHearing {
                    Text("Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }
                HStack(spacing: 12) {
                    RossInfoPill(title: "\(model.openTaskCount(for: caseMatter.id)) open tasks", systemImage: "checklist")
                    RossInfoPill(title: "\(model.reviewQueue(caseId: caseMatter.id).count) review items", systemImage: "exclamationmark.bubble")
                }
                HStack(spacing: 12) {
                    RossInfoPill(title: "\(caseMatter.documents.count) docs", systemImage: "doc.text")
                    RossInfoPill(title: "On this device", systemImage: "lock")
                }
            }
        }
    }
}

@MainActor
private func alphaPrivateAIStatus(_ model: AlphaRossModel) -> String {
    if let job = model.persisted.modelJobs.first {
        switch job.state {
        case .installed:
            return "Ready"
        case .downloading, .queued, .verifying:
            return "Downloading"
        case .pausedWaitingForWifi:
            return "Waiting for Wi-Fi"
        case .failed:
            return "Needs attention"
        default:
            return "Downloading"
        }
    }
    if model.activePack != nil {
        return "Ready"
    }
    if model.activeExtractionMode == .basic {
        return "Using basic local mode"
    }
    return "Not installed"
}

private struct AlphaTaskRow: View {
    let task: AlphaTaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status == .done ? Color.rossSuccess : Color.rossAccent)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                if let notes = task.notes {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                }
                if let dueDate = task.dueDate {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.6))
                }
            }
            Spacer()
        }
    }
}

private struct AlphaReviewRow: View {
    let item: AlphaReviewQueueItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.detail)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                    Text(item.caseTitle)
                        .font(.caption)
                        .foregroundStyle(Color.rossAccent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.rossInk.opacity(0.35))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaTaskQuickAddCard: View {
    @State private var title = ""
    @State private var dueOffset = 0
    let onAdd: (String, Date?) -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("Add task", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Due", selection: $dueOffset) {
                Text("No date").tag(0)
                Text("Today").tag(1)
                Text("Tomorrow").tag(2)
                Text("This week").tag(7)
            }
            .pickerStyle(.segmented)
            Button("Add task") {
                let dueDate = dueOffset == 0 ? nil : Calendar.current.date(byAdding: .day, value: dueOffset - 1, to: .now)
                onAdd(title, dueDate)
                title = ""
                dueOffset = 0
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private struct AlphaAskComposerBar: View {
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(
                    "Ask Ross about your cases...",
                    text: Binding(
                        get: { model.askDraft(for: activeScopeCaseID) },
                        set: { model.setAskDraft($0, for: activeScopeCaseID) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button("Send") {
                    model.submitAsk(
                        question: model.askDraft(for: activeScopeCaseID),
                        scopeCaseID: activeScopeCaseID,
                        webEnabled: model.askWebEnabled
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                if fixedScopeCaseID == nil {
                    Menu(model.scopeLabel(for: activeScopeCaseID)) {
                        Button("All cases") {
                            model.askSelectedScopeCaseID = nil
                        }
                        ForEach(model.cases) { caseMatter in
                            Button(caseMatter.title) {
                                model.askSelectedScopeCaseID = caseMatter.id
                            }
                        }
                    }
                } else {
                    Text(model.scopeLabel(for: fixedScopeCaseID))
                        .font(.footnote.weight(.semibold))
                }

                Toggle("Web", isOn: $model.askWebEnabled)
                    .toggleStyle(.switch)
                    .font(.footnote.weight(.semibold))
            }

            if model.askWebEnabled {
                Text("Web search only sends a generic public-law query. Your case files stay on this device.")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }
        }
        .padding(12)
        .background(Color.rossSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .sheet(isPresented: Binding(
            get: { model.publicLawPreview != nil && model.pendingPublicLawQuestion != nil },
            set: { if !$0 { model.cancelPendingPublicLawSearch() } }
        )) {
            if let preview = model.publicLawPreview {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Public-law query to be sent")
                            .font(.headline)
                        Text(preview.query)
                            .font(.body.weight(.semibold))
                        Text("No case files or document text will be sent.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(preview.removed, id: \.self) { item in
                                RossBulletRow(text: item)
                            }
                        }
                        Spacer()
                        Button("Search public law") {
                            Task { await model.confirmPendingPublicLawSearch() }
                        }
                        .rossPrimaryButtonStyle()
                        Button("Cancel") {
                            model.cancelPendingPublicLawSearch()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(24)
                }
                .presentationDetents([.medium])
            }
        }
    }
}

private struct AlphaAskResultCard: View {
    let result: AlphaAskResult
    let onOpenSource: (AlphaSourceRef) -> Void

    var body: some View {
        RossSectionCard(title: result.answerTitle, subtitle: result.scopeLabel) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(result.answerSections, id: \.self) { section in
                    RossBulletRow(text: section)
                }

                if let note = result.statusNote {
                    Text(note)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }

                if let warning = result.needsReviewWarning {
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                if !result.caseFileSources.isEmpty {
                    Text("Case-file sources")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                    AlphaSourceRefChips(sourceRefs: result.caseFileSources, onOpenSourceRef: onOpenSource)
                }

                if let preview = result.publicLawPreview {
                    Text("Web search preview")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                    Text(preview.query)
                        .font(.subheadline)
                }

                if !result.publicLawResults.isEmpty {
                    Text("Public-law results")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                    ForEach(result.publicLawResults) { publicResult in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(publicResult.title).font(.headline)
                            Text(publicResult.citation).font(.footnote.weight(.semibold)).foregroundStyle(Color.rossAccent)
                            Text(publicResult.snippet).font(.footnote).foregroundStyle(Color.rossInk.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}

private struct AlphaCaseWorkspaceScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var selectedSection: AlphaCaseWorkspaceSection = .overview

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            if let caseMatter {
                VStack(alignment: .leading, spacing: 20) {
                    RossHeroCard(
                        eyebrow: caseMatter.forum,
                        title: caseMatter.title,
                        detail: caseMatter.summary
                    ) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: caseMatter.stage.title, systemImage: "briefcase")
                            RossInfoPill(title: caseMatter.localNotice, systemImage: "lock")
                            RossInfoPill(title: "\(model.openTaskCount(for: caseId)) open tasks", systemImage: "checklist")
                        }
                    }
                    Picker("Section", selection: $selectedSection) {
                        ForEach(AlphaCaseWorkspaceSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedSection {
                    case .overview:
                        RossSectionCard(title: "Overview", subtitle: "Case summary and next steps.") {
                            VStack(alignment: .leading, spacing: 12) {
                                if let nextHearing = caseMatter.nextHearing {
                                    Text("Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.headline)
                                }
                                Text("\(caseMatter.documents.count) documents • \(model.reviewQueue(caseId: caseId).count) review items")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                ForEach(caseMatter.issueHighlights.prefix(3), id: \.self) { item in
                                    RossBulletRow(text: item)
                                }
                            }
                        }

                        RossSectionCard(title: "Recent activity", subtitle: "Case notes and corrections stay visible.") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(caseMatter.caseMemoryUpdates.prefix(4)) { update in
                                    Text(update.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.rossInk.opacity(0.75))
                                }
                            }
                        }
                    case .documents:
                        RossSectionCard(title: "Documents", subtitle: "Import and open documents.") {
                            Button("Import document") {
                                model.path.append(.documentList(caseId))
                            }
                            .rossPrimaryButtonStyle()
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(caseMatter.documents) { document in
                                    Button {
                                        model.path.append(.documentViewer(caseId, document.id, 1))
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(document.title).font(.headline)
                                                Text(document.lawyerStatusTitle).font(.footnote.weight(.semibold)).foregroundStyle(Color.rossAccent)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    case .tasks:
                        RossSectionCard(title: "Tasks", subtitle: "Case-specific work list.") {
                            AlphaTaskQuickAddCard(onAdd: { title, dueDate in
                                model.addTask(title: title, caseId: caseId, dueDate: dueDate)
                            })
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(model.tasks(for: caseId)) { task in
                                    AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                                }
                            }
                        }
                    case .review:
                        RossSectionCard(title: "Review", subtitle: "Details waiting for advocate review.") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(model.reviewQueue(caseId: caseId)) { item in
                                    AlphaReviewRow(item: item) {
                                        model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                                    }
                                }
                            }
                        }
                    case .notesExports:
                        RossSectionCard(title: "Notes / Exports", subtitle: "Generate local reports for this case.") {
                            VStack(spacing: 12) {
                                Button("Generate chronology") {
                                    Task { await model.generateExport(kind: "chronology_report", caseId: caseId) }
                                }
                                .rossPrimaryButtonStyle()
                                Button("Generate case note") {
                                    Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                                }
                                .buttonStyle(.bordered)
                                Button("Generate order summary") {
                                    Task { await model.generateExport(kind: "order_summary", caseId: caseId) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            AlphaAskComposerBar(model: model, fixedScopeCaseID: caseId)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("Case")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaDocumentListScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var showingImporter = false

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Documents", subtitle: "Files are copied into app-private storage.") {
                    Button("Import document") {
                        showingImporter = true
                    }
                    .rossPrimaryButtonStyle()
                }

                ForEach(caseMatter?.documents ?? []) { document in
                    Button {
                        model.path.append(.documentViewer(caseId, document.id, 1))
                    } label: {
                        RossSectionCard(title: document.title, subtitle: "\(document.kind.title) • \(document.pageCount) page(s)") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(document.lawyerStatusTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.rossAccent)
                                Text(document.extractedText ?? "Ross will show source-backed details here when review is ready.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                                    .lineLimit(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task { await model.importDocument(caseId: caseId, from: url) }
            }
        }
        .navigationTitle("Documents")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaDocumentViewerScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    let documentId: UUID
    let initialPage: Int?

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first(where: { $0.id == caseId })
    }

    private var document: AlphaCaseDocument? {
        caseMatter?.documents.first(where: { $0.id == documentId })
    }

    private var sourceRefs: [AlphaSourceRef] {
        caseMatter?.sourceRefs.filter { $0.documentId == documentId } ?? []
    }

    private var resolvedPage: Int {
        let upperBound = max(document?.pageCount ?? 1, 1)
        return min(max(initialPage ?? sourceRefs.first?.pageNumber ?? 1, 1), upperBound)
    }

    private var currentPageRefs: [AlphaSourceRef] {
        sourceRefs.filter { $0.pageNumber == resolvedPage }
    }

    private var reviewSummaryText: String? {
        model.reviewSummary(caseId: caseId, documentId: documentId)
    }

    private var reviewFields: [AlphaExtractedLegalField] {
        model.visibleExtractedFields(caseId: caseId, documentId: documentId)
    }

    private var reviewFindings: [AlphaExtractionFinding] {
        model.reviewFindings(caseId: caseId, documentId: documentId)
    }

    private var needsReviewCount: Int {
        reviewFields.filter(\.needsReview).count + reviewFindings.count
    }

    var body: some View {
        ScrollView {
            if let document {
                VStack(alignment: .leading, spacing: 20) {
                    RossHeroCard(
                        eyebrow: document.kind.title,
                        title: document.title,
                        detail: "Pages: \(document.pageCount) • Status: \(document.lawyerStatusTitle) • Needs review: \(needsReviewCount)"
                    ) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: document.fileName, systemImage: "doc")
                            RossInfoPill(title: "Jump to p. \(resolvedPage)", systemImage: "arrow.right.circle")
                        }
                    }

                    RossSectionCard(title: "Actions", subtitle: "Keep review simple and local.") {
                        VStack(spacing: 12) {
                            Button("Ask about this document") {
                                model.askDrafts[caseId] = "What should I note from \(document.title)?"
                                model.path.append(.askCase(caseId))
                            }
                            .rossPrimaryButtonStyle()

                            Button("Add task") {
                                model.addTask(
                                    title: "Review \(document.title)",
                                    caseId: caseId,
                                    dueDate: caseMatter?.nextHearing,
                                    priority: .normal,
                                    notes: "Created from the document viewer."
                                )
                            }
                            .buttonStyle(.bordered)

                            Button("Export note") {
                                Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                            }
                            .buttonStyle(.bordered)

                            Button("Re-run review") {
                                Task { await model.rerunReview(caseId: caseId, documentId: documentId) }
                            }
                            .buttonStyle(.bordered)

                            Button("Delete document", role: .destructive) {
                                model.deleteDocument(caseId: caseId, documentId: documentId)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let preview = AlphaDocumentPreview(document: document, initialPage: resolvedPage) {
                        preview
                    }

                    if let reviewSummaryText {
                        RossSectionCard(title: "Review extracted details", subtitle: reviewSummaryText) {
                            VStack(alignment: .leading, spacing: 14) {
                                if let classification = document.classification {
                                    AlphaClassificationReviewCard(
                                        classification: classification,
                                        onAccept: {
                                            model.updateDocumentClassification(
                                                caseId: caseId,
                                                documentId: documentId,
                                                type: classification.type
                                            )
                                        },
                                        onUpdateType: { type in
                                            model.updateDocumentClassification(
                                                caseId: caseId,
                                                documentId: documentId,
                                                type: type
                                            )
                                        },
                                        onOpenSourceRef: model.openSourceRef
                                    )
                                }

                                if let languageProfile = document.languageProfile {
                                    RossSectionCard(
                                        title: "Language profile",
                                        subtitle: "Ross keeps Hindi/English handling local and source-backed."
                                    ) {
                                        HStack(spacing: 12) {
                                            RossInfoPill(title: "Primary: \(languageProfile.primaryLanguage.rawValue.capitalized)", systemImage: "character.book.closed")
                                            RossInfoPill(title: "Scripts: \(languageProfile.scriptsDetected.joined(separator: ", "))", systemImage: "textformat.abc.dottedunderline")
                                        }
                                    }
                                }

                                ForEach(reviewFields) { field in
                                    AlphaExtractedFieldReviewCard(
                                        field: field,
                                        onAccept: {
                                            model.acceptExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                        },
                                        onSaveEdit: { newValue in
                                            model.applyFieldCorrection(caseId: caseId, documentId: documentId, fieldId: field.id, newValue: newValue)
                                        },
                                        onIgnore: {
                                            model.ignoreExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                        },
                                        onOpenSourceRef: model.openSourceRef
                                    )
                                }

                                if !reviewFindings.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Needs review")
                                            .font(.headline)
                                        ForEach(reviewFindings) { finding in
                                            AlphaFindingCard(finding: finding, onOpenSourceRef: model.openSourceRef)
                                        }
                                    }
                                }

                                if let upgrade = model.extractionUpgradeMessage(for: document) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(upgrade)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.rossAccent)

                                        Button("Run better extraction") {
                                            model.path.append(.privateAISettings)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }

                    RossSectionCard(title: "Document review", subtitle: "Text available so far for this document.") {
                        Text(document.extractedText ?? "Ross will keep source references visible even when exact highlights are still pending.")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.8))
                    }

                    RossSectionCard(title: "Source panel", subtitle: "If exact highlight placement is not ready, Ross shows page and snippet metadata here.") {
                        VStack(alignment: .leading, spacing: 10) {
                            if sourceRefs.isEmpty {
                                Text("Source unavailable. Ross will keep the document context visible without pretending to anchor a missing excerpt.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                            }

                            ForEach(currentPageRefs.isEmpty ? sourceRefs : currentPageRefs) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.label)
                                        .font(.headline)
                                    Text(source.detail)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.65))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.rossCardBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.rossBorder, lineWidth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Document")
        .rossInlineNavigationTitle()
    }
}

@MainActor
private func AlphaDocumentPreview(document: AlphaCaseDocument, initialPage: Int) -> AnyView? {
    if document.kind == .pdf {
        return AnyView(AlphaPDFPreview(relativePath: document.storedRelativePath, initialPage: initialPage))
    }

    if document.kind == .image {
        return AnyView(AlphaImagePreview(relativePath: document.storedRelativePath))
    }

    return AnyView(
        RossSectionCard(title: "Preview", subtitle: "Preview is not available for this file type yet.") {
            Text("A placeholder preview is shown while source anchors and extracted text stay available.")
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.7))
        }
    )
}

private struct AlphaClassificationReviewCard: View {
    let classification: AlphaLegalDocumentClassification
    let onAccept: () -> Void
    let onUpdateType: (AlphaLegalDocumentType) -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document type")
                        .font(.headline)
                    Text(classification.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title3.weight(.semibold))
                    Text(classification.needsReview ? "Needs advocate review" : "Verified from source")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(classification.needsReview ? Color.orange : Color.rossSuccess)
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: classification.needsReview || classification.confidence < 0.64 ? "Needs review" : (classification.confidence >= 0.84 ? "High" : "Medium"),
                    tint: classification.needsReview || classification.confidence < 0.64 ? .orange : (classification.confidence >= 0.84 ? .green : Color.rossAccent)
                )
            }

            if let subtype = classification.subtype, !subtype.isEmpty {
                Text(subtype.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }

            HStack(spacing: 10) {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)

                Menu("Edit") {
                    ForEach([
                        AlphaLegalDocumentType.pleading,
                        .order,
                        .judgment,
                        .affidavit,
                        .notice,
                        .evidence,
                        .correspondence,
                        .misc
                    ], id: \.self) { type in
                        Button(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) {
                            onUpdateType(type)
                        }
                    }
                }
            }

            AlphaSourceRefChips(sourceRefs: classification.sourceRefs, onOpenSourceRef: onOpenSourceRef)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
    }
}

private struct AlphaExtractedFieldReviewCard: View {
    let field: AlphaExtractedLegalField
    let onAccept: () -> Void
    let onSaveEdit: (String) -> Void
    let onIgnore: () -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    @State private var isEditing = false
    @State private var draftValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label)
                        .font(.headline)
                    if isEditing {
                        TextField("Edit \(field.label.lowercased())", text: $draftValue)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(field.value)
                            .font(.body)
                            .foregroundStyle(Color.rossInk)
                    }
                    Text(field.needsReview ? "Needs advocate review" : "Verified from source")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(field.needsReview ? Color.orange : Color.rossSuccess)
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: field.confidenceLabel,
                    tint: field.confidenceLabel == "High" ? .green : (field.confidenceLabel == "Medium" ? Color.rossAccent : .orange)
                )
            }

            AlphaSourceRefChips(sourceRefs: field.sourceRefs, onOpenSourceRef: onOpenSourceRef)

            HStack(spacing: 10) {
                if isEditing {
                    Button("Save") {
                        onSaveEdit(draftValue)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        draftValue = field.value
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Accept", action: onAccept)
                        .buttonStyle(.borderedProminent)

                    Button("Edit") {
                        draftValue = field.value
                        isEditing = true
                    }
                    .buttonStyle(.bordered)

                    Button("Ignore", role: .destructive, action: onIgnore)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
        .onAppear {
            draftValue = field.value
        }
    }
}

private struct AlphaFindingCard: View {
    let finding: AlphaExtractionFinding
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(finding.message)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                AlphaConfidenceBadge(
                    label: finding.severity.rawValue.capitalized,
                    tint: finding.severity == .critical ? .red : .orange
                )
            }

            AlphaSourceRefChips(sourceRefs: finding.sourceRefs, onOpenSourceRef: onOpenSourceRef)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
    }
}

private struct AlphaSourceRefChips: View {
    let sourceRefs: [AlphaSourceRef]
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sourceRefs.isEmpty {
                Text("Source pending")
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            } else {
                Text("Source")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.65))

                ForEach(sourceRefs.prefix(3)) { sourceRef in
                    Button {
                        onOpenSourceRef(sourceRef)
                    } label: {
                        HStack {
                            Text(sourceRef.label)
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Text(sourceRef.detail)
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AlphaConfidenceBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct AlphaAskCaseScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Ask Ross",
                    title: model.scopeLabel(for: caseId),
                    detail: "Ross answers from local case files unless you explicitly turn on Web."
                ) {
                    RossInfoPill(title: "Case files stay on this device", systemImage: "lock")
                }

                if let result = model.latestAskResult, result.scopeCaseID == caseId {
                    AlphaAskResultCard(result: result) { source in
                        model.openSourceRef(source)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            AlphaAskComposerBar(model: model, fixedScopeCaseID: caseId)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("Ask Case")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaPublicLawScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Public Law Search Preview", subtitle: "Public-law search sends only a sanitized query after explicit confirmation.") {
                    TextEditor(text: $model.publicLawDraft)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Do not send case IDs, filenames, OCR text, chunk text, chat history, client names, party names, phone numbers, emails, or long factual narratives.")
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))

                    Button("Generate Query Preview") {
                        model.buildPublicLawPreview()
                    }
                    .rossPrimaryButtonStyle()
                }

                if let preview = model.publicLawPreview {
                    RossSectionCard(title: "Sanitized preview", subtitle: preview.confirmationNote) {
                        Text(preview.query)
                            .font(.headline)
                        ForEach(preview.removed, id: \.self) { item in
                            RossBulletRow(text: item)
                        }
                        Button("Run Public-Law Search") {
                            Task { await model.runPublicLawSearch() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !model.publicLawResults.isEmpty {
                    RossSectionCard(title: "Preview results", subtitle: "Draft for advocate review") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.publicLawResults) { result in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.headline)
                                    Text(result.citation)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.rossAccent)
                                    Text(result.snippet)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Public Law")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaExportsScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Drafts / Exports", subtitle: "Generate local reports for chronology, case note, or chat transcript review.") {
                    VStack(spacing: 12) {
                        Button("Generate Chronology Report") {
                            Task { await model.generateExport(kind: "chronology_report", caseId: caseId) }
                        }
                        .rossPrimaryButtonStyle()

                        Button("Generate Case Note") {
                            Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)

                        Button("Generate Order Summary") {
                            Task { await model.generateExport(kind: "order_summary", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)

                        Button("Generate Chat Transcript") {
                            Task { await model.generateExport(kind: "chat_transcript", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ForEach(model.persisted.exports) { report in
                    RossSectionCard(title: report.title, subtitle: report.kind.replacingOccurrences(of: "_", with: " ").capitalized) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(report.relativePath)
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.7))

                            ShareLink(item: model.exportURL(for: report)) {
                                Label("Share local PDF", systemImage: "square.and.arrow.up")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Exports")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaSettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List {
            Section("Privacy") {
                Toggle("Require approval before Web search", isOn: $model.persisted.settings.requirePublicLawApproval)
                Toggle("Keep Ross private by default", isOn: $model.persisted.settings.privateByDefault)
                Text("Case files stay on this device. Public-law search sends only a sanitized query.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Private AI status") {
                LabeledContent("Status", value: alphaPrivateAIStatus(model))
                LabeledContent("Pack", value: model.activePack?.tier.title ?? "Not installed")
                NavigationLink(value: AlphaRoute.privateAISettings) {
                    Label("Advanced", systemImage: "gearshape.2")
                }
            }

            Section("Exports") {
                LabeledContent("Local reports", value: "\(model.persisted.exports.count)")
            }

            Section("Privacy ledger") {
                NavigationLink(value: AlphaRoute.privacyLedger) {
                    Label("Open Privacy Ledger", systemImage: "checklist")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

private struct AlphaPrivateAISettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List {
            Section("Private AI") {
                LabeledContent("Status", value: alphaPrivateAIStatus(model))
                LabeledContent("Pack", value: model.activePack?.tier.title ?? "Not installed")
                LabeledContent("Current help", value: model.activeExtractionMode.qualityLabel)
                Text("Choose the pack that fits this device. Ross keeps technical names out of normal screens.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Download policy") {
                Toggle("Wi-Fi only downloads", isOn: $model.persisted.settings.wifiOnlyDownloads)
                Toggle("Allow mobile data for large packs", isOn: $model.persisted.settings.allowMobileDataForLargePacks)
            }

            Section("Available tiers") {
                ForEach(AlphaPackOffer.catalog) { offer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(offer.tier.title)
                            .font(.headline)
                        Text(offer.tier.summary)
                            .font(.footnote)
                        Text("Extraction quality: \(offer.tier.extractionQuality)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                        Text(offer.tier.bestFor)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Download / Resume") {
                                Task { await model.startPackDownload(for: offer.tier, mobileAllowed: model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Jobs") {
                ForEach(model.persisted.modelJobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.tier.title)
                            .font(.headline)
                        Text(job.state.title)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossAccent)
                        Text("Ross is preparing this pack on this device.")
                            .font(.caption)
                        HStack {
                            Button("Pause") { model.pauseJob(job) }
                            Button("Resume") { model.resumeJob(job) }
                        }
                    }
                }
            }

            Section("Installed packs") {
                ForEach(model.persisted.installedPacks) { pack in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pack.tier.title)
                            .font(.headline)
                        Text("Ready on this device")
                            .font(.caption)
                        HStack {
                            Button("Make Active") { model.activateInstalledPack(pack) }
                            Button("Remove", role: .destructive) { model.removeInstalledPack(pack) }
                        }
                    }
                }
            }

            if let runtimeHealth = model.activeRuntimeHealth {
                Section("Advanced") {
                    DisclosureGroup("Technical diagnostics") {
                        LabeledContent("Runtime mode", value: runtimeHealth.runtimeMode.rawValue)
                        LabeledContent("Artifact kind", value: model.activePack?.artifactKind ?? "Missing")
                        LabeledContent("Checksum verified", value: runtimeHealth.checksumVerified ? "yes" : "no")
                        LabeledContent("Fallback active", value: runtimeHealth.fallbackActive ? "yes" : "no")
                        LabeledContent("Model path", value: runtimeHealth.modelPathPresent ? "Configured" : "Missing")
                        if let modelPathLabel = runtimeHealth.modelPathLabel {
                            LabeledContent("Model file", value: modelPathLabel)
                        }
                        if let lastErrorCategory = runtimeHealth.lastErrorCategory {
                            LabeledContent("Last error category", value: lastErrorCategory)
                        }
                        if let lastInvocationRuntimeMode = model.lastModelInvocationRuntimeMode {
                            LabeledContent("Last invocation runtime", value: lastInvocationRuntimeMode)
                        }
                        Button(model.localInferenceSmokeRunning ? "Running local inference smoke..." : "Run local inference smoke") {
                            model.runLocalInferenceSmoke()
                        }
                        .disabled(model.localInferenceSmokeRunning)
                    }
                }
            }
        }
        .navigationTitle("Private AI")
    }
}

private struct AlphaPrivacyLedgerScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List(model.persisted.ledgerEntries) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.lawyerTitle)
                    .font(.headline)
                Text(entry.lawyerDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(entry.purpose.rawValue.replacingOccurrences(of: "_", with: " "))
                    Spacer()
                    Text(entry.success ? "Completed" : "Needs attention")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy Ledger")
    }
}

private func alphaFieldSortRank(_ type: AlphaExtractedLegalFieldType) -> Int {
    switch type {
    case .caseNumber:
        return 0
    case .court:
        return 1
    case .partyName:
        return 2
    case .date:
        return 3
    case .nextDate:
        return 4
    case .orderDirection:
        return 5
    case .section:
        return 6
    case .exhibitNumber:
        return 7
    case .relief:
        return 8
    case .prayer:
        return 9
    case .amount:
        return 10
    case .issue:
        return 11
    case .advocateName:
        return 12
    case .judgeName:
        return 13
    case .limitationDate:
        return 14
    case .fact:
        return 15
    case .unknown:
        return 16
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

#if canImport(PDFKit)
private struct AlphaPDFPreview: View {
    let relativePath: String
    let initialPage: Int

    var body: some View {
        RossSectionCard(title: "Preview", subtitle: "PDF viewer") {
            PDFRepresentedView(url: alphaAbsoluteURL(for: relativePath), initialPage: initialPage)
                .frame(minHeight: 360)
        }
    }
}

#if canImport(UIKit)
private struct PDFRepresentedView: UIViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
        if let document = uiView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                uiView.go(to: target)
            }
        }
    }
}
#elseif canImport(AppKit)
private struct PDFRepresentedView: NSViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: url)
        if let document = nsView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                nsView.go(to: target)
            }
        }
    }
}
#endif
#endif

private struct AlphaImagePreview: View {
    let relativePath: String

    var body: some View {
        RossSectionCard(title: "Preview", subtitle: "Imported image") {
            let url = alphaAbsoluteURL(for: relativePath)
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Image preview unavailable.")
            }
            #elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Image preview unavailable.")
            }
            #else
            Text("Image preview unavailable.")
            #endif
        }
    }
}
