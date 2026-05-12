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

    private var dockBadgeFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.11) : Color.white.opacity(0.94)
    }

    private var dockGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color.white.opacity(0.045),
                Color.rossGlassFill.opacity(0.82)
            ]
        }

        return [
            Color.white.opacity(0.98),
            Color.rossSecondaryGroupedBackground.opacity(0.94)
        ]
    }

    private var dockStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.76)
    }

    private var dockShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.rossShadow.opacity(0.08)
    }

    private var dockBackdropTint: Color {
        colorScheme == .dark ? Color.rossBackdropGlow.opacity(0.12) : Color.white.opacity(0.62)
    }

    private var dockLiftHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.42)
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

    private var activeDockActivity: (title: String, detail: String, status: String, progress: Double?)? {
        if model.publicLawSearchStatus == .reviewing && model.publicLawPreview != nil {
            return (
                "Review required",
                "Check the search query before anything leaves this device.",
                "Review",
                nil
            )
        }

        if model.publicLawSearchInFlight {
            return (
                "Searching legal sources",
                "Ross is searching with a cleaned query. Your files stay on this iPhone.",
                "Searching",
                nil
            )
        }

        if let latest = model.latestAskResult,
           latest.scopeCaseID == activeScopeCaseID,
           latest.isPendingLocalModelResponse {
            let context: String
            if latest.selectedDocumentTitles.count == 1, let title = latest.selectedDocumentTitles.first {
                context = title
            } else if latest.selectedDocumentTitles.count > 1 {
                context = "\(latest.selectedDocumentTitles.count) selected files"
            } else if activeSelectedDocuments.count == 1, let document = activeSelectedDocuments.first {
                context = document.displayTitle
            } else if activeScopeCaseID != nil {
                context = "this matter"
            } else {
                context = "your workspace"
            }

            return (
                "Ross is answering",
                "Checking \(context) with the private on-device assistant.",
                "Working",
                nil
            )
        }

        if pendingCollapseQuestion != nil {
            let context: String
            if activeSelectedDocuments.count == 1, let document = activeSelectedDocuments.first {
                context = document.displayTitle
            } else if activeSelectedDocuments.count > 1 {
                context = "\(activeSelectedDocuments.count) tagged files"
            } else if activeScopeCaseID != nil {
                context = "this matter"
            } else {
                context = "your workspace"
            }

            return (
                "Ross is working",
                "Reading \(context) and drafting an answer you can verify.",
                "Thinking",
                nil
            )
        }

        if let setupJob = alphaActiveSetupJob(model) {
            switch setupJob.state {
            case .queued, .downloading, .verifying:
                return (
                    "Private assistant setup",
                    alphaAssistantActivityDetail(for: setupJob.state),
                    alphaAssistantStateLabel(setupJob.state),
                    alphaDownloadProgressValue(setupJob)
                )
            case .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .failed, .notStarted, .installed, .cancelled:
                break
            }
        }

        return nil
    }

    private var publicLawModeTitle: String {
        if model.publicLawSearchStatus == .reviewing && model.publicLawPreview != nil {
            return "Review required"
        }
        return model.askWebEnabled ? "Legal Search on" : "Local only"
    }

    private var composerPlaceholder: String {
        if alphaUsesHindiUi() {
            if fixedDocumentIDs.count == 1 {
                return "Ross से इस फ़ाइल के बारे में पूछें…"
            }
            if activeScopeCaseID != nil {
                return "Ross से इस मामले के बारे में पूछें…"
            }
            return "Ross से आज, किसी मामले, या किसी फ़ाइल के बारे में पूछें…"
        }
        if fixedDocumentIDs.count == 1 {
            return "Ask Ross about this file…"
        }
        if activeScopeCaseID != nil {
            return "Ask Ross about this matter…"
        }
        return "Ask Ross about today, a matter, or a file…"
    }

    private var collapsedDockTitle: String {
        if alphaUsesHindiUi() {
            if fixedDocumentIDs.count == 1 {
                return "Ross से इस फ़ाइल के बारे में पूछें…"
            }
            if activeScopeCaseID != nil {
                return "Ross से इस मामले के बारे में पूछें…"
            }
            return "Ross से पूछें…"
        }
        if fixedDocumentIDs.count == 1 {
            return "Ask Ross about this file…"
        }
        if activeScopeCaseID != nil {
            return "Ask Ross about this matter…"
        }
        return "Ask Ross…"
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

    private func send(dismissingExpandedComposer: Bool = false) {
        let scopeCaseID = activeScopeCaseID
        let webEnabled = model.askWebEnabled
        let question = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        alphaHaptic(.light)
        dockComposerFocused = false
        if !fixedDocumentIDs.isEmpty {
            model.setSelectedAskDocumentIDs(fixedDocumentIDs, for: scopeCaseID)
        }
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
        guard case let .success(urls) = result, let url = urls.first else { return }
        Task { await model.importDocument(caseId: activeScopeCaseID, from: url) }
    }

    private var expandedDock: some View {
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
                    .accessibilityHint("Ask Ross is scoped to this matter.")
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
                            .background(
                                colorScheme == .dark ? Color.black.opacity(0.32) : Color.white.opacity(0.78),
                                in: Circle()
                            )
                            .overlay {
                                Circle()
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.rossBorder.opacity(0.58), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add to Ask Ross")

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
                        .accessibilityLabel("Clear Ask Ross text")
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, 13)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.rossBorder.opacity(0.68), lineWidth: 1)
                }

                Button {
                    if canSend {
                        send()
                    } else {
                        cancelDockEditing()
                    }
                } label: {
                    Image(systemName: canSend ? "arrow.up" : "xmark")
                        .font((canSend ? Font.body : Font.callout).weight(.bold))
                        .imageScale(.small)
                        .foregroundStyle(canSend ? (colorScheme == .dark ? Color.rossGroupedBackground : Color.rossCardBackground) : dockPrimaryText.opacity(0.82))
                        .frame(width: 36, height: 36)
                        .background(
                            canSend
                                ? Color.rossAccent
                                : (colorScheme == .dark ? Color.black.opacity(0.32) : Color.white.opacity(0.78)),
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.rossBorder.opacity(0.58), lineWidth: canSend ? 0 : 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(canSend ? "Send Ask Ross question" : "Close Ask Ross")
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
                Text("Asking about \(model.scopeLabel(for: activeScopeCaseID))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(dockSecondaryText)
            } else if let selectionSubtitle, fixedDocumentIDs.isEmpty {
                Text(selectionSubtitle)
                    .font(.caption2)
                    .foregroundStyle(dockSecondaryText)
            } else if fixedDocumentIDs.isEmpty {
                Text("Tap \u{FF0B} to attach a file, or say \u{201C}add task\u{201D} or \u{201C}save date\u{201D}.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(dockMutedText)
            }

            if model.askWebEnabled {
                Text("Ross will use Legal Search with a cleaned query. Your case files stay on this device.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(dockSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: dockGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .rossGlassSurface(
            tint: dockBackdropTint,
            cornerRadius: 22,
            shadowOpacity: colorScheme == .dark ? 0.2 : 0.12,
            shadowRadius: colorScheme == .dark ? 18 : 14,
            shadowY: colorScheme == .dark ? 10 : 7,
            fillOpacity: colorScheme == .dark ? 0.78 : 0.86,
            strokeOpacity: colorScheme == .dark ? 0.22 : 0.7
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let activity = activeDockActivity {
                AlphaDockActivityBar(
                    title: activity.title,
                    detail: activity.detail,
                    progressValue: activity.progress
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let inlineResult, !dockComposerFocused {
                AlphaInlineAskResponseCard(
                    result: inlineResult,
                    contextDocumentTitle: fixedDocumentIDs.count == 1 ? activeSelectedDocuments.first?.title : nil,
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Review Legal Search")
                                .font(.title3.weight(.semibold))
                            Text("Ross will search using only the query below. Your case files, party names, and private details stay on this device.")
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Query to be sent")
                                    .font(.subheadline.weight(.semibold))
                                if editingPublicLawQuery {
                                    TextEditor(text: Binding(
                                        get: { model.publicLawPreview?.query ?? "" },
                                        set: { model.updatePendingPublicLawQuery($0) }
                                    ))
                                    .font(.callout.weight(.medium))
                                    .frame(minHeight: 96)
                                    .padding(8)
                                    .background(Color.rossSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    Text(preview.query)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.rossSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }

                            Text(preview.removed == ["No private case data detected"] ? "0 private case details sent" : "\(preview.removed.count) private details removed · 0 sent")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.62))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.rossSecondaryGroupedBackground.opacity(0.72), in: Capsule())

                            if model.publicLawSearchInFlight {
                                ProgressView("Searching legal sources…")
                                    .progressViewStyle(.circular)
                                    .tint(Color.rossAccent)
                                    .font(.footnote.weight(.medium))
                            }
                        }
                        .padding(alphaScreenPadding)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        HStack(spacing: 10) {
                            Button("Cancel") {
                                model.cancelPendingPublicLawSearch()
                            }
                            .buttonStyle(.bordered)

                            Spacer(minLength: 0)

                            Button("Send") {
                                Task { await model.confirmPendingPublicLawSearch() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.publicLawSearchInFlight || (model.publicLawPreview?.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true))
                        }
                    }
                    .padding(alphaScreenPadding)
                    .background(Color.rossGroupedBackground.opacity(0.94))
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
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

    private var dockLiftHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.42)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.78) : Color.rossInk.opacity(0.72))
                .lineLimit(1)
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
        .rossGlassSurface(
            tint: dockBackdropTint,
            cornerRadius: 999,
            shadowOpacity: colorScheme == .dark ? 0.18 : 0.1,
            shadowRadius: 12,
            shadowY: 6,
            fillOpacity: colorScheme == .dark ? 0.82 : 0.88,
            strokeOpacity: colorScheme == .dark ? 0.18 : 0.72
        )
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
            if let clampedProgress {
                ProgressView(value: clampedProgress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(Color.rossAccent)
                    .frame(width: 46)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(Color.rossAccent)
                    .frame(width: 22)
            }

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
                .background(Color.rossAccent.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.11) : Color.rossBorder.opacity(0.52), lineWidth: 1)
        }
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
            if let progressValue {
                ProgressView(value: min(max(progressValue, 0), 1), total: 1)
                    .progressViewStyle(.linear)
                    .tint(Color.rossAccent)
                    .frame(width: 54)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.rossAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : Color.rossInk.opacity(0.84))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.58) : Color.rossInk.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(colorScheme == .dark ? Color.rossGlassFill.opacity(0.9) : Color.white.opacity(0.86), in: Capsule())
        .overlay {
            Capsule()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.13) : Color.rossBorder.opacity(0.58), lineWidth: 1)
        }
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}

struct AlphaInlineAskResponseCard: View {
    let result: AlphaAskResult
    let contextDocumentTitle: String?
    let onOpenSource: (AlphaSourceRef) -> Void
    let onOpenConversation: () -> Void
    let onClose: () -> Void

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
                            .fixedSize(horizontal: false, vertical: true)

                        if let note = result.statusNote {
                            Text(note)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.rossAccent)
                        }
                    }
                    Spacer(minLength: 8)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.rossInk.opacity(0.45))
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
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
                    Button("View full answer", action: onOpenConversation)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }
            }
        }
        .padding(14)
        .background(Color.rossCardBackground.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
}

struct AlphaAskScopePill: View {
    let title: String
    let foregroundStyle: Color
    let backgroundOpacity: Double
    var statusSystemImage: String? = nil
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .lineLimit(1)

            if let statusSystemImage {
                Image(systemName: statusSystemImage)
                    .font(.caption2.weight(.bold))
            }

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, AlphaAskPillMetrics.horizontalPadding)
        .frame(height: AlphaAskPillMetrics.height)
        .background(Color.white.opacity(backgroundOpacity), in: Capsule())
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
        let dockBackground = colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.6)
        let dockStroke = colorScheme == .dark ? Color.white.opacity(0.08) : Color.rossGlassStroke.opacity(0.9)

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
                .accessibilityLabel("Remove \(title)")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone == .dock ? dockForeground : Color.rossInk.opacity(0.82))
        .padding(.horizontal, AlphaAskPillMetrics.horizontalPadding)
        .frame(height: AlphaAskPillMetrics.height)
        .background(
            tone == .dock ? dockBackground : Color.rossGlassSubtleFill,
            in: RoundedRectangle(cornerRadius: AlphaAskPillMetrics.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AlphaAskPillMetrics.cornerRadius, style: .continuous)
                .stroke(
                    tone == .dock ? dockStroke : Color.rossGlassStroke.opacity(0.82),
                    lineWidth: 1
                )
        }
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
            .background(
                tone == .dock
                    ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.rossAccent.opacity(0.08))
                    : Color.rossAccent.opacity(0.08),
                in: Capsule()
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
        .padding(8)
        .background(
            tone == .dock
                ? (colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.68))
                : Color.rossGlassSubtleFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    tone == .dock
                        ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.rossGlassStroke.opacity(0.9))
                        : Color.rossGlassStroke.opacity(0.82),
                    lineWidth: 1
                )
        }
        .shadow(
            color: tone == .dock
                ? (colorScheme == .dark ? Color.black.opacity(0.12) : Color.rossShadow.opacity(0.12))
                : Color.rossShadow.opacity(0.14),
            radius: 10,
            x: 0,
            y: 4
        )
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
        let dockBackground = colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.54)

        HStack(spacing: 10) {
            RossGlassIconView(icon.0, variant: icon.1, size: 16, fallbackSystemImage: icon.2)
                .frame(width: 26, height: 26)
                .background(
                    tone == .dock ? dockBackground : Color.rossGlassFill,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
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
        .background(
            tone == .dock ? dockBackground : Color.rossGlassFill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    tone == .dock
                        ? (colorScheme == .dark ? Color.white.opacity(0.06) : Color.rossGlassStroke.opacity(0.86))
                        : Color.rossGlassStroke.opacity(0.82),
                    lineWidth: 1
                )
        }
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
                        Text("Ask Ross")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text("Type @ to add a file.")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.64))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button("Done") {
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
                            statusSystemImage: "lock.fill",
                            showsChevron: false
                        )
                    }

                    Button {
                        model.askWebEnabled.toggle()
                    } label: {
                        AlphaAskScopePill(
                            title: model.askWebEnabled ? "Legal Search on" : "Local only",
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
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.rossCardBackground.opacity(0.86))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.rossBorder.opacity(0.85), lineWidth: 1)
                        }

                    if draftText.isEmpty {
                        Text("Ask Ross about this matter, a tagged file, or your next drafting step.")
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
            Text("Legal Search only uses a sanitized legal query. Case files and document text stay on-device.")
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    hideKeyboard()
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                        }
                        Text("Choose scope, add a file, or turn on Legal Search.")
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
                            .background(Color.rossGlassFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Ask Ross tools")
                }

                VStack(spacing: 10) {
                    AlphaRootAskToolRow(
                        title: "Add file",
                        detail: activeScopeCaseID == nil ? "Add a PDF or note to shared files." : "Add a PDF or note to this matter.",
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
                        detail: activeScopeCaseID == nil ? "Add a photo, scan, or screenshot to shared files." : "Add a photo, scan, or screenshot to this matter.",
                        accentLabel: "Open",
                        icon: .files,
                        variant: .neutral,
                        fallbackSystemImage: "photo.stack"
                    ) {
                        dismiss()
                        onAddImage()
                    }

                    AlphaRootAskToolRow(
                        title: "Legal Search",
                        detail: model.askWebEnabled
                            ? "On. Ross only sends a sanitized legal query."
                            : "Off. Ross stays fully local until you turn it on.",
                        accentLabel: model.askWebEnabled ? "On" : "Off",
                        icon: .earth,
                        variant: model.askWebEnabled ? .highlight : .neutral,
                        fallbackSystemImage: model.askWebEnabled ? "globe.badge.chevron.backward" : "globe.slash"
                    ) {
                        model.askWebEnabled.toggle()
                    }

                    AlphaRootAskToolRow(
                        title: "Activity Log",
                        detail: "See what stayed local and what, if anything, left the device.",
                        accentLabel: "Open",
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
