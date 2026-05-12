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

private extension View {
    @ViewBuilder
    func alphaThreadListStyle() -> some View {
        #if os(macOS)
        listStyle(.inset)
        #else
        listStyle(.insetGrouped)
        #endif
    }
}

struct AlphaAskConversationScreen: View {
    @Bindable var model: AlphaRossModel
    let fixedScopeCaseID: UUID?
    @State private var selectedScopeCaseID: UUID?
    @State private var showingThreads = false
    @State private var showingTools = false
    @State private var pendingImportKind: AlphaDockImportKind?
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
        guard case let .success(urls) = result, let url = urls.first else { return }
        let scopeCaseID = activeScopeCaseID
        Task {
            await model.importDocument(caseId: scopeCaseID, from: url, openAfterImport: false)
        }
    }

    var body: some View {
        let conversation = conversation
        let contextDocumentTitle = model.askDocumentTitle(for: activeScopeCaseID)

        VStack(spacing: 0) {
            AlphaFullScreenChatTopBar(
                scopeTitle: scopeTitle,
                cases: allScopeCases,
                onBack: goBack,
                onSelectScope: switchScope,
                onShowThreads: { showingThreads = true }
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                if conversation.isEmpty {
                    Spacer(minLength: 120)
                    Text("Ask Ross...")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.42))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 120)
                } else {
                    ForEach(conversation, id: \.stableIdentity) { result in
                        AlphaFullScreenChatTurn(
                            result: result,
                            contextDocumentTitle: contextDocumentTitle,
                            onOpenSource: model.openSourceRef
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                }
            }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .animation(.snappy(duration: 0.3), value: conversation.count)
            }
            .alphaDismissesKeyboardOnScroll()

            AlphaFullScreenChatComposer(
                text: draftBinding,
                canSend: canSend,
                resetToken: composerResetToken,
                focused: $composerFocused,
                onShowTools: { showingTools = true },
                onSend: send
            )
        }
        .background(Color.rossGroupedBackground.ignoresSafeArea())
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
        .fileImporter(
            isPresented: Binding(
                get: { pendingImportKind != nil },
                set: { if !$0 { pendingImportKind = nil } }
            ),
            allowedContentTypes: pendingImportKind?.allowedTypes ?? [.pdf, .plainText, .image],
            allowsMultipleSelection: false,
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
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.rossInk)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer(minLength: 0)

            Menu {
                Button("Ross") { onSelectScope(nil) }
                ForEach(cases) { caseMatter in
                    Button(caseMatter.title) { onSelectScope(caseMatter.id) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(scopeTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.rossInk.opacity(0.45))
                }
                .frame(maxWidth: 220)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose chat scope")

            Spacer(minLength: 0)

            Button(action: onShowThreads) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.rossInk)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Threads")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color.rossGroupedBackground.opacity(0.96))
    }
}

struct AlphaFullScreenChatComposer: View {
    @Binding var text: String
    let canSend: Bool
    let resetToken: UUID
    var focused: FocusState<Bool>.Binding
    let onShowTools: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onShowTools) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .frame(width: 40, height: 40)
                    .background(Color.rossCardBackground, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.rossBorder.opacity(0.74), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add files or images")

            TextField("Ask Ross...", text: $text, axis: .vertical)
                .id(resetToken)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.rossInk)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.rossCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.rossBorder.opacity(0.74), lineWidth: 1)
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? Color.rossCardBackground : Color.rossInk.opacity(0.44))
                    .frame(width: 40, height: 40)
                    .background(canSend ? Color.rossAccent : Color.rossSecondaryGroupedBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.rossGroupedBackground.opacity(0.98))
    }
}

struct AlphaFullScreenChatTurn: View {
    let result: AlphaAskResult
    let contextDocumentTitle: String?
    let onOpenSource: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !result.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Spacer(minLength: 46)
                    Text(result.question)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Color.rossCardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(result.answerTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(result.answerSectionItems()) { section in
                    AlphaFormattedAnswerText(text: section.text)
                }

                ForEach(result.caseFileSources.prefix(3)) { sourceRef in
                    Button {
                        onOpenSource(sourceRef)
                    } label: {
                        Text("Source: \(alphaSourceRefDisplayLabel(sourceRef, contextDocumentTitle: contextDocumentTitle))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.rossGlassStroke.opacity(0.86), lineWidth: 1)
            }
            .contextMenu {
                Button {
                    alphaCopyAskResultToPasteboard(result)
                } label: {
                    Label("Copy answer", systemImage: "doc.on.doc")
                }
            }
        }
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
        return [(title: "Ross (General)", caseId: nil, sessions: general)] + matterGroups
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(scopedCases, id: \.title) { group in
                    if !group.sessions.isEmpty || group.caseId == activeScopeCaseID {
                        Section(group.title) {
                            ForEach(group.sessions) { session in
                                Button {
                                    onSelectThread(session, group.caseId)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(model.chatSessionTitle(session))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.rossInk)
                                            .lineLimit(1)
                                        Text(alphaRelativeThreadTime(session.updatedAt))
                                            .font(.caption)
                                            .foregroundStyle(Color.rossInk.opacity(0.54))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .alphaThreadListStyle()
            .navigationTitle("Threads")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onNewThread) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New thread")
                }
            }
        }
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
                        Text(suggestion)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.rossInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .padding(.horizontal, 13)
                            .background(Color.rossGlassSubtleFill)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: RossSurface.cornerRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: RossSurface.cornerRadius, style: .continuous)
                                    .stroke(Color.rossBorder.opacity(0.7), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Responses are a starting point — always verify with your own judgement.")
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.42))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                        .background(Color.rossCardBackground.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.rossBorder.opacity(0.6), lineWidth: 1)
                        }
                }
            } else {
                HStack(spacing: 8) {
                    RossGlassIconView(.badgeSparkle, variant: .accent, size: 16, fallbackSystemImage: "sparkles")
                    Text("Matter update")
                        .font(.caption.weight(.semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.rossAccent)
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(result.answerTitle)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Menu {
                            Button {
                                alphaCopyAskResultToPasteboard(result)
                            } label: {
                                Label("Copy answer", systemImage: "doc.on.doc")
                            }
                            Button(action: onReport) {
                                Label("Report answer", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.rossAccent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Answer actions")
                    }

                    let answerItems = result.answerSectionItems()
                    ForEach(Array(answerItems.enumerated()), id: \.element.id) { index, section in
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaFormattedAnswerText(text: section.text)
                            if index < answerItems.count - 1 {
                                Divider().overlay(Color.rossBorder.opacity(0.4))
                            }
                        }
                    }

                    if let note = deduplicatedStatusNote {
                        Text(note)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                    }

                    if !result.selectedDocumentTitles.isEmpty, contextDocumentTitle == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(result.selectedDocumentTitles, id: \.self) { title in
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
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaSectionLabel(title: "Sources", detail: "From your files on this device.")
                            if result.caseFileSources.count > 2 {
                                Button {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        sourcesExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(sourcesExpanded ? "Hide sources" : "Show \(result.caseFileSources.count) sources")
                                            .font(.footnote.weight(.semibold))
                                        Spacer(minLength: 8)
                                        Image(systemName: sourcesExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(Color.rossAccent)
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
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let preview = result.publicLawPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            AlphaSectionLabel(
                                title: "What Ross searched",
                                detail: result.publicLawResults.isEmpty ? "Awaiting your review. No web search used yet." : "Ross removed case details before searching."
                            )
                            Text(preview.query)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.82))
                        }
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if !result.publicLawResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaSectionLabel(title: "From Legal Search", detail: "Separate from your case files. Based on a cleaned search query.")
                            ForEach(result.publicLawResults) { publicResult in
                                AlphaPublicLawResultCard(result: publicResult)
                            }
                        }
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(alphaCompactPrivacyLabel(result))
                                .font(.caption2.weight(.semibold))
                            Spacer(minLength: 4)
                            Image(systemName: privacyExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.rossInk.opacity(0.52))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.rossSecondaryGroupedBackground, in: Capsule())
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
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.rossGlassFill)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.rossGlassStroke, lineWidth: 1)
                }

                Spacer(minLength: 40)
            }
        }
    }
}

struct AlphaAskToolbarButton: View {
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

struct AlphaSectionLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.74))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Color.rossInk.opacity(0.62))
        }
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
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct AlphaPublicLawResultCard: View {
    let result: AlphaPublicLawResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                AlphaTagChip(title: "Legal Search")
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
        .background(Color.rossGlassSubtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AlphaPublicLawWarningsView: View {
    let needsReviewWarning: String?
    let includePublicLawWarnings: Bool

    var body: some View {
        if includePublicLawWarnings || needsReviewWarning != nil {
            VStack(alignment: .leading, spacing: 4) {
                if includePublicLawWarnings {
                    Text("Legal Search results — verify citations before use.")
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
        return "On-device · review pending"
    }
    if result.publicLawPreview != nil || !result.publicLawResults.isEmpty {
        return "On-device + Legal Search"
    }
    return "On-device only"
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
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("* ") {
                return AnswerLine(id: index, text: String(trimmed.dropFirst(2)), isBullet: true, bulletPrefix: "•")
            }
            if let dotRange = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let prefix = String(trimmed[dotRange]).trimmingCharacters(in: .whitespaces)
                let body = String(trimmed[dotRange.upperBound...])
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
            return "Your files stay on this device. A public-law query is awaiting your review — nothing has been sent yet."
        }
        if publicLawPreview != nil, !publicLawResults.isEmpty, !caseFileSources.isEmpty {
            return "Ross used your local files and public-law results. Case details were removed before searching."
        }
        if publicLawPreview != nil || !publicLawResults.isEmpty {
            return "Ross used Legal Search after you approved. Your case files stayed on this device."
        }
        return "Answered using only your files on this device. Nothing was sent online."
    }

    func answerSectionItems(limit: Int? = nil) -> [AlphaAnswerSectionItem] {
        let displaySections = AlphaMatterAskPayloadParser.displaySections(from: answerSections)
        let sections = limit.map { Array(displaySections.prefix($0)) } ?? displaySections
        return sections.enumerated().map { index, section in
            AlphaAnswerSectionItem(id: "\(stableIdentity)-section-\(index)", text: section)
        }
    }
}

func alphaUsesHindiUi() -> Bool {
    rossSelectedLanguageCode().hasPrefix("hi")
}

func alphaAskEmptyTitle() -> String {
    alphaUsesHindiUi() ? "Ross से आगे का काम पूछें" : "Ask Ross what's next"
}

func alphaAskSuggestions(for scopeLabel: String?, documentTitle: String? = nil) -> [String] {
    if alphaUsesHindiUi() {
        if let documentTitle, !documentTitle.isEmpty {
            return [
                "इस दस्तावेज़ का सार बताओ",
                "अदालत ने क्या निर्देश दिए?",
                "इस दस्तावेज़ से कार्य बनाओ",
                "क्या पुष्टि करनी है?"
            ]
        }
        if let scopeLabel, !scopeLabel.isEmpty {
            return [
                "इस मामले का सार बताओ",
                "हियरिंग नोट तैयार करो",
                "महत्वपूर्ण तारीखें बताओ",
                "कौन से कार्य बनाने चाहिए?"
            ]
        }
        return [
            "आज मुझे किस पर ध्यान देना है?",
            "कार्य जोड़ो",
            "अगली तारीख सहेजो",
            "केस नोट बनाओ"
        ]
    }
    if let documentTitle, !documentTitle.isEmpty {
        return [
            "Summarize this document",
            "Extract court directions",
            "Find dates and deadlines",
            "What should I verify?",
            "Create tasks from this document",
        ]
    }
    if let scopeLabel, !scopeLabel.isEmpty {
        return [
            "Prepare hearing note",
            "List next dates and deadlines",
            "Show unconfirmed facts",
            "Summarize latest order",
            "Create tasks from latest document"
        ]
    }
    return [
        "What needs my attention today?",
        "Show upcoming hearing dates",
        "Which items need confirmation?",
        "Create a task"
    ]
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
