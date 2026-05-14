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

struct AlphaMatterTimelineRow: View {
    let entry: AlphaMatterTimelineEntry
    let onToggleTask: (AlphaTaskItem) -> Void
    let onSnoozeTask: (AlphaTaskItem) -> Void
    let onDeleteTask: (AlphaTaskItem) -> Void
    let onMarkDateDone: (AlphaMatterDate) -> Void
    let onCancelDate: (AlphaMatterDate) -> Void

    var body: some View {
        switch entry {
        case .date(let matterDate):
            AlphaMatterDateRow(
                matterDate: matterDate,
                onMarkDone: { onMarkDateDone(matterDate) },
                onCancel: { onCancelDate(matterDate) }
            )
        case .task(let task):
            AlphaTaskRow(
                task: task,
                onToggle: { onToggleTask(task) },
                onSnooze: task.status == .open ? { onSnoozeTask(task) } : nil
            )
            .contextMenu {
                if task.status == .open {
                    Button("Snooze by 1 day") {
                        onSnoozeTask(task)
                    }
                }
                Button("Delete task", role: .destructive) {
                    onDeleteTask(task)
                }
            }
        }
    }
}

enum AlphaMatterWorkspaceSection: String, CaseIterable, Identifiable {
    case documents
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents:
            "Documents"
        case .notes:
            "Notes"
        }
    }

    var systemImage: String {
        switch self {
        case .documents:
            "folder"
        case .notes:
            "note.text"
        }
    }
}

struct AlphaMatterSectionPicker: View {
    @Binding var selectedSection: AlphaMatterWorkspaceSection
    let fileCount: Int
    let taskCount: Int
    let noteCount: Int
    let draftCount: Int

    private func badge(for section: AlphaMatterWorkspaceSection) -> String? {
        switch section {
        case .documents:
            return "\(fileCount)"
        case .notes:
            let count = taskCount + noteCount + draftCount
            return count == 0 ? nil : "\(count)"
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AlphaMatterWorkspaceSection.allCases) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedSection = section
                        }
                    } label: {
                        AlphaMatterSectionChip(
                            title: section.title,
                            systemImage: section.systemImage,
                            badge: badge(for: section),
                            isSelected: selectedSection == section
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
    }
}

struct AlphaMatterSectionChip: View {
    let title: String
    let systemImage: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .imageScale(.small)

            Text(title)
                .font(.caption.weight(.semibold))

            if let badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((isSelected ? Color.rossGroupedBackground : Color.rossGlassSubtleFill).opacity(0.7), in: Capsule())
            }
        }
        .foregroundStyle(isSelected ? Color.rossGroupedBackground : Color.rossInk.opacity(0.74))
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(isSelected ? Color.rossAccent : Color.rossGlassSubtleFill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(isSelected ? Color.rossAccent.opacity(0.45) : Color.rossBorder.opacity(0.82), lineWidth: 1)
        }
    }
}

struct AlphaCaseWorkspaceScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var documentLayoutMode: AlphaDocumentLayoutMode = .grid
    @State private var expandedDocumentIDs: Set<UUID> = []
    @State private var showingImporter = false
    @State private var selectedSection: AlphaMatterWorkspaceSection = .documents
    @State private var filesExpanded = true
    @State private var timelineExpanded = true
    @State private var notesExpanded = true
    @State private var draftsExpanded = true

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    private var matterDates: [AlphaMatterDate] {
        model.scheduledMatterDates(for: caseId)
    }

    private var reviewItems: [AlphaReviewQueueItem] {
        model.reviewQueue(caseId: caseId)
    }

    var body: some View {
        ScrollView {
            if let caseMatter {
                let matterTasks = model.tasks(for: caseId)
                let openTaskCount = model.openTaskCount(for: caseId)
                let timelineEntries = alphaMatterTimelineEntries(dates: matterDates, tasks: matterTasks)
                // Single pass instead of two filter calls; sort the filtered slice.
                let matterExports = model.persisted.exports
                    .filter { $0.caseId == caseId }
                    .sorted { $0.createdAt > $1.createdAt }
                let draftCount = matterExports.count

                LazyVStack(alignment: .leading, spacing: 16) {
                    AlphaInlineHeader(
                        eyebrow: caseMatter.forum,
                        title: caseMatter.title,
                        detail: caseMatter.stage.title
                    )

                    RossSectionCard(title: "Ross Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(caseMatter.summary)
                                .rossBody()
                                .foregroundStyle(Color.rossInk.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            if let caseNumber = caseMatter.caseNumber, !caseNumber.isEmpty {
                                AlphaSettingsValueRow(label: "Case number", value: caseNumber)
                            }
                            if let partiesSummary = caseMatter.partiesSummary, !partiesSummary.isEmpty {
                                AlphaSettingsValueRow(label: "Parties", value: partiesSummary)
                            }
                            if let nextHearing = caseMatter.nextHearing {
                                AlphaSettingsValueRow(label: "Next hearing/deadline", value: nextHearing.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                    }

                    if !reviewItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaWorkspaceSectionLabel(title: "Needs Review", detail: "Accept, edit, or dismiss facts before Ross relies on them.")
                            ForEach(reviewItems.prefix(4)) { item in
                                AlphaReviewNudgeCard(
                                    item: item,
                                    onAccept: {
                                        alphaHaptic(.medium)
                                        model.acceptReviewQueueItem(item)
                                    },
                                    onEdit: {
                                        model.path.append(.documentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber))
                                    },
                                    onDismiss: {
                                        alphaHaptic(.medium)
                                        model.dismissReviewQueueItem(item)
                                    }
                                )
                            }
                        }
                    }

                    AlphaDisclosureCard(
                        title: "Suggested Next Steps",
                        badge: "\(caseMatter.draftTasks.count + openTaskCount + matterDates.count)",
                        isExpanded: $timelineExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(caseMatter.draftTasks, id: \.self) { task in
                                AlphaSummaryRow(title: task, detail: "Prepared locally")
                            }
                            ForEach(timelineEntries) { entry in
                                AlphaMatterTimelineRow(
                                    entry: entry,
                                    onToggleTask: { task in
                                        alphaHaptic(.light)
                                        model.toggleTaskDone(task.id)
                                    },
                                    onSnoozeTask: { task in model.snoozeTask(task.id, by: 1) },
                                    onDeleteTask: { task in model.removeTask(task.id) },
                                    onMarkDateDone: { matterDate in model.setMatterDateStatus(caseId: caseId, dateId: matterDate.id, status: .done) },
                                    onCancelDate: { matterDate in model.setMatterDateStatus(caseId: caseId, dateId: matterDate.id, status: .cancelled) }
                                )
                            }
                            if caseMatter.draftTasks.isEmpty && timelineEntries.isEmpty {
                                AlphaMatterCommandHintCard(
                                    detail: "Ask Ross to refresh this matter after importing real files.",
                                    actionSystemImage: "arrow.clockwise",
                                    actionLabel: "Refresh matter",
                                    actionDisabled: model.refreshingCaseOverviewIDs.contains(caseId),
                                    action: { Task { await model.refreshCaseOverview(caseId: caseId) } }
                                )
                            }
                        }
                    }

                    AlphaDisclosureCard(
                        title: "Drafts",
                        badge: draftCount == 0 ? nil : "\(draftCount)",
                        isExpanded: $draftsExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            if matterExports.isEmpty {
                                Text("No drafts generated yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.66))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(matterExports.prefix(4)) { export in
                                    Button {
                                        model.path.append(.exports(caseId))
                                    } label: {
                                        AlphaDraftPreviewRow(export: export)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            AlphaMatterCommandHintCard(
                                detail: "Ask Ross to prepare a chronology, case note, or order summary from local matter state.",
                                actionSystemImage: "bubble.right",
                                actionLabel: matterExports.isEmpty ? "Ask about this matter" : "Open drafts",
                                actionDisabled: false,
                                action: {
                                    if matterExports.isEmpty {
                                        model.openAsk(scopeCaseID: caseId)
                                    } else {
                                        model.path.append(.exports(caseId))
                                    }
                                }
                            )
                        }
                    }

                    AlphaDisclosureCard(
                        title: "File Room",
                        badge: "\(caseMatter.documents.count)",
                        isExpanded: $filesExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("\(alphaFileCountLabel(caseMatter.documents.count)) on this matter")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                Spacer(minLength: 0)
                                AlphaDocumentLayoutMenu(layoutMode: $documentLayoutMode)
                            }
                            if caseMatter.documents.isEmpty {
                                RossSectionCard {
                                    Text("Import the first real file for this matter.")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.rossInk.opacity(0.7))
                                }
                            } else {
                                AlphaDocumentCollectionView(
                                    documents: caseMatter.documents,
                                    caseTitle: nil,
                                    layoutMode: documentLayoutMode,
                                    expandedDocumentIDs: $expandedDocumentIDs,
                                    onOpen: { documentId in model.path.append(.documentViewer(caseId, documentId, 1)) },
                                    onMoveDocument: { documentId, offset in model.moveDocument(caseId: caseId, documentId: documentId, by: offset) },
                                    onOpenChat: { documentId in model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false) },
                                    onStartReviewChat: { documentId in model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: true) }
                                )
                            }
                            Button("Import document") {
                                showingImporter = true
                            }
                            .rossPrimaryButtonStyle()
                        }
                    }
                }
                .padding(alphaScreenPadding)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AlphaRootAskDock(
                model: model,
                fixedScopeCaseID: caseId,
                showsInlineResponseCard: true
            )
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 6)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image, .plainText],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result {
                Task { await model.importDocuments(caseId: caseId, from: urls) }
            }
        }
        .navigationTitle(caseMatter?.title ?? "Matter")
        .rossInlineNavigationTitle()
    }
}

struct AlphaMatterAttentionCard: View {
    let caseMatter: AlphaCaseMatter
    let matterTasks: [AlphaTaskItem]
    let reviewItems: [AlphaReviewQueueItem]
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onOpenReview: () -> Void
    @State private var isExpanded = false

    private var hasReview: Bool {
        !reviewItems.isEmpty
    }

    private var tint: Color {
        hasReview ? .orange : Color.rossAccent
    }

    private var eyebrow: String {
        hasReview ? "Needs review" : "Next action"
    }

    private var title: String {
        if hasReview {
            return reviewItems.count == 1 ? "1 item needs review" : "\(reviewItems.count) items need review"
        }
        if let firstOpenTask = matterTasks.first(where: { $0.status == .open }) {
            return firstOpenTask.title
        }
        if let firstDraftTask = caseMatter.draftTasks.first {
            return firstDraftTask
        }
        if caseMatter.documents.isEmpty {
            return "Import the first document"
        }
        return "Review the latest file"
    }

    private var reviewPreviewItems: [AlphaReviewQueueItem] {
        Array(reviewItems.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded && hasReview ? 10 : 0) {
            HStack(alignment: .center, spacing: 10) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundStyle(tint)

                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if hasReview {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.rossInk.opacity(0.48))
                } else {
                    Button(isRefreshing ? "Refreshing" : "Refresh", action: onRefresh)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if hasReview {
                    withAnimation(.snappy(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                }
            }

            if isExpanded && hasReview {
                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(reviewPreviewItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(tint)
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.rossInk)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color.rossInk.opacity(0.66))
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                Button {
                    onOpenReview()
                } label: {
                    Text("Open review")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.rossSecondaryGroupedBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.rossBorder.opacity(0.85), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.leading, 3)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(tint.opacity(hasReview ? 0.75 : 0.45))
                .frame(width: 2)
                .padding(.vertical, 10)
        }
        .background(Color.rossCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.86), lineWidth: 1)
        }
    }
}

struct AlphaMatterOverviewSummaryCard: View {
    let caseMatter: AlphaCaseMatter

    private var importantPoints: [String] {
        let source = !caseMatter.issueHighlights.isEmpty
            ? caseMatter.issueHighlights
            : (!caseMatter.evidenceNotes.isEmpty ? caseMatter.evidenceNotes : caseMatter.draftTasks)
        return Array(source.prefix(3))
    }

    var body: some View {
        RossSectionCard(title: "Latest summary") {
            VStack(alignment: .leading, spacing: 12) {
                if let nextHearing = caseMatter.nextHearing {
                    Text("Next hearing: \(nextHearing.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                }

                Text(caseMatter.summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.78))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                if !importantPoints.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.rossInk.opacity(0.52))

                        ForEach(Array(importantPoints.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.rossAccent)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)

                                Text(point)
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.76))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
