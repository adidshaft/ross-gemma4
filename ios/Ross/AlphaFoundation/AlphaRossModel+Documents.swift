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

func alphaPossibleConflictMessage(
    matterLabel: String,
    matterValue: String,
    fileValue: String,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(
        format: rossLocalized("possible_conflict_found_detail", languageCode: languageCode),
        matterLabel,
        matterValue,
        rossLocalized("file_value", languageCode: languageCode),
        fileValue
    )
}

func alphaReviewItemResolvedSummary(_ resolution: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("review_item_resolved_summary", languageCode: languageCode), resolution)
}

func alphaConflictResolvedUsingFileValueSummary(_ value: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("conflict_resolved_using_file_value", languageCode: languageCode), value)
}

func alphaAlternateReferenceNoteLine(documentTitle: String, alternate: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("alternate_reference_from_document", languageCode: languageCode), documentTitle, alternate)
}

func alphaPrepareFileForDateHighlight(_ date: Date, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(
        format: rossLocalized("prepare_file_for_date", languageCode: languageCode),
        date.formatted(date: .abbreviated, time: .omitted)
    )
}

func alphaDocumentReviewSummaryLabel(
    fieldsFound: Int,
    verified: Int,
    pending: Int,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(
        format: rossLocalized("document_review_summary_counts", languageCode: languageCode),
        fieldsFound,
        verified,
        pending
    )
}

func alphaBetterExtractionStandardMessage(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("document_review_upgrade_standard", languageCode: languageCode)
}

func alphaBetterExtractionAdvancedMessage(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("document_review_upgrade_advanced_scan", languageCode: languageCode)
}

extension AlphaRossModel {

    func rerunReview(caseId: UUID, documentId: UUID) async {
        guard let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId }) else {
            return
        }
        let requestedTier = activePack?.tier ?? persisted.settings.activeTier ?? selectedTier
        let runtimeEnvironment = alphaLocalRuntimeEnvironment(
            activePack: activePack,
            requestedTier: requestedTier,
            installedPacks: persisted.installedPacks
        )
        let result = await store.runLocalExtraction(
            caseId: caseId,
            document: document,
            activePack: activePack,
            runtimeEnvironment: runtimeEnvironment
        )
        applyExtractionResult(result, caseId: caseId, documentId: documentId)
    }

    func deleteDocument(caseId: UUID, documentId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        let removedDocument = caseMatter.documents.first(where: { $0.id == documentId })
        if let relativePath = removedDocument?.storedRelativePath {
            try? FileManager.default.removeItem(at: alphaAbsoluteURL(for: relativePath))
        }
        caseMatter.documents.removeAll { $0.id == documentId }
        caseMatter.sourceRefs.removeAll { $0.documentId == documentId }
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        persisted.tasks = (persisted.tasks ?? []).filter { $0.caseId != caseId || !($0.notes?.contains(removedDocument?.title ?? "") ?? false) }
        globalAskSelectedDocumentIDs.remove(documentId)
        askSelectedDocumentIDs = askSelectedDocumentIDs.mapValues { ids in
            var updated = ids
            updated.remove(documentId)
            return updated
        }.filter { !$0.value.isEmpty }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Document removed locally",
                detail: "\(removedDocument?.title ?? "Document") was removed from this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://document-delete",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
    }

    func moveDocument(caseId: UUID, documentId: UUID, by offset: Int) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard let currentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }) else { return }
        let targetIndex = min(
            max(currentIndex + offset, 0),
            caseMatter.documents.count - 1
        )
        guard targetIndex != currentIndex else { return }

        let movedDocument = caseMatter.documents.remove(at: currentIndex)
        caseMatter.documents.insert(movedDocument, at: targetIndex)
        caseMatter.updatedAt = .now
        persisted.cases[caseIndex] = caseMatter
        persist(workspaceChanged: true)
    }

    func updateDocumentAdvocateNote(caseId: UUID, documentId: UUID, note: String) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }) else { return }

        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        caseMatter.documents[documentIndex].advocateNote = cleaned.isEmpty ? nil : cleaned
        caseMatter.updatedAt = .now
        persisted.cases[caseIndex] = caseMatter
        persist(workspaceChanged: true)
    }

    func updateDocumentTitle(caseId: UUID, documentId: UUID, title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }) else { return }

        let oldTitle = caseMatter.documents[documentIndex].title
        guard oldTitle != cleaned else { return }
        caseMatter.documents[documentIndex].title = cleaned
        caseMatter.documents[documentIndex].extractedFields = caseMatter.documents[documentIndex].extractedFields.map { field in
            var updated = field
            updated.sourceRefs = updated.sourceRefs.map { sourceRef in
                guard sourceRef.documentId == documentId else { return sourceRef }
                var renamed = sourceRef
                renamed.documentTitle = cleaned
                return renamed
            }
            return updated
        }
        caseMatter.documents[documentIndex].extractionFindings = caseMatter.documents[documentIndex].extractionFindings.map { finding in
            var updated = finding
            updated.sourceRefs = updated.sourceRefs.map { sourceRef in
                guard sourceRef.documentId == documentId else { return sourceRef }
                var renamed = sourceRef
                renamed.documentTitle = cleaned
                return renamed
            }
            return updated
        }
        caseMatter.sourceRefs = caseMatter.sourceRefs.map { sourceRef in
            guard sourceRef.documentId == documentId else { return sourceRef }
            var renamed = sourceRef
            renamed.documentTitle = cleaned
            return renamed
        }
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: "Document renamed from '\(oldTitle)' to '\(cleaned)'.",
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        persist(workspaceChanged: true)
    }

    func suggestedDocumentTitle(caseId: UUID, documentId: UUID) -> String? {
        guard let caseMatter = persisted.cases.first(where: { $0.id == caseId }),
              let document = caseMatter.documents.first(where: { $0.id == documentId }) else {
            return nil
        }
        return alphaSuggestedDocumentTitle(caseMatter: caseMatter, document: document)
    }

    func askCase(caseId: UUID) {
        let question = askDrafts[caseId] ?? ""
        submitAsk(question: question, scopeCaseID: caseId, webEnabled: false)
    }

    func openSourceRef(_ ref: AlphaSourceRef) {
        if ref.effectiveSourceCategory == .matterDetail || !sourceRefPointsToDocument(ref) {
            path.append(.caseWorkspace(ref.caseId))
            return
        }
        path.append(.documentViewer(ref.caseId, ref.documentId, ref.pageNumber))
    }

    func visibleExtractedFields(caseId: UUID, documentId: UUID) -> [AlphaExtractedLegalField] {
        let ignored = ignoredFieldIDs(caseId: caseId, documentId: documentId)
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return [] }

        return document.extractedFields
            .filter { !ignored.contains($0.id) }
            .sorted {
                let lhs = alphaFieldSortRank($0.fieldType)
                let rhs = alphaFieldSortRank($1.fieldType)
                if lhs == rhs {
                    return $0.createdAt < $1.createdAt
                }
                return lhs < rhs
            }
    }

    func reviewFindings(caseId: UUID, documentId: UUID) -> [AlphaExtractionFinding] {
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return [] }
        return document.extractionFindings.filter { !$0.resolved }
    }

    func reviewSummary(caseId: UUID, documentId: UUID) -> String? {
        guard
            let document = persisted.cases.first(where: { $0.id == caseId })?.documents.first(where: { $0.id == documentId })
        else { return nil }

        let visibleFields = visibleExtractedFields(caseId: caseId, documentId: documentId)
        let verifiedCount = visibleFields.count { !$0.needsReview || $0.userCorrected }
        let pendingCount = visibleFields.filter(\.needsReview).count
        switch (visibleFields.isEmpty, document.classification == nil, pendingCount > 0 || document.extractionFindings.contains(where: { !$0.resolved })) {
        case (true, true, _):
            return nil
        case (_, _, true):
            return alphaDocumentReviewSummaryLabel(fieldsFound: visibleFields.count, verified: verifiedCount, pending: pendingCount)
        default:
            return alphaDocumentReviewSummaryLabel(fieldsFound: visibleFields.count, verified: verifiedCount, pending: 0)
        }
    }

    func extractionUpgradeMessage(for document: AlphaCaseDocument) -> String? {
        let mode = activeExtractionMode
        if mode == .basic {
            return alphaBetterExtractionStandardMessage()
        }
        if mode == .quickStart,
           document.languageProfile?.primaryLanguage == .mixed || document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return alphaBetterExtractionAdvancedMessage()
        }
        if mode == .quickStart {
            return alphaBetterExtractionStandardMessage()
        }
        if mode == .caseAssociate,
           document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return alphaBetterExtractionAdvancedMessage()
        }
        return nil
    }

    func acceptExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = caseMatter.documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        caseMatter.documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func ignoreExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let field = caseMatter.documents[documentIndex].extractedFields.first(where: { $0.id == fieldId })
        else { return }

        caseMatter.advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                fieldId: field.id,
                oldValue: field.value,
                newValue: "Ignored",
                correctionType: .ignoreField
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func applyFieldCorrection(caseId: UUID, documentId: UUID, fieldId: UUID, newValue: String) {
        let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = caseMatter.documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        let original = caseMatter.documents[documentIndex].extractedFields[fieldIndex]
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].value = cleaned
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].normalizedValue = cleaned.lowercased()
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].userCorrected = true
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].extractionPass = .userCorrected
        caseMatter.documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        caseMatter.advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                fieldId: fieldId,
                oldValue: original.value,
                newValue: cleaned,
                correctionType: alphaCorrectionType(for: original.fieldType)
            ),
            at: 0
        )
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: "\(original.label) updated to '\(cleaned)' during advocate review.",
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func updateDocumentClassification(caseId: UUID, documentId: UUID, type: AlphaLegalDocumentType) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }) else { return }

        if caseMatter.documents[documentIndex].classification == nil {
            caseMatter.documents[documentIndex].classification = AlphaLegalDocumentClassification(
                documentId: documentId,
                type: type,
                subtype: nil,
                confidence: 0.64,
                sourceRefs: [],
                needsReview: false
            )
        } else {
            let confidence = caseMatter.documents[documentIndex].classification?.confidence ?? 0.64
            caseMatter.documents[documentIndex].classification?.type = type
            caseMatter.documents[documentIndex].classification?.needsReview = false
            caseMatter.documents[documentIndex].classification?.confidence = max(confidence, 0.64)
        }

        if type.blocksAutomaticLegalFactSaving {
            caseMatter.documents[documentIndex].extractedFields.removeAll()
            caseMatter.documents[documentIndex].extractionFindings.removeAll { finding in
                finding.kind == .documentClassificationNeedsReview ||
                    finding.kind == .caseNumberConflict ||
                    finding.kind == .dateConflict ||
                    finding.kind == .partyConflict ||
                    finding.kind == .courtConflict
            }
        }

        caseMatter.advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                oldValue: nil,
                newValue: type.rawValue,
                correctionType: .documentType
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func resolveFinding(caseId: UUID, documentId: UUID, findingId: UUID, resolution: String) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let findingIndex = caseMatter.documents[documentIndex].extractionFindings.firstIndex(where: { $0.id == findingId })
        else { return }

        caseMatter.documents[documentIndex].extractionFindings[findingIndex].resolved = true
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: alphaReviewItemResolvedSummary(resolution),
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func acceptReviewQueueItem(_ item: AlphaReviewQueueItem) {
        switch item.target {
        case .extractedField(let fieldId):
            acceptExtractedField(caseId: item.caseId, documentId: item.documentId, fieldId: fieldId)
        case .finding(let findingId):
            resolveFinding(caseId: item.caseId, documentId: item.documentId, findingId: findingId, resolution: rossLocalized("review_confirmed_from_inline_review"))
        }
    }

    func dismissReviewQueueItem(_ item: AlphaReviewQueueItem) {
        switch item.target {
        case .extractedField(let fieldId):
            ignoreExtractedField(caseId: item.caseId, documentId: item.documentId, fieldId: fieldId)
        case .finding(let findingId):
            resolveFinding(caseId: item.caseId, documentId: item.documentId, findingId: findingId, resolution: rossLocalized("review_dismissed_from_inline_review"))
        }
    }

    func useFileValueForConflict(caseId: UUID, documentId: UUID, findingId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let findingIndex = caseMatter.documents[documentIndex].extractionFindings.firstIndex(where: { $0.id == findingId })
        else { return }

        let finding = caseMatter.documents[documentIndex].extractionFindings[findingIndex]
        guard let value = finding.fileValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }

        switch finding.fieldType {
        case .caseNumber:
            caseMatter.caseNumber = value
        case .court:
            caseMatter.forum = value
        case .partyName:
            caseMatter.partiesSummary = value
        case .nextDate, .date:
            if let parsedDate = alphaParsedDate(from: value) {
                caseMatter.nextHearing = parsedDate
                upsertMatterDate(
                    in: &caseMatter,
                    title: AlphaMatterDateKind.hearing.title,
                    kind: .hearing,
                    date: parsedDate,
                    sourceRef: finding.sourceRefs.first
                )
            }
        default:
            break
        }

        caseMatter.documents[documentIndex].extractionFindings[findingIndex].resolved = true
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: alphaConflictResolvedUsingFileValueSummary(value),
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func saveConflictAsAlternateReference(caseId: UUID, documentId: UUID, findingId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        var caseMatter = persisted.cases[caseIndex]
        guard
            let documentIndex = caseMatter.documents.firstIndex(where: { $0.id == documentId }),
            let findingIndex = caseMatter.documents[documentIndex].extractionFindings.firstIndex(where: { $0.id == findingId })
        else { return }

        let finding = caseMatter.documents[documentIndex].extractionFindings[findingIndex]
        let alternate = finding.fileValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rossLocalized("no_linked_source_yet")
        let existingNotes = caseMatter.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteLine = alphaAlternateReferenceNoteLine(documentTitle: caseMatter.documents[documentIndex].title, alternate: alternate)
        caseMatter.notes = [existingNotes, noteLine].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "\n")
        caseMatter.documents[documentIndex].extractionFindings[findingIndex].resolved = true
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
        syncReviewTasks(caseId: caseId, documentId: documentId)
        persist(workspaceChanged: true)
    }

    func matterConflictFindings(
        caseMatter: AlphaCaseMatter,
        document: AlphaCaseDocument,
        fields: [AlphaExtractedLegalField]
    ) -> [AlphaExtractionFinding] {
        var findings: [AlphaExtractionFinding] = []

        func appendConflict(
            field: AlphaExtractedLegalField,
            kind: AlphaExtractionFindingKind,
            matterLabel: String,
            matterValue: String
        ) {
            let fileValue = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = matterValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fileValue.isEmpty, !existing.isEmpty else { return }
            guard normalizeForMatterConflict(fileValue) != normalizeForMatterConflict(existing) else { return }
            findings.append(
                AlphaExtractionFinding(
                    caseId: caseMatter.id,
                    documentId: document.id,
                    kind: kind,
                    message: alphaPossibleConflictMessage(matterLabel: matterLabel, matterValue: existing, fileValue: fileValue),
                    sourceRefs: field.sourceRefs,
                    severity: .warning,
                    fieldType: field.fieldType,
                    matterValue: existing,
                    fileValue: fileValue
                )
            )
        }

        for field in fields where !field.needsReview || field.userCorrected {
            switch field.fieldType {
            case .caseNumber:
                if let caseNumber = caseMatter.caseNumber {
                    appendConflict(field: field, kind: .caseNumberConflict, matterLabel: rossLocalized("matter_value"), matterValue: caseNumber)
                }
            case .court:
                appendConflict(field: field, kind: .courtConflict, matterLabel: rossLocalized("matter_value"), matterValue: caseMatter.forum)
            case .partyName:
                if let parties = caseMatter.partiesSummary {
                    appendConflict(field: field, kind: .partyConflict, matterLabel: rossLocalized("matter_value"), matterValue: parties)
                }
            case .nextDate:
                if let nextHearing = caseMatter.nextHearing, let parsed = alphaParsedDate(from: field.value), !Calendar.current.isDate(nextHearing, inSameDayAs: parsed) {
                    appendConflict(
                        field: field,
                        kind: .dateConflict,
                        matterLabel: rossLocalized("matter_value"),
                        matterValue: nextHearing.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            default:
                break
            }
        }

        return findings
    }

    func normalizeForMatterConflict(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func appendSourceRefs(_ refs: [AlphaSourceRef], to caseMatter: inout AlphaCaseMatter) {
        for ref in refs {
            let exists = caseMatter.sourceRefs.contains {
                $0.documentId == ref.documentId &&
                $0.pageNumber == ref.pageNumber &&
                ($0.textSnippet ?? "") == (ref.textSnippet ?? "")
            }
            if !exists {
                caseMatter.sourceRefs.insert(ref, at: 0)
            }
        }
    }

    func mergeCaseMemoryUpdates(_ updates: [AlphaCaseMemoryUpdate], into caseMatter: inout AlphaCaseMatter) {
        for update in updates.reversed() {
            let exists = caseMatter.caseMemoryUpdates.contains {
                $0.summary == update.summary && $0.affectedDocuments == update.affectedDocuments
            }
            if !exists {
                caseMatter.caseMemoryUpdates.insert(update, at: 0)
            }
        }
    }

    func mergeUserCorrectedFields(
        previousFields: [AlphaExtractedLegalField],
        newFields: [AlphaExtractedLegalField]
    ) -> [AlphaExtractedLegalField] {
        let corrected = previousFields
            .filter(\.userCorrected)
            .reduce(into: [String: AlphaExtractedLegalField]()) { result, field in
                result["\(field.fieldType.rawValue):\(field.normalizedValue ?? field.value.lowercased())"] = field
            }

        let merged = newFields.map { field in
            corrected["\(field.fieldType.rawValue):\(field.normalizedValue ?? field.value.lowercased())"] ?? field
        }
        let preserved = corrected.values.filter { correctedField in
            !newFields.contains {
                $0.fieldType == correctedField.fieldType &&
                ($0.normalizedValue ?? $0.value.lowercased()) == (correctedField.normalizedValue ?? correctedField.value.lowercased())
            }
        }
        return merged + preserved
    }

    func refreshCaseWorkspace(at caseIndex: Int) {
        var caseMatter = persisted.cases[caseIndex]
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
    }

    func refreshCaseWorkspace(caseMatter: inout AlphaCaseMatter) {
        let verifiedFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter(\.needsReview)
        let allOpenTaskItems = tasks(for: caseMatter.id).filter { $0.status == .open }
        let planningTaskItems = allOpenTaskItems.filter { !isRossSuggestedTask($0) }
        let nextOpenTask = planningTaskItems.first
        let latestDocumentTitle = caseMatter.documents.sorted { $0.importedAt > $1.importedAt }.first?.title
        let ignoredFieldIDs = Set(caseMatter.advocateCorrections.filter { $0.correctionType == .ignoreField }.compactMap(\.fieldId))
        let reviewItemCount = caseMatter.documents.reduce(into: 0) { total, document in
            total += document.extractedFields.filter { $0.needsReview && !ignoredFieldIDs.contains($0.id) }.count
            total += document.extractionFindings.count { !$0.resolved }
        }

        if let forum = verifiedFields.first(where: { $0.fieldType == .court })?.value,
           alphaIsCourtNotYetSpecified(caseMatter.forum) {
            caseMatter.forum = forum
        }

        if let caseNumber = verifiedFields.first(where: { $0.fieldType == .caseNumber })?.value,
           (caseMatter.caseNumber?.isEmpty ?? true) {
            caseMatter.caseNumber = caseNumber
        }

        let verifiedPartyNames = Array(
            NSOrderedSet(
                array: verifiedFields
                    .filter { $0.fieldType == .partyName }
                    .map(\.value)
            )
        ).compactMap { $0 as? String }
        if caseMatter.partiesSummary == nil || caseMatter.partiesSummary?.isEmpty == true,
           !verifiedPartyNames.isEmpty {
            caseMatter.partiesSummary = verifiedPartyNames.joined(separator: " · ")
        }

        if let nextDate = verifiedFields.first(where: { $0.fieldType == .nextDate })?.value {
            caseMatter.localNotice = alphaMatterLocalNoticeNextDate(nextDate)
            if let parsedDate = alphaParsedDate(from: nextDate) {
                if caseMatter.nextHearing == nil || Calendar.current.isDate(caseMatter.nextHearing ?? parsedDate, inSameDayAs: parsedDate) {
                    caseMatter.nextHearing = parsedDate
                    upsertMatterDate(
                        in: &caseMatter,
                        title: AlphaMatterDateKind.hearing.title,
                        kind: .hearing,
                        date: parsedDate,
                        sourceRef: verifiedFields.first(where: { $0.fieldType == .nextDate })?.sourceRefs.first
                    )
                }
            }
        } else if let nextHearing = caseMatter.nextHearing {
            upsertMatterDate(in: &caseMatter, title: AlphaMatterDateKind.hearing.title, kind: .hearing, date: nextHearing)
        }

        let classifications = caseMatter.documents.compactMap { $0.classification?.type.title.lowercased() }
        let classificationText = classifications.isEmpty ? nil : classifications.joined(separator: ", ")
        if caseMatter.documents.isEmpty {
            caseMatter.summary = alphaMatterReadyForFirstDocumentLabel()
        } else {
            let readingCount = caseMatter.documents.filter { $0.processingState == .readingText || $0.processingState == .imported }.count
            let readyCount = caseMatter.documents.filter { $0.processingState == .ready }.count
            var summaryParts = [
                readingCount > 0
                    ? alphaMatterDocumentsReadingSummary(documentCount: caseMatter.documents.count, readingCount: readingCount)
                    : alphaMatterDocumentsReadSummary(documentCount: caseMatter.documents.count)
            ]
            if readyCount > 0 {
                summaryParts.append(alphaMatterReadyDocumentsLabel(readyCount))
            }
            if let classificationText {
                summaryParts.append(alphaMatterFileTypesSeenLabel(classificationText))
            }
            if let nextHearing = caseMatter.nextHearing {
                summaryParts.append(alphaMatterNextDateCapturedLabel(nextHearing))
            }
            if reviewItemCount > 0 {
                summaryParts.append(alphaReviewItemsNeedAdvocateReviewLabel(reviewItemCount))
            } else if !allOpenTaskItems.isEmpty {
                summaryParts.append(alphaMatterOpenTasksSavedLabel(allOpenTaskItems.count))
            }
            if let latestDocumentTitle {
                summaryParts.append(alphaMatterLatestFileLabel(latestDocumentTitle))
            }
            caseMatter.summary = summaryParts.joined(separator: " ")
        }

        let issueCandidates = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .prayer }
            .map(\.value)
        if issueCandidates.isEmpty {
            var fallbackHighlights: [String] = []
            if let nextHearing = caseMatter.nextHearing {
                fallbackHighlights.append(alphaPrepareFileForDateHighlight(nextHearing))
            }
            if let nextOpenTask {
                fallbackHighlights.append(nextOpenTask.title)
            }
            if reviewItemCount > 0 {
                fallbackHighlights.append(alphaResolveReviewItemsBeforeRelyingLabel(reviewItemCount))
            }
            caseMatter.issueHighlights = fallbackHighlights.isEmpty
                ? [alphaReviewExtractedLegalIssuesLabel()]
                : Array(fallbackHighlights.prefix(4))
        } else {
            caseMatter.issueHighlights = Array(issueCandidates.prefix(4))
        }

        let evidenceCandidates = caseMatter.documents
            .flatMap(\.extractionFindings)
            .filter { !$0.resolved }
            .map(\.message)
        caseMatter.evidenceNotes = evidenceCandidates.isEmpty ? [alphaExtractionAvailableForMatterLabel()] : Array(evidenceCandidates.prefix(4))

        var generatedTasks: [String] = []
        if let nextHearing = caseMatter.nextHearing {
            generatedTasks.append("Prepare this matter for \(nextHearing.formatted(date: .abbreviated, time: .omitted)).")
        }
        if let nextOpenTask {
            if let dueDate = nextOpenTask.dueDate {
                generatedTasks.append("\(nextOpenTask.title) by \(dueDate.formatted(date: .abbreviated, time: .omitted)).")
            } else {
                generatedTasks.append(nextOpenTask.title)
            }
        }
        if reviewItemCount > 0 {
            generatedTasks.append(alphaResolveReviewItemsBeforeRelyingLabel(reviewItemCount))
        } else if !pendingFields.isEmpty {
            generatedTasks.append(alphaReviewUncertainExtractedFieldsLabel())
        }
        if caseMatter.documents.isEmpty {
            generatedTasks.append(alphaImportFirstMatterDocumentLabel())
        } else {
            generatedTasks.append(alphaOpenSourceChipsBeforeSharingLabel())
        }
        generatedTasks.append(alphaGenerateLocalDraftLabel())
        var uniqueTasks: [String] = []
        for task in generatedTasks where !uniqueTasks.contains(task) {
            uniqueTasks.append(task)
        }
        caseMatter.draftTasks = Array(uniqueTasks.prefix(3))
        caseMatter.updatedAt = .now
    }

    func upsertMatterDate(
        in caseMatter: inout AlphaCaseMatter,
        title: String,
        kind: AlphaMatterDateKind,
        date: Date,
        sourceRef: AlphaSourceRef? = nil
    ) {
        if let existingIndex = caseMatter.dates.firstIndex(where: { $0.kind == kind && $0.status == .scheduled }) {
            caseMatter.dates[existingIndex].title = title
            caseMatter.dates[existingIndex].date = date
            caseMatter.dates[existingIndex].sourceRef = sourceRef ?? caseMatter.dates[existingIndex].sourceRef
            caseMatter.dates[existingIndex].updatedAt = .now
        } else {
            caseMatter.dates.insert(
                AlphaMatterDate(
                    caseId: caseMatter.id,
                    title: title,
                    kind: kind,
                    date: date,
                    sourceRef: sourceRef
                ),
                at: 0
            )
        }
        caseMatter.dates.sort { $0.date < $1.date }
    }

    func upsertReviewTasks(for caseMatter: AlphaCaseMatter, document: AlphaCaseDocument) {
        let reviewTitles = Set(
            visibleExtractedFields(caseId: caseMatter.id, documentId: document.id)
                .filter(\.needsReview)
                .map { alphaReviewTitle(for: $0.fieldType) } +
                reviewFindings(caseId: caseMatter.id, documentId: document.id)
                .map { alphaReviewTitle(for: $0.kind) }
        )

        var taskList = persisted.tasks ?? []
        for title in reviewTitles {
            let exists = taskList.contains {
                $0.status == .open &&
                    $0.caseId == caseMatter.id &&
                    $0.source == .extraction &&
                    $0.title == title
            }
            if !exists {
                taskList.insert(
                    AlphaTaskItem(
                        caseId: caseMatter.id,
                        title: title,
                        notes: "Created from document review for \(document.title).",
                        dueDate: caseMatter.nextHearing,
                        priority: .high,
                        source: .extraction
                    ),
                    at: 0
                )
            }
        }
        persisted.tasks = taskList
    }

    func syncReviewTasks(caseId: UUID, documentId: UUID) {
        let remainingTitles = Set(
            visibleExtractedFields(caseId: caseId, documentId: documentId)
                .filter(\.needsReview)
                .map { alphaReviewTitle(for: $0.fieldType) } +
                reviewFindings(caseId: caseId, documentId: documentId)
                .map { alphaReviewTitle(for: $0.kind) }
        )
        persisted.tasks = (persisted.tasks ?? []).map { task in
            guard task.caseId == caseId, task.source == .extraction else { return task }
            if remainingTitles.contains(task.title) {
                return task
            }
            var updatedTask = task
            updatedTask.status = .done
            updatedTask.updatedAt = .now
            return updatedTask
        }
    }

    func completeImportFirstDocumentTask(caseId: UUID) {
        persisted.tasks = (persisted.tasks ?? []).map { task in
            guard task.caseId == caseId, task.status == .open else { return task }
            let normalized = task.title
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard normalized == "import first document" || normalized == "import the first case document" else { return task }
            var updatedTask = task
            updatedTask.status = .done
            updatedTask.updatedAt = .now
            return updatedTask
        }
    }

    func dockCommandAction(for rawInput: String) -> DockCommandAction? {
        let normalized = rawInput
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let exportCommands: [([String], String, String)] = [
            (["generate chronology", "prepare chronology", "draft chronology", "export chronology", "create chronology"], "chronology_report", rossLocalized("draft_action_chronology")),
            (["generate case note", "prepare case note", "draft case note", "export case note"], "case_note", rossLocalized("draft_action_case_note")),
            (["generate hearing note", "prepare hearing note", "draft hearing note", "export hearing note"], "case_note", rossLocalized("draft_action_hearing_note")),
            (["generate order summary", "prepare order summary", "draft order summary", "export order summary"], "order_summary", rossLocalized("draft_action_order_summary")),
            (["generate transcript", "draft transcript", "export transcript", "generate chat transcript", "generate thread transcript"], "chat_transcript", rossLocalized("export_thread_transcript"))
        ]

        let lowered = normalized.lowercased()
        if let exportCommand = exportCommands.first(where: { prefixes, _, _ in
            prefixes.contains(where: { lowered.hasPrefix($0) })
        }) {
            return .generateExport(kind: exportCommand.1, label: exportCommand.2)
        }

        if [
            "review this document",
            "review this file",
            "review this order",
            "review latest document",
            "review latest order",
            "review this document again",
            "review this file again"
        ].contains(where: { lowered.hasPrefix($0) }) {
            return .rerunDocumentReview
        }

        if [
            "create tasks from this document",
            "create tasks from this file",
            "create tasks from this order",
            "create tasks from latest order",
            "create tasks from latest document"
        ].contains(where: { lowered.hasPrefix($0) }) {
            return .createTasksFromDocument
        }

        let routineCommands: [([String], AlphaRoutineKind)] = [
            (["prepare today", "run morning brief"], .morningBrief),
            (["refresh this matter", "update summary"], .afterDocumentImport),
            (["prepare hearing note"], .beforeHearing),
            (["scan missing facts"], .missingFactsScan),
            (["refresh drafts"], .draftRefresh),
            (["prepare public-law search", "prepare public law search"], .publicLawPreview)
        ]
        if let command = routineCommands.first(where: { prefixes, _ in
            prefixes.contains(where: { lowered.hasPrefix($0) })
        }) {
            return .runRoutine(command.1)
        }

        if let body = dockCommandBody(in: normalized, prefixes: ["add task ", "create task ", "save task ", "add reminder ", "save reminder ", "remind me to "]) {
            let (title, dueDate) = dockCommandTitleAndDate(from: body)
            guard !title.isEmpty else {
                return .guidance(
                    title: rossLocalized("dock_guidance_add_task_title"),
                    detail: rossLocalized("dock_guidance_add_task_title_detail")
                )
            }
            return .addTask(title: title, dueDate: dueDate)
        }

        if let body = dockCommandBody(in: normalized, prefixes: ["mark task ", "complete task ", "finish task "]) {
            let cleaned = body
                .replacingOccurrences(of: "\\b(done|complete|completed|finished)\\b", with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                return .guidance(
                    title: rossLocalized("dock_guidance_name_task"),
                    detail: rossLocalized("dock_guidance_name_task_detail")
                )
            }
            return .completeTask(title: cleaned)
        }

        let specificDateCommands: [([String], AlphaMatterDateKind)] = [
            (["set next hearing ", "save next hearing ", "add next hearing ", "save hearing ", "add hearing "], .hearing),
            (["save filing deadline ", "add filing deadline ", "set filing deadline "], .filingDeadline),
            (["save compliance date ", "add compliance date ", "set compliance date "], .complianceDate),
            (["save client follow-up ", "add client follow-up ", "set client follow-up "], .clientFollowUp)
        ]

        for (prefixes, kind) in specificDateCommands {
            if let body = dockCommandBody(in: normalized, prefixes: prefixes) {
                let (title, date) = dockCommandTitleAndDate(from: body)
                guard let date else {
                    return .guidance(
                        title: rossLocalized("dock_guidance_add_date"),
                        detail: String(
                            format: rossLocalized("dock_guidance_add_specific_date_detail"),
                            prefixes[0].trimmingCharacters(in: .whitespaces)
                        )
                    )
                }
                return .addMatterDate(title: title.ifEmpty(kind.title), kind: kind, date: date)
            }
        }

        if let body = dockCommandBody(in: normalized, prefixes: ["save date ", "add date ", "set date "]) {
            let (title, date) = dockCommandTitleAndDate(from: body)
            guard let date else {
                return .guidance(
                    title: rossLocalized("dock_guidance_add_date"),
                    detail: rossLocalized("dock_guidance_add_date_detail")
                )
            }
            let inferredKind = inferredMatterDateKind(for: title)
            return .addMatterDate(title: title.ifEmpty(inferredKind.title), kind: inferredKind, date: date)
        }

        return nil
    }

    func alphaReviewTitle(for findingKind: AlphaExtractionFindingKind) -> String {
        switch findingKind {
        case .lowConfidenceOcr, .languageUncertain, .possibleHandwriting:
            rossLocalized("document_status_low_confidence_scan")
        case .ambiguousOrderDirection:
            rossLocalized("review_title_check_order_direction")
        case .dateConflict:
            rossLocalized("review_title_confirm_next_date")
        case .partyConflict:
            rossLocalized("review_title_review_party_name")
        default:
            rossLocalized("please_confirm")
        }
    }

    func alphaCorrectionType(for fieldType: AlphaExtractedLegalFieldType) -> AlphaAdvocateCorrectionType {
        switch fieldType {
        case .date, .nextDate, .limitationDate:
            return .date
        case .partyName:
            return .party
        default:
            return .fieldValue
        }
    }

    func persist(workspaceChanged: Bool = false) {
        if workspaceChanged {
            invalidateWorkspaceDerivedState()
        }
        var snapshot = persisted
        snapshot.publicLawDraft = publicLawDraft
        snapshot.publicLawPreview = publicLawPreview
        snapshot.publicLawResults = publicLawResults
        pendingPersistTask?.cancel()
        pendingPersistTask = Task { [store] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            try? await store.replace(with: snapshot)
            if snapshot.settings.deviceCacheEnabled {
                try? await store.writeDeviceCacheMetadata(snapshot)
            } else {
                try? await store.clearDeviceCache()
            }
        }
    }
}
