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

struct AlphaFeedScreen: View {
    @Bindable var model: AlphaRossModel
    @AppStorage("ross.matterListSortMode") private var storedSortModeRaw = AlphaCaseSortMode.recentlyViewed.rawValue
    @AppStorage("ross.matterListViewMode") private var storedViewModeRaw = AlphaMatterListViewMode.expanded.rawValue
    @State private var dueTodayExpanded = false
    @State private var upcomingExpanded = false
    @State private var reviewExpanded = true
    @State private var recentFilesExpanded = false
    @State private var matterSearchText = ""
    @State private var renameTarget: AlphaCaseMatter?
    @State private var renameDraft = ""
    @State private var deleteTarget: AlphaCaseMatter?

    private var sortMode: AlphaCaseSortMode {
        get { AlphaCaseSortMode(rawValue: storedSortModeRaw) ?? .recentlyViewed }
        nonmutating set { storedSortModeRaw = newValue.rawValue }
    }

    private var viewMode: AlphaMatterListViewMode {
        get { AlphaMatterListViewMode(rawValue: storedViewModeRaw) ?? .expanded }
        nonmutating set { storedViewModeRaw = newValue.rawValue }
    }

    private var sortedCases: [AlphaCaseMatter] {
        let cases = alphaSortedCases(for: sortMode, model: model)
        let query = matterSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cases }
        return cases.filter { caseMatter in
            [
                caseMatter.title,
                caseMatter.caseNumber ?? "",
                caseMatter.partiesSummary ?? "",
                caseMatter.forum,
                caseMatter.summary
            ]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var totalMatterCount: Int {
        model.cases.filter { $0.id != alphaSharedWorkspaceID }.count
    }

    var body: some View {
        let reviewItems = model.reviewQueue()
        let upcomingTasks = model.upcomingTasks()
        let todayTasks = model.todayTasks()
        let todayDates = model.todayDateRows()
        let upcomingDates = model.upcomingDateRows()
        let recentDocuments = model.recentDocumentItems()
        let attentionCount = todayDates.count + todayTasks.count + reviewItems.count
        let hasDueTodayItems = !todayDates.isEmpty || !todayTasks.isEmpty
        let hasUpcomingItems = !upcomingDates.isEmpty || !upcomingTasks.isEmpty
        let hasReviewItems = !reviewItems.isEmpty
        let hasRecentDocuments = !recentDocuments.isEmpty
        let hasAnyMatters = totalMatterCount > 0
        let hasVisibleMatters = !sortedCases.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                RossHeroCard(
                    eyebrow: alphaGreeting(),
                    title: alphaAttentionHeadline(attentionCount),
                    detail: !hasAnyMatters
                        ? "Add your first matter to start."
                        : attentionCount == 0
                        ? "All caught up for now."
                        : nil,
                    showsMedia: false,
                    mediaHeight: 108,
                    logoSize: 58
                ) {
                    if let activeJob = alphaActiveSetupJob(model) {
                        AlphaAssistantActivityStrip(
                            title: "Setting up your assistant",
                            detail: alphaAssistantActivityDetail(for: activeJob.state),
                            statusLabel: alphaAssistantStateLabel(activeJob.state),
                            tint: Color.rossAccent,
                            progressValue: alphaDownloadProgressValue(activeJob),
                            showsIndeterminateProgress: alphaDownloadShowsIndeterminateProgress(activeJob)
                        )
                    }
                }
                .animation(.snappy(duration: 0.28, extraBounce: 0.04), value: model.persisted.modelJobs.count)

                if !hasAnyMatters {
                        AlphaMatterStarterCard(model: model)
                }

                if hasDueTodayItems {
                    AlphaDisclosureCard(
                        title: "Today",
                        badge: "\(todayDates.count + todayTasks.count)",
                        isExpanded: $dueTodayExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(todayDates.prefix(3)), id: \.title) { row in
                                AlphaSummaryRow(title: row.title, detail: row.detail, tint: Color.rossAccent)
                            }
                                ForEach(Array(todayTasks.prefix(max(0, 4 - todayDates.count)))) { task in
                                AlphaTaskRow(task: task, onToggle: {
                                    alphaHaptic(.light)
                                    model.toggleTaskDone(task.id)
                                })
                            }
                        }
                    }
                }

                if totalMatterCount >= 5 {
                    AlphaMatterSearchField(text: $matterSearchText)
                }

                if hasVisibleMatters {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text(alphaMatterCountLabel(sortedCases.count))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.7))

                            Spacer(minLength: 0)

                            Menu {
                                ForEach(AlphaCaseSortMode.allCases) { option in
                                    Button(option.title) {
                                        sortMode = option
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(sortMode.shortTitle)
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(Color.rossInk)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.rossSecondaryGroupedBackground, in: Capsule())
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
                        }

                        if viewMode == .folder {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 122, maximum: 148), spacing: 14)],
                                alignment: .leading,
                                spacing: 16
                            ) {
                                ForEach(sortedCases) { caseMatter in
                                    Button {
                                        alphaHaptic(.selection)
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
                            LazyVStack(spacing: viewMode == .expanded ? 12 : 8) {
                                ForEach(sortedCases) { caseMatter in
                                    Button {
                                        alphaHaptic(.selection)
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

                if hasUpcomingItems {
                    AlphaDisclosureCard(
                        title: "Upcoming dates",
                        badge: "\(upcomingDates.count + upcomingTasks.count)",
                        isExpanded: $upcomingExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(upcomingDates.prefix(4)), id: \.title) { row in
                                AlphaSummaryRow(title: row.title, detail: row.detail)
                            }
                            ForEach(Array(upcomingTasks.prefix(2))) { task in
                                AlphaTaskRow(task: task, onToggle: {
                                    alphaHaptic(.light)
                                    model.toggleTaskDone(task.id)
                                })
                            }
                        }
                    }
                }

                if hasReviewItems {
                    AlphaDisclosureCard(
                        title: "Needs review",
                        badge: "\(reviewItems.count)",
                        isExpanded: $reviewExpanded
                    ) {
                    VStack(alignment: .leading, spacing: 10) {
                        AlphaWorkspaceSectionLabel(title: "Needs review", detail: "\(alphaReviewItemCountLabel(reviewItems.count)) from your files.")
                        ForEach(Array(reviewItems.prefix(4))) { item in
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
                } else if hasAnyMatters && !matterSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RossSectionCard {
                        Text("No matters match this search.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if hasRecentDocuments {
                    AlphaDisclosureCard(
                        title: "Recent files",
                        badge: "\(recentDocuments.count)",
                        isExpanded: $recentFilesExpanded
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
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
            .padding(alphaScreenPadding)
            .padding(.bottom, 24)
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
                alphaHaptic(.warning)
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

struct AlphaMatterSearchField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rossInk.opacity(0.5))
                .frame(width: 16)

            TextField("Search by matter, client, or case number", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.rossInk)
                .autocorrectionDisabled(true)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.34))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear matter search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .frame(minHeight: 50)
        .background(
            colorScheme == .dark ? Color.rossCardBackground.opacity(0.96) : Color.white.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
        }
        .shadow(
            color: colorScheme == .dark ? Color.clear : Color.rossShadow.opacity(0.06),
            radius: 10,
            y: 3
        )
    }
}

enum AlphaCaseSortMode: String, CaseIterable, Identifiable {
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

    var shortTitle: String {
        switch self {
        case .recentlyViewed:
            "Recent"
        case .lastAdded:
            "Added"
        case .earliestActionNeeded:
            "Urgent"
        }
    }
}

enum AlphaMatterListViewMode: String, CaseIterable, Identifiable {
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

enum AlphaDocumentLayoutMode: String, CaseIterable, Identifiable {
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

func alphaMatterCountLabel(_ count: Int) -> String {
    count == 1 ? "1 matter on this device" : "\(count) matters on this device"
}

func alphaActiveMatterLabel(_ count: Int) -> String {
    count == 1 ? "1 active matter" : "\(count) active matters"
}

func alphaFileCountLabel(_ count: Int) -> String {
    count == 1 ? "1 file" : "\(count) files"
}

func alphaDocumentCountLabel(_ count: Int) -> String {
    count == 1 ? "1 document" : "\(count) documents"
}

func alphaPageCountLabel(_ count: Int) -> String {
    count == 1 ? "1 page" : "\(count) pages"
}

func alphaReviewItemCountLabel(_ count: Int) -> String {
    count == 1 ? "1 review item" : "\(count) review items"
}

func alphaUpdateCountLabel(_ count: Int) -> String {
    count == 1 ? "1 update" : "\(count) updates"
}

func alphaMatterTintColor(_ tint: AlphaMatterTint) -> Color {
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

func alphaMatterTintTitle(_ tint: AlphaMatterTint) -> String {
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
