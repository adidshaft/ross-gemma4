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

enum AlphaDockImportKind {
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

func alphaAskMentionTokenRange(in draft: String) -> Range<String.Index>? {
    draft.range(of: #"(?<!\S)@[^\s@]*$"#, options: .regularExpression)
}

func alphaAskMentionQuery(in draft: String) -> String? {
    guard let range = alphaAskMentionTokenRange(in: draft) else { return nil }
    return String(draft[range].dropFirst())
}

func alphaAskReplacingTrailingMention(in draft: String, with title: String) -> String {
    guard let range = alphaAskMentionTokenRange(in: draft) else { return draft }
    return draft.replacingCharacters(in: range, with: "@\(title) ")
}

func alphaAskMentionSuggestions(
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
            || document.fileName.localizedCaseInsensitiveContains(trimmedQuery)
            || document.displayTitle.localizedCaseInsensitiveContains(trimmedQuery)
            || document.caseTitle.localizedCaseInsensitiveContains(trimmedQuery)
    }
    return Array(matchingDocuments.prefix(limit))
}

func alphaAskPlaceholder(
    fixedDocumentCount: Int,
    hasActiveMatterScope: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    if fixedDocumentCount == 1 {
        return rossLocalized("ask_placeholder_file", languageCode: languageCode)
    }
    if hasActiveMatterScope {
        return rossLocalized("ask_placeholder_matter", languageCode: languageCode)
    }
    return rossLocalized("ask_placeholder_general", languageCode: languageCode)
}

func alphaAskCollapsedTitle(
    fixedDocumentCount: Int,
    hasActiveMatterScope: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    if fixedDocumentCount == 1 || hasActiveMatterScope {
        return alphaAskPlaceholder(
            fixedDocumentCount: fixedDocumentCount,
            hasActiveMatterScope: hasActiveMatterScope,
            languageCode: languageCode
        )
    }
    return rossLocalized("ask_collapsed_general", languageCode: languageCode)
}

func alphaAskSheetPlaceholder(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("ask_sheet_placeholder", languageCode: languageCode)
}

func alphaAskingAboutScopeLabel(_ scopeLabel: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("asking_about_scope", languageCode: languageCode), scopeLabel)
}

func alphaPublicLawPrivacyCountLabel(_ removedCount: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    if removedCount == 0 {
        return rossLocalized("zero_private_case_details_sent", languageCode: languageCode)
    }
    return String(format: rossLocalized("private_details_removed_zero_sent", languageCode: languageCode), removedCount)
}

func alphaRootAskEmptyFilesDetail(scopeIsShared: Bool, languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized(scopeIsShared ? "ask_empty_files_shared_detail" : "ask_empty_files_matter_detail", languageCode: languageCode)
}

func alphaRemoveAskSelectionLabel(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("remove_ask_selection", languageCode: languageCode), title)
}

struct AlphaRootAskDock: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    let fixedDocumentIDs: Set<UUID>
    let showsInlineResponseCard: Bool
    let collapsesWhenIdle: Bool
    @State private var showingTools = false
    @State private var dismissedInlineQuestion: String?
    @State private var pendingImportKind: AlphaDockImportKind?
    @State private var showingExpandedComposer = false
    @State private var dockExpanded = false
    @State private var pendingCollapseQuestion: String?
    @State private var composerResetToken = UUID()
    @State private var editingPublicLawQuery = false
    @State private var answerDetailsResult: AlphaAskResult?
    @State private var askPreflightUpgrade: AlphaAskPreflightUpgradePresentation?
    @State private var askPreflightDismissesExpandedComposer = false
    @FocusState private var dockComposerFocused: Bool

    init(
        model: AlphaRossModel,
        fixedScopeCaseID: UUID? = nil,
        fixedDocumentIDs: Set<UUID> = [],
        showsInlineResponseCard: Bool = true,
        collapsesWhenIdle: Bool = true
    ) {
        self.model = model
        self.fixedScopeCaseID = fixedScopeCaseID
        self.fixedDocumentIDs = fixedDocumentIDs
        self.showsInlineResponseCard = showsInlineResponseCard
        self.collapsesWhenIdle = collapsesWhenIdle
    }

    private var activeScopeCaseID: UUID? {
        fixedScopeCaseID ?? model.askSelectedScopeCaseID ?? model.selectedCaseID
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

    private var dockPrimaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.rossInk.opacity(0.84)
    }

    private var dockSecondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.rossInk.opacity(0.58)
    }

    private var dockMutedText: Color {
        colorScheme == .dark ? Color.white.opacity(0.52) : Color.rossInk.opacity(0.48)
    }

    private var dockBackdropTint: Color {
        colorScheme == .dark ? Color.rossBackdropGlow.opacity(0.12) : Color.white.opacity(0.62)
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
            return first.isShared ? alphaAskSharedFileSelectionLabel(first.title) : first.title
        }
        return alphaAskFilesSelectedLabel(selected.count)
    }

    private var activeDockActivity: (title: String, detail: String, status: String, progress: Double?)? {
        if model.publicLawSearchStatus == .reviewing && model.publicLawPreview != nil {
            return (
                rossLocalized("review_required"),
                rossLocalized("ask_legal_search_review_before_send_detail"),
                rossLocalized("review"),
                nil
            )
        }

        if model.publicLawSearchInFlight {
            return (
                rossLocalized("searching_legal_sources_ellipsis"),
                rossLocalized("ask_legal_search_clean_query_detail"),
                rossLocalized("searching"),
                nil
            )
        }

        return nil
    }

    private var publicLawModeTitle: String {
        if model.publicLawSearchStatus == .reviewing && model.publicLawPreview != nil {
            return rossLocalized("review_required")
        }
        return model.askWebEnabled ? rossLocalized("legal_search_on") : rossLocalized("local_only")
    }

    private var composerPlaceholder: String {
        alphaAskPlaceholder(
            fixedDocumentCount: fixedDocumentIDs.count,
            hasActiveMatterScope: activeScopeCaseID != nil
        )
    }

    private var collapsedDockTitle: String {
        alphaAskCollapsedTitle(
            fixedDocumentCount: fixedDocumentIDs.count,
            hasActiveMatterScope: activeScopeCaseID != nil
        )
    }

    private var showsCollapsedDock: Bool {
        collapsesWhenIdle &&
            !dockExpanded &&
            !showingTools &&
            !showingExpandedComposer &&
            draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func expandDock() {
        guard collapsesWhenIdle else { return }
        dockExpanded = true
    }

    private func collapseDock() {
        guard collapsesWhenIdle else { return }
        dockExpanded = false
    }

    private func clearDraft() {
        pendingCollapseQuestion = nil
        model.setAskDraft("", for: activeScopeCaseID)
        composerResetToken = UUID()
    }

    private func cancelDockEditing() {
        dockComposerFocused = false
        if !canSend {
            collapseDock()
        }
    }

    private func performSend(
        question: String,
        scopeCaseID: UUID?,
        webEnabled: Bool,
        dismissingExpandedComposer: Bool
    ) {
        alphaHaptic(.light)
        dockComposerFocused = false
        dismissedInlineQuestion = nil
        pendingCollapseQuestion = question
        model.setAskDraft("", for: scopeCaseID)
        composerResetToken = UUID()
        if dismissingExpandedComposer {
            showingExpandedComposer = false
        }
        Task { @MainActor in
            await Task.yield()
            model.setAskDraft("", for: scopeCaseID)
            composerResetToken = UUID()
            await model.submitDockInput(
                question: question,
                scopeCaseID: scopeCaseID,
                webEnabled: webEnabled
            )
            model.setAskDraft("", for: scopeCaseID)
            composerResetToken = UUID()
        }
    }

    private func send(dismissingExpandedComposer: Bool = false, skipPreflight: Bool = false) {
        let scopeCaseID = activeScopeCaseID
        let webEnabled = model.askWebEnabled
        let question = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if !fixedDocumentIDs.isEmpty {
            model.setSelectedAskDocumentIDs(fixedDocumentIDs, for: scopeCaseID)
        }
        if !skipPreflight,
           let preflight = model.localAskPreflightUpgrade(
            question: question,
            scopeCaseID: scopeCaseID,
            webEnabled: webEnabled
           ) {
            dockComposerFocused = false
            askPreflightUpgrade = preflight
            askPreflightDismissesExpandedComposer = dismissingExpandedComposer
            return
        }
        performSend(
            question: question,
            scopeCaseID: scopeCaseID,
            webEnabled: webEnabled,
            dismissingExpandedComposer: dismissingExpandedComposer
        )
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
        model.setAskDraft(alphaAskReplacingTrailingMention(in: draftText, with: document.displayTitle), for: activeScopeCaseID)
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        defer { pendingImportKind = nil }
        guard case let .success(urls) = result, !urls.isEmpty else { return }
        Task { await model.importDocuments(caseId: activeScopeCaseID, from: urls, openAfterImport: false) }
    }

    private var expandedDock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if fixedScopeCaseID == nil {
                    Menu {
                        Button(rossLocalized("all_work")) {
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
                            foregroundStyle: dockPrimaryText,
                            backgroundOpacity: colorScheme == .dark ? 0.1 : 0.16,
                            showsChevron: true
                        )
                    }
                } else {
                    AlphaAskScopePill(
                        title: model.scopeLabel(for: activeScopeCaseID),
                        foregroundStyle: dockPrimaryText,
                        backgroundOpacity: colorScheme == .dark ? 0.08 : 0.16,
                        statusSystemImage: "lock.fill",
                        showsChevron: false
                    )
                    .accessibilityHint(rossLocalized("ask_scoped_to_this_matter"))
                }

                Button {
                    model.askWebEnabled.toggle()
                } label: {
                    AlphaAskScopePill(
                        title: publicLawModeTitle,
                        foregroundStyle: model.askWebEnabled ? dockPrimaryText : dockSecondaryText,
                        backgroundOpacity: colorScheme == .dark ? 0.08 : 0.14,
                        statusSystemImage: "globe",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
            }

            if !activeSelectedDocuments.isEmpty, fixedDocumentIDs.count != 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeSelectedDocuments) { document in
                            AlphaAskSelectionChip(
                                title: document.displayTitle,
                                detail: activeScopeCaseID == nil ? (document.isShared ? "shared" : document.caseTitle) : (document.isShared ? "shared" : nil),
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

            RossGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 9) {
                        Button {
                            dockComposerFocused = false
                            showingTools = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.callout.weight(.bold))
                                .imageScale(.small)
                                .foregroundStyle(dockPrimaryText.opacity(0.82))
                                .frame(width: 36, height: 36)
                                .rossNativeGlassSurface(
                                    tint: Color.rossHighlight,
                                    shape: Circle(),
                                    interactive: true,
                                    fallbackFillOpacity: colorScheme == .dark ? 0.58 : 0.78,
                                    fallbackStrokeOpacity: 0.52
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(rossLocalized("add_to_ask_ross"))

                        ZStack(alignment: .leading) {
                            if draftText.isEmpty {
                                Text(composerPlaceholder)
                                    .font(.body)
                                    .foregroundStyle(dockPrimaryText.opacity(0.42))
                                    .lineLimit(1)
                            }

                            TextField("", text: draftBinding, axis: .vertical)
                                .id(composerResetToken)
                                .lineLimit(1...2)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundStyle(dockPrimaryText)
                                .focused($dockComposerFocused)
                                .submitLabel(.send)
                                .onSubmit {
                                    if canSend {
                                        send()
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !draftText.isEmpty {
                            Button(action: clearDraft) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body.weight(.semibold))
                                    .imageScale(.medium)
                                    .foregroundStyle(dockMutedText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(rossLocalized("clear_ask_ross_text"))
                        }
                    }
                    .padding(.leading, 7)
                    .padding(.trailing, 13)
                    .padding(.vertical, 5)
                    .rossNativeGlassSurface(
                        tint: Color.rossHighlight,
                        shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: colorScheme == .dark ? 0.76 : 0.86,
                        fallbackStrokeOpacity: 0.52
                    )
                    .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.10 : 0.04), radius: 5, y: 1)

                    AlphaAskDockSendButton(
                        canSend: canSend,
                        onSend: { send() },
                        onCancel: cancelDockEditing
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dockComposerFocused = true
            }

            if !mentionSuggestions.isEmpty {
                AlphaAskMentionSuggestionsCard(
                    documents: mentionSuggestions,
                    scopeCaseID: activeScopeCaseID,
                    tone: .dock,
                    onSelect: applyMention
                )
            }

            if fixedDocumentIDs.isEmpty, let activeScopeCaseID {
                Text(alphaAskingAboutScopeLabel(model.scopeLabel(for: activeScopeCaseID)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(dockSecondaryText)
            } else if let selectionSubtitle, fixedDocumentIDs.isEmpty {
                Text(selectionSubtitle)
                    .font(.caption2)
                    .foregroundStyle(dockSecondaryText)
            } else if fixedDocumentIDs.isEmpty {
                Text(rossLocalized("ask_attach_or_command_hint"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(dockMutedText)
            }

            if model.askWebEnabled {
                Text(rossLocalized("ask_legal_search_clean_query_detail"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(dockSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .rossNativeGlassSurface(
            tint: dockBackdropTint,
            shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
            fallbackFillOpacity: colorScheme == .dark ? 0.78 : 0.86,
            fallbackStrokeOpacity: colorScheme == .dark ? 0.22 : 0.70
        )
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.12 : 0.055), radius: colorScheme == .dark ? 11 : 7, y: colorScheme == .dark ? 5 : 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let activity = activeDockActivity {
                AlphaDockActivityBar(
                    title: activity.title,
                    detail: activity.detail,
                    progressValue: activity.progress
                )
                .transition(.opacity)
            }

            if let inlineResult, !dockComposerFocused {
                AlphaInlineAskResponseCard(
                    result: inlineResult,
                    contextDocumentTitle: fixedDocumentIDs.count == 1 ? activeSelectedDocuments.first?.title : nil,
                    onOpenSource: model.openSourceRef,
                    onShowDetails: { answerDetailsResult = $0 },
                    onRetryUpgrade: { model.retryAskWithUpgrade($0) },
                    canRetryUpgrade: model.canRetryAskWithUpgrade(inlineResult),
                    onOpenConversation: {
                        if fixedDocumentIDs.count == 1, let documentID = fixedDocumentIDs.first {
                            model.openAsk(scopeCaseID: activeScopeCaseID, documentID: documentID)
                        } else {
                            model.openAsk(scopeCaseID: activeScopeCaseID)
                        }
                    },
                    onClose: { dismissedInlineQuestion = inlineResult.question }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showsCollapsedDock {
                Button(action: expandDock) {
                    AlphaCollapsedAskDockPill(title: collapsedDockTitle)
                }
                .buttonStyle(.plain)
            } else {
                expandedDock
            }
        }
        .alphaDismissesKeyboardOnScroll()
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
        .sheet(
            isPresented: Binding(
                get: { answerDetailsResult != nil },
                set: { if !$0 { answerDetailsResult = nil } }
            )
        ) {
            if let answerDetailsResult {
                AlphaAnswerDetailsSheet(
                    result: answerDetailsResult,
                    contextDocumentTitle: fixedDocumentIDs.count == 1 ? activeSelectedDocuments.first?.title : nil,
                    onOpenSource: model.openSourceRef
                )
                    .presentationDetents([.height(320), .medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { pendingImportKind != nil },
                set: { if !$0 { pendingImportKind = nil } }
            ),
            allowedContentTypes: pendingImportKind?.allowedTypes ?? [.pdf, .plainText, .image],
            allowsMultipleSelection: true,
            onCompletion: handleImport
        )
        .sheet(isPresented: Binding(
            get: { !showingExpandedComposer && model.publicLawPreview != nil && model.pendingPublicLawQuestion != nil },
            set: { if !$0 { model.cancelPendingPublicLawSearch() } }
        )) {
            if let preview = model.publicLawPreview {
                NavigationStack {
                    ScrollView {
                        RossGlassGroup(spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(rossLocalized("review_legal_search"))
                                    .font(.title3.weight(.semibold))
                                Text(rossLocalized("review_legal_search_detail"))
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(rossLocalized("query_to_be_sent"))
                                        .font(.subheadline.weight(.semibold))
                                    if editingPublicLawQuery {
                                        TextEditor(text: Binding(
                                            get: { model.publicLawPreview?.query ?? "" },
                                            set: { model.updatePendingPublicLawQuery($0) }
                                        ))
                                        .font(.callout.weight(.medium))
                                        .frame(minHeight: 96)
                                        .padding(8)
                                        .rossNativeGlassSurface(
                                            tint: Color.rossAccent,
                                            shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                                            interactive: true,
                                            fallbackFillOpacity: 0.84,
                                            fallbackStrokeOpacity: 0.48
                                        )
                                        .shadow(color: Color.rossShadow.opacity(0.04), radius: 4, y: 1)
                                    } else {
                                        Text(preview.query)
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(Color.rossInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .rossNativeGlassSurface(
                                                tint: Color.rossAccent,
                                                shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                                                fallbackFillOpacity: 0.84,
                                                fallbackStrokeOpacity: 0.48
                                            )
                                    }
                                }

                                Text(alphaPublicLawPrivacyCountLabel(alphaPublicLawRemovedReasonsContainOnlyNoPrivateData(preview.removed) ? 0 : preview.removed.count))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rossInk.opacity(0.62))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .rossNativeGlassSurface(
                                        tint: Color.rossAccent,
                                        shape: Capsule(),
                                        fallbackFillOpacity: 0.84,
                                        fallbackStrokeOpacity: 0.42
                                    )

                                if model.publicLawSearchInFlight {
                                    ProgressView(rossLocalized("searching_legal_sources_ellipsis"))
                                        .progressViewStyle(.circular)
                                        .tint(Color.rossAccent)
                                        .font(.footnote.weight(.medium))
                                }
                            }
                            .padding(alphaScreenPadding)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        RossGlassGroup(spacing: 10) {
                            HStack(spacing: 10) {
                                Button(rossLocalized("cancel")) {
                                    model.cancelPendingPublicLawSearch()
                                }
                                .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16, expandsHorizontally: false)

                                Spacer(minLength: 0)

                                Button(rossLocalized("send")) {
                                    Task { await model.confirmPendingPublicLawSearch() }
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16, expandsHorizontally: false)
                                .disabled(model.publicLawSearchInFlight || (model.publicLawPreview?.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
                            }
                        }
                        .padding(12)
                        .rossNativeGlassSurface(
                            tint: Color.rossHighlight,
                            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                            fallbackFillOpacity: 0.82,
                            fallbackStrokeOpacity: 0.52
                        )
                        .shadow(color: Color.rossShadow.opacity(0.08), radius: 10, y: 4)
                    }
                    .padding(alphaScreenPadding)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
            }
        }
        .alert(
            rossLocalized("ask_preflight_upgrade_title"),
            isPresented: Binding(
                get: { askPreflightUpgrade != nil },
                set: {
                    if !$0 {
                        askPreflightUpgrade = nil
                        askPreflightDismissesExpandedComposer = false
                    }
                }
            )
        ) {
            Button(rossLocalized("ask_preflight_continue_local")) {
                let dismissesExpandedComposer = askPreflightDismissesExpandedComposer
                askPreflightUpgrade = nil
                askPreflightDismissesExpandedComposer = false
                send(
                    dismissingExpandedComposer: dismissesExpandedComposer,
                    skipPreflight: true
                )
            }
            if let askPreflightUpgrade {
                Button(alphaAskUpgradeActionTitle(
                    askPreflightUpgrade.upgradeTierHint,
                    runtimeMode: askPreflightUpgrade.upgradeRuntimeHint
                )) {
                    let preflight = askPreflightUpgrade
                    let dismissesExpandedComposer = askPreflightDismissesExpandedComposer
                    self.askPreflightUpgrade = nil
                    askPreflightDismissesExpandedComposer = false
                    if dismissesExpandedComposer {
                        showingExpandedComposer = false
                    }
                    if model.applyAskPreflightUpgradeIfAvailable(preflight) {
                        send(
                            dismissingExpandedComposer: dismissesExpandedComposer,
                            skipPreflight: true
                        )
                    } else {
                        model.openAskUpgradeSetup(for: preflight)
                    }
                }
            }
            Button(rossLocalized("cancel"), role: .cancel) {
                askPreflightUpgrade = nil
                askPreflightDismissesExpandedComposer = false
            }
        } message: {
            if let askPreflightUpgrade {
                Text(askPreflightUpgrade.messageText())
            }
        }
        .onChange(of: draftText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, collapsesWhenIdle, !dockExpanded {
                expandDock()
            } else if trimmed.isEmpty,
                      collapsesWhenIdle,
                      pendingCollapseQuestion == nil,
                      !showingTools,
                      !showingExpandedComposer {
                collapseDock()
            }
        }
        .onChange(of: model.latestAskResult) { _, latestResult in
            guard let latestResult else { return }
            guard pendingCollapseQuestion == latestResult.question else { return }
            guard latestResult.scopeCaseID == activeScopeCaseID else { return }
            pendingCollapseQuestion = nil
            collapseDock()
        }
    }
}

struct AlphaCollapsedAskDockPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    private var dockBackdropTint: Color {
        colorScheme == .dark ? Color.rossBackdropGlow.opacity(0.12) : Color.white.opacity(0.62)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.rossInk.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .imageScale(.small)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.48) : Color.rossInk.opacity(0.42))
                .frame(width: 22, height: 22)
        }
        .padding(.leading, 15)
        .padding(.trailing, 10)
        .frame(height: 44)
        .contentShape(Capsule())
        .rossNativeGlassSurface(
            tint: dockBackdropTint,
            shape: Capsule(),
            fallbackFillOpacity: colorScheme == .dark ? 0.82 : 0.88,
            fallbackStrokeOpacity: colorScheme == .dark ? 0.18 : 0.72
        )
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.10 : 0.045), radius: 7, y: 2)
    }
}

struct AlphaDockActivityPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let detail: String
    let statusLabel: String
    let progressValue: Double?

    private var clampedProgress: Double? {
        progressValue.map { min(max($0, 0), 1) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            AlphaStaticActivityGlyph(progressValue: clampedProgress)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.rossInk.opacity(0.82))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.58) : Color.rossInk.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(statusLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.rossAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .rossNativeGlassSurface(
                    tint: Color.rossAccent,
                    shape: Capsule(),
                    fallbackFillOpacity: colorScheme == .dark ? 0.74 : 0.68,
                    fallbackStrokeOpacity: 0.36
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackFillOpacity: 0.78,
            fallbackStrokeOpacity: 0.44
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

struct AlphaDockActivityBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let detail: String
    let progressValue: Double?

    var body: some View {
        HStack(spacing: 9) {
            AlphaStaticActivityGlyph(progressValue: progressValue.map { min(max($0, 0), 1) })

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.rossInk.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .layoutPriority(2)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.58) : Color.rossInk.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: Capsule(),
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.48
        )
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.08 : 0.035), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }
}

struct AlphaStaticActivityGlyph: View {
    let progressValue: Double?

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.rossAccent.opacity(0.12))
                .frame(width: 46, height: 6)

            if let progressValue {
                Capsule()
                    .fill(Color.rossAccent.opacity(0.74))
                    .frame(width: max(6, 46 * min(max(progressValue, 0), 1)), height: 6)
            } else {
                Capsule()
                    .fill(Color.rossAccent.opacity(0.54))
                    .frame(width: 14, height: 6)
            }
        }
        .frame(width: 46, height: 16)
        .accessibilityHidden(true)
    }
}

private struct AlphaAskDockSendButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let canSend: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            if canSend {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(Font.body.weight(.bold))
                        .imageScale(.small)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.rossAccent)
                .accessibilityLabel(rossLocalized("send_ask_ross_question"))
            } else {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(Font.callout.weight(.bold))
                        .imageScale(.small)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)
                .tint(Color.rossHighlight)
                .accessibilityLabel(rossLocalized("close_ask_ross"))
            }
        } else {
            Button {
                if canSend {
                    onSend()
                } else {
                    onCancel()
                }
            } label: {
                Image(systemName: canSend ? "arrow.up" : "xmark")
                    .font((canSend ? Font.body : Font.callout).weight(.bold))
                    .imageScale(.small)
                    .foregroundStyle(canSend ? (colorScheme == .dark ? Color.rossGroupedBackground : Color.rossCardBackground) : Color.rossInk.opacity(0.82))
                    .frame(width: 36, height: 36)
                    .background {
                        if canSend {
                            Circle().fill(Color.rossAccent.opacity(0.92))
                        }
                    }
                    .rossNativeGlassSurface(
                        tint: canSend ? Color.rossAccent : Color.rossHighlight,
                        shape: Circle(),
                        interactive: true,
                        fallbackFillOpacity: canSend ? 0.88 : (colorScheme == .dark ? 0.58 : 0.78),
                        fallbackStrokeOpacity: canSend ? 0.24 : 0.52
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(canSend ? rossLocalized("send_ask_ross_question") : rossLocalized("close_ask_ross"))
        }
    }
}

struct AlphaInlineAskResponseCard: View {
    let result: AlphaAskResult
    let contextDocumentTitle: String?
    let onOpenSource: (AlphaSourceRef) -> Void
    let onShowDetails: (AlphaAskResult) -> Void
    let onRetryUpgrade: (AlphaAskResult) -> Void
    let canRetryUpgrade: Bool
    let onOpenConversation: () -> Void
    let onClose: () -> Void

    private var responseActions: [AlphaInlineAskResponseAction] {
        result.inlineResponseActions(canRetryUpgrade: canRetryUpgrade)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if result.isPendingLocalModelResponse {
                AlphaPendingLocalModelCard(
                    result: result,
                    style: .compact
                )
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.answerTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(2)

                        if let note = result.statusNote {
                            Text(note)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.rossAccent)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let continuationContext = result.answerContinuationContext {
                            AlphaAnswerContinuationContextRow(context: continuationContext)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 8)
                    Menu {
                        ForEach(responseActions, id: \.rawValue) { action in
                            inlineActionButton(action)
                        }
                    } label: {
                        AlphaInlineAskResponseAccessoryLabel(systemImage: "ellipsis")
                    }
                    .accessibilityLabel(rossLocalized("more_answer_actions"))
                }

                ForEach(result.answerSectionItems(limit: 2)) { section in
                    Text(section.text)
                        .font(.footnote)
                        .lineSpacing(4)
                        .foregroundStyle(Color.rossInk.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !result.caseFileSources.isEmpty {
                    AlphaSourceRefChips(
                        sourceRefs: Array(result.caseFileSources.prefix(2)),
                        contextDocumentTitle: contextDocumentTitle,
                        onOpenSourceRef: onOpenSource
                    )
                }

                HStack {
                    Spacer()
                    Button(rossLocalized("view_full_answer"), action: onOpenConversation)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }
            }
        }
        .padding(14)
        .rossNativeGlassSurface(
            tint: Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallbackFillOpacity: 0.76,
            fallbackStrokeOpacity: 0.40
        )
        .shadow(color: Color.rossShadow.opacity(0.035), radius: 5, y: 1)
        .contextMenu {
            ForEach(responseActions, id: \.rawValue) { action in
                inlineActionButton(action)
            }
        }
        .accessibilityActions {
            ForEach(responseActions, id: \.rawValue) { action in
                Button(accessibilityTitle(for: action)) {
                    perform(action)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 0 {
                        withAnimation {
                            onClose()
                        }
                    }
                }
        )
    }

    private func perform(_ action: AlphaInlineAskResponseAction) {
        switch action {
        case .retryUpgrade:
            onRetryUpgrade(result)
        case .answerDetails:
            onShowDetails(result)
        case .copyAnswer:
            alphaCopyAskResultToPasteboard(result)
        case .dismiss:
            onClose()
        }
    }

    @ViewBuilder
    private func inlineActionButton(_ action: AlphaInlineAskResponseAction) -> some View {
        switch action {
        case .retryUpgrade:
            Button {
                perform(.retryUpgrade)
            } label: {
                Label(
                    alphaAskRetryUpgradeActionTitle(
                        result.upgradeTierHint,
                        runtimeMode: result.upgradeRuntimeHint
                    ),
                    systemImage: "arrow.clockwise"
                )
            }
        case .answerDetails:
            Button {
                perform(.answerDetails)
            } label: {
                Label(rossLocalized("answer_details"), systemImage: "info.circle")
            }
        case .copyAnswer:
            Button {
                perform(.copyAnswer)
            } label: {
                Label(rossLocalized("copy_answer"), systemImage: "doc.on.doc")
            }
        case .dismiss:
            Button(role: .destructive) {
                perform(.dismiss)
            } label: {
                Label(rossLocalized("dismiss"), systemImage: "xmark")
            }
        }
    }

    private func accessibilityTitle(for action: AlphaInlineAskResponseAction) -> String {
        switch action {
        case .retryUpgrade:
            alphaAskRetryUpgradeActionTitle(
                result.upgradeTierHint,
                runtimeMode: result.upgradeRuntimeHint
            )
        case .answerDetails:
            rossLocalized("answer_details")
        case .copyAnswer:
            rossLocalized("copy_answer")
        case .dismiss:
            rossLocalized("dismiss")
        }
    }
}

enum AlphaInlineAskResponseAction: String {
    case retryUpgrade
    case answerDetails
    case copyAnswer
    case dismiss
}

extension AlphaAskResult {
    func inlineResponseActions(canRetryUpgrade: Bool = false) -> [AlphaInlineAskResponseAction] {
        var actions: [AlphaInlineAskResponseAction] = []
        if canRetryUpgrade {
            actions.append(.retryUpgrade)
        }
        if hasAnswerDetails {
            actions.append(.answerDetails)
        }
        actions.append(.copyAnswer)
        actions.append(.dismiss)
        return actions
    }
}

private struct AlphaInlineAskResponseAccessoryLabel: View {
    let systemImage: String

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            icon(foregroundOpacity: 0.62)
                .glassEffect(.regular.interactive())
                .tint(Color.rossHighlight)
        } else {
            icon(foregroundOpacity: 0.45)
                .rossNativeGlassSurface(
                    tint: Color.rossHighlight,
                    shape: Circle(),
                    interactive: true,
                    fallbackFillOpacity: 0.68,
                    fallbackStrokeOpacity: 0.36
                )
        }
    }

    private func icon(foregroundOpacity: Double) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.rossInk.opacity(foregroundOpacity))
            .frame(width: 32, height: 32)
    }
}

private struct AlphaInlineAskResponseAccessoryButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                AlphaInlineAskResponseAccessoryLabel(systemImage: systemImage)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                AlphaInlineAskResponseAccessoryLabel(systemImage: systemImage)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}

struct AlphaAskScopePill: View {
    let title: String
    let foregroundStyle: Color
    let backgroundOpacity: Double
    var statusSystemImage: String? = nil
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 5) {
            if let statusSystemImage {
                Image(systemName: statusSystemImage)
                    .font(.caption2.weight(.bold))
            }

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .layoutPriority(1)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, AlphaAskPillMetrics.horizontalPadding)
        .frame(height: AlphaAskPillMetrics.height)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: Capsule(),
            interactive: showsChevron,
            fallbackFillOpacity: backgroundOpacity,
            fallbackStrokeOpacity: 0.38
        )
        .contentShape(Capsule())
    }
}

enum AlphaAskSurfaceTone {
    case dock
    case sheet
}

enum AlphaAskPillMetrics {
    static let height: CGFloat = 36
    static let horizontalPadding: CGFloat = 11
    static let cornerRadius: CGFloat = 18
}

struct AlphaAskSelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let detail: String?
    let isShared: Bool
    let tone: AlphaAskSurfaceTone
    let onRemove: (() -> Void)?

    init(
        title: String,
        detail: String? = nil,
        isShared: Bool,
        tone: AlphaAskSurfaceTone = .dock,
        onRemove: (() -> Void)?
    ) {
        self.title = title
        self.detail = detail
        self.isShared = isShared
        self.tone = tone
        self.onRemove = onRemove
    }

    var body: some View {
        let dockForeground = colorScheme == .dark ? Color.white.opacity(0.76) : Color.rossInk.opacity(0.82)
        let dockDetail = colorScheme == .dark ? Color.white.opacity(0.46) : Color.rossInk.opacity(0.46)
        HStack(spacing: 8) {
            Group {
                if isShared {
                    RossGlassIconView(.earth, variant: .highlight, size: 12, fallbackSystemImage: "globe")
                } else {
                    RossGlassIconView(.folder, variant: .neutral, size: 12, fallbackSystemImage: "folder.fill")
                }
            }
            .frame(width: 18, height: 18)

            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Circle()
                        .fill(tone == .dock ? dockDetail.opacity(0.6) : Color.rossInk.opacity(0.18))
                        .frame(width: 3, height: 3)

                    Text(detail)
                        .lineLimit(1)
                        .foregroundStyle(tone == .dock ? dockDetail : Color.rossInk.opacity(0.46))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tone == .dock ? dockDetail : Color.rossInk.opacity(0.32))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(alphaRemoveAskSelectionLabel(title))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone == .dock ? dockForeground : Color.rossInk.opacity(0.82))
        .padding(.horizontal, AlphaAskPillMetrics.horizontalPadding)
        .frame(height: AlphaAskPillMetrics.height)
        .rossNativeGlassSurface(
            tint: tone == .dock ? Color.rossHighlight : Color.rossAccent.opacity(0.10),
            shape: Capsule(),
            fallbackFillOpacity: tone == .dock ? 0.68 : 0.78,
            fallbackStrokeOpacity: tone == .dock ? 0.48 : 0.56
        )
        .shadow(color: Color.rossShadow.opacity(tone == .dock ? 0.025 : 0.02), radius: 3, y: 1)
    }
}

struct AlphaAskSuggestionBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let tone: AlphaAskSurfaceTone

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(
                tone == .dock
                    ? (colorScheme == .dark ? Color.white.opacity(0.74) : Color.rossAccent.opacity(0.82))
                    : Color.rossAccent.opacity(0.86)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .rossNativeGlassSurface(
                tint: tone == .dock ? Color.rossHighlight : Color.rossAccent,
                shape: Capsule(),
                fallbackFillOpacity: tone == .dock ? 0.56 : 0.64,
                fallbackStrokeOpacity: 0.36
            )
    }
}

struct AlphaAskMentionSuggestionsCard: View {
    @Environment(\.colorScheme) private var colorScheme
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
        RossGlassGroup(spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(8)
        .rossNativeGlassSurface(
            tint: tone == .dock ? Color.rossHighlight : Color.rossAccent.opacity(0.10),
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackFillOpacity: tone == .dock ? 0.74 : 0.82,
            fallbackStrokeOpacity: tone == .dock ? 0.52 : 0.58
        )
        .shadow(color: Color.rossShadow.opacity(tone == .dock ? 0.045 : 0.055), radius: 6, y: 2)
    }
}

struct AlphaAskMentionSuggestionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let document: AlphaAskDocumentOption
    let scopeCaseID: UUID?
    let tone: AlphaAskSurfaceTone

    var body: some View {
        let icon = alphaDocumentGlassIcon(document.kind)
        let dockPrimary = colorScheme == .dark ? Color.white.opacity(0.88) : Color.rossInk.opacity(0.9)
        let dockSecondary = colorScheme == .dark ? Color.white.opacity(0.52) : Color.rossInk.opacity(0.56)

        HStack(spacing: 10) {
            RossGlassIconView(icon.0, variant: icon.1, size: 16, fallbackSystemImage: icon.2)
                .frame(width: 26, height: 26)
                .rossNativeGlassSurface(
                    tint: tone == .dock ? Color.rossHighlight : Color.rossAccent,
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    fallbackFillOpacity: tone == .dock ? 0.54 : 0.66,
                    fallbackStrokeOpacity: tone == .dock ? 0.34 : 0.42
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(document.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone == .dock ? dockPrimary : Color.rossInk.opacity(0.9))
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                Text(document.compactDetail(scopeCaseID: scopeCaseID))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(tone == .dock ? dockSecondary : Color.rossInk.opacity(0.56))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AlphaAskSuggestionBadge(title: document.badgeTitle, tone: tone)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .rossNativeGlassSurface(
            tint: tone == .dock ? Color.rossHighlight : Color.rossAccent.opacity(0.18),
            shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
            interactive: true,
            fallbackFillOpacity: tone == .dock ? 0.70 : 0.78,
            fallbackStrokeOpacity: tone == .dock ? 0.46 : 0.54
        )
    }
}

struct AlphaAskComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    let fixedDocumentIDs: Set<UUID>
    let onSelectMention: (AlphaAskDocumentOption) -> Void
    let onRemoveDocumentSelection: (UUID) -> Void
    let onSend: () -> Void
    @FocusState private var composerFocused: Bool

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

    private func hideKeyboard() {
        composerFocused = false
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rossLocalized("ask_ross"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(rossLocalized("type_at_to_add_file"))
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button(rossLocalized("done")) {
                        if composerFocused {
                            hideKeyboard()
                        } else {
                            dismiss()
                        }
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, expandsHorizontally: false)
                }

                HStack(spacing: 10) {
                    if fixedScopeCaseID == nil {
                        Menu {
                            Button(rossLocalized("all_work")) {
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
                            statusSystemImage: "lock.fill",
                            showsChevron: false
                        )
                    }

                    Button {
                        model.askWebEnabled.toggle()
                    } label: {
                        AlphaAskScopePill(
                            title: model.askWebEnabled ? rossLocalized("legal_search_on") : rossLocalized("local_only"),
                            foregroundStyle: model.askWebEnabled ? Color.rossHighlight : Color.rossInk.opacity(0.78),
                            backgroundOpacity: 0.08,
                            statusSystemImage: "globe",
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !activeSelectedDocuments.isEmpty, fixedDocumentIDs.count != 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeSelectedDocuments) { document in
                                AlphaAskSelectionChip(
                                    title: document.displayTitle,
                                    detail: activeScopeCaseID == nil ? (document.isShared ? "shared" : document.caseTitle) : (document.isShared ? "shared" : nil),
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
                    if draftText.isEmpty {
                        Text(alphaAskSheetPlaceholder())
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.34))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                    }

                    TextEditor(text: draftBinding)
                        .scrollContentBackground(.hidden)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk)
                        .focused($composerFocused)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .rossNativeGlassSurface(
                    tint: Color.rossHighlight,
                    shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                    interactive: true,
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: 0.50
                )
                .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
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
                    Text(rossLocalized("legal_search_sanitized_query_detail"))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    hideKeyboard()
                    onSend()
                } label: {
                    Text(rossLocalized("send"))
                }
                .buttonStyle(RossPrimaryButtonStyle())
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.42)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
        }
        .rossAppBackdrop()
        .alphaDismissesKeyboardOnScroll()
    }
}

struct AlphaRootAskToolsSheet: View {
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
            RossGlassGroup(spacing: 18) {
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
                                Text(rossLocalized("ask_ross"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.rossInk)
                            }
                            Text(rossLocalized("ask_tools_detail"))
                                .font(.caption)
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
                                .rossNativeGlassSurface(
                                    tint: Color.rossInk.opacity(0.7),
                                    shape: Circle(),
                                    interactive: true,
                                    fallbackFillOpacity: 0.82,
                                    fallbackStrokeOpacity: 0.44
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(rossLocalized("close_ask_ross_tools"))
                    }

                    VStack(spacing: 10) {
                        AlphaRootAskToolRow(
                            title: rossLocalized("add_file"),
                            detail: activeScopeCaseID == nil ? rossLocalized("add_file_shared_detail") : rossLocalized("add_file_matter_detail"),
                            accentLabel: rossLocalized("open"),
                            icon: .fileUpload,
                            variant: .accent,
                            fallbackSystemImage: "doc.badge.plus"
                        ) {
                            dismiss()
                            onAddFile()
                        }

                        AlphaRootAskToolRow(
                            title: rossLocalized("add_image"),
                            detail: activeScopeCaseID == nil ? rossLocalized("add_image_shared_detail") : rossLocalized("add_image_matter_detail"),
                            accentLabel: rossLocalized("open"),
                            icon: .files,
                            variant: .neutral,
                            fallbackSystemImage: "photo.stack"
                        ) {
                            dismiss()
                            onAddImage()
                        }

                        AlphaRootAskToolRow(
                            title: rossLocalized("legal_search"),
                            detail: model.askWebEnabled
                                ? rossLocalized("legal_search_on_detail")
                                : rossLocalized("legal_search_off_detail"),
                            accentLabel: model.askWebEnabled ? rossLocalized("on") : rossLocalized("off"),
                            icon: .earth,
                            variant: model.askWebEnabled ? .highlight : .neutral,
                            fallbackSystemImage: model.askWebEnabled ? "globe.badge.chevron.backward" : "globe.slash"
                        ) {
                            model.askWebEnabled.toggle()
                        }

                        AlphaRootAskToolRow(
                            title: rossLocalized("activity_log"),
                            detail: rossLocalized("ask_activity_log_detail"),
                            accentLabel: rossLocalized("open"),
                            icon: .gearKeyhole,
                            variant: .neutral,
                            fallbackSystemImage: "lock.shield"
                        ) {
                            dismiss()
                            model.path.append(.privacyLedger)
                        }
                    }

                    if let fixedScopeCaseID {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(fixedScopeCaseID == alphaSharedWorkspaceID ? rossLocalized("this_space") : rossLocalized("this_matter"))
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
                            Text(rossLocalized("ask_in"))
                                .font(.caption.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.rossInk.opacity(0.64))

                            AlphaRootAskScopeRow(
                                title: rossLocalized("all_work"),
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
                            Text(rossLocalized("use_uploaded_files"))
                                .font(.caption.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.rossInk.opacity(0.64))

                            if availableDocuments.isEmpty {
                                AlphaRootAskEmptyFilesCard(
                                    scopeIsShared: activeScopeCaseID == nil || activeScopeCaseID == alphaSharedWorkspaceID,
                                    onAddFile: {
                                        dismiss()
                                        onAddFile()
                                    },
                                    onAddImage: {
                                        dismiss()
                                        onAddImage()
                                    }
                                )
                            }

                            ForEach(availableDocuments) { document in
                                AlphaRootAskDocumentRow(
                                    title: document.title,
                                    detail: document.isShared
                                        ? rossLocalized("shared_file")
                                        : (activeScopeCaseID == nil ? document.caseTitle : rossLocalized("this_matter")),
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
            }
            .padding(20)
        }
    }
}

struct AlphaRootAskEmptyFilesCard: View {
    let scopeIsShared: Bool
    let onAddFile: () -> Void
    let onAddImage: () -> Void

    private var detail: String {
        alphaRootAskEmptyFilesDetail(scopeIsShared: scopeIsShared)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RossGlassIconView(.fileUpload, variant: .accent, size: 28, fallbackSystemImage: "doc.badge.plus")
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rossLocalized("no_ready_files_yet"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            RossGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        onAddFile()
                    } label: {
                        Label(rossLocalized("add_file"), systemImage: "doc.badge.plus")
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 15)

                    Button {
                        onAddImage()
                    } label: {
                        Label(rossLocalized("add_image"), systemImage: "photo")
                    }
                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 15)
                }
            }
        }
        .padding(14)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallbackFillOpacity: 0.80,
            fallbackStrokeOpacity: 0.48
        )
        .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
    }
}

struct AlphaRootAskDocumentRow: View {
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
            .rossNativeGlassSurface(
                tint: isSelected ? Color.rossAccent : Color.rossHighlight,
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.82,
                fallbackStrokeOpacity: isSelected ? 0.56 : 0.46
            )
            .shadow(color: Color.rossShadow.opacity(isSelected ? 0.10 : 0.07), radius: isSelected ? 9 : 7, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct AlphaRootAskToolRow: View {
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
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: Capsule(),
                        fallbackFillOpacity: 0.68,
                        fallbackStrokeOpacity: 0.36
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .rossNativeGlassSurface(
                tint: Color.rossAccent,
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.82,
                fallbackStrokeOpacity: 0.48
            )
            .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct AlphaRootAskScopeRow: View {
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
            .rossNativeGlassSurface(
                tint: isSelected ? Color.rossAccent.opacity(0.18) : Color.rossAccent.opacity(0.08),
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                interactive: true,
                fallbackFillOpacity: isSelected ? 0.80 : 0.72,
                fallbackStrokeOpacity: isSelected ? 0.62 : 0.48
            )
            .shadow(color: Color.rossShadow.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 8 : 5, y: isSelected ? 2 : 1)
        }
        .buttonStyle(.plain)
    }
}
