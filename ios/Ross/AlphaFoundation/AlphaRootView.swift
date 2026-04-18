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
    }

    func runPublicLawSearch() {
        guard let preview = publicLawPreview else { return }
        publicLawResults = [
            AlphaPublicLawResult(
                title: "Delay condonation and documented diligence",
                citation: "(2024) 7 SCC 112",
                snippet: "Diligence, chronology, and the absence of strategic delay remain central to condonation review.",
                sourceName: "Official or licensed source (preview)"
            ),
            AlphaPublicLawResult(
                title: "Administrative fairness in filing-delay matters",
                citation: "2023 SCC OnLine SC 881",
                snippet: "A brief disruption may be weighed differently where the record shows prompt corrective action and contemporaneous documentation.",
                sourceName: "Official or licensed source (preview)"
            )
        ]
        persisted.publicLawCache.insert(
            AlphaPublicLawCacheItem(query: preview.query, resultTitles: publicLawResults.map(\.title)),
            at: 0
        )
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
        let body = exportBody(kind: kind, caseMatter: caseMatter)

        do {
            let report = try await store.createTextExport(
                title: "\(titleBase) \(kind)",
                kind: kind,
                caseId: caseId,
                body: body
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
        let sessionId = "mdl-\(UUID().uuidString.prefix(8))"
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let waitingForWifi = !mobileAllowed && tier != .quickStart
        let totalBytes: Int64 = tier == .quickStart ? 1_200_000_000 : (tier == .caseAssociate ? 2_800_000_000 : 4_600_000_000)
        let checksumSeed = SHA256.hash(data: Data("\(tier.rawValue)-\(sessionId)".utf8)).map { String(format: "%02x", $0) }.joined()

        let job = AlphaModelDownloadJob(
            sessionId: sessionId,
            packId: "\(tier.rawValue)-pack",
            tier: tier,
            state: waitingForWifi ? .pausedWaitingForWifi : .queued,
            networkPolicy: policy,
            bytesDownloaded: 0,
            totalBytes: totalBytes,
            checksumSha256: checksumSeed
        )

        upsertJob(job)
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
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: waitingForWifi ? "Private AI Pack waiting for Wi-Fi" : "Private AI Pack queued",
                detail: "Model delivery started without reading case files.",
                purpose: .model_download,
                payloadClass: .no_case_data,
                endpointLabel: "/model-download/session",
                success: true
            ),
            at: 0
        )
        persist()

        guard !waitingForWifi else { return }

        updateJob(job.id) {
            $0.state = .downloading
            $0.bytesDownloaded = $0.totalBytes
            $0.updatedAt = .now
        }
        persist()

        updateJob(job.id) {
            $0.state = .verifying
            $0.updatedAt = .now
        }
        persist()

        do {
            let artifact = try await store.writeDevPackArtifact(for: tier)
            let installed = AlphaInstalledModelPack(
                packId: job.packId,
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
            updateJob(job.id) {
                $0.state = .failed
                $0.failureReason = "Install artifact could not be prepared."
                $0.updatedAt = .now
            }
            persist()
        }
    }

    private func exportBody(kind: String, caseMatter: AlphaCaseMatter?) -> String {
        let title = caseMatter?.title ?? "Ross"
        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        let refs = caseMatter?.sourceRefs.prefix(3).map { "- \($0.label): \($0.detail)" }.joined(separator: "\n") ?? "- No source references available yet."
        let notes = caseMatter?.draftTasks.joined(separator: "\n- ") ?? "No tasks yet."

        return """
        \(title)
        Generated: \(generatedDate)
        Draft for advocate review

        Report type: \(kind)

        Summary
        \(caseMatter?.summary ?? "No case selected.")

        Working notes
        - \(notes)

        Source references
        \(refs)

        Generated locally for advocate review. Verify all citations.
        """
    }

    private func persist() {
        let snapshot = persisted
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
                            RossInfoPill(title: initialPage.map { "Jump to p. \($0)" } ?? "Source reference ready", systemImage: "arrow.right.circle")
                        }
                    }

                    if let preview = AlphaDocumentPreview(document: document) {
                        preview
                    }

                    RossSectionCard(title: "Extracted text", subtitle: "Text available so far for this document.") {
                        Text(document.extractedText ?? "No extracted text yet. Ross will keep source references visible even when exact highlights are still pending.")
                            .font(.body)
                            .foregroundStyle(Color.rossInk.opacity(0.8))
                    }

                    RossSectionCard(title: "Source reference", subtitle: "If exact highlight placement is not ready, Ross shows page and snippet metadata here.") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sourceRefs) { source in
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
private func AlphaDocumentPreview(document: AlphaCaseDocument) -> AnyView? {
    if document.kind == .pdf {
        return AnyView(AlphaPDFPreview(relativePath: document.storedRelativePath))
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
                            model.runPublicLawSearch()
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

    var body: some View {
        RossSectionCard(title: "Preview", subtitle: "PDF viewer") {
            PDFRepresentedView(url: alphaAbsoluteURL(for: relativePath))
                .frame(minHeight: 360)
        }
    }
}

#if canImport(UIKit)
private struct PDFRepresentedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
#elseif canImport(AppKit)
private struct PDFRepresentedView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: url)
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
