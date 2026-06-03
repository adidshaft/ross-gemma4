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
            RossGlassGroup(spacing: alphaSectionSpacing) {
                LazyVStack(alignment: .leading, spacing: alphaSectionSpacing) {
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
                            title: rossLocalized("setting_up_your_assistant"),
                            detail: alphaAssistantActivityDetail(for: activeJob.state),
                            statusLabel: alphaAssistantStateLabel(activeJob.state),
                            tint: Color.rossAccent,
                            progressValue: alphaDownloadProgressValue(activeJob),
                            showsIndeterminateProgress: alphaDownloadShowsIndeterminateProgress(activeJob)
                        )
                    } else if model.activePack == nil {
                        Button {
                            alphaHaptic(.selection)
                            model.path.append(.privateAISettings)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "brain")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.rossAccent)
                                    .frame(width: 32, height: 32)
                                    .rossNativeGlassSurface(
                                        tint: Color.rossAccent,
                                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                                        fallbackFillOpacity: 0.74,
                                        fallbackStrokeOpacity: 0.42
                                    )
                                    
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rossLocalized("setup_my_assistant"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)
                                    Text(rossLocalized("required_for_local_ai_tasks"))
                                        .font(.caption2)
                                        .foregroundStyle(Color.rossInk.opacity(0.66))
                                }
                                
                                Spacer(minLength: 0)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.rossInk.opacity(0.24))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .rossGlassSurface(cornerRadius: 14, interactive: true, strokeOpacity: 0.58)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
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
                                .rossNativeGlassSurface(
                                    tint: Color.rossAccent,
                                    shape: Capsule(),
                                    interactive: true,
                                    fallbackFillOpacity: 0.82,
                                    fallbackStrokeOpacity: 0.48
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(rossLocalized("sort_matters"))

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
                                    .rossGlassSurface(cornerRadius: 17, interactive: true, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2, strokeOpacity: 0.46)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(rossLocalized("choose_matter_view"))
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
                        title: rossLocalized("needs_review"),
                        badge: "\(reviewItems.count)",
                        isExpanded: $reviewExpanded
                    ) {
                    VStack(alignment: .leading, spacing: 10) {
                        AlphaWorkspaceSectionLabel(title: rossLocalized("needs_review"), detail: alphaReviewItemsFromFilesLabel(reviewItems.count))
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
                        Text(rossLocalized("no_matters_match_search"))
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if hasRecentDocuments {
                    AlphaDisclosureCard(
                        title: rossLocalized("recent_files"),
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
        }
        .rossHideNavigationBarIfSupported()
        .alert(rossLocalized("rename_matter"), isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField(rossLocalized("matter_name"), text: $renameDraft)
            Button(rossLocalized("save")) {
                if let renameTarget {
                    model.renameCase(renameTarget.id, title: renameDraft)
                }
                renameTarget = nil
            }
            Button(rossLocalized("cancel"), role: .cancel) {
                renameTarget = nil
            }
        } message: {
            Text(rossLocalized("rename_matter_detail"))
        }
        .alert(rossLocalized("delete_matter_question"), isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { caseMatter in
            Button(rossLocalized("delete"), role: .destructive) {
                alphaHaptic(.warning)
                model.deleteCase(caseMatter.id)
                deleteTarget = nil
            }
            Button(rossLocalized("cancel"), role: .cancel) {
                deleteTarget = nil
            }
        } message: { caseMatter in
            Text(alphaDeleteMatterDetail(caseMatter.title))
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

            TextField(rossLocalized("matter_search_placeholder"), text: $text)
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
                .accessibilityLabel(rossLocalized("clear_matter_search"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .frame(minHeight: 50)
        .rossGlassSurface(
            cornerRadius: 16,
            shadowOpacity: colorScheme == .dark ? 0 : 0.06,
            shadowRadius: 10,
            shadowY: 3,
            fillOpacity: colorScheme == .dark ? 0.90 : 0.78,
            strokeOpacity: 0.58
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

func alphaFilesInMatterLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("files_in_matter", languageCode: languageCode), alphaFileCountLabel(count))
}

func alphaFilesStoredForMatterLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("files_stored_for_matter", languageCode: languageCode), alphaFileCountLabel(count))
}

func alphaFilesOnMatterLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("files_on_matter", languageCode: languageCode), alphaFileCountLabel(count))
}

func alphaDocumentCountLabel(_ count: Int) -> String {
    count == 1 ? "1 document" : "\(count) documents"
}

func alphaPageCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    let key = count == 1 ? "page_count_one" : "page_count_many"
    return String(format: rossLocalized(key, languageCode: languageCode), count)
}

func alphaPageLabel(_ pageNumber: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("page_number", languageCode: languageCode), pageNumber)
}

func alphaReviewItemCountLabel(_ count: Int) -> String {
    count == 1 ? "1 review item" : "\(count) review items"
}

func alphaReviewItemsNeedAdvocateReviewLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("review_items_need_advocate_review", languageCode: languageCode), alphaReviewItemCountLabel(count))
}

func alphaResolveReviewItemsBeforeRelyingLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("review_items_resolve_before_relying", languageCode: languageCode), alphaReviewItemCountLabel(count))
}

func alphaReviewItemsNeedConfirmationBeforeFileUseLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("review_items_need_confirmation_before_file_use", languageCode: languageCode), alphaReviewItemCountLabel(count))
}

func alphaReviewExtractedLegalIssuesLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_review_extracted_legal_issues", languageCode: languageCode)
}

func alphaExtractionAvailableForMatterLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_extraction_available", languageCode: languageCode)
}

func alphaReviewUncertainExtractedFieldsLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_review_uncertain_fields", languageCode: languageCode)
}

func alphaImportFirstMatterDocumentLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_import_first_document", languageCode: languageCode)
}

func alphaOpenSourceChipsBeforeSharingLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_open_source_chips", languageCode: languageCode)
}

func alphaGenerateLocalDraftLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_generate_local_draft", languageCode: languageCode)
}

func alphaDocumentReadyForMatterChatLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("document_review_ready_for_matter_chat", languageCode: languageCode)
}

func alphaDocumentReviewUpdatedTitle(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("document_review_updated_for_title", languageCode: languageCode), title)
}

func alphaMatterChatUpdatedStatus(needsReview: Bool, languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized(
        needsReview ? "matter_chat_updated_needs_review" : "matter_chat_updated_ready",
        languageCode: languageCode
    )
}

func alphaMatterChatImportedFileStatus(hasReadableText: Bool, languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized(
        hasReadableText ? "matter_chat_updated_file_ready" : "matter_chat_updated_source_saved",
        languageCode: languageCode
    )
}

func alphaImportedDocumentLedgerDetail(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("privacy_ledger_document_imported_detail", languageCode: languageCode), title)
}

func alphaImportBatchLimitDetail(importedLimit: Int, skippedCount: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("document_import_batch_limit_detail", languageCode: languageCode), importedLimit, skippedCount)
}

func alphaFileAddedToMatterSection(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("file_added_to_matter_detail", languageCode: languageCode), title)
}

func alphaImportedFileAskReadyDetail(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("imported_file_ask_ready_detail", languageCode: languageCode)
}

func alphaImportedFileSourceSavedDetail(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("imported_file_source_saved_detail", languageCode: languageCode)
}

func alphaNextDateCapturedLabel(_ nextDate: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("document_review_next_date_captured", languageCode: languageCode), nextDate)
}

func alphaDocumentClassifiedSummary(
    documentTitle: String,
    typeTitle: String,
    legalFactSavingPaused: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(
        format: rossLocalized(
            legalFactSavingPaused ? "document_review_classified_paused" : "document_review_classified",
            languageCode: languageCode
        ),
        documentTitle,
        typeTitle
    )
}

func alphaDocumentFinishedRereadingSummary(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("document_review_finished_rereading", languageCode: languageCode), title)
}

func alphaMatterLocalNoticeNextDate(_ nextDate: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("matter_memory_local_notice_next_date", languageCode: languageCode), nextDate)
}

func alphaMatterReadyForFirstDocumentLabel(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("matter_memory_ready_for_first_document", languageCode: languageCode)
}

func alphaMatterDocumentsReadingSummary(documentCount: Int, readingCount: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("matter_memory_documents_reading_summary", languageCode: languageCode),
        alphaDocumentCountLabel(documentCount),
        readingCount
    )
}

func alphaMatterDocumentsReadSummary(documentCount: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("matter_memory_documents_read_summary", languageCode: languageCode),
        alphaDocumentCountLabel(documentCount)
    )
}

func alphaMatterReadyDocumentsLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("matter_memory_ready_documents", languageCode: languageCode), count)
}

func alphaMatterFileTypesSeenLabel(_ fileTypes: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("matter_memory_file_types_seen", languageCode: languageCode), fileTypes)
}

func alphaMatterNextDateCapturedLabel(_ date: Date, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("matter_memory_next_date_captured", languageCode: languageCode),
        date.formatted(date: .abbreviated, time: .omitted)
    )
}

func alphaMatterOpenTasksSavedLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("matter_memory_open_tasks_saved", languageCode: languageCode), count)
}

func alphaMatterLatestFileLabel(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("matter_memory_latest_file", languageCode: languageCode), title)
}

func alphaReviewItemsFromFilesLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("review_items_from_files", languageCode: languageCode), alphaReviewItemCountLabel(count))
}

func alphaDeleteMatterDetail(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("delete_matter_detail", languageCode: languageCode), title)
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
