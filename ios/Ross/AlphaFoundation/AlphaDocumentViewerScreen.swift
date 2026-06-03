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
    case .mixed: rossLocalized("document_language_mixed")
    case .unknown: rossLocalized("document_language_unknown")
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

func alphaDocumentReadinessMessage(
    _ document: AlphaCaseDocument,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    if document.hasAskUsableExtractedText {
        switch document.processingState {
        case .imported, .readingText:
            return rossLocalized("document_readiness_ask_review_running", languageCode: languageCode)
        case .needsConfirmation, .reviewingFindings:
            return rossLocalized("document_readiness_ask_review_findings", languageCode: languageCode)
        case .ready:
            return rossLocalized("document_readiness_ask_verified", languageCode: languageCode)
        case .failed:
            return rossLocalized("document_readiness_ask_review_failed", languageCode: languageCode)
        }
    }
    if document.isAwaitingReadableText {
        return rossLocalized("document_readiness_still_reading", languageCode: languageCode)
    }
    return rossLocalized("document_readiness_needs_clearer_text", languageCode: languageCode)
}

struct AlphaDocumentReadinessItem {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

func alphaDocumentReadinessItems(
    _ document: AlphaCaseDocument,
    languageCode: String = rossSelectedLanguageCode()
) -> [AlphaDocumentReadinessItem] {
    let askItem: AlphaDocumentReadinessItem
    if document.hasAskUsableExtractedText {
        askItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_ask_ready_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_ask_ready_detail", languageCode: languageCode),
            systemImage: "bubble.right.fill",
            tint: Color.rossSuccess
        )
    } else if document.isAwaitingReadableText {
        askItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_still_reading_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_still_reading_detail", languageCode: languageCode),
            systemImage: "text.viewfinder",
            tint: Color.rossAccent
        )
    } else {
        askItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_needs_clearer_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_needs_clearer_detail", languageCode: languageCode),
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange
        )
    }

    let reviewItem: AlphaDocumentReadinessItem
    switch document.processingState {
    case .ready:
        reviewItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_review_complete_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_review_complete_detail", languageCode: languageCode),
            systemImage: "checkmark.seal.fill",
            tint: Color.rossSuccess
        )
    case .failed:
        reviewItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_review_attention_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_review_attention_detail", languageCode: languageCode),
            systemImage: "arrow.clockwise.circle.fill",
            tint: .orange
        )
    case .needsConfirmation, .reviewingFindings:
        reviewItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_check_details_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_check_details_detail", languageCode: languageCode),
            systemImage: "checklist.checked",
            tint: .orange
        )
    case .imported, .readingText:
        reviewItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_readiness_review_progress_title", languageCode: languageCode),
            detail: rossLocalized("document_readiness_review_progress_detail", languageCode: languageCode),
            systemImage: "hourglass",
            tint: Color.rossAccent
        )
    }

    let languageItem: AlphaDocumentReadinessItem
    if let profile = document.languageProfile {
        let languageName = alphaDocumentLanguageDisplayName(profile.primaryLanguage)
        let scriptLabel = profile.scriptsDetected.isEmpty
            ? rossLocalized("document_script_detected", languageCode: languageCode)
            : profile.scriptsDetected.sorted().joined(separator: ", ")
        languageItem = AlphaDocumentReadinessItem(
            title: languageName,
            detail: String(format: rossLocalized("document_language_detected_detail", languageCode: languageCode), scriptLabel),
            systemImage: "character.book.closed.fill",
            tint: profile.primaryLanguage == .mixed ? .orange : Color.rossAccent
        )
    } else {
        languageItem = AlphaDocumentReadinessItem(
            title: rossLocalized("document_language_pending_title", languageCode: languageCode),
            detail: rossLocalized("document_language_pending_detail", languageCode: languageCode),
            systemImage: "character.book.closed.fill",
            tint: Color.rossInk.opacity(0.52)
        )
    }

    return [askItem, reviewItem, languageItem]
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
            RossGlassGroup(spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                AlphaInlineHeader(
                    eyebrow: caseMatter?.forum ?? rossLocalized("documents_title"),
                    title: caseMatter?.title ?? rossLocalized("documents_title"),
                    detail: alphaFilesInMatterLabel(caseMatter?.documents.count ?? 0)
                )

                RossSectionCard {
                    HStack {
                        Text(alphaFilesStoredForMatterLabel(caseMatter?.documents.count ?? 0))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.7))

                        Spacer(minLength: 0)

                        AlphaDocumentLayoutMenu(layoutMode: $documentLayoutMode)
                    }
                }

                if let caseMatter, caseMatter.documents.isEmpty {
                    AlphaEmptyFileRoomCard(
                        title: rossLocalized("file_room_import_first_file"),
                        detail: rossLocalized("file_room_import_first_file_detail"),
                        actionTitle: rossLocalized("import_document"),
                        onImport: { showingImporter = true }
                    )
                } else {
                    Button(rossLocalized("import_document")) {
                        showingImporter = true
                    }
                    .rossPrimaryButtonStyle()
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
        .navigationTitle(rossLocalized("documents_title"))
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: rossLocalized("open_ask_ross")) {
                    model.openAsk(scopeCaseID: caseId)
                }
            }
        }
    }
}

struct AlphaEmptyFileRoomCard: View {
    let title: String
    let detail: String
    let actionTitle: String
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.rossAccent)
                    .frame(width: 36, height: 36)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.24),
                        shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                        interactive: false,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.48
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(actionTitle, action: onImport)
                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
        }
        .padding(14)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.14),
            cornerRadius: 18,
            interactive: true,
            shadowOpacity: 0.07,
            shadowRadius: 7,
            shadowY: 3,
            fillOpacity: 0.80,
            strokeOpacity: 0.50
        )
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
        guard !isSharedDocument else { return rossLocalized("general_files") }
        return caseMatter?.title ?? rossLocalized("matter")
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
                RossGlassGroup(spacing: 16) {
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

                    AlphaDocumentReadinessCard(document: document)

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
                        AlphaDocumentReviewWorkbenchCard(title: rossLocalized("document_review_what_ross_found"), subtitle: reviewSummaryText) {
                            VStack(alignment: .leading, spacing: 14) {
                                if document.classification?.needsReview == true || !importantReviewFields.isEmpty || !reviewFindings.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top, spacing: 10) {
                                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                                .fill(Color.orange.opacity(0.76))
                                                .frame(width: alphaReviewAccentWidth)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(rossLocalized("document_review_important"))
                                                    .font(.caption.weight(.bold))
                                                    .textCase(.uppercase)
                                                    .foregroundStyle(Color.rossInk.opacity(0.62))
                                                Text(rossLocalized("document_review_important_detail"))
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
                                            Text(rossLocalized("document_review_helpful_details"))
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
                                            Text(rossLocalized("document_review_other_details"))
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

                                        Button(rossLocalized("document_run_better_extraction")) {
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
        .navigationTitle(document?.title ?? rossLocalized("document_title"))
        .navigationBarBackButtonHidden(true)
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: alphaNavigationBarLeadingPlacement) {
                AlphaDocumentToolbarIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: rossLocalized("back"),
                    action: exitDocument
                )
            }

            ToolbarItem(placement: alphaNavigationBarTrailingPlacement) {
                HStack(spacing: 8) {
                    AlphaDocumentToolbarIconButton(
                        systemImage: "bubble.right",
                        accessibilityLabel: rossLocalized("ask_ross_about_document"),
                        action: {
                            model.openDocumentInChat(caseId: caseId, documentId: documentId, startNewThread: false)
                        }
                    )

                    AlphaDocumentToolbarIconButton(
                        systemImage: "arrow.clockwise",
                        accessibilityLabel: rossLocalized("review_document_again"),
                        action: {
                            Task { await model.rerunReview(caseId: caseId, documentId: documentId) }
                        }
                    )
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

struct AlphaDocumentReadinessCard: View {
    let document: AlphaCaseDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(rossLocalized("file_readiness"))
                    .font(.headline)
                    .foregroundStyle(Color.rossInk)

                Spacer(minLength: 8)

                Text(document.hasAskUsableExtractedText ? rossLocalized("ask_ready") : rossLocalized("preparing"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(document.hasAskUsableExtractedText ? Color.rossSuccess : Color.rossAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .rossGlassSurface(
                        tint: document.hasAskUsableExtractedText ? Color.rossSuccess.opacity(0.18) : Color.rossAccent.opacity(0.14),
                        cornerRadius: 11,
                        shadowOpacity: 0.03,
                        shadowRadius: 3,
                        shadowY: 1,
                        fillOpacity: 0.70,
                        strokeOpacity: 0.38
                    )
            }

            VStack(spacing: 8) {
                let items = alphaDocumentReadinessItems(document)
                ForEach(items.indices, id: \.self) { index in
                    AlphaDocumentReadinessRow(item: items[index])
                }
            }
        }
        .padding(14)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.10),
            cornerRadius: 18,
            shadowOpacity: 0.07,
            shadowRadius: 7,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.48
        )
    }
}

private struct AlphaDocumentToolbarIconButton: View {
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
                    .rossGlassSurface(
                        tint: Color.rossAccent,
                        cornerRadius: 16,
                        interactive: true,
                        shadowOpacity: 0.05,
                        shadowRadius: 5,
                        shadowY: 2,
                        strokeOpacity: 0.48
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.rossInk)
            .frame(width: 32, height: 32)
    }
}

private struct AlphaDocumentReadinessRow: View {
    let item: AlphaDocumentReadinessItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28)
                .rossNativeGlassSurface(
                    tint: item.tint.opacity(0.18),
                    shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    interactive: false,
                    fallbackFillOpacity: 0.76,
                    fallbackStrokeOpacity: 0.40
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .rossGlassSurface(
            tint: item.tint.opacity(0.08),
            cornerRadius: 14,
            shadowOpacity: 0.035,
            shadowRadius: 4,
            shadowY: 1,
            fillOpacity: 0.72,
            strokeOpacity: 0.38
        )
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "translate")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
                    .frame(width: 34, height: 34)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent.opacity(0.24),
                        shape: RoundedRectangle(cornerRadius: 11, style: .continuous),
                        interactive: false,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.48
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(rossLocalized("translate_this_file"))
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)

                    Text(isAssistantReady ? rossLocalized("translation_ready") : rossLocalized("translation_needs_assistant"))
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            RossGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    AlphaTranslationLanguageChip(label: rossLocalized("translation_from_label"), value: documentLanguage, systemImage: "doc.text.magnifyingglass")
                    AlphaTranslationLanguageChip(label: rossLocalized("translation_to_label"), value: targetLanguage, systemImage: "text.bubble")
                }
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
            .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
        }
        .padding(14)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.14),
            cornerRadius: 18,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.50
        )
    }
}

private struct AlphaTranslationLanguageChip: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.54))
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 10)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.10),
            cornerRadius: 14,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1,
            fillOpacity: 0.74,
            strokeOpacity: 0.44
        )
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
        .rossNativeGlassSurface(
            tint: alphaDocumentTypeTint(type),
            shape: Capsule(),
            fallbackFillOpacity: 0.74,
            fallbackStrokeOpacity: 0.42
        )
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
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent,
                            shape: RoundedRectangle(cornerRadius: 9, style: .continuous),
                            fallbackFillOpacity: 0.76,
                            fallbackStrokeOpacity: 0.42
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rossLocalized("document_title_suggestion_title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                        Text(rossLocalized("document_title_suggestion_detail"))
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isEditing {
                    TextField(rossLocalized("document_name"), text: $draftTitle)
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

                RossGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        if isEditing {
                            Button(rossLocalized("save")) {
                                onSaveEdit(draftTitle)
                                isEditing = false
                            }
                            .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                            Button(rossLocalized("cancel")) {
                                draftTitle = suggestedTitle
                                isEditing = false
                            }
                            .buttonStyle(AlphaReviewActionButtonStyle())
                        } else {
                            Button(rossLocalized("accept"), action: onAccept)
                                .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                            Button(rossLocalized("edit")) {
                                draftTitle = suggestedTitle
                                isEditing = true
                            }
                            .buttonStyle(AlphaReviewActionButtonStyle())

                            Button(alphaKeepOriginalFileNameLabel(originalFileName), action: onKeepOriginal)
                                .buttonStyle(AlphaReviewActionButtonStyle())
                        }
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
                Text(rossLocalized("confirmed_details_usage_detail"))
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
                    Text(rossLocalized("confirmed_for_ross"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(rossLocalized("details_already_approved_for_matter"))
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
        RossSectionCard(title: rossLocalized("advocate_note")) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.clear)

                    if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(rossLocalized("advocate_note_placeholder"))
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
                    AlphaDocumentActionButton(
                        title: rossLocalized("save_note"),
                        systemImage: "checkmark",
                        isProminent: true,
                        action: {
                            noteFocused = false
                            onSave()
                        }
                    )

                    AlphaDocumentActionButton(
                        title: rossLocalized("ask"),
                        systemImage: "bubble.left.and.text.bubble.right",
                        action: {
                            noteFocused = false
                            onAskRoss()
                        }
                    )

                    AlphaDocumentActionButton(
                        title: rossLocalized("review"),
                        systemImage: "arrow.clockwise",
                        accessibilityLabel: rossLocalized("review_document_again"),
                        action: onReviewAgain
                    )
                }
            }
        }
    }
}

private struct AlphaDocumentActionButton: View {
    let title: String
    let systemImage: String
    var accessibilityLabel: String?
    var isProminent = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            if isProminent {
                Button(action: action) {
                    label
                }
                .buttonStyle(.glassProminent)
                .tint(Color.rossAccent)
                .accessibilityLabel(accessibilityLabel ?? title)
            } else {
                Button(action: action) {
                    label
                }
                .buttonStyle(.glass)
                .tint(Color.rossAccent)
                .accessibilityLabel(accessibilityLabel ?? title)
            }
        } else {
            Button(action: action) {
                label
            }
            .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
            .accessibilityLabel(accessibilityLabel ?? title)
        }
    }

    private var label: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
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
        RossSectionCard(title: rossLocalized("check_sources"), subtitle: rossLocalized("check_sources_detail")) {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $sourceDetailsExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        if sourceRefs.isEmpty {
                            Text(rossLocalized("no_source_previews"))
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                        }

                        ForEach(Array(sourceRefs.enumerated()), id: \.offset) { _, source in
                            Button {
                                onOpenSourceRef(source)
                            } label: {
                                AlphaDocumentSourceRow(
                                    title: alphaSourceRefDisplayLabel(source, contextDocumentTitle: documentTitle),
                                    detail: source.detail
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourceDetailsExpanded ? rossLocalized("hide_source_links") : rossLocalized("source_links"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(rossLocalized("source_links_detail"))
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
                        Text(extractedText ?? rossLocalized("no_extracted_text"))
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
                            Text(rawTextExpanded ? rossLocalized("hide_extracted_text") : rossLocalized("extracted_text"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(rossLocalized("extracted_text_detail"))
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

private struct AlphaDocumentSourceRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rossInk)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .modifier(AlphaDocumentSourceRowSurface())
    }
}

private struct AlphaDocumentSourceRowSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(Color.rossAccent.opacity(0.10))
                        .interactive(),
                    in: .rect(cornerRadius: 14)
                )
        } else {
            content
                .rossGlassSurface(cornerRadius: 14, interactive: true, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.46)
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
            return rossLocalized("document_status_reading")
        case .imported:
            return rossLocalized("document_status_imported")
        case .failed:
            return rossLocalized("document_status_failed")
        case .ready:
            return rossLocalized("document_status_ready")
        case .needsConfirmation:
            return rossLocalized("document_status_confirm")
        case .reviewingFindings:
            break
        }
        return needsReviewCount == 0
            ? rossLocalized("document_status_ready")
            : needsReviewCount == 1
            ? rossLocalized("one_finding")
            : alphaFindingsCountLabel(needsReviewCount)
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

            Text(isWorking ? (progressLabel ?? rossLocalized("working_locally")) : alphaReviewItemCountLabel(needsReviewCount))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.66))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isWorking {
                if let progressValue {
                    AlphaGlassLinearProgressView(
                        value: progressValue,
                        tint: tint
                    )
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

private struct AlphaGlassLinearProgressView: View {
    let value: Double
    let tint: Color

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.clear)
                    .rossNativeGlassSurface(
                        tint: tint,
                        shape: Capsule(),
                        fallbackFillOpacity: 0.62,
                        fallbackStrokeOpacity: 0.42
                    )

                Capsule()
                    .fill(tint.opacity(0.82))
                    .frame(width: max(proxy.size.width * clampedValue, 4))
                    .padding(2)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rossLocalized("document_review_progress_title"))
        .accessibilityValue(clampedValue.formatted(.percent.precision(.fractionLength(0))))
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
        stage = rossLocalized("extraction_stage_reading_text")
    case .detectingLanguage:
        stage = rossLocalized("extraction_stage_checking_language")
    case .extractingFields:
        stage = rossLocalized("extraction_stage_finding_key_details")
    case .verifyingFields:
        stage = rossLocalized("extraction_stage_checking_sources")
    case .preparingReview:
        stage = rossLocalized("extraction_stage_preparing_review")
    case .complete:
        stage = rossLocalized("extraction_stage_complete")
    case .needsReview:
        stage = rossLocalized("extraction_stage_please_confirm")
    case .failed:
        stage = rossLocalized("extraction_stage_needs_attention")
    }

    guard run.totalPages > 0, run.pagesProcessed > 0 else { return stage }
    return alphaExtractionPagesProgressLabel(
        stage: stage,
        processed: min(run.pagesProcessed, run.totalPages),
        total: run.totalPages
    )
}

func alphaFindingsCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("findings_count", languageCode: languageCode), count)
}

func alphaExtractionPagesProgressLabel(
    stage: String,
    processed: Int,
    total: Int,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(format: rossLocalized("extraction_pages_progress", languageCode: languageCode), stage, processed, total)
}

func alphaExtractionProgressDetail(_ label: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("document_review_progress_detail", languageCode: languageCode), label)
}

func alphaDocumentReviewBannerDetail(run: AlphaExtractionRun?, fallback: String) -> String {
    guard let run, alphaExtractionRunIsWorking(run) else { return fallback }
    if let label = alphaExtractionProgressLabel(run) {
        return alphaExtractionProgressDetail(label)
    }
    return rossLocalized("document_review_reading_detail")
}

func alphaDocumentFallbackReviewDetail(document: AlphaCaseDocument, needsReviewCount: Int) -> String {
    switch document.processingState {
    case .imported, .readingText:
        return rossLocalized("document_review_still_reading_warning")
    case .needsConfirmation, .reviewingFindings:
        return rossLocalized("document_review_check_findings_warning")
    case .ready:
        return needsReviewCount > 0
            ? rossLocalized("document_review_check_findings_warning")
            : rossLocalized("document_review_verified_ready_warning")
    case .failed:
        return rossLocalized("document_review_failed_warning")
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

func alphaKeepOriginalFileNameLabel(_ fileName: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("keep_original_file_name", languageCode: languageCode), fileName)
}

func alphaEditFieldPlaceholder(_ fieldLabel: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("edit_field_placeholder", languageCode: languageCode), fieldLabel.lowercased())
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
        RossSectionCard(title: rossLocalized("preview")) {
            AlphaDocumentTextPreview(document: document, initialPage: initialPage)
        }
    )
}

struct AlphaReviewActionButtonStyle: ButtonStyle {
    var tint: Color = Color.rossInk

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: configuration.isPressed ? 0.62 : 0.76,
                fallbackStrokeOpacity: 0.50
            )
            .shadow(
                color: Color.rossShadow.opacity(configuration.isPressed ? 0.04 : 0.07),
                radius: configuration.isPressed ? 4 : 7,
                y: configuration.isPressed ? 1 : 2
            )
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
            .rossNativeGlassSurface(
                tint: tint,
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                fallbackFillOpacity: 0.74,
                fallbackStrokeOpacity: 0.50
            )
            .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 1)
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
        let confidenceTint = alphaConfidenceTint(confidence: classification.confidence, needsReview: classification.needsReview)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(rossLocalized("type"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                Spacer(minLength: 8)
                AlphaConfidenceBadge(
                    label: confidenceLabel,
                    tint: confidenceTint
                )
            }

            Text(classification.type.title)
                .font(.headline)
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)

            Text(confidenceSupport)
                .font(.caption)
                .foregroundStyle(confidenceTint)
                .fixedSize(horizontal: false, vertical: true)

            if let subtype = classification.subtype, !subtype.isEmpty {
                Text(subtype.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }

            if classification.type.blocksAutomaticLegalFactSaving {
                VStack(alignment: .leading, spacing: 8) {
                    Text(rossLocalized("may_not_be_legal_document"))
                        .font(.subheadline.weight(.semibold))
                    Text(rossLocalized("may_not_be_legal_document_detail"))
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(classification.type.blocksAutomaticLegalFactSaving ? rossLocalized("use_as_reference_only") : rossLocalized("accept"), action: onAccept)
                    .buttonStyle(AlphaReviewActionButtonStyle())

                Menu {
                    ForEach(AlphaLegalDocumentType.reviewMenuTypes, id: \.self) { type in
                        Button(type.title) {
                            onUpdateType(type)
                        }
                    }
                } label: {
                    AlphaReviewActionLabel(title: rossLocalized("edit"))
                }

                if classification.type.blocksAutomaticLegalFactSaving {
                    Button(rossLocalized("mark_as_legal_document")) {
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
                .fill(confidenceTint.opacity(0.72))
                .frame(width: alphaReviewAccentWidth)
                .padding(.vertical, 12)
        }
        .rossGlassSurface(tint: confidenceTint.opacity(0.10), cornerRadius: RossSurface.cornerRadius, strokeOpacity: 0.58)
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
        let confidenceLabel = alphaConfidenceLabel(confidence: field.confidence, needsReview: field.needsReview)
        let confidenceTint = alphaConfidenceTint(confidence: field.confidence, needsReview: field.needsReview)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(field.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                Spacer(minLength: 8)
                AlphaConfidenceBadge(
                    label: confidenceLabel,
                    tint: confidenceTint
                )
            }

            if isEditing {
                TextField(alphaEditFieldPlaceholder(field.label), text: $draftValue)
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
                .foregroundStyle(confidenceTint)
                .fixedSize(horizontal: false, vertical: true)

            AlphaSourceRefChips(
                sourceRefs: field.sourceRefs,
                contextDocumentTitle: contextDocumentTitle,
                onOpenSourceRef: onOpenSourceRef
            )

            RossGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    if isEditing {
                        Button(rossLocalized("save")) {
                            onSaveEdit(draftValue)
                            isEditing = false
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))

                        Button(rossLocalized("cancel")) {
                            draftValue = field.value
                            isEditing = false
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle())
                    } else {
                        Button(rossLocalized("accept"), action: onAccept)
                            .buttonStyle(AlphaReviewActionButtonStyle())

                        Button(rossLocalized("edit")) {
                            draftValue = field.value
                            isEditing = true
                        }
                        .buttonStyle(AlphaReviewActionButtonStyle())

                        Button(rossLocalized("ignore"), role: .destructive, action: onIgnore)
                            .buttonStyle(AlphaReviewActionButtonStyle(tint: .red))
                    }
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .padding(.leading, 5)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(confidenceTint.opacity(0.72))
                .frame(width: alphaReviewAccentWidth)
                .padding(.vertical, 12)
        }
        .rossGlassSurface(tint: confidenceTint.opacity(0.10), cornerRadius: RossSurface.cornerRadius, strokeOpacity: 0.58)
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
                        AlphaSettingsValueRow(label: rossLocalized("matter_value"), value: matterValue)
                    }
                    if let fileValue = finding.fileValue, !fileValue.isEmpty {
                        AlphaSettingsValueRow(label: rossLocalized("file_value"), value: fileValue)
                    }
                }
            }

            AlphaSourceRefChips(
                sourceRefs: finding.sourceRefs,
                contextDocumentTitle: contextDocumentTitle,
                onOpenSourceRef: onOpenSourceRef
            )

            if isConflict {
                RossGlassGroup(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button(rossLocalized("keep_matter_value"), action: onKeepMatterValue)
                                .buttonStyle(AlphaReviewActionButtonStyle())
                            Button(rossLocalized("use_file_value"), action: onUseFileValue)
                                .buttonStyle(AlphaReviewActionButtonStyle(tint: Color.rossAccent))
                        }
                        HStack(spacing: 8) {
                            Button(rossLocalized("save_as_alternate_reference"), action: onSaveAlternate)
                                .buttonStyle(AlphaReviewActionButtonStyle())
                            Button(rossLocalized("ignore"), role: .destructive, action: onIgnore)
                                .buttonStyle(AlphaReviewActionButtonStyle(tint: .red))
                        }
                    }
                    .font(.footnote.weight(.semibold))
                }
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
    var isInteractive = false

    var body: some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 30)
            .modifier(AlphaRossTokenChipSurface(isInteractive: isInteractive))
    }

    private var content: some View {
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
    }
}

private struct AlphaRossTokenChipSurface: ViewModifier {
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *), isInteractive {
            content
                .glassEffect(
                    .regular
                        .tint(Color.rossAccent.opacity(0.12))
                        .interactive(),
                    in: .rect(cornerRadius: 15)
                )
        } else {
            content
                .rossGlassSurface(cornerRadius: 15, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1, strokeOpacity: 0.48)
        }
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
                    Text(rossLocalized("no_linked_source_yet"))
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
                detail: alphaSourceRefDetailLabel(sourceRef),
                systemImage: "doc.text",
                isInteractive: true
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
            return rossLocalized("this_file")
        }
        return label
    }

    if label == context {
        return rossLocalized("this_file")
    }

    for prefix in ["\(context) ", "\(context): ", "\(context) · "] {
        if label.hasPrefix(prefix) {
            let shortened = String(label.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return shortened.isEmpty ? rossLocalized("this_file") : shortened
        }
    }

    return label
}

func alphaSourceRefDetailLabel(_ sourceRef: AlphaSourceRef) -> String? {
    if sourceRef.documentTitle.localizedCaseInsensitiveContains("Matter memory") {
        return rossLocalized("matter_details")
    }

    switch sourceRef.effectiveSourceCategory {
    case .documentSource:
        return sourceRef.pageNumber > 0 ? alphaPageLabel(sourceRef.pageNumber) : rossLocalized("no_linked_page")
    case .matterDetail:
        let field = sourceRef.paragraphRange?.trimmingCharacters(in: .whitespacesAndNewlines)
        return field?.isEmpty == false ? field : rossLocalized("matter_details")
    case .rossSuggestion:
        return rossLocalized("suggestion")
    case .userConfirmedFact:
        return rossLocalized("confirmed")
    case .publicLawSource:
        return "Legal Search"
    }
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
            .rossNativeGlassSurface(
                tint: tint.opacity(0.16),
                shape: Capsule(),
                fallbackFillOpacity: 0.72,
                fallbackStrokeOpacity: 0.46
            )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
