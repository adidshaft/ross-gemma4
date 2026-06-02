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

private var alphaNavigationBarLeadingPlacement: ToolbarItemPlacement {
    #if os(macOS)
    .automatic
    #else
    .navigationBarLeading
    #endif
}

private var alphaNavigationBarTrailingPlacement: ToolbarItemPlacement {
    #if os(macOS)
    .automatic
    #else
    .navigationBarTrailing
    #endif
}

private func alphaDocumentLanguage(forAppLanguageCode code: String) -> AlphaDocumentLanguage? {
    switch code.split(separator: "-").first.map(String.init) ?? code {
    case "en": .english
    case "hi": .hindi
    case "bn": .bengali
    case "ta": .tamil
    case "te": .telugu
    default: nil
    }
}

private func alphaDocumentLanguageDisplayName(_ language: AlphaDocumentLanguage) -> String {
    switch language {
    case .english: rossLanguageDisplayName(code: "en")
    case .hindi: rossLanguageDisplayName(code: "hi")
    case .bengali: rossLanguageDisplayName(code: "bn")
    case .tamil: rossLanguageDisplayName(code: "ta")
    case .telugu: rossLanguageDisplayName(code: "te")
    case .mixed: "Mixed language"
    case .unknown: "Unknown"
    }
}

private func alphaDocumentNeedsTranslation(_ document: AlphaCaseDocument, selectedLanguageCode: String) -> Bool {
    guard let profile = document.languageProfile else { return false }
    guard profile.primaryLanguage != .unknown else { return false }
    guard let selectedLanguage = alphaDocumentLanguage(forAppLanguageCode: selectedLanguageCode) else { return false }
    if profile.primaryLanguage == .mixed {
        return !profile.scriptsDetected.isEmpty
    }
    return profile.primaryLanguage != selectedLanguage
}

func alphaDocumentReadinessMessage(_ document: AlphaCaseDocument) -> String {
    if document.hasAskUsableExtractedText {
        switch document.processingState {
        case .imported, .readingText:
            return "Ross can answer from extracted text now. Deeper review is still running in the background."
        case .needsConfirmation, .reviewingFindings:
            return "Ross can answer from extracted text now. Review the highlighted findings before relying on this file in notes or exports."
        case .ready:
            return "Ross can answer from extracted text now. Verified details are ready for notes, tasks, and exports."
        case .failed:
            return "Ross can answer from extracted text now, but full review did not finish. Check the source before relying on this file."
        }
    }
    if document.isAwaitingReadableText {
        return "Ross is still reading this file. Ask will be available as soon as text is extracted."
    }
    return "Ross could not find readable text in this file yet. Review again, re-import a clearer file, or choose another file for Ask."
}

struct AlphaDocumentListScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var showingImporter = false
    @State private var documentLayoutMode: AlphaDocumentLayoutMode = .grid
    @State private var expandedDocumentIDs: Set<UUID> = []

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: caseMatter?.forum ?? "Documents",
                    title: caseMatter?.title ?? "Documents",
                    detail: "\(alphaFileCountLabel(caseMatter?.documents.count ?? 0)) in this matter"
                )

                RossSectionCard {
                    HStack {
                        Text("\(alphaFileCountLabel(caseMatter?.documents.count ?? 0)) stored for this matter")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.7))

                        Spacer(minLength: 0)

                        AlphaDocumentLayoutMenu(layoutMode: $documentLayoutMode)
                    }
                }

                Button("Import document") {
                    showingImporter = true
                }
                .rossPrimaryButtonStyle()

                if let caseMatter, caseMatter.documents.isEmpty {
                    RossSectionCard {
                        Text("Import the first order, pleading, notice, or note for this matter.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }

                if let documents = caseMatter?.documents, !documents.isEmpty {
                    AlphaDocumentCollectionView(
                        documents: documents,
                        caseTitle: nil,
                        layoutMode: documentLayoutMode,
                        expandedDocumentIDs: $expandedDocumentIDs,
                        onOpen: { documentId in
                            model.path.append(.documentViewer(caseId, documentId, 1))
                        },
                        onMoveDocument: { documentId, offset in
                            model.moveDocument(caseId: caseId, documentId: documentId, by: offset)
                        },
                        onOpenChat: { documentId in
                            model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false)
                        },
                        onStartReviewChat: { documentId in
                            model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: true)
                        }
                    )
                }
            }
            .padding(alphaScreenPadding)
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
        .navigationTitle("Documents")
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: "Open Ask Ross") {
                    model.openAsk(scopeCaseID: caseId)
                }
            }
        }
    }
}

struct AlphaDocumentViewerScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    let documentId: UUID
    let initialPage: Int?
    @State private var rawTextExpanded = false
    @State private var sourceDetailsExpanded = false
    @State private var otherDetailsExpanded = false
    @State private var advocateNoteDraft = ""
    @State private var loadedAdvocateNoteDocumentID: UUID?
    @AppStorage("ross.dismissedDocumentTitleSuggestionIDs") private var dismissedTitleSuggestionRaw = ""

    private var isSharedDocument: Bool {
        caseId == alphaSharedWorkspaceID
    }

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first(where: { $0.id == caseId })
    }

    private var document: AlphaCaseDocument? {
        caseMatter?.documents.first(where: { $0.id == documentId })
    }

    private var sourceRefs: [AlphaSourceRef] {
        caseMatter?.sourceRefs.filter { $0.documentId == documentId } ?? []
    }

    private var resolvedPage: Int {
        let upperBound = max(document?.pageCount ?? 1, 1)
        return min(max(initialPage ?? sourceRefs.first?.pageNumber ?? 1, 1), upperBound)
    }

    private var currentPageRefs: [AlphaSourceRef] {
        sourceRefs.filter { $0.pageNumber == resolvedPage }
    }

    private var displayedSourceRefs: [AlphaSourceRef] {
        currentPageRefs.isEmpty ? sourceRefs : currentPageRefs
    }

    private var reviewSummaryText: String? {
        model.reviewSummary(caseId: caseId, documentId: documentId)
    }

    private var activeExtractionRun: AlphaExtractionRun? {
        document?.extractionRuns.sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast) > (rhs.startedAt ?? .distantPast)
        }.first
    }

    private var reviewFields: [AlphaExtractedLegalField] {
        model.visibleExtractedFields(caseId: caseId, documentId: documentId)
    }

    private var sortedReviewFields: [AlphaExtractedLegalField] {
        reviewFields.sorted { alphaFieldSortRank($0.fieldType) < alphaFieldSortRank($1.fieldType) }
    }

    private var actionableReviewFields: [AlphaExtractedLegalField] {
        sortedReviewFields.filter(\.needsReview)
    }

    private var acceptedReviewFields: [AlphaExtractedLegalField] {
        sortedReviewFields.filter { !$0.needsReview }
    }

    private var importantReviewFields: [AlphaExtractedLegalField] {
        actionableReviewFields.filter { alphaIsImportantReviewField($0.fieldType) }
    }

    private var detailReviewFields: [AlphaExtractedLegalField] {
        actionableReviewFields.filter { !alphaIsImportantReviewField($0.fieldType) }
    }

    private var reviewFindings: [AlphaExtractionFinding] {
        model.reviewFindings(caseId: caseId, documentId: documentId)
    }

    private var needsReviewCount: Int {
        reviewFields.filter(\.needsReview).count + reviewFindings.count
    }

    private var matterLabel: String {
        guard !isSharedDocument else { return "General files" }
        return caseMatter?.title ?? "Matter"
    }

    private var suggestedTitle: String? {
        guard let document else { return nil }
        guard !dismissedTitleSuggestionIDs.contains(document.id) else { return nil }
        return model.suggestedDocumentTitle(caseId: caseId, documentId: documentId)
    }

    private var dismissedTitleSuggestionIDs: Set<UUID> {
        Set(
            dismissedTitleSuggestionRaw
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        )
    }

    private func dismissTitleSuggestion(for documentID: UUID) {
        var ids = dismissedTitleSuggestionIDs
        ids.insert(documentID)
        dismissedTitleSuggestionRaw = ids
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    private func syncAdvocateNoteDraftIfNeeded(document: AlphaCaseDocument) {
        guard loadedAdvocateNoteDocumentID != document.id else { return }
        advocateNoteDraft = document.advocateNote ?? ""
        loadedAdvocateNoteDocumentID = document.id
    }

    private func saveAdvocateNote() {
        model.updateDocumentAdvocateNote(caseId: caseId, documentId: documentId, note: advocateNoteDraft)
    }

    private func exitDocument() {
        guard !model.path.isEmpty else { return }
        model.path.removeLast()
    }

    var body: some View {
        ScrollView {
            if let document {
                VStack(alignment: .leading, spacing: 16) {
                    AlphaInlineHeader(
                        eyebrow: document.kind.title,
                        title: document.title,
                        detail: "\(matterLabel) · \(alphaPageCountLabel(document.pageCount)) · \(document.lawyerStatusTitle)"
                    )

                    if let classification = document.classification {
                        AlphaDocumentTypePill(
                            type: classification.type,
                            confidenceLabel: alphaConfidenceLabel(
                                confidence: classification.confidence,
                                needsReview: classification.needsReview
                            )
                        )
                    }

                    AlphaDocumentReviewStatusBanner(
                        state: document.processingState,
                        needsReviewCount: needsReviewCount,
                        detail: alphaDocumentReviewBannerDetail(
                            run: activeExtractionRun,
                            fallback: alphaDocumentFallbackReviewDetail(document: document, needsReviewCount: needsReviewCount)
                        ),
                        isWorking: alphaExtractionRunIsWorking(activeExtractionRun),
                        progressLabel: alphaExtractionProgressLabel(activeExtractionRun),
                        progressValue: alphaExtractionProgressValue(activeExtractionRun)
                    )

                    if alphaDocumentNeedsTranslation(document, selectedLanguageCode: rossSelectedLanguageCode()) {
                        AlphaDocumentTranslationCard(
                            documentLanguage: alphaDocumentLanguageDisplayName(document.languageProfile?.primaryLanguage ?? .unknown),
                            targetLanguage: rossLanguageDisplayName(code: rossSelectedLanguageCode()),
                            isAssistantReady: model.activeRuntimeHealth?.available == true,
                            onTranslate: {
                                model.prepareDocumentTranslation(
                                    caseId: caseId,
                                    documentId: document.id,
                                    targetLanguageCode: rossSelectedLanguageCode()
                                )
                            },
                            onSetupAssistant: {
                                model.path.append(.privateAISettings)
                            }
                        )
                    }

                    if let suggestedTitle {
                        AlphaDocumentTitleSuggestionCard(
                            suggestedTitle: suggestedTitle,
                            originalFileName: (document.fileName as NSString).deletingPathExtension,
                            onAccept: {
                                alphaHaptic(.medium)
                                model.updateDocumentTitle(caseId: caseId, documentId: documentId, title: suggestedTitle)
                                dismissTitleSuggestion(for: document.id)
                            },
                            onSaveEdit: { title in
                                alphaHaptic(.medium)
                                model.updateDocumentTitle(caseId: caseId, documentId: documentId, title: title)
                                dismissTitleSuggestion(for: document.id)
                            },
                            onKeepOriginal: {
                                alphaHaptic(.light)
                                model.updateDocumentTitle(
                                    caseId: caseId,
                                    documentId: documentId,
                                    title: (document.fileName as NSString).deletingPathExtension
                                )
                                dismissTitleSuggestion(for: document.id)
                            }
                        )
                    }

                    if let preview = AlphaDocumentPreview(document: document, initialPage: resolvedPage) {
                        preview
                    }

                    if let reviewSummaryText {
                        AlphaDocumentReviewWorkbenchCard(title: "What Ross found", subtitle: reviewSummaryText) {
                            VStack(alignment: .leading, spacing: 14) {
                                if document.classification?.needsReview == true || !importantReviewFields.isEmpty || !reviewFindings.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top, spacing: 10) {
                                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                                .fill(Color.orange.opacity(0.76))
                                                .frame(width: alphaReviewAccentWidth)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Important")
                                                    .font(.caption.weight(.bold))
                                                    .textCase(.uppercase)
                                                    .foregroundStyle(Color.rossInk.opacity(0.62))
                                                Text("Check details that can change dates, parties, filing position, or what happens next.")
                                                    .font(.caption)
                                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }

                                        if let classification = document.classification, classification.needsReview {
                                            AlphaClassificationReviewCard(
                                                classification: classification,
                                                contextDocumentTitle: document.title,
                                                onAccept: {
                                                    model.updateDocumentClassification(
                                                        caseId: caseId,
                                                        documentId: documentId,
                                                        type: classification.type
                                                    )
                                                },
                                                onUpdateType: { type in
                                                    model.updateDocumentClassification(
                                                        caseId: caseId,
                                                        documentId: documentId,
                                                        type: type
                                                    )
                                                },
                                                onOpenSourceRef: model.openSourceRef
                                            )
                                        }

                                        ForEach(importantReviewFields) { field in
                                            AlphaExtractedFieldReviewCard(
                                                field: field,
                                                contextDocumentTitle: document.title,
                                                onAccept: {
                                                    model.acceptExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                                },
                                                onSaveEdit: { newValue in
                                                    model.applyFieldCorrection(caseId: caseId, documentId: documentId, fieldId: field.id, newValue: newValue)
                                                },
                                                onIgnore: {
                                                    model.ignoreExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                                },
                                                onOpenSourceRef: model.openSourceRef
                                            )
                                        }

                                        ForEach(reviewFindings) { finding in
                                            AlphaFindingCard(
                                                finding: finding,
                                                contextDocumentTitle: document.title,
                                                onKeepMatterValue: {
                                                    model.resolveFinding(caseId: caseId, documentId: documentId, findingId: finding.id, resolution: "Kept matter value")
                                                },
                                                onUseFileValue: {
                                                    model.useFileValueForConflict(caseId: caseId, documentId: documentId, findingId: finding.id)
                                                },
                                                onSaveAlternate: {
                                                    model.saveConflictAsAlternateReference(caseId: caseId, documentId: documentId, findingId: finding.id)
                                                },
                                                onIgnore: {
                                                    model.resolveFinding(caseId: caseId, documentId: documentId, findingId: finding.id, resolution: "Ignored")
                                                },
                                                onOpenSourceRef: model.openSourceRef
                                            )
                                        }
                                    }
                                }

                                if !acceptedReviewFields.isEmpty || (document.classification?.needsReview == false && document.classification != nil) {
                                    AlphaAcceptedReviewSummaryCard(
                                        classification: document.classification,
                                        fields: acceptedReviewFields
                                    )
                                }

                                if !detailReviewFields.isEmpty {
                                    DisclosureGroup(isExpanded: $otherDetailsExpanded) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Helpful details you can accept, edit, or ignore after the essentials are clear.")
                                                .font(.footnote)
                                                .foregroundStyle(Color.rossInk.opacity(0.65))

                                            ForEach(detailReviewFields) { field in
                                                AlphaExtractedFieldReviewCard(
                                                    field: field,
                                                    contextDocumentTitle: document.title,
                                                    onAccept: {
                                                        model.acceptExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                                    },
                                                    onSaveEdit: { newValue in
                                                        model.applyFieldCorrection(caseId: caseId, documentId: documentId, fieldId: field.id, newValue: newValue)
                                                    },
                                                    onIgnore: {
                                                        model.ignoreExtractedField(caseId: caseId, documentId: documentId, fieldId: field.id)
                                                    },
                                                    onOpenSourceRef: model.openSourceRef
                                                )
                                            }
                                        }
                                        .padding(.top, 10)
                                    } label: {
                                        HStack {
                                            Text("Other details")
                                                .font(.headline)
                                                .foregroundStyle(Color.rossInk)
                                            Spacer()
                                            Text("\(detailReviewFields.count)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.rossAccent)
                                        }
                                    }
                                    .tint(Color.rossAccent)
                                    .padding(12)
                                    .rossGlassSurface(cornerRadius: 16, strokeOpacity: 0.52)
                                }

                                if let upgrade = model.extractionUpgradeMessage(for: document) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(upgrade)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.rossAccent)

                                        Button("Run better extraction") {
                                            model.path.append(.privateAISettings)
                                        }
                                        .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                                    }
                                }
                            }
                        }
                    }

                    if sourceDetailsExpanded || rawTextExpanded {
                        AlphaDocumentInspectCard(
                            documentTitle: document.title,
                            extractedText: document.extractedText,
                            sourceRefs: displayedSourceRefs,
                            sourceDetailsExpanded: $sourceDetailsExpanded,
                            rawTextExpanded: $rawTextExpanded,
                            onOpenSourceRef: model.openSourceRef
                        )
                    }

                    if !sourceDetailsExpanded && !rawTextExpanded {
                        AlphaDocumentInspectCard(
                            documentTitle: document.title,
                            extractedText: document.extractedText,
                            sourceRefs: displayedSourceRefs,
                            sourceDetailsExpanded: $sourceDetailsExpanded,
                            rawTextExpanded: $rawTextExpanded,
                            onOpenSourceRef: model.openSourceRef
                        )
                    }

                    AlphaDocumentAdvocateNoteCard(
                        note: $advocateNoteDraft,
                        onSave: saveAdvocateNote,
                        onAskRoss: {
                            model.openDocumentInChat(caseId: caseId, documentId: document.id, startNewThread: false)
                        },
                        onReviewAgain: {
                            Task { await model.rerunReview(caseId: caseId, documentId: documentId) }
                        }
                    )
                }
                .padding(.horizontal, alphaDocumentScreenHorizontalPadding)
                .padding(.vertical, alphaScreenPadding)
            }
        }
        .onAppear {
            if let document {
                syncAdvocateNoteDraftIfNeeded(document: document)
            }
        }
        .onChange(of: document?.id) { _, _ in
            if let document {
                syncAdvocateNoteDraftIfNeeded(document: document)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28, coordinateSpace: .local)
                .onEnded { value in
                    guard value.translation.width > 96,
                          abs(value.translation.width) > abs(value.translation.height) * 1.35 else { return }
                    withAnimation(.snappy(duration: 0.22)) {
                        exitDocument()
                    }
                }
        )
        .navigationTitle(document?.title ?? "Document")
        .navigationBarBackButtonHidden(true)
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: alphaNavigationBarLeadingPlacement) {
                Button(action: exitDocument) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.rossInk)
                        .frame(width: 32, height: 32)
                        .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 2, strokeOpacity: 0.48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: alphaNavigationBarTrailingPlacement) {
                HStack(spacing: 8) {
                    Button {
                        model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false)
                    } label: {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 32, height: 32)
                            .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 2, strokeOpacity: 0.48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ask Ross about this document")

                    Button {
                        Task { await model.rerunReview(caseId: caseId, documentId: documentId) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 32, height: 32)
                            .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 2, strokeOpacity: 0.48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review document again")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if let document, document.processingState == .readingText || document.processingState == .imported {
                    Text(alphaDocumentReadinessMessage(document))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .rossGlassSurface(
                            tint: document.hasAskUsableExtractedText ? Color.rossSuccess : Color.rossAccent,
                            cornerRadius: 16,
                            shadowOpacity: 0.08,
                            shadowRadius: 8,
                            shadowY: 3,
                            fillOpacity: 0.84,
                            strokeOpacity: 0.48
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
    }
}

struct AlphaDocumentReviewWorkbenchCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.rossSerifHeadline())
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .rossGlassSurface(
            tint: Color.rossHighlight,
            cornerRadius: RossSurface.cornerRadius,
            shadowOpacity: 0.08,
            shadowRadius: 9,
            shadowY: 4,
            fillOpacity: 0.84,
            strokeOpacity: 0.50
        )
    }
}

struct AlphaDocumentTranslationCard: View {
    let documentLanguage: String
    let targetLanguage: String
    let isAssistantReady: Bool
    let onTranslate: () -> Void
    let onSetupAssistant: () -> Void

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "translate")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.rossAccent)
                        .frame(width: 30, height: 30)
                        .background(Color.rossAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Document language: \(documentLanguage)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(isAssistantReady ? rossLocalized("translation_ready") : rossLocalized("translation_needs_assistant"))
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Button {
                    isAssistantReady ? onTranslate() : onSetupAssistant()
                } label: {
                    Label(
                        isAssistantReady
                            ? String(format: rossLocalized("translate_to"), targetLanguage)
                            : rossLocalized("setup_assistant"),
                        systemImage: isAssistantReady ? "sparkles" : "arrow.down.circle"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))
            }
        }
    }
}

struct AlphaDocumentTypePill: View {
    let type: AlphaLegalDocumentType
    let confidenceLabel: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(alphaDocumentTypeTint(type).opacity(0.9))
                .frame(width: 7, height: 7)

            Text(type.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(alphaDocumentTypeTint(type))

            Text(confidenceLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.58))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(alphaDocumentTypeTint(type).opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(alphaDocumentTypeTint(type).opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AlphaDocumentTitleSuggestionCard: View {
    let suggestedTitle: String
    let originalFileName: String
    let onAccept: () -> Void
    let onSaveEdit: (String) -> Void
    let onKeepOriginal: () -> Void
    @State private var isEditing = false
    @State private var draftTitle = ""

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.rossAccent)
                        .frame(width: 28, height: 28)
                        .background(Color.rossAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ross suggests a clearer name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                        Text("Keep the file name, accept this label, or edit it before saving.")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isEditing {
                    TextField("Document name", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .padding(10)
                        .rossGlassSurface(cornerRadius: 12, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.48)
                } else {
                    Text(suggestedTitle)
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if isEditing {
                        Button("Save") {
                            onSaveEdit(draftTitle)
                            isEditing = false
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                        Button("Cancel") {
                            draftTitle = suggestedTitle
                            isEditing = false
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle())
                    } else {
                        Button("Accept", action: onAccept)
                            .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                        Button("Edit") {
                            draftTitle = suggestedTitle
                            isEditing = true
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle())

                        Button("Keep \(originalFileName)", action: onKeepOriginal)
                            .buttonStyle(AlphaReviewActionButtonStyle())
                    }
                }
            }
            .onAppear {
                if draftTitle.isEmpty {
                    draftTitle = suggestedTitle
                }
            }
            .onChange(of: suggestedTitle) { _, newValue in
                guard !isEditing else { return }
                draftTitle = newValue
            }
        }
    }
}

struct AlphaAcceptedReviewSummaryCard: View {
    let classification: AlphaLegalDocumentClassification?
    let fields: [AlphaExtractedLegalField]

    private var acceptedCount: Int {
        fields.count + (classification?.needsReview == false ? 1 : 0)
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ross will use these confirmed details when preparing notes, tasks, and matter answers.")
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                if let classification, !classification.needsReview {
                    AlphaDocumentTypePill(
                        type: classification.type,
                        confidenceLabel: alphaConfidenceLabel(
                            confidence: classification.confidence,
                            needsReview: classification.needsReview
                        )
                    )
                }

                ForEach(Array(fields.prefix(5))) { field in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(field.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.58))
                            .frame(minWidth: 78, alignment: .leading)
                        Text(field.value)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.82))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.rossSuccess)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirmed for Ross")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text("Details already approved for this matter")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                }
                .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(acceptedCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossSuccess)
            }
        }
        .tint(Color.rossSuccess)
        .padding(12)
        .rossGlassSurface(tint: Color.rossSuccess.opacity(0.14), cornerRadius: 16, strokeOpacity: 0.48)
    }
}

struct AlphaDocumentAdvocateNoteCard: View {
    @Binding var note: String
    let onSave: () -> Void
    let onAskRoss: () -> Void
    let onReviewAgain: () -> Void
    @FocusState private var noteFocused: Bool

    var body: some View {
        RossSectionCard(title: "Advocate note") {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)

                    if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Write your manual note for this document.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.42))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }

                    TextEditor(text: $note)
                        .scrollContentBackground(.hidden)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk)
                        .focused($noteFocused)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .frame(minHeight: 112)
                .rossGlassSurface(cornerRadius: 18, interactive: true, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 2, strokeOpacity: 0.50)

                HStack(spacing: 8) {
                    Button("Save note") {
                        noteFocused = false
                        onSave()
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)

                    Button {
                        noteFocused = false
                        onAskRoss()
                    } label: {
                        Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)

                    Button {
                        onReviewAgain()
                    } label: {
                        Label("Review", systemImage: "arrow.clockwise")
                            .font(.footnote.weight(.semibold))
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                    .accessibilityLabel("Review document again")
                }
            }
        }
    }
}

struct AlphaDocumentInspectCard: View {
    let documentTitle: String
    let extractedText: String?
    let sourceRefs: [AlphaSourceRef]
    @Binding var sourceDetailsExpanded: Bool
    @Binding var rawTextExpanded: Bool
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        RossSectionCard(title: "Check sources", subtitle: "Open the evidence Ross used, or inspect extracted text.") {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $sourceDetailsExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        if sourceRefs.isEmpty {
                            Text("No source previews available for this page.")
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                        }

                        ForEach(Array(sourceRefs.enumerated()), id: \.offset) { _, source in
                            Button {
                                onOpenSourceRef(source)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alphaSourceRefDisplayLabel(source, contextDocumentTitle: documentTitle))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rossInk)
                                    Text(source.detail)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.65))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .rossGlassSurface(cornerRadius: 14, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.46)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourceDetailsExpanded ? "Hide source links" : "Source links")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text("Jump to the page or snippet behind a detail")
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.58))
                        }
                        Spacer(minLength: 8)
                        Text(sourceRefs.isEmpty ? "0" : "\(sourceRefs.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.rossAccent)
                    }
                }
                .tint(Color.rossAccent)
                .padding(12)
                .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.44)

                DisclosureGroup(isExpanded: $rawTextExpanded) {
                    ScrollView {
                        Text(extractedText ?? "No extracted text is available for this page yet.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                    .padding(12)
                    .rossGlassSurface(cornerRadius: 14, strokeOpacity: 0.42)
                    .padding(.top, 10)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rawTextExpanded ? "Hide extracted text" : "Extracted text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text("Use this when a scan or OCR result needs manual checking")
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.58))
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "text.viewfinder")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                    }
                }
                .tint(Color.rossAccent)
                .padding(12)
                .rossGlassSurface(cornerRadius: 16, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.44)
            }
        }
    }
}

struct AlphaDocumentReviewStatusBanner: View {
    let state: AlphaDocumentProcessingState
    let needsReviewCount: Int
    let detail: String
    var isWorking: Bool = false
    var progressLabel: String?
    var progressValue: Double?

    private var title: String {
        switch state {
        case .readingText:
            return "Reading"
        case .imported:
            return "Imported"
        case .failed:
            return "Failed"
        case .ready:
            return needsReviewCount == 0 ? "Ready" : "Ready"
        case .needsConfirmation:
            return "Confirm"
        case .reviewingFindings:
            break
        }
        return needsReviewCount == 0
            ? "Ready"
            : needsReviewCount == 1
            ? "1 finding"
            : "\(needsReviewCount) findings"
    }

    private var tint: Color {
        if state == .failed {
            return .red
        }
        if isWorking || state == .imported {
            return Color.rossAccent
        }
        return state == .ready || needsReviewCount == 0 ? Color.rossSuccess : .orange
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.82))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(1)

            Text("·")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.42))

            Text(isWorking ? (progressLabel ?? "Working locally") : alphaReviewItemCountLabel(needsReviewCount))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.66))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isWorking {
                if let progressValue {
                    ProgressView(value: min(max(progressValue, 0), 1), total: 1)
                        .progressViewStyle(.linear)
                        .tint(tint)
                        .frame(width: 72)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .rossGlassSurface(
            tint: tint,
            cornerRadius: RossSurface.cornerRadius,
            shadowOpacity: 0.07,
            shadowRadius: 7,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.46
        )
    }
}

func alphaExtractionRunIsWorking(_ run: AlphaExtractionRun?) -> Bool {
    guard let run else { return false }
    switch run.status {
    case .queued, .running:
        return true
    case .needsReview, .complete, .failed, .cancelled:
        return false
    }
}

func alphaExtractionProgressValue(_ run: AlphaExtractionRun?) -> Double? {
    guard let run, run.totalPages > 0, run.pagesProcessed > 0 else { return nil }
    return Double(min(run.pagesProcessed, run.totalPages)) / Double(run.totalPages)
}

func alphaExtractionProgressLabel(_ run: AlphaExtractionRun?) -> String? {
    guard let run else { return nil }
    let stage: String
    switch run.progressState {
    case .acquiringText:
        stage = "Reading text"
    case .detectingLanguage:
        stage = "Checking language"
    case .extractingFields:
        stage = "Finding key details"
    case .verifyingFields:
        stage = "Checking sources"
    case .preparingReview:
        stage = "Preparing review"
    case .complete:
        stage = "Complete"
    case .needsReview:
        stage = "Please confirm"
    case .failed:
        stage = "Needs attention"
    }

    guard run.totalPages > 0, run.pagesProcessed > 0 else { return stage }
    return "\(stage) · \(min(run.pagesProcessed, run.totalPages)) of \(run.totalPages) pages"
}

func alphaDocumentReviewBannerDetail(run: AlphaExtractionRun?, fallback: String) -> String {
    guard let run, alphaExtractionRunIsWorking(run) else { return fallback }
    if let label = alphaExtractionProgressLabel(run) {
        return "\(label). Ross will update this file as soon as it finishes reading."
    }
    return "Ross is reading the file and will show what it found as soon as it finishes."
}

func alphaDocumentFallbackReviewDetail(document: AlphaCaseDocument, needsReviewCount: Int) -> String {
    switch document.processingState {
    case .imported, .readingText:
        return "Ross is still reading this file. Do not rely on full-document facts until review finishes."
    case .needsConfirmation, .reviewingFindings:
        return "Check the highlighted items below before relying on this document in a note or export."
    case .ready:
        return needsReviewCount > 0
            ? "Check the highlighted items below before relying on this document in a note or export."
            : "Verified details can be used in notes, tasks, and exports for this matter."
    case .failed:
        return "Ross could not finish reading this file. Review the source manually before using it."
    }
}

func alphaSuggestedDocumentTitle(caseMatter: AlphaCaseMatter, document: AlphaCaseDocument) -> String? {
    guard document.processingState != .imported, document.processingState != .readingText else { return nil }

    let originalTitle = (document.fileName as NSString).deletingPathExtension
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let currentTitle = document.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let type = document.classification?.type
    let usefulTypeTitle: String? = {
        guard let type, type != .unknown, type != .misc else { return nil }
        return type.title
    }()
    let dateTitle = alphaSuggestedDocumentTitleDate(from: document)
    let matterName = caseMatter.partiesSummary?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nilIfEmpty
        ?? caseMatter.title.trimmingCharacters(in: .whitespacesAndNewlines)

    let candidateParts = [
        usefulTypeTitle,
        dateTitle,
        matterName.nilIfEmpty
    ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

    guard !candidateParts.isEmpty else { return nil }
    let candidate = alphaCleanDocumentTitle(candidateParts.joined(separator: " - "))
    guard candidate.count >= 4 else { return nil }
    guard candidate.caseInsensitiveCompare(currentTitle) != .orderedSame else { return nil }
    guard originalTitle.isEmpty || candidate.caseInsensitiveCompare(originalTitle) != .orderedSame else { return nil }
    return candidate
}

func alphaSuggestedDocumentTitleDate(from document: AlphaCaseDocument) -> String? {
    let dateFields = document.extractedFields
        .filter { $0.fieldType == .nextDate || $0.fieldType == .date || $0.fieldType == .limitationDate }
        .sorted { lhs, rhs in
            if lhs.fieldType == rhs.fieldType {
                return lhs.confidence > rhs.confidence
            }
            return alphaFieldSortRank(lhs.fieldType) < alphaFieldSortRank(rhs.fieldType)
        }

    for field in dateFields {
        let value = field.normalizedValue?.nilIfEmpty ?? field.value
        if let date = alphaParsedDocumentTitleDate(from: value) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let cleaned {
            return cleaned
        }
    }
    return nil
}

func alphaParsedDocumentTitleDate(from value: String) -> Date? {
    let cleaned = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    guard !cleaned.isEmpty else { return nil }

    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: .now)
    switch cleaned.lowercased() {
    case "today":
        return startOfToday
    case "tomorrow":
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    case "next week":
        return calendar.date(byAdding: .day, value: 7, to: startOfToday)
    default:
        break
    }

    let formatters = [
        "yyyy-MM-dd",
        "d/M/yyyy",
        "dd/MM/yyyy",
        "d/M/yy",
        "d-MM-yyyy",
        "dd-MM-yyyy",
        "d MMM yyyy",
        "dd MMM yyyy",
        "d MMMM yyyy",
        "dd MMMM yyyy",
        "d MMM",
        "dd MMM",
        "d MMMM",
        "dd MMMM"
    ]
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_IN")
    formatter.timeZone = .current
    formatter.isLenient = false
    formatter.defaultDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: .now), month: 1, day: 1))

    for format in formatters {
        formatter.dateFormat = format
        if let date = formatter.date(from: cleaned) {
            if format.contains("y") {
                return date
            }
            if date < startOfToday {
                return calendar.date(byAdding: .year, value: 1, to: date)
            }
            return date
        }
    }
    return nil
}

func alphaCleanDocumentTitle(_ title: String) -> String {
    let collapsed = title
        .replacingOccurrences(of: "\n", with: " ")
        .split(separator: " ")
        .joined(separator: " ")
    guard collapsed.count > 72 else { return collapsed }
    return String(collapsed.prefix(69)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
}

func alphaDocumentTypeTint(_ type: AlphaLegalDocumentType) -> Color {
    switch type {
    case .order, .judgment:
        return Color.rossAccent
    case .pleading, .courtFiling:
        return Color.rossHighlight
    case .affidavit, .evidence:
        return Color.orange
    case .notice, .correspondence, .clientNote:
        return Color.rossSuccess
    case .legalResearch:
        return Color.purple
    case .nonLegalDocument, .fictionalGameMaterial, .unknown, .misc:
        return Color.rossInk.opacity(0.58)
    }
}

@MainActor
func AlphaDocumentPreview(document: AlphaCaseDocument, initialPage: Int) -> AnyView? {
    if document.kind == .pdf {
        return AnyView(AlphaPDFPreview(document: document, initialPage: initialPage))
    }

    if document.kind == .image {
        return AnyView(AlphaImagePreview(relativePath: document.storedRelativePath))
    }

    return AnyView(
        RossSectionCard(title: "Preview") {
            AlphaDocumentTextPreview(document: document, initialPage: initialPage)
        }
    )
}

struct AlphaReviewActionButtonStyle: ButtonStyle {
    var tint: Color = Color.rossInk

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .rossGlassSurface(tint: tint.opacity(0.12), cornerRadius: 14, interactive: true, shadowOpacity: configuration.isPressed ? 0.04 : 0.07, shadowRadius: configuration.isPressed ? 4 : 7, shadowY: configuration.isPressed ? 1 : 2, fillOpacity: configuration.isPressed ? 0.66 : 0.78, strokeOpacity: 0.52)
    }
}

struct AlphaReviewActionLabel: View {
    let title: String
    var tint: Color = Color.rossInk

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .rossGlassSurface(tint: tint.opacity(0.10), cornerRadius: 14, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 1, strokeOpacity: 0.50)
    }
}

struct AlphaClassificationReviewCard: View {
    let classification: AlphaLegalDocumentClassification
    let contextDocumentTitle: String?
    let onAccept: () -> Void
    let onUpdateType: (AlphaLegalDocumentType) -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        let confidenceLabel = alphaConfidenceLabel(confidence: classification.confidence, needsReview: classification.needsReview)
        let confidenceSupport = alphaConfidenceSupportText(confidence: classification.confidence, needsReview: classification.needsReview)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Type")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                Spacer(minLength: 8)
                AlphaConfidenceBadge(
                    label: confidenceLabel,
                    tint: alphaConfidenceTint(confidenceLabel)
                )
            }

            Text(classification.type.title)
                .font(.headline)
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)

            Text(confidenceSupport)
                .font(.caption)
                .foregroundStyle(alphaConfidenceTint(confidenceLabel))
                .fixedSize(horizontal: false, vertical: true)

            if let subtype = classification.subtype, !subtype.isEmpty {
                Text(subtype.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }

            if classification.type.blocksAutomaticLegalFactSaving {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This may not be a legal case document")
                        .font(.subheadline.weight(.semibold))
                    Text("Ross found language suggesting this file is fictional, instructional, or non-legal. Ross will not save case details, hearing dates, or tasks from this file unless you confirm.")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(classification.type.blocksAutomaticLegalFactSaving ? "Use as reference only" : "Accept", action: onAccept)
                    .buttonStyle(AlphaReviewActionButtonStyle())

                Menu {
                    ForEach(AlphaLegalDocumentType.reviewMenuTypes, id: \.self) { type in
                        Button(type.title) {
                            onUpdateType(type)
                        }
                    }
                } label: {
                    AlphaReviewActionLabel(title: "Edit")
                }

                if classification.type.blocksAutomaticLegalFactSaving {
                    Button("Mark as legal document") {
                        onUpdateType(.courtFiling)
                    }
                    .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))
                }
            }
            .font(.footnote.weight(.semibold))

            AlphaSourceRefChips(
                sourceRefs: classification.sourceRefs,
                contextDocumentTitle: contextDocumentTitle,
                onOpenSourceRef: onOpenSourceRef
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .padding(.leading, 5)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(alphaConfidenceTint(confidenceLabel).opacity(0.72))
                .frame(width: alphaReviewAccentWidth)
                .padding(.vertical, 12)
        }
        .rossGlassSurface(tint: alphaConfidenceTint(confidenceLabel).opacity(0.10), cornerRadius: RossSurface.cornerRadius, strokeOpacity: 0.58)
    }
}

struct AlphaExtractedFieldReviewCard: View {
    let field: AlphaExtractedLegalField
    let contextDocumentTitle: String?
    let onAccept: () -> Void
    let onSaveEdit: (String) -> Void
    let onIgnore: () -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    @State private var isEditing = false
    @State private var draftValue = ""

    var body: some View {
        let confidenceSupport = alphaConfidenceSupportText(confidence: field.confidence, needsReview: field.needsReview)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(field.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                Spacer(minLength: 8)
                AlphaConfidenceBadge(
                    label: field.confidenceLabel,
                    tint: alphaConfidenceTint(field.confidenceLabel)
                )
            }

            if isEditing {
                TextField("Edit \(field.label.lowercased())", text: $draftValue)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .rossGlassSurface(cornerRadius: 10, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.44)
            } else {
                Text(field.value)
                    .font(.headline)
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(confidenceSupport)
                .font(.caption)
                .foregroundStyle(alphaConfidenceTint(field.confidenceLabel))
                .fixedSize(horizontal: false, vertical: true)

            AlphaSourceRefChips(
                sourceRefs: field.sourceRefs,
                contextDocumentTitle: contextDocumentTitle,
                onOpenSourceRef: onOpenSourceRef
            )

            HStack(spacing: 10) {
                if isEditing {
                    Button("Save") {
                        onSaveEdit(draftValue)
                        isEditing = false
                    }
                    .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                    Button("Cancel") {
                        draftValue = field.value
                        isEditing = false
                    }
                    .buttonStyle(AlphaReviewActionButtonStyle())
                } else {
                    Button("Accept", action: onAccept)
                        .buttonStyle(AlphaReviewActionButtonStyle())

                    Button("Edit") {
                        draftValue = field.value
                        isEditing = true
                    }
                    .buttonStyle(AlphaReviewActionButtonStyle())

                    Button("Ignore", role: .destructive, action: onIgnore)
                        .buttonStyle(AlphaReviewActionButtonStyle(tint: .red))
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .padding(.leading, 5)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(alphaConfidenceTint(field.confidenceLabel).opacity(0.72))
                .frame(width: alphaReviewAccentWidth)
                .padding(.vertical, 12)
        }
        .rossGlassSurface(tint: alphaConfidenceTint(field.confidenceLabel).opacity(0.10), cornerRadius: RossSurface.cornerRadius, strokeOpacity: 0.58)
        .onAppear {
            draftValue = field.value
        }
    }
}

struct AlphaFindingCard: View {
    let finding: AlphaExtractionFinding
    let contextDocumentTitle: String?
    let onKeepMatterValue: () -> Void
    let onUseFileValue: () -> Void
    let onSaveAlternate: () -> Void
    let onIgnore: () -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    private var isConflict: Bool {
        finding.matterValue?.isEmpty == false || finding.fileValue?.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(finding.message)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                AlphaConfidenceBadge(
                    label: finding.severity.rawValue.capitalized,
                    tint: finding.severity == .critical ? .red : .orange
                )
            }

            if isConflict {
                VStack(alignment: .leading, spacing: 6) {
                    if let matterValue = finding.matterValue, !matterValue.isEmpty {
                        AlphaSettingsValueRow(label: "Matter value", value: matterValue)
                    }
                    if let fileValue = finding.fileValue, !fileValue.isEmpty {
                        AlphaSettingsValueRow(label: "File value", value: fileValue)
                    }
                }
            }

            AlphaSourceRefChips(
                sourceRefs: finding.sourceRefs,
                contextDocumentTitle: contextDocumentTitle,
                onOpenSourceRef: onOpenSourceRef
            )

            if isConflict {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Keep matter value", action: onKeepMatterValue)
                            .buttonStyle(AlphaReviewActionButtonStyle())
                        Button("Use file value", action: onUseFileValue)
                            .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))
                    }
                    HStack(spacing: 8) {
                        Button("Save as alternate reference", action: onSaveAlternate)
                            .buttonStyle(AlphaReviewActionButtonStyle())
                        Button("Ignore", role: .destructive, action: onIgnore)
                            .buttonStyle(AlphaReviewActionButtonStyle(tint: .red))
                    }
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .padding(.leading, 5)
        .rossGlassSurface(
            tint: finding.severity == .critical ? Color.red : Color.orange,
            cornerRadius: RossSurface.cornerRadius,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.84,
            strokeOpacity: 0.48
        )
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill((finding.severity == .critical ? Color.red : Color.orange).opacity(0.72))
                .frame(width: alphaReviewAccentWidth)
                .padding(.vertical, 12)
        }
    }
}

struct AlphaRossTokenChip: View {
    let title: String
    var detail: String? = nil
    var systemImage: String = "paperclip"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.rossAccent)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.84))
                .lineLimit(1)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.54))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .rossGlassSurface(cornerRadius: 15, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.48)
    }
}

struct AlphaSourceRefChips: View {
    let sourceRefs: [AlphaSourceRef]
    let contextDocumentTitle: String?
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    private var visibleSourceRefs: [AlphaSourceRef] {
        Array(sourceRefs.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sourceRefs.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.rossInk.opacity(0.42))
                    Text("source not available")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(visibleSourceRefs.enumerated()), id: \.offset) { _, sourceRef in
                            sourceRefButton(sourceRef)
                        }
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 116), spacing: 8, alignment: .leading)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(Array(visibleSourceRefs.enumerated()), id: \.offset) { _, sourceRef in
                            sourceRefButton(sourceRef)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sourceRefButton(_ sourceRef: AlphaSourceRef) -> some View {
        Button {
            onOpenSourceRef(sourceRef)
        } label: {
            AlphaRossTokenChip(
                title: alphaSourceRefDisplayLabel(sourceRef, contextDocumentTitle: contextDocumentTitle),
                detail: nil,
                systemImage: "doc.text"
            )
        }
        .buttonStyle(.plain)
    }
}

func alphaSourceRefDisplayLabel(_ sourceRef: AlphaSourceRef, contextDocumentTitle: String?) -> String {
    let label = sourceRef.label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let contextDocumentTitle else { return label }
    let context = contextDocumentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !context.isEmpty else { return label }

    if sourceRef.effectiveSourceCategory == .documentSource {
        if sourceRef.documentTitle.trimmingCharacters(in: .whitespacesAndNewlines) == context {
            return sourceRef.pageNumber > 0 ? "This file · p. \(sourceRef.pageNumber)" : "This file · source not available"
        }
        return label
    }

    if label == context {
        return "This file"
    }

    for prefix in ["\(context) ", "\(context): ", "\(context) · "] {
        if label.hasPrefix(prefix) {
            let shortened = String(label.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return shortened.isEmpty ? "This file" : shortened
        }
    }

    return label
}

struct AlphaConfidenceBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
