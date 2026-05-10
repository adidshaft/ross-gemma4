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

extension AlphaRossModel {

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
        let scope = scopeLabel(for: scopeCaseID)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "AI output reported",
                detail: "Feedback was saved for \(scope) without sending answer text or case files.",
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
