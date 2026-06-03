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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private func alphaRoutineRunSummary(updatedCount: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    guard updatedCount > 0 else {
        return rossLocalized("routine_no_prepared_work_changed", languageCode: languageCode)
    }
    return String(format: rossLocalized("routine_prepared_items_updated", languageCode: languageCode), updatedCount)
}

private func alphaRoutineRanLocallyTitle(_ reason: AlphaRoutineKind, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("routine_ran_locally_title", languageCode: languageCode), rossLocalized(reason.rawValue, languageCode: languageCode))
}

private func alphaNextDateSavedForMatterSummary(_ date: Date, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("prepared_work_next_date_saved_for_matter", languageCode: languageCode),
        date.formatted(date: .abbreviated, time: .omitted)
    )
}

private func alphaDraftReadyTitle(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("prepared_work_draft_ready_title", languageCode: languageCode), title)
}

private func alphaHearingNoteReadySummary(_ date: Date, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("prepared_work_hearing_note_ready_summary", languageCode: languageCode),
        date.formatted(date: .abbreviated, time: .omitted)
    )
}

private func alphaReviewItemsFromFileNeedReviewSummary(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("prepared_work_file_review_items_need_review", languageCode: languageCode),
        alphaReviewItemCountLabel(count)
    )
}

extension AlphaRossModel {
    var routineSettings: AlphaRoutineSettings {
        persisted.routineSettings ?? .default
    }

    func updateRoutineSettings(_ mutate: (inout AlphaRoutineSettings) -> Void) {
        var settings = routineSettings
        mutate(&settings)
        settings.requirePublicLawApproval = true
        persisted.routineSettings = settings
        persisted.settings.requirePublicLawApproval = true
        persist()
    }

    func preparedWorkItems(caseId: UUID? = nil, includeDismissed: Bool = false) -> [AlphaPreparedWorkItem] {
        let items = (persisted.preparedWorkItems ?? [])
            .filter { includeDismissed || $0.status != .dismissed }
            .filter { item in
                guard let caseId else { return true }
                return item.caseId == caseId
            }
        return items.sorted {
            if $0.status != $1.status {
                return $0.status.sortRank < $1.status.sortRank
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func preparedWorkNeedingAttention(caseId: UUID? = nil) -> [AlphaPreparedWorkItem] {
        preparedWorkItems(caseId: caseId).filter { $0.status == .new || $0.status == .reviewed }
    }

    func setPreparedWorkStatus(_ itemID: UUID, status: AlphaPreparedWorkStatus) {
        guard var items = persisted.preparedWorkItems,
              let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = status
        items[index].updatedAt = .now
        persisted.preparedWorkItems = items
        persist(workspaceChanged: true)
    }

    func runMorningRoutineIfNeeded(now: Date = .now) {
        guard routineSettings.morningBriefEnabled else { return }
        let calendar = Calendar.current
        let alreadyRanToday = (persisted.routineRuns ?? []).contains {
            $0.kind == .morningBrief && calendar.isDate($0.ranAt, inSameDayAs: now)
        }
        guard !alreadyRanToday else { return }
        rebuildPreparedWork(reason: .morningBrief, caseId: nil, persistAfter: true)
    }

    func runWorkbenchRoutine(_ kind: AlphaRoutineKind, caseId: UUID? = nil) {
        switch kind {
        case .publicLawPreview:
            preparePublicLawPreviewWork(caseId: caseId)
        default:
            rebuildPreparedWork(reason: kind, caseId: caseId, persistAfter: true)
        }
    }

    func rebuildPreparedWork(reason: AlphaRoutineKind, caseId: UUID? = nil, persistAfter: Bool) {
        var existingItems = persisted.preparedWorkItems ?? []
        let generatedItems = generatePreparedWork(caseId: caseId)
        let generatedKeys = Set(generatedItems.map(\.stableKey))
        var touchedIDs: [UUID] = []

        for generated in generatedItems {
            if let index = existingItems.firstIndex(where: { $0.stableKey == generated.stableKey }) {
                var updated = generated
                let existing = existingItems[index]
                updated.id = existing.id
                updated.createdAt = existing.createdAt
                if existing.sourceFingerprint == generated.sourceFingerprint {
                    updated.status = existing.status
                    updated.updatedAt = existing.updatedAt
                } else {
                    updated.status = .new
                    updated.updatedAt = .now
                }
                existingItems[index] = updated
                touchedIDs.append(updated.id)
            } else {
                existingItems.insert(generated, at: 0)
                touchedIDs.append(generated.id)
            }
        }

        if let caseId {
            existingItems = existingItems.filter { item in
                item.caseId != caseId || generatedKeys.contains(item.stableKey) || item.status == .dismissed
            }
        } else {
            existingItems = existingItems.filter { item in
                generatedKeys.contains(item.stableKey) || item.status == .dismissed
            }
        }

        persisted.preparedWorkItems = existingItems
        persisted.routineRuns = ([AlphaRoutineRun(
            kind: reason,
            caseId: caseId,
            preparedItemIDs: touchedIDs,
            summary: alphaRoutineRunSummary(updatedCount: touchedIDs.count)
        )] + (persisted.routineRuns ?? [])).prefix(50).map { $0 }

        if persistAfter {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: alphaRoutineRanLocallyTitle(reason),
                    detail: rossLocalized("routine_used_saved_local_data_detail"),
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://routines/\(reason.rawValue)",
                    success: true
                ),
                at: 0
            )
            persist(workspaceChanged: true)
        }
    }

    func generatePreparedWork(caseId: UUID? = nil) -> [AlphaPreparedWorkItem] {
        let matters = persisted.cases.filter { matter in
            matter.id != alphaSharedWorkspaceID &&
                matter.archivedAt == nil &&
                (caseId == nil || matter.id == caseId)
        }
        guard !matters.isEmpty else { return [] }

        var items: [AlphaPreparedWorkItem] = []
        for matter in matters {
            let reviews = reviewQueue(caseId: matter.id)
            let matterTasks = tasks(for: matter.id).filter { $0.status == .open }
            let scheduledDates = scheduledMatterDates(for: matter.id)
            let matterExports = persisted.exports.filter { $0.caseId == matter.id }
            let latestDocument = matter.documents.sorted { $0.importedAt > $1.importedAt }.first
            let sourceRefs = Array(matter.sourceRefs.prefix(3))

            if let latestDocument,
               latestDocument.indexingStatus == .indexed ||
                latestDocument.indexingStatus == .partial ||
                latestDocument.processingState == .ready ||
                latestDocument.processingState == .needsConfirmation {
                let reviewCount = reviews.filter { $0.documentId == latestDocument.id }.count
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "document-reviewed:\(matter.id.uuidString):\(latestDocument.id.uuidString)",
                        caseId: matter.id,
                        type: .documentReviewed,
                        matterName: matter.title,
                        title: alphaDocumentReviewUpdatedTitle(latestDocument.title),
                        summary: reviewCount == 0 ? rossLocalized("prepared_work_file_read_updated_matter_memory") : alphaReviewItemsFromFileNeedReviewSummary(reviewCount),
                        badge: reviewCount == 0 ? .sourceBacked : .needsReview,
                        sourceRefs: sourceRefsFor(documentId: latestDocument.id, in: matter, fallback: sourceRefs),
                        sourceFingerprint: alphaPreparedFingerprint(parts: [
                            latestDocument.id.uuidString,
                            latestDocument.lastIndexedAt?.timeIntervalSince1970.description ?? "",
                            "\(latestDocument.extractedFields.count)",
                            "\(latestDocument.extractionFindings.count)"
                        ]),
                        primaryAction: reviewCount == 0 ? rossLocalized("open") : rossLocalized("review"),
                        secondaryActions: reviewCount == 0 ? [rossLocalized("check_sources"), rossLocalized("dismiss")] : [rossLocalized("edit"), rossLocalized("dismiss")]
                    )
                )
            }

            if let nextDate = scheduledDates.first {
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "next-date:\(matter.id.uuidString):\(nextDate.id.uuidString)",
                        caseId: matter.id,
                        type: .nextDateFound,
                        matterName: matter.title,
                        title: nextDate.title,
                        summary: alphaNextDateSavedForMatterSummary(nextDate.date),
                        badge: nextDate.sourceRef == nil ? .preparedLocally : .sourceBacked,
                        sourceRefs: nextDate.sourceRef.map { [$0] } ?? [],
                        sourceFingerprint: alphaPreparedFingerprint(parts: [nextDate.id.uuidString, nextDate.date.timeIntervalSince1970.description, nextDate.updatedAt.timeIntervalSince1970.description]),
                        primaryAction: rossLocalized("confirm"),
                        secondaryActions: [rossLocalized("open"), rossLocalized("dismiss")]
                    )
                )
            }

            if !matterTasks.isEmpty {
                let topTasks = matterTasks.prefix(3).map(\.title)
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "suggested-tasks:\(matter.id.uuidString)",
                        caseId: matter.id,
                        type: .suggestedTasks,
                        matterName: matter.title,
                        title: rossLocalized("prepared_work_tasks_ready_for_review"),
                        summary: topTasks.joined(separator: "; "),
                        badge: .preparedLocally,
                        sourceRefs: sourceRefs,
                        sourceFingerprint: alphaPreparedFingerprint(parts: matterTasks.map { "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)" }),
                        primaryAction: rossLocalized("review"),
                        secondaryActions: [rossLocalized("accept"), rossLocalized("edit"), rossLocalized("dismiss")]
                    )
                )
            }

            if !reviews.isEmpty {
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "missing-facts:\(matter.id.uuidString)",
                        caseId: matter.id,
                        type: .missingFactsFound,
                        matterName: matter.title,
                        title: rossLocalized("prepared_work_uncertain_facts_need_review"),
                        summary: alphaResolveReviewItemsBeforeRelyingLabel(reviews.count),
                        badge: .needsReview,
                        sourceRefs: Array(reviews.compactMap(\.sourceRef).prefix(3)),
                        sourceFingerprint: alphaPreparedFingerprint(parts: reviews.map(\.id)),
                        primaryAction: rossLocalized("review"),
                        secondaryActions: [rossLocalized("edit"), rossLocalized("dismiss")]
                    )
                )
            }

            if let upcomingHearing = scheduledDates.first(where: { $0.kind == .hearing && $0.date <= Calendar.current.date(byAdding: .day, value: 14, to: .now)! }) {
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "hearing-note:\(matter.id.uuidString):\(upcomingHearing.id.uuidString)",
                        caseId: matter.id,
                        type: .hearingNoteReady,
                        matterName: matter.title,
                        title: rossLocalized("prepared_work_hearing_note_checklist_ready"),
                        summary: alphaHearingNoteReadySummary(upcomingHearing.date),
                        badge: reviews.isEmpty ? .preparedLocally : .needsReview,
                        sourceRefs: upcomingHearing.sourceRef.map { [$0] } ?? sourceRefs,
                        sourceFingerprint: alphaPreparedFingerprint(parts: [upcomingHearing.id.uuidString, "\(reviews.count)", matter.updatedAt.timeIntervalSince1970.description]),
                        primaryAction: rossLocalized("review"),
                        secondaryActions: [rossLocalized("edit"), rossLocalized("dismiss")]
                    )
                )
            }

            if let latestDraft = matterExports.sorted(by: { $0.createdAt > $1.createdAt }).first {
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "draft-ready:\(matter.id.uuidString):\(latestDraft.id.uuidString)",
                        caseId: matter.id,
                        type: alphaPreparedType(forExportKind: latestDraft.kind),
                        matterName: matter.title,
                        title: alphaDraftReadyTitle(latestDraft.title),
                        summary: rossLocalized("prepared_work_draft_for_review_summary"),
                        badge: .preparedLocally,
                        sourceRefs: sourceRefs,
                        sourceFingerprint: alphaPreparedFingerprint(parts: [latestDraft.id.uuidString, latestDraft.createdAt.timeIntervalSince1970.description]),
                        primaryAction: rossLocalized("open"),
                        secondaryActions: [rossLocalized("edit"), rossLocalized("dismiss")]
                    )
                )
            }

            if matter.documents.isEmpty || !reviews.isEmpty || !matterTasks.isEmpty {
                items.append(
                    AlphaPreparedWorkItem(
                        stableKey: "matter-attention:\(matter.id.uuidString)",
                        caseId: matter.id,
                        type: .matterNeedsAttention,
                        matterName: matter.title,
                        title: rossLocalized("prepared_work_type_matter_needs_attention"),
                        summary: matter.documents.isEmpty ? rossLocalized("prepared_work_import_real_file_before_source_backed") : matter.summary,
                        badge: matter.documents.isEmpty ? .preparedLocally : .needsReview,
                        sourceRefs: sourceRefs,
                        sourceFingerprint: alphaPreparedFingerprint(parts: [matter.updatedAt.timeIntervalSince1970.description, "\(matter.documents.count)", "\(reviews.count)", "\(matterTasks.count)"]),
                        primaryAction: matter.documents.isEmpty ? rossLocalized("open") : rossLocalized("review"),
                        secondaryActions: [rossLocalized("dismiss")]
                    )
                )
            }
        }
        return items
    }

    func preparePublicLawPreviewWork(caseId: UUID? = nil) {
        let caseMatter = caseId.flatMap { id in persisted.cases.first { $0.id == id } }
        let seed = caseMatter?.issueHighlights.first ?? caseMatter?.draftTasks.first ?? publicLawDraft
        let preview = sanitizePublicLawPreview(rawQuery: seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Indian public-law guidance on court procedure and filing compliance" : seed, caseMatter: caseMatter)
        publicLawPreview = preview
        publicLawResults = []
        publicLawSearchStatus = .reviewing
        persisted.publicLawPreview = preview
        persisted.publicLawResults = []

        var items = persisted.preparedWorkItems ?? []
        let stableKey = "public-law-preview:\(caseId?.uuidString ?? "workspace")"
        let generated = AlphaPreparedWorkItem(
            stableKey: stableKey,
            caseId: caseId,
            type: .publicLawQueryAwaitingApproval,
            matterName: caseMatter?.title ?? rossLocalized("workspace"),
            title: rossLocalized("prepared_work_review_public_law_query"),
            summary: preview.query,
            badge: .approvalRequired,
            sourceRefs: [],
            sourceFingerprint: alphaPreparedFingerprint(parts: [preview.query, preview.removed.joined(separator: "|")]),
            primaryAction: rossLocalized("approve"),
            secondaryActions: [rossLocalized("edit"), rossLocalized("dismiss")]
        )
        if let index = items.firstIndex(where: { $0.stableKey == stableKey }) {
            var updated = generated
            updated.id = items[index].id
            updated.createdAt = items[index].createdAt
            updated.status = items[index].sourceFingerprint == generated.sourceFingerprint ? items[index].status : .new
            items[index] = updated
        } else {
            items.insert(generated, at: 0)
        }
        persisted.preparedWorkItems = items
        persisted.routineRuns = ([AlphaRoutineRun(kind: .publicLawPreview, caseId: caseId, preparedItemIDs: [generated.id], summary: rossLocalized("routine_sanitized_query_preview_prepared"))] + (persisted.routineRuns ?? [])).prefix(50).map { $0 }
        persist(workspaceChanged: true)
    }

    func upcomingTasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.upcomingTasks }
        return workspaceDerivedState.upcomingTasksByCase[caseId] ?? []
    }

    func openTaskCount(for caseId: UUID? = nil) -> Int {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.openTasks.count }
        return workspaceDerivedState.openTaskCountByCase[caseId] ?? 0
    }

    func scheduledMatterDates(for caseId: UUID) -> [AlphaMatterDate] {
        persisted.cases
            .first(where: { $0.id == caseId })?
            .dates
            .filter { $0.status == .scheduled }
            .sorted { $0.date < $1.date } ?? []
    }

    func reviewQueueCount(for caseId: UUID? = nil) -> Int {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.reviewQueue.count }
        return workspaceDerivedState.reviewQueueByCase[caseId]?.count ?? 0
    }

    func toggleTaskDone(_ taskID: UUID) {
        guard var taskList = persisted.tasks, let index = taskList.firstIndex(where: { $0.id == taskID }) else { return }
        taskList[index].status = taskList[index].status == .open ? .done : .open
        taskList[index].updatedAt = .now
        let caseId = taskList[index].caseId
        persisted.tasks = taskList
        invalidateWorkspaceDerivedState()
        if let caseId, let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) {
            refreshCaseWorkspace(at: caseIndex)
        }
        persist(workspaceChanged: true)
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
        invalidateWorkspaceDerivedState()
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
        persist(workspaceChanged: true)
        if let dueDate {
            scheduleReminderNotification(for: dueDate)
        }
    }

    func scheduleReminderNotification(for dueDate: Date) {
        guard dueDate > .now else { return }
        guard !alphaRootViewIsRunningTests() else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else { return }

            let content = UNMutableNotificationContent()
            content.title = "Ross reminder"
            content.body = "A saved task is due. Open Ross to review the details."
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "ross-task-\(UUID().uuidString)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func alphaRootViewIsRunningTests() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["ROSS_RUNNING_TESTS"] == "1" {
            return true
        }
        return Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
    }

    func completeTask(matching title: String, caseId: UUID?) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTitle.isEmpty, var taskList = persisted.tasks else { return false }
        guard let index = taskList.firstIndex(where: { task in
            task.status == .open
                && (caseId == nil || task.caseId == caseId)
                && task.title.lowercased().contains(normalizedTitle)
        }) else { return false }
        taskList[index].status = .done
        taskList[index].updatedAt = .now
        let affectedCaseID = taskList[index].caseId
        persisted.tasks = taskList
        invalidateWorkspaceDerivedState()
        if let affectedCaseID, let caseIndex = persisted.cases.firstIndex(where: { $0.id == affectedCaseID }) {
            refreshCaseWorkspace(at: caseIndex)
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Task status changed locally",
                detail: "A task was marked done on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://task-status",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
        return true
    }

    func reportAIOutput(question: String, scopeCaseID: UUID?) {
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "AI output reported",
                detail: rossLocalized("privacy_ledger_ai_output_reported_detail"),
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://ai-output-report",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func snoozeTask(_ taskID: UUID, by days: Int) {
        guard var taskList = persisted.tasks, let index = taskList.firstIndex(where: { $0.id == taskID }) else { return }
        let currentDueDate = taskList[index].dueDate ?? .now
        taskList[index].dueDate = Calendar.current.date(byAdding: .day, value: days, to: currentDueDate)
        taskList[index].updatedAt = .now
        persisted.tasks = taskList
        invalidateWorkspaceDerivedState()
        persist(workspaceChanged: true)
    }

    func removeTask(_ taskID: UUID) {
        guard let task = (persisted.tasks ?? []).first(where: { $0.id == taskID }) else { return }
        persisted.tasks = (persisted.tasks ?? []).filter { $0.id != taskID }
        invalidateWorkspaceDerivedState()
        if let caseId = task.caseId, let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) {
            refreshCaseWorkspace(at: caseIndex)
        }
        persist(workspaceChanged: true)
    }

    func addMatterDate(
        caseId: UUID,
        title: String,
        kind: AlphaMatterDateKind,
        date: Date,
        notes: String? = nil
    ) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        let newDate = AlphaMatterDate(
            caseId: caseId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(kind.title),
            kind: kind,
            date: date,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        caseMatter.dates.insert(newDate, at: 0)
        if kind == .hearing {
            caseMatter.nextHearing = date
        }
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Matter date saved locally",
                detail: "\(newDate.title) was added on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://matter-date",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
    }

    func setMatterDateStatus(caseId: UUID, dateId: UUID, status: AlphaMatterDateStatus) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard let dateIndex = caseMatter.dates.firstIndex(where: { $0.id == dateId }) else { return }
        caseMatter.dates[dateIndex].status = status
        caseMatter.dates[dateIndex].updatedAt = .now
        if caseMatter.dates[dateIndex].kind == .hearing, status != .scheduled {
            let nextScheduledHearing = caseMatter.dates
                .filter { $0.kind == .hearing && $0.status == .scheduled }
                .map(\.date)
                .sorted()
                .first
            caseMatter.nextHearing = nextScheduledHearing
        }
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        persist(workspaceChanged: true)
    }

    func refreshCaseOverview(caseId: UUID) async {
        guard !refreshingCaseOverviewIDs.contains(caseId),
              let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }

        refreshingCaseOverviewIDs.insert(caseId)
        defer { refreshingCaseOverviewIDs.remove(caseId) }

        try? await Task.sleep(nanoseconds: 250_000_000)
        refreshCaseWorkspace(at: caseIndex)
        rebuildPreparedWork(reason: .afterDocumentImport, caseId: caseId, persistAfter: false)
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
        persist(workspaceChanged: true)
    }

    func recentDocumentItems(for caseId: UUID? = nil) -> [AlphaRecentDocumentItem] {
        ensureWorkspaceDerivedState()
        if let caseId {
            return workspaceDerivedState.recentDocumentItemsByCase[caseId] ?? []
        }
        return workspaceDerivedState.recentDocumentItems
    }

    func reviewQueue(caseId: UUID? = nil) -> [AlphaReviewQueueItem] {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.reviewQueue }
        return workspaceDerivedState.reviewQueueByCase[caseId] ?? []
    }

    func todayDateRows() -> [AlphaUpcomingDateRow] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.todayDateRows
    }

    func upcomingDateRows() -> [AlphaUpcomingDateRow] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.upcomingDateRows
    }
}

private extension AlphaPreparedWorkStatus {
    var sortRank: Int {
        switch self {
        case .new: 0
        case .reviewed: 1
        case .accepted: 2
        case .dismissed: 3
        }
    }
}

private func alphaPreparedFingerprint(parts: [String]) -> String {
    parts.joined(separator: "|")
}

private func alphaPreparedType(forExportKind kind: String) -> AlphaPreparedWorkType {
    switch kind {
    case "chronology_report":
        .chronologyReady
    case "order_summary":
        .orderSummaryReady
    case "case_note":
        .caseNoteReady
    default:
        .caseNoteReady
    }
}

private func sourceRefsFor(documentId: UUID, in matter: AlphaCaseMatter, fallback: [AlphaSourceRef]) -> [AlphaSourceRef] {
    let refs = matter.sourceRefs.filter { $0.documentId == documentId }
    return Array((refs.isEmpty ? fallback : refs).prefix(3))
}
