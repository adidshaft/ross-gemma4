import CryptoKit
import Observation
import SwiftUI
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

enum AlphaRoute: Hashable {
    case createCase
    case caseWorkspace(UUID)
    case documentList(UUID)
    case documentViewer(UUID, UUID, Int?)
    case askCase(UUID)
    case exports(UUID?)
    case privacyLedger
    case privateAISettings
}

@MainActor
@Observable
final class AlphaRossModel {
    private let store = AlphaRossStore()
    @ObservationIgnored private let backend = AlphaBackendClient()

    var persisted = AlphaPersistedState.seed()
    var path: [AlphaRoute] = []
    var selectedCaseID: UUID?
    var selectedTier: AlphaCapabilityTier = .caseAssociate
    var caseDraftTitle = ""
    var caseDraftForum = ""
    var askDrafts: [UUID: String] = [:]
    var publicLawDraft = "Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted."
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult] = []
    var loaded = false

    func loadIfNeeded() async {
        guard !loaded else { return }
        do {
            persisted = try await store.load()
            selectedCaseID = persisted.cases.first?.id
            selectedTier = persisted.settings.activeTier ?? .caseAssociate
            publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
            publicLawPreview = persisted.publicLawPreview
            publicLawResults = persisted.publicLawResults ?? []
            loaded = true
        } catch {
            loaded = true
        }
    }

    var cases: [AlphaCaseMatter] {
        persisted.cases.sorted { $0.updatedAt > $1.updatedAt }
    }

    var selectedCase: AlphaCaseMatter? {
        if let selectedCaseID {
            return persisted.cases.first { $0.id == selectedCaseID }
        }
        return persisted.cases.first
    }

    var activePack: AlphaInstalledModelPack? {
        persisted.installedPacks.first(where: \.isActive)
    }

    var activeRuntimeHealth: AlphaLocalRuntimeHealth? {
        AlphaLocalModelRuntime.runtimeHealth(
            activePack: activePack,
            requestedTier: activePack?.tier ?? persisted.settings.activeTier
        )
    }

    var lastModelInvocationRuntimeMode: String? {
        persisted.cases
            .flatMap(\.documents)
            .flatMap(\.modelInvocations)
            .last?
            .runtimeMode
    }

    func advanceOnboarding() {
        persisted.onboardingStage = .privateAIPack
        persist()
    }

    func skipPackSetup() {
        persisted.onboardingStage = .completed
        persisted.selectedTab = .cases
        persist()
    }

    func finishPackSetup() {
        persisted.settings.activeTier = selectedTier
        persisted.onboardingStage = .completed
        persisted.selectedTab = .cases
        persist()
        Task { await startPackDownload(for: selectedTier, mobileAllowed: selectedTier == .quickStart) }
    }

    func createCase() {
        let title = caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let forum = caseDraftForum.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let matter = AlphaCaseMatter(
            title: title,
            forum: forum.isEmpty ? "Forum pending" : forum,
            stage: .intake,
            summary: "New matter created locally. Import pleadings, orders, or captures to build a source-backed workspace.",
            issueHighlights: ["Import the first source document to begin chronology work."],
            evidenceNotes: ["No imported documents yet."],
            draftTasks: ["Import the first case document.", "Pin the first source reference."],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )

        persisted.cases.insert(matter, at: 0)
        selectedCaseID = matter.id
        caseDraftTitle = ""
        caseDraftForum = ""
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Case created locally",
                detail: "A new case matter was created on this device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://case-create",
                success: true
            ),
            at: 0
        )
        persist()
        path.removeAll()
        path.append(.caseWorkspace(matter.id))
    }

    func importDocument(caseId: UUID, from sourceURL: URL) async {
        do {
            let imported = try await store.importDocument(from: sourceURL, into: caseId)
            guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
            var document = imported.document
            document.indexingStatus = .extracting
            document.extractionRuns = [
                AlphaExtractionRun(
                    caseId: caseId,
                    documentId: document.id,
                    mode: .fromInstalledPack(activePack),
                    status: .running,
                    progressState: .acquiringText,
                    startedAt: .now,
                    pagesProcessed: 0,
                    totalPages: document.pageCount,
                    fieldsExtracted: 0,
                    fieldsNeedingReview: 0,
                    warnings: []
                )
            ]

            persisted.cases[caseIndex].documents.insert(document, at: 0)
            persisted.cases[caseIndex].updatedAt = .now

            let sourceRef = AlphaSourceRef(
                caseId: caseId,
                documentId: document.id,
                documentTitle: document.title,
                pageNumber: 1,
                paragraphRange: nil,
                textSnippet: document.dominantSourceSnippet ?? document.extractedText ?? "Imported source reference",
                ocrConfidence: document.kind == .image ? nil : 0.92
            )
            persisted.cases[caseIndex].sourceRefs.insert(sourceRef, at: 0)

            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document imported locally",
                    detail: "\(document.title) was copied into app-private storage.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: true
                ),
                at: 0
            )
            persist()
            path.append(.documentViewer(caseId, document.id, 1))

            let result = await store.runLocalExtraction(
                caseId: caseId,
                document: document,
                activePack: activePack
            )
            applyExtractionResult(result, caseId: caseId, documentId: document.id)
        } catch {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document import failed",
                    detail: "Ross could not copy the selected file into app-private storage.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: false
                ),
                at: 0
            )
            persist()
        }
    }

    func askCase(caseId: UUID) {
        guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }) else { return }
        let question = askDrafts[caseId, default: "Summarize the next hearing posture and strongest source-backed issue."]
        let caseMatter = persisted.cases[caseIndex]
        let sourceRefs = Array(caseMatter.sourceRefs.prefix(2))
        let answerSections = [
            caseMatter.issueHighlights.first ?? "Confirm the main issue from the indexed bundle.",
            "Keep the hearing note tied to the source chips already surfaced in this case.",
            caseMatter.draftTasks.first ?? "Prepare a short chronology note."
        ]
        let turn = AlphaChatTurn(
            question: question,
            answerTitle: "Local review completed",
            answerSections: answerSections,
            sourceRefs: sourceRefs
        )
        persisted.cases[caseIndex].chatTurns.insert(turn, at: 0)
        persisted.cases[caseIndex].updatedAt = .now
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Local case review run",
                detail: "The case question and source-backed draft stayed on-device.",
                purpose: .local_only,
                payloadClass: .local_only,
                endpointLabel: "device://ask-case",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func openSourceRef(_ ref: AlphaSourceRef) {
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
            return "Fields found: \(visibleFields.count) • Verified: \(verifiedCount) • Needs review: \(pendingCount)"
        default:
            return "Fields found: \(visibleFields.count) • Verified: \(verifiedCount) • Needs review: 0"
        }
    }

    func extractionUpgradeMessage(for document: AlphaCaseDocument) -> String? {
        let mode = activeExtractionMode
        if mode == .basic {
            return "Better extraction is available with Case Associate."
        }
        if mode == .quickStart,
           document.languageProfile?.primaryLanguage == .mixed || document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
        }
        if mode == .quickStart {
            return "Better extraction is available with Case Associate."
        }
        if mode == .caseAssociate,
           document.extractionFindings.contains(where: { $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain }) {
            return "This scan has mixed language or low OCR confidence. Senior Drafting Support may improve review."
        }
        return nil
    }

    func acceptExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = persisted.cases[caseIndex].documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        refreshCaseWorkspace(at: caseIndex)
        persist()
    }

    func ignoreExtractedField(caseId: UUID, documentId: UUID, fieldId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let field = persisted.cases[caseIndex].documents[documentIndex].extractedFields.first(where: { $0.id == fieldId })
        else { return }

        persisted.cases[caseIndex].advocateCorrections.insert(
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
        refreshCaseWorkspace(at: caseIndex)
        persist()
    }

    func applyFieldCorrection(caseId: UUID, documentId: UUID, fieldId: UUID, newValue: String) {
        let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId }),
            let fieldIndex = persisted.cases[caseIndex].documents[documentIndex].extractedFields.firstIndex(where: { $0.id == fieldId })
        else { return }

        let original = persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex]
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].value = cleaned
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].normalizedValue = cleaned.lowercased()
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].needsReview = false
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].userCorrected = true
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].extractionPass = .userCorrected
        persisted.cases[caseIndex].documents[documentIndex].extractedFields[fieldIndex].updatedAt = .now
        persisted.cases[caseIndex].advocateCorrections.insert(
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
        persisted.cases[caseIndex].caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseId,
                source: .userCorrection,
                summary: "\(original.label) updated to '\(cleaned)' during advocate review.",
                affectedDocuments: [documentId]
            ),
            at: 0
        )
        refreshCaseWorkspace(at: caseIndex)
        persist()
    }

    func updateDocumentClassification(caseId: UUID, documentId: UUID, type: AlphaLegalDocumentType) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId })
        else { return }

        if persisted.cases[caseIndex].documents[documentIndex].classification == nil {
            persisted.cases[caseIndex].documents[documentIndex].classification = AlphaLegalDocumentClassification(
                documentId: documentId,
                type: type,
                subtype: nil,
                confidence: 0.64,
                sourceRefs: [],
                needsReview: false
            )
        } else {
            persisted.cases[caseIndex].documents[documentIndex].classification?.type = type
            persisted.cases[caseIndex].documents[documentIndex].classification?.needsReview = false
            persisted.cases[caseIndex].documents[documentIndex].classification?.confidence = max(persisted.cases[caseIndex].documents[documentIndex].classification?.confidence ?? 0.64, 0.64)
        }

        persisted.cases[caseIndex].advocateCorrections.insert(
            AlphaAdvocateCorrection(
                caseId: caseId,
                documentId: documentId,
                oldValue: nil,
                newValue: type.rawValue,
                correctionType: .documentType
            ),
            at: 0
        )
        refreshCaseWorkspace(at: caseIndex)
        persist()
    }

    func buildPublicLawPreview() {
        let text = publicLawDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedQuery = suggestedPublicLawQuery() ?? "Find current public-law guidance relevant to delay condonation where diligence is documented."
        let lower = text.lowercased()
        let blockedPatterns = [
            "raghav fakepriv",
            "9876501234",
            "fakepriv@example.com",
            "fake/123/2026",
            "blue suitcase near temple",
            "@",
            "case number",
            "client",
            "party",
            "ocr"
        ]

        var removed: [String] = []
        var sanitized = text
            .replacingOccurrences(of: "\\b\\d{2,}\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let selectedCase {
            if lower.contains(selectedCase.title.lowercased()) || lower.contains(selectedCase.forum.lowercased()) {
                removed.append("Case title and forum references")
                sanitized = sanitized
                    .replacingOccurrences(of: selectedCase.title, with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: selectedCase.forum, with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if blockedPatterns.contains(where: { lower.contains($0) }) {
            removed.append("Private details and obvious identifiers")
            sanitized = suggestedQuery
        }

        if sanitized.count > 180 {
            removed.append("Long factual narrative")
            sanitized = String(sanitized.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        publicLawPreview = AlphaPublicLawPreview(
            query: sanitized.isEmpty ? suggestedQuery : sanitized,
            removed: removed.isEmpty ? ["No private case data detected"] : removed,
            confirmationNote: "Public-law search sends only a sanitized query after explicit confirmation."
        )
        publicLawResults = []
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = publicLawPreview
        persisted.publicLawResults = publicLawResults
        persist()
    }

    func runPublicLawSearch() async {
        guard let preview = publicLawPreview else { return }
        do {
            publicLawResults = try await backend.searchPublicLaw(preview: preview)
        } catch {
            publicLawResults = []
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Public-law search unavailable",
                    detail: "Ross could not reach the sanitized public-law backend with the approved preview.",
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
                title: "Public-law query sent",
                detail: "Only a sanitized public query crossed the network boundary.",
                purpose: .public_law_search,
                payloadClass: .sanitized_public_query,
                endpointLabel: "/public-law/search",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func generateExport(kind: String, caseId: UUID?) async {
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
        }
    }

    func exportURL(for report: AlphaExportedReport) -> URL {
        alphaAbsoluteURL(for: report.relativePath)
    }

    var activeExtractionMode: AlphaExtractionMode {
        .fromInstalledPack(activePack)
    }

    func pauseJob(_ job: AlphaModelDownloadJob) {
        updateJob(job.id) {
            $0.state = .pausedUser
            $0.updatedAt = .now
        }
    }

    func resumeJob(_ job: AlphaModelDownloadJob) {
        Task { await startPackDownload(for: job.tier, mobileAllowed: job.networkPolicy == .mobileAllowed) }
    }

    func removeInstalledPack(_ pack: AlphaInstalledModelPack) {
        persisted.installedPacks.removeAll { $0.id == pack.id }
        if persisted.settings.activeTier == pack.tier {
            persisted.settings.activeTier = persisted.installedPacks.first(where: \.isActive)?.tier
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Private AI Pack removed",
                detail: "\(pack.tier.title) was removed from local storage.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-remove",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func activateInstalledPack(_ pack: AlphaInstalledModelPack) {
        persisted.installedPacks = persisted.installedPacks.map {
            var copy = $0
            copy.isActive = copy.id == pack.id
            return copy
        }
        persisted.settings.activeTier = pack.tier
        persist()
    }

    func startPackDownload(for tier: AlphaCapabilityTier, mobileAllowed: Bool) async {
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let waitingForWifi = !mobileAllowed && tier != .quickStart
        let sessionId = "mdl-\(UUID().uuidString.prefix(8))"

        let job = AlphaModelDownloadJob(
            sessionId: sessionId,
            packId: "\(tier.rawValue)-pack",
            tier: tier,
            state: waitingForWifi ? .pausedWaitingForWifi : .queued,
            networkPolicy: policy,
            bytesDownloaded: 0,
            totalBytes: 0,
            checksumSha256: ""
        )

        upsertJob(job)
        persist()

        do {
            let catalog = try await backend.fetchCatalog(for: tier)
            guard let pack = catalog.packs.first(where: { $0.tier == tier }) else {
                throw AlphaBackendError.missingPack
            }

            persisted.lastModelCatalogRefresh = .now
            updateJob(job.id) {
                $0.packId = pack.packId
                $0.totalBytes = pack.sizeBytes
                $0.checksumSha256 = pack.checksumSha256
                $0.artifactKind = pack.artifactKind
                $0.runtimeMode = pack.runtimeMode
                $0.developmentOnly = pack.developmentOnly
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Model catalog checked",
                    detail: "Private AI Pack metadata was reviewed without case data.",
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "/model-catalog",
                    success: true
                ),
                at: 0
            )
            persist()

            if waitingForWifi {
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Private AI Pack waiting for Wi-Fi",
                        detail: "Model delivery is paused until you allow a trusted network.",
                        purpose: .model_download,
                        payloadClass: .no_case_data,
                        endpointLabel: "/model-download/session",
                        success: true
                    ),
                    at: 0
                )
                persist()
                return
            }

            let session = try await backend.createDownloadSession(for: pack.packId)
            updateJob(job.id) {
                $0.sessionId = session.sessionId
                $0.packId = session.packId
                $0.totalBytes = session.artifact.sizeBytes
                $0.checksumSha256 = session.artifact.finalSha256
                $0.artifactKind = session.artifact.artifactKind
                $0.runtimeMode = session.artifact.runtimeMode
                $0.developmentOnly = session.artifact.developmentOnly
                $0.state = .downloading
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Private AI Pack queued",
                    detail: "Model delivery started without reading case files.",
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "/model-download/session",
                    success: true
                ),
                at: 0
            )
            persist()

            let downloaded = try await backend.downloadArtifact(session: session) { bytesDownloaded in
                await MainActor.run {
                    self.updateJob(job.id) {
                        $0.state = .downloading
                        $0.bytesDownloaded = bytesDownloaded
                        $0.updatedAt = .now
                    }
                    self.persist()
                }
            }

            updateJob(job.id) {
                $0.state = .verifying
                $0.bytesDownloaded = downloaded.bytes
                $0.updatedAt = .now
            }
            persist()

            let artifact = try await store.installDownloadedPackArtifact(
                for: tier,
                fileName: session.artifact.fileName,
                data: downloaded.data,
                expectedChecksum: session.artifact.finalSha256
            )
            let installed = AlphaInstalledModelPack(
                packId: pack.packId,
                tier: tier,
                installPath: artifact.relativePath,
                checksumSha256: artifact.checksum,
                artifactKind: session.artifact.artifactKind,
                runtimeMode: session.artifact.runtimeMode,
                developmentOnly: session.artifact.developmentOnly,
                isActive: true
            )
            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
            persisted.installedPacks.removeAll { $0.tier == tier }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = artifact.bytes
                $0.totalBytes = artifact.bytes
                $0.checksumSha256 = artifact.checksum
                $0.artifactKind = installed.artifactKind
                $0.runtimeMode = installed.runtimeMode
                $0.developmentOnly = installed.developmentOnly
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Private AI Pack verified",
                    detail: "Checksum and install metadata were verified locally.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
            persist()
        } catch {
            do {
                let fallback = try await store.writeDevPackArtifact(for: tier)
                let installed = AlphaInstalledModelPack(
                    packId: "\(tier.rawValue)-pack",
                    tier: tier,
                    installPath: fallback.relativePath,
                    checksumSha256: fallback.checksum,
                    artifactKind: "tiny_dev_artifact",
                    runtimeMode: .deterministicDev,
                    developmentOnly: true,
                    isActive: true
                )
                persisted.installedPacks = persisted.installedPacks.map {
                    var copy = $0
                    copy.isActive = false
                    return copy
                }
                persisted.installedPacks.removeAll { $0.tier == tier }
                persisted.installedPacks.insert(installed, at: 0)
                persisted.settings.activeTier = tier
                updateJob(job.id) {
                    $0.state = .installed
                    $0.packId = installed.packId
                    $0.bytesDownloaded = fallback.bytes
                    $0.totalBytes = fallback.bytes
                    $0.checksumSha256 = fallback.checksum
                    $0.artifactKind = installed.artifactKind
                    $0.runtimeMode = installed.runtimeMode
                    $0.developmentOnly = installed.developmentOnly
                    $0.updatedAt = .now
                    $0.completedAt = .now
                }
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Private AI Pack fallback installed",
                        detail: "The backend was unavailable, so Ross prepared a local development artifact without case data.",
                        purpose: .model_verification,
                        payloadClass: .no_case_data,
                        endpointLabel: "device://model-verify",
                        success: true
                    ),
                    at: 0
                )
                persist()
            } catch {
                updateJob(job.id) {
                    $0.state = .failed
                    $0.failureReason = "Install artifact could not be prepared."
                    $0.updatedAt = .now
                }
                persist()
            }
        }
    }

    private func exportBodyLines(kind: String, caseMatter: AlphaCaseMatter?) -> [String] {
        let title = caseMatter?.title ?? "Ross"
        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        guard let caseMatter else {
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "No case selected.",
                "",
                "Generated locally for advocate review. Verify all citations."
            ]
        }

        let documents = caseMatter.documents
        let allFields = documents.flatMap(\.extractedFields)
        let verifiedFields = allFields.filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = allFields.filter(\.needsReview)
        let unresolvedFindings = documents.flatMap(\.extractionFindings).filter { !$0.resolved }
        let refs = caseMatter.sourceRefs.prefix(8).map { "- \($0.label): \($0.detail)" }
        let documentLines = documents.map { "- \($0.title) (\($0.pageCount) pages, \($0.ocrStatus.title))" }

        func uniqueValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            Array(Set(fields.filter { $0.fieldType == type }.map(\.value))).sorted()
        }

        func sourcedValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            fields
                .filter { $0.fieldType == type }
                .map { field in
                    let sourceLabel = field.sourceRefs.first?.label ?? "Source pending"
                    return "- \(field.value) (\(sourceLabel))"
                }
        }

        switch kind {
        case "chronology_report":
            let chronologyLines = verifiedFields
                .filter { $0.fieldType == .date || $0.fieldType == .nextDate }
                .sorted { ($0.normalizedValue ?? $0.value) < ($1.normalizedValue ?? $1.value) }
                .map { "- \($0.label): \($0.value) (\($0.sourceRefs.first?.label ?? "Source pending"))" }
            let warningLines = unresolvedFindings.map { "- \($0.message)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Chronology candidates",
            ] + (chronologyLines.isEmpty ? ["- No verified chronology candidates found yet."] : chronologyLines) + [
                "",
                "Review warnings",
            ] + (warningLines.isEmpty ? ["- No unresolved warnings."] : warningLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "case_note":
            let court = uniqueValues(for: .court, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let caseNumbers = uniqueValues(for: .caseNumber, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let parties = uniqueValues(for: .partyName, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let dateLines = sourcedValues(for: .date, in: verifiedFields)
            let pendingLines = pendingFields.map { "- \($0.label): \($0.value)" }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Court / case metadata",
                "Court: \(court)",
                "Case number: \(caseNumbers)",
                "Parties: \(parties)",
                "",
                "Document list",
            ] + (documentLines.isEmpty ? ["- No imported documents yet."] : documentLines) + [
                "",
                "Key dates",
            ] + (dateLines.isEmpty ? ["- No verified key dates found yet."] : dateLines) + [
                "",
                "Pending review fields",
            ] + (pendingLines.isEmpty ? ["- No pending review fields."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "order_summary":
            let directions = sourcedValues(for: .orderDirection, in: verifiedFields)
            let nextDates = sourcedValues(for: .nextDate, in: verifiedFields)
            let compliance = unresolvedFindings
                .filter { $0.kind == .ambiguousOrderDirection || $0.kind == .dateConflict }
                .map { "- \($0.message)" }
            let pendingLines = pendingFields
                .filter { $0.fieldType == .orderDirection || $0.fieldType == .nextDate || $0.fieldType == .date }
                .map { "- \($0.label): \($0.value)" }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Operative directions",
            ] + (directions.isEmpty ? ["- No verified operative directions found yet."] : directions) + [
                "",
                "Next date",
            ] + (nextDates.isEmpty ? ["- Not found"] : nextDates) + [
                "",
                "Compliance requirements",
            ] + (compliance.isEmpty ? ["- Review operative directions against cited source pages."] : compliance) + [
                "",
                "Needs review",
            ] + (pendingLines.isEmpty ? ["- No pending review flags for order details."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        default:
            let notes = caseMatter.draftTasks.map { "- \($0)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft for advocate review",
                "",
                "Summary",
                caseMatter.summary,
                "",
                "Working notes",
            ] + (notes.isEmpty ? ["- No tasks yet."] : notes) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]
        }
    }

    private func applyExtractionResult(_ result: AlphaLocalExtractionResult, caseId: UUID, documentId: UUID) {
        guard
            let caseIndex = persisted.cases.firstIndex(where: { $0.id == caseId }),
            let documentIndex = persisted.cases[caseIndex].documents.firstIndex(where: { $0.id == documentId })
        else { return }

        var caseMatter = persisted.cases[caseIndex]
        var document = caseMatter.documents[documentIndex]
        document.pages = result.pages
        document.languageProfile = result.languageProfile
        document.classification = result.classification
        document.extractedFields = mergeUserCorrectedFields(previousFields: document.extractedFields, newFields: result.extractedFields)
        document.extractionRuns.insert(result.extractionRun, at: 0)
        document.extractionFindings = result.findings
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
        refreshCaseWorkspace(caseMatter: &caseMatter)

        persisted.cases[caseIndex] = caseMatter
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
        persist()
    }

    private func appendSourceRefs(_ refs: [AlphaSourceRef], to caseMatter: inout AlphaCaseMatter) {
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

    private func mergeCaseMemoryUpdates(_ updates: [AlphaCaseMemoryUpdate], into caseMatter: inout AlphaCaseMatter) {
        for update in updates.reversed() {
            let exists = caseMatter.caseMemoryUpdates.contains {
                $0.summary == update.summary && $0.affectedDocuments == update.affectedDocuments
            }
            if !exists {
                caseMatter.caseMemoryUpdates.insert(update, at: 0)
            }
        }
    }

    private func mergeUserCorrectedFields(
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

    private func refreshCaseWorkspace(at caseIndex: Int) {
        var caseMatter = persisted.cases[caseIndex]
        refreshCaseWorkspace(caseMatter: &caseMatter)
        persisted.cases[caseIndex] = caseMatter
    }

    private func refreshCaseWorkspace(caseMatter: inout AlphaCaseMatter) {
        let verifiedFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter(\.needsReview)

        if let forum = verifiedFields.first(where: { $0.fieldType == .court })?.value,
           caseMatter.forum == "Forum pending" || caseMatter.forum.isEmpty {
            caseMatter.forum = forum
        }

        if let nextDate = verifiedFields.first(where: { $0.fieldType == .nextDate })?.value {
            caseMatter.localNotice = "Case files stay on this device. Next date found: \(nextDate)"
        }

        let classifications = caseMatter.documents.compactMap { $0.classification?.type.rawValue.replacingOccurrences(of: "_", with: " ") }
        let classificationText = classifications.isEmpty ? "local legal document review" : classifications.joined(separator: ", ")
        caseMatter.summary = "Ross indexed \(caseMatter.documents.count) document(s) locally for \(classificationText)."

        let issueCandidates = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .prayer }
            .map(\.value)
        caseMatter.issueHighlights = issueCandidates.isEmpty ? ["Review extracted legal issues and directions."] : Array(issueCandidates.prefix(4))

        let evidenceCandidates = caseMatter.documents
            .flatMap(\.extractionFindings)
            .filter { !$0.resolved }
            .map(\.message)
        caseMatter.evidenceNotes = evidenceCandidates.isEmpty ? ["Source-backed extraction is available for this matter."] : Array(evidenceCandidates.prefix(4))

        caseMatter.draftTasks = [
            pendingFields.isEmpty ? "Review the latest chronology and order summary." : "Review uncertain extracted fields before relying on them.",
            "Open source chips before sharing or filing.",
            "Generate a local chronology or order summary draft."
        ]
        caseMatter.updatedAt = .now
    }

    private func ignoredFieldIDs(caseId: UUID, documentId: UUID) -> Set<UUID> {
        guard let caseMatter = persisted.cases.first(where: { $0.id == caseId }) else { return [] }
        return Set(
            caseMatter.advocateCorrections
                .filter { $0.documentId == documentId && $0.correctionType == .ignoreField }
                .compactMap(\.fieldId)
        )
    }

    private func suggestedPublicLawQuery() -> String? {
        guard let selectedCase else { return nil }
        let verifiedFields = selectedCase.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let issues = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .section }
            .flatMap { publicLawKeywords(from: $0.value) }
        let classifications = selectedCase.documents.compactMap { document in
            document.classification
                .flatMap { $0.needsReview ? nil : $0.type.rawValue.replacingOccurrences(of: "_", with: " ") }
        }
        let terms = Array(NSOrderedSet(array: issues + classifications))
            .compactMap { $0 as? String }
            .filter(isSafePublicLawTerm)
        guard !terms.isEmpty else { return nil }
        return (terms + ["India"]).joined(separator: " ")
    }

    private func publicLawKeywords(from value: String) -> [String] {
        let lowered = value.lowercased()
        let patterns = [
            "commercial courts act",
            "negotiable instruments act",
            "arbitration act",
            "limitation act",
            "written statement",
            "delay condonation",
            "interim maintenance",
            "interim relief",
            "injunction",
            "stay",
            "cheque dishonour",
            "section \\d+[a-z]*",
            "order [a-z0-9]+ rule \\d+"
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

    private func looksLikeLegalConcept(_ value: String) -> Bool {
        let legalSignals = [
            "act",
            "section",
            "order",
            "rule",
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
        return value.range(of: #"section\s+\d+[a-z]*"#, options: .regularExpression) != nil ||
            value.range(of: #"order\s+[a-z0-9]+\s+rule\s+\d+"#, options: .regularExpression) != nil
    }

    private func isSafePublicLawTerm(_ value: String) -> Bool {
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

    private func alphaCorrectionType(for fieldType: AlphaExtractedLegalFieldType) -> AlphaAdvocateCorrectionType {
        switch fieldType {
        case .date, .nextDate, .limitationDate:
            return .date
        case .partyName:
            return .party
        default:
            return .fieldValue
        }
    }

    private func persist() {
        var snapshot = persisted
        snapshot.publicLawDraft = publicLawDraft
        snapshot.publicLawPreview = publicLawPreview
        snapshot.publicLawResults = publicLawResults
        Task {
            try? await store.replace(with: snapshot)
        }
    }

    private func upsertJob(_ job: AlphaModelDownloadJob) {
        if let index = persisted.modelJobs.firstIndex(where: { $0.id == job.id }) {
            persisted.modelJobs[index] = job
        } else {
            persisted.modelJobs.insert(job, at: 0)
        }
    }

    private func updateJob(_ jobID: UUID, transform: (inout AlphaModelDownloadJob) -> Void) {
        guard let index = persisted.modelJobs.firstIndex(where: { $0.id == jobID }) else { return }
        transform(&persisted.modelJobs[index])
    }
}

private actor AlphaBackendClient {
    private let configuration = AlphaBackendConfiguration()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func fetchCatalog(for tier: AlphaCapabilityTier) async throws -> AlphaBackendCatalogManifest {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent("model-catalog"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "tier", value: tier.rawValue)
        ]
        guard let url = components?.url else {
            throw AlphaBackendError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeout

        let response: AlphaBackendCatalogResponse = try await send(request, expecting: AlphaBackendCatalogResponse.self)
        return response.manifest.payload
    }

    func createDownloadSession(for packId: String) async throws -> AlphaBackendDownloadSessionPayload {
        let requestBody = AlphaBackendDownloadSessionRequest(
            accountToken: configuration.accountToken,
            packId: packId,
            platform: "ios",
            deviceIdHash: configuration.deviceIdHash,
            appVersion: configuration.appVersion
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("model-download/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let response: AlphaBackendDownloadSessionResponse = try await send(request, expecting: AlphaBackendDownloadSessionResponse.self)
        return response.downloadSession.payload
    }

    func searchPublicLaw(preview: AlphaPublicLawPreview) async throws -> [AlphaPublicLawResult] {
        let requestBody = AlphaBackendPublicLawSearchRequest(
            query: preview.query,
            jurisdiction: "IN-ALL",
            language: "en",
            confirmedPublicPreview: true
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("public-law/search"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let response: AlphaBackendPublicLawResponse = try await send(request, expecting: AlphaBackendPublicLawResponse.self)
        return response.results.map {
            AlphaPublicLawResult(
                title: $0.title,
                citation: $0.citation,
                snippet: $0.snippet,
                sourceName: $0.source
            )
        }
    }

    func downloadArtifact(
        session: AlphaBackendDownloadSessionPayload,
        onProgress: @escaping @Sendable (Int64) async -> Void
    ) async throws -> AlphaDownloadedArtifact {
        let artifactURL = try resolveArtifactURL(for: session.artifact)
        var downloaded = Data()
        downloaded.reserveCapacity(Int(session.artifact.sizeBytes))

        for segment in session.artifact.segments {
            var request = URLRequest(url: artifactURL)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.requestTimeout
            request.setValue(segment.rangeHeader, forHTTPHeaderField: "Range")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw AlphaBackendError.unavailable
            }
            guard sha256Hex(data) == segment.sha256.lowercased() else {
                throw AlphaBackendError.segmentIntegrityFailed
            }

            downloaded.append(data)
            await onProgress(Int64(downloaded.count))
        }

        guard Int64(downloaded.count) == session.artifact.sizeBytes else {
            throw AlphaBackendError.invalidResponse
        }
        guard sha256Hex(downloaded) == session.artifact.finalSha256.lowercased() else {
            throw AlphaBackendError.finalIntegrityFailed
        }

        return AlphaDownloadedArtifact(data: downloaded, bytes: Int64(downloaded.count))
    }

    private func resolveArtifactURL(for artifact: AlphaBackendArtifact) throws -> URL {
        if let downloadPath = artifact.downloadPath {
            return configuration.baseURL.appendingPathComponent(downloadPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        guard let url = URL(string: artifact.downloadUrl) else {
            throw AlphaBackendError.invalidResponse
        }

        if url.host == "downloads.example.invalid" {
            return configuration.baseURL.appendingPathComponent(url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        return url
    }

    private func send<Response: Decodable>(_ request: URLRequest, expecting type: Response.Type) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaBackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AlphaBackendError.unavailable
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AlphaBackendError.invalidResponse
        }
    }
}

private struct AlphaBackendConfiguration {
    let baseURL: URL
    let requestTimeout: TimeInterval = 2
    let accountToken = "acct_local_alpha_device"
    let appVersion = "0.1.0-alpha"
    let deviceIdHash = sha256Hex(Data("ross-ios-alpha-device".utf8))

    init() {
        let environment = ProcessInfo.processInfo.environment
        let rawURL = environment["ROSS_BACKEND_BASE_URL"] ?? environment["ROSS_BACKEND_URL"] ?? "http://127.0.0.1:8080"
        baseURL = URL(string: rawURL) ?? URL(string: "http://127.0.0.1:8080")!
    }
}

private struct AlphaBackendSignedEnvelope<Payload: Codable>: Codable {
    let payload: Payload
}

private struct AlphaBackendCatalogResponse: Codable {
    let manifest: AlphaBackendSignedEnvelope<AlphaBackendCatalogManifest>
}

private struct AlphaBackendCatalogManifest: Codable {
    let packs: [AlphaBackendCatalogPack]
}

private struct AlphaBackendCatalogPack: Codable {
    let packId: String
    let displayName: String
    let tier: AlphaCapabilityTier
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
}

private struct AlphaBackendDownloadSessionRequest: Codable {
    let accountToken: String
    let packId: String
    let platform: String
    let deviceIdHash: String
    let appVersion: String
}

private struct AlphaBackendDownloadSessionResponse: Codable {
    let downloadSession: AlphaBackendSignedEnvelope<AlphaBackendDownloadSessionPayload>
}

private struct AlphaBackendDownloadSessionPayload: Codable {
    let sessionId: String
    let packId: String
    let artifact: AlphaBackendArtifact
}

private struct AlphaBackendArtifact: Codable {
    let fileName: String
    let sizeBytes: Int64
    let finalSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let downloadPath: String?
    let downloadUrl: String
    let segments: [AlphaBackendArtifactSegment]
}

private struct AlphaBackendArtifactSegment: Codable {
    let index: Int
    let startByte: Int64
    let endByteInclusive: Int64
    let sizeBytes: Int64
    let sha256: String
    let rangeHeader: String
}

private struct AlphaBackendPublicLawSearchRequest: Codable {
    let query: String
    let jurisdiction: String
    let language: String
    let confirmedPublicPreview: Bool
}

private struct AlphaBackendPublicLawResponse: Codable {
    let results: [AlphaBackendPublicLawResult]
}

private struct AlphaBackendPublicLawResult: Codable {
    let source: String
    let title: String
    let citation: String
    let snippet: String
}

private struct AlphaDownloadedArtifact {
    let data: Data
    let bytes: Int64
}

private enum AlphaBackendError: Error {
    case unavailable
    case invalidResponse
    case missingPack
    case segmentIntegrityFailed
    case finalIntegrityFailed
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

struct AlphaRossRootView: View {
    @State private var model = AlphaRossModel()

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                switch model.persisted.onboardingStage {
                case .onboarding:
                    AlphaOnboardingScreen(model: model)
                case .privateAIPack:
                    AlphaPackSetupScreen(model: model)
                case .completed:
                    AlphaTabShell(model: model)
                }
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationDestination(for: AlphaRoute.self) { route in
                switch route {
                case .createCase:
                    AlphaCreateCaseScreen(model: model)
                case .caseWorkspace(let caseId):
                    AlphaCaseWorkspaceScreen(model: model, caseId: caseId)
                case .documentList(let caseId):
                    AlphaDocumentListScreen(model: model, caseId: caseId)
                case .documentViewer(let caseId, let documentId, let page):
                    AlphaDocumentViewerScreen(model: model, caseId: caseId, documentId: documentId, initialPage: page)
                case .askCase(let caseId):
                    AlphaAskCaseScreen(model: model, caseId: caseId)
                case .exports(let caseId):
                    AlphaExportsScreen(model: model, caseId: caseId)
                case .privacyLedger:
                    AlphaPrivacyLedgerScreen(model: model)
                case .privateAISettings:
                    AlphaPrivateAISettingsScreen(model: model)
                }
            }
        }
        .task {
            await model.loadIfNeeded()
        }
    }
}

private struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RossHeroCard(
                    eyebrow: "Ross",
                    title: "Your case files stay on this device",
                    detail: "Ross is a private legal workbench. It keeps case work local, shows a visible privacy ledger, and treats every output as a draft for advocate review."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        RossInfoPill(title: "Case files stay on this device", systemImage: "lock")
                        RossInfoPill(title: "Source-backed", systemImage: "paperclip")
                        RossInfoPill(title: "Public-law search sends only a sanitized query", systemImage: "shield")
                    }
                }

                RossSectionCard(title: "What happens next", subtitle: "Keep setup calm and outcome-focused.") {
                    VStack(alignment: .leading, spacing: 16) {
                        RossBulletRow(text: "Pick a Private AI Pack that matches this device.")
                        RossBulletRow(text: "Continue setting up cases while the pack download prepares in the background.")
                        RossBulletRow(text: "Reach the Privacy Ledger at any time from settings.")
                    }
                }

                Button("Continue") {
                    model.advanceOnboarding()
                }
                .rossPrimaryButtonStyle()
            }
            .padding(24)
        }
    }
}

private struct AlphaPackSetupScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RossHeroCard(
                    eyebrow: "Private AI Pack",
                    title: "This is the private AI brain of Ross.",
                    detail: "It stays on your phone. You can continue setting up cases while this downloads, and larger case analysis will be available after the Private AI Pack is ready."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        RossInfoPill(title: "Wi-Fi recommended", systemImage: "wifi")
                        RossInfoPill(title: "Mobile data is optional but explicit", systemImage: "antenna.radiowaves.left.and.right")
                        RossInfoPill(title: "Download can resume", systemImage: "arrow.clockwise")
                    }
                }

                ForEach(AlphaPackOffer.catalog) { offer in
                    Button {
                        model.selectedTier = offer.tier
                    } label: {
                        RossSectionCard(
                            title: offer.tier.title,
                            subtitle: offer.tier.summary
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    RossInfoPill(title: offer.tier.downloadSizeLabel, systemImage: "arrow.down.circle")
                                    RossInfoPill(title: offer.tier.installedSizeLabel, systemImage: "shippingbox")
                                    RossInfoPill(title: offer.tier.storageNote, systemImage: "internaldrive")
                                }
                                Text("Best for: \(offer.tier.bestFor)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.7))
                                if model.selectedTier == offer.tier {
                                    Text("Selected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.rossAccent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button("Continue to Case List") {
                    model.finishPackSetup()
                }
                .rossPrimaryButtonStyle()

                Button("Skip for now") {
                    model.skipPackSetup()
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
        }
    }
}

private struct AlphaTabShell: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        TabView(selection: $model.persisted.selectedTab) {
            AlphaCaseListScreen(model: model)
                .tabItem { Label("Cases", systemImage: "folder") }
                .tag(AlphaAppTab.cases)

            AlphaPublicLawScreen(model: model)
                .tabItem { Label("Public Law", systemImage: "magnifyingglass") }
                .tag(AlphaAppTab.publicLaw)

            AlphaExportsScreen(model: model, caseId: model.selectedCaseID)
                .tabItem { Label("Exports", systemImage: "square.and.arrow.up") }
                .tag(AlphaAppTab.exports)

            AlphaSettingsScreen(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AlphaAppTab.settings)
        }
        .tint(Color.rossAccent)
    }
}

private struct AlphaCaseListScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossHeroCard(
                    eyebrow: "Case List",
                    title: "Private case matters",
                    detail: "Create a case, import source documents, and move straight into a case workspace without leaving the device."
                ) {
                    HStack(spacing: 12) {
                        RossInfoPill(title: "\(model.persisted.cases.count) matters", systemImage: "briefcase")
                        RossInfoPill(title: "\(model.persisted.exports.count) reports", systemImage: "doc")
                        RossInfoPill(title: "Privacy ledger visible", systemImage: "checklist")
                    }
                }

                Button("Create Case") {
                    model.path.append(.createCase)
                }
                .rossPrimaryButtonStyle()

                ForEach(model.cases) { caseMatter in
                    Button {
                        model.selectedCaseID = caseMatter.id
                        model.path.append(.caseWorkspace(caseMatter.id))
                    } label: {
                        RossSectionCard(
                            title: caseMatter.title,
                            subtitle: "\(caseMatter.forum) • \(caseMatter.stage.title)"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(caseMatter.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.75))
                                HStack(spacing: 12) {
                                    RossInfoPill(title: "\(caseMatter.documents.count) docs", systemImage: "doc.text")
                                    RossInfoPill(title: "\(caseMatter.sourceRefs.count) source refs", systemImage: "paperclip")
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .navigationTitle("Case List")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaCreateCaseScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        Form {
            Section("Create Case") {
                TextField("Case title", text: $model.caseDraftTitle)
                TextField("Forum", text: $model.caseDraftForum)
            }

            Section {
                Button("Create") {
                    model.createCase()
                }
                .disabled(model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Create Case")
    }
}

private struct AlphaCaseWorkspaceScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            if let caseMatter {
                VStack(alignment: .leading, spacing: 20) {
                    RossHeroCard(
                        eyebrow: caseMatter.forum,
                        title: caseMatter.title,
                        detail: caseMatter.summary
                    ) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: caseMatter.stage.title, systemImage: "briefcase")
                            RossInfoPill(title: caseMatter.localNotice, systemImage: "lock")
                        }
                    }

                    RossSectionCard(title: "Workspace actions", subtitle: "Move between documents, source-backed review, and exports.") {
                        VStack(spacing: 12) {
                            RossActionTile(title: "Documents", detail: "Import or open case documents.", systemImage: "doc.text", tint: .rossAccent) {
                                model.path.append(.documentList(caseId))
                            }
                            RossActionTile(title: "Ask Case", detail: "Run a local, source-backed review.", systemImage: "text.bubble", tint: .rossHighlight) {
                                model.path.append(.askCase(caseId))
                            }
                            RossActionTile(title: "Drafts / Exports", detail: "Generate chronology, case note, or chat transcript reports.", systemImage: "square.and.arrow.up", tint: .rossSuccess) {
                                model.path.append(.exports(caseId))
                            }
                        }
                    }

                    RossSectionCard(title: "Issue highlights", subtitle: "Keep the next hearing posture visible.") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(caseMatter.issueHighlights, id: \.self) { item in
                                RossBulletRow(text: item)
                            }
                        }
                    }

                    RossSectionCard(title: "Source chips", subtitle: "Tap to jump into the referenced document page.") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(caseMatter.sourceRefs.prefix(5)) { source in
                                Button {
                                    model.openSourceRef(source)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(source.label)
                                                .font(.headline)
                                                .foregroundStyle(Color.rossInk)
                                            Text(source.detail)
                                                .font(.footnote)
                                                .foregroundStyle(Color.rossInk.opacity(0.65))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Color.rossInk.opacity(0.3))
                                    }
                                    .padding(16)
                                    .background(Color.rossCardBackground)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.rossBorder, lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Case Workspace")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaDocumentListScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    @State private var showingImporter = false

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Document List", subtitle: "PDF and image imports are copied into app-private storage.") {
                    Button("Import Document") {
                        showingImporter = true
                    }
                    .rossPrimaryButtonStyle()
                }

                ForEach(caseMatter?.documents ?? []) { document in
                    Button {
                        model.path.append(.documentViewer(caseId, document.id, 1))
                    } label: {
                        RossSectionCard(title: document.title, subtitle: "\(document.kind.title) • \(document.pageCount) page(s)") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(document.ocrStatus.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.rossAccent)
                                Text(document.extractedText ?? "Extracted text will appear here when available.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                                    .lineLimit(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task { await model.importDocument(caseId: caseId, from: url) }
            }
        }
        .navigationTitle("Documents")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaDocumentViewerScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID
    let documentId: UUID
    let initialPage: Int?

    private var document: AlphaCaseDocument? {
        model.persisted.cases
            .first(where: { $0.id == caseId })?
            .documents.first(where: { $0.id == documentId })
    }

    private var sourceRefs: [AlphaSourceRef] {
        model.persisted.cases
            .first(where: { $0.id == caseId })?
            .sourceRefs.filter { $0.documentId == documentId } ?? []
    }

    private var resolvedPage: Int {
        let upperBound = max(document?.pageCount ?? 1, 1)
        return min(max(initialPage ?? sourceRefs.first?.pageNumber ?? 1, 1), upperBound)
    }

    private var currentPageRefs: [AlphaSourceRef] {
        sourceRefs.filter { $0.pageNumber == resolvedPage }
    }

    private var reviewSummaryText: String? {
        model.reviewSummary(caseId: caseId, documentId: documentId)
    }

    private var reviewFields: [AlphaExtractedLegalField] {
        model.visibleExtractedFields(caseId: caseId, documentId: documentId)
    }

    private var reviewFindings: [AlphaExtractionFinding] {
        model.reviewFindings(caseId: caseId, documentId: documentId)
    }

    private var needsReviewCount: Int {
        reviewFields.filter(\.needsReview).count + reviewFindings.count
    }

    var body: some View {
        ScrollView {
            if let document {
                VStack(alignment: .leading, spacing: 20) {
                    RossHeroCard(
                        eyebrow: document.kind.title,
                        title: document.title,
                        detail: "Page count: \(document.pageCount) • OCR/indexing: \(document.ocrStatus.title) • Extraction: \((document.extractionRuns.first?.mode.qualityLabel ?? model.activeExtractionMode.qualityLabel)) • Needs review: \(needsReviewCount)"
                    ) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: document.fileName, systemImage: "doc")
                            RossInfoPill(title: "Jump to p. \(resolvedPage)", systemImage: "arrow.right.circle")
                        }
                    }

                    if let preview = AlphaDocumentPreview(document: document, initialPage: resolvedPage) {
                        preview
                    }

                    if let reviewSummaryText {
                        RossSectionCard(title: "Review extracted details", subtitle: reviewSummaryText) {
                            VStack(alignment: .leading, spacing: 14) {
                                if let classification = document.classification {
                                    AlphaClassificationReviewCard(
                                        classification: classification,
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

                                if let languageProfile = document.languageProfile {
                                    RossSectionCard(
                                        title: "Language profile",
                                        subtitle: "Ross keeps Hindi/English handling local and source-backed."
                                    ) {
                                        HStack(spacing: 12) {
                                            RossInfoPill(title: "Primary: \(languageProfile.primaryLanguage.rawValue.capitalized)", systemImage: "character.book.closed")
                                            RossInfoPill(title: "Scripts: \(languageProfile.scriptsDetected.joined(separator: ", "))", systemImage: "textformat.abc.dottedunderline")
                                        }
                                    }
                                }

                                ForEach(reviewFields) { field in
                                    AlphaExtractedFieldReviewCard(
                                        field: field,
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

                                if !reviewFindings.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Needs review")
                                            .font(.headline)
                                        ForEach(reviewFindings) { finding in
                                            AlphaFindingCard(finding: finding, onOpenSourceRef: model.openSourceRef)
                                        }
                                    }
                                }

                                if let upgrade = model.extractionUpgradeMessage(for: document) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(upgrade)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.rossAccent)

                                        Button("Run better extraction") {
                                            model.path.append(.privateAISettings)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }

                    RossSectionCard(title: "Extracted text", subtitle: "Text available so far for this document.") {
                        Text(document.extractedText ?? "No extracted text yet. Ross will keep source references visible even when exact highlights are still pending.")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.8))
                    }

                    RossSectionCard(title: "Source reference", subtitle: "If exact highlight placement is not ready, Ross shows page and snippet metadata here.") {
                        VStack(alignment: .leading, spacing: 10) {
                            if sourceRefs.isEmpty {
                                Text("Source unavailable. Ross will keep the document context visible without pretending to anchor a missing excerpt.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                            }

                            ForEach(currentPageRefs.isEmpty ? sourceRefs : currentPageRefs) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.label)
                                        .font(.headline)
                                    Text(source.detail)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.65))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.rossCardBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.rossBorder, lineWidth: 1)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Document Viewer")
        .rossInlineNavigationTitle()
    }
}

@MainActor
private func AlphaDocumentPreview(document: AlphaCaseDocument, initialPage: Int) -> AnyView? {
    if document.kind == .pdf {
        return AnyView(AlphaPDFPreview(relativePath: document.storedRelativePath, initialPage: initialPage))
    }

    if document.kind == .image {
        return AnyView(AlphaImagePreview(relativePath: document.storedRelativePath))
    }

    return AnyView(
        RossSectionCard(title: "Preview", subtitle: "Preview is not available for this file type yet.") {
            Text("A placeholder preview is shown while source anchors and extracted text stay available.")
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.7))
        }
    )
}

private struct AlphaClassificationReviewCard: View {
    let classification: AlphaLegalDocumentClassification
    let onAccept: () -> Void
    let onUpdateType: (AlphaLegalDocumentType) -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document type")
                        .font(.headline)
                    Text(classification.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.title3.weight(.semibold))
                    Text(classification.needsReview ? "Needs advocate review" : "Verified from source")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(classification.needsReview ? Color.orange : Color.rossSuccess)
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: classification.needsReview || classification.confidence < 0.64 ? "Needs review" : (classification.confidence >= 0.84 ? "High" : "Medium"),
                    tint: classification.needsReview || classification.confidence < 0.64 ? .orange : (classification.confidence >= 0.84 ? .green : Color.rossAccent)
                )
            }

            if let subtype = classification.subtype, !subtype.isEmpty {
                Text(subtype.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }

            HStack(spacing: 10) {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)

                Menu("Edit") {
                    ForEach([
                        AlphaLegalDocumentType.pleading,
                        .order,
                        .judgment,
                        .affidavit,
                        .notice,
                        .evidence,
                        .correspondence,
                        .misc
                    ], id: \.self) { type in
                        Button(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) {
                            onUpdateType(type)
                        }
                    }
                }
            }

            AlphaSourceRefChips(sourceRefs: classification.sourceRefs, onOpenSourceRef: onOpenSourceRef)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
    }
}

private struct AlphaExtractedFieldReviewCard: View {
    let field: AlphaExtractedLegalField
    let onAccept: () -> Void
    let onSaveEdit: (String) -> Void
    let onIgnore: () -> Void
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    @State private var isEditing = false
    @State private var draftValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label)
                        .font(.headline)
                    if isEditing {
                        TextField("Edit \(field.label.lowercased())", text: $draftValue)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(field.value)
                            .font(.body)
                            .foregroundStyle(Color.rossInk)
                    }
                    Text(field.needsReview ? "Needs advocate review" : "Verified from source")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(field.needsReview ? Color.orange : Color.rossSuccess)
                }
                Spacer()
                AlphaConfidenceBadge(
                    label: field.confidenceLabel,
                    tint: field.confidenceLabel == "High" ? .green : (field.confidenceLabel == "Medium" ? Color.rossAccent : .orange)
                )
            }

            AlphaSourceRefChips(sourceRefs: field.sourceRefs, onOpenSourceRef: onOpenSourceRef)

            HStack(spacing: 10) {
                if isEditing {
                    Button("Save") {
                        onSaveEdit(draftValue)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        draftValue = field.value
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Accept", action: onAccept)
                        .buttonStyle(.borderedProminent)

                    Button("Edit") {
                        draftValue = field.value
                        isEditing = true
                    }
                    .buttonStyle(.bordered)

                    Button("Ignore", role: .destructive, action: onIgnore)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
        .onAppear {
            draftValue = field.value
        }
    }
}

private struct AlphaFindingCard: View {
    let finding: AlphaExtractionFinding
    let onOpenSourceRef: (AlphaSourceRef) -> Void

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

            AlphaSourceRefChips(sourceRefs: finding.sourceRefs, onOpenSourceRef: onOpenSourceRef)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 1)
        }
    }
}

private struct AlphaSourceRefChips: View {
    let sourceRefs: [AlphaSourceRef]
    let onOpenSourceRef: (AlphaSourceRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sourceRefs.isEmpty {
                Text("Source pending")
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            } else {
                Text("Source")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.65))

                ForEach(sourceRefs.prefix(3)) { sourceRef in
                    Button {
                        onOpenSourceRef(sourceRef)
                    } label: {
                        HStack {
                            Text(sourceRef.label)
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Text(sourceRef.detail)
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.65))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AlphaConfidenceBadge: View {
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

private struct AlphaAskCaseScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID

    private var caseMatter: AlphaCaseMatter? {
        model.persisted.cases.first { $0.id == caseId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Ask Case", subtitle: "Source-backed local review for the selected matter.") {
                    TextEditor(text: Binding(
                        get: { model.askDrafts[caseId, default: "Summarize the next hearing posture and identify the strongest source-backed issue."] },
                        set: { model.askDrafts[caseId] = $0 }
                    ))
                    .frame(minHeight: 160)
                    .padding(12)
                    .background(Color.rossSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button("Run Local Review") {
                        model.askCase(caseId: caseId)
                    }
                    .rossPrimaryButtonStyle()
                }

                if let lastTurn = caseMatter?.chatTurns.first {
                    RossSectionCard(title: lastTurn.answerTitle, subtitle: "Draft for advocate review") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(lastTurn.answerSections, id: \.self) { section in
                                RossBulletRow(text: section)
                            }
                            Divider()
                            ForEach(lastTurn.sourceRefs) { source in
                                Button {
                                    model.openSourceRef(source)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(source.label)
                                                .font(.headline)
                                                .foregroundStyle(Color.rossInk)
                                            Text(source.detail)
                                                .font(.footnote)
                                                .foregroundStyle(Color.rossInk.opacity(0.65))
                                        }
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(Color.rossCardBackground)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.rossBorder, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Ask Case")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaPublicLawScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Public Law Search Preview", subtitle: "Public-law search sends only a sanitized query after explicit confirmation.") {
                    TextEditor(text: $model.publicLawDraft)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(Color.rossSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Do not send case IDs, filenames, OCR text, chunk text, chat history, client names, party names, phone numbers, emails, or long factual narratives.")
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))

                    Button("Generate Query Preview") {
                        model.buildPublicLawPreview()
                    }
                    .rossPrimaryButtonStyle()
                }

                if let preview = model.publicLawPreview {
                    RossSectionCard(title: "Sanitized preview", subtitle: preview.confirmationNote) {
                        Text(preview.query)
                            .font(.headline)
                        ForEach(preview.removed, id: \.self) { item in
                            RossBulletRow(text: item)
                        }
                        Button("Run Public-Law Search") {
                            Task { await model.runPublicLawSearch() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !model.publicLawResults.isEmpty {
                    RossSectionCard(title: "Preview results", subtitle: "Draft for advocate review") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.publicLawResults) { result in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.headline)
                                    Text(result.citation)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.rossAccent)
                                    Text(result.snippet)
                                        .font(.footnote)
                                        .foregroundStyle(Color.rossInk.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Public Law")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaExportsScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RossSectionCard(title: "Drafts / Exports", subtitle: "Generate local reports for chronology, case note, or chat transcript review.") {
                    VStack(spacing: 12) {
                        Button("Generate Chronology Report") {
                            Task { await model.generateExport(kind: "chronology_report", caseId: caseId) }
                        }
                        .rossPrimaryButtonStyle()

                        Button("Generate Case Note") {
                            Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)

                        Button("Generate Order Summary") {
                            Task { await model.generateExport(kind: "order_summary", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)

                        Button("Generate Chat Transcript") {
                            Task { await model.generateExport(kind: "chat_transcript", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ForEach(model.persisted.exports) { report in
                    RossSectionCard(title: report.title, subtitle: report.kind.replacingOccurrences(of: "_", with: " ").capitalized) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(report.relativePath)
                                .font(.footnote)
                                .foregroundStyle(Color.rossInk.opacity(0.7))

                            ShareLink(item: model.exportURL(for: report)) {
                                Label("Share local PDF", systemImage: "square.and.arrow.up")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Exports")
        .rossInlineNavigationTitle()
    }
}

private struct AlphaSettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List {
            Section("Privacy defaults") {
                Toggle("Require public-law approval", isOn: $model.persisted.settings.requirePublicLawApproval)
                Toggle("Private by default", isOn: $model.persisted.settings.privateByDefault)
                Toggle("Instant Mode", isOn: $model.persisted.settings.instantModeEnabled)
            }

            Section("Private AI") {
                LabeledContent("Active pack", value: model.activePack?.tier.title ?? "Not installed")
                LabeledContent("Extraction quality", value: model.activeExtractionMode.qualityLabel)
                NavigationLink(value: AlphaRoute.privateAISettings) {
                    Label("Private AI Settings", systemImage: "cpu")
                }
            }

            Section("Privacy ledger") {
                NavigationLink(value: AlphaRoute.privacyLedger) {
                    Label("Open Privacy Ledger", systemImage: "checklist")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

private struct AlphaPrivateAISettingsScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List {
            Section("Active pack") {
                LabeledContent("Pack", value: model.activePack?.tier.title ?? "No Private AI Pack installed")
                LabeledContent("Extraction quality", value: model.activeExtractionMode.qualityLabel)
                Text("Technical model names stay hidden unless you open technical details. Ross shows advocate-facing extraction quality instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let activePack = model.activePack {
                    Text(
                        activePack.tier == .quickStart
                            ? "Quick Start is best for shorter documents."
                            : "Better extraction for mixed-language or poor scans is enabled with this pack."
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                }
            }

            if let runtimeHealth = model.activeRuntimeHealth {
                Section("Technical details") {
                    LabeledContent("Runtime mode", value: runtimeHealth.runtimeMode.rawValue)
                    LabeledContent("Local runtime", value: runtimeHealth.available ? "available" : "unavailable")
                    LabeledContent("Fallback active", value: runtimeHealth.fallbackActive ? "yes" : "no")
                    LabeledContent("Explicit opt-in", value: runtimeHealth.explicitOptInEnabled ? "enabled" : "disabled")
                    LabeledContent("Model path present", value: runtimeHealth.modelPathPresent ? "yes" : "no")
                    LabeledContent("Checksum verified", value: runtimeHealth.checksumVerified ? "yes" : "no")
                    if let lastErrorCategory = runtimeHealth.lastErrorCategory {
                        LabeledContent("Last runtime error", value: lastErrorCategory)
                    }
                    if let lastInvocationRuntimeMode = model.lastModelInvocationRuntimeMode {
                        LabeledContent("Last invocation runtime", value: lastInvocationRuntimeMode)
                    }
                    if let maxInputChars = runtimeHealth.maxInputChars {
                        LabeledContent("Max input chars", value: "\(maxInputChars)")
                    }
                    Text(runtimeHealth.userFacingStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Download policy") {
                Toggle("Wi-Fi only downloads", isOn: $model.persisted.settings.wifiOnlyDownloads)
                Toggle("Allow mobile data for large packs", isOn: $model.persisted.settings.allowMobileDataForLargePacks)
            }

            Section("Available tiers") {
                ForEach(AlphaPackOffer.catalog) { offer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(offer.tier.title)
                            .font(.headline)
                        Text(offer.tier.summary)
                            .font(.footnote)
                        Text("Extraction quality: \(offer.tier.extractionQuality)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossAccent)
                        Text(offer.tier.bestFor)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Download / Resume") {
                                Task { await model.startPackDownload(for: offer.tier, mobileAllowed: model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Jobs") {
                ForEach(model.persisted.modelJobs) { job in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(job.tier.title)
                            .font(.headline)
                        Text(job.state.title)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossAccent)
                        Text("Checksum: \(job.checksumSha256.prefix(16))…")
                            .font(.caption)
                        HStack {
                            Button("Pause") { model.pauseJob(job) }
                            Button("Resume") { model.resumeJob(job) }
                        }
                    }
                }
            }

            Section("Installed packs") {
                ForEach(model.persisted.installedPacks) { pack in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pack.tier.title)
                            .font(.headline)
                        Text(pack.installPath)
                            .font(.caption)
                        HStack {
                            Button("Make Active") { model.activateInstalledPack(pack) }
                            Button("Remove", role: .destructive) { model.removeInstalledPack(pack) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Private AI")
    }
}

private struct AlphaPrivacyLedgerScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        List(model.persisted.ledgerEntries) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(entry.purpose.rawValue.replacingOccurrences(of: "_", with: " "))
                    Spacer()
                    Text(entry.payloadClass.rawValue.replacingOccurrences(of: "_", with: " "))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy Ledger")
    }
}

private func alphaFieldSortRank(_ type: AlphaExtractedLegalFieldType) -> Int {
    switch type {
    case .caseNumber:
        return 0
    case .court:
        return 1
    case .partyName:
        return 2
    case .date:
        return 3
    case .nextDate:
        return 4
    case .orderDirection:
        return 5
    case .section:
        return 6
    case .exhibitNumber:
        return 7
    case .relief:
        return 8
    case .prayer:
        return 9
    case .amount:
        return 10
    case .issue:
        return 11
    case .advocateName:
        return 12
    case .judgeName:
        return 13
    case .limitationDate:
        return 14
    case .fact:
        return 15
    case .unknown:
        return 16
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

#if canImport(PDFKit)
private struct AlphaPDFPreview: View {
    let relativePath: String
    let initialPage: Int

    var body: some View {
        RossSectionCard(title: "Preview", subtitle: "PDF viewer") {
            PDFRepresentedView(url: alphaAbsoluteURL(for: relativePath), initialPage: initialPage)
                .frame(minHeight: 360)
        }
    }
}

#if canImport(UIKit)
private struct PDFRepresentedView: UIViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
        if let document = uiView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                uiView.go(to: target)
            }
        }
    }
}
#elseif canImport(AppKit)
private struct PDFRepresentedView: NSViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: url)
        if let document = nsView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                nsView.go(to: target)
            }
        }
    }
}
#endif
#endif

private struct AlphaImagePreview: View {
    let relativePath: String

    var body: some View {
        RossSectionCard(title: "Preview", subtitle: "Imported image") {
            let url = alphaAbsoluteURL(for: relativePath)
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Image preview unavailable.")
            }
            #elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Image preview unavailable.")
            }
            #else
            Text("Image preview unavailable.")
            #endif
        }
    }
}
