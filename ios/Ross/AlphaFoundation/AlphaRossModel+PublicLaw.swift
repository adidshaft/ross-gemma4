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

func alphaPublicLawPrivacyReason(_ key: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("public_law_privacy_reason_\(key)", languageCode: languageCode)
}

func alphaPublicLawNoPrivateDataReason(languageCode: String = rossSelectedLanguageCode()) -> String {
    alphaPublicLawPrivacyReason("no_private_data", languageCode: languageCode)
}

func alphaPublicLawRemovedReasonsContainOnlyNoPrivateData(_ reasons: [String]) -> Bool {
    reasons.count == 1 && rossSupportedLanguageCodes().contains { languageCode in
        reasons[0] == alphaPublicLawNoPrivateDataReason(languageCode: languageCode)
    }
}

extension AlphaRossModel {

    func confirmPendingPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        guard publicLawSearchStatus != .running else { return }
        publicLawSearchStatus = .running
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_public_law_reviewed_title"),
                detail: rossLocalized("privacy_ledger_public_law_reviewed_detail"),
                purpose: .public_law_search,
                payloadClass: .no_case_data,
                endpointLabel: "device://public-law-review",
                success: true
            ),
            at: 0
        )
        persist()

        do {
            let results = try await publicLawSearchAction(preview)
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.publicLawResults = results
            let latestInvocationStatus: AlphaLocalModelInvocationStatus? = {
                guard
                    let sessionID = pendingPublicLawSessionID,
                    let turnID = pendingPublicLawTurnID
                else { return nil }
                let storageCaseID = pendingPublicLawScopeCaseID ?? alphaSharedWorkspaceID
                return persisted.cases
                    .first(where: { $0.id == storageCaseID })?
                    .chatSessions
                    .first(where: { $0.id == sessionID })?
                    .turns
                    .first(where: { $0.id == turnID })?
                    .modelInvocation?
                    .status
            }()
            latestAskResult?.statusNote = latestInvocationStatus == nil
                ? alphaPublicLawResultsStatus()
                : (latestInvocationStatus == .running
                    ? alphaPrivateAssistantRunningWithPublicLawStatus()
                    : alphaPrivateAssistantWithPublicLawStatus())
            updateStoredAskTurn(
                scopeCaseID: pendingPublicLawScopeCaseID,
                sessionID: pendingPublicLawSessionID,
                turnID: pendingPublicLawTurnID
            ) { turn in
                turn.publicLawPreview = preview
                turn.publicLawResults = results
                turn.statusNote = turn.modelInvocation == nil
                    ? alphaPublicLawResultsStatus()
                    : (turn.modelInvocation?.status == .running
                        ? alphaPrivateAssistantRunningWithPublicLawStatus()
                        : alphaPrivateAssistantWithPublicLawStatus())
            }
            publicLawResults = results
            persisted.publicLawCache.insert(
                AlphaPublicLawCacheItem(query: preview.query, resultTitles: results.map(\.title)),
                at: 0
            )
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: rossLocalized("privacy_ledger_public_law_sent_title"),
                    detail: rossLocalized("privacy_ledger_public_law_sent_detail"),
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: true
                ),
                at: 0
            )
            persisted.publicLawDraft = pendingPublicLawQuestion
            persisted.publicLawPreview = preview
            persisted.publicLawResults = results
            publicLawSearchStatus = .complete
            persist()
        } catch {
            latestAskResult?.publicLawPreview = preview
            latestAskResult?.publicLawResults = []
            latestAskResult?.statusNote = alphaPublicLawUnavailableStatus()
            updateStoredAskTurn(
                scopeCaseID: pendingPublicLawScopeCaseID,
                sessionID: pendingPublicLawSessionID,
                turnID: pendingPublicLawTurnID
            ) { turn in
                turn.publicLawPreview = preview
                turn.publicLawResults = []
                turn.statusNote = alphaPublicLawUnavailableStatus()
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: rossLocalized("privacy_ledger_public_law_unavailable_title"),
                    detail: rossLocalized("privacy_ledger_public_law_unavailable_detail"),
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: false
                ),
                at: 0
            )
            publicLawSearchStatus = .failed
            persist()
        }

        pendingPublicLawQuestion = nil
        pendingPublicLawScopeCaseID = nil
        pendingPublicLawSessionID = nil
        pendingPublicLawTurnID = nil
    }

    func appendAskResult(
        _ result: AlphaAskResult,
        persistToCase caseID: UUID?,
        includeReviewLedger: Bool = true
    ) -> AlphaAskResult {
        let storageCaseID = caseID ?? alphaSharedWorkspaceID
        let contextDocumentIDs = selectedAskDocumentIDs(for: caseID)
        let turn = AlphaChatTurn(
            kind: result.kind,
            question: result.question,
            answerTitle: result.answerTitle,
            answerSections: result.answerSections,
            sourceRefs: result.caseFileSources,
            selectedDocumentTitles: result.selectedDocumentTitles.isEmpty ? nil : result.selectedDocumentTitles,
            publicLawPreview: result.publicLawPreview,
            publicLawResults: result.publicLawResults,
            statusNote: result.statusNote,
            needsReviewWarning: result.needsReviewWarning
        )

        if let storedResult = appendStoredTurn(turn, to: storageCaseID, contextDocumentIDs: contextDocumentIDs) {
            if includeReviewLedger {
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: caseID == nil ? "Review run" : "Case review run",
                        detail: "The question and draft from your files stayed on this device.",
                        purpose: .local_only,
                        payloadClass: .local_only,
                        endpointLabel: caseID == nil ? "device://ask" : "device://ask-case",
                        success: true
                    ),
                    at: 0
                )
            }
            persist(workspaceChanged: true)
            return storedResult
        }

        let fallback = result
        askHistory.append(fallback)
        return fallback
    }

    func updatePendingPublicLawQuery(_ query: String) {
        guard var preview = publicLawPreview else { return }
        preview.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        publicLawPreview = preview
        latestAskResult?.publicLawPreview = preview
        updateStoredAskTurn(
            scopeCaseID: pendingPublicLawScopeCaseID,
            sessionID: pendingPublicLawSessionID,
            turnID: pendingPublicLawTurnID
        ) { turn in
            turn.publicLawPreview = preview
        }
        persisted.publicLawPreview = preview
        persist()
    }

    func runPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        guard publicLawSearchStatus != .running else { return }
        publicLawSearchStatus = .running
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_public_law_reviewed_title"),
                detail: rossLocalized("privacy_ledger_public_law_reviewed_detail"),
                purpose: .public_law_search,
                payloadClass: .no_case_data,
                endpointLabel: "device://public-law-review",
                success: true
            ),
            at: 0
        )
        persist()

        do {
            publicLawResults = try await backend.searchPublicLaw(preview: preview)
        } catch {
            publicLawResults = []
            publicLawSearchStatus = .failed
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: rossLocalized("privacy_ledger_public_law_unavailable_title"),
                    detail: rossLocalized("privacy_ledger_public_law_unavailable_detail"),
                    purpose: .public_law_search,
                    payloadClass: .sanitized_public_query,
                    endpointLabel: "/public-law/search",
                    success: false
                ),
                at: 0
            )
            persist()
            return
        }

        persisted.publicLawCache.insert(
            AlphaPublicLawCacheItem(query: preview.query, resultTitles: publicLawResults.map(\.title)),
            at: 0
        )
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = preview
        persisted.publicLawResults = publicLawResults
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_public_law_sent_title"),
                detail: rossLocalized("privacy_ledger_public_law_sent_detail"),
                purpose: .public_law_search,
                payloadClass: .sanitized_public_query,
                endpointLabel: "/public-law/search",
                success: true
            ),
            at: 0
        )
        publicLawSearchStatus = .complete
        persist()
    }

    func generateExport(kind: String, caseId: UUID?) async -> Bool {
        let caseMatter = caseId.flatMap { id in persisted.cases.first { $0.id == id } }
        let titleBase = caseMatter?.title ?? "Ross Report"
        let bodyLines = exportBodyLines(kind: kind, caseMatter: caseMatter)

        do {
            let report = try await store.createPDFExport(
                title: "\(titleBase) \(kind)",
                kind: kind,
                caseId: caseId,
                bodyLines: bodyLines
            )
            persisted.exports.insert(report, at: 0)
            if routineSettings.draftRefreshEnabled {
                rebuildPreparedWork(reason: .draftRefresh, caseId: caseId, persistAfter: false)
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Local export generated",
                    detail: "\(kind) was generated locally for advocate review.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://export",
                    success: true
                ),
                at: 0
            )
            persist()
            return true
        } catch {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Export generation failed",
                    detail: "Ross could not write the local report file.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://export",
                    success: false
                ),
                at: 0
            )
            persist()
            return false
        }
    }

    func publicLawFocusTerm(for type: AlphaLegalDocumentType) -> String? {
        switch type {
        case .pleading:
            return "pleading requirements and court procedure"
        case .order:
            return "court orders and order directions"
        case .judgment:
            return "judgment review and relief"
        case .affidavit:
            return "affidavit practice and evidence procedure"
        case .notice:
            return "statutory notice requirements"
        case .evidence:
            return "evidence procedure"
        case .clientNote, .correspondence:
            return nil
        case .courtFiling:
            return "court filing procedure"
        case .legalResearch:
            return "legal research and precedent"
        case .nonLegalDocument, .fictionalGameMaterial, .unknown, .misc:
            return nil
        }
    }

    func publicLawKeywords(from value: String) -> [String] {
        let lowered = value.lowercased()
        let patterns = [
            "commercial courts act",
            "negotiable instruments act",
            "arbitration act",
            "limitation act",
            "constitution of india",
            "written statement",
            "delay condonation",
            "interim maintenance",
            "interim relief",
            "injunction",
            "stay",
            "cheque dishonour",
            "article \\d+[a-z]*",
            "section \\d+[a-z]*",
            "order [a-z0-9]+(?: rules? \\d+[a-z]*(?:\\s*(?:,|and|to|-)\\s*\\d+[a-z]*)*)?"
        ]
        let matches: [String] = patterns.compactMap { pattern -> String? in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            let range = NSRange(location: 0, length: lowered.utf16.count)
            guard let match = regex.firstMatch(in: lowered, range: range) else { return nil }
            return (lowered as NSString).substring(with: match.range)
        }
        let sanitizedPhrase = lowered
            .replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !sanitizedPhrase.isEmpty, looksLikeLegalConcept(sanitizedPhrase) {
            let tokenCount = sanitizedPhrase.split(separator: " ").count
            if (3...10).contains(tokenCount) {
                return (Array(NSOrderedSet(array: matches + [sanitizedPhrase])) as? [String] ?? matches + [sanitizedPhrase]).filter(isSafePublicLawTerm)
            }
        }
        return matches.filter(isSafePublicLawTerm)
    }

    func looksLikeLegalConcept(_ value: String) -> Bool {
        let legalSignals = [
            "act",
            "article",
            "section",
            "order",
            "rule",
            "constitution",
            "writ",
            "maintenance",
            "injunction",
            "dishonour",
            "written statement",
            "delay",
            "limitation",
            "interim",
            "commercial",
            "cheque",
            "court",
            "filing",
        ]
        if legalSignals.contains(where: { value.contains($0) }) {
            return true
        }
        return value.range(of: #"article\s+\d+[a-z]*"#, options: .regularExpression) != nil ||
            value.range(of: #"section\s+\d+[a-z]*"#, options: .regularExpression) != nil ||
            value.range(of: #"order\s+[a-z0-9]+(?:\s+rules?\s+\d+[a-z]?(?:\s*(?:,|and|to|-)\s*\d+[a-z]?)*)?"#, options: .regularExpression) != nil
    }

    func isSafePublicLawTerm(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if lowered.contains("fakepriv") || lowered.contains("blue suitcase near temple") {
            return false
        }
        if value.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b\+?\d[\d\s-]{7,}\b"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#, options: .regularExpression) != nil {
            return false
        }
        if value.range(of: #"\b[A-Za-z]{1,8}[(/\- ]*\d+[A-Za-z/()\- ]*\d{4}\b"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    func sanitizePublicLawPreview(rawQuery: String, caseMatter: AlphaCaseMatter?) -> AlphaPublicLawPreview {
        let suggested = suggestedPublicLawQuery(for: caseMatter ?? selectedCase) ?? "Find current public law guidance on court procedure and filing compliance."
        var sanitized = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var removed: [String] = []
        let blockedTerms = [
            "case number",
            "case no",
            "case no.",
            "client",
            "party",
            "petitioner",
            "respondent",
            "chat history",
            "source chunk",
            "ocr",
            "filename",
            "address",
            "mobile",
            "this matter",
            "this case",
            "my matter",
            "my case",
            "our matter",
            "our case",
            "my client",
            "our client",
            "private matter",
            "confidential matter",
            "what should i",
            "do next",
            "next step",
            "next steps"
        ]
        let patterns: [(String, String)] = [
            (#"\b(my|our)\s+(client|case|matter)\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\b(this|private|confidential)\s+(case|matter)\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\bwhat\s+should\s+i\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\bdo\s+next\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\bnext\s+steps?\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\bfor\s+(this|my|our)\s+(client|case|matter)\b"#, alphaPublicLawPrivacyReason("matter_scoped_wording")),
            (#"\b[A-Za-z]{1,8}[(/\- ]*\d+[A-Za-z/()\- ]*\d{4}\b"#, alphaPublicLawPrivacyReason("case_numbers_or_filing_references")),
            (#"\b[A-Z]{2,}(?:\([A-Z]+\))?(?:[/ -]?\d+/\d{4})\b"#, alphaPublicLawPrivacyReason("case_numbers_or_filing_references")),
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+"#, alphaPublicLawPrivacyReason("email_addresses")),
            (#"\b\+?\d[\d\s-]{7,}\b"#, alphaPublicLawPrivacyReason("phone_numbers")),
            (#"\b\d{8,}\b"#, alphaPublicLawPrivacyReason("phone_numbers_or_long_numeric_strings")),
            (#"\b[^ ]+\.(pdf|docx|doc|txt|png|jpg|jpeg)\b"#, alphaPublicLawPrivacyReason("file_names")),
            (#"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#, alphaPublicLawPrivacyReason("exact_private_dates")),
            (#"\b\d{1,2}\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+\d{4}\b"#, alphaPublicLawPrivacyReason("exact_private_dates")),
            (#"raghav\s+fakepriv|blue suitcase near temple"#, alphaPublicLawPrivacyReason("fake_secrets_and_private_facts")),
            (#"\b(?:near|behind|opposite|at)\s+[A-Za-z][A-Za-z\s]{3,40}\b"#, alphaPublicLawPrivacyReason("addresses_or_location_details"))
        ]

        if let caseMatter {
            let sensitiveTokens = [caseMatter.title, caseMatter.forum] + caseMatter.documents.map(\.title) + caseMatter.documents.map(\.fileName)
            sensitiveTokens.filter { !$0.isEmpty }.forEach { token in
                if sanitized.localizedCaseInsensitiveContains(token) {
                    removed.append(alphaPublicLawPrivacyReason("case_titles_forum_names_or_document_labels"))
                    sanitized = sanitized.replacingOccurrences(of: token, with: " ", options: .caseInsensitive)
                }
            }
        }

        blockedTerms.forEach { token in
            if sanitized.localizedCaseInsensitiveContains(token) {
                removed.append(alphaPublicLawPrivacyReason("case_detail_phrasing_and_private_drafting_cues"))
                sanitized = sanitized.replacingOccurrences(of: token, with: " ", options: .caseInsensitive)
            }
        }

        for (pattern, label) in patterns {
            if sanitized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                removed.append(label)
                sanitized = sanitized.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
            }
        }

        sanitized = sanitized
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(for|about|regarding|with|on)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.count > 180 {
            removed.append(alphaPublicLawPrivacyReason("long_factual_narrative"))
            sanitized = String(sanitized.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let legalCandidate = sanitized
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if legalCandidate.isEmpty {
            sanitized = suggested
            removed.append(alphaPublicLawPrivacyReason("private_case_details"))
        } else if legalCandidate.range(of: #"\b(my|our)\s+(client|case|matter)\b|\b(this|private|confidential)\s+(case|matter)\b"#, options: .regularExpression) != nil {
            sanitized = suggested
            removed.append(alphaPublicLawPrivacyReason("matter_scoped_wording"))
        } else if !looksLikeLegalConcept(legalCandidate) {
            sanitized = suggested
            removed.append(alphaPublicLawPrivacyReason("general_drafting_phrasing"))
        }

        let dedupedRemoved = Array(NSOrderedSet(array: removed)) as? [String] ?? removed
        return AlphaPublicLawPreview(
            query: sanitized,
            removed: dedupedRemoved.isEmpty ? [alphaPublicLawNoPrivateDataReason()] : dedupedRemoved,
            confirmationNote: rossLocalized("public_law_search_confirmation_note")
        )
    }

    func alphaReviewTitle(for fieldType: AlphaExtractedLegalFieldType) -> String {
        switch fieldType {
        case .nextDate:
            rossLocalized("review_title_confirm_next_date")
        case .partyName:
            rossLocalized("review_title_review_party_name")
        case .orderDirection:
            rossLocalized("review_title_check_order_direction")
        default:
            rossLocalized("please_confirm")
        }
    }
}
