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

struct AlphaAskConversationScreen: View {
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    @State private var selectedScopeCaseID: UUID?
    @State private var showingThreads = false
    @State private var showingTools = false
    @State private var pendingImportKind: AlphaDockImportKind?
    @State private var answerDetailsResult: AlphaAskResult?
    @State private var composerResetToken = UUID()
    @FocusState private var composerFocused: Bool

    private var activeScopeCaseID: UUID? {
        selectedScopeCaseID ?? fixedScopeCaseID ?? model.askSelectedScopeCaseID
    }

    private var conversation: [AlphaAskResult] {
        model.askConversation(for: activeScopeCaseID)
    }

    private var scopeTitle: String {
        guard activeScopeCaseID != nil else { return "Ross" }
        return model.scopeLabel(for: activeScopeCaseID)
    }

    private var draftText: String {
        model.askDraft(for: activeScopeCaseID)
    }

    private var activeSelectedDocuments: [AlphaAskDocumentOption] {
        model.selectedAskDocuments(for: activeScopeCaseID)
    }

    private var mentionSuggestions: [AlphaAskDocumentOption] {
        guard let query = alphaAskMentionQuery(in: draftText) else { return [] }
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

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var allScopeCases: [AlphaCaseMatter] {
        model.cases.filter { $0.id != alphaSharedWorkspaceID }
    }

    private func goBack() {
        if !model.path.isEmpty {
            model.path.removeLast()
        }
    }

    private func switchScope(to scopeCaseID: UUID?) {
        alphaHaptic(.selection)
        selectedScopeCaseID = scopeCaseID
        model.askSelectedScopeCaseID = scopeCaseID
        model.startNewChat(forScope: scopeCaseID, openConversation: false)
        composerFocused = true
    }

    private func send() {
        let scopeCaseID = activeScopeCaseID
        let question = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        alphaHaptic(.light)
        composerFocused = false
        model.setAskDraft("", for: scopeCaseID)
        composerResetToken = UUID()
        Task { @MainActor in
            await model.submitDockInput(question: question, scopeCaseID: scopeCaseID, webEnabled: model.askWebEnabled)
            model.setAskDraft("", for: scopeCaseID)
            composerResetToken = UUID()
        }
    }

    private func selectThread(_ session: AlphaChatSession, scopeCaseID: UUID?) {
        selectedScopeCaseID = scopeCaseID
        model.setActiveChatSession(session.id, forScope: scopeCaseID)
        showingThreads = false
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        defer { pendingImportKind = nil }
        guard case let .success(urls) = result else { return }
        let scopeCaseID = activeScopeCaseID
        Task {
            await model.importDocuments(caseId: scopeCaseID, from: urls, openAfterImport: false)
        }
    }

    private func removeDocumentSelection(_ documentID: UUID) {
        var selected = model.selectedAskDocumentIDs(for: activeScopeCaseID)
        selected.remove(documentID)
        model.setSelectedAskDocumentIDs(selected, for: activeScopeCaseID)
    }

    private func applyMention(_ document: AlphaAskDocumentOption) {
        let scopeCaseID = activeScopeCaseID
        model.toggleAskDocumentSelection(document.id, for: scopeCaseID)
        model.setAskDraft(
            alphaAskReplacingTrailingMention(in: draftText, with: document.displayTitle),
            for: scopeCaseID
        )
    }

    var body: some View {
        let conversation = conversation
        let contextDocumentTitle = model.askDocumentTitle(for: activeScopeCaseID)
        let latestTurnID = conversation.last?.stableIdentity

        VStack(spacing: 0) {
            AlphaFullScreenChatTopBar(
                scopeTitle: scopeTitle,
                cases: allScopeCases,
                onBack: goBack,
                onSelectScope: switchScope,
                onShowThreads: { showingThreads = true }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    RossGlassGroup(spacing: 18) {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if conversation.isEmpty {
                            Spacer(minLength: 82)
                            AlphaFullScreenAskEmptyState(
                                scopeLabel: activeScopeCaseID == nil ? nil : scopeTitle,
                                selectedDocumentCount: activeSelectedDocuments.count
                            )
                            Spacer(minLength: 82)
                        } else {
                            ForEach(conversation, id: \.stableIdentity) { result in
                                AlphaFullScreenChatTurn(
                                    result: result,
                                    contextDocumentTitle: contextDocumentTitle,
                                    onOpenSource: model.openSourceRef,
                                    onShowDetails: { answerDetailsResult = $0 }
                                )
                                .id(result.stableIdentity)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                            }
                        }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .animation(.snappy(duration: 0.3), value: conversation.count)
                    }
                }
                .alphaDismissesKeyboardOnScroll()
                .onAppear {
                    if let latestTurnID {
                        proxy.scrollTo(latestTurnID, anchor: .bottom)
                    }
                }
                .onChange(of: latestTurnID) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.snappy(duration: 0.28)) {
                        proxy.scrollTo(newValue, anchor: .bottom)
                    }
                }
            }

            AlphaFullScreenChatComposer(
                text: draftBinding,
                canSend: canSend,
                resetToken: composerResetToken,
                selectedDocuments: activeSelectedDocuments,
                mentionSuggestions: mentionSuggestions,
                scopeCaseID: activeScopeCaseID,
                focused: $composerFocused,
                onShowTools: { showingTools = true },
                onRemoveDocumentSelection: removeDocumentSelection,
                onSelectMention: applyMention,
                onSend: send
            )
        }
        .rossAppBackdrop()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if selectedScopeCaseID == nil {
                selectedScopeCaseID = fixedScopeCaseID ?? model.askSelectedScopeCaseID
            }
        }
        .sheet(isPresented: $showingThreads) {
            AlphaThreadSidebarSheet(
                model: model,
                activeScopeCaseID: activeScopeCaseID,
                onNewThread: {
                    model.startNewChat(forScope: activeScopeCaseID, openConversation: false)
                    showingThreads = false
                    composerFocused = true
                },
                onSelectThread: selectThread
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTools) {
            AlphaRootAskToolsSheet(
                model: model,
                fixedScopeCaseID: activeScopeCaseID,
                fixedDocumentIDs: [],
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
                AlphaAnswerDetailsSheet(result: answerDetailsResult)
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
    }
}

struct AlphaFullScreenChatTopBar: View {
    let scopeTitle: String
    let cases: [AlphaCaseMatter]
    let onBack: () -> Void
    let onSelectScope: (UUID?) -> Void
    let onShowThreads: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AlphaFullScreenChatTopBarButton(
                systemImage: "chevron.left",
                accessibilityLabel: rossLocalized("back"),
                action: onBack
            )

            Spacer(minLength: 0)

            Menu {
                Button(rossLocalized("ross_scope_all")) { onSelectScope(nil) }
                ForEach(cases) { caseMatter in
                    Button(caseMatter.title) { onSelectScope(caseMatter.id) }
                }
            } label: {
                AlphaFullScreenChatScopeLabel(scopeTitle: scopeTitle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rossLocalized("choose_chat_scope"))

            Spacer(minLength: 0)

            AlphaFullScreenChatTopBarButton(
                systemImage: "line.3.horizontal",
                accessibilityLabel: rossLocalized("threads"),
                action: onShowThreads
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .rossNativeGlassSurface(
            tint: Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
            fallbackFillOpacity: 0.78,
            fallbackStrokeOpacity: 0.42
        )
        .shadow(color: Color.rossShadow.opacity(0.05), radius: 7, y: 2)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

private struct AlphaFullScreenChatTopBarButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                icon
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.28),
                        shape: Circle(),
                        interactive: true,
                        fallbackFillOpacity: 0.74,
                        fallbackStrokeOpacity: 0.42
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.rossInk)
            .frame(width: 36, height: 36)
    }
}

private struct AlphaFullScreenChatScopeLabel: View {
    let scopeTitle: String

    var body: some View {
        label
            .modifier(AlphaFullScreenChatScopeGlassModifier())
    }

    private var label: some View {
        HStack(spacing: 5) {
            Text(scopeTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.rossInk.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 220)
        .frame(height: 36)
    }
}

private struct AlphaFullScreenChatScopeGlassModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = Capsule()

        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    Glass.regular
                        .tint(Color.rossHighlight.opacity(0.18))
                        .interactive(),
                    in: shape
                )
        } else {
            content
                .rossNativeGlassSurface(
                    tint: Color.rossHighlight,
                    shape: shape,
                    interactive: true,
                    fallbackFillOpacity: 0.74,
                    fallbackStrokeOpacity: 0.42
                )
        }
    }
}

struct AlphaFullScreenAskEmptyState: View {
    let scopeLabel: String?
    let selectedDocumentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedDocumentCount > 0 ? "doc.text.magnifyingglass" : "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
                    .frame(width: 40, height: 40)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.22),
                        shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                        interactive: false,
                        fallbackFillOpacity: 0.82,
                        fallbackStrokeOpacity: 0.46
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(alphaAskEmptyTitle())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(alphaAskEmptyDetail(scopeLabel: scopeLabel, selectedDocumentCount: selectedDocumentCount))
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                AlphaAskEmptyWorkflowChip(systemImage: "at", title: rossLocalized("ask_workflow_tag_file"))
                AlphaAskEmptyWorkflowChip(systemImage: "plus", title: rossLocalized("ask_workflow_import"))
                AlphaAskEmptyWorkflowChip(systemImage: "arrow.up", title: rossLocalized("ask_workflow_ask"))
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(16)
        .rossNativeGlassSurface(
            tint: Color.rossAccent.opacity(0.12),
            shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.50
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 10, y: 4)
        .frame(maxWidth: .infinity)
    }
}

private struct AlphaAskEmptyWorkflowChip: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.rossInk.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .rossNativeGlassSurface(
                tint: Color.rossHighlight,
                shape: RoundedRectangle(cornerRadius: 13, style: .continuous),
                fallbackFillOpacity: 0.72,
                fallbackStrokeOpacity: 0.38
            )
            .shadow(color: Color.rossShadow.opacity(0.035), radius: 4, y: 1)
    }
}

struct AlphaFullScreenChatComposer: View {
    @Binding var text: String
    let canSend: Bool
    let resetToken: UUID
    let selectedDocuments: [AlphaAskDocumentOption]
    let mentionSuggestions: [AlphaAskDocumentOption]
    let scopeCaseID: UUID?
    var focused: FocusState<Bool>.Binding
    let onShowTools: () -> Void
    let onRemoveDocumentSelection: (UUID) -> Void
    let onSelectMention: (AlphaAskDocumentOption) -> Void
    let onSend: () -> Void

    private var liveCanSend: Bool {
        canSend || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !selectedDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedDocuments) { document in
                            AlphaAskSelectionChip(
                                title: document.displayTitle,
                                detail: scopeCaseID == nil ? (document.isShared ? "shared" : document.caseTitle) : (document.isShared ? "shared" : nil),
                                isShared: document.isShared,
                                tone: .sheet,
                                onRemove: {
                                    onRemoveDocumentSelection(document.id)
                                }
                            )
                        }
                    }
                }
            }

            RossGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    AlphaFullScreenChatAddFilesButton(action: onShowTools)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField(alphaAskConversationPlaceholder(), text: $text, axis: .vertical)
                            .id(resetToken)
                            .lineLimit(1...5)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(Color.rossInk)
                            .focused(focused)
                            .submitLabel(.send)
                            .onSubmit {
                                if liveCanSend { onSend() }
                            }

                        if selectedDocuments.isEmpty {
                            Text(alphaAskTagFileHint())
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.46))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .rossNativeGlassSurface(
                        tint: Color.rossHighlight,
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.50
                    )
                    .shadow(color: Color.rossShadow.opacity(0.07), radius: 8, y: 3)

                    AlphaFullScreenChatSendButton(
                        canSend: liveCanSend,
                        onSend: onSend
                    )
                }
            }

            if !mentionSuggestions.isEmpty {
                AlphaAskMentionSuggestionsCard(
                    documents: mentionSuggestions,
                    scopeCaseID: scopeCaseID,
                    tone: .sheet,
                    onSelect: onSelectMention
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .rossNativeGlassSurface(
            tint: Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.50
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 10, y: 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }
}

struct AlphaFullScreenChatTurn: View {
    let result: AlphaAskResult
    let contextDocumentTitle: String?
    let onOpenSource: (AlphaSourceRef) -> Void
    let onShowDetails: (AlphaAskResult) -> Void

    private var deduplicatedStatusNote: String? {
        guard let note = result.statusNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty else { return nil }
        let titleNormalized = result.answerTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard titleNormalized != note.lowercased() else { return nil }
        return note
    }

    var body: some View {
        let answerItems = result.answerSectionItems()

        VStack(alignment: .leading, spacing: 12) {
            if !result.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Spacer(minLength: 46)
                    VStack(alignment: .trailing, spacing: 8) {
                        if !result.selectedDocumentTitles.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(result.selectedDocumentTitles.enumerated()), id: \.offset) { _, title in
                                        AlphaRossTokenChip(
                                            title: title,
                                            detail: nil,
                                            systemImage: "paperclip"
                                        )
                                    }
                                }
                            }
                            .frame(maxWidth: 280, alignment: .trailing)
                        }

                        Text(result.question)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .rossNativeGlassSurface(
                                tint: Color.rossAccent,
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fallbackFillOpacity: 0.82,
                                fallbackStrokeOpacity: 0.46
                            )
                            .shadow(color: Color.rossShadow.opacity(0.06), radius: 7, y: 3)
                    }
                }
            }

            if result.isPendingLocalModelResponse {
                AlphaPendingLocalModelCard(
                    result: result,
                    style: .fullScreen
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    let copyAnswerAction: () -> Void = {
                        alphaCopyAskResultToPasteboard(result)
                        alphaHaptic(.light)
                    }
                    let showAnswerDetailsAction: () -> Void = {
                        alphaHaptic(.light)
                        onShowDetails(result)
                    }

                    if result.hasAnswerDetails {
                        AlphaCleanAnswerHeader<EmptyView>(
                            title: result.answerTitle,
                            continuationContext: result.answerContinuationContext,
                            statusNote: deduplicatedStatusNote,
                            onCopy: copyAnswerAction,
                            onShowDetails: showAnswerDetailsAction
                        )
                    } else {
                        AlphaCleanAnswerHeader<EmptyView>(
                            title: result.answerTitle,
                            continuationContext: result.answerContinuationContext,
                            statusNote: deduplicatedStatusNote,
                            onCopy: copyAnswerAction
                        )
                    }

                    ForEach(Array(answerItems.enumerated()), id: \.element.id) { index, section in
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaFormattedAnswerText(text: section.text)
                            if index < answerItems.count - 1 {
                                Divider()
                                    .overlay(Color.rossBorder.opacity(0.4))
                            }
                        }
                    }

                    if !result.caseFileSources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rossLocalized("sources"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.56))
                            AlphaSourceRefChips(
                                sourceRefs: result.caseFileSources,
                                contextDocumentTitle: contextDocumentTitle,
                                onOpenSourceRef: onOpenSource
                            )
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .rossNativeGlassSurface(
                    tint: Color.rossAccent,
                    shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: 0.56
                )
                .contextMenu {
                    if result.hasAnswerDetails {
                        Button {
                            onShowDetails(result)
                        } label: {
                            Label(rossLocalized("answer_details"), systemImage: "info.circle")
                        }
                    }
                    Button {
                        alphaCopyAskResultToPasteboard(result)
                    } label: {
                        Label(rossLocalized("copy_answer"), systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

struct AlphaAnswerDetailsSheet: View {
    let result: AlphaAskResult

    private var invocation: AlphaLocalModelInvocation? {
        result.modelInvocation
    }

    private var overviewMetrics: [AlphaAnswerDetailMetric] {
        invocation?.answerDetailOverviewMetrics ?? []
    }

    private var secondaryMetrics: [AlphaAnswerDetailMetric] {
        invocation?.answerDetailSecondaryMetrics ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rossLocalized("answer_details"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(result.answerTitle)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !overviewMetrics.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)
                        ],
                        spacing: 12
                    ) {
                        ForEach(overviewMetrics) { metric in
                            AlphaAnswerDetailsOverviewCard(metric: metric)
                        }
                    }
                }

                if !secondaryMetrics.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(secondaryMetrics) { metric in
                            AlphaAnswerDetailsRow(
                                label: metric.label,
                                value: metric.value
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .rossAppBackdrop()
    }
}

struct AlphaAnswerDetailMetric: Equatable, Identifiable {
    let key: String
    let label: String
    let value: String

    var id: String { key }
}

extension AlphaLocalModelInvocation {
    var answerDetailProcessedTokensLabel: String? {
        guard let tokens = estimatedProcessedTokens else { return nil }
        return usesMeasuredTokenCounts ? tokens.formatted() : "~\(tokens.formatted())"
    }

    var answerDetailOverviewMetrics: [AlphaAnswerDetailMetric] {
        var metrics: [AlphaAnswerDetailMetric] = []

        if let processedTokens = answerDetailProcessedTokensLabel {
            metrics.append(
                AlphaAnswerDetailMetric(
                    key: "tokens_processed",
                    label: rossLocalized("tokens_processed"),
                    value: processedTokens
                )
            )
        }

        if let tokenSpeed = estimatedOutputTokensPerSecond {
            metrics.append(
                AlphaAnswerDetailMetric(
                    key: "token_speed",
                    label: rossLocalized("token_speed"),
                    value: alphaAssistantTokenRateLabel(tokensPerSecond: tokenSpeed)
                )
            )
        }

        return metrics
    }

    var answerDetailSecondaryMetrics: [AlphaAnswerDetailMetric] {
        guard let timeToFirstTokenMs else { return [] }
        return [
            AlphaAnswerDetailMetric(
                key: "runtime_first_response",
                label: rossLocalized("runtime_first_response"),
                value: alphaAssistantFirstResponseLabel(milliseconds: timeToFirstTokenMs)
            )
        ]
    }
}

private struct AlphaAnswerDetailsOverviewCard: View {
    let metric: AlphaAnswerDetailMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            Text(metric.value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .rossNativeGlassSurface(
            tint: Color.rossAccent.opacity(0.18),
            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.42
        )
    }
}

private struct AlphaAnswerDetailsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Color.rossInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .rossNativeGlassSurface(
            tint: Color.rossAccent.opacity(0.22),
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackFillOpacity: 0.76,
            fallbackStrokeOpacity: 0.40
        )
    }
}

enum AlphaPendingLocalModelCardStyle {
    case compact
    case fullScreen

    var showsTaggedFilesAsChips: Bool {
        switch self {
        case .compact:
            return false
        case .fullScreen:
            return true
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact:
            return 18
        case .fullScreen:
            return 20
        }
    }
}

struct AlphaPendingLocalModelCard: View {
    let result: AlphaAskResult
    let style: AlphaPendingLocalModelCardStyle

    private var taggedFilesLine: String? {
        guard !result.selectedDocumentTitles.isEmpty else { return nil }
        if result.selectedDocumentTitles.count == 1, let title = result.selectedDocumentTitles.first {
            return alphaTaggedFileLine(title)
        }
        return alphaTaggedFilesLine(result.selectedDocumentTitles)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.rossAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(rossLocalized("ross_answering"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    if let label = result.pendingLocalModelLabel {
                        Text(alphaLocalModelRunningLabel(label))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.rossAccent)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(rossLocalized("ross_checking_local_files"))
                .font(.footnote)
                .lineSpacing(4)
                .foregroundStyle(Color.rossInk.opacity(0.78))

            if style.showsTaggedFilesAsChips, !result.selectedDocumentTitles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(result.selectedDocumentTitles.enumerated()), id: \.offset) { _, title in
                            AlphaRossTokenChip(
                                title: title,
                                detail: nil,
                                systemImage: "paperclip"
                            )
                        }
                    }
                }
            } else if let taggedFilesLine {
                Text(taggedFilesLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.56
        )
    }
}

struct AlphaThreadSidebarSheet: View {
    @Bindable var model: AlphaRossModel
    let activeScopeCaseID: UUID?
    let onNewThread: () -> Void
    let onSelectThread: (AlphaChatSession, UUID?) -> Void

    private var scopedCases: [(title: String, caseId: UUID?, sessions: [AlphaChatSession])] {
        let general = model.chatSessions(forScope: nil)
        let matterGroups = model.cases
            .filter { $0.id != alphaSharedWorkspaceID }
            .map { caseMatter in
                (title: caseMatter.title, caseId: Optional(caseMatter.id), sessions: model.chatSessions(forScope: caseMatter.id))
            }
        return [(title: rossLocalized("ross_general_scope"), caseId: nil, sessions: general)] + matterGroups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                RossGlassGroup(spacing: 16) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(scopedCases, id: \.title) { group in
                            if !group.sessions.isEmpty || group.caseId == activeScopeCaseID {
                                AlphaThreadGroupCard(
                                    title: group.title,
                                    caseId: group.caseId,
                                    sessions: group.sessions,
                                    activeScopeCaseID: activeScopeCaseID,
                                    model: model,
                                    onSelectThread: onSelectThread
                                )
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .rossAppBackdrop()
            .navigationTitle(rossLocalized("threads"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onNewThread) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(rossLocalized("new_thread"))
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14, expandsHorizontally: false)
                }
            }
        }
    }
}

private struct AlphaThreadGroupCard: View {
    let title: String
    let caseId: UUID?
    let sessions: [AlphaChatSession]
    let activeScopeCaseID: UUID?
    @Bindable var model: AlphaRossModel
    let onSelectThread: (AlphaChatSession, UUID?) -> Void

    private var isActiveScope: Bool {
        caseId == activeScopeCaseID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rossInk.opacity(0.64))
                    .lineLimit(1)

                if isActiveScope {
                    Text(rossLocalized("current"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.rossAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent.opacity(0.16),
                            shape: Capsule(),
                            fallbackFillOpacity: 0.84,
                            fallbackStrokeOpacity: 0.40
                        )
                }

                Spacer(minLength: 0)
            }

            if sessions.isEmpty {
                Text(rossLocalized("no_saved_threads"))
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        Button {
                            onSelectThread(session, caseId)
                        } label: {
                            HStack(spacing: 12) {
                                RossGlassIconView(.userMsg, variant: .neutral, size: 18, fallbackSystemImage: "bubble.left.and.text.bubble.right.fill")

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.chatSessionTitle(session))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)
                                        .lineLimit(1)

                                    Text(alphaRelativeThreadTime(session.updatedAt))
                                        .font(.caption)
                                        .foregroundStyle(Color.rossInk.opacity(0.54))
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.rossInk.opacity(0.36))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .modifier(AlphaAskThreadRowSurface())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .rossNativeGlassSurface(
            tint: isActiveScope ? Color.rossAccent.opacity(0.14) : Color.rossAccent.opacity(0.06),
            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: isActiveScope ? 0.66 : 0.50
        )
    }
}

private struct AlphaAskThreadRowSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.10),
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.44
            )
            .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 2)
    }
}

func alphaRelativeThreadTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: .now)
}

struct AlphaAskEmptyState: View {
    let detail: String
    let suggestions: [String]
    let onSelectSuggestion: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(alphaAskEmptyTitle())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        AlphaAskSuggestionLabel(suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(rossLocalized("answers_starting_point_warning"))
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.42))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AlphaAskSuggestionLabel: View {
    let suggestion: String

    init(_ suggestion: String) {
        self.suggestion = suggestion
    }

    var body: some View {
        label
            .modifier(AlphaAskSuggestionSurface())
    }

    private var label: some View {
        Text(suggestion)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.rossInk)
            .lineLimit(2)
            .minimumScaleFactor(0.88)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 13)
    }
}

private struct AlphaAskSuggestionSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.12),
                shape: RoundedRectangle(cornerRadius: RossSurface.cornerRadius, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.82,
                fallbackStrokeOpacity: 0.48
            )
            .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
    }
}

struct AlphaAskTurnCard: View {
    let result: AlphaAskResult
    let contextDocumentTitle: String?
    let onOpenSource: (AlphaSourceRef) -> Void
    let onReport: () -> Void
    @State private var privacyExpanded = false
    @State private var sourcesExpanded = false

    private var deduplicatedStatusNote: String? {
        guard let note = result.statusNote else { return nil }
        let titleNormalized = result.answerTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let noteNormalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard titleNormalized != noteNormalized else { return nil }
        return note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.kind == .userAsk {
                HStack {
                    Spacer(minLength: 48)
                    Text(result.question)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent,
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fallbackFillOpacity: 0.82,
                            fallbackStrokeOpacity: 0.46
                        )
                        .shadow(color: Color.rossShadow.opacity(0.06), radius: 7, y: 3)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.caption.weight(.semibold))
                    Text(rossLocalized("matter_update"))
                        .font(.caption.weight(.semibold))
                        .tracking(0.2)
                }
                .foregroundStyle(Color.rossInk.opacity(0.62))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    AlphaCleanAnswerHeader(
                        title: result.answerTitle,
                        continuationContext: result.answerContinuationContext,
                        statusNote: deduplicatedStatusNote,
                        onCopy: {
                            alphaCopyAskResultToPasteboard(result)
                            alphaHaptic(.light)
                        },
                        menu: {
                            Button(action: onReport) {
                                Label(rossLocalized("report_answer"), systemImage: "exclamationmark.bubble")
                            }
                        }
                    )

                    let answerItems = result.answerSectionItems()
                    ForEach(Array(answerItems.enumerated()), id: \.element.id) { index, section in
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaFormattedAnswerText(text: section.text)
                            if index < answerItems.count - 1 {
                                Divider().overlay(Color.rossBorder.opacity(0.4))
                            }
                        }
                    }

                    if !result.selectedDocumentTitles.isEmpty, contextDocumentTitle == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(result.selectedDocumentTitles.enumerated()), id: \.offset) { _, title in
                                    AlphaRossTokenChip(
                                        title: title,
                                        detail: nil,
                                        systemImage: "paperclip"
                                    )
                                }
                            }
                        }
                    }

                    if !result.caseFileSources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(rossLocalized("sources"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.56))
                            if result.caseFileSources.count > 2 {
                                Button {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        sourcesExpanded.toggle()
                                    }
                                } label: {
                                    AlphaAnswerSourcesToggleLabel(
                                        title: sourcesExpanded ? rossLocalized("hide_sources") : alphaShowSourcesLabel(result.caseFileSources.count),
                                        isExpanded: sourcesExpanded
                                    )
                                }
                                .buttonStyle(.plain)

                                if sourcesExpanded {
                                    AlphaSourceRefChips(
                                        sourceRefs: result.caseFileSources,
                                        contextDocumentTitle: contextDocumentTitle,
                                        onOpenSourceRef: onOpenSource
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            } else {
                                AlphaSourceRefChips(
                                    sourceRefs: result.caseFileSources,
                                    contextDocumentTitle: contextDocumentTitle,
                                    onOpenSourceRef: onOpenSource
                                )
                            }
                        }
                        .padding(.top, 2)
                    }

                    if let preview = result.publicLawPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            AlphaSectionLabel(
                                title: rossLocalized("what_ross_searched"),
                                detail: result.publicLawResults.isEmpty ? rossLocalized("awaiting_review_no_web_search") : rossLocalized("ross_removed_case_details_before_searching")
                            )
                            Text(preview.query)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.82))
                        }
                        .padding(12)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent,
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fallbackFillOpacity: 0.84,
                            fallbackStrokeOpacity: 0.48
                        )
                    }

                    if !result.publicLawResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaSectionLabel(title: rossLocalized("from_legal_search"), detail: rossLocalized("from_legal_search_detail"))
                            ForEach(result.publicLawResults) { publicResult in
                                AlphaPublicLawResultCard(result: publicResult)
                            }
                        }
                        .padding(12)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent,
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fallbackFillOpacity: 0.84,
                            fallbackStrokeOpacity: 0.48
                        )
                    }

                    if result.publicLawPreview != nil || !result.publicLawResults.isEmpty || result.needsReviewWarning != nil {
                        AlphaPublicLawWarningsView(
                            needsReviewWarning: result.needsReviewWarning,
                            includePublicLawWarnings: result.publicLawPreview != nil || !result.publicLawResults.isEmpty
                        )
                    }

                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            privacyExpanded.toggle()
                        }
                    } label: {
                        AlphaAnswerPrivacyToggleLabel(
                            title: alphaCompactPrivacyLabel(result),
                            isExpanded: privacyExpanded
                        )
                    }
                    .buttonStyle(.plain)

                    if privacyExpanded {
                        Text(result.privacyReceipt)
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(14)
                .rossNativeGlassSurface(
                    tint: Color.rossHighlight,
                    shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: 0.50
                )
                .shadow(color: Color.rossShadow.opacity(0.09), radius: 10, y: 4)

                Spacer(minLength: 40)
            }
        }
    }
}

private struct AlphaFullScreenChatAddFilesButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
            .accessibilityLabel(rossLocalized("add_files_or_images"))
        } else {
            Button(action: action) {
                icon
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: 0.80,
                        fallbackStrokeOpacity: 0.48
                    )
                    .shadow(color: Color.rossShadow.opacity(0.08), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rossLocalized("add_files_or_images"))
        }
    }

    private var icon: some View {
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.rossInk.opacity(0.72))
            .frame(width: 40, height: 40)
    }
}

private struct AlphaFullScreenChatSendButton: View {
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            if canSend {
                Button(action: onSend) {
                    icon
                }
                .buttonStyle(.glassProminent)
                .tint(Color.rossAccent)
                .accessibilityLabel(rossLocalized("send"))
            } else {
                Button(action: onSend) {
                    icon
                }
                .buttonStyle(.glass)
                .tint(Color.rossInk.opacity(0.22))
                .disabled(true)
                .accessibilityLabel(rossLocalized("send"))
            }
        } else {
            Button(action: onSend) {
                icon
                    .foregroundStyle(canSend ? Color.rossCardBackground : Color.rossInk.opacity(0.44))
                    .rossNativeGlassSurface(
                        tint: canSend ? Color.rossAccent : Color.rossInk.opacity(0.22),
                        shape: Circle(),
                        interactive: true,
                        fallbackFillOpacity: canSend ? 0.92 : 0.72,
                        fallbackStrokeOpacity: canSend ? 0.62 : 0.34
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(rossLocalized("send"))
        }
    }

    private var icon: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 15, weight: .bold))
            .frame(width: 40, height: 40)
    }
}

struct AlphaAskToolbarButton: View {
    let systemImage: String
    var tint: Color = Color.rossInk
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon
            }
            .buttonStyle(.glass)
            .tint(tint)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                icon
                    .rossNativeGlassSurface(
                        tint: tint.opacity(0.64),
                        shape: Circle(),
                        interactive: true,
                        fallbackFillOpacity: 0.74,
                        fallbackStrokeOpacity: 0.48
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
    }
}

struct AlphaSectionLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.74))
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
            }
        }
    }
}

struct AlphaCleanAnswerHeader<MenuContent: View>: View {
    let title: String
    let continuationContext: AlphaAnswerContinuationContext?
    let statusNote: String?
    let onCopy: () -> Void
    let onShowDetails: (() -> Void)?
    let showsMenu: Bool
    @ViewBuilder var menu: () -> MenuContent

    init(
        title: String,
        continuationContext: AlphaAnswerContinuationContext? = nil,
        statusNote: String?,
        onCopy: @escaping () -> Void,
        onShowDetails: (() -> Void)? = nil,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) {
        self.title = title
        self.continuationContext = continuationContext
        self.statusNote = AlphaCleanAnswerHeader.cleanedStatusNote(statusNote)
        self.onCopy = onCopy
        self.onShowDetails = onShowDetails
        self.showsMenu = true
        self.menu = menu
    }

    init(
        title: String,
        continuationContext: AlphaAnswerContinuationContext? = nil,
        statusNote: String?,
        onCopy: @escaping () -> Void,
        onShowDetails: (() -> Void)? = nil
    ) where MenuContent == EmptyView {
        self.title = title
        self.continuationContext = continuationContext
        self.statusNote = AlphaCleanAnswerHeader.cleanedStatusNote(statusNote)
        self.onCopy = onCopy
        self.onShowDetails = onShowDetails
        self.showsMenu = false
        self.menu = { EmptyView() }
    }

    private static func cleanedStatusNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                AlphaCleanAnswerCopyButton(action: onCopy)

                if let onShowDetails {
                    AlphaAnswerAccessoryIconButton(
                        systemImage: "info.circle",
                        accessibilityLabel: rossLocalized("answer_details"),
                        action: onShowDetails
                    )
                }

                if showsMenu {
                    Menu {
                        menu()
                    } label: {
                        AlphaCleanAnswerMenuLabel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rossLocalized("more_answer_actions"))
                }
            }

            if let statusNote {
                AlphaAnswerStatusPill(note: statusNote)
            }

            if let continuationContext {
                AlphaAnswerContinuationContextRow(context: continuationContext)
            }
        }
    }
}

struct AlphaAnswerContinuationContext: Equatable {
    let iconName: String
    let label: String
}

struct AlphaAnswerContinuationContextRow: View {
    let context: AlphaAnswerContinuationContext

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: context.iconName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.54))
            Text(context.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AlphaAnswerAccessoryIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon(foregroundOpacity: 0.6)
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                icon(foregroundOpacity: 0.5)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.08),
                        shape: Circle(),
                        interactive: true,
                        fallbackFillOpacity: 0.82,
                        fallbackStrokeOpacity: 0.42
                    )
                    .shadow(color: Color.rossShadow.opacity(0.03), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private func icon(foregroundOpacity: Double) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.rossInk.opacity(foregroundOpacity))
            .frame(width: 32, height: 32)
    }
}

private struct AlphaAnswerSourcesToggleLabel: View {
    let title: String
    let isExpanded: Bool

    var body: some View {
        label
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.10),
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.42
            )
            .shadow(color: Color.rossShadow.opacity(0.03), radius: 3, y: 1)
    }

    private var label: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
            Spacer(minLength: 8)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Color.rossAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct AlphaAnswerPrivacyToggleLabel: View {
    let title: String
    let isExpanded: Bool

    var body: some View {
        label
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.08),
                shape: Capsule(),
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.44
            )
            .shadow(color: Color.rossShadow.opacity(0.03), radius: 3, y: 1)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.caption2.weight(.semibold))
            Spacer(minLength: 4)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(Color.rossInk.opacity(0.52))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct AlphaCleanAnswerMenuLabel: View {
    var body: some View {
        icon
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.08),
                shape: Capsule(),
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.42
            )
            .shadow(color: Color.rossShadow.opacity(0.03), radius: 3, y: 1)
    }

    private var icon: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.rossInk.opacity(0.48))
            .frame(width: 28, height: 28)
    }
}

private struct AlphaCleanAnswerCopyButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
            .accessibilityLabel(rossLocalized("copy_answer"))
        } else {
            Button(action: action) {
                label
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.08),
                        shape: Capsule(),
                        interactive: true,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.42
                    )
                    .shadow(color: Color.rossShadow.opacity(0.03), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rossLocalized("copy_answer"))
        }
    }

    private var label: some View {
        Label(rossLocalized("copy"), systemImage: "doc.on.doc")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.rossInk.opacity(0.72))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
    }
}

struct AlphaAnswerStatusPill: View {
    let note: String

    var body: some View {
        Label(note, systemImage: "checkmark.seal")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(Color.rossInk.opacity(0.58))
            .labelStyle(.titleAndIcon)
    }
}

struct AlphaTagChip: View {
    let title: String
    var tint: Color = Color.rossAccent

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .rossNativeGlassSurface(
                tint: tint,
                shape: Capsule(),
                fallbackFillOpacity: 0.70,
                fallbackStrokeOpacity: 0.38
            )
    }
}

struct AlphaPublicLawResultCard: View {
    let result: AlphaPublicLawResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                AlphaTagChip(title: rossLocalized("legal_search"))
                Spacer(minLength: 8)
                Text(result.sourceName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .multilineTextAlignment(.trailing)
            }

            Text(result.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            if !result.citation.isEmpty {
                Text(result.citation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
            }

            Text(result.snippet)
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.74))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackFillOpacity: 0.78,
            fallbackStrokeOpacity: 0.44
        )
        .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
    }
}

struct AlphaPublicLawWarningsView: View {
    let needsReviewWarning: String?
    let includePublicLawWarnings: Bool

    var body: some View {
        if includePublicLawWarnings || needsReviewWarning != nil {
            VStack(alignment: .leading, spacing: 4) {
                if includePublicLawWarnings {
                    Text(rossLocalized("legal_search_verify_citations_warning"))
                        .italic()
                }

                if let needsReviewWarning, !needsReviewWarning.isEmpty {
                    Text(needsReviewWarning)
                }
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.rossInk.opacity(0.72))
        }
    }
}

func alphaCopyAskResultToPasteboard(_ result: AlphaAskResult) {
    let text = ([result.answerTitle] + AlphaMatterAskPayloadParser.displaySections(from: result.answerSections)).joined(separator: "\n\n")
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}

struct AlphaAnswerSectionItem: Identifiable {
    let id: String
    let text: String
}

func alphaCompactPrivacyLabel(_ result: AlphaAskResult) -> String {
    if result.publicLawPreview != nil, result.publicLawResults.isEmpty {
        return rossLocalized("ask_privacy_label_review_pending")
    }
    if result.publicLawPreview != nil || !result.publicLawResults.isEmpty {
        return rossLocalized("ask_privacy_label_legal_search")
    }
    return rossLocalized("ask_privacy_label_on_device_only")
}

// Compile these regex patterns once instead of once per SwiftUI body re-eval.
// `AlphaFormattedAnswerText` is re-rendered every time a streamed answer
// token lands, so inline `.replacingOccurrences(of:..., options:.regularExpression)`
// was recompiling 5 regexes for every line of every render — a major
// per-frame cost on physical devices.
private let alphaAnswerHeadingRegex = try! NSRegularExpression(pattern: #"^\s*#{1,6}\s*"#)
private let alphaAnswerJSONPrefixRegex = try! NSRegularExpression(
    pattern: #"^\s*json\s*(?=\{)"#,
    options: [.caseInsensitive]
)
private let alphaAnswerBoldRegex = try! NSRegularExpression(pattern: #"\*\*(.*?)\*\*"#)
private let alphaAnswerQuoteRegex = try! NSRegularExpression(pattern: #"^>\s*"#)
private let alphaAnswerNumberedRegex = try! NSRegularExpression(pattern: #"^\d+\.\s"#)

private func alphaApplyRegex(_ regex: NSRegularExpression, to text: String, with replacement: String) -> String {
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
}

/// Renders answer text with basic formatting: bullets, numbered lists, and bold markers.
struct AlphaFormattedAnswerText: View {
    let text: String

    private struct AnswerLine: Identifiable {
        let id: Int
        let text: String
        let isBullet: Bool
        let bulletPrefix: String?
    }

    private var lines: [AnswerLine] {
        let rawLines = text.components(separatedBy: "\n")
        return rawLines.enumerated().compactMap { index, line in
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            trimmed = alphaApplyRegex(alphaAnswerHeadingRegex, to: trimmed, with: "")
            trimmed = alphaApplyRegex(alphaAnswerJSONPrefixRegex, to: trimmed, with: "")
            trimmed = alphaApplyRegex(alphaAnswerBoldRegex, to: trimmed, with: "$1")
            trimmed = trimmed.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if trimmed == "---" || trimmed == "```" { return nil }
            trimmed = alphaApplyRegex(alphaAnswerQuoteRegex, to: trimmed, with: "")
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("* ") {
                return AnswerLine(id: index, text: String(trimmed.dropFirst(2)), isBullet: true, bulletPrefix: "•")
            }
            let nsTrimmed = trimmed as NSString
            let nsRange = NSRange(location: 0, length: nsTrimmed.length)
            if let match = alphaAnswerNumberedRegex.firstMatch(in: trimmed, range: nsRange) {
                let matched = nsTrimmed.substring(with: match.range)
                let prefix = matched.trimmingCharacters(in: .whitespaces)
                let body = nsTrimmed.substring(from: match.range.upperBound)
                return AnswerLine(id: index, text: body, isBullet: true, bulletPrefix: prefix)
            }
            return AnswerLine(id: index, text: trimmed, isBullet: false, bulletPrefix: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines) { line in
                if line.isBullet {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(line.bulletPrefix ?? "•")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossAccent.opacity(0.7))
                            .frame(width: 18, alignment: .trailing)
                        Text(line.text)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(line.text)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

extension AlphaAskResult {
    var stableIdentity: String {
        if let chatTurnID {
            return chatTurnID.uuidString
        }
        return "\(kind.rawValue)|\(question)|\(answerTitle)"
    }

    var privacyReceipt: String {
        if publicLawPreview != nil, publicLawResults.isEmpty {
            return rossLocalized("ask_privacy_receipt_review_pending")
        }
        if publicLawPreview != nil, !publicLawResults.isEmpty, !caseFileSources.isEmpty {
            return rossLocalized("ask_privacy_receipt_files_and_legal_search")
        }
        if publicLawPreview != nil || !publicLawResults.isEmpty {
            return rossLocalized("ask_privacy_receipt_legal_search")
        }
        return rossLocalized("ask_privacy_receipt_on_device_only")
    }

    var isPendingLocalModelResponse: Bool {
        (answerTitle == "Ross is answering..." || rossSupportedLanguageCodes().contains { answerTitle == rossLocalized("ask_ross_answering_pending", languageCode: $0) })
            && alphaPendingLocalModelLabel(from: statusNote) != nil
            && publicLawPreview == nil
            && publicLawResults.isEmpty
    }

    var pendingLocalModelLabel: String? {
        guard isPendingLocalModelResponse else { return nil }
        return alphaPendingLocalModelLabel(from: statusNote)
    }

    var hasAnswerDetails: Bool {
        guard let modelInvocation else { return false }
        return modelInvocation.estimatedProcessedTokens != nil ||
            modelInvocation.estimatedOutputTokensPerSecond != nil ||
            modelInvocation.timeToFirstTokenMs != nil
    }

    var answerContinuationContext: AlphaAnswerContinuationContext? {
        guard let sourceRef = caseFileSources.first(where: { $0.effectiveSourceCategory == .documentSource }) ?? caseFileSources.first else {
            return nil
        }
        let normalizedQuestion = question.lowercased()
        if normalizedQuestion.contains("next page") || normalizedQuestion.contains("following page") {
            return AlphaAnswerContinuationContext(iconName: "arrow.down.right", label: sourceRef.label)
        }
        if normalizedQuestion.contains("previous page") ||
            normalizedQuestion.contains("prior page") ||
            normalizedQuestion.contains("page before") {
            return AlphaAnswerContinuationContext(iconName: "arrow.up.left", label: sourceRef.label)
        }
        if normalizedQuestion.contains("exact quote") ||
            normalizedQuestion.contains("quote exactly") ||
            normalizedQuestion.contains("quote that") ||
            normalizedQuestion.contains("quote this") {
            return AlphaAnswerContinuationContext(iconName: "text.quote", label: sourceRef.label)
        }
        if normalizedQuestion.contains("which page") ||
            normalizedQuestion.contains("what page") ||
            normalizedQuestion.contains("where does it say") ||
            normalizedQuestion.contains("show me the source") ||
            normalizedQuestion.contains("show the source") ||
            normalizedQuestion.contains("cite that") ||
            normalizedQuestion.contains("cite this") ||
            normalizedQuestion.contains("which file") ||
            normalizedQuestion.contains("which document") {
            return AlphaAnswerContinuationContext(iconName: "doc.text", label: sourceRef.label)
        }
        return nil
    }

    func answerSectionItems(limit: Int? = nil) -> [AlphaAnswerSectionItem] {
        let displaySections = AlphaMatterAskPayloadParser.displaySections(from: answerSections)
        let sections = limit.map { Array(displaySections.prefix($0)) } ?? displaySections
        return sections.enumerated().map { index, section in
            AlphaAnswerSectionItem(id: "\(stableIdentity)-section-\(index)", text: section)
        }
    }
}

extension AlphaLocalModelInvocation {
    var estimatedProcessedTokens: Int? {
        let components = [estimatedInputTokens, estimatedOutputTokens].compactMap { $0 }
        guard !components.isEmpty else { return nil }
        return components.reduce(0, +)
    }
}

func alphaUsesHindiUi() -> Bool {
    rossSelectedLanguageCode().hasPrefix("hi")
}

func alphaAskEmptyTitle(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("ask_empty_title", languageCode: languageCode)
}

func alphaAskEmptyDetail(
    scopeLabel: String?,
    selectedDocumentCount: Int,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    if selectedDocumentCount > 0 {
        let key = selectedDocumentCount == 1
            ? "ask_empty_detail_selected_file_one"
            : "ask_empty_detail_selected_files_many"
        return String(
            format: rossLocalized(key, languageCode: languageCode),
            selectedDocumentCount
        )
    }
    if let scopeLabel = scopeLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
       !scopeLabel.isEmpty {
        return String(
            format: rossLocalized("ask_empty_detail_matter", languageCode: languageCode),
            scopeLabel
        )
    }
    return rossLocalized("ask_empty_detail_general", languageCode: languageCode)
}

func alphaAskConversationPlaceholder(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("ask_conversation_placeholder", languageCode: languageCode)
}

func alphaAskTagFileHint(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("ask_tag_file_hint", languageCode: languageCode)
}

func alphaShowSourcesLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("show_sources_count", languageCode: languageCode), count)
}

func alphaTaggedFileLine(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("tagged_file_line", languageCode: languageCode), title)
}

func alphaTaggedFilesLine(_ titles: [String], languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("tagged_files_line", languageCode: languageCode), titles.joined(separator: ", "))
}

func alphaLocalModelRunningLabel(_ label: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("local_model_running_on_phone", languageCode: languageCode), label)
}

func alphaAskSuggestions(
    for scopeLabel: String?,
    documentTitle: String? = nil,
    languageCode: String = rossSelectedLanguageCode()
) -> [String] {
    let hasDocument = documentTitle?.isEmpty == false
    let hasScope = scopeLabel?.isEmpty == false
    let kind: AlphaAskSuggestionKind = hasDocument ? .document : (hasScope ? .matter : .general)
    return alphaLocalizedAskSuggestions(kind: kind, languageCode: languageCode)
}

private enum AlphaAskSuggestionKind {
    case document
    case matter
    case general
}

private func alphaLocalizedAskSuggestions(kind: AlphaAskSuggestionKind, languageCode: String) -> [String] {
    let normalizedCode = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
    let table: [String: [AlphaAskSuggestionKind: [String]]] = [
        "en": [
            .document: [
                "Summarize this document",
                "Extract court directions",
                "Find dates and deadlines",
                "What should I verify?",
                "Create tasks from this document",
            ],
            .matter: [
                "Prepare hearing note",
                "List next dates and deadlines",
                "Show unconfirmed facts",
                "Summarize latest order",
                "Create tasks from latest document"
            ],
            .general: [
                "What needs my attention today?",
                "Show upcoming hearing dates",
                "Which items need confirmation?",
                "Create a task"
            ]
        ],
        "hi": [
            .document: [
                "इस दस्तावेज़ का सार बताओ",
                "अदालत ने क्या निर्देश दिए?",
                "इस दस्तावेज़ से कार्य बनाओ",
                "क्या पुष्टि करनी है?"
            ],
            .matter: [
                "इस मामले का सार बताओ",
                "हियरिंग नोट तैयार करो",
                "महत्वपूर्ण तारीखें बताओ",
                "कौन से कार्य बनाने चाहिए?"
            ],
            .general: [
                "आज मुझे किस पर ध्यान देना है?",
                "कार्य जोड़ो",
                "अगली तारीख सहेजो",
                "केस नोट बनाओ"
            ]
        ],
        "bn": [
            .document: [
                "এই নথির সারাংশ দিন",
                "আদালতের নির্দেশ বের করুন",
                "তারিখ ও সময়সীমা খুঁজুন",
                "কী যাচাই করতে হবে?"
            ],
            .matter: [
                "শুনানির নোট তৈরি করুন",
                "পরের তারিখ ও সময়সীমা দেখান",
                "অনিশ্চিত তথ্য দেখান",
                "সাম্প্রতিক আদেশের সারাংশ দিন"
            ],
            .general: [
                "আজ কোন কাজে নজর দেব?",
                "আসন্ন শুনানির তারিখ দেখান",
                "কোন তথ্য যাচাই দরকার?",
                "একটি কাজ তৈরি করুন"
            ]
        ],
        "ta": [
            .document: [
                "இந்த ஆவணத்தை சுருக்கவும்",
                "நீதிமன்ற உத்தரவுகளை எடுக்கவும்",
                "தேதிகள் மற்றும் காலக்கெடுகளை கண்டறியவும்",
                "எதை சரிபார்க்க வேண்டும்?"
            ],
            .matter: [
                "விசாரணை குறிப்பை தயாரிக்கவும்",
                "அடுத்த தேதிகள் மற்றும் காலக்கெடுகளை பட்டியலிடவும்",
                "உறுதிப்படுத்தாத விவரங்களை காட்டவும்",
                "சமீபத்திய உத்தரவை சுருக்கவும்"
            ],
            .general: [
                "இன்று என்ன கவனிக்க வேண்டும்?",
                "வரவிருக்கும் விசாரணை தேதிகளை காட்டவும்",
                "எந்த விவரங்களுக்கு உறுதி தேவை?",
                "ஒரு பணியை உருவாக்கவும்"
            ]
        ],
        "te": [
            .document: [
                "ఈ పత్రాన్ని సారాంశం చేయండి",
                "కోర్టు ఆదేశాలను తీసుకోండి",
                "తేదీలు మరియు గడువులను కనుగొనండి",
                "నేను ఏమి ధృవీకరించాలి?"
            ],
            .matter: [
                "విచారణ గమనికను సిద్ధం చేయండి",
                "తదుపరి తేదీలు మరియు గడువులను జాబితా చేయండి",
                "ధృవీకరించని విషయాలను చూపండి",
                "తాజా ఆదేశాన్ని సారాంశం చేయండి"
            ],
            .general: [
                "ఈ రోజు నేను దేనిపై దృష్టి పెట్టాలి?",
                "రాబోయే విచారణ తేదీలను చూపండి",
                "ఏ అంశాలకు ధృవీకరణ అవసరం?",
                "ఒక పనిని సృష్టించండి"
            ]
        ]
    ]
    return table[normalizedCode]?[kind] ?? table["en"]?[kind] ?? []
}

enum AlphaMatterTimelineEntry: Identifiable {
    case date(AlphaMatterDate)
    case task(AlphaTaskItem)

    var id: String {
        switch self {
        case .date(let matterDate):
            "date-\(matterDate.id.uuidString)"
        case .task(let task):
            "task-\(task.id.uuidString)"
        }
    }

    var sortDate: Date? {
        switch self {
        case .date(let matterDate):
            matterDate.date
        case .task(let task):
            task.dueDate
        }
    }

    var sortTitle: String {
        switch self {
        case .date(let matterDate):
            matterDate.title
        case .task(let task):
            task.title
        }
    }
}

func alphaMatterTimelineEntries(dates: [AlphaMatterDate], tasks: [AlphaTaskItem]) -> [AlphaMatterTimelineEntry] {
    (dates.map(AlphaMatterTimelineEntry.date) + tasks.map(AlphaMatterTimelineEntry.task))
        .sorted { lhs, rhs in
            switch (lhs.sortDate, rhs.sortDate) {
            case let (left?, right?):
                if left == right {
                    return lhs.sortTitle.localizedCaseInsensitiveCompare(rhs.sortTitle) == .orderedAscending
                }
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.sortTitle.localizedCaseInsensitiveCompare(rhs.sortTitle) == .orderedAscending
            }
        }
}
