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
            "Basic extraction for short documents, simple summaries, and lighter storage use."
        case .caseAssociate:
            "Better document understanding, stronger field extraction, mixed English/Hindi support, and source-backed chronology work."
        case .seniorDraftingSupport:
            "Deeper review, verification pass, longer bilingual bundles, and evidence or issue analysis."
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
            "Fast intake, smaller devices, and standard extraction for short documents."
        case .caseAssociate:
            "Most advocates who need source-backed extraction, chronology work, and mixed-language review on-device."
        case .seniorDraftingSupport:
            "Longer bundles, hearing prep, verification passes, and stronger bilingual workflows."
        }
    }

    var extractionQuality: String {
        switch self {
        case .quickStart:
            "Standard"
        case .caseAssociate:
            "Advanced"
        case .seniorDraftingSupport:
            "Advanced"
        }
    }

    var quickStartFriendly: Bool {
        self != .seniorDraftingSupport
    }

    var rank: Int {
        switch self {
        case .quickStart:
            1
        case .caseAssociate:
            2
        case .seniorDraftingSupport:
            3
        }
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
    case nativeText = "native_text"
    case ocrComplete = "ocr_complete"
    case partial
    case failed

    var title: String {
        switch self {
        case .notStarted:
            "Not indexed"
        case .indexed:
            "Indexed locally"
        case .placeholder:
            "Placeholder indexing"
        case .nativeText:
            "Native text indexed"
        case .ocrComplete:
            "OCR complete"
        case .partial:
            "Partial OCR"
        case .failed:
            "OCR unavailable"
        }
    }
}

enum AlphaIndexingStatus: String, Codable, Hashable, Sendable {
    case notStarted = "not_started"
    case extracting
    case indexed
    case partial
    case failed

    var title: String {
        switch self {
        case .notStarted:
            "Not started"
        case .extracting:
            "Extracting locally"
        case .indexed:
            "Indexed locally"
        case .partial:
            "Partially indexed"
        case .failed:
            "Indexing failed"
        }
    }
}

struct AlphaNormalizedRect: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct AlphaDocumentPage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let pageNumber: Int
    let snippet: String?
    var extractedText: String?
    var anchorText: String?
    var ocrConfidence: Double?
    var ocrStatus: AlphaOcrStatus?
    var indexingStatus: AlphaIndexingStatus?
    var highlightRects: [AlphaNormalizedRect]?

    init(
        id: UUID = UUID(),
        pageNumber: Int,
        snippet: String? = nil,
        extractedText: String? = nil,
        anchorText: String? = nil,
        ocrConfidence: Double? = nil,
        ocrStatus: AlphaOcrStatus? = nil,
        indexingStatus: AlphaIndexingStatus? = nil,
        highlightRects: [AlphaNormalizedRect]? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.snippet = snippet
        self.extractedText = extractedText
        self.anchorText = anchorText
        self.ocrConfidence = ocrConfidence
        self.ocrStatus = ocrStatus
        self.indexingStatus = indexingStatus
        self.highlightRects = highlightRects
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
    var highlightText: String?
    var highlightRects: [AlphaNormalizedRect]?

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        documentTitle: String,
        pageNumber: Int,
        paragraphRange: String? = nil,
        textSnippet: String? = nil,
        ocrConfidence: Double? = nil,
        highlightText: String? = nil,
        highlightRects: [AlphaNormalizedRect]? = nil
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.paragraphRange = paragraphRange
        self.textSnippet = textSnippet
        self.ocrConfidence = ocrConfidence
        self.highlightText = highlightText
        self.highlightRects = highlightRects
    }

    var label: String {
        "\(documentTitle) p. \(pageNumber)"
    }

    var detail: String {
        textSnippet ?? "Source reference"
    }
}

enum AlphaExtractionMode: String, Codable, Hashable, Sendable {
    case basic
    case quickStart = "quick_start"
    case caseAssociate = "case_associate"
    case seniorDraftingSupport = "senior_drafting_support"

    static func fromTier(_ tier: AlphaCapabilityTier?) -> AlphaExtractionMode {
        switch tier {
        case .none:
            .basic
        case .quickStart:
            .quickStart
        case .caseAssociate:
            .caseAssociate
        case .seniorDraftingSupport:
            .seniorDraftingSupport
        }
    }

    static func fromInstalledPack(_ pack: AlphaInstalledModelPack?) -> AlphaExtractionMode {
        fromTier(pack?.tier)
    }

    var qualityLabel: String {
        switch self {
        case .basic:
            "Basic"
        case .quickStart:
            "Standard"
        case .caseAssociate:
            "Advanced"
        case .seniorDraftingSupport:
            "Advanced"
        }
    }
}

enum AlphaDocumentLanguage: String, Codable, Hashable, Sendable {
    case english
    case hindi
    case mixed
    case unknown
}

enum AlphaDocumentScript: String, Codable, Hashable, Sendable {
    case latin
    case devanagari
    case mixed
    case other
    case unknown
}

struct AlphaDocumentLanguageProfilePage: Codable, Hashable, Sendable {
    var pageNumber: Int
    var language: AlphaDocumentLanguage
    var script: AlphaDocumentScript
    var confidence: Double
}

struct AlphaDocumentLanguageProfile: Codable, Hashable, Sendable {
    var documentId: UUID
    var primaryLanguage: AlphaDocumentLanguage
    var scriptsDetected: [String]
    var confidence: Double
    var pageProfiles: [AlphaDocumentLanguageProfilePage]
}

enum AlphaLegalDocumentType: String, Codable, Hashable, Sendable {
    case pleading
    case order
    case judgment
    case affidavit
    case notice
    case evidence
    case correspondence
    case misc
}

struct AlphaLegalDocumentClassification: Codable, Hashable, Sendable {
    var documentId: UUID
    var type: AlphaLegalDocumentType
    var subtype: String?
    var confidence: Double
    var sourceRefs: [AlphaSourceRef]
    var needsReview: Bool
}

enum AlphaExtractedLegalFieldType: String, Codable, Hashable, Sendable {
    case court
    case caseNumber = "case_number"
    case partyName = "party_name"
    case advocateName = "advocate_name"
    case judgeName = "judge_name"
    case date
    case nextDate = "next_date"
    case section
    case relief
    case prayer
    case orderDirection = "order_direction"
    case limitationDate = "limitation_date"
    case amount
    case exhibitNumber = "exhibit_number"
    case fact
    case issue
    case unknown

    var title: String {
        switch self {
        case .court:
            "Court"
        case .caseNumber:
            "Case number"
        case .partyName:
            "Party"
        case .advocateName:
            "Advocate"
        case .judgeName:
            "Judge"
        case .date:
            "Date"
        case .nextDate:
            "Next date"
        case .section:
            "Section"
        case .relief:
            "Relief"
        case .prayer:
            "Prayer"
        case .orderDirection:
            "Order direction"
        case .limitationDate:
            "Limitation date"
        case .amount:
            "Amount"
        case .exhibitNumber:
            "Exhibit"
        case .fact:
            "Fact"
        case .issue:
            "Issue"
        case .unknown:
            "Unknown"
        }
    }
}

enum AlphaExtractionPass: String, Codable, Hashable, Sendable {
    case ocr
    case regex
    case llmExtract = "llm_extract"
    case llmVerify = "llm_verify"
    case userCorrected = "user_corrected"
}

struct AlphaExtractedLegalField: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var documentId: UUID
    var fieldType: AlphaExtractedLegalFieldType
    var label: String
    var value: String
    var normalizedValue: String?
    var sourceRefs: [AlphaSourceRef]
    var confidence: Double
    var extractionMode: AlphaExtractionMode
    var extractionPass: AlphaExtractionPass
    var needsReview: Bool
    var userCorrected: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        fieldType: AlphaExtractedLegalFieldType,
        label: String,
        value: String,
        normalizedValue: String? = nil,
        sourceRefs: [AlphaSourceRef],
        confidence: Double,
        extractionMode: AlphaExtractionMode,
        extractionPass: AlphaExtractionPass,
        needsReview: Bool,
        userCorrected: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.fieldType = fieldType
        self.label = label
        self.value = value
        self.normalizedValue = normalizedValue
        self.sourceRefs = sourceRefs
        self.confidence = confidence
        self.extractionMode = extractionMode
        self.extractionPass = extractionPass
        self.needsReview = needsReview
        self.userCorrected = userCorrected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var confidenceLabel: String {
        if needsReview || confidence < 0.64 {
            return "Needs review"
        }
        if confidence >= 0.84 {
            return "High"
        }
        return "Medium"
    }
}

enum AlphaExtractionRunStatus: String, Codable, Hashable, Sendable {
    case queued
    case running
    case needsReview = "needs_review"
    case complete
    case failed
    case cancelled
}

enum AlphaExtractionProgressState: String, Codable, Hashable, Sendable {
    case acquiringText = "acquiring_text"
    case detectingLanguage = "detecting_language"
    case extractingFields = "extracting_fields"
    case verifyingFields = "verifying_fields"
    case preparingReview = "preparing_review"
    case complete
    case needsReview = "needs_review"
    case failed
}

struct AlphaExtractionRun: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var documentId: UUID
    var mode: AlphaExtractionMode
    var status: AlphaExtractionRunStatus
    var progressState: AlphaExtractionProgressState
    var startedAt: Date?
    var completedAt: Date?
    var pagesProcessed: Int
    var totalPages: Int
    var fieldsExtracted: Int
    var fieldsNeedingReview: Int
    var warnings: [String]
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        mode: AlphaExtractionMode,
        status: AlphaExtractionRunStatus,
        progressState: AlphaExtractionProgressState,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        pagesProcessed: Int,
        totalPages: Int,
        fieldsExtracted: Int,
        fieldsNeedingReview: Int,
        warnings: [String],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.mode = mode
        self.status = status
        self.progressState = progressState
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.pagesProcessed = pagesProcessed
        self.totalPages = totalPages
        self.fieldsExtracted = fieldsExtracted
        self.fieldsNeedingReview = fieldsNeedingReview
        self.warnings = warnings
        self.errorMessage = errorMessage
    }
}

enum AlphaExtractionFindingKind: String, Codable, Hashable, Sendable {
    case lowConfidenceOcr = "low_confidence_ocr"
    case languageUncertain = "language_uncertain"
    case possibleMissingPage = "possible_missing_page"
    case dateConflict = "date_conflict"
    case partyConflict = "party_conflict"
    case caseNumberConflict = "case_number_conflict"
    case ambiguousOrderDirection = "ambiguous_order_direction"
    case possibleHandwriting = "possible_handwriting"
    case unsupportedLayout = "unsupported_layout"
}

enum AlphaExtractionFindingSeverity: String, Codable, Hashable, Sendable {
    case info
    case warning
    case critical
}

struct AlphaExtractionFinding: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var documentId: UUID
    var kind: AlphaExtractionFindingKind
    var message: String
    var sourceRefs: [AlphaSourceRef]
    var severity: AlphaExtractionFindingSeverity
    var resolved: Bool

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        kind: AlphaExtractionFindingKind,
        message: String,
        sourceRefs: [AlphaSourceRef],
        severity: AlphaExtractionFindingSeverity,
        resolved: Bool = false
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.kind = kind
        self.message = message
        self.sourceRefs = sourceRefs
        self.severity = severity
        self.resolved = resolved
    }
}

enum AlphaAdvocateCorrectionType: String, Codable, Hashable, Sendable {
    case fieldValue = "field_value"
    case documentType = "document_type"
    case language
    case date
    case party
    case sourceRef = "source_ref"
    case ignoreField = "ignore_field"
}

struct AlphaAdvocateCorrection: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var documentId: UUID
    var fieldId: UUID?
    var oldValue: String?
    var newValue: String
    var correctionType: AlphaAdvocateCorrectionType
    var createdAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        fieldId: UUID? = nil,
        oldValue: String? = nil,
        newValue: String,
        correctionType: AlphaAdvocateCorrectionType,
        createdAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.fieldId = fieldId
        self.oldValue = oldValue
        self.newValue = newValue
        self.correctionType = correctionType
        self.createdAt = createdAt
    }
}

enum AlphaCaseMemoryUpdateSource: String, Codable, Hashable, Sendable {
    case extractionRun = "extraction_run"
    case userCorrection = "user_correction"
    case askCase = "ask_case"
    case manualNote = "manual_note"
}

struct AlphaCaseMemoryUpdate: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var source: AlphaCaseMemoryUpdateSource
    var summary: String
    var affectedDocuments: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        source: AlphaCaseMemoryUpdateSource,
        summary: String,
        affectedDocuments: [UUID],
        createdAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.source = source
        self.summary = summary
        self.affectedDocuments = affectedDocuments
        self.createdAt = createdAt
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
    var indexingStatus: AlphaIndexingStatus?
    var extractedText: String?
    var dominantSourceSnippet: String?
    var lastIndexedAt: Date?
    var pages: [AlphaDocumentPage]
    var languageProfile: AlphaDocumentLanguageProfile?
    var classification: AlphaLegalDocumentClassification?
    var extractedFields: [AlphaExtractedLegalField]
    var extractionRuns: [AlphaExtractionRun]
    var extractionFindings: [AlphaExtractionFinding]
    var modelInvocations: [AlphaLocalModelInvocation]

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        kind: AlphaDocumentKind,
        storedRelativePath: String,
        importedAt: Date,
        pageCount: Int,
        ocrStatus: AlphaOcrStatus,
        indexingStatus: AlphaIndexingStatus? = nil,
        extractedText: String? = nil,
        dominantSourceSnippet: String? = nil,
        lastIndexedAt: Date? = nil,
        pages: [AlphaDocumentPage],
        languageProfile: AlphaDocumentLanguageProfile? = nil,
        classification: AlphaLegalDocumentClassification? = nil,
        extractedFields: [AlphaExtractedLegalField] = [],
        extractionRuns: [AlphaExtractionRun] = [],
        extractionFindings: [AlphaExtractionFinding] = [],
        modelInvocations: [AlphaLocalModelInvocation] = []
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.kind = kind
        self.storedRelativePath = storedRelativePath
        self.importedAt = importedAt
        self.pageCount = pageCount
        self.ocrStatus = ocrStatus
        self.indexingStatus = indexingStatus
        self.extractedText = extractedText
        self.dominantSourceSnippet = dominantSourceSnippet
        self.lastIndexedAt = lastIndexedAt
        self.pages = pages
        self.languageProfile = languageProfile
        self.classification = classification
        self.extractedFields = extractedFields
        self.extractionRuns = extractionRuns
        self.extractionFindings = extractionFindings
        self.modelInvocations = modelInvocations
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
    var advocateCorrections: [AlphaAdvocateCorrection]
    var caseMemoryUpdates: [AlphaCaseMemoryUpdate]
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
        advocateCorrections: [AlphaAdvocateCorrection] = [],
        caseMemoryUpdates: [AlphaCaseMemoryUpdate] = [],
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
        self.advocateCorrections = advocateCorrections
        self.caseMemoryUpdates = caseMemoryUpdates
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

enum AlphaPackRuntimeMode: String, Codable, Hashable, Sendable {
    case deterministicDev = "deterministic_dev"
    case mediapipeLlm = "mediapipe_llm"
    case llamaCppGguf = "gemma_local_runtime"
    case appleFoundationModels = "apple_foundation_models"
    case unavailable = "unavailable"

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case AlphaPackRuntimeMode.deterministicDev.rawValue:
            self = .deterministicDev
        case AlphaPackRuntimeMode.mediapipeLlm.rawValue:
            self = .mediapipeLlm
        case AlphaPackRuntimeMode.llamaCppGguf.rawValue:
            self = .llamaCppGguf
        case AlphaPackRuntimeMode.appleFoundationModels.rawValue:
            self = .appleFoundationModels
        case "platform_stub", AlphaPackRuntimeMode.unavailable.rawValue:
            self = .unavailable
        default:
            self = .unavailable
        }
    }
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
    var artifactKind: String
    var runtimeMode: AlphaPackRuntimeMode
    var developmentOnly: Bool
    var minimumAppVersion: String
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
        artifactKind: String = "tiny_dev_artifact",
        runtimeMode: AlphaPackRuntimeMode = .deterministicDev,
        developmentOnly: Bool = true,
        minimumAppVersion: String = "0.1.0",
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
        self.artifactKind = artifactKind
        self.runtimeMode = runtimeMode
        self.developmentOnly = developmentOnly
        self.minimumAppVersion = minimumAppVersion
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case packId
        case tier
        case state
        case networkPolicy
        case bytesDownloaded
        case totalBytes
        case checksumSha256
        case artifactKind
        case runtimeMode
        case developmentOnly
        case minimumAppVersion
        case failureReason
        case createdAt
        case updatedAt
        case completedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sessionId = try container.decode(String.self, forKey: .sessionId)
        packId = try container.decode(String.self, forKey: .packId)
        tier = try container.decode(AlphaCapabilityTier.self, forKey: .tier)
        state = try container.decode(AlphaDownloadState.self, forKey: .state)
        networkPolicy = try container.decode(AlphaDownloadPolicy.self, forKey: .networkPolicy)
        bytesDownloaded = try container.decode(Int64.self, forKey: .bytesDownloaded)
        totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
        checksumSha256 = try container.decode(String.self, forKey: .checksumSha256)
        artifactKind = try container.decodeIfPresent(String.self, forKey: .artifactKind) ?? "tiny_dev_artifact"
        runtimeMode = try container.decodeIfPresent(AlphaPackRuntimeMode.self, forKey: .runtimeMode) ?? .deterministicDev
        developmentOnly = try container.decodeIfPresent(Bool.self, forKey: .developmentOnly) ?? true
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion) ?? "0.1.0"
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

struct AlphaInstalledModelPack: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var packId: String
    var tier: AlphaCapabilityTier
    var installPath: String
    var checksumSha256: String
    var artifactKind: String
    var runtimeMode: AlphaPackRuntimeMode
    var developmentOnly: Bool
    var checksumVerified: Bool
    var minimumAppVersion: String
    var installedAt: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        packId: String,
        tier: AlphaCapabilityTier,
        installPath: String,
        checksumSha256: String,
        artifactKind: String = "tiny_dev_artifact",
        runtimeMode: AlphaPackRuntimeMode = .deterministicDev,
        developmentOnly: Bool = true,
        checksumVerified: Bool = true,
        minimumAppVersion: String = "0.1.0",
        installedAt: Date = .now,
        isActive: Bool
    ) {
        self.id = id
        self.packId = packId
        self.tier = tier
        self.installPath = installPath
        self.checksumSha256 = checksumSha256
        self.artifactKind = artifactKind
        self.runtimeMode = runtimeMode
        self.developmentOnly = developmentOnly
        self.checksumVerified = checksumVerified
        self.minimumAppVersion = minimumAppVersion
        self.installedAt = installedAt
        self.isActive = isActive
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case packId
        case tier
        case installPath
        case checksumSha256
        case artifactKind
        case runtimeMode
        case developmentOnly
        case checksumVerified
        case minimumAppVersion
        case installedAt
        case isActive
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        packId = try container.decode(String.self, forKey: .packId)
        tier = try container.decode(AlphaCapabilityTier.self, forKey: .tier)
        installPath = try container.decode(String.self, forKey: .installPath)
        checksumSha256 = try container.decode(String.self, forKey: .checksumSha256)
        artifactKind = try container.decodeIfPresent(String.self, forKey: .artifactKind) ?? "tiny_dev_artifact"
        runtimeMode = try container.decodeIfPresent(AlphaPackRuntimeMode.self, forKey: .runtimeMode) ?? .deterministicDev
        developmentOnly = try container.decodeIfPresent(Bool.self, forKey: .developmentOnly) ?? true
        checksumVerified = try container.decodeIfPresent(Bool.self, forKey: .checksumVerified) ?? true
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion) ?? "0.1.0"
        installedAt = try container.decodeIfPresent(Date.self, forKey: .installedAt) ?? .now
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
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
    var lastModelCatalogRefresh: Date?
    var publicLawCache: [AlphaPublicLawCacheItem]
    var publicLawDraft: String?
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult]?
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
                ocrStatus: .nativeText,
                indexingStatus: .indexed,
                extractedText: "Representation chronology, demand challenge, and hearing posture.",
                dominantSourceSnippet: "Representation chronology, demand challenge, and hearing posture.",
                lastIndexedAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
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
                ocrStatus: .nativeText,
                indexingStatus: .indexed,
                extractedText: "Inspection grounds and compliance window.",
                dominantSourceSnippet: "Inspection grounds and compliance window.",
                lastIndexedAt: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
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
                ocrStatus: .nativeText,
                indexingStatus: .indexed,
                extractedText: "Assessment reasoning and discrepancy notes.",
                dominantSourceSnippet: "Assessment reasoning and discrepancy notes.",
                lastIndexedAt: Calendar.current.date(byAdding: .day, value: -15, to: .now) ?? .now,
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
            lastModelCatalogRefresh: nil,
            publicLawCache: [],
            publicLawDraft: "Find Supreme Court guidance on delay condonation where diligence is documented but filing was disrupted.",
            publicLawPreview: nil,
            publicLawResults: [],
            exports: []
        )
    }
}

extension AlphaCaseDocument {
    var effectiveIndexingStatus: AlphaIndexingStatus {
        if let indexingStatus {
            return indexingStatus
        }

        switch ocrStatus {
        case .indexed, .nativeText, .ocrComplete:
            return .indexed
        case .partial:
            return .partial
        case .failed:
            return .failed
        case .placeholder, .notStarted:
            return .notStarted
        }
    }

    var displaySourceSnippet: String? {
        dominantSourceSnippet
            ?? pages.first(where: { ($0.snippet ?? "").isEmpty == false })?.snippet
            ?? extractedText
    }
}
