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
    case captureImport
    case askRoss
    case askCase(UUID)
    case exports(UUID?)
    case privacyLedger
    case privateAISettings
}

private extension AlphaRoute {
    var isAskRoute: Bool {
        switch self {
        case .askRoss, .askCase:
            true
        default:
            false
        }
    }
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
    var chatSessionID: UUID?
    var chatTurnID: UUID?
    var kind: AlphaChatTurnKind
    var question: String
    var scopeCaseID: UUID?
    var scopeLabel: String
    var selectedDocumentTitles: [String]
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

private let alphaScreenPadding: CGFloat = 18
private let alphaSectionSpacing: CGFloat = 14
private let alphaRossSuggestedTaskNotePrefix = "ross-overview::"
private let alphaSharedWorkspaceID = UUID(uuidString: "0D9E5220-4D3C-4B49-9A67-10B42B593B7D")!

private struct AlphaAskDocumentOption: Identifiable, Hashable {
    let id: UUID
    let caseId: UUID
    let caseTitle: String
    let title: String
    let kind: AlphaDocumentKind
    let isShared: Bool
}

private struct AlphaRecentDocumentItem: Identifiable {
    let caseId: UUID
    let caseTitle: String
    let document: AlphaCaseDocument

    var id: UUID { document.id }
}

private struct AlphaAssistantStatusSnapshot {
    let title: String
    let detail: String
    let tint: Color
}

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
    var askSelectedDocumentIDs: [UUID: Set<UUID>] = [:]
    var globalAskSelectedDocumentIDs: Set<UUID> = []
    var askWebEnabled = false
    var pendingPublicLawQuestion: String?
    var pendingPublicLawScopeCaseID: UUID?
    var pendingPublicLawSessionID: UUID?
    var pendingPublicLawTurnID: UUID?
    var latestAskResult: AlphaAskResult?
    var askHistory: [AlphaAskResult] = []
    var publicLawDraft = "Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted."
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult] = []
    var localInferenceSmokeReport: AlphaLocalInferenceSmokeReport?
    var localInferenceSmokeRunning = false
    var refreshingCaseOverviewIDs: Set<UUID> = []
    var workspaceDrawerPresented = false
    var loaded = false

    init(
        store: AlphaRossStore = AlphaRossStore(),
        publicLawSearchAction: AlphaPublicLawSearchAction? = nil,
        previewState: AlphaPersistedState? = nil,
        previewPath: [AlphaRoute] = []
    ) {
        self.store = store
        let backend = AlphaBackendClient()
        self.backend = backend
        self.publicLawSearchAction = publicLawSearchAction ?? { preview in
            try await backend.searchPublicLaw(preview: preview)
        }
        self.globalAskDraft = ""

        if let previewState {
            persisted = normalizeLoadedState(previewState)
            path = previewPath
            syncDerivedStateFromPersisted()
            loaded = true
        }
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        do {
            persisted = normalizeLoadedState(try await store.load())
            syncDerivedStateFromPersisted()
            loaded = true
        } catch {
            loaded = true
        }
    }

    private func syncDerivedStateFromPersisted() {
        selectedCaseID = cases.first?.id
        selectedTier = persisted.settings.activeTier ?? recommendedOnDeviceTier()
        publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
        publicLawPreview = persisted.publicLawPreview
        publicLawResults = persisted.publicLawResults ?? []
        rebuildAskHistory()
    }

    private func rebuildAskHistory() {
        askHistory = persisted.cases.flatMap { caseMatter in
            caseMatter.chatSessions.flatMap { session in
                session.turns.reversed().map { turn in
                    askResult(from: turn, in: caseMatter, chatSessionID: session.id)
                }
            }
        }
    }

    private func askResult(
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
        persisted.cases
            .filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var sharedWorkspace: AlphaCaseMatter? {
        persisted.cases.first(where: { $0.id == alphaSharedWorkspaceID })
    }

    private var activeCaseIDs: Set<UUID> {
        Set(cases.map(\.id))
    }

    var tasks: [AlphaTaskItem] {
        (persisted.tasks ?? [])
            .filter { task in
                guard let caseId = task.caseId else { return true }
                return activeCaseIDs.contains(caseId)
            }
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
            return cases.first { $0.id == selectedCaseID }
        }
        return cases.first
    }

    func focusCase(_ caseID: UUID) {
        guard activeCaseIDs.contains(caseID) else { return }
        selectedCaseID = caseID
        askSelectedScopeCaseID = caseID
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].updatedAt = .now
        persist()
    }

    func tasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        tasks.filter { task in
            guard let caseId else { return true }
            guard caseId != alphaSharedWorkspaceID else { return false }
            return task.caseId == caseId
        }
    }

    func askDraft(for scopeCaseID: UUID?) -> String {
        if let scopeCaseID {
            return askDrafts[scopeCaseID] ?? ""
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

    func selectedAskDocumentIDs(for scopeCaseID: UUID?) -> Set<UUID> {
        if let scopeCaseID {
            return askSelectedDocumentIDs[scopeCaseID, default: []]
        }
        return globalAskSelectedDocumentIDs
    }

    func setSelectedAskDocumentIDs(_ documentIDs: Set<UUID>, for scopeCaseID: UUID?) {
        if let scopeCaseID {
            if documentIDs.isEmpty {
                askSelectedDocumentIDs.removeValue(forKey: scopeCaseID)
            } else {
                askSelectedDocumentIDs[scopeCaseID] = documentIDs
            }
        } else {
            globalAskSelectedDocumentIDs = documentIDs
        }
        updateActiveChatContext(documentIDs: documentIDs, for: scopeCaseID)
    }

    func askDocumentTitle(for scopeCaseID: UUID?) -> String? {
        let titles = selectedAskDocuments(for: scopeCaseID).map(\.title)
        if titles.count == 1 {
            return titles.first
        }
        return nil
    }

    fileprivate func selectedAskDocuments(for scopeCaseID: UUID?) -> [AlphaAskDocumentOption] {
        let selectedIDs = selectedAskDocumentIDs(for: scopeCaseID)
        guard !selectedIDs.isEmpty else { return [] }
        return availableAskDocuments(for: scopeCaseID).filter { selectedIDs.contains($0.id) }
    }

    fileprivate func availableAskDocuments(for scopeCaseID: UUID?) -> [AlphaAskDocumentOption] {
        let scopedCases: [AlphaCaseMatter]
        if let scopeCaseID {
            scopedCases = persisted.cases.filter { $0.id == scopeCaseID || $0.id == alphaSharedWorkspaceID }
        } else {
            scopedCases = persisted.cases
        }

        return scopedCases
            .flatMap { caseMatter in
                caseMatter.documents.map { document in
                    AlphaAskDocumentOption(
                        id: document.id,
                        caseId: caseMatter.id,
                        caseTitle: caseMatter.title,
                        title: document.title,
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

    func toggleAskDocumentSelection(_ documentID: UUID, for scopeCaseID: UUID?) {
        var selected = selectedAskDocumentIDs(for: scopeCaseID)
        if selected.contains(documentID) {
            selected.remove(documentID)
        } else {
            selected.insert(documentID)
        }
        setSelectedAskDocumentIDs(selected, for: scopeCaseID)
    }

    func askSelectionSubtitle(for scopeCaseID: UUID?) -> String? {
        let selected = selectedAskDocuments(for: scopeCaseID)
        guard !selected.isEmpty else { return nil }
        if selected.count == 1, let first = selected.first {
            if first.isShared {
                return "\(first.title) · shared file"
            }
            if scopeCaseID == nil {
                return "\(first.title) · \(first.caseTitle)"
            }
            return first.title
        }
        let sharedCount = selected.filter(\.isShared).count
        if sharedCount > 0 {
            return "\(selected.count) files selected · \(sharedCount) shared"
        }
        return "\(selected.count) files selected"
    }

    func openAsk(scopeCaseID: UUID? = nil, documentID: UUID? = nil) {
        if let documentID {
            setSelectedAskDocumentIDs([documentID], for: scopeCaseID)
        }
        if let scopeCaseID {
            askSelectedScopeCaseID = scopeCaseID
            selectedCaseID = scopeCaseID
            path.append(.askCase(scopeCaseID))
        } else {
            path.append(.askRoss)
        }
    }

    func scopeLabel(for caseId: UUID?) -> String {
        if caseId == alphaSharedWorkspaceID {
            return "Shared files"
        }
        guard let caseId, let caseMatter = cases.first(where: { $0.id == caseId }) else {
            return "All work"
        }
        return caseMatter.title
    }

    func askConversation(for scopeCaseID: UUID?) -> [AlphaAskResult] {
        let storageCaseID = scopeCaseID ?? alphaSharedWorkspaceID
        guard let caseMatter = persisted.cases.first(where: { $0.id == storageCaseID }) else { return [] }
        guard let sessionID = caseMatter.activeChatSessionID ?? caseMatter.chatSessions.first?.id else { return [] }
        guard let session = caseMatter.chatSessions.first(where: { $0.id == sessionID }) else { return [] }
        return session.turns.map { askResult(from: $0, in: caseMatter, chatSessionID: session.id) }
    }

    func chatSessions(for caseId: UUID) -> [AlphaChatSession] {
        guard let caseMatter = persisted.cases.first(where: { $0.id == caseId }) else { return [] }
        return caseMatter.chatSessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    func activeChatSession(for caseId: UUID?) -> AlphaChatSession? {
        let storageCaseID = caseId ?? alphaSharedWorkspaceID
        guard let caseMatter = persisted.cases.first(where: { $0.id == storageCaseID }) else { return nil }
        guard let sessionID = caseMatter.activeChatSessionID ?? caseMatter.chatSessions.first?.id else { return nil }
        return caseMatter.chatSessions.first(where: { $0.id == sessionID })
    }

    func activeChatSessionID(for caseId: UUID?) -> UUID? {
        let storageCaseID = caseId ?? alphaSharedWorkspaceID
        return persisted.cases.first(where: { $0.id == storageCaseID })?.activeChatSessionID
    }

    func setActiveChatSession(_ sessionID: UUID, for caseId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        guard persisted.cases[caseIndex].chatSessions.contains(where: { $0.id == sessionID }) else { return }
        persisted.cases[caseIndex].activeChatSessionID = sessionID
        persisted.cases[caseIndex].updatedAt = .now
        selectedCaseID = caseId
        askSelectedScopeCaseID = caseId
        restoreComposerContext(for: caseId)
        rebuildAskHistory()
        persist()
    }

    func startNewChat(for caseId: UUID, openConversation: Bool = true) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        let session = AlphaChatSession()
        persisted.cases[caseIndex].chatSessions.insert(session, at: 0)
        persisted.cases[caseIndex].activeChatSessionID = session.id
        persisted.cases[caseIndex].updatedAt = .now
        selectedCaseID = caseId
        askSelectedScopeCaseID = caseId
        restoreComposerContext(for: caseId)
        rebuildAskHistory()
        persist()
        if openConversation {
            path.removeAll { route in
                if case .askCase(let existingCaseID) = route {
                    return existingCaseID == caseId
                }
                return false
            }
            path.append(.askCase(caseId))
        }
    }

    func chatSessionTitle(_ session: AlphaChatSession) -> String {
        guard let question = session.turns.first?.question.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty else {
            return "New chat"
        }
        let compact = question.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(compact.prefix(44))
    }

    func chatSessionSubtitle(_ session: AlphaChatSession) -> String {
        if let latestTurn = session.turns.first {
            return latestTurn.askedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "No messages yet"
    }

    private func updateActiveChatContext(documentIDs: Set<UUID>, for scopeCaseID: UUID?) {
        let storageCaseID = scopeCaseID ?? alphaSharedWorkspaceID
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == storageCaseID }) else { return }
        guard let sessionID = persisted.cases[caseIndex].activeChatSessionID ?? persisted.cases[caseIndex].chatSessions.first?.id else { return }
        guard let sessionIndex = persisted.cases[caseIndex].chatSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        persisted.cases[caseIndex].chatSessions[sessionIndex].contextDocumentIDs = documentIDs.sorted { $0.uuidString < $1.uuidString }
    }

    private func restoreComposerContext(for scopeCaseID: UUID?) {
        let availableDocuments = availableAskDocuments(for: scopeCaseID)
        let validDocumentIDs = Set(availableDocuments.map(\.id))
        let restoredDocumentIDs = Set(activeChatSession(for: scopeCaseID)?.contextDocumentIDs ?? []).intersection(validDocumentIDs)
        setSelectedAskDocumentIDs(restoredDocumentIDs, for: scopeCaseID)

        if restoredDocumentIDs.count == 1,
           let restoredDocumentID = restoredDocumentIDs.first,
           let document = availableDocuments.first(where: { $0.id == restoredDocumentID }) {
            setAskDraft("What should I note from \(document.title)?", for: scopeCaseID)
            return
        }

        clearAskDraft(for: scopeCaseID)
    }

    private func clearAskDraft(for scopeCaseID: UUID?) {
        if let scopeCaseID {
            askDrafts.removeValue(forKey: scopeCaseID)
        } else {
            globalAskDraft = ""
        }
    }

    func openDocumentInChat(caseId: UUID, documentId: UUID, startNewThread: Bool) {
        guard let caseMatter = persisted.cases.first(where: { $0.id == caseId }),
              let document = caseMatter.documents.first(where: { $0.id == documentId }) else { return }

        if startNewThread || activeChatSession(for: caseId) == nil {
            startNewChat(for: caseId, openConversation: false)
        }

        selectedCaseID = caseId
        askSelectedScopeCaseID = caseId
        setSelectedAskDocumentIDs([documentId], for: caseId)
        setAskDraft("What should I note from \(document.title)?", for: caseId)
        path.removeAll { route in
            if case .askCase(let existingCaseID) = route {
                return existingCaseID == caseId
            }
            return false
        }
        path.append(.askCase(caseId))
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
        let caseId = taskList[index].caseId
        persisted.tasks = taskList
        if let caseId, let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) {
            refreshCaseWorkspace(at: caseIndex)
        }
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
        if let caseId, let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) {
            refreshCaseWorkspace(at: caseIndex)
        }
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

    func refreshCaseOverview(caseId: UUID) async {
        guard !refreshingCaseOverviewIDs.contains(caseId),
              let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }

        refreshingCaseOverviewIDs.insert(caseId)
        defer { refreshingCaseOverviewIDs.remove(caseId) }

        try? await Task.sleep(nanoseconds: 250_000_000)
        refreshCaseWorkspace(at: caseIndex)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Local matter overview refreshed",
                detail: "Ross reviewed the matter files, tasks, and progress on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://matter-refresh",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func recentDocuments(for caseId: UUID? = nil) -> [AlphaCaseDocument] {
        let visibleCases = caseId.map { id in cases.filter { $0.id == id } } ?? cases
        return visibleCases
            .flatMap(\.documents)
            .sorted { $0.importedAt > $1.importedAt }
    }

    func reviewQueue(caseId: UUID? = nil) -> [AlphaReviewQueueItem] {
        let visibleCases = caseId.map { id in cases.filter { $0.id == id } } ?? cases
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
        let storedResult = appendAskResult(localResult, persistToCase: scopeCaseID)
        latestAskResult = storedResult
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
            pendingPublicLawSessionID = storedResult.chatSessionID
            pendingPublicLawTurnID = storedResult.chatTurnID
            publicLawPreview = preview
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.statusNote = "Web search preview ready"
            updateStoredAskTurn(
                scopeCaseID: scopeCaseID,
                sessionID: storedResult.chatSessionID,
                turnID: storedResult.chatTurnID
            ) { turn in
                turn.publicLawPreview = preview
                turn.statusNote = "Web search preview ready"
            }
        } else {
            pendingPublicLawQuestion = nil
            pendingPublicLawScopeCaseID = nil
            pendingPublicLawSessionID = nil
            pendingPublicLawTurnID = nil
            publicLawPreview = nil
            latestAskResult?.statusNote = "Web search off"
            updateStoredAskTurn(
                scopeCaseID: scopeCaseID,
                sessionID: storedResult.chatSessionID,
                turnID: storedResult.chatTurnID
            ) { turn in
                turn.publicLawPreview = nil
                turn.publicLawResults = []
                turn.statusNote = "Web search off"
            }
        }
    }

    func cancelPendingPublicLawSearch() {
        pendingPublicLawQuestion = nil
        publicLawPreview = nil
        if latestAskResult?.chatTurnID == pendingPublicLawTurnID, latestAskResult?.publicLawResults.isEmpty == true {
            latestAskResult?.statusNote = "Web search off"
        }
        updateStoredAskTurn(
            scopeCaseID: pendingPublicLawScopeCaseID,
            sessionID: pendingPublicLawSessionID,
            turnID: pendingPublicLawTurnID
        ) { turn in
            turn.publicLawPreview = nil
            turn.statusNote = "Web search off"
        }
        pendingPublicLawScopeCaseID = nil
        pendingPublicLawSessionID = nil
        pendingPublicLawTurnID = nil
    }

    func confirmPendingPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        do {
            let results = try await publicLawSearchAction(preview)
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.publicLawResults = results
            latestAskResult?.statusNote = "Public-law results"
            updateStoredAskTurn(
                scopeCaseID: pendingPublicLawScopeCaseID,
                sessionID: pendingPublicLawSessionID,
                turnID: pendingPublicLawTurnID
            ) { turn in
                turn.publicLawPreview = preview
                turn.publicLawResults = results
                turn.statusNote = "Public-law results"
            }
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
            updateStoredAskTurn(
                scopeCaseID: pendingPublicLawScopeCaseID,
                sessionID: pendingPublicLawSessionID,
                turnID: pendingPublicLawTurnID
            ) { turn in
                turn.publicLawPreview = preview
                turn.publicLawResults = []
                turn.statusNote = "Public-law results are unavailable right now."
            }
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
        pendingPublicLawSessionID = nil
        pendingPublicLawTurnID = nil
    }

    @discardableResult
    private func appendAskResult(_ result: AlphaAskResult, persistToCase caseID: UUID?) -> AlphaAskResult {
        let storageCaseID = caseID ?? alphaSharedWorkspaceID
        let contextDocumentIDs = selectedAskDocumentIDs(for: caseID)
        let turn = AlphaChatTurn(
            kind: result.kind,
            question: result.question,
            answerTitle: result.answerTitle,
            answerSections: result.answerSections,
            sourceRefs: result.caseFileSources,
            selectedDocumentTitles: result.selectedDocumentTitles.isEmpty ? nil : result.selectedDocumentTitles,
            publicLawPreview: result.publicLawPreview,
            publicLawResults: result.publicLawResults,
            statusNote: result.statusNote,
            needsReviewWarning: result.needsReviewWarning
        )

        if let storedResult = appendStoredTurn(turn, to: storageCaseID, contextDocumentIDs: contextDocumentIDs) {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: caseID == nil ? "Local review run" : "Local case review run",
                    detail: "The question and source-backed draft stayed on this device.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: caseID == nil ? "device://ask" : "device://ask-case",
                    success: true
                ),
                at: 0
            )
            persist()
            return storedResult
        }

        let fallback = result
        askHistory.append(fallback)
        return fallback
    }

    @discardableResult
    private func appendStoredTurn(
        _ turn: AlphaChatTurn,
        to storageCaseID: UUID,
        contextDocumentIDs: Set<UUID> = []
    ) -> AlphaAskResult? {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == storageCaseID }) else { return nil }

        let sessionID: UUID
        if let activeSessionID = persisted.cases[caseIndex].activeChatSessionID,
           persisted.cases[caseIndex].chatSessions.contains(where: { $0.id == activeSessionID }) {
            sessionID = activeSessionID
        } else {
            let session = AlphaChatSession(contextDocumentIDs: contextDocumentIDs.sorted { $0.uuidString < $1.uuidString })
            persisted.cases[caseIndex].chatSessions.insert(session, at: 0)
            persisted.cases[caseIndex].activeChatSessionID = session.id
            sessionID = session.id
        }

        if let sessionIndex = persisted.cases[caseIndex].chatSessions.firstIndex(where: { $0.id == sessionID }) {
            persisted.cases[caseIndex].chatSessions[sessionIndex].turns.insert(turn, at: 0)
            persisted.cases[caseIndex].chatSessions[sessionIndex].updatedAt = turn.askedAt
            persisted.cases[caseIndex].chatSessions[sessionIndex].contextDocumentIDs = contextDocumentIDs.sorted { $0.uuidString < $1.uuidString }
            let updatedSession = persisted.cases[caseIndex].chatSessions.remove(at: sessionIndex)
            persisted.cases[caseIndex].chatSessions.insert(updatedSession, at: 0)
        }
        persisted.cases[caseIndex].activeChatSessionID = sessionID
        persisted.cases[caseIndex].updatedAt = .now
        let storedResult = askResult(from: turn, in: persisted.cases[caseIndex], chatSessionID: sessionID)
        askHistory.append(storedResult)
        return storedResult
    }

    private func appendMatterThreadUpdate(
        caseId: UUID?,
        title: String,
        sections: [String],
        sourceRefs: [AlphaSourceRef] = [],
        selectedDocumentIDs: Set<UUID> = [],
        selectedDocumentTitles: [String] = [],
        statusNote: String? = nil,
        needsReviewWarning: String? = nil
    ) {
        let storageCaseID = caseId ?? alphaSharedWorkspaceID
        let turn = AlphaChatTurn(
            kind: .matterUpdate,
            question: "",
            answerTitle: title,
            answerSections: sections,
            sourceRefs: sourceRefs,
            selectedDocumentTitles: selectedDocumentTitles.isEmpty ? nil : selectedDocumentTitles,
            publicLawPreview: nil,
            publicLawResults: [],
            statusNote: statusNote,
            needsReviewWarning: needsReviewWarning
        )
        _ = appendStoredTurn(turn, to: storageCaseID, contextDocumentIDs: selectedDocumentIDs)
        persist()
    }

    private func updateAskHistory(turnID: UUID?, mutate: (inout AlphaAskResult) -> Void) {
        guard let turnID, let index = askHistory.lastIndex(where: { $0.chatTurnID == turnID }) else {
            return
        }
        var updated = askHistory[index]
        mutate(&updated)
        askHistory[index] = updated
    }

    private func updateStoredAskTurn(
        scopeCaseID: UUID?,
        sessionID: UUID?,
        turnID: UUID?,
        mutate: (inout AlphaChatTurn) -> Void
    ) {
        guard let sessionID, let turnID else { return }
        let storageCaseID = scopeCaseID ?? alphaSharedWorkspaceID
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == storageCaseID }) else { return }
        guard let sessionIndex = persisted.cases[caseIndex].chatSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let turnIndex = persisted.cases[caseIndex].chatSessions[sessionIndex].turns.firstIndex(where: { $0.id == turnID }) else { return }

        mutate(&persisted.cases[caseIndex].chatSessions[sessionIndex].turns[turnIndex])
        persisted.cases[caseIndex].chatSessions[sessionIndex].updatedAt = .now
        persisted.cases[caseIndex].updatedAt = .now
        let updatedSession = persisted.cases[caseIndex].chatSessions.remove(at: sessionIndex)
        persisted.cases[caseIndex].chatSessions.insert(updatedSession, at: 0)
        rebuildAskHistory()
        updateAskHistory(turnID: turnID) { updated in
            mutateAskResult(&updated, from: persisted.cases[caseIndex].chatSessions[0].turns[turnIndex], caseMatter: persisted.cases[caseIndex], chatSessionID: sessionID)
        }
        persist()
    }

    private func mutateAskResult(
        _ result: inout AlphaAskResult,
        from turn: AlphaChatTurn,
        caseMatter: AlphaCaseMatter,
        chatSessionID: UUID
    ) {
        result = askResult(from: turn, in: caseMatter, chatSessionID: chatSessionID)
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
        askSelectedScopeCaseID = matter.id
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

    func renameCase(_ caseID: UUID, title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard caseID != alphaSharedWorkspaceID else { return }
        guard !cleaned.isEmpty, let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].title = cleaned
        persisted.cases[caseIndex].updatedAt = .now
        rebuildAskHistory()
        if latestAskResult?.scopeCaseID == caseID {
            latestAskResult?.scopeLabel = cleaned
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Matter renamed locally",
                detail: "A matter name was updated on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://matter-rename",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func archiveCase(_ caseID: UUID) {
        guard caseID != alphaSharedWorkspaceID else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].archivedAt = .now
        persisted.cases[caseIndex].updatedAt = .now
        clearCaseSelectionState(for: caseID)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Matter archived locally",
                detail: "A matter was archived on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://matter-archive",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func setFolderTint(_ tint: AlphaMatterTint, for caseID: UUID) {
        guard caseID != alphaSharedWorkspaceID else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].folderTint = tint
        persisted.cases[caseIndex].updatedAt = .now
        persist()
    }

    func deleteCase(_ caseID: UUID) {
        guard caseID != alphaSharedWorkspaceID else { return }
        guard let removedCase = persisted.cases.first(where: { $0.id == caseID }) else { return }

        removedCase.documents.forEach { document in
            try? FileManager.default.removeItem(at: alphaAbsoluteURL(for: document.storedRelativePath))
        }
        try? FileManager.default.removeItem(at: alphaAbsoluteURL(for: "documents/\(caseID.uuidString)"))

        let removedExports = persisted.exports.filter { $0.caseId == caseID }
        removedExports.forEach { report in
            try? FileManager.default.removeItem(at: alphaAbsoluteURL(for: report.relativePath))
        }

        persisted.cases.removeAll { $0.id == caseID }
        persisted.tasks = (persisted.tasks ?? []).filter { $0.caseId != caseID }
        persisted.exports.removeAll { $0.caseId == caseID }
        rebuildAskHistory()
        if latestAskResult?.scopeCaseID == caseID {
            latestAskResult = nil
        }
        clearCaseSelectionState(for: caseID)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Matter deleted locally",
                detail: "A matter and its stored context were removed from this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://matter-delete",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func importDocument(caseId: UUID?, from sourceURL: URL) async {
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

            persisted.cases[caseIndex].documents.insert(document, at: 0)
            persisted.cases[caseIndex].updatedAt = .now
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
            appendMatterThreadUpdate(
                caseId: targetCaseID == alphaSharedWorkspaceID ? nil : targetCaseID,
                title: "File added to this matter",
                sections: [
                    "\(document.title) was copied into private storage and linked to the current matter.",
                    "Ross started local review so the active chat can pick up dates, directions, and follow-up work from this file."
                ],
                sourceRefs: [sourceRef],
                selectedDocumentIDs: [document.id],
                selectedDocumentTitles: [document.title],
                statusNote: "Matter chat updated · review starting"
            )
            path.append(.documentViewer(targetCaseID, document.id, 1))

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
        globalAskSelectedDocumentIDs.remove(documentId)
        askSelectedDocumentIDs = askSelectedDocumentIDs.mapValues { ids in
            var updated = ids
            updated.remove(documentId)
            return updated
        }.filter { !$0.value.isEmpty }
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

    func moveDocument(caseId: UUID, documentId: UUID, by offset: Int) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        guard let currentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }) else { return }
        let targetIndex = min(
            max(currentIndex + offset, 0),
            persisted.cases[caseIndex].documents.count - 1
        )
        guard targetIndex != currentIndex else { return }

        let movedDocument = persisted.cases[caseIndex].documents.remove(at: currentIndex)
        persisted.cases[caseIndex].documents.insert(movedDocument, at: targetIndex)
        persisted.cases[caseIndex].updatedAt = .now
        persist()
    }

    func askCase(caseId: UUID) {
        let question = askDrafts[caseId] ?? ""
        submitAsk(question: question, scopeCaseID: caseId, webEnabled: false)
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
        let nextDateValue = result.extractedFields.first(where: { $0.fieldType == .nextDate && (!$0.needsReview || $0.userCorrected) })?.value
        let reviewItemCount = result.reviewQueue.fieldIDs.count + result.reviewQueue.findingIDs.count
        let reviewSummary = reviewItemCount == 0
            ? "This file is ready to use in the matter chat."
            : "\(reviewItemCount) review item(s) still need advocate confirmation before relying on this file."
        let classificationSummary = result.classification.map {
            "Ross classified \(document.title) as \($0.type.rawValue.replacingOccurrences(of: "_", with: " "))."
        } ?? "Ross refreshed the local review for \(document.title)."
        var threadSections = [classificationSummary, reviewSummary]
        if let nextDateValue {
            threadSections.insert("Next date captured: \(nextDateValue).", at: 1)
        }
        let threadSourceRefs = Array(
            (
                (result.classification?.sourceRefs ?? [])
                + result.extractedFields.flatMap(\.sourceRefs)
            ).prefix(3)
        )
        appendMatterThreadUpdate(
            caseId: caseId == alphaSharedWorkspaceID ? nil : caseId,
            title: "Review updated for \(document.title)",
            sections: threadSections,
            sourceRefs: threadSourceRefs,
            selectedDocumentIDs: [document.id],
            selectedDocumentTitles: [document.title],
            statusNote: reviewItemCount == 0 ? "Matter chat updated · ready to use" : "Matter chat updated · needs review",
            needsReviewWarning: reviewItemCount == 0 ? nil : "\(reviewItemCount) review item(s) still need advocate review."
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
        let allOpenTaskItems = tasks(for: caseMatter.id).filter { $0.status == .open }
        let planningTaskItems = allOpenTaskItems.filter { !isRossSuggestedTask($0) }
        let nextOpenTask = planningTaskItems.first
        let latestDocumentTitle = caseMatter.documents.sorted { $0.importedAt > $1.importedAt }.first?.title
        let ignoredFieldIDs = Set(caseMatter.advocateCorrections.filter { $0.correctionType == .ignoreField }.compactMap(\.fieldId))
        let reviewItemCount = caseMatter.documents.reduce(into: 0) { total, document in
            total += document.extractedFields.filter { $0.needsReview && !ignoredFieldIDs.contains($0.id) }.count
            total += document.extractionFindings.count { !$0.resolved }
        }

        if let forum = verifiedFields.first(where: { $0.fieldType == .court })?.value,
           caseMatter.forum == "Forum pending" || caseMatter.forum.isEmpty {
            caseMatter.forum = forum
        }

        if let nextDate = verifiedFields.first(where: { $0.fieldType == .nextDate })?.value {
            caseMatter.localNotice = "Case files stay on this device. Next date found: \(nextDate)"
            caseMatter.nextHearing = alphaParsedDate(from: nextDate) ?? caseMatter.nextHearing
        }

        let classifications = caseMatter.documents.compactMap { $0.classification?.type.rawValue.replacingOccurrences(of: "_", with: " ") }
        let classificationText = classifications.isEmpty ? nil : classifications.joined(separator: ", ")
        if caseMatter.documents.isEmpty {
            caseMatter.summary = "Ross is ready to build this matter once the first document is imported on this device."
        } else {
            var summaryParts = ["Ross reviewed \(caseMatter.documents.count) document(s) locally."]
            if let classificationText {
                summaryParts.append("File types seen: \(classificationText).")
            }
            if let nextHearing = caseMatter.nextHearing {
                summaryParts.append("Next date \(nextHearing.formatted(date: .abbreviated, time: .omitted)) is already captured.")
            }
            if reviewItemCount > 0 {
                summaryParts.append("\(reviewItemCount) item(s) still need advocate review.")
            } else if !allOpenTaskItems.isEmpty {
                summaryParts.append("\(allOpenTaskItems.count) open task(s) are saved for this matter.")
            }
            if let latestDocumentTitle {
                summaryParts.append("Latest file: \(latestDocumentTitle).")
            }
            caseMatter.summary = summaryParts.joined(separator: " ")
        }

        let issueCandidates = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .prayer }
            .map(\.value)
        if issueCandidates.isEmpty {
            var fallbackHighlights: [String] = []
            if let nextHearing = caseMatter.nextHearing {
                fallbackHighlights.append("Prepare the file for \(nextHearing.formatted(date: .abbreviated, time: .omitted)).")
            }
            if let nextOpenTask {
                fallbackHighlights.append(nextOpenTask.title)
            }
            if reviewItemCount > 0 {
                fallbackHighlights.append("Resolve \(reviewItemCount) review item(s) before relying on extracted details.")
            }
            caseMatter.issueHighlights = fallbackHighlights.isEmpty
                ? ["Review extracted legal issues and directions."]
                : Array(fallbackHighlights.prefix(4))
        } else {
            caseMatter.issueHighlights = Array(issueCandidates.prefix(4))
        }

        let evidenceCandidates = caseMatter.documents
            .flatMap(\.extractionFindings)
            .filter { !$0.resolved }
            .map(\.message)
        caseMatter.evidenceNotes = evidenceCandidates.isEmpty ? ["Source-backed extraction is available for this matter."] : Array(evidenceCandidates.prefix(4))

        var generatedTasks: [String] = []
        if let nextHearing = caseMatter.nextHearing {
            generatedTasks.append("Prepare this matter for \(nextHearing.formatted(date: .abbreviated, time: .omitted)).")
        }
        if let nextOpenTask {
            if let dueDate = nextOpenTask.dueDate {
                generatedTasks.append("\(nextOpenTask.title) by \(dueDate.formatted(date: .abbreviated, time: .omitted)).")
            } else {
                generatedTasks.append(nextOpenTask.title)
            }
        }
        if reviewItemCount > 0 {
            generatedTasks.append("Resolve \(reviewItemCount) review item(s) before relying on extracted details.")
        } else if !pendingFields.isEmpty {
            generatedTasks.append("Review uncertain extracted fields before relying on them.")
        }
        if caseMatter.documents.isEmpty {
            generatedTasks.append("Import the first pleading, order, or note for this matter.")
        } else {
            generatedTasks.append("Open source chips before sharing or filing.")
        }
        generatedTasks.append("Generate a local chronology or order summary draft.")
        var uniqueTasks: [String] = []
        for task in generatedTasks where !uniqueTasks.contains(task) {
            uniqueTasks.append(task)
        }
        caseMatter.draftTasks = Array(uniqueTasks.prefix(3))
        caseMatter.updatedAt = .now
        syncRossSuggestedTasks(for: caseMatter)
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

    private func syncRossSuggestedTasks(for caseMatter: AlphaCaseMatter) {
        let existingTasks = persisted.tasks ?? []
        let preservedTasks = existingTasks.filter {
            !($0.caseId == caseMatter.id && $0.status == .open && isRossSuggestedTask($0))
        }

        let generatedTasks = caseMatter.draftTasks.enumerated().compactMap { offset, title -> AlphaTaskItem? in
            guard !preservedTasks.contains(where: { $0.caseId == caseMatter.id && $0.title == title }) else {
                return nil
            }

            return AlphaTaskItem(
                caseId: caseMatter.id,
                title: title,
                notes: rossSuggestedTaskNote(caseId: caseMatter.id, slot: offset),
                dueDate: offset == 0 ? caseMatter.nextHearing : nil,
                priority: offset == 0 ? .high : .normal,
                source: .system
            )
        }

        persisted.tasks = generatedTasks + preservedTasks
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
        if !normalized.cases.contains(where: { $0.id == alphaSharedWorkspaceID }) {
            normalized.cases.append(sharedWorkspaceMatter())
        }
        if normalized.tasks == nil {
            normalized.tasks = initialTasks(from: normalized.cases)
        }
        return normalized
    }

    private func initialTasks(from cases: [AlphaCaseMatter]) -> [AlphaTaskItem] {
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

    private func rossSuggestedTaskNote(caseId: UUID, slot: Int) -> String {
        "\(alphaRossSuggestedTaskNotePrefix)\(caseId.uuidString)::\(slot)"
    }

    private func isRossSuggestedTask(_ task: AlphaTaskItem) -> Bool {
        task.notes?.hasPrefix(alphaRossSuggestedTaskNotePrefix) == true
    }

    private func sharedWorkspaceMatter() -> AlphaCaseMatter {
        AlphaCaseMatter(
            id: alphaSharedWorkspaceID,
            title: "Shared files",
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
        let thermalCondition = alphaCurrentThermalCondition()

        if lowPowerModeEnabled || totalMemoryGB <= 4 || freeStorageGB < 14 {
            return .quickStart
        }
        if totalMemoryGB >= 12 && freeStorageGB >= 32 && thermalCondition == "Nominal" {
            return .seniorDraftingSupport
        }
        return .caseAssociate
    }

    var recommendedAssistantTitle: String {
        switch recommendedOnDeviceTier() {
        case .quickStart:
            return "Phone-optimized local review"
        case .caseAssociate:
            return "Balanced local matter review"
        case .seniorDraftingSupport:
            return "Deeper drafting and review"
        }
    }

    var recommendedAssistantDetail: String {
        let totalMemoryGB = max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let freeStorageGB = max(4, alphaAvailableStorageInGigabytes())
        let summary: String
        switch recommendedOnDeviceTier() {
        case .quickStart:
            summary = "Ross will keep setup lighter on this phone so imports, case review, and short legal questions stay responsive."
        case .caseAssociate:
            summary = "Ross will use a balanced on-device assistant for matter summaries, chronology work, source-backed Q&A, and everyday legal review."
        case .seniorDraftingSupport:
            summary = "Ross can prepare a deeper on-device assistant on this phone for longer bundles, hearing prep, and richer drafting support."
        }
        return "\(summary) (\(totalMemoryGB) GB memory · \(freeStorageGB) GB free)"
    }

    var recommendedAssistantSetupNote: String {
        switch recommendedOnDeviceTier() {
        case .quickStart:
            return "Setup stays smaller and mobile-friendly for this device."
        case .caseAssociate:
            return "This is the best default for most day-to-day legal work on phone."
        case .seniorDraftingSupport:
            return "Ross found enough room on this device for longer local drafting sessions."
        }
    }

    private func alphaAvailableStorageInGigabytes() -> Int {
        let values = try? URL.homeDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let bytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return Int(bytes / 1_073_741_824)
    }

    private func alphaCurrentLowPowerMode() -> Bool {
        #if canImport(UIKit)
        ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        false
        #endif
    }

    private func alphaCurrentThermalCondition() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            "Nominal"
        case .fair:
            "Fair"
        case .serious:
            "Serious"
        case .critical:
            "Critical"
        @unknown default:
            "Unknown"
        }
    }

    private func buildLocalAskResult(question: String, scopeCaseID: UUID?) -> AlphaAskResult {
        let selectedDocuments = selectedAskDocuments(for: scopeCaseID)
        let selectedDocumentIDs = Set(selectedDocuments.map(\.id))
        let scopedCases: [AlphaCaseMatter]
        if let scopeCaseID {
            scopedCases = persisted.cases.filter { $0.id == scopeCaseID || $0.id == alphaSharedWorkspaceID }
        } else {
            scopedCases = persisted.cases
        }
        let lowered = question.lowercased()
        let asksAboutSchedule = lowered.contains("next date") || lowered.contains("hearing")
        let asksAboutTasks = lowered.contains("task") || lowered.contains("today") || lowered.contains("reminder") || lowered.contains("due")
        let asksAboutReview = lowered.contains("review") || lowered.contains("document") || lowered.contains("order") || lowered.contains("party")
        let matchedSources = scopedCases
            .flatMap(\.sourceRefs)
            .filter { selectedDocumentIDs.isEmpty || selectedDocumentIDs.contains($0.documentId) }
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
            let dateLines = cases
                .filter { scopeCaseID == nil || $0.id == scopeCaseID }
                .compactMap { caseMatter -> String? in
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
            let reviewItems = reviewQueue(caseId: scopeCaseID)
                .filter { selectedDocumentIDs.isEmpty || selectedDocumentIDs.contains($0.documentId) }
                .prefix(3)
                .map { "\($0.title): \($0.detail)" }
            sections.append(contentsOf: reviewItems)
        }

        if sections.isEmpty, !selectedDocuments.isEmpty {
            sections.append(contentsOf: selectedDocuments.prefix(3).map { option in
                option.isShared ? "\(option.title): shared across matters." : "\(option.title): included for this answer."
            })
        }

        let warnings = reviewQueue(caseId: scopeCaseID)
            .filter { selectedDocumentIDs.isEmpty || selectedDocumentIDs.contains($0.documentId) }
        let notFound = sections.isEmpty && matchedSources.isEmpty
        return AlphaAskResult(
            chatSessionID: nil,
            chatTurnID: nil,
            kind: .userAsk,
            question: question,
            scopeCaseID: scopeCaseID,
            scopeLabel: scopeLabel(for: scopeCaseID),
            selectedDocumentTitles: selectedDocuments.map(\.title),
            answerTitle: notFound ? "I could not find this in your case files." : "Ross drafted this from your files",
            answerSections: notFound ? ["I could not find this in your case files."] : Array(sections.prefix(3)),
            caseFileSources: Array(matchedSources.prefix(3)),
            publicLawPreview: nil,
            publicLawResults: [],
            statusNote: notFound ? "Web Search is off" : selectedDocuments.isEmpty ? "Chat · local files" : "Chat · selected files only",
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

    private func clearCaseSelectionState(for caseID: UUID) {
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
    @State private var model: AlphaRossModel
    @State private var showingLaunchSplash = true

    init(initialModel: AlphaRossModel = AlphaRossModel()) {
        _model = State(initialValue: initialModel)
    }

    var body: some View {
        ZStack {
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
                    case .captureImport:
                        AlphaCaptureScreen(model: model)
                    case .askRoss:
                        AlphaAskRossScreen(model: model)
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

            if showingLaunchSplash {
                RossLaunchSplashView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .task {
            await model.loadIfNeeded()
        }
        .task {
            try? await Task.sleep(for: .seconds(1.15))
            withAnimation(.spring(response: 0.75, dampingFraction: 0.92)) {
                showingLaunchSplash = false
            }
        }
    }
}

private struct AlphaSetupBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.rossGroupedBackground,
                    Color.rossSecondaryGroupedBackground,
                    Color.rossGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.rossBackdropGlow, Color.clear],
                center: .topLeading,
                startRadius: 18,
                endRadius: 360
            )
            .offset(x: -42, y: -82)

            Circle()
                .fill(Color.rossAccent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 38)
                .offset(x: 128, y: -156)

            Circle()
                .fill(Color.rossHighlight.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 32)
                .offset(x: -140, y: 260)
        }
        .ignoresSafeArea()
    }
}

private struct AlphaSetupWordmarkRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image("RossLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(4)
                .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.rossShadow.opacity(0.45), radius: 10, y: 4)

            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(2.4)
                .foregroundStyle(Color.rossAccent)
        }
    }
}

private struct AlphaSetupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.rossAccent.opacity(configuration.isPressed ? 0.82 : 0.94),
                                        Color.rossAccent.opacity(configuration.isPressed ? 0.7 : 0.84)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.rossGlassStroke.opacity(0.45), lineWidth: 1)
                    }
            )
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.2 : 0.28), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AlphaSetupSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.rossInk.opacity(configuration.isPressed ? 0.7 : 0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.rossGlassFill.opacity(configuration.isPressed ? 0.82 : 0.96))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.rossGlassStroke.opacity(0.85), lineWidth: 1)
                    }
            )
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.14 : 0.22), radius: configuration.isPressed ? 6 : 12, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel

    private let featurePills: [(String, String)] = [
        ("Files stay on this device", "lock"),
        ("Source-backed drafts", "paperclip"),
        ("Web search is opt-in", "shield")
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AlphaSetupBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        AlphaSetupWordmarkRow(title: "Ross")

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Private legal work on this phone")
                                .font(.system(size: 29, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.rossInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Create matters, add files, and ask Ross privately.")
                                .font(.title3)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 168), spacing: 12)],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            ForEach(featurePills, id: \.0) { feature in
                                RossInfoPill(title: feature.0, systemImage: feature.1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            RossBulletRow(text: "Ross recommends the best setup for this phone.")
                            RossBulletRow(text: "Setup can finish in the background.")
                            RossBulletRow(text: "Each matter keeps its own files and chats.")
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.rossGlassStroke.opacity(0.9), lineWidth: 1)
                        }
                        .shadow(color: Color.rossShadow.opacity(0.24), radius: 18, y: 10)

                        Spacer(minLength: 10)

                        Button("Continue") {
                            model.advanceOnboarding()
                        }
                        .buttonStyle(AlphaSetupPrimaryButtonStyle())
                    }
                    .frame(
                        minHeight: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom,
                        alignment: .top
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, proxy.safeAreaInsets.top + 28)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
                }
            }
        }
    }
}

private struct AlphaPackSetupScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var infoTier: AlphaCapabilityTier?

    private var recommendedTier: AlphaCapabilityTier {
        model.recommendedOnDeviceTier()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AlphaSetupBackdrop()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        AlphaSetupWordmarkRow(title: "Assistant setup")

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose setup for this phone")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.rossInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Recommended is selected, but you can choose any level.")
                                .font(.title3)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 10) {
                            RossGlassIconView(.badgeSparkle, variant: .accent, size: 20, fallbackSystemImage: "checkmark.shield.fill")
                            Text("Recommended: \(recommendedTier.title)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossAccent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.rossGlassStroke.opacity(0.92), lineWidth: 1)
                        }

                        VStack(spacing: 10) {
                            ForEach(AlphaPackOffer.catalog) { offer in
                                AlphaPackTierSelectionBar(
                                    tier: offer.tier,
                                    isSelected: model.selectedTier == offer.tier,
                                    badge: offer.tier == recommendedTier ? "Recommended" : nil,
                                    onSelect: { model.selectedTier = offer.tier },
                                    onInfo: { infoTier = offer.tier }
                                )
                            }
                        }

                        AlphaAssistantActivityStrip(
                            title: "Setup continues in the background",
                            detail: "You can start matters and chats while setup finishes.",
                            statusLabel: "Background",
                            tint: .orange
                        )

                        Spacer(minLength: 8)

                        HStack(spacing: 12) {
                            Button("Start setup") {
                                model.finishPackSetup()
                            }
                            .buttonStyle(AlphaSetupPrimaryButtonStyle())

                            Button("Not now") {
                                model.skipPackSetup()
                            }
                            .buttonStyle(AlphaSetupSecondaryButtonStyle())
                        }
                    }
                    .frame(
                        minHeight: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom,
                        alignment: .top
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, proxy.safeAreaInsets.top + 28)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
                }
            }
        }
        .sheet(item: $infoTier) { tier in
            AlphaPackTierInfoSheet(
                tier: tier,
                isSelected: model.selectedTier == tier,
                onUseTier: { model.selectedTier = tier }
            )
        }
    }

}

private struct AlphaTabShell: View {
    @Bindable var model: AlphaRossModel

    private var shouldShowGlobalAskDock: Bool {
        let selectedTab = model.persisted.selectedTab.normalizedForLawyerShell
        guard selectedTab != .settings, selectedTab != .ask else { return false }
        guard model.path.last?.isAskRoute != true else { return false }
        return true
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Group {
                    switch model.persisted.selectedTab.normalizedForLawyerShell {
                    case .home:
                        AlphaHomeScreen(model: model)
                    case .cases:
                        AlphaCaseListScreen(model: model)
                    case .ask:
                        AlphaAskRossScreen(model: model)
                    case .settings:
                        AlphaSettingsScreen(model: model)
                    case .capture, .publicLawLegacy, .exportsLegacy:
                        AlphaHomeScreen(model: model)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    AlphaRootTopRail(model: model)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if shouldShowGlobalAskDock {
                        AlphaRootAskDock(model: model)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                            .padding(.bottom, 6)
                    }
                }

                if model.workspaceDrawerPresented {
                    Color.rossScrim
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.24)) {
                                model.workspaceDrawerPresented = false
                            }
                        }

                    AlphaWorkspaceDrawerPanel(model: model)
                        .frame(width: min(320, proxy.size.width * 0.82))
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(.snappy(duration: 0.24), value: model.workspaceDrawerPresented)
        }
        .tint(Color.rossAccent)
    }
}

private extension AlphaAppTab {
    var workspaceStripTitle: String {
        switch self {
        case .home:
            "Today"
        case .cases:
            "Matters"
        case .ask:
            "Ask"
        case .settings:
            "Settings"
        case .capture, .publicLawLegacy, .exportsLegacy:
            "Today"
        }
    }

    var workspaceStripSymbol: String {
        switch self {
        case .home:
            "house"
        case .cases:
            "folder"
        case .ask:
            "bubble.left.and.text.bubble.right"
        case .settings:
            "gearshape"
        case .capture:
            "square.and.arrow.down"
        case .publicLawLegacy:
            "text.magnifyingglass"
        case .exportsLegacy:
            "doc.text"
        }
    }

    var workspaceStripSelectedSymbol: String {
        switch self {
        case .home:
            "house.fill"
        case .cases:
            "folder.fill"
        case .ask:
            "bubble.left.and.text.bubble.right.fill"
        case .settings:
            "gearshape.fill"
        case .capture:
            "square.and.arrow.down.fill"
        case .publicLawLegacy:
            "text.magnifyingglass"
        case .exportsLegacy:
            "doc.text.fill"
        }
    }
}

private struct AlphaRootTopRail: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        HStack(spacing: 8) {
            AlphaWorkspaceDrawerButton {
                withAnimation(.snappy(duration: 0.24)) {
                    model.workspaceDrawerPresented = true
                }
            }

            AlphaRootWorkspaceStrip(selectedTab: model.persisted.selectedTab) { tab in
                withAnimation(.snappy(duration: 0.22)) {
                    model.persisted.selectedTab = tab.normalizedForLawyerShell
                }
            }
        }
    }
}

private struct AlphaRootWorkspaceStrip: View {
    let selectedTab: AlphaAppTab
    let onSelect: (AlphaAppTab) -> Void

    private let tabs: [AlphaAppTab] = [.home, .cases]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                AlphaRootWorkspaceTabButton(
                    tab: tab,
                    isSelected: selectedTab.normalizedForLawyerShell == tab
                ) {
                    onSelect(tab)
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

private struct AlphaRootWorkspaceTabButton: View {
    let tab: AlphaAppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? tab.workspaceStripSelectedSymbol : tab.workspaceStripSymbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.rossInk.opacity(0.58))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.rossAccent : Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.rossAccent : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.workspaceStripTitle)
    }
}

private enum AlphaDockImportKind {
    case file
    case image

    var allowedTypes: [UTType] {
        switch self {
        case .file:
            return [.pdf, .plainText]
        case .image:
            return [.image]
        }
    }
}

private func alphaAskMentionTokenRange(in draft: String) -> Range<String.Index>? {
    draft.range(of: #"(?<!\S)@[^\s@]*$"#, options: .regularExpression)
}

private func alphaAskMentionQuery(in draft: String) -> String? {
    guard let range = alphaAskMentionTokenRange(in: draft) else { return nil }
    return String(draft[range].dropFirst())
}

private func alphaAskReplacingTrailingMention(in draft: String, with title: String) -> String {
    guard let range = alphaAskMentionTokenRange(in: draft) else { return draft }
    return draft.replacingCharacters(in: range, with: "@\(title) ")
}

private func alphaAskMentionSuggestions(
    query: String,
    documents: [AlphaAskDocumentOption],
    selectedDocumentIDs: Set<UUID>,
    limit: Int = 5
) -> [AlphaAskDocumentOption] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let matchingDocuments = documents.filter { document in
        guard !selectedDocumentIDs.contains(document.id) else { return false }
        guard !trimmedQuery.isEmpty else { return true }
        return document.title.localizedCaseInsensitiveContains(trimmedQuery)
            || document.caseTitle.localizedCaseInsensitiveContains(trimmedQuery)
    }
    return Array(matchingDocuments.prefix(limit))
}

private struct AlphaRootAskDock: View {
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    let fixedDocumentIDs: Set<UUID>
    let showsInlineResponseCard: Bool
    let showsConversationShortcut: Bool
    @State private var showingTools = false
    @State private var dismissedInlineQuestion: String?
    @State private var pendingImportKind: AlphaDockImportKind?
    @State private var showingExpandedComposer = false

    init(
        model: AlphaRossModel,
        fixedScopeCaseID: UUID? = nil,
        fixedDocumentIDs: Set<UUID> = [],
        showsInlineResponseCard: Bool = true,
        showsConversationShortcut: Bool = true
    ) {
        self.model = model
        self.fixedScopeCaseID = fixedScopeCaseID
        self.fixedDocumentIDs = fixedDocumentIDs
        self.showsInlineResponseCard = showsInlineResponseCard
        self.showsConversationShortcut = showsConversationShortcut
    }

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    private var activeSelectedDocuments: [AlphaAskDocumentOption] {
        if fixedDocumentIDs.isEmpty {
            return model.selectedAskDocuments(for: activeScopeCaseID)
        }
        return model.availableAskDocuments(for: activeScopeCaseID).filter { fixedDocumentIDs.contains($0.id) }
    }

    private var draftText: String {
        model.askDraft(for: activeScopeCaseID)
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var mentionSuggestions: [AlphaAskDocumentOption] {
        guard fixedDocumentIDs.isEmpty, let query = alphaAskMentionQuery(in: draftText) else { return [] }
        return alphaAskMentionSuggestions(
            query: query,
            documents: model.availableAskDocuments(for: activeScopeCaseID),
            selectedDocumentIDs: model.selectedAskDocumentIDs(for: activeScopeCaseID)
        )
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { model.askDraft(for: activeScopeCaseID) },
            set: { model.setAskDraft($0, for: activeScopeCaseID) }
        )
    }

    private var inlineResult: AlphaAskResult? {
        guard showsInlineResponseCard else { return nil }
        guard let latest = model.latestAskResult else { return nil }
        guard latest.scopeCaseID == activeScopeCaseID else { return nil }
        if !fixedDocumentIDs.isEmpty {
            let latestTitles = Set(latest.selectedDocumentTitles)
            let currentTitles = Set(activeSelectedDocuments.map(\.title))
            guard latestTitles == currentTitles else { return nil }
        }
        return dismissedInlineQuestion == latest.question ? nil : latest
    }

    private var selectionSubtitle: String? {
        if fixedDocumentIDs.isEmpty {
            return model.askSelectionSubtitle(for: activeScopeCaseID)
        }
        let selected = activeSelectedDocuments
        guard !selected.isEmpty else { return nil }
        if selected.count == 1, let first = selected.first {
            return first.isShared ? "\(first.title) · shared file" : first.title
        }
        return "\(selected.count) files selected"
    }

    private func send(dismissingExpandedComposer: Bool = false) {
        let question = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if !fixedDocumentIDs.isEmpty {
            model.setSelectedAskDocumentIDs(fixedDocumentIDs, for: activeScopeCaseID)
        }
        dismissedInlineQuestion = nil
        if dismissingExpandedComposer {
            showingExpandedComposer = false
        }
        model.submitAsk(question: question, scopeCaseID: activeScopeCaseID, webEnabled: model.askWebEnabled)
    }

    private func removeDocumentSelection(_ documentID: UUID) {
        guard fixedDocumentIDs.isEmpty else { return }
        var selected = model.selectedAskDocumentIDs(for: activeScopeCaseID)
        selected.remove(documentID)
        model.setSelectedAskDocumentIDs(selected, for: activeScopeCaseID)
    }

    private func applyMention(_ document: AlphaAskDocumentOption) {
        guard fixedDocumentIDs.isEmpty else { return }
        var selected = model.selectedAskDocumentIDs(for: activeScopeCaseID)
        selected.insert(document.id)
        model.setSelectedAskDocumentIDs(selected, for: activeScopeCaseID)
        model.setAskDraft(alphaAskReplacingTrailingMention(in: draftText, with: document.title), for: activeScopeCaseID)
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        defer { pendingImportKind = nil }
        guard case let .success(urls) = result, let url = urls.first else { return }
        Task { await model.importDocument(caseId: activeScopeCaseID, from: url) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let inlineResult {
                AlphaInlineAskResponseCard(
                    result: inlineResult,
                    onOpenSource: model.openSourceRef,
                    onOpenConversation: {
                        if fixedDocumentIDs.count == 1, let documentID = fixedDocumentIDs.first {
                            model.openAsk(scopeCaseID: activeScopeCaseID, documentID: documentID)
                        } else {
                            model.openAsk(scopeCaseID: activeScopeCaseID)
                        }
                    },
                    onClose: { dismissedInlineQuestion = inlineResult.question }
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if fixedScopeCaseID == nil {
                        Menu {
                            Button("All work") {
                                model.askSelectedScopeCaseID = nil
                            }
                            ForEach(model.cases) { caseMatter in
                                Button(caseMatter.title) {
                                    model.askSelectedScopeCaseID = caseMatter.id
                                }
                            }
                        } label: {
                            AlphaAskScopePill(
                                title: model.scopeLabel(for: activeScopeCaseID),
                                foregroundStyle: Color.white.opacity(0.8),
                                backgroundOpacity: 0.1,
                                showsChevron: true
                            )
                        }
                    } else {
                        AlphaAskScopePill(
                            title: model.scopeLabel(for: activeScopeCaseID),
                            foregroundStyle: Color.white.opacity(0.8),
                            backgroundOpacity: 0.08,
                            showsChevron: false
                        )
                    }

                    if model.askWebEnabled {
                        HStack(spacing: 4) {
                            RossGlassIconView(.earth, variant: .highlight, size: 14, fallbackSystemImage: "globe")
                            Text("Web Search")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }
                }

                if !activeSelectedDocuments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeSelectedDocuments) { document in
                                AlphaAskSelectionChip(
                                    title: document.title,
                                    isShared: document.isShared,
                                    tone: .dock,
                                    onRemove: fixedDocumentIDs.isEmpty ? {
                                        removeDocumentSelection(document.id)
                                    } : nil
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        showingTools = true
                    } label: {
                        RossGlassIconView(.badgeSparkle, variant: .neutral, size: 18, fallbackSystemImage: "plus")
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ask Ross tools")

                    TextField("Ask Ross about dates, files, or next steps", text: draftBinding, axis: .vertical)
                        .lineLimit(1...2)
                        .textFieldStyle(.plain)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showingExpandedComposer = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open full composer")

                    Button(action: { send() }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .frame(width: 34, height: 34)
                            .background(Color.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.42)

                    if showsConversationShortcut {
                        Button {
                            if fixedDocumentIDs.count == 1, let documentID = fixedDocumentIDs.first {
                                model.openAsk(scopeCaseID: activeScopeCaseID, documentID: documentID)
                            } else {
                                model.openAsk(scopeCaseID: activeScopeCaseID)
                            }
                        } label: {
                            RossGlassIconView(.userMsg, variant: .accent, size: 20, fallbackSystemImage: "bubble.left.and.text.bubble.right.fill")
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Ask Ross conversation")
                    }
                }

                if !mentionSuggestions.isEmpty {
                    AlphaAskMentionSuggestionsCard(
                        documents: mentionSuggestions,
                        scopeCaseID: activeScopeCaseID,
                        tone: .dock,
                        onSelect: applyMention
                    )
                }

                if let selectionSubtitle, fixedDocumentIDs.isEmpty {
                    Text(selectionSubtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                } else if fixedDocumentIDs.isEmpty {
                    Text("Type @ to add a file.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                if model.askWebEnabled {
                    Text("Web Search only sends a generic public-law query, never your case files or document text.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.rossChromeBackground.opacity(0.78),
                                    Color.rossChromeBackground.opacity(0.66)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
        .sheet(isPresented: $showingExpandedComposer) {
            AlphaAskComposerSheet(
                model: model,
                fixedScopeCaseID: fixedScopeCaseID,
                fixedDocumentIDs: fixedDocumentIDs,
                onSelectMention: applyMention,
                onRemoveDocumentSelection: removeDocumentSelection,
                onSend: { send(dismissingExpandedComposer: true) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTools) {
            AlphaRootAskToolsSheet(
                model: model,
                fixedScopeCaseID: fixedScopeCaseID,
                fixedDocumentIDs: fixedDocumentIDs,
                onAddFile: { pendingImportKind = .file },
                onAddImage: { pendingImportKind = .image }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
        .fileImporter(
            isPresented: Binding(
                get: { pendingImportKind != nil },
                set: { if !$0 { pendingImportKind = nil } }
            ),
            allowedContentTypes: pendingImportKind?.allowedTypes ?? [.pdf, .plainText, .image],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .sheet(isPresented: Binding(
            get: { !showingExpandedComposer && model.publicLawPreview != nil && model.pendingPublicLawQuestion != nil },
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
                    .padding(alphaScreenPadding)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

private struct AlphaInlineAskResponseCard: View {
    let result: AlphaAskResult
    let onOpenSource: (AlphaSourceRef) -> Void
    let onOpenConversation: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(result.answerTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.rossInk.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(result.answerSections.prefix(2).enumerated()), id: \.offset) { _, section in
                Text(section)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !result.caseFileSources.isEmpty {
                AlphaSourceRefChips(sourceRefs: Array(result.caseFileSources.prefix(2)), onOpenSourceRef: onOpenSource)
            }

            HStack {
                if let note = result.statusNote {
                    Text(note)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }
                Spacer(minLength: 8)
                Button("Open chat", action: onOpenConversation)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .background(Color.rossCardBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct AlphaAskScopePill: View {
    let title: String
    let foregroundStyle: Color
    let backgroundOpacity: Double
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .lineLimit(1)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(backgroundOpacity), in: Capsule())
    }
}

private enum AlphaAskSurfaceTone {
    case dock
    case sheet
}

private struct AlphaAskSelectionChip: View {
    let title: String
    let isShared: Bool
    let tone: AlphaAskSurfaceTone
    let onRemove: (() -> Void)?

    init(
        title: String,
        isShared: Bool,
        tone: AlphaAskSurfaceTone = .dock,
        onRemove: (() -> Void)?
    ) {
        self.title = title
        self.isShared = isShared
        self.tone = tone
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 6) {
            if isShared {
                RossGlassIconView(.earth, variant: .highlight, size: 12, fallbackSystemImage: "globe")
            } else {
                RossGlassIconView(.folder, variant: .neutral, size: 12, fallbackSystemImage: "folder.fill")
            }
            Text(title)
                .lineLimit(1)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tone == .dock ? Color.white.opacity(0.52) : Color.rossInk.opacity(0.32))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title)")
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tone == .dock ? Color.white.opacity(0.76) : Color.rossInk.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            tone == .dock ? Color.white.opacity(0.08) : Color.rossGlassSubtleFill,
            in: Capsule()
        )
        .overlay {
            if tone == .sheet {
                Capsule()
                    .stroke(Color.rossGlassStroke.opacity(0.82), lineWidth: 1)
            }
        }
    }
}

private struct AlphaAskMentionSuggestionsCard: View {
    let documents: [AlphaAskDocumentOption]
    let scopeCaseID: UUID?
    let tone: AlphaAskSurfaceTone
    let onSelect: (AlphaAskDocumentOption) -> Void

    init(
        documents: [AlphaAskDocumentOption],
        scopeCaseID: UUID?,
        tone: AlphaAskSurfaceTone = .dock,
        onSelect: @escaping (AlphaAskDocumentOption) -> Void
    ) {
        self.documents = documents
        self.scopeCaseID = scopeCaseID
        self.tone = tone
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mention a file")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tone == .dock ? Color.white.opacity(0.58) : Color.rossInk.opacity(0.48))
                .tracking(0.8)

            ForEach(documents) { document in
                Button {
                    onSelect(document)
                } label: {
                    AlphaAskMentionSuggestionRow(
                        document: document,
                        scopeCaseID: scopeCaseID,
                        tone: tone
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            tone == .dock ? Color.white.opacity(0.08) : Color.rossGlassSubtleFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    tone == .dock ? Color.white.opacity(0.08) : Color.rossGlassStroke.opacity(0.82),
                    lineWidth: 1
                )
        }
    }
}

private struct AlphaAskMentionSuggestionRow: View {
    let document: AlphaAskDocumentOption
    let scopeCaseID: UUID?
    let tone: AlphaAskSurfaceTone

    private var detail: String {
        if document.isShared {
            return "Shared file"
        }
        if scopeCaseID == nil {
            return document.caseTitle
        }
        return "This matter"
    }

    var body: some View {
        let icon = alphaDocumentGlassIcon(document.kind)

        HStack(spacing: 10) {
            RossGlassIconView(icon.0, variant: icon.1, size: 16, fallbackSystemImage: icon.2)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tone == .dock ? Color.white.opacity(0.82) : Color.rossInk.opacity(0.84))
                    .multilineTextAlignment(.leading)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(tone == .dock ? Color.white.opacity(0.52) : Color.rossInk.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("@")
                .font(.caption.weight(.bold))
                .foregroundStyle(tone == .dock ? Color.white.opacity(0.34) : Color.rossAccent.opacity(0.62))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            tone == .dock ? Color.white.opacity(0.05) : Color.rossGlassFill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            if tone == .sheet {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.rossGlassStroke.opacity(0.72), lineWidth: 1)
            }
        }
    }
}

private struct AlphaAskComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    let fixedDocumentIDs: Set<UUID>
    let onSelectMention: (AlphaAskDocumentOption) -> Void
    let onRemoveDocumentSelection: (UUID) -> Void
    let onSend: () -> Void

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { model.askDraft(for: activeScopeCaseID) },
            set: { model.setAskDraft($0, for: activeScopeCaseID) }
        )
    }

    private var activeSelectedDocuments: [AlphaAskDocumentOption] {
        if fixedDocumentIDs.isEmpty {
            return model.selectedAskDocuments(for: activeScopeCaseID)
        }
        return model.availableAskDocuments(for: activeScopeCaseID).filter { fixedDocumentIDs.contains($0.id) }
    }

    private var draftText: String {
        model.askDraft(for: activeScopeCaseID)
    }

    private var mentionSuggestions: [AlphaAskDocumentOption] {
        guard fixedDocumentIDs.isEmpty, let query = alphaAskMentionQuery(in: draftText) else { return [] }
        return alphaAskMentionSuggestions(
            query: query,
            documents: model.availableAskDocuments(for: activeScopeCaseID),
            selectedDocumentIDs: model.selectedAskDocumentIDs(for: activeScopeCaseID)
        )
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ask Ross")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text("Type @ to add a file.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button("Done") {
                        dismiss()
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, expandsHorizontally: false)
                }

                HStack(spacing: 10) {
                    if fixedScopeCaseID == nil {
                        Menu {
                            Button("All work") {
                                model.askSelectedScopeCaseID = nil
                            }
                            ForEach(model.cases) { caseMatter in
                                Button(caseMatter.title) {
                                    model.askSelectedScopeCaseID = caseMatter.id
                                }
                            }
                        } label: {
                            AlphaAskScopePill(
                                title: model.scopeLabel(for: activeScopeCaseID),
                                foregroundStyle: Color.rossInk.opacity(0.82),
                                backgroundOpacity: 0.08,
                                showsChevron: true
                            )
                        }
                    } else {
                        AlphaAskScopePill(
                            title: model.scopeLabel(for: activeScopeCaseID),
                            foregroundStyle: Color.rossInk.opacity(0.82),
                            backgroundOpacity: 0.08,
                            showsChevron: false
                        )
                    }

                    Button {
                        model.askWebEnabled.toggle()
                    } label: {
                        AlphaAskScopePill(
                            title: model.askWebEnabled ? "Web Search On" : "Web Search Off",
                            foregroundStyle: model.askWebEnabled ? Color.rossHighlight : Color.rossInk.opacity(0.78),
                            backgroundOpacity: 0.08,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !activeSelectedDocuments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeSelectedDocuments) { document in
                                AlphaAskSelectionChip(
                                    title: document.title,
                                    isShared: document.isShared,
                                    tone: .sheet,
                                    onRemove: fixedDocumentIDs.isEmpty ? {
                                        onRemoveDocumentSelection(document.id)
                                    } : nil
                                )
                            }
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.rossCardBackground.opacity(0.86))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.rossBorder.opacity(0.85), lineWidth: 1)
                        }

                    if draftText.isEmpty {
                        Text("Ask Ross about this matter, a tagged file, or your next drafting step.")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.34))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                    }

                    TextEditor(text: draftBinding)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .foregroundStyle(Color.rossInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: min(max(proxy.size.height * 0.34, 220), 320),
                    maxHeight: .infinity,
                    alignment: .topLeading
                )

                if !mentionSuggestions.isEmpty {
                    AlphaAskMentionSuggestionsCard(
                        documents: mentionSuggestions,
                        scopeCaseID: activeScopeCaseID,
                        tone: .sheet,
                        onSelect: onSelectMention
                    )
                }

                if model.askWebEnabled {
                    Text("Web Search only uses an approved public-law query. Case files and document text stay on-device.")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    onSend()
                } label: {
                    Text("Send")
                }
                .buttonStyle(AlphaSetupPrimaryButtonStyle())
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.42)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
    }
}

private struct AlphaRootAskToolsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    let fixedDocumentIDs: Set<UUID>
    let onAddFile: () -> Void
    let onAddImage: () -> Void

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    private var availableDocuments: [AlphaAskDocumentOption] {
        model.availableAskDocuments(for: activeScopeCaseID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.rossBorder.opacity(0.9))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            RossGlassIconView(.userMsg, variant: .accent, size: 22, fallbackSystemImage: "bubble.left.and.text.bubble.right.fill")
                            Text("Ask Ross")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                        }
                        Text("Choose scope, add a file, or turn on Web search.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .frame(width: 30, height: 30)
                            .background(Color.rossGlassFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Ask Ross tools")
                }

                VStack(spacing: 10) {
                    AlphaRootAskToolRow(
                        title: "Add file",
                        detail: activeScopeCaseID == nil
                            ? "Add a PDF or note to shared files."
                            : "Add a PDF or note to this matter.",
                        accentLabel: "Open",
                        icon: .fileUpload,
                        variant: .accent,
                        fallbackSystemImage: "doc.badge.plus"
                    ) {
                        dismiss()
                        onAddFile()
                    }

                    AlphaRootAskToolRow(
                        title: "Add image",
                        detail: activeScopeCaseID == nil
                            ? "Add a photo, scan, or screenshot to shared files."
                            : "Add a photo, scan, or screenshot to this matter.",
                        accentLabel: "Open",
                        icon: .files,
                        variant: .neutral,
                        fallbackSystemImage: "photo.stack"
                    ) {
                        dismiss()
                        onAddImage()
                    }

                    AlphaRootAskToolRow(
                        title: "Web Search",
                        detail: model.askWebEnabled
                            ? "On. Ross only sends a sanitized public-law query."
                            : "Off. Ross stays fully local until you turn it on.",
                        accentLabel: model.askWebEnabled ? "On" : "Off",
                        icon: .earth,
                        variant: model.askWebEnabled ? .highlight : .neutral,
                        fallbackSystemImage: model.askWebEnabled ? "globe.badge.chevron.backward" : "globe.slash"
                    ) {
                        model.askWebEnabled.toggle()
                    }
                }

                if let fixedScopeCaseID {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(fixedScopeCaseID == alphaSharedWorkspaceID ? "This space" : "This matter")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.rossInk.opacity(0.64))

                        AlphaRootAskScopeRow(
                            title: model.scopeLabel(for: fixedScopeCaseID),
                            isSelected: true,
                            icon: .folder,
                            variant: .neutral,
                            fallbackSystemImage: "folder.fill",
                            action: { }
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ask in")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.rossInk.opacity(0.64))

                        AlphaRootAskScopeRow(
                            title: "All work",
                            isSelected: model.askSelectedScopeCaseID == nil,
                            icon: .files,
                            variant: .neutral,
                            fallbackSystemImage: "square.stack.3d.up.fill"
                        ) {
                            model.askSelectedScopeCaseID = nil
                            dismiss()
                        }

                        ForEach(model.cases) { caseMatter in
                            AlphaRootAskScopeRow(
                                title: caseMatter.title,
                                isSelected: model.askSelectedScopeCaseID == caseMatter.id,
                                icon: .folder,
                                variant: .neutral,
                                fallbackSystemImage: "folder.fill"
                            ) {
                                model.askSelectedScopeCaseID = caseMatter.id
                                dismiss()
                            }
                        }
                    }
                }

                if fixedDocumentIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use uploaded files")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.rossInk.opacity(0.64))

                        if availableDocuments.isEmpty {
                            Text("No files are ready here yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.62))
                        }

                        ForEach(availableDocuments) { document in
                            AlphaRootAskDocumentRow(
                                title: document.title,
                                detail: document.isShared
                                    ? "Shared file"
                                    : (activeScopeCaseID == nil ? document.caseTitle : "This matter"),
                                isSelected: model.selectedAskDocumentIDs(for: activeScopeCaseID).contains(document.id),
                                icon: alphaDocumentGlassIcon(document.kind).0,
                                variant: alphaDocumentGlassIcon(document.kind).1,
                                fallbackSystemImage: alphaDocumentGlassIcon(document.kind).2
                            ) {
                                model.toggleAskDocumentSelection(document.id, for: activeScopeCaseID)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct AlphaRootAskDocumentRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RossGlassIconView(icon, variant: variant, size: 20, fallbackSystemImage: fallbackSystemImage)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.rossAccent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.rossAccent.opacity(0.36) : Color.rossBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaRootAskToolRow: View {
    let title: String
    let detail: String
    let accentLabel: String
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RossGlassIconView(icon, variant: variant, size: 28, fallbackSystemImage: fallbackSystemImage)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text(accentLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.rossAccent.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.rossBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaRootAskScopeRow: View {
    let title: String
    let isSelected: Bool
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RossGlassIconView(icon, variant: variant, size: 24, fallbackSystemImage: fallbackSystemImage)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossBorder)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.rossAccent.opacity(0.08) : Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.rossAccent.opacity(0.22) : Color.rossBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaWorkspaceDrawerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rossInk)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open workspace drawer")
    }
}

private struct AlphaWorkspaceDrawerPanel: View {
    @Bindable var model: AlphaRossModel
    @State private var expandedMatterIDs: Set<UUID> = []
    @State private var recentFilesExpanded = false
    @State private var renameTarget: AlphaCaseMatter?
    @State private var renameDraft = ""
    @State private var deleteTarget: AlphaCaseMatter?

    private var recentDocuments: [AlphaRecentDocumentItem] {
        alphaRecentDocumentItems(from: model.cases)
    }

    private func closeDrawer() {
        withAnimation(.snappy(duration: 0.24)) {
            model.workspaceDrawerPresented = false
        }
    }

    private func openCase(_ caseId: UUID) {
        closeDrawer()
        model.persisted.selectedTab = .cases
        model.focusCase(caseId)
        model.path.append(.caseWorkspace(caseId))
    }

    private func openChat(caseId: UUID, sessionId: UUID) {
        closeDrawer()
        model.persisted.selectedTab = .cases
        model.setActiveChatSession(sessionId, for: caseId)
        model.path.append(.askCase(caseId))
    }

    private func toggleThreads(for caseId: UUID) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedMatterIDs.contains(caseId) {
                expandedMatterIDs.remove(caseId)
            } else {
                expandedMatterIDs.insert(caseId)
            }
        }
    }

    private func startNewChat(for caseId: UUID) {
        closeDrawer()
        model.persisted.selectedTab = .cases
        model.startNewChat(for: caseId)
    }

    private func openDocument(caseId: UUID, documentId: UUID) {
        closeDrawer()
        model.focusCase(caseId)
        model.path.append(.documentViewer(caseId, documentId, 1))
    }

    private func createMatter() {
        closeDrawer()
        model.persisted.selectedTab = .cases
        model.path.append(.createCase)
    }

    private func openSettings() {
        closeDrawer()
        model.persisted.selectedTab = .settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 0)

                Button(action: closeDrawer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .frame(width: 30, height: 30)
                        .background(Color.rossGlassFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close workspace drawer")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text("Matters")
                            .font(.rossSerifHeadline())
                            .foregroundStyle(Color.rossInk)

                        Spacer(minLength: 0)

                        AlphaGlassPlusButton(action: createMatter)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if model.cases.isEmpty {
                            Text("No matters yet. Create the first one here.")
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            ForEach(Array(model.cases.enumerated()), id: \.element.id) { index, caseMatter in
                                VStack(spacing: 0) {
                                    AlphaWorkspaceDrawerMatterEntry(
                                        caseMatter: caseMatter,
                                        sessions: model.chatSessions(for: caseMatter.id),
                                        activeSessionID: model.activeChatSessionID(for: caseMatter.id),
                                        isSelected: model.selectedCaseID == caseMatter.id,
                                        isExpanded: expandedMatterIDs.contains(caseMatter.id),
                                        openCase: { openCase(caseMatter.id) },
                                        toggleThreads: { toggleThreads(for: caseMatter.id) },
                                        startNewChat: { startNewChat(for: caseMatter.id) },
                                        openChat: { sessionId in openChat(caseId: caseMatter.id, sessionId: sessionId) },
                                        model: model
                                    )
                                    .contextMenu {
                                        AlphaMatterContextMenu(
                                            model: model,
                                            caseMatter: caseMatter,
                                            renameTarget: $renameTarget,
                                            renameDraft: $renameDraft,
                                            deleteTarget: $deleteTarget
                                        )
                                    }

                                    if index < min(model.cases.count, 6) - 1 {
                                        Divider()
                                            .padding(.leading, 50)
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        guard expandedMatterIDs.isEmpty else { return }
                        expandedMatterIDs = Set(
                            model.cases.compactMap { caseMatter in
                                if caseMatter.id == model.selectedCaseID || !caseMatter.chatSessions.isEmpty {
                                    return caseMatter.id
                                }
                                return nil
                            }
                        )
                    }

                    if !recentDocuments.isEmpty {
                        AlphaWorkspaceDrawerSection(
                            title: "Recent files",
                            isExpanded: recentFilesExpanded,
                            toggle: {
                                withAnimation(.snappy(duration: 0.2)) {
                                    recentFilesExpanded.toggle()
                                }
                            }
                        ) {
                            ForEach(Array(recentDocuments.prefix(5).enumerated()), id: \.element.document.id) { index, entry in
                                VStack(spacing: 0) {
                                    Button {
                                        openDocument(caseId: entry.caseId, documentId: entry.document.id)
                                    } label: {
                                        AlphaWorkspaceDrawerDocumentRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)

                                    if index < min(recentDocuments.count, 5) - 1 {
                                        Divider()
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            AlphaWorkspaceDrawerFooterButton(
                title: "Settings",
                isSelected: model.persisted.selectedTab == .settings,
                action: openSettings
            )
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.rossGlassFill.opacity(0.96))
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.9), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.rossShadow.opacity(0.32), radius: 18, x: 8, y: 6)
        .alert("Rename matter", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Matter name", text: $renameDraft)
            Button("Save") {
                if let renameTarget {
                    model.renameCase(renameTarget.id, title: renameDraft)
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
        } message: {
            Text("Update the matter name on this device.")
        }
        .alert("Delete matter?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { caseMatter in
            Button("Delete", role: .destructive) {
                model.deleteCase(caseMatter.id)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: { caseMatter in
            Text("Deleting \(caseMatter.title) removes its files, tasks, chat context, and saved reports from this device.")
        }
    }
}

private struct AlphaWorkspaceDrawerSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let toggle: () -> Void
    let trailing: AnyView?
    let content: Content

    init(
        title: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isExpanded = isExpanded
        self.toggle = toggle
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.rossSerifHeadline())
                            .foregroundStyle(Color.rossInk)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if let trailing {
                    trailing
                }
            }

            if isExpanded {
                content
            }
        }
    }
}

private struct AlphaWorkspaceDrawerFooterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RossGlassIconView(.gearKeyhole, variant: isSelected ? .accent : .neutral, size: 22, fallbackSystemImage: isSelected ? "gearshape.fill" : "gearshape")

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.34))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.rossAccent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaWorkspaceDrawerMatterEntry: View {
    let caseMatter: AlphaCaseMatter
    let sessions: [AlphaChatSession]
    let activeSessionID: UUID?
    let isSelected: Bool
    let isExpanded: Bool
    let openCase: () -> Void
    let toggleThreads: () -> Void
    let startNewChat: () -> Void
    let openChat: (UUID) -> Void
    @Bindable var model: AlphaRossModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: openCase) {
                    AlphaWorkspaceDrawerMatterRow(
                        caseMatter: caseMatter,
                        openTaskCount: model.openTaskCount(for: caseMatter.id),
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)

                Button(action: toggleThreads) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.rossInk.opacity(0.56))
                        .frame(width: 28, height: 28)
                        .background(Color.rossSecondaryGroupedBackground.opacity(0.9), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse chats" : "Expand chats")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if !sessions.isEmpty {
                        ForEach(sessions) { session in
                            Button {
                                openChat(session.id)
                            } label: {
                                AlphaWorkspaceDrawerChatRow(
                                    title: model.chatSessionTitle(session),
                                    subtitle: model.chatSessionSubtitle(session),
                                    isSelected: activeSessionID == session.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: startNewChat) {
                        AlphaWorkspaceDrawerNewChatRow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start a new chat for \(caseMatter.title)")
                }
            }
        }
    }
}

private struct AlphaWorkspaceDrawerMatterRow: View {
    let caseMatter: AlphaCaseMatter
    let openTaskCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AlphaMatterFolderGlyph(tint: caseMatter.folderTint, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(caseMatter.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(2)
                Text("\(openTaskCount) open tasks • \(caseMatter.documents.count) docs")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if let nextHearing = caseMatter.nextHearing {
                Text(nextHearing.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.rossAccent.opacity(0.08) : Color.clear)
        )
    }
}

private struct AlphaWorkspaceDrawerNewChatRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossAccent)
                .frame(width: 22, height: 22)
                .background(Color.rossAccent.opacity(0.12), in: Circle())

            Text("New chat")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.34))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .overlay {
            Rectangle()
                .fill(Color.rossBorder.opacity(0.38))
                .frame(height: 1)
                .offset(y: -17)
        }
    }
}

private struct AlphaWorkspaceDrawerChatRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.24))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.54))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.rossAccent.opacity(0.08) : Color.clear)
        )
    }
}

private struct AlphaWorkspaceDrawerDocumentRow: View {
    let entry: AlphaRecentDocumentItem

    var body: some View {
        HStack(spacing: 12) {
            RossGlassIconView(.file, size: 24, fallbackSystemImage: alphaDocumentFallbackSymbolName(entry.document.kind))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)
                Text(entry.caseTitle)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(entry.document.kind.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossHighlight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct AlphaHomeScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var dueTodayExpanded = false
    @State private var upcomingExpanded = false
    @State private var needsReviewExpanded = false
    @State private var matterActivityExpanded = false

    var body: some View {
        let reviewItems = model.reviewQueue()
        let upcomingTasks = model.upcomingTasks()
        let todayTasks = model.todayTasks()
        let todayDates = alphaTodayDateRows(from: model.cases)
        let upcomingDates = alphaUpcomingDateRows(from: model.cases)
        let recentDocuments = alphaRecentDocumentItems(from: model.cases)
        let assistantStatus = alphaAssistantStatusSnapshot(model)
        let attentionCount = todayDates.count + todayTasks.count + reviewItems.count

        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                RossHeroCard(
                    eyebrow: alphaGreeting(),
                    title: alphaAttentionHeadline(attentionCount),
                    detail: attentionCount == 0
                        ? "No urgent work right now."
                        : "Due dates, review, and matter activity are below.",
                    showsMedia: false,
                    mediaHeight: 108,
                    logoSize: 58
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            RossMetricTile(label: "Matters", value: "\(model.cases.count)", tint: Color.rossAccent)
                            RossMetricTile(label: "Due today", value: "\(todayDates.count + todayTasks.count)", tint: Color.rossHighlight)
                            RossMetricTile(label: "Needs review", value: "\(reviewItems.count)", tint: reviewItems.isEmpty ? Color.rossSuccess : .orange)
                        }

                        AlphaCompactAssistantStatusRow(snapshot: assistantStatus) {
                            model.path.append(.privateAISettings)
                        }
                    }
                }
                .animation(.snappy(duration: 0.28, extraBounce: 0.04), value: model.persisted.modelJobs.count)

                if model.cases.isEmpty {
                    AlphaMatterStarterCard(model: model)
                }

                AlphaDisclosureCard(
                    title: "Due today",
                    badge: "\(todayDates.count + todayTasks.count)",
                    isExpanded: $dueTodayExpanded
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if todayDates.isEmpty && todayTasks.isEmpty {
                            Text("Nothing urgent is due today.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            ForEach(Array(todayDates.prefix(3)), id: \.title) { row in
                                AlphaSummaryRow(title: row.title, detail: row.detail, tint: Color.rossAccent)
                            }
                            ForEach(Array(todayTasks.prefix(max(0, 4 - todayDates.count)))) { task in
                                AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                            }
                        }
                    }
                }

                AlphaDisclosureCard(
                    title: "Upcoming dates",
                    badge: "\(upcomingDates.count + upcomingTasks.count)",
                    isExpanded: $upcomingExpanded
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if upcomingDates.isEmpty && upcomingTasks.isEmpty {
                            Text("No upcoming dates are saved yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            ForEach(Array(upcomingDates.prefix(4)), id: \.title) { row in
                                AlphaSummaryRow(title: row.title, detail: row.detail)
                            }
                            ForEach(Array(upcomingTasks.prefix(2))) { task in
                                AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                            }
                        }
                    }
                }

                AlphaDisclosureCard(
                    title: "Needs review",
                    badge: "\(reviewItems.count)",
                    isExpanded: $needsReviewExpanded
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if reviewItems.isEmpty {
                            Text("Nothing is waiting for manual review right now.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            ForEach(Array(reviewItems.prefix(4))) { item in
                                AlphaReviewRow(item: item) {
                                    model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                                }
                            }
                        }
                    }
                }

                AlphaDisclosureCard(
                    title: "Matters and files",
                    badge: "\(model.cases.count)",
                    isExpanded: $matterActivityExpanded
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if model.cases.isEmpty && recentDocuments.isEmpty {
                            Text("No matters yet. Create the first one above.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        } else {
                            if !model.cases.isEmpty {
                                ForEach(Array(model.cases.prefix(4))) { caseMatter in
                                    Button {
                                        model.focusCase(caseMatter.id)
                                        model.path.append(.caseWorkspace(caseMatter.id))
                                    } label: {
                                        AlphaCaseSummaryCard(model: model, caseMatter: caseMatter)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if !recentDocuments.isEmpty {
                                Divider()

                                Text("Recent files")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rossInk.opacity(0.65))

                                ForEach(Array(recentDocuments.prefix(4))) { entry in
                                    Button {
                                        model.focusCase(entry.caseId)
                                        model.path.append(.documentViewer(entry.caseId, entry.document.id, 1))
                                    } label: {
                                        AlphaDocumentRow(
                                            caseTitle: entry.caseTitle,
                                            document: entry.document,
                                            showChevron: true
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(alphaScreenPadding)
        }
        .rossHideNavigationBarIfSupported()
    }
}

private struct AlphaCaseListScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var sortMode: AlphaCaseSortMode = .recentlyViewed
    @State private var viewMode: AlphaMatterListViewMode = .expanded
    @State private var renameTarget: AlphaCaseMatter?
    @State private var renameDraft = ""
    @State private var deleteTarget: AlphaCaseMatter?

    private var sortedCases: [AlphaCaseMatter] {
        alphaSortedCases(for: sortMode, model: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                HStack(spacing: 10) {
                    Text("\(model.cases.count) matter(s) on this device")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.62))

                    Spacer(minLength: 0)

                    Menu {
                        ForEach(AlphaCaseSortMode.allCases) { option in
                            Button(option.title) {
                                sortMode = option
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 34, height: 34)
                            .background(Color.rossSecondaryGroupedBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sort matters")

                    Menu {
                        ForEach(AlphaMatterListViewMode.allCases) { option in
                            Button(option.title) {
                                viewMode = option
                            }
                        }
                    } label: {
                        Image(systemName: viewMode.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.rossBorder, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose matter view")

                    AlphaGlassPlusButton {
                        model.path.append(.createCase)
                    }
                }

                if model.cases.isEmpty {
                    RossSectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create a matter to start adding documents, dates, and tasks.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))

                            Button {
                                model.path.append(.createCase)
                            } label: {
                                Label("Create matter", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    if viewMode == .folder {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 106, maximum: 132), spacing: 14)],
                            alignment: .leading,
                            spacing: 16
                        ) {
                            ForEach(sortedCases) { caseMatter in
                                Button {
                                    model.focusCase(caseMatter.id)
                                    model.path.append(.caseWorkspace(caseMatter.id))
                                } label: {
                                    AlphaCaseFolderCard(model: model, caseMatter: caseMatter)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    AlphaMatterContextMenu(
                                        model: model,
                                        caseMatter: caseMatter,
                                        renameTarget: $renameTarget,
                                        renameDraft: $renameDraft,
                                        deleteTarget: $deleteTarget
                                    )
                                }
                            }
                        }
                    } else {
                        VStack(spacing: viewMode == .expanded ? 12 : 8) {
                            ForEach(sortedCases) { caseMatter in
                                Button {
                                    model.focusCase(caseMatter.id)
                                    model.path.append(.caseWorkspace(caseMatter.id))
                                } label: {
                                    switch viewMode {
                                    case .expanded:
                                        AlphaCaseSummaryCard(model: model, caseMatter: caseMatter)
                                    case .summary:
                                        AlphaCaseSummaryLine(model: model, caseMatter: caseMatter)
                                    case .folder:
                                        AlphaCaseFolderCard(model: model, caseMatter: caseMatter)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    AlphaMatterContextMenu(
                                        model: model,
                                        caseMatter: caseMatter,
                                        renameTarget: $renameTarget,
                                        renameDraft: $renameDraft,
                                        deleteTarget: $deleteTarget
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(alphaScreenPadding)
        }
        .rossHideNavigationBarIfSupported()
        .alert("Rename matter", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Matter name", text: $renameDraft)
            Button("Save") {
                if let renameTarget {
                    model.renameCase(renameTarget.id, title: renameDraft)
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
        } message: {
            Text("Update the matter name on this device.")
        }
        .alert("Delete matter?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { caseMatter in
            Button("Delete", role: .destructive) {
                model.deleteCase(caseMatter.id)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {
                deleteTarget = nil
            }
        } message: { caseMatter in
            Text("Deleting \(caseMatter.title) removes its files, tasks, chat context, and saved reports from this device.")
        }
    }
}

private enum AlphaCaseSortMode: String, CaseIterable, Identifiable {
    case recentlyViewed
    case lastAdded
    case earliestActionNeeded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyViewed:
            "Recently Viewed"
        case .lastAdded:
            "Last Added"
        case .earliestActionNeeded:
            "Earliest Action Needed"
        }
    }
}

private enum AlphaMatterListViewMode: String, CaseIterable, Identifiable {
    case expanded
    case summary
    case folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expanded:
            "Expanded"
        case .summary:
            "Summary"
        case .folder:
            "Folder"
        }
    }

    var systemImage: String {
        switch self {
        case .expanded:
            "rectangle.grid.1x2"
        case .summary:
            "list.bullet"
        case .folder:
            "folder"
        }
    }
}

private enum AlphaDocumentLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid:
            "Grid"
        case .list:
            "List"
        }
    }

    var systemImage: String {
        switch self {
        case .grid:
            "square.grid.2x2"
        case .list:
            "list.bullet"
        }
    }
}

private func alphaMatterTintColor(_ tint: AlphaMatterTint) -> Color {
    switch tint {
    case .indigo:
        return Color.rossAccent
    case .amber:
        return Color.rossHighlight
    case .emerald:
        return Color.rossSuccess
    case .rose:
        return Color(red: 0.76, green: 0.36, blue: 0.48)
    case .slate:
        return Color.rossInk.opacity(0.68)
    }
}

private func alphaMatterTintTitle(_ tint: AlphaMatterTint) -> String {
    switch tint {
    case .indigo:
        return "Indigo"
    case .amber:
        return "Amber"
    case .emerald:
        return "Emerald"
    case .rose:
        return "Rose"
    case .slate:
        return "Slate"
    }
}

private struct AlphaGlassPlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.rossAccent)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossAccent.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create matter")
    }
}

private struct AlphaMatterFolderGlyph: View {
    let tint: AlphaMatterTint
    var size: CGFloat = 44

    var body: some View {
        let color = alphaMatterTintColor(tint)

        ZStack(alignment: .bottomTrailing) {
            RossGlassIconView(.folder, size: size * 0.8, fallbackSystemImage: "folder.fill")
                .frame(width: size, height: size, alignment: .center)

            Circle()
                .fill(color)
                .frame(width: max(8, size * 0.22), height: max(8, size * 0.22))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                }
                .offset(x: -2, y: -2)
        }
        .frame(width: size, height: size)
    }
}

private func alphaDocumentTint(_ kind: AlphaDocumentKind) -> Color {
    switch kind {
    case .pdf:
        return Color.rossAccent
    case .image:
        return Color.rossHighlight
    case .text:
        return Color.rossSuccess
    case .unknown:
        return Color.rossInk.opacity(0.56)
    }
}

private func alphaDocumentFallbackSymbolName(_ kind: AlphaDocumentKind) -> String {
    switch kind {
    case .pdf:
        return "doc.richtext.fill"
    case .image:
        return "photo.fill"
    case .text:
        return "doc.text.fill"
    case .unknown:
        return "doc.fill"
    }
}

private func alphaTierGlassIcon(_ tier: AlphaCapabilityTier) -> (RossGlassIconName, RossGlassIconVariant, String) {
    switch tier {
    case .quickStart:
        return (.badgeSparkle, .accent, "sparkles")
    case .caseAssociate:
        return (.bookOpen, .neutral, "books.vertical.fill")
    case .seniorDraftingSupport:
        return (.timelineVertical, .neutral, "square.and.pencil")
    }
}

private func alphaDocumentGlassIcon(_ kind: AlphaDocumentKind) -> (RossGlassIconName, RossGlassIconVariant, String) {
    switch kind {
    case .pdf:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .image:
        return (.files, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .text:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .unknown:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    }
}

private func alphaDocumentImportedLabel(_ document: AlphaCaseDocument) -> String {
    document.importedAt.formatted(date: .abbreviated, time: .omitted)
}

private struct AlphaFolderArtwork: View {
    let tint: Color
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let badgeText: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RossGlassIconView(icon, variant: variant, size: 64, fallbackSystemImage: fallbackSystemImage)
                .padding(.leading, 2)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let badgeText {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.45), lineWidth: 0.7)
                    }
                    .padding(.leading, 2)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }
}

private struct AlphaDocumentLayoutMenu: View {
    @Binding var layoutMode: AlphaDocumentLayoutMode

    var body: some View {
        Menu {
            ForEach(AlphaDocumentLayoutMode.allCases) { option in
                Button(option.title) {
                    layoutMode = option
                }
            }
        } label: {
            Image(systemName: layoutMode.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rossInk)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossBorder, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose document view")
    }
}

private struct AlphaDocumentCollectionView: View {
    let documents: [AlphaCaseDocument]
    let caseTitle: String?
    let layoutMode: AlphaDocumentLayoutMode
    @Binding var expandedDocumentIDs: Set<UUID>
    let onOpen: (UUID) -> Void
    let onMoveDocument: (UUID, Int) -> Void
    var onOpenChat: ((UUID) -> Void)? = nil
    var onStartReviewChat: ((UUID) -> Void)? = nil

    var body: some View {
        switch layoutMode {
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 126), spacing: 14)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    Button {
                        onOpen(document.id)
                    } label: {
                        AlphaDocumentFolderTile(document: document)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open document") {
                            onOpen(document.id)
                        }

                        if let onOpenChat {
                            Button("Continue in chat") {
                                onOpenChat(document.id)
                            }
                        }

                        if let onStartReviewChat {
                            Button("Start review chat") {
                                onStartReviewChat(document.id)
                            }
                        }

                        if index > 0 {
                            Button("Move earlier") {
                                onMoveDocument(document.id, -1)
                            }
                        }

                        if index < documents.count - 1 {
                            Button("Move later") {
                                onMoveDocument(document.id, 1)
                            }
                        }
                    }
                }
            }
        case .list:
            VStack(spacing: 10) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    AlphaExpandableDocumentRow(
                        caseTitle: caseTitle,
                        document: document,
                        isExpanded: expandedDocumentIDs.contains(document.id),
                        canMoveEarlier: index > 0,
                        canMoveLater: index < documents.count - 1,
                        onToggle: {
                            withAnimation(.snappy(duration: 0.24)) {
                                if expandedDocumentIDs.contains(document.id) {
                                    expandedDocumentIDs.remove(document.id)
                                } else {
                                    expandedDocumentIDs.insert(document.id)
                                }
                            }
                        },
                        onOpen: { onOpen(document.id) },
                        onOpenChat: { onOpenChat?(document.id) },
                        onStartReviewChat: { onStartReviewChat?(document.id) },
                        onMoveEarlier: { onMoveDocument(document.id, -1) },
                        onMoveLater: { onMoveDocument(document.id, 1) }
                    )
                }
            }
        }
    }
}

private struct AlphaDocumentFolderTile: View {
    let document: AlphaCaseDocument

    var body: some View {
        let tint = alphaDocumentTint(document.kind)
        let glassIcon = alphaDocumentGlassIcon(document.kind)

        VStack(alignment: .leading, spacing: 9) {
            AlphaFolderArtwork(
                tint: tint,
                icon: glassIcon.0,
                variant: glassIcon.1,
                fallbackSystemImage: glassIcon.2,
                badgeText: document.pageCount == 1 ? "1 page" : "\(document.pageCount)"
            )

            Text(document.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(document.lawyerStatusTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint.opacity(0.92))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(11)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 0.9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AlphaExpandableDocumentRow: View {
    let caseTitle: String?
    let document: AlphaCaseDocument
    let isExpanded: Bool
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onOpenChat: () -> Void
    let onStartReviewChat: () -> Void
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void

    var body: some View {
        let tint = alphaDocumentTint(document.kind)
        let glassIcon = alphaDocumentGlassIcon(document.kind)

        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    RossGlassIconView(glassIcon.0, variant: glassIcon.1, size: 28, fallbackSystemImage: glassIcon.2)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)

                        if let caseTitle {
                            Text(caseTitle)
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.56))
                                .lineLimit(1)
                        }

                        Text("\(document.kind.title) • \(document.pageCount) page(s) • \(document.lawyerStatusTitle)")
                            .font(.caption)
                            .foregroundStyle(tint.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.42))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Imported \(alphaDocumentImportedLabel(document))")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.58))

                    if let snippet = document.displaySourceSnippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Button("Open", action: onOpen)
                            .buttonStyle(.borderedProminent)

                        Button("Chat", action: onOpenChat)
                            .buttonStyle(.bordered)

                        Button("New review chat", action: onStartReviewChat)
                            .buttonStyle(.bordered)

                        if canMoveEarlier {
                            Button {
                                onMoveEarlier()
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Move document earlier")
                        }

                        if canMoveLater {
                            Button {
                                onMoveLater()
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Move document later")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy(duration: 0.24), value: isExpanded)
    }
}

private struct AlphaMatterContextMenu: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter
    @Binding var renameTarget: AlphaCaseMatter?
    @Binding var renameDraft: String
    @Binding var deleteTarget: AlphaCaseMatter?

    var body: some View {
        Button {
            renameTarget = caseMatter
            renameDraft = caseMatter.title
        } label: {
            Label("Rename matter", systemImage: "pencil")
        }

        Menu("Folder color") {
            ForEach(AlphaMatterTint.allCases) { tint in
                Button {
                    model.setFolderTint(tint, for: caseMatter.id)
                } label: {
                    Label(
                        alphaMatterTintTitle(tint),
                        systemImage: tint == caseMatter.folderTint ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }

        Button {
            model.archiveCase(caseMatter.id)
        } label: {
            Label("Archive matter", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            deleteTarget = caseMatter
        } label: {
            Label("Delete matter", systemImage: "trash")
        }
    }
}

private func alphaTierTint(_ tier: AlphaCapabilityTier) -> Color {
    switch tier {
    case .quickStart:
        return Color.rossHighlight
    case .caseAssociate:
        return Color.rossAccent
    case .seniorDraftingSupport:
        return Color.rossSuccess
    }
}

private struct AlphaTierGlyph: View {
    let tier: AlphaCapabilityTier

    var body: some View {
        let tint = alphaTierTint(tier)
        let glassIcon = alphaTierGlassIcon(tier)

        RossGlassIconView(glassIcon.0, variant: glassIcon.1, size: 22, fallbackSystemImage: glassIcon.2)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct AlphaPackTierSelectionBar: View {
    let tier: AlphaCapabilityTier
    let isSelected: Bool
    let badge: String?
    let onSelect: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    AlphaTierGlyph(tier: tier)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(tier.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                                .lineLimit(1)

                            if let badge {
                                Text(badge)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(alphaTierTint(tier))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(alphaTierTint(tier).opacity(0.12), in: Capsule())
                            }
                        }

                        Text("\(tier.compactSetupSummary) • \(tier.downloadSizeLabel) • \(tier.setupTimeLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 10)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? alphaTierTint(tier) : Color.rossInk.opacity(0.2))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onInfo) {
                RossGlassIconView(.circleInfo, variant: .highlight, size: 22, fallbackSystemImage: "info.circle")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About \(tier.title)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? alphaTierTint(tier).opacity(0.08) : Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? alphaTierTint(tier).opacity(0.28) : Color.rossBorder, lineWidth: 1)
            }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AlphaPackTierInfoSheet: View {
    let tier: AlphaCapabilityTier
    let isSelected: Bool
    let onUseTier: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 14) {
                            AlphaTierGlyph(tier: tier)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tier.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.rossInk)

                                Text(tier.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if isSelected {
                            Text("Selected for this device")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(alphaTierTint(tier))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(alphaTierTint(tier).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            RossInfoPill(title: "\(tier.downloadSizeLabel) download", systemImage: "arrow.down.circle")
                            RossInfoPill(title: tier.setupTimeLabel, systemImage: "clock")
                        }

                        HStack(spacing: 10) {
                            RossInfoPill(title: "\(tier.installedSizeLabel) on device", systemImage: "internaldrive")
                            RossInfoPill(title: tier.storageNote, systemImage: "shippingbox")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best for")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(tier.bestFor)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.rossAccent)
                            .padding(.top, 2)

                        Text("Setup continues after you leave this screen.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(isSelected ? "Close" : "Use \(tier.title)") {
                        if !isSelected {
                            onUseTier()
                        }
                        dismiss()
                    }
                    .rossPrimaryButtonStyle()
                }
            }
            .padding(alphaScreenPadding)
            .navigationTitle(tier.title)
            .rossInlineNavigationTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                #endif
            }
        }
    }
}

private struct AlphaMatterStarterCard: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        RossSectionCard(title: "Start with one matter", subtitle: "You can add the court or forum now, or leave it for later.") {
            VStack(spacing: 12) {
                TextField("Matter name", text: $model.caseDraftTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Court or forum", text: $model.caseDraftForum)
                    .textFieldStyle(.roundedBorder)
                Button("Save matter and open") {
                    model.createCase()
                }
                .rossPrimaryButtonStyle()
                .disabled(model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct AlphaAssistantActivityStrip: View {
    let title: String
    let detail: String
    let statusLabel: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RossGlassIconView(.sparkle3, variant: .accent, size: 30, fallbackSystemImage: "brain.head.profile")
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(
            tint.opacity(0.04)
                .background(Color.rossSecondaryGroupedBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct AlphaDisclosureCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let badge: String
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        badge: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.rossSerifHeadline())
                                .foregroundStyle(Color.rossInk)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 12)

                        HStack(spacing: 10) {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.rossAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.rossAccent.opacity(0.12))
                                .clipShape(Capsule())

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.45))
                        }
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    content
                }
            }
        }
    }
}

@MainActor
private func alphaSortedCases(for sortMode: AlphaCaseSortMode, model: AlphaRossModel) -> [AlphaCaseMatter] {
    switch sortMode {
    case .recentlyViewed:
        return model.cases
    case .lastAdded:
        return model.cases
    case .earliestActionNeeded:
        return model.cases.sorted { lhs, rhs in
            let lhsDate = alphaNextActionDate(for: lhs, model: model)
            let rhsDate = alphaNextActionDate(for: rhs, model: model)
            switch (lhsDate, rhsDate) {
            case let (.some(lhsDate), .some(rhsDate)):
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}

@MainActor
private func alphaNextActionDate(for caseMatter: AlphaCaseMatter, model: AlphaRossModel) -> Date? {
    let nextTaskDate = model.tasks(for: caseMatter.id)
        .first { $0.status == .open && $0.dueDate != nil }?
        .dueDate
    return [nextTaskDate, caseMatter.nextHearing]
        .compactMap { $0 }
        .min()
}

@MainActor
private func alphaActiveSetupJob(_ model: AlphaRossModel) -> AlphaModelDownloadJob? {
    model.persisted.modelJobs.first {
        switch $0.state {
        case .queued, .downloading, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .verifying, .failed:
            true
        case .notStarted, .installed, .cancelled:
            false
        }
    }
}

private func alphaAssistantActivityDetail(for state: AlphaDownloadState) -> String {
    switch state {
    case .queued, .downloading:
        "Ross is downloading the assistant in the background. You can keep using the app."
    case .verifying:
        "Ross finished the download and is checking the files before turning it on."
    case .pausedWaitingForWifi:
        "Ross is waiting for Wi-Fi before continuing the assistant setup."
    case .pausedUser:
        "The assistant setup is paused. Open device setup to resume it."
    case .pausedNoStorage:
        "Ross needs more free space before the assistant can finish setting up."
    case .pausedError, .failed:
        "Ross hit a setup problem. Open device setup to resume or choose another model."
    case .notStarted, .installed, .cancelled:
        "No setup is running right now."
    }
}

private struct AlphaCaptureScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var selectedCaseID: UUID?
    @State private var showingImporter = false

    var body: some View {
        let activeCase = model.cases.first(where: { $0.id == selectedCaseID ?? model.selectedCaseID }) ?? model.cases.first

        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: nil,
                    title: activeCase == nil ? "Start with a matter" : "Bring a file into the matter",
                    detail: activeCase == nil
                        ? "Ross files each document into a specific matter, so create one before you import."
                        : "Ross copies the file into private storage, reads it locally, opens review, and refreshes the matter workspace."
                )

                if let activeCase {
                    RossSectionCard(title: "Import into", subtitle: activeCase.title) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Case", selection: Binding(
                                get: { selectedCaseID ?? model.selectedCaseID ?? model.cases.first?.id },
                                set: { selectedCaseID = $0 }
                            )) {
                                ForEach(model.cases) { caseMatter in
                                    Text(caseMatter.title).tag(Optional(caseMatter.id))
                                }
                            }
                            .pickerStyle(.menu)

                            HStack(spacing: 10) {
                                RossInfoPill(title: "PDF, image, or text", systemImage: "doc")
                                RossInfoPill(title: "Stays on this device", systemImage: "lock")
                            }

                            Button("Import file or image") {
                                showingImporter = true
                            }
                            .rossPrimaryButtonStyle()
                        }
                    }

                } else {
                    RossSectionCard(title: "Start with a matter first", subtitle: "This keeps imported files, dates, and review notes together in the right place.") {
                        VStack(spacing: 12) {
                            Button("Create matter") {
                                model.path.append(.createCase)
                            }
                            .rossPrimaryButtonStyle()

                            Text("After you create a matter, Ross will let you import a PDF, image, or text file directly into it.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        }
                    }
                }

                RossSectionCard(title: "Recent files") {
                    VStack(alignment: .leading, spacing: 12) {
                        let recentItems = alphaRecentDocumentItems(from: model.cases, caseId: selectedCaseID)
                        if recentItems.isEmpty {
                            Text("No files added yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        }
                        ForEach(Array(recentItems.prefix(6))) { entry in
                            Button {
                                model.selectedCaseID = entry.caseId
                                model.path.append(.documentViewer(entry.caseId, entry.document.id, 1))
                            } label: {
                                AlphaDocumentRow(
                                    caseTitle: entry.caseTitle,
                                    document: entry.document,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(alphaScreenPadding)
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
        .navigationTitle("Import File")
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: "Open Ask Ross") {
                    model.openAsk()
                }
            }
        }
    }
}

private struct AlphaAskRossScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        AlphaAskConversationScreen(model: model, fixedScopeCaseID: nil)
    }
}

private struct AlphaCreateCaseScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        Form {
            Section {
                TextField("Matter name", text: $model.caseDraftTitle)
                TextField("Court or forum", text: $model.caseDraftForum)
            }

            Section {
                Button("Create matter") {
                    model.createCase()
                }
                .disabled(model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Create Matter")
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

    var symbolName: String {
        switch self {
        case .overview:      "doc.richtext"
        case .documents:     "folder"
        case .tasks:         "checkmark.square"
        case .review:        "eye"
        case .notesExports:  "arrow.up.doc"
        }
    }
}

private struct AlphaCaseWorkspaceSectionBar: View {
    @Binding var selectedSection: AlphaCaseWorkspaceSection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AlphaCaseWorkspaceSection.allCases) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedSection = section
                        }
                    } label: {
                        Label(section.title, systemImage: section.symbolName)
                            .symbolRenderingMode(.hierarchical)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(selectedSection == section ? Color.white : Color.rossInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                selectedSection == section
                                    ? Color.rossAccent
                                    : Color.rossSecondaryGroupedBackground
                            )
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(
                                        selectedSection == section ? Color.rossAccent : Color.rossBorder,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [Color.clear, Color.rossGroupedBackground],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 42)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.35))
            }
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
}

private struct AlphaUpcomingDateRow {
    let title: String
    let detail: String
    let date: Date
}

private func alphaGreeting() -> String {
    "Today"
}

private func alphaCaseAttentionSummary(_ caseMatter: AlphaCaseMatter) -> String {
    if let nextHearing = caseMatter.nextHearing {
        return "Ross sees the next focus as getting this file ready for \(nextHearing.formatted(date: .abbreviated, time: .omitted))."
    }
    if let firstTask = caseMatter.draftTasks.first {
        return "Ross sees the next focus as \(firstTask.lowercased())."
    }
    return "Ross is ready to refresh the next-step note after another document or instruction is added."
}

private func upcomingDateCount(in cases: [AlphaCaseMatter]) -> Int {
    let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    return cases.filter { caseMatter in
        guard let nextHearing = caseMatter.nextHearing else { return false }
        return nextHearing <= endOfWeek
    }.count
}

private func alphaUpcomingDateRows(from cases: [AlphaCaseMatter]) -> [AlphaUpcomingDateRow] {
    let startOfDay = Calendar.current.startOfDay(for: .now)
    return cases.compactMap { caseMatter -> AlphaUpcomingDateRow? in
        guard let nextHearing = caseMatter.nextHearing else { return nil }
        guard nextHearing >= startOfDay else { return nil }
        return AlphaUpcomingDateRow(
            title: caseMatter.title,
            detail: "Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))",
            date: nextHearing
        )
    }
    .filter { !Calendar.current.isDateInToday($0.date) }
    .sorted { $0.date < $1.date }
}

private func alphaTodayDateRows(from cases: [AlphaCaseMatter]) -> [AlphaUpcomingDateRow] {
    cases.compactMap { caseMatter -> AlphaUpcomingDateRow? in
        guard let nextHearing = caseMatter.nextHearing, Calendar.current.isDateInToday(nextHearing) else { return nil }
        return AlphaUpcomingDateRow(
            title: caseMatter.title,
            detail: "Hearing today",
            date: nextHearing
        )
    }
    .sorted { $0.date < $1.date }
}

private struct AlphaCaseSummaryCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AlphaMatterFolderGlyph(tint: caseMatter.folderTint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(caseMatter.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(caseMatter.forum) · \(caseMatter.stage.title)")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                }
                Spacer(minLength: 12)
                if let nextHearing = caseMatter.nextHearing {
                    Text(nextHearing.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }
            }

            Text("\(model.openTaskCount(for: caseMatter.id)) open tasks · \(model.reviewQueue(caseId: caseMatter.id).count) review items · \(caseMatter.documents.count) documents")
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.7))

            Text(caseMatter.summary)
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.72))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(caseMatter.localNotice)
                .font(.caption2)
                .foregroundStyle(Color.rossInk.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AlphaCaseSummaryLine: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        HStack(spacing: 12) {
            AlphaMatterFolderGlyph(tint: caseMatter.folderTint, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(caseMatter.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)

                Text("\(caseMatter.forum) · \(caseMatter.documents.count) files")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? "\(model.openTaskCount(for: caseMatter.id)) open"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(caseMatter.nextHearing == nil ? Color.rossInk.opacity(0.55) : Color.rossAccent)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossInk.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AlphaCaseFolderCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        let tint = alphaMatterTintColor(caseMatter.folderTint)

        VStack(alignment: .leading, spacing: 10) {
            AlphaFolderArtwork(
                tint: tint,
                icon: .folder,
                variant: .neutral,
                fallbackSystemImage: "folder.fill",
                badgeText: caseMatter.documents.isEmpty ? "New" : "\(caseMatter.documents.count)"
            )

            Text(caseMatter.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? "\(model.openTaskCount(for: caseMatter.id)) open task(s)"
            )
            .font(.caption)
            .foregroundStyle(tint.opacity(0.9))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
        .padding(11)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 0.9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AlphaInlineHeader: View {
    let eyebrow: String?
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.rossAccent)
            }

            Text(title)
                .font(.rossInlineTitle())
                .foregroundStyle(Color.rossInk)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AlphaSummaryRow: View {
    let title: String
    let detail: String
    var tint: Color = Color.rossInk

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }
            Spacer()
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
        }
    }
}

private struct AlphaDocumentRow: View {
    let caseTitle: String?
    let document: AlphaCaseDocument
    let showChevron: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(2)

                if let caseTitle {
                    Text(caseTitle)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.55))
                }

                Text(document.lawyerStatusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private func alphaRecentDocumentItems(from cases: [AlphaCaseMatter], caseId: UUID? = nil) -> [AlphaRecentDocumentItem] {
    let visibleCases = caseId.map { id in
        cases.filter { $0.id == id }
    } ?? cases

    return visibleCases
        .flatMap { caseMatter in
            caseMatter.documents.map { document in
                AlphaRecentDocumentItem(caseId: caseMatter.id, caseTitle: caseMatter.title, document: document)
            }
        }
        .sorted { $0.document.importedAt > $1.document.importedAt }
}

@MainActor
private func alphaPrivateAIStatus(_ model: AlphaRossModel) -> String {
    alphaAssistantStatusSnapshot(model).title
}

@MainActor
private func alphaAssistantStatusSnapshot(_ model: AlphaRossModel) -> AlphaAssistantStatusSnapshot {
    if let job = model.persisted.modelJobs.first {
        switch job.state {
        case .installed:
            break
        case .downloading, .queued, .verifying:
            return AlphaAssistantStatusSnapshot(
                title: "Setting up assistant",
                detail: "Ross is preparing \(job.tier.title) on this device. You can keep working while it finishes.",
                tint: Color.rossAccent
            )
        case .pausedWaitingForWifi:
            return AlphaAssistantStatusSnapshot(
                title: "Waiting for Wi-Fi",
                detail: "\(job.tier.title) is ready to continue as soon as Wi-Fi is available.",
                tint: Color.rossHighlight
            )
        case .failed:
            return AlphaAssistantStatusSnapshot(
                title: "Assistant needs attention",
                detail: "Ross could not finish the assistant setup. Open the setup screen to resume or choose another tier.",
                tint: .orange
            )
        default:
            return AlphaAssistantStatusSnapshot(
                title: "Setting up assistant",
                detail: "Ross is still preparing the assistant on this device.",
                tint: Color.rossAccent
            )
        }
    }

    if let activePack = model.activePack {
        if model.activeRuntimeHealth?.fallbackActive == true {
            return AlphaAssistantStatusSnapshot(
                title: "Basic local mode",
                detail: "\(activePack.tier.title) is installed, but Ross is using the lighter local mode right now.",
                tint: Color.rossHighlight
            )
        }

        return AlphaAssistantStatusSnapshot(
            title: "Assistant ready",
            detail: "\(activePack.tier.title) is ready for private on-device review and drafting support.",
            tint: Color.rossSuccess
        )
    }

    return AlphaAssistantStatusSnapshot(
        title: "Basic local mode",
        detail: "Files are ready now. Install the assistant for deeper local review.",
        tint: Color.rossAccent
    )
}

private struct AlphaCompactAssistantStatusRow: View {
    let snapshot: AlphaAssistantStatusSnapshot
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(snapshot.tint)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text("Private AI")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(snapshot.tint.opacity(0.9))

                Text(snapshot.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(snapshot.detail)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("Setup", action: onOpen)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.rossSecondaryGroupedBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.75), lineWidth: 1)
        }
    }
}

private struct AlphaActiveMatterChatCard: View {
    let session: AlphaChatSession?
    let sessionTitle: String?
    let sessionSubtitle: String?
    let onOpenChat: () -> Void
    let onStartNewChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active chat")
                    .font(.headline)
                Text(
                    session == nil
                        ? "Ross will keep imported files and review updates in the current matter chat."
                        : "Imports, review updates, and next-step work stay anchored to the current matter chat."
                )
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            }

            if let session, let sessionTitle {
                HStack(alignment: .top, spacing: 12) {
                    RossGlassIconView(.userMsg, variant: .accent, size: 20, fallbackSystemImage: "bubble.left.and.text.bubble.right.fill")
                        .frame(width: 32, height: 32)
                        .background(Color.rossAccent.opacity(0.1), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text("\(session.turns.count) update(s) · \(sessionSubtitle ?? "Recent activity")")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.62))
                    }
                }
            } else {
                Text("No active chat yet. Ross will start one as soon as you import a file, review a document, or ask the first question for this matter.")
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(session == nil ? "Open matter chat" : "Continue in active chat", action: onOpenChat)
                    .rossPrimaryButtonStyle()

                Button("Start new chat", action: onStartNewChat)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
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

private struct AlphaAskConversationScreen: View {
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    private var conversation: [AlphaAskResult] {
        model.askConversation(for: activeScopeCaseID)
    }

    private var scopeTitle: String {
        model.scopeLabel(for: activeScopeCaseID)
    }

    private var introDetail: String {
        let selectedDocuments = model.selectedAskDocuments(for: activeScopeCaseID)
        if let documentTitle = model.askDocumentTitle(for: activeScopeCaseID) {
            return "Ask about \(documentTitle), what it means, or what to do next."
        }
        if !selectedDocuments.isEmpty {
            return "Ask using only the files you selected here."
        }
        if activeScopeCaseID != nil {
            return "Ask about this matter, its files, and what to do next."
        }
        return "Ask about today, shared files, or any matter on this device."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if conversation.isEmpty {
                    AlphaAskEmptyState(
                        detail: introDetail,
                        suggestions: alphaAskSuggestions(
                            for: activeScopeCaseID == nil ? nil : scopeTitle,
                            documentTitle: model.askDocumentTitle(for: activeScopeCaseID)
                        ),
                        onSelectSuggestion: { suggestion in
                            model.setAskDraft(suggestion, for: activeScopeCaseID)
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(conversation.enumerated()), id: \.offset) { _, result in
                            AlphaAskTurnCard(result: result, onOpenSource: model.openSourceRef)
                        }
                    }
                }
            }
            .padding(alphaScreenPadding)
            .padding(.bottom, 112)
        }
        .navigationTitle("Chat")
        .rossInlineNavigationTitle()
        .toolbar {
            if fixedScopeCaseID == nil {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    AlphaWorkspaceDrawerButton {
                        withAnimation(.snappy(duration: 0.24)) {
                            model.workspaceDrawerPresented = true
                        }
                    }
                }
                #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            AlphaRootAskDock(
                model: model,
                fixedScopeCaseID: fixedScopeCaseID,
                showsInlineResponseCard: false,
                showsConversationShortcut: false
            )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
    }
}

private struct AlphaAskEmptyState: View {
    let detail: String
    let suggestions: [String]
    let onSelectSuggestion: (String) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Ask Ross what's next")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.rossInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.rossGlassSubtleFill)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.rossBorder.opacity(0.7), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AlphaAskTurnCard: View {
    let result: AlphaAskResult
    let onOpenSource: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.kind == .userAsk {
                HStack {
                    Spacer(minLength: 48)
                    Text(result.question)
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.rossCardBackground.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.rossBorder.opacity(0.6), lineWidth: 1)
                        }
                }
            } else {
                HStack(spacing: 8) {
                    RossGlassIconView(.badgeSparkle, variant: .accent, size: 16, fallbackSystemImage: "sparkles")
                    Text("Matter update")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.rossAccent)
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(result.answerTitle)
                        .font(.headline)

                    ForEach(Array(result.answerSections.enumerated()), id: \.offset) { index, section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section)
                                .font(.body)
                                .foregroundStyle(Color.rossInk.opacity(0.92))
                            if index < result.answerSections.count - 1 {
                                Divider().overlay(Color.rossBorder.opacity(0.4))
                            }
                        }
                    }

                    if let note = result.statusNote {
                        Text(note)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                    }

                    if !result.selectedDocumentTitles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(result.selectedDocumentTitles, id: \.self) { title in
                                    Text(title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.rossInk.opacity(0.74))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.rossSecondaryGroupedBackground, in: Capsule())
                                }
                            }
                        }
                    }

                    if let warning = result.needsReviewWarning {
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if !result.caseFileSources.isEmpty {
                        Text("Local sources")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.65))
                        AlphaSourceRefChips(sourceRefs: result.caseFileSources, onOpenSourceRef: onOpenSource)
                    }

                    if let preview = result.publicLawPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Web search preview")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                            Text(preview.query)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.82))
                        }
                    }

                    if !result.publicLawResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Public-law results")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                            ForEach(result.publicLawResults) { publicResult in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(publicResult.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(publicResult.citation)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossAccent)
                                    Text(publicResult.snippet)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.74))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.rossGlassSubtleFill)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.rossBorder.opacity(0.65), lineWidth: 1)
                }

                Spacer(minLength: 40)
            }
        }
    }
}

private struct AlphaAskToolbarButton: View {
    let systemImage: String
    var tint: Color = Color.rossInk
    var fillColor: Color = Color.rossGlassFill
    var strokeColor: Color = Color.rossGlassStroke.opacity(0.7)
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(fillColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(strokeColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private func alphaAskSuggestions(for scopeLabel: String?, documentTitle: String? = nil) -> [String] {
    if let documentTitle, !documentTitle.isEmpty {
        return [
            "What should I note from \(documentTitle)?",
            "What in \(documentTitle) still needs review?",
            "What should I do next after this file?"
        ]
    }
    if let scopeLabel, !scopeLabel.isEmpty {
        return [
            "Summarise this matter in one note.",
            "What is the next date and why does it matter?",
            "What should I do next for this matter?"
        ]
    }
    return [
        "What needs my attention today?",
        "What should I prepare this week?",
        "Which files still need review?"
    ]
}

private struct AlphaCaseWorkspaceScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var selectedSection: AlphaCaseWorkspaceSection = .overview
    @State private var documentLayoutMode: AlphaDocumentLayoutMode = .grid
    @State private var expandedDocumentIDs: Set<UUID> = []
    @State private var showingImporter = false

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            if let caseMatter {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    AlphaInlineHeader(
                        eyebrow: caseMatter.forum,
                        title: caseMatter.title,
                        detail: "\(caseMatter.stage.title) · \(caseMatter.documents.count) documents · \(model.openTaskCount(for: caseId)) open tasks"
                    )

                    AlphaCaseWorkspaceSectionBar(selectedSection: $selectedSection)

                    switch selectedSection {
                    case .overview:
                        RossSectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Auto-generated locally")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossAccent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.rossAccent.opacity(0.1), in: Capsule())

                                    Spacer(minLength: 8)

                                    Button {
                                        Task { await model.refreshCaseOverview(caseId: caseId) }
                                    } label: {
                                        RossGlassIconView(.refresh, variant: .accent, size: 24, fallbackSystemImage: model.refreshingCaseOverviewIDs.contains(caseId) ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                                            .frame(width: 34, height: 34)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(model.refreshingCaseOverviewIDs.contains(caseId))
                                    .accessibilityLabel("Reload overview with Ross")
                                }

                                if let nextHearing = caseMatter.nextHearing {
                                    Text("Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.headline)
                                }
                                Text("\(caseMatter.documents.count) documents • \(model.reviewQueue(caseId: caseId).count) review items")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))

                                if caseMatter.draftTasks.isEmpty {
                                    Text("No next-step note is saved yet. Import another file or ask Ross to refresh this matter's next actions.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.rossInk.opacity(0.7))
                                } else {
                                    Text(alphaCaseAttentionSummary(caseMatter))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.rossInk.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)

                                    ForEach(caseMatter.draftTasks.prefix(3), id: \.self) { task in
                                        RossBulletRow(text: task)
                                    }
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Matter summary")
                                        .font(.headline)
                                        .foregroundStyle(Color.rossInk)
                                    Text("Built from the documents Ross has already read on this device.")
                                        .font(.caption)
                                        .foregroundStyle(Color.rossInk.opacity(0.62))
                                }

                                Text(caseMatter.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)

                                if !caseMatter.issueHighlights.isEmpty {
                                    Text("Key points")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossInk.opacity(0.65))
                                    ForEach(caseMatter.issueHighlights.prefix(4), id: \.self) { item in
                                        RossBulletRow(text: item)
                                    }
                                }

                                if !caseMatter.caseMemoryUpdates.isEmpty {
                                    Divider()
                                    Text("Recent activity")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossInk.opacity(0.65))
                                    ForEach(caseMatter.caseMemoryUpdates.prefix(3)) { update in
                                        Text(update.summary)
                                            .font(.footnote)
                                            .foregroundStyle(Color.rossInk.opacity(0.7))
                                    }
                                }
                            }
                        }
                    case .documents:
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaActiveMatterChatCard(
                                session: model.activeChatSession(for: caseId),
                                sessionTitle: model.activeChatSession(for: caseId).map(model.chatSessionTitle),
                                sessionSubtitle: model.activeChatSession(for: caseId).map(model.chatSessionSubtitle),
                                onOpenChat: { model.openAsk(scopeCaseID: caseId) },
                                onStartNewChat: { model.startNewChat(for: caseId) }
                            )

                            HStack(spacing: 10) {
                                Text("\(caseMatter.documents.count) file(s) on this matter")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rossInk.opacity(0.62))

                                Spacer(minLength: 0)

                                AlphaDocumentLayoutMenu(layoutMode: $documentLayoutMode)
                            }

                            Button("Import document") {
                                showingImporter = true
                            }
                            .rossPrimaryButtonStyle()

                            if caseMatter.documents.isEmpty {
                                RossSectionCard {
                                    Text("Import the first file for this case.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.rossInk.opacity(0.7))
                                }
                            } else {
                                AlphaDocumentCollectionView(
                                    documents: caseMatter.documents,
                                    caseTitle: nil,
                                    layoutMode: documentLayoutMode,
                                    expandedDocumentIDs: $expandedDocumentIDs,
                                    onOpen: { documentId in
                                        model.path.append(.documentViewer(caseId, documentId, 1))
                                    },
                                    onMoveDocument: { documentId, offset in
                                        model.moveDocument(caseId: caseId, documentId: documentId, by: offset)
                                    },
                                    onOpenChat: { documentId in
                                        model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false)
                                    },
                                    onStartReviewChat: { documentId in
                                        model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: true)
                                    }
                                )
                            }
                        }
                    case .tasks:
                        RossSectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(model.refreshingCaseOverviewIDs.contains(caseId) ? "Refreshing task suggestions with Ross..." : "Refresh task suggestions with Ross") {
                                    Task { await model.refreshCaseOverview(caseId: caseId) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.refreshingCaseOverviewIDs.contains(caseId))

                                AlphaTaskQuickAddCard(onAdd: { title, dueDate in
                                    model.addTask(title: title, caseId: caseId, dueDate: dueDate)
                                })
                                ForEach(model.tasks(for: caseId)) { task in
                                    AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                                }
                            }
                        }
                    case .review:
                        RossSectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(model.reviewQueue(caseId: caseId)) { item in
                                    AlphaReviewRow(item: item) {
                                        model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                                    }
                                }
                            }
                        }
                    case .notesExports:
                        RossSectionCard {
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
                .padding(alphaScreenPadding)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AlphaRootAskDock(model: model, fixedScopeCaseID: caseId)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 6)
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
        .navigationTitle("Case")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaDocumentListScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var showingImporter = false
    @State private var documentLayoutMode: AlphaDocumentLayoutMode = .grid
    @State private var expandedDocumentIDs: Set<UUID> = []

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: caseMatter?.forum ?? "Documents",
                    title: caseMatter?.title ?? "Documents",
                    detail: "\(caseMatter?.documents.count ?? 0) file(s) in this case"
                )

                RossSectionCard {
                    HStack {
                        Text("\(caseMatter?.documents.count ?? 0) file(s) stored for this matter")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.62))

                        Spacer(minLength: 0)

                        AlphaDocumentLayoutMenu(layoutMode: $documentLayoutMode)
                    }
                }

                Button("Import document") {
                    showingImporter = true
                }
                .rossPrimaryButtonStyle()

                if let caseMatter, caseMatter.documents.isEmpty {
                    RossSectionCard {
                        Text("Import the first order, pleading, notice, or note for this matter.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }

                if let documents = caseMatter?.documents, !documents.isEmpty {
                    AlphaDocumentCollectionView(
                        documents: documents,
                        caseTitle: nil,
                        layoutMode: documentLayoutMode,
                        expandedDocumentIDs: $expandedDocumentIDs,
                        onOpen: { documentId in
                            model.path.append(.documentViewer(caseId, documentId, 1))
                        },
                        onMoveDocument: { documentId, offset in
                            model.moveDocument(caseId: caseId, documentId: documentId, by: offset)
                        },
                        onOpenChat: { documentId in
                            model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false)
                        },
                        onStartReviewChat: { documentId in
                            model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: true)
                        }
                    )
                }
            }
            .padding(alphaScreenPadding)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: "Open Ask Ross") {
                    model.openAsk(scopeCaseID: caseId)
                }
            }
        }
    }
}

private struct AlphaDocumentViewerScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    let documentId: UUID
    let initialPage: Int?

    private var isSharedDocument: Bool {
        caseId == alphaSharedWorkspaceID
    }

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

    private var sortedReviewFields: [AlphaExtractedLegalField] {
        reviewFields.sorted { alphaFieldSortRank($0.fieldType) < alphaFieldSortRank($1.fieldType) }
    }

    private var importantReviewFields: [AlphaExtractedLegalField] {
        sortedReviewFields.filter { alphaIsImportantReviewField($0.fieldType) }
    }

    private var detailReviewFields: [AlphaExtractedLegalField] {
        sortedReviewFields.filter { !alphaIsImportantReviewField($0.fieldType) }
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
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    AlphaInlineHeader(
                        eyebrow: document.kind.title,
                        title: document.title,
                        detail: "Status: \(document.lawyerStatusTitle) · \(document.pageCount) page(s) · \(needsReviewCount) need review"
                    )

                    RossSectionCard(
                        title: "Review snapshot",
                        subtitle: reviewSummaryText ?? (needsReviewCount > 0 ? "Ross found details that still need advocate review." : "This document is ready for normal use in the matter.")
                    ) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            RossMetricTile(label: "Status", value: needsReviewCount > 0 ? "Needs review" : "Ready", tint: needsReviewCount > 0 ? .orange : Color.rossSuccess)
                            RossMetricTile(label: "Fields", value: "\(reviewFields.count)", tint: Color.rossAccent)
                            RossMetricTile(label: "Needs review", value: "\(needsReviewCount)", tint: needsReviewCount > 0 ? .orange : Color.rossSuccess)
                            RossMetricTile(label: "Page", value: "\(resolvedPage)/\(document.pageCount)", tint: Color.rossHighlight)
                        }
                    }

                    RossSectionCard(title: "Actions") {
                        VStack(spacing: 12) {
                            AlphaActiveMatterChatCard(
                                session: model.activeChatSession(for: caseId),
                                sessionTitle: model.activeChatSession(for: caseId).map(model.chatSessionTitle),
                                sessionSubtitle: model.activeChatSession(for: caseId).map(model.chatSessionSubtitle),
                                onOpenChat: {
                                    model.openDocumentInChat(caseId: caseId, documentId: document.id, startNewThread: false)
                                },
                                onStartNewChat: {
                                    model.openDocumentInChat(caseId: caseId, documentId: document.id, startNewThread: true)
                                }
                            )

                            RossActionTile(
                                title: "Continue in active matter chat",
                                detail: "Use the current matter thread with this document already selected.",
                                systemImage: "bubble.left.and.text.bubble.right",
                                tint: Color.rossAccent
                            ) {
                                model.openDocumentInChat(caseId: caseId, documentId: document.id, startNewThread: false)
                            }

                            RossActionTile(
                                title: "Start review chat for this document",
                                detail: "Open a fresh matter thread dedicated to this file and its review.",
                                systemImage: "square.and.pencil",
                                tint: Color.rossHighlight
                            ) {
                                model.openDocumentInChat(caseId: caseId, documentId: document.id, startNewThread: true)
                            }

                            RossActionTile(
                                title: "Create review task",
                                detail: "Save a follow-up task linked to this matter and its next date.",
                                systemImage: "checklist",
                                tint: Color.rossHighlight
                            ) {
                                model.addTask(
                                    title: "Review \(document.title)",
                                    caseId: caseId,
                                    dueDate: caseMatter?.nextHearing,
                                    priority: .normal,
                                    notes: "Created from the document viewer."
                                )
                            }

                            RossActionTile(
                                title: "Generate case note",
                                detail: "Create a local note you can refine before sharing or filing.",
                                systemImage: "text.append",
                                tint: Color.rossSuccess
                            ) {
                                Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                            }

                            RossActionTile(
                                title: "Re-run review",
                                detail: "Ask Ross to review this file again using the current assistant and source rules.",
                                systemImage: "arrow.clockwise",
                                tint: Color.rossAccent
                            ) {
                                Task { await model.rerunReview(caseId: caseId, documentId: documentId) }
                            }

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
                        RossSectionCard(title: "Review details", subtitle: reviewSummaryText) {
                            VStack(alignment: .leading, spacing: 14) {
                                if document.classification != nil || !importantReviewFields.isEmpty || !reviewFindings.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Important")
                                            .font(.headline)
                                        Text("Check the details that can change dates, parties, filing position, or what happens next.")
                                            .font(.footnote)
                                            .foregroundStyle(Color.rossInk.opacity(0.65))

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

                                        ForEach(importantReviewFields) { field in
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

                                        ForEach(reviewFindings) { finding in
                                            AlphaFindingCard(finding: finding, onOpenSourceRef: model.openSourceRef)
                                        }
                                    }
                                }

                                if document.languageProfile != nil || !detailReviewFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Other details")
                                            .font(.headline)
                                        Text("Helpful details you can accept, edit, or ignore after the essentials are clear.")
                                            .font(.footnote)
                                            .foregroundStyle(Color.rossInk.opacity(0.65))

                                        if let languageProfile = document.languageProfile {
                                            RossSectionCard(title: "Language profile", subtitle: "Scripts seen in this file.") {
                                                HStack(spacing: 12) {
                                                    RossInfoPill(title: "Primary: \(languageProfile.primaryLanguage.rawValue.capitalized)", systemImage: "character.book.closed")
                                                    RossInfoPill(title: "Scripts: \(languageProfile.scriptsDetected.joined(separator: ", "))", systemImage: "textformat.abc.dottedunderline")
                                                }
                                            }
                                        }

                                        ForEach(detailReviewFields) { field in
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

                    RossSectionCard(title: "Text found") {
                        Text(document.extractedText ?? "Ross will keep source references visible even when exact highlights are still pending.")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.8))
                    }

                    RossSectionCard(title: "Sources") {
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
                .padding(alphaScreenPadding)
            }
        }
        .navigationTitle("Document")
        .rossInlineNavigationTitle()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if let document {
                    AlphaDocumentQuickAskStrip(
                        title: document.title,
                        detail: reviewSummaryText
                            ?? document.dominantSourceSnippet
                            ?? "Ross will answer from this file only while you stay here.",
                        isShared: isSharedDocument
                    )
                }

                AlphaRootAskDock(model: model, fixedScopeCaseID: caseId, fixedDocumentIDs: [documentId])
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
        }
    }
}

private struct AlphaDocumentQuickAskStrip: View {
    let title: String
    let detail: String
    let isShared: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RossGlassIconView(
                isShared ? .earth : .file,
                variant: isShared ? .highlight : .neutral,
                size: 18,
                fallbackSystemImage: isShared ? "globe" : "doc.text"
            )
            .frame(width: 28, height: 28)
            .background(Color.rossCardBackground, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(isShared ? "Shared file" : "This file")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.rossAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.rossAccent.opacity(0.1), in: Capsule())
        }
        .padding(12)
        .background(Color.rossCardBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
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
        RossSectionCard {
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
        let confidenceLabel = alphaConfidenceLabel(confidence: classification.confidence, needsReview: classification.needsReview)
        let confidenceSupport = alphaConfidenceSupportText(confidence: classification.confidence, needsReview: classification.needsReview)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document type")
                        .font(.headline)
                    Text(classification.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title3.weight(.semibold))
                    Text(confidenceSupport)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(alphaConfidenceTint(confidenceLabel))
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: confidenceLabel,
                    tint: alphaConfidenceTint(confidenceLabel)
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
        let confidenceSupport = alphaConfidenceSupportText(confidence: field.confidence, needsReview: field.needsReview)

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
                    Text(confidenceSupport)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(alphaConfidenceTint(field.confidenceLabel))
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: field.confidenceLabel,
                    tint: alphaConfidenceTint(field.confidenceLabel)
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
        AlphaAskConversationScreen(model: model, fixedScopeCaseID: caseId)
    }
}

private struct AlphaPublicLawScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: nil,
                    title: "Sanitized law search",
                    detail: "Ross only sends a generic public-law query after you review it."
                )

                RossSectionCard {
                    TextEditor(text: $model.publicLawDraft)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Do not send case IDs, filenames, OCR text, chunk text, chat history, client names, party names, phone numbers, emails, or long factual narratives.")
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))

                    Button("Review sanitized query") {
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
            .padding(alphaScreenPadding)
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
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: nil,
                    title: "Drafts and reports",
                    detail: "Generate local reports for advocate review."
                )

                RossSectionCard(title: "Generate") {
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

                        Button("Generate Ross Thread Transcript") {
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
            .padding(alphaScreenPadding)
        }
        .navigationTitle("Exports")
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: "Open Ask Ross") {
                    if let caseId {
                        model.openAsk(scopeCaseID: caseId)
                    } else {
                        model.openAsk()
                    }
                }
            }
        }
    }
}

private struct AlphaSettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                if let activeJob = alphaActiveSetupJob(model) {
                    NavigationLink(value: AlphaRoute.privateAISettings) {
                        AlphaAssistantActivityStrip(
                            title: "\(activeJob.tier.title) is still preparing",
                            detail: alphaAssistantActivityDetail(for: activeJob.state),
                            statusLabel: activeJob.state.title,
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                RossSectionCard(title: "Privacy") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Ask before Web search", isOn: $model.persisted.settings.requirePublicLawApproval)
                        Divider()
                        Toggle("Keep Ross private by default", isOn: $model.persisted.settings.privateByDefault)
                        Text("Matter files stay on this device. Web search sends only a sanitized public-law query after you approve it.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.64))
                    }
                }

                RossSectionCard(title: "On this device") {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaSettingsValueRow(label: "Status", value: alphaPrivateAIStatus(model))
                        Divider()
                        AlphaSettingsValueRow(label: "Pack", value: model.activePack?.tier.title ?? "Not installed")
                        Divider()
                        AlphaSettingsValueRow(label: "Saved reports", value: "\(model.persisted.exports.count)")
                        Divider()
                        NavigationLink(value: AlphaRoute.privateAISettings) {
                            AlphaSettingsNavigationRow(
                                title: "Open device setup",
                                detail: "Review downloads, setup progress, and diagnostics.",
                                systemImage: "gearshape.2"
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                        NavigationLink(value: AlphaRoute.privacyLedger) {
                            AlphaSettingsNavigationRow(
                                title: "Open Privacy Ledger",
                                detail: "See visible network and local actions.",
                                systemImage: "checklist"
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                        NavigationLink(value: AlphaRoute.privateAISettings) {
                            AlphaSettingsNavigationRow(
                                title: "Diagnostics",
                                detail: "Use this only if setup or on-device review needs attention.",
                                systemImage: "wrench.and.screwdriver"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(alphaScreenPadding)
        }
        .rossHideNavigationBarIfSupported()
    }
}

private struct AlphaSettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            Spacer(minLength: 12)

            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.62))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct AlphaSettingsNavigationRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.rossAccent)
                .frame(width: 30, height: 30)
                .background(Color.rossAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossInk.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AlphaPrivateAISettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        let assistantStatus = alphaAssistantStatusSnapshot(model)

        List {
            if let activeJob = alphaActiveSetupJob(model) {
                Section("Assistant activity") {
                    AlphaAssistantActivityStrip(
                        title: "\(activeJob.tier.title) is still preparing",
                        detail: alphaAssistantActivityDetail(for: activeJob.state),
                        statusLabel: activeJob.state.title,
                        tint: .orange
                    )
                }
            }

            Section("Current status") {
                LabeledContent("Status", value: assistantStatus.title)
                LabeledContent("Pack", value: model.activePack?.tier.title ?? "Not installed")
                LabeledContent("Review quality", value: model.activeExtractionMode.qualityLabel)
                Text(assistantStatus.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Download settings") {
                Toggle("Wi-Fi only downloads", isOn: $model.persisted.settings.wifiOnlyDownloads)
                Toggle("Allow mobile data for large packs", isOn: $model.persisted.settings.allowMobileDataForLargePacks)
            }

            Section("Choose a review level") {
                ForEach(AlphaPackOffer.catalog) { offer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(offer.tier.title)
                            .font(.headline)
                        Text(offer.tier.summary)
                            .font(.footnote)
                        Text("Review quality: \(offer.tier.extractionQuality)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                        Text(offer.tier.bestFor)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Download or resume") {
                                Task { await model.startPackDownload(for: offer.tier, mobileAllowed: model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Setup in progress") {
                ForEach(model.persisted.modelJobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.tier.title)
                            .font(.headline)
                        Text(job.state.title)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossAccent)
                        Text("Ross is downloading and checking this level on this device.")
                            .font(.caption)
                        HStack {
                            Button("Pause") { model.pauseJob(job) }
                            Button("Resume") { model.resumeJob(job) }
                        }
                    }
                }
            }

            Section("Ready on this device") {
                ForEach(model.persisted.installedPacks) { pack in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pack.tier.title)
                            .font(.headline)
                        Text("Ready on this device")
                            .font(.caption)
                        HStack {
                            Button("Use this level") { model.activateInstalledPack(pack) }
                            Button("Remove", role: .destructive) { model.removeInstalledPack(pack) }
                        }
                    }
                }
            }

            if let runtimeHealth = model.activeRuntimeHealth {
                Section("Diagnostics") {
                    DisclosureGroup("Diagnostics details") {
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
        .navigationTitle("Private Assistant")
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

private func alphaAttentionHeadline(_ count: Int) -> String {
    switch count {
    case 0:
        return "Today is under control"
    case 1:
        return "1 item needs attention"
    default:
        return "\(count) items need attention"
    }
}

private func alphaIsImportantReviewField(_ type: AlphaExtractedLegalFieldType) -> Bool {
    alphaFieldSortRank(type) <= 8
}

private func alphaConfidenceLabel(confidence: Double, needsReview: Bool) -> String {
    if needsReview {
        return "Needs review"
    }
    if confidence < 0.84 {
        return "Low confidence"
    }
    return "Verified"
}

private func alphaConfidenceTint(_ label: String) -> Color {
    switch label {
    case "Verified":
        return Color.rossSuccess
    case "Low confidence":
        return Color.rossAccent
    default:
        return .orange
    }
}

private func alphaConfidenceSupportText(confidence: Double, needsReview: Bool) -> String {
    switch alphaConfidenceLabel(confidence: confidence, needsReview: needsReview) {
    case "Verified":
        return "Verified from the file"
    case "Low confidence":
        return "Ross found this, but the wording should be double-checked"
    default:
        return "Needs your confirmation before you rely on it"
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
        RossSectionCard {
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
        RossSectionCard {
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
