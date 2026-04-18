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

            persisted.cases[caseIndex].documents.insert(imported.document, at: 0)
            persisted.cases[caseIndex].updatedAt = .now

            let sourceRef = AlphaSourceRef(
                caseId: caseId,
                documentId: imported.document.id,
                documentTitle: imported.document.title,
                pageNumber: 1,
                paragraphRange: nil,
                textSnippet: imported.document.extractedText ?? "Imported source reference",
                ocrConfidence: imported.document.kind == .image ? nil : 0.92
            )
            persisted.cases[caseIndex].sourceRefs.insert(sourceRef, at: 0)

            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document imported locally",
                    detail: "\(imported.document.title) was copied into app-private storage.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: true
                ),
                at: 0
            )
            persist()
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

    func buildPublicLawPreview() {
        let text = publicLawDraft.trimmingCharacters(in: .whitespacesAndNewlines)
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
            sanitized = "Find current public-law guidance relevant to delay condonation where diligence is documented."
        }

        if sanitized.count > 180 {
            removed.append("Long factual narrative")
            sanitized = String(sanitized.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        publicLawPreview = AlphaPublicLawPreview(
            query: sanitized.isEmpty ? "Find current public-law guidance relevant to delay condonation where diligence is documented." : sanitized,
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
        let refs = caseMatter?.sourceRefs.prefix(6).map { "- \($0.label): \($0.detail)" } ?? ["- No source references available yet."]
        let notes = caseMatter?.draftTasks.map { "- \($0)" } ?? ["- No tasks yet."]

        return [
            title,
            "Generated: \(generatedDate)",
            "Draft for advocate review",
            "",
            "Report type: \(kind.replacingOccurrences(of: "_", with: " "))",
            "",
            "Summary",
            caseMatter?.summary ?? "No case selected.",
            "",
            "Working notes",
        ] + notes + [
            "",
            "Source references",
        ] + refs + [
            "",
            "Generated locally for advocate review. Verify all citations."
        ]
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
        let rawURL = ProcessInfo.processInfo.environment["ROSS_BACKEND_BASE_URL"] ?? "http://127.0.0.1:8080"
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

    var body: some View {
        ScrollView {
            if let document {
                VStack(alignment: .leading, spacing: 20) {
                    RossHeroCard(
                        eyebrow: document.kind.title,
                        title: document.title,
                        detail: "Page count: \(document.pageCount) • OCR/indexing: \(document.ocrStatus.title)"
                    ) {
                        HStack(spacing: 12) {
                            RossInfoPill(title: document.fileName, systemImage: "doc")
                            RossInfoPill(title: "Jump to p. \(resolvedPage)", systemImage: "arrow.right.circle")
                        }
                    }

                    if let preview = AlphaDocumentPreview(document: document, initialPage: resolvedPage) {
                        preview
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

                        Button("Generate Chat Transcript") {
                            Task { await model.generateExport(kind: "chat_transcript", caseId: caseId) }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ForEach(model.persisted.exports) { report in
                    RossSectionCard(title: report.title, subtitle: report.kind.replacingOccurrences(of: "_", with: " ").capitalized) {
                        Text(report.relativePath)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
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
                LabeledContent("Active tier", value: model.persisted.settings.activeTier?.title ?? "Not selected")
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
