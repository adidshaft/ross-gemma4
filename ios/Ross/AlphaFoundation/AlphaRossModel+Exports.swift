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

extension AlphaRossModel {

    func exportURL(for report: AlphaExportedReport) -> URL {
        alphaAbsoluteURL(for: report.relativePath)
    }

    func applyExtractionResult(_ result: AlphaLocalExtractionResult, caseId: UUID, documentId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId })
        else { return }

        var caseMatter = persisted.cases[caseIndex]
        var document = caseMatter.documents[documentIndex]
        var findings = result.findings
        findings.append(contentsOf: matterConflictFindings(caseMatter: caseMatter, document: document, fields: result.extractedFields))
        document.pages = result.pages
        document.languageProfile = result.languageProfile
        document.classification = result.classification
        document.extractedFields = mergeUserCorrectedFields(previousFields: document.extractedFields, newFields: result.extractedFields)
        document.extractionRuns.insert(result.extractionRun, at: 0)
        document.extractionFindings = findings
        document.modelInvocations = result.modelInvocations
        document.indexingStatus = {
            switch result.extractionRun.status {
            case .failed:
                return .failed
            case .needsReview:
                return .partial
            default:
                return .indexed
            }
        }()
        document.lastIndexedAt = .now
        let fullText = result.pages.compactMap(\.extractedText).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullText.isEmpty {
            document.extractedText = fullText
        }
        document.dominantSourceSnippet = result.pages.compactMap { $0.anchorText ?? $0.snippet }.first ?? document.dominantSourceSnippet
        caseMatter.documents[documentIndex] = document

        if let classification = result.classification {
            appendSourceRefs(classification.sourceRefs, to: &caseMatter)
        }
        appendSourceRefs(result.extractedFields.flatMap(\.sourceRefs), to: &caseMatter)
        mergeCaseMemoryUpdates(result.caseMemoryUpdates, into: &caseMatter)
        if let nextDateValue = result.extractedFields.first(where: { $0.fieldType == .nextDate && (!$0.needsReview || $0.userCorrected) })?.value,
           let parsedDate = alphaParsedDate(from: nextDateValue),
           caseMatter.nextHearing == nil || Calendar.current.isDate(caseMatter.nextHearing ?? parsedDate, inSameDayAs: parsedDate) {
            caseMatter.nextHearing = parsedDate
        }
        refreshCaseWorkspace(caseMatter: &caseMatter)

        persisted.cases[caseIndex] = caseMatter
        upsertReviewTasks(for: caseMatter, document: document)
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Local extraction completed",
                detail: result.reviewQueue.summary,
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://local-extraction",
                success: result.extractionRun.status != .failed
            ),
            at: 0
        )
        let nextDateValue = result.extractedFields.first(where: { $0.fieldType == .nextDate && (!$0.needsReview || $0.userCorrected) })?.value
        let reviewItemCount = document.extractedFields.filter(\.needsReview).count + findings.filter { !$0.resolved }.count
        let reviewSummary = reviewItemCount == 0
            ? "This file is ready to use in the matter chat."
            : "\(alphaReviewItemCountLabel(reviewItemCount)) still need advocate confirmation before relying on this file."
        let classificationSummary = result.classification.map {
            $0.type.blocksAutomaticLegalFactSaving
                ? "Ross classified \(document.title) as \($0.type.title.lowercased()) and paused legal fact saving."
                : "Ross classified \(document.title) as \($0.type.title.lowercased())."
        } ?? "Ross finished re-reading \(document.title)."
        var threadSections = [classificationSummary, reviewSummary]
        if let nextDateValue {
            threadSections.insert("Next date captured: \(nextDateValue).", at: 1)
        }
        let threadSourceRefs = Array(
            (
                (result.classification?.sourceRefs ?? [])
                + result.extractedFields.flatMap(\.sourceRefs)
            ).prefix(3)
        )
        appendMatterThreadUpdate(
            caseId: caseId == alphaSharedWorkspaceID ? nil : caseId,
            title: "Review updated for \(document.title)",
            sections: threadSections,
            sourceRefs: threadSourceRefs,
            selectedDocumentIDs: [document.id],
            selectedDocumentTitles: [document.title],
            statusNote: reviewItemCount == 0 ? "Matter chat updated · ready to use" : "Matter chat updated · needs review",
            needsReviewWarning: reviewItemCount == 0 ? nil : "\(alphaReviewItemCountLabel(reviewItemCount)) still need advocate review."
        )
        persist(workspaceChanged: true)
    }
}
