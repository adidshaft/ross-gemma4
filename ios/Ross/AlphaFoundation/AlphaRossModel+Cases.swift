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

func alphaNewMatterSummary(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("new_matter_summary", languageCode: languageCode)
}

func alphaNewMatterIssueHighlight(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("new_matter_issue_highlight", languageCode: languageCode)
}

func alphaNewMatterEvidenceNote(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("new_matter_evidence_note", languageCode: languageCode)
}

func alphaNewMatterDraftTasks(languageCode: String = rossSelectedLanguageCode()) -> [String] {
    [
        rossLocalized("new_matter_draft_task_import_first_document", languageCode: languageCode),
        rossLocalized("new_matter_draft_task_pin_first_source", languageCode: languageCode)
    ]
}

func alphaNewMatterFirstTaskTitle(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("new_matter_first_task_title", languageCode: languageCode)
}

func alphaNewMatterFirstTaskNotes(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("new_matter_first_task_notes", languageCode: languageCode)
}

func alphaCourtNotYetSpecifiedLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("court_not_yet_specified", languageCode: languageCode)
}

func alphaIsCourtNotYetSpecified(_ forum: String) -> Bool {
    let trimmed = forum.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    if trimmed == "Court not yet specified" { return true }
    return rossSupportedLanguageCodes().contains { languageCode in
        trimmed == alphaCourtNotYetSpecifiedLabel(languageCode: languageCode)
    }
}

extension AlphaRossModel {

    var sharedWorkspace: AlphaCaseMatter? {
        persisted.cases.first(where: { $0.id == alphaSharedWorkspaceID })
    }

    var activeCaseIDs: Set<UUID> {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.activeCaseIDs
    }

    var tasks: [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.tasks
    }

    var openTasks: [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.openTasks
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
        persist(workspaceChanged: true)
    }

    func tasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.tasks }
        guard caseId != alphaSharedWorkspaceID else { return [] }
        return workspaceDerivedState.tasksByCase[caseId] ?? []
    }

    func nextActionDate(for caseId: UUID) -> Date? {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.nextActionDateByCase[caseId]
    }

    func askDraft(for scopeCaseID: UUID?) -> String {
        if let scopeCaseID {
            return askDrafts[scopeCaseID] ?? ""
        }
        return globalAskDraft
    }

    func skipPackSetup() {
        persisted.onboardingStage = .completed
        persist()
    }

    func updateSettings(_ mutate: (inout AlphaSettings) -> Void) {
        mutate(&persisted.settings)
        if let activeTier = persisted.settings.activeTier {
            selectedTier = activeTier
        }
        persist()
    }

    func finishPackSetup() {
        let decision = assistantRuntimeDecision(selectedTier: selectedTier)
        selectedTier = decision.effectiveTier
        persisted.settings.activeTier = decision.effectiveTier
        persisted.onboardingStage = .completed
        if decision.deviceSupportState == .autoDowngraded {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant level adjusted",
                    detail: decision.reason,
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://assistant-routing",
                    success: true
                ),
                at: 0
            )
        }
        persist()
        Task { await startPackDownload(for: decision.effectiveTier, mobileAllowed: decision.effectiveTier == .quickStart) }
    }

    func clearCaseDraft() {
        caseDraftTitle = ""
    }

    func resetDemoWorkspace(for subject: String = "local_demo_advocate") {
        let preserved = preservedWorkspaceConfiguration()
        persisted = AlphaPersistedState.demoSeed(profileSubject: subject)
        applyPreservedWorkspaceConfiguration(preserved)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_demo_workspace_reset_title"),
                detail: rossLocalized("privacy_ledger_demo_workspace_reset_detail"),
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://demo-reset",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
    }

    func createCase(openWorkspace: Bool = true) {
        let title = caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let matter = AlphaCaseMatter(
            title: title,
            forum: alphaCourtNotYetSpecifiedLabel(),
            caseNumber: nil,
            partiesSummary: nil,
            stage: .intake,
            nextHearing: nil,
            dates: [],
            notes: nil,
            summary: alphaNewMatterSummary(),
            issueHighlights: [alphaNewMatterIssueHighlight()],
            evidenceNotes: [alphaNewMatterEvidenceNote()],
            draftTasks: alphaNewMatterDraftTasks(),
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )

        let normalizedMatter = matter
        persisted.cases.insert(normalizedMatter, at: 0)
        var taskList = persisted.tasks ?? []
        taskList.insert(
            AlphaTaskItem(
                caseId: normalizedMatter.id,
                title: alphaNewMatterFirstTaskTitle(),
                notes: alphaNewMatterFirstTaskNotes(),
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                priority: .high,
                source: .system
            ),
            at: 0
        )
        persisted.tasks = taskList
        selectedCaseID = normalizedMatter.id
        askSelectedScopeCaseID = normalizedMatter.id
        clearCaseDraft()
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Case created locally",
                detail: rossLocalized("privacy_ledger_case_created_detail"),
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://case-create",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
        if openWorkspace {
            path.removeAll()
            path.append(.caseWorkspace(normalizedMatter.id))
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
        persist(workspaceChanged: true)
    }

    func archiveCase(_ caseID: UUID) {
        guard caseID != alphaSharedWorkspaceID else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].archivedAt = .now
        persisted.cases[caseIndex].updatedAt = .now
        invalidateWorkspaceDerivedState()
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
        persist(workspaceChanged: true)
    }

    func setFolderTint(_ tint: AlphaMatterTint, for caseID: UUID) {
        guard caseID != alphaSharedWorkspaceID else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseID }) else { return }
        persisted.cases[caseIndex].folderTint = tint
        persisted.cases[caseIndex].updatedAt = .now
        persist(workspaceChanged: true)
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
        invalidateWorkspaceDerivedState()
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
        persist(workspaceChanged: true)
    }

    func upsertJob(_ job: AlphaModelDownloadJob) {
        if let index = persisted.modelJobs.firstIndex(where: { $0.id == job.id }) {
            persisted.modelJobs[index] = job
        } else if let index = persisted.modelJobs.firstIndex(where: { $0.tier == job.tier && $0.state != .installed }) {
            persisted.modelJobs[index] = job
        } else {
            persisted.modelJobs.insert(job, at: 0)
        }
    }
}
