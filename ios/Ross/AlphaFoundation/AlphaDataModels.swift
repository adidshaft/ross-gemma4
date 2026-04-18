import Foundation

enum AlphaOnboardingStage: String, Codable, Hashable, Sendable {
    case onboarding
    case privateAIPack
    case completed
}

enum AlphaAppTab: String, Codable, Hashable, CaseIterable, Sendable {
    case cases
    case publicLaw
    case exports
    case settings
}

enum AlphaCapabilityTier: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case quickStart = "quick_start"
    case caseAssociate = "case_associate"
    case seniorDraftingSupport = "senior_drafting_support"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickStart:
            "Quick Start"
        case .caseAssociate:
            "Case Associate"
        case .seniorDraftingSupport:
            "Senior Drafting Support"
        }
    }

    var summary: String {
        switch self {
        case .quickStart:
            "Basic summaries, short-file review, and lighter storage use."
        case .caseAssociate:
            "Source-backed case review, chronology work, and balanced local drafting."
        case .seniorDraftingSupport:
            "Longer files, deeper issue analysis, and richer drafting support."
        }
    }

    var storageNote: String {
        switch self {
        case .quickStart:
            "Light footprint"
        case .caseAssociate:
            "Balanced footprint"
        case .seniorDraftingSupport:
            "Largest footprint"
        }
    }

    var downloadSizeLabel: String {
        switch self {
        case .quickStart:
            "1.2 GB"
        case .caseAssociate:
            "2.8 GB"
        case .seniorDraftingSupport:
            "4.6 GB"
        }
    }

    var installedSizeLabel: String {
        switch self {
        case .quickStart:
            "2.1 GB"
        case .caseAssociate:
            "4.9 GB"
        case .seniorDraftingSupport:
            "7.4 GB"
        }
    }

    var bestFor: String {
        switch self {
        case .quickStart:
            "Fast intake, smaller devices, and quick summaries."
        case .caseAssociate:
            "Most advocates who need source-backed case work on-device."
        case .seniorDraftingSupport:
            "Longer bundles, hearing prep, and deeper drafting support."
        }
    }

    var quickStartFriendly: Bool {
        self != .seniorDraftingSupport
    }
}

struct AlphaPackOffer: Identifiable, Codable, Hashable, Sendable {
    let tier: AlphaCapabilityTier
    let runtimeLabel: String
    let supportsBilingualDrafting: Bool

    var id: AlphaCapabilityTier { tier }

    static let catalog: [AlphaPackOffer] = [
        AlphaPackOffer(tier: .quickStart, runtimeLabel: "Quick local review", supportsBilingualDrafting: false),
        AlphaPackOffer(tier: .caseAssociate, runtimeLabel: "Balanced local case work", supportsBilingualDrafting: true),
        AlphaPackOffer(tier: .seniorDraftingSupport, runtimeLabel: "Deeper local drafting", supportsBilingualDrafting: true)
    ]
}

enum AlphaCaseStage: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case intake
    case pleadings
    case evidence
    case arguments
    case reserved

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum AlphaDocumentKind: String, Codable, Hashable, Sendable {
    case pdf
    case image
    case text
    case unknown

    var title: String {
        rawValue.uppercased()
    }
}

enum AlphaOcrStatus: String, Codable, Hashable, Sendable {
    case notStarted
    case indexed
    case placeholder

    var title: String {
        switch self {
        case .notStarted:
            "Not indexed"
        case .indexed:
            "Indexed locally"
        case .placeholder:
            "Placeholder indexing"
        }
    }
}

struct AlphaDocumentPage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let pageNumber: Int
    let snippet: String?

    init(id: UUID = UUID(), pageNumber: Int, snippet: String? = nil) {
        self.id = id
        self.pageNumber = pageNumber
        self.snippet = snippet
    }
}

struct AlphaSourceRef: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let caseId: UUID
    let documentId: UUID
    let documentTitle: String
    let pageNumber: Int
    let paragraphRange: String?
    let textSnippet: String?
    let ocrConfidence: Double?

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        documentTitle: String,
        pageNumber: Int,
        paragraphRange: String? = nil,
        textSnippet: String? = nil,
        ocrConfidence: Double? = nil
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.paragraphRange = paragraphRange
        self.textSnippet = textSnippet
        self.ocrConfidence = ocrConfidence
    }

    var label: String {
        "\(documentTitle) p. \(pageNumber)"
    }

    var detail: String {
        textSnippet ?? "Source reference"
    }
}

struct AlphaCaseDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var fileName: String
    var kind: AlphaDocumentKind
    var storedRelativePath: String
    var importedAt: Date
    var pageCount: Int
    var ocrStatus: AlphaOcrStatus
    var extractedText: String?
    var pages: [AlphaDocumentPage]

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        kind: AlphaDocumentKind,
        storedRelativePath: String,
        importedAt: Date,
        pageCount: Int,
        ocrStatus: AlphaOcrStatus,
        extractedText: String? = nil,
        pages: [AlphaDocumentPage]
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.kind = kind
        self.storedRelativePath = storedRelativePath
        self.importedAt = importedAt
        self.pageCount = pageCount
        self.ocrStatus = ocrStatus
        self.extractedText = extractedText
        self.pages = pages
    }
}

struct AlphaChatTurn: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let askedAt: Date
    let question: String
    let answerTitle: String
    let answerSections: [String]
    let sourceRefs: [AlphaSourceRef]

    init(
        id: UUID = UUID(),
        askedAt: Date = .now,
        question: String,
        answerTitle: String,
        answerSections: [String],
        sourceRefs: [AlphaSourceRef]
    ) {
        self.id = id
        self.askedAt = askedAt
        self.question = question
        self.answerTitle = answerTitle
        self.answerSections = answerSections
        self.sourceRefs = sourceRefs
    }
}

struct AlphaCaseMatter: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var forum: String
    var stage: AlphaCaseStage
    var nextHearing: Date?
    var localNotice: String
    var summary: String
    var issueHighlights: [String]
    var evidenceNotes: [String]
    var draftTasks: [String]
    var documents: [AlphaCaseDocument]
    var sourceRefs: [AlphaSourceRef]
    var chatTurns: [AlphaChatTurn]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        forum: String,
        stage: AlphaCaseStage,
        nextHearing: Date? = nil,
        localNotice: String = "Case files stay on this device",
        summary: String,
        issueHighlights: [String],
        evidenceNotes: [String],
        draftTasks: [String],
        documents: [AlphaCaseDocument],
        sourceRefs: [AlphaSourceRef],
        chatTurns: [AlphaChatTurn] = [],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.forum = forum
        self.stage = stage
        self.nextHearing = nextHearing
        self.localNotice = localNotice
        self.summary = summary
        self.issueHighlights = issueHighlights
        self.evidenceNotes = evidenceNotes
        self.draftTasks = draftTasks
        self.documents = documents
        self.sourceRefs = sourceRefs
        self.chatTurns = chatTurns
        self.updatedAt = updatedAt
    }
}

enum AlphaPrivacyPurpose: String, Codable, Hashable, Sendable {
    case local_only
    case model_catalog
    case model_download
    case model_verification
    case public_law_search
}

enum AlphaPrivacyPayloadClass: String, Codable, Hashable, Sendable {
    case local_only
    case no_case_data
    case sanitized_public_query
    case account_token
}

struct AlphaPrivacyLedgerEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String
    let purpose: AlphaPrivacyPurpose
    let payloadClass: AlphaPrivacyPayloadClass
    let endpointLabel: String
    let success: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        title: String,
        detail: String,
        purpose: AlphaPrivacyPurpose,
        payloadClass: AlphaPrivacyPayloadClass,
        endpointLabel: String,
        success: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.purpose = purpose
        self.payloadClass = payloadClass
        self.endpointLabel = endpointLabel
        self.success = success
    }
}

enum AlphaDownloadState: String, Codable, Hashable, Sendable {
    case notStarted = "not_started"
    case queued
    case downloading
    case pausedWaitingForWifi = "paused_waiting_for_wifi"
    case pausedUser = "paused_user"
    case pausedNoStorage = "paused_no_storage"
    case pausedError = "paused_error"
    case verifying
    case installed
    case failed
    case cancelled

    var title: String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

enum AlphaDownloadPolicy: String, Codable, Hashable, Sendable {
    case wifiOnly = "wifi_only"
    case mobileAllowed = "mobile_allowed"
}

struct AlphaModelDownloadJob: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sessionId: String
    var packId: String
    var tier: AlphaCapabilityTier
    var state: AlphaDownloadState
    var networkPolicy: AlphaDownloadPolicy
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var checksumSha256: String
    var failureReason: String?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        sessionId: String,
        packId: String,
        tier: AlphaCapabilityTier,
        state: AlphaDownloadState,
        networkPolicy: AlphaDownloadPolicy,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        checksumSha256: String,
        failureReason: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.packId = packId
        self.tier = tier
        self.state = state
        self.networkPolicy = networkPolicy
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.checksumSha256 = checksumSha256
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }
}

struct AlphaInstalledModelPack: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var packId: String
    var tier: AlphaCapabilityTier
    var installPath: String
    var checksumSha256: String
    var installedAt: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        packId: String,
        tier: AlphaCapabilityTier,
        installPath: String,
        checksumSha256: String,
        installedAt: Date = .now,
        isActive: Bool
    ) {
        self.id = id
        self.packId = packId
        self.tier = tier
        self.installPath = installPath
        self.checksumSha256 = checksumSha256
        self.installedAt = installedAt
        self.isActive = isActive
    }
}

struct AlphaPublicLawResult: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let citation: String
    let snippet: String
    let sourceName: String

    init(id: UUID = UUID(), title: String, citation: String, snippet: String, sourceName: String) {
        self.id = id
        self.title = title
        self.citation = citation
        self.snippet = snippet
        self.sourceName = sourceName
    }
}

struct AlphaPublicLawCacheItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let query: String
    let savedAt: Date
    let resultTitles: [String]

    init(id: UUID = UUID(), query: String, savedAt: Date = .now, resultTitles: [String]) {
        self.id = id
        self.query = query
        self.savedAt = savedAt
        self.resultTitles = resultTitles
    }
}

struct AlphaExportedReport: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let caseId: UUID?
    let title: String
    let kind: String
    let relativePath: String
    let createdAt: Date

    init(id: UUID = UUID(), caseId: UUID?, title: String, kind: String, relativePath: String, createdAt: Date = .now) {
        self.id = id
        self.caseId = caseId
        self.title = title
        self.kind = kind
        self.relativePath = relativePath
        self.createdAt = createdAt
    }
}

struct AlphaSettings: Codable, Hashable, Sendable {
    var activeTier: AlphaCapabilityTier?
    var wifiOnlyDownloads: Bool
    var allowMobileDataForLargePacks: Bool
    var requirePublicLawApproval: Bool
    var instantModeEnabled: Bool
    var privateByDefault: Bool

    static let `default` = AlphaSettings(
        activeTier: nil,
        wifiOnlyDownloads: true,
        allowMobileDataForLargePacks: false,
        requirePublicLawApproval: true,
        instantModeEnabled: true,
        privateByDefault: true
    )
}

struct AlphaPublicLawPreview: Codable, Hashable, Sendable {
    var query: String
    var removed: [String]
    var confirmationNote: String
}

struct AlphaPersistedState: Codable, Hashable, Sendable {
    var onboardingStage: AlphaOnboardingStage
    var selectedTab: AlphaAppTab
    var settings: AlphaSettings
    var cases: [AlphaCaseMatter]
    var ledgerEntries: [AlphaPrivacyLedgerEntry]
    var modelJobs: [AlphaModelDownloadJob]
    var installedPacks: [AlphaInstalledModelPack]
    var publicLawCache: [AlphaPublicLawCacheItem]
    var exports: [AlphaExportedReport]

    static func seed() -> AlphaPersistedState {
        let petitionId = UUID()
        let noticeDocId = UUID()
        let draftDocId = UUID()
        let taxCaseId = UUID()
        let taxOrderId = UUID()

        let petitionDocs = [
            AlphaCaseDocument(
                id: draftDocId,
                title: "Writ Petition Draft",
                fileName: "writ-petition-draft.pdf",
                kind: .pdf,
                storedRelativePath: "seed/writ-petition-draft.pdf",
                importedAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
                pageCount: 28,
                ocrStatus: .indexed,
                extractedText: "Representation chronology, demand challenge, and hearing posture.",
                pages: (1...3).map { AlphaDocumentPage(pageNumber: $0, snippet: "Draft reference page \($0).") }
            ),
            AlphaCaseDocument(
                id: noticeDocId,
                title: "Impugned Notice",
                fileName: "impugned-notice.pdf",
                kind: .pdf,
                storedRelativePath: "seed/impugned-notice.pdf",
                importedAt: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
                pageCount: 6,
                ocrStatus: .indexed,
                extractedText: "Inspection grounds and compliance window.",
                pages: (1...2).map { AlphaDocumentPage(pageNumber: $0, snippet: "Notice page \($0).") }
            )
        ]

        let petitionSources = [
            AlphaSourceRef(caseId: petitionId, documentId: draftDocId, documentTitle: "Writ Petition Draft", pageNumber: 4, paragraphRange: "¶2-3", textSnippet: "Representation and reply timeline.", ocrConfidence: 0.96),
            AlphaSourceRef(caseId: petitionId, documentId: noticeDocId, documentTitle: "Impugned Notice", pageNumber: 2, paragraphRange: "¶1", textSnippet: "Inspection grounds and compliance window.", ocrConfidence: 0.91)
        ]

        let petitionCase = AlphaCaseMatter(
            id: petitionId,
            title: "Kaveri Developers v. South Ward Municipal Corporation",
            forum: "Karnataka High Court",
            stage: .pleadings,
            nextHearing: Calendar.current.date(byAdding: .day, value: 6, to: .now),
            summary: "The file is ready for a chronology-focused hearing note. The strongest near-term task is tying the representation sequence to the municipal demand pages already in the bundle.",
            issueHighlights: [
                "Whether the demand proceeds without addressing the representation already on record.",
                "Whether the notice timing supports a procedural fairness argument."
            ],
            evidenceNotes: [
                "Representation acknowledgment page should stay close to the hearing note.",
                "Photo bundle still needs placeholder page records for quick navigation."
            ],
            draftTasks: [
                "Prepare a short chronology for the next hearing.",
                "Anchor the reply timeline to source chips.",
                "Draft a focused procedural fairness note."
            ],
            documents: petitionDocs,
            sourceRefs: petitionSources,
            updatedAt: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now
        )

        let taxDocs = [
            AlphaCaseDocument(
                id: taxOrderId,
                title: "Assessment Order",
                fileName: "assessment-order.pdf",
                kind: .pdf,
                storedRelativePath: "seed/assessment-order.pdf",
                importedAt: Calendar.current.date(byAdding: .day, value: -15, to: .now) ?? .now,
                pageCount: 19,
                ocrStatus: .indexed,
                extractedText: "Assessment reasoning and discrepancy notes.",
                pages: (1...2).map { AlphaDocumentPage(pageNumber: $0, snippet: "Assessment page \($0).") }
            )
        ]

        let taxSources = [
            AlphaSourceRef(caseId: taxCaseId, documentId: taxOrderId, documentTitle: "Assessment Order", pageNumber: 11, paragraphRange: "¶4", textSnippet: "Reasoning on discrepancy.", ocrConfidence: 0.89)
        ]

        let taxCase = AlphaCaseMatter(
            id: taxCaseId,
            title: "Arun Textiles v. State Tax Officer",
            forum: "Madras High Court",
            stage: .evidence,
            nextHearing: Calendar.current.date(byAdding: .day, value: 14, to: .now),
            summary: "The file supports an evidence-focused review with the order and reconciliation pages ready for source-backed issue extraction.",
            issueHighlights: [
                "Mismatch between the assessment reasoning and the reconciliation schedule.",
                "Need to isolate whether the clarification already supplied was engaged."
            ],
            evidenceNotes: [
                "Order pages are ready for source-backed notes.",
                "A short hearing-preparation export can be generated once discrepancy pages are pinned."
            ],
            draftTasks: [
                "Map discrepancy pages against the order reasoning.",
                "Prepare a short note for the next hearing."
            ],
            documents: taxDocs,
            sourceRefs: taxSources,
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        )

        return AlphaPersistedState(
            onboardingStage: .onboarding,
            selectedTab: .cases,
            settings: .default,
            cases: [petitionCase, taxCase],
            ledgerEntries: [
                AlphaPrivacyLedgerEntry(
                    timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: .now) ?? .now,
                    title: "Model catalog checked",
                    detail: "Catalog metadata was reviewed without case files attached.",
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "/model-catalog",
                    success: true
                )
            ],
            modelJobs: [],
            installedPacks: [],
            publicLawCache: [],
            exports: []
        )
    }
}
