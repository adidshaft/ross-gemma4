import Foundation

let AlphaCurrentPersistedStateSchemaVersion = 2

enum AlphaOnboardingStage: String, Codable, Hashable, Sendable {
    case onboarding
    // Kept so older saved state can migrate into the simplified onboarding flow.
    case privateAIPack
    case completed
}

enum AlphaAppTab: String, Codable, Hashable, CaseIterable, Sendable {
    case today
    case matters
    case files
    case work
    case settings
    case home

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? Self.today.rawValue
        switch rawValue {
        case Self.today.rawValue:
            self = .today
        case Self.home.rawValue:
            self = .home
        case Self.matters.rawValue:
            self = .matters
        case Self.files.rawValue:
            self = .files
        case Self.work.rawValue:
            self = .work
        case Self.settings.rawValue:
            self = .settings
        default:
            self = .today
        }
    }

    var title: String {
        switch self {
        case .today, .home:
            rossLocalized("tab_today")
        case .matters:
            rossLocalized("tab_matters")
        case .files:
            rossLocalized("tab_files")
        case .work:
            rossLocalized("tab_work")
        case .settings:
            rossLocalized("tab_settings")
        }
    }

    var systemImage: String {
        switch self {
        case .today, .home:
            "sun.max"
        case .matters:
            "folder"
        case .files:
            "doc.text"
        case .work:
            "tray.full"
        case .settings:
            "slider.horizontal.3"
        }
    }
}

enum AlphaAppearanceMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case auto
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            rossLocalized("appearance_auto")
        case .dark:
            rossLocalized("appearance_dark")
        case .light:
            rossLocalized("appearance_light")
        }
    }

    var detail: String {
        switch self {
        case .auto:
            rossLocalized("appearance_auto_detail")
        case .dark:
            rossLocalized("appearance_dark_detail")
        case .light:
            rossLocalized("appearance_light_detail")
        }
    }
}

enum AlphaCapabilityTier: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case flash = "flash"
    case quickStart = "quick_start"
    case caseAssociate = "case_associate"
    case seniorDraftingSupport = "senior_drafting_support"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash:
            "Flash"
        case .quickStart:
            "Small"
        case .caseAssociate:
            "Standard"
        case .seniorDraftingSupport:
            "Full"
        }
    }

    var setupTitle: String {
        switch self {
        case .flash:
            "Flash - simplest, ultra-fast"
        case .quickStart:
            "Small - short orders only"
        case .caseAssociate:
            "Standard - most matters"
        case .seniorDraftingSupport:
            "Full - long bundles and drafting"
        }
    }

    var summary: String {
        switch self {
        case .flash:
            "Lighter footprint for immediate, fast answers and simple checklists."
        case .quickStart:
            "Lighter setup for short orders, quick summaries, and simple private Ask Ross actions."
        case .caseAssociate:
            "Recommended for everyday matters, document review, chronology work, and answers from your files."
        case .seniorDraftingSupport:
            "Best for longer bundles, deeper review, and heavier drafting on this phone."
        }
    }

    var storageNote: String {
        switch self {
        case .flash:
            "Smallest footprint"
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
        case .flash:
            "3.0 GB"
        case .quickStart:
            "3.5 GB"
        case .caseAssociate:
            "5.4 GB"
        case .seniorDraftingSupport:
            "17.0 GB"
        }
    }

    var installedSizeLabel: String {
        switch self {
        case .flash:
            "3.0 GB"
        case .quickStart:
            "3.5 GB"
        case .caseAssociate:
            "5.4 GB"
        case .seniorDraftingSupport:
            "17.0 GB"
        }
    }

    var bestFor: String {
        switch self {
        case .flash:
            "Ultra-fast short document Q&A."
        case .quickStart:
            "Fast intake, smaller devices, and short document Q&A after the assistant is installed."
        case .caseAssociate:
            "Most advocates who need document review, next dates, chronologies, notes, and answers from your files on-device."
        case .seniorDraftingSupport:
            "Longer bundles, deeper review, hearing preparation, and more detailed drafting support."
        }
    }

    var compactSetupSummary: String {
        switch self {
        case .flash:
            "Simple answers"
        case .quickStart:
            "Short orders"
        case .caseAssociate:
            "Most matters"
        case .seniorDraftingSupport:
            "Long bundles"
        }
    }

    var setupWarning: String {
        setupWarning(languageCode: rossSelectedLanguageCode())
    }

    func setupWarning(languageCode: String) -> String {
        switch self {
        case .flash, .quickStart:
            String(
                format: rossLocalized("setup_warning_wifi", languageCode: languageCode),
                downloadSizeLabel
            )
        case .caseAssociate:
            String(
                format: rossLocalized("setup_warning_storage", languageCode: languageCode),
                downloadSizeLabel
            )
        case .seniorDraftingSupport:
            String(
                format: rossLocalized("setup_warning_large", languageCode: languageCode),
                downloadSizeLabel
            )
        }
    }

    var setupTimeLabel: String {
        switch self {
        case .flash:
            "about 2 min"
        case .quickStart:
            "about 2 min"
        case .caseAssociate:
            "about 4 min"
        case .seniorDraftingSupport:
            "about 7 min"
        }
    }

    var extractionQuality: String {
        switch self {
        case .flash:
            "Basic"
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
        case .flash:
            0
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
        AlphaPackOffer(tier: .flash, runtimeLabel: "Flash", supportsBilingualDrafting: false),
        AlphaPackOffer(tier: .quickStart, runtimeLabel: "Basic", supportsBilingualDrafting: false),
        AlphaPackOffer(tier: .caseAssociate, runtimeLabel: "Standard", supportsBilingualDrafting: true),
        AlphaPackOffer(tier: .seniorDraftingSupport, runtimeLabel: "Advanced", supportsBilingualDrafting: true)
    ]
}

enum AlphaCaseStage: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case intake
    case pleadings
    case evidence
    case arguments
    case reserved
    case disposed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intake:
            "Filing"
        case .pleadings:
            "Pleadings"
        case .evidence:
            "Evidence"
        case .arguments:
            "Arguments"
        case .reserved:
            "Judgment Reserved"
        case .disposed:
            "Disposed"
        }
    }
}

enum AlphaMatterTint: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case indigo
    case amber
    case emerald
    case rose
    case slate

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum AlphaTaskPriority: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case normal
    case high

    var title: String {
        switch self {
        case .low:
            "Low"
        case .normal:
            "Normal"
        case .high:
            "High"
        }
    }
}

enum AlphaTaskStatus: String, Codable, Hashable, Sendable {
    case open
    case done
}

enum AlphaTaskSource: String, Codable, Hashable, Sendable {
    case manual
    case extraction
    case system
}

enum AlphaMatterDateKind: String, Codable, CaseIterable, Hashable, Sendable {
    case hearing
    case filingDeadline = "filing_deadline"
    case complianceDate = "compliance_date"
    case clientFollowUp = "client_follow_up"

    var title: String {
        switch self {
        case .hearing:
            "Next hearing"
        case .filingDeadline:
            "Filing deadline"
        case .complianceDate:
            "Compliance date"
        case .clientFollowUp:
            "Client follow-up"
        }
    }
}

enum AlphaMatterDateStatus: String, Codable, Hashable, Sendable {
    case scheduled
    case done
    case cancelled
}

struct AlphaMatterDate: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID
    var title: String
    var kind: AlphaMatterDateKind
    var date: Date
    var status: AlphaMatterDateStatus
    var notes: String?
    var sourceRef: AlphaSourceRef?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID,
        title: String,
        kind: AlphaMatterDateKind,
        date: Date,
        status: AlphaMatterDateStatus = .scheduled,
        notes: String? = nil,
        sourceRef: AlphaSourceRef? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.title = title
        self.kind = kind
        self.date = date
        self.status = status
        self.notes = notes
        self.sourceRef = sourceRef
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AlphaTaskItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var caseId: UUID?
    var title: String
    var notes: String?
    var dueDate: Date?
    var priority: AlphaTaskPriority
    var status: AlphaTaskStatus
    var source: AlphaTaskSource
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        caseId: UUID? = nil,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: AlphaTaskPriority = .normal,
        status: AlphaTaskStatus = .open,
        source: AlphaTaskSource = .manual,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.caseId = caseId
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
            rossLocalized("document_status_not_ready")
        case .indexed:
            rossLocalized("document_status_ready")
        case .placeholder:
            rossLocalized("document_status_reading_file")
        case .nativeText:
            rossLocalized("document_status_ready")
        case .ocrComplete:
            rossLocalized("document_status_ready")
        case .partial:
            rossLocalized("document_status_partial")
        case .failed:
            rossLocalized("document_status_could_not_read")
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
            rossLocalized("document_status_not_ready")
        case .extracting:
            rossLocalized("document_status_reading_file")
        case .indexed:
            rossLocalized("document_status_ready")
        case .partial:
            rossLocalized("document_status_partial")
        case .failed:
            rossLocalized("document_status_could_not_read")
        }
    }
}

enum AlphaDocumentProcessingState: String, Codable, Hashable, Sendable {
    case imported
    case readingText
    case reviewingFindings
    case ready
    case needsConfirmation
    case failed

    var title: String {
        switch self {
        case .imported:
            rossLocalized("document_status_imported")
        case .readingText:
            rossLocalized("document_status_reading")
        case .reviewingFindings:
            rossLocalized("review")
        case .ready:
            rossLocalized("document_status_ready")
        case .needsConfirmation:
            rossLocalized("needs_review")
        case .failed:
            rossLocalized("document_status_failed")
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

enum AlphaSourceCategory: String, Codable, Hashable, Sendable {
    case documentSource = "document_source"
    case matterDetail = "matter_detail"
    case rossSuggestion = "ross_suggestion"
    case userConfirmedFact = "user_confirmed_fact"
    case publicLawSource = "public_law_source"
}

struct AlphaSourceRef: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let caseId: UUID
    let documentId: UUID
    var documentTitle: String
    let pageNumber: Int
    let paragraphRange: String?
    let textSnippet: String?
    let ocrConfidence: Double?
    var highlightText: String?
    var highlightRects: [AlphaNormalizedRect]?
    var sourceCategory: AlphaSourceCategory?

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
        highlightRects: [AlphaNormalizedRect]? = nil,
        sourceCategory: AlphaSourceCategory = .documentSource
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
        self.sourceCategory = sourceCategory
    }

    var effectiveSourceCategory: AlphaSourceCategory {
        sourceCategory ?? .documentSource
    }

    var label: String {
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let noLinkedSource = rossLocalized("no_linked_source_short")
        if title.localizedCaseInsensitiveContains("Matter memory") {
            return "\(rossLocalized("matter_details")) · \(noLinkedSource)"
        }
        switch effectiveSourceCategory {
        case .documentSource:
            guard !title.isEmpty else { return "\(rossLocalized("document_source")) · \(noLinkedSource)" }
            return pageNumber > 0 ? "\(title) · p. \(pageNumber)" : "\(title) · \(noLinkedSource)"
        case .matterDetail:
            let field = paragraphRange?.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(rossLocalized("matter_details")) · \((field?.isEmpty == false ? field : noLinkedSource) ?? noLinkedSource)"
        case .rossSuggestion:
            return "\(rossLocalized("suggested_by_ross")) · \(rossLocalized("not_confirmed"))"
        case .userConfirmedFact:
            let confirmedAt = paragraphRange?.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(rossLocalized("confirmed_by_advocate")) · \((confirmedAt?.isEmpty == false ? confirmedAt : noLinkedSource) ?? noLinkedSource)"
        case .publicLawSource:
            return "Legal Search · \(!title.isEmpty ? title : noLinkedSource)"
        }
    }

    var detail: String {
        let snippet = textSnippet?.trimmingCharacters(in: .whitespacesAndNewlines)
        return snippet?.isEmpty == false ? snippet! : rossLocalized("no_linked_source_yet")
    }
}

enum AlphaExtractionMode: String, Codable, Hashable, Sendable {
    case basic
    case flash = "flash"
    case quickStart = "quick_start"
    case caseAssociate = "case_associate"
    case seniorDraftingSupport = "senior_drafting_support"

    static func fromTier(_ tier: AlphaCapabilityTier?) -> AlphaExtractionMode {
        switch tier {
        case .none:
            .basic
        case .some(.flash):
            .flash
        case .some(.quickStart):
            .quickStart
        case .some(.caseAssociate):
            .caseAssociate
        case .some(.seniorDraftingSupport):
            .seniorDraftingSupport
        }
    }

    static func fromInstalledPack(_ pack: AlphaInstalledModelPack?) -> AlphaExtractionMode {
        fromTier(pack?.tier)
    }

    var qualityLabel: String {
        switch self {
        case .basic, .flash:
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
    case bengali
    case tamil
    case telugu
    case mixed
    case unknown
}

enum AlphaDocumentScript: String, Codable, Hashable, Sendable {
    case latin
    case devanagari
    case bengali
    case tamil
    case telugu
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
    case clientNote = "client_note"
    case courtFiling = "court_filing"
    case legalResearch = "legal_research"
    case nonLegalDocument = "non_legal_document"
    case fictionalGameMaterial = "fictional_game_material"
    case unknown
    case correspondence
    case misc

    var title: String {
        switch self {
        case .pleading:
            "Pleading"
        case .order:
            "Order"
        case .judgment:
            "Judgment"
        case .affidavit:
            "Affidavit"
        case .notice:
            "Notice"
        case .evidence:
            "Evidence"
        case .clientNote:
            "Client note"
        case .courtFiling:
            "Court filing"
        case .legalResearch:
            "Legal research"
        case .nonLegalDocument:
            "Non-legal document"
        case .fictionalGameMaterial:
            "Fictional/game material"
        case .unknown, .misc:
            "Unknown"
        case .correspondence:
            "Client note"
        }
    }

    var blocksAutomaticLegalFactSaving: Bool {
        switch self {
        case .nonLegalDocument, .fictionalGameMaterial, .unknown, .misc:
            true
        default:
            false
        }
    }

    static var reviewMenuTypes: [AlphaLegalDocumentType] {
        [
            .order,
            .pleading,
            .notice,
            .affidavit,
            .evidence,
            .clientNote,
            .courtFiling,
            .legalResearch,
            .nonLegalDocument,
            .fictionalGameMaterial,
            .unknown
        ]
    }
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
        if needsReview {
            return "Please confirm"
        }
        if confidence < 0.84 {
            return "Low confidence"
        }
        return "Verified"
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
    case documentClassificationNeedsReview = "document_classification_needs_review"
    case dateConflict = "date_conflict"
    case partyConflict = "party_conflict"
    case caseNumberConflict = "case_number_conflict"
    case courtConflict = "court_conflict"
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
    var fieldType: AlphaExtractedLegalFieldType?
    var matterValue: String?
    var fileValue: String?

    init(
        id: UUID = UUID(),
        caseId: UUID,
        documentId: UUID,
        kind: AlphaExtractionFindingKind,
        message: String,
        sourceRefs: [AlphaSourceRef],
        severity: AlphaExtractionFindingSeverity,
        resolved: Bool = false,
        fieldType: AlphaExtractedLegalFieldType? = nil,
        matterValue: String? = nil,
        fileValue: String? = nil
    ) {
        self.id = id
        self.caseId = caseId
        self.documentId = documentId
        self.kind = kind
        self.message = message
        self.sourceRefs = sourceRefs
        self.severity = severity
        self.resolved = resolved
        self.fieldType = fieldType
        self.matterValue = matterValue
        self.fileValue = fileValue
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
    var advocateNote: String?
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
        advocateNote: String? = nil,
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
        self.advocateNote = advocateNote
        self.languageProfile = languageProfile
        self.classification = classification
        self.extractedFields = extractedFields
        self.extractionRuns = extractionRuns
        self.extractionFindings = extractionFindings
        self.modelInvocations = modelInvocations
    }
}

enum AlphaChatTurnKind: String, Codable, Hashable, Sendable {
    case userAsk = "user_ask"
    case matterUpdate = "matter_update"
}

struct AlphaChatTurn: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: AlphaChatTurnKind
    var askedAt: Date
    var question: String
    var answerTitle: String
    var answerSections: [String]
    var sourceRefs: [AlphaSourceRef]
    var selectedDocumentTitles: [String]?
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult]
    var statusNote: String?
    var needsReviewWarning: String?
    var modelInvocation: AlphaLocalModelInvocation?

    init(
        id: UUID = UUID(),
        kind: AlphaChatTurnKind = .userAsk,
        askedAt: Date = .now,
        question: String,
        answerTitle: String,
        answerSections: [String],
        sourceRefs: [AlphaSourceRef],
        selectedDocumentTitles: [String]? = nil,
        publicLawPreview: AlphaPublicLawPreview? = nil,
        publicLawResults: [AlphaPublicLawResult] = [],
        statusNote: String? = nil,
        needsReviewWarning: String? = nil,
        modelInvocation: AlphaLocalModelInvocation? = nil
    ) {
        self.id = id
        self.kind = kind
        self.askedAt = askedAt
        self.question = question
        self.answerTitle = answerTitle
        self.answerSections = answerSections
        self.sourceRefs = sourceRefs
        self.selectedDocumentTitles = selectedDocumentTitles
        self.publicLawPreview = publicLawPreview
        self.publicLawResults = publicLawResults
        self.statusNote = statusNote
        self.needsReviewWarning = needsReviewWarning
        self.modelInvocation = modelInvocation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case askedAt
        case question
        case answerTitle
        case answerSections
        case sourceRefs
        case selectedDocumentTitles
        case publicLawPreview
        case publicLawResults
        case statusNote
        case needsReviewWarning
        case modelInvocation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(AlphaChatTurnKind.self, forKey: .kind) ?? .userAsk
        askedAt = try container.decodeIfPresent(Date.self, forKey: .askedAt) ?? .now
        question = try container.decode(String.self, forKey: .question)
        answerTitle = try container.decode(String.self, forKey: .answerTitle)
        answerSections = try container.decode([String].self, forKey: .answerSections)
        sourceRefs = try container.decodeIfPresent([AlphaSourceRef].self, forKey: .sourceRefs) ?? []
        selectedDocumentTitles = try container.decodeIfPresent([String].self, forKey: .selectedDocumentTitles)
        publicLawPreview = try container.decodeIfPresent(AlphaPublicLawPreview.self, forKey: .publicLawPreview)
        publicLawResults = try container.decodeIfPresent([AlphaPublicLawResult].self, forKey: .publicLawResults) ?? []
        statusNote = try container.decodeIfPresent(String.self, forKey: .statusNote)
        needsReviewWarning = try container.decodeIfPresent(String.self, forKey: .needsReviewWarning)
        modelInvocation = try container.decodeIfPresent(AlphaLocalModelInvocation.self, forKey: .modelInvocation)
    }
}

struct AlphaChatSession: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var contextDocumentIDs: [UUID]
    var turns: [AlphaChatTurn]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        contextDocumentIDs: [UUID] = [],
        turns: [AlphaChatTurn] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contextDocumentIDs = contextDocumentIDs
        self.turns = turns
    }

    init(legacyTurns: [AlphaChatTurn]) {
        let sortedTurns = legacyTurns.sorted { $0.askedAt > $1.askedAt }
        self.init(
            createdAt: sortedTurns.last?.askedAt ?? .now,
            updatedAt: sortedTurns.first?.askedAt ?? .now,
            turns: sortedTurns
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case updatedAt
        case contextDocumentIDs
        case turns
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTurns = try container.decodeIfPresent([AlphaChatTurn].self, forKey: .turns) ?? []
        let decodedCreatedAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? decodedTurns.last?.askedAt ?? .now
        let decodedUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? decodedTurns.first?.askedAt ?? decodedCreatedAt

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = decodedCreatedAt
        updatedAt = decodedUpdatedAt
        contextDocumentIDs = try container.decodeIfPresent([UUID].self, forKey: .contextDocumentIDs) ?? []
        turns = decodedTurns
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(contextDocumentIDs, forKey: .contextDocumentIDs)
        try container.encode(turns, forKey: .turns)
    }
}

struct AlphaCaseMatter: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var forum: String
    var caseNumber: String?
    var partiesSummary: String?
    var judgeName: String?
    var advocateName: String?
    var stage: AlphaCaseStage
    var folderTint: AlphaMatterTint
    var nextHearing: Date?
    var dates: [AlphaMatterDate]
    var localNotice: String
    var notes: String?
    var summary: String
    var issueHighlights: [String]
    var evidenceNotes: [String]
    var draftTasks: [String]
    var documents: [AlphaCaseDocument]
    var sourceRefs: [AlphaSourceRef]
    var chatSessions: [AlphaChatSession]
    var activeChatSessionID: UUID?
    var advocateCorrections: [AlphaAdvocateCorrection]
    var caseMemoryUpdates: [AlphaCaseMemoryUpdate]
    var updatedAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        forum: String,
        caseNumber: String? = nil,
        partiesSummary: String? = nil,
        judgeName: String? = nil,
        advocateName: String? = nil,
        stage: AlphaCaseStage,
        folderTint: AlphaMatterTint = .indigo,
        nextHearing: Date? = nil,
        dates: [AlphaMatterDate] = [],
        localNotice: String = "Case files stay on this device",
        notes: String? = nil,
        summary: String,
        issueHighlights: [String],
        evidenceNotes: [String],
        draftTasks: [String],
        documents: [AlphaCaseDocument],
        sourceRefs: [AlphaSourceRef],
        chatSessions: [AlphaChatSession] = [],
        activeChatSessionID: UUID? = nil,
        advocateCorrections: [AlphaAdvocateCorrection] = [],
        caseMemoryUpdates: [AlphaCaseMemoryUpdate] = [],
        updatedAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.forum = forum
        self.caseNumber = caseNumber
        self.partiesSummary = partiesSummary
        self.judgeName = judgeName
        self.advocateName = advocateName
        self.stage = stage
        self.folderTint = folderTint
        self.nextHearing = nextHearing
        self.dates = dates.sorted { $0.date < $1.date }
        self.localNotice = localNotice
        self.notes = notes
        self.summary = summary
        self.issueHighlights = issueHighlights
        self.evidenceNotes = evidenceNotes
        self.draftTasks = draftTasks
        self.documents = documents
        self.sourceRefs = sourceRefs
        self.chatSessions = chatSessions.sorted { $0.updatedAt > $1.updatedAt }
        self.activeChatSessionID = activeChatSessionID ?? self.chatSessions.first?.id
        self.advocateCorrections = advocateCorrections
        self.caseMemoryUpdates = caseMemoryUpdates
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case forum
        case caseNumber
        case partiesSummary
        case judgeName
        case advocateName
        case stage
        case folderTint
        case nextHearing
        case dates
        case localNotice
        case notes
        case summary
        case issueHighlights
        case evidenceNotes
        case draftTasks
        case documents
        case sourceRefs
        case chatSessions
        case activeChatSessionID
        case chatTurns
        case advocateCorrections
        case caseMemoryUpdates
        case updatedAt
        case archivedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        forum = try container.decode(String.self, forKey: .forum)
        caseNumber = try container.decodeIfPresent(String.self, forKey: .caseNumber)
        partiesSummary = try container.decodeIfPresent(String.self, forKey: .partiesSummary)
        judgeName = try container.decodeIfPresent(String.self, forKey: .judgeName)
        advocateName = try container.decodeIfPresent(String.self, forKey: .advocateName)
        stage = try container.decode(AlphaCaseStage.self, forKey: .stage)
        folderTint = try container.decodeIfPresent(AlphaMatterTint.self, forKey: .folderTint) ?? .indigo
        nextHearing = try container.decodeIfPresent(Date.self, forKey: .nextHearing)
        dates = (try container.decodeIfPresent([AlphaMatterDate].self, forKey: .dates) ?? []).sorted { $0.date < $1.date }
        localNotice = try container.decodeIfPresent(String.self, forKey: .localNotice) ?? "Case files stay on this device"
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        summary = try container.decode(String.self, forKey: .summary)
        issueHighlights = try container.decodeIfPresent([String].self, forKey: .issueHighlights) ?? []
        evidenceNotes = try container.decodeIfPresent([String].self, forKey: .evidenceNotes) ?? []
        draftTasks = try container.decodeIfPresent([String].self, forKey: .draftTasks) ?? []
        documents = try container.decodeIfPresent([AlphaCaseDocument].self, forKey: .documents) ?? []
        sourceRefs = try container.decodeIfPresent([AlphaSourceRef].self, forKey: .sourceRefs) ?? []

        let decodedSessions = try container.decodeIfPresent([AlphaChatSession].self, forKey: .chatSessions) ?? []
        let legacyTurns = try container.decodeIfPresent([AlphaChatTurn].self, forKey: .chatTurns) ?? []
        if decodedSessions.isEmpty, !legacyTurns.isEmpty {
            chatSessions = [AlphaChatSession(legacyTurns: legacyTurns)]
        } else {
            chatSessions = decodedSessions.sorted { $0.updatedAt > $1.updatedAt }
        }
        let decodedActiveSessionID = try container.decodeIfPresent(UUID.self, forKey: .activeChatSessionID)
        activeChatSessionID = chatSessions.contains(where: { $0.id == decodedActiveSessionID }) ? decodedActiveSessionID : chatSessions.first?.id

        advocateCorrections = try container.decodeIfPresent([AlphaAdvocateCorrection].self, forKey: .advocateCorrections) ?? []
        caseMemoryUpdates = try container.decodeIfPresent([AlphaCaseMemoryUpdate].self, forKey: .caseMemoryUpdates) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(forum, forKey: .forum)
        try container.encodeIfPresent(caseNumber, forKey: .caseNumber)
        try container.encodeIfPresent(partiesSummary, forKey: .partiesSummary)
        try container.encodeIfPresent(judgeName, forKey: .judgeName)
        try container.encodeIfPresent(advocateName, forKey: .advocateName)
        try container.encode(stage, forKey: .stage)
        try container.encode(folderTint, forKey: .folderTint)
        try container.encodeIfPresent(nextHearing, forKey: .nextHearing)
        try container.encode(dates.sorted { $0.date < $1.date }, forKey: .dates)
        try container.encode(localNotice, forKey: .localNotice)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(summary, forKey: .summary)
        try container.encode(issueHighlights, forKey: .issueHighlights)
        try container.encode(evidenceNotes, forKey: .evidenceNotes)
        try container.encode(draftTasks, forKey: .draftTasks)
        try container.encode(documents, forKey: .documents)
        try container.encode(sourceRefs, forKey: .sourceRefs)
        try container.encode(chatSessions, forKey: .chatSessions)
        try container.encodeIfPresent(activeChatSessionID, forKey: .activeChatSessionID)
        try container.encode(advocateCorrections, forKey: .advocateCorrections)
        try container.encode(caseMemoryUpdates, forKey: .caseMemoryUpdates)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
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
    var resumeDataRelativePath: String?
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
        artifactKind: String = "local_model_artifact",
        runtimeMode: AlphaPackRuntimeMode = .unavailable,
        developmentOnly: Bool = false,
        minimumAppVersion: String = "0.1.0",
        failureReason: String? = nil,
        resumeDataRelativePath: String? = nil,
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
        self.resumeDataRelativePath = resumeDataRelativePath
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
        case resumeDataRelativePath
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
        artifactKind = try container.decodeIfPresent(String.self, forKey: .artifactKind) ?? "local_model_artifact"
        runtimeMode = try container.decodeIfPresent(AlphaPackRuntimeMode.self, forKey: .runtimeMode) ?? .unavailable
        developmentOnly = try container.decodeIfPresent(Bool.self, forKey: .developmentOnly) ?? false
        minimumAppVersion = try container.decodeIfPresent(String.self, forKey: .minimumAppVersion) ?? "0.1.0"
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        resumeDataRelativePath = try container.decodeIfPresent(String.self, forKey: .resumeDataRelativePath)
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
        artifactKind: String = "local_model_artifact",
        runtimeMode: AlphaPackRuntimeMode = .unavailable,
        developmentOnly: Bool = false,
        checksumVerified: Bool = false,
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
        artifactKind = try container.decodeIfPresent(String.self, forKey: .artifactKind) ?? "local_model_artifact"
        runtimeMode = try container.decodeIfPresent(AlphaPackRuntimeMode.self, forKey: .runtimeMode) ?? .unavailable
        developmentOnly = try container.decodeIfPresent(Bool.self, forKey: .developmentOnly) ?? false
        checksumVerified = try container.decodeIfPresent(Bool.self, forKey: .checksumVerified) ?? false
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

struct AlphaModelUpdateCandidate: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var tier: AlphaCapabilityTier
    var installedPackId: String
    var availablePackId: String
    var availableSizeBytes: Int64
    var requiresWifi: Bool
    var checkedAt: Date
    var dismissedAt: Date?

    init(
        id: UUID = UUID(),
        tier: AlphaCapabilityTier,
        installedPackId: String,
        availablePackId: String,
        availableSizeBytes: Int64,
        requiresWifi: Bool = true,
        checkedAt: Date = .now,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.tier = tier
        self.installedPackId = installedPackId
        self.availablePackId = availablePackId
        self.availableSizeBytes = availableSizeBytes
        self.requiresWifi = requiresWifi
        self.checkedAt = checkedAt
        self.dismissedAt = dismissedAt
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

enum AlphaPreparedWorkType: String, Codable, CaseIterable, Hashable, Sendable {
    case documentReviewed = "document_reviewed"
    case nextDateFound = "next_date_found"
    case suggestedTasks = "suggested_tasks"
    case chronologyReady = "chronology_ready"
    case caseNoteReady = "case_note_ready"
    case orderSummaryReady = "order_summary_ready"
    case hearingNoteReady = "hearing_note_ready"
    case publicLawQueryAwaitingApproval = "public_law_query_awaiting_approval"
    case missingFactsFound = "missing_facts_found"
    case evidenceSummaryNeedsReview = "evidence_summary_needs_review"
    case matterNeedsAttention = "matter_needs_attention"

    var title: String {
        rossLocalized("prepared_work_type_\(rawValue)")
    }
}

enum AlphaPreparedWorkStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case new
    case reviewed
    case accepted
    case dismissed

    var title: String {
        rossLocalized("prepared_work_status_\(rawValue)")
    }
}

enum AlphaPreparedWorkBadge: String, Codable, CaseIterable, Hashable, Sendable {
    case sourceBacked = "source_backed"
    case preparedLocally = "prepared_locally"
    case needsReview = "needs_review"
    case approvalRequired = "approval_required"

    var title: String {
        switch self {
        case .sourceBacked: rossLocalized("source_backed")
        case .preparedLocally: rossLocalized("prepared_locally")
        case .needsReview: rossLocalized("needs_review")
        case .approvalRequired: rossLocalized("approval_required")
        }
    }
}

struct AlphaPreparedWorkItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var stableKey: String
    var caseId: UUID?
    var type: AlphaPreparedWorkType
    var matterName: String
    var title: String
    var summary: String
    var badge: AlphaPreparedWorkBadge
    var status: AlphaPreparedWorkStatus
    var sourceRefs: [AlphaSourceRef]
    var sourceFingerprint: String
    var primaryAction: String
    var secondaryActions: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        stableKey: String,
        caseId: UUID?,
        type: AlphaPreparedWorkType,
        matterName: String,
        title: String,
        summary: String,
        badge: AlphaPreparedWorkBadge,
        status: AlphaPreparedWorkStatus = .new,
        sourceRefs: [AlphaSourceRef] = [],
        sourceFingerprint: String,
        primaryAction: String,
        secondaryActions: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.stableKey = stableKey
        self.caseId = caseId
        self.type = type
        self.matterName = matterName
        self.title = title
        self.summary = summary
        self.badge = badge
        self.status = status
        self.sourceRefs = sourceRefs
        self.sourceFingerprint = sourceFingerprint
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AlphaRoutineKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case morningBrief = "morning_brief"
    case afterDocumentImport = "after_document_import"
    case beforeHearing = "before_hearing"
    case missingFactsScan = "missing_facts_scan"
    case draftRefresh = "draft_refresh"
    case publicLawPreview = "public_law_preview"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningBrief: "Morning brief"
        case .afterDocumentImport: "After document import"
        case .beforeHearing: "Before hearing"
        case .missingFactsScan: "Missing facts scan"
        case .draftRefresh: "Draft refresh"
        case .publicLawPreview: "Public-law search preview"
        }
    }
}

struct AlphaRoutineRun: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: AlphaRoutineKind
    var caseId: UUID?
    var ranAt: Date
    var preparedItemIDs: [UUID]
    var summary: String

    init(id: UUID = UUID(), kind: AlphaRoutineKind, caseId: UUID? = nil, ranAt: Date = .now, preparedItemIDs: [UUID] = [], summary: String) {
        self.id = id
        self.kind = kind
        self.caseId = caseId
        self.ranAt = ranAt
        self.preparedItemIDs = preparedItemIDs
        self.summary = summary
    }
}

struct AlphaRoutineSettings: Codable, Hashable, Sendable {
    var morningBriefEnabled: Bool
    var afterDocumentImportEnabled: Bool
    var beforeHearingEnabled: Bool
    var missingFactsScanEnabled: Bool
    var draftRefreshEnabled: Bool
    var requirePublicLawApproval: Bool

    static let `default` = AlphaRoutineSettings(
        morningBriefEnabled: true,
        afterDocumentImportEnabled: true,
        beforeHearingEnabled: true,
        missingFactsScanEnabled: true,
        draftRefreshEnabled: true,
        requirePublicLawApproval: true
    )
}

struct AlphaSettings: Codable, Hashable, Sendable {
    var activeTier: AlphaCapabilityTier?
    var appearanceMode: AlphaAppearanceMode
    var wifiOnlyDownloads: Bool
    var allowMobileDataForLargePacks: Bool
    var requirePublicLawApproval: Bool
    var instantModeEnabled: Bool
    var privateByDefault: Bool
    var deviceCacheEnabled: Bool
    var backgroundWorkEnabled: Bool
    var autoModelUpdateChecksEnabled: Bool
    var keepModelFilesOnWorkspaceReset: Bool
    var llamaSamplerSettings: AlphaLlamaSamplerSettings

    static let `default` = AlphaSettings(
        activeTier: nil,
        appearanceMode: .auto,
        wifiOnlyDownloads: true,
        allowMobileDataForLargePacks: false,
        requirePublicLawApproval: false,
        instantModeEnabled: true,
        privateByDefault: true,
        deviceCacheEnabled: true,
        backgroundWorkEnabled: true,
        autoModelUpdateChecksEnabled: true,
        keepModelFilesOnWorkspaceReset: true,
        llamaSamplerSettings: .legalQA
    )

    private enum CodingKeys: String, CodingKey {
        case activeTier
        case appearanceMode
        case wifiOnlyDownloads
        case allowMobileDataForLargePacks
        case requirePublicLawApproval
        case instantModeEnabled
        case privateByDefault
        case deviceCacheEnabled
        case backgroundWorkEnabled
        case autoModelUpdateChecksEnabled
        case keepModelFilesOnWorkspaceReset
        case llamaSamplerSettings
    }

    init(
        activeTier: AlphaCapabilityTier?,
        appearanceMode: AlphaAppearanceMode,
        wifiOnlyDownloads: Bool,
        allowMobileDataForLargePacks: Bool,
        requirePublicLawApproval: Bool,
        instantModeEnabled: Bool,
        privateByDefault: Bool,
        deviceCacheEnabled: Bool,
        backgroundWorkEnabled: Bool,
        autoModelUpdateChecksEnabled: Bool,
        keepModelFilesOnWorkspaceReset: Bool,
        llamaSamplerSettings: AlphaLlamaSamplerSettings = .legalQA
    ) {
        self.activeTier = activeTier
        self.appearanceMode = appearanceMode
        self.wifiOnlyDownloads = wifiOnlyDownloads
        self.allowMobileDataForLargePacks = allowMobileDataForLargePacks
        self.requirePublicLawApproval = requirePublicLawApproval
        self.instantModeEnabled = instantModeEnabled
        self.privateByDefault = privateByDefault
        self.deviceCacheEnabled = deviceCacheEnabled
        self.backgroundWorkEnabled = backgroundWorkEnabled
        self.autoModelUpdateChecksEnabled = autoModelUpdateChecksEnabled
        self.keepModelFilesOnWorkspaceReset = keepModelFilesOnWorkspaceReset
        self.llamaSamplerSettings = llamaSamplerSettings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeTier = try container.decodeIfPresent(AlphaCapabilityTier.self, forKey: .activeTier)
        appearanceMode = try container.decodeIfPresent(AlphaAppearanceMode.self, forKey: .appearanceMode) ?? .auto
        wifiOnlyDownloads = try container.decodeIfPresent(Bool.self, forKey: .wifiOnlyDownloads) ?? true
        allowMobileDataForLargePacks = try container.decodeIfPresent(Bool.self, forKey: .allowMobileDataForLargePacks) ?? false
        requirePublicLawApproval = try container.decodeIfPresent(Bool.self, forKey: .requirePublicLawApproval) ?? true
        instantModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .instantModeEnabled) ?? true
        privateByDefault = try container.decodeIfPresent(Bool.self, forKey: .privateByDefault) ?? true
        deviceCacheEnabled = try container.decodeIfPresent(Bool.self, forKey: .deviceCacheEnabled) ?? true
        backgroundWorkEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundWorkEnabled) ?? true
        autoModelUpdateChecksEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoModelUpdateChecksEnabled) ?? true
        keepModelFilesOnWorkspaceReset = try container.decodeIfPresent(Bool.self, forKey: .keepModelFilesOnWorkspaceReset) ?? true
        llamaSamplerSettings = try container.decodeIfPresent(AlphaLlamaSamplerSettings.self, forKey: .llamaSamplerSettings) ?? .legalQA
    }
}

struct AlphaLlamaSamplerSettings: Codable, Hashable, Sendable {
    var temperature: Double
    var topP: Double
    var topK: Int
    var repeatPenalty: Double
    var seed: UInt32

    static let legalQA = AlphaLlamaSamplerSettings(
        temperature: 0.25,
        topP: 0.90,
        topK: 40,
        repeatPenalty: 1.10,
        seed: 1234
    )
}

struct AlphaAssistantStorageBreakdown: Codable, Hashable, Sendable {
    var modelPackBytes: Int64
    var resumeBytes: Int64
    var pendingDownloadBytes: Int64
    var deviceCacheBytes: Int64

    var totalBytes: Int64 {
        modelPackBytes + resumeBytes + pendingDownloadBytes + deviceCacheBytes
    }
}

struct AlphaPublicLawPreview: Codable, Hashable, Sendable {
    var query: String
    var removed: [String]
    var confirmationNote: String
}

enum AlphaAssistantDeviceSupportState: String, Codable, Hashable, Sendable {
    case supported
    case autoDowngraded = "auto_downgraded"
    case needsStorage = "needs_storage"
    case needsNewerOS = "needs_newer_os"
    case unavailable
}

enum AlphaAssistantInstallState: String, Codable, Hashable, Sendable {
    case notStarted = "not_started"
    case queued
    case downloading
    case installed
    case failed
}

struct AlphaAssistantRuntimeDecision: Codable, Hashable, Sendable {
    var selectedTier: AlphaCapabilityTier
    var recommendedTier: AlphaCapabilityTier
    var effectiveTier: AlphaCapabilityTier
    var displayName: String
    var deviceSupportState: AlphaAssistantDeviceSupportState
    var modelPackId: String
    var installState: AlphaAssistantInstallState
    var reason: String
}

struct AlphaPersistedState: Codable, Hashable, Sendable {
    var schemaVersion: Int? = AlphaCurrentPersistedStateSchemaVersion
    var onboardingStage: AlphaOnboardingStage
    var selectedTab: AlphaAppTab
    var settings: AlphaSettings
    var demoProfileSubject: String?
    var cases: [AlphaCaseMatter]
    var tasks: [AlphaTaskItem]?
    var ledgerEntries: [AlphaPrivacyLedgerEntry]
    var modelJobs: [AlphaModelDownloadJob]
    var installedPacks: [AlphaInstalledModelPack]
    var lastModelCatalogRefresh: Date?
    var publicLawCache: [AlphaPublicLawCacheItem]
    var publicLawDraft: String?
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult]?
    var exports: [AlphaExportedReport]
    var preparedWorkItems: [AlphaPreparedWorkItem]?
    var routineRuns: [AlphaRoutineRun]?
    var routineSettings: AlphaRoutineSettings?
    var modelUpdateCandidates: [AlphaModelUpdateCandidate]?

    static func empty() -> AlphaPersistedState {
        AlphaPersistedState(
            onboardingStage: .onboarding,
            selectedTab: .home,
            settings: .default,
            demoProfileSubject: nil,
            cases: [sharedWorkspaceMatter()],
            tasks: [],
            ledgerEntries: [
                AlphaPrivacyLedgerEntry(
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
            publicLawDraft: "Find Indian public-law guidance on delay condonation and filing compliance.",
            publicLawPreview: nil,
            publicLawResults: [],
            exports: [],
            preparedWorkItems: [],
            routineRuns: [],
            routineSettings: .default,
            modelUpdateCandidates: []
        )
    }

    static func seed() -> AlphaPersistedState {
        demoSeed()
    }

    static func demoSeed(profileSubject: String = "local_demo_advocate") -> AlphaPersistedState {
        let sharedWorkspaceID = UUID(uuidString: "0D9E5220-4D3C-4B49-9A67-10B42B593B7D")!
        let matterID = UUID()
        let orderID = UUID()
        let affidavitID = UUID()
        let noticeID = UUID()
        let nextHearing = Calendar.current.date(byAdding: .day, value: 9, to: .now) ?? .now
        let filingDeadline = Calendar.current.date(byAdding: .day, value: 4, to: .now) ?? .now
        let clientFollowUp = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let orderImportedAt = Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        let affidavitImportedAt = Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now
        let noticeImportedAt = Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now

        let hearingSource = AlphaSourceRef(
            caseId: matterID,
            documentId: orderID,
            documentTitle: "Demo order",
            pageNumber: 2,
            paragraphRange: "¶3",
            textSnippet: "List the matter on \(nextHearing.formatted(date: .abbreviated, time: .omitted)) for arguments.",
            ocrConfidence: 0.95
        )
        let directionSource = AlphaSourceRef(
            caseId: matterID,
            documentId: orderID,
            documentTitle: "Demo order",
            pageNumber: 3,
            paragraphRange: "¶5",
            textSnippet: "Filing defects are to be cured before the next date and a short hearing note should be prepared.",
            ocrConfidence: 0.93
        )
        let partySource = AlphaSourceRef(
            caseId: matterID,
            documentId: affidavitID,
            documentTitle: "Demo affidavit",
            pageNumber: 1,
            paragraphRange: "Cause title",
            textSnippet: "Sharma versus Rana",
            ocrConfidence: 0.91
        )
        let filingSource = AlphaSourceRef(
            caseId: matterID,
            documentId: noticeID,
            documentTitle: "Demo notice",
            pageNumber: 1,
            paragraphRange: "¶2",
            textSnippet: "Reply and filing compliance should be completed before \(filingDeadline.formatted(date: .abbreviated, time: .omitted)).",
            ocrConfidence: 0.88
        )

        let demoOrder = AlphaCaseDocument(
            id: orderID,
            title: "Demo order",
            fileName: "demo-order.pdf",
            kind: .pdf,
            storedRelativePath: "seed/demo-order.pdf",
            importedAt: orderImportedAt,
            pageCount: 4,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: "Interim order directing filing compliance and listing the matter for arguments.",
            dominantSourceSnippet: "List the matter for arguments and prepare a hearing note.",
            lastIndexedAt: orderImportedAt,
            pages: (1...4).map { AlphaDocumentPage(pageNumber: $0, snippet: "Demo order page \($0).") },
            classification: AlphaLegalDocumentClassification(
                documentId: orderID,
                type: .order,
                subtype: "interim order",
                confidence: 0.82,
                sourceRefs: [hearingSource],
                needsReview: false
            ),
            extractedFields: [
                AlphaExtractedLegalField(
                    caseId: matterID,
                    documentId: orderID,
                    fieldType: .nextDate,
                    label: "Next date",
                    value: nextHearing.formatted(date: .abbreviated, time: .omitted),
                    sourceRefs: [hearingSource],
                    confidence: 0.58,
                    extractionMode: .caseAssociate,
                    extractionPass: .llmExtract,
                    needsReview: true
                ),
                AlphaExtractedLegalField(
                    caseId: matterID,
                    documentId: orderID,
                    fieldType: .orderDirection,
                    label: "Order direction",
                    value: "Cure filing defects and prepare a short hearing note before the next date.",
                    sourceRefs: [directionSource],
                    confidence: 0.86,
                    extractionMode: .caseAssociate,
                    extractionPass: .llmVerify,
                    needsReview: false
                )
            ],
            extractionRuns: [
                AlphaExtractionRun(
                    caseId: matterID,
                    documentId: orderID,
                    mode: .caseAssociate,
                    status: .needsReview,
                    progressState: .needsReview,
                    startedAt: orderImportedAt.addingTimeInterval(90),
                    completedAt: orderImportedAt.addingTimeInterval(180),
                    pagesProcessed: 4,
                    totalPages: 4,
                    fieldsExtracted: 2,
                    fieldsNeedingReview: 1,
                    warnings: ["Next date still needs advocate confirmation."]
                )
            ],
            extractionFindings: [
                AlphaExtractionFinding(
                    caseId: matterID,
                    documentId: orderID,
                    kind: .dateConflict,
                    message: "Confirm the next date against the signed order before relying on it in a note or export.",
                    sourceRefs: [hearingSource],
                    severity: .warning
                )
            ]
        )

        let demoAffidavit = AlphaCaseDocument(
            id: affidavitID,
            title: "Demo affidavit",
            fileName: "demo-affidavit.pdf",
            kind: .pdf,
            storedRelativePath: "seed/demo-affidavit.pdf",
            importedAt: affidavitImportedAt,
            pageCount: 3,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: "Affidavit describing chronology and supporting facts for arguments.",
            dominantSourceSnippet: "Cause title and supporting chronology for arguments.",
            lastIndexedAt: affidavitImportedAt,
            pages: (1...3).map { AlphaDocumentPage(pageNumber: $0, snippet: "Demo affidavit page \($0).") },
            classification: AlphaLegalDocumentClassification(
                documentId: affidavitID,
                type: .affidavit,
                subtype: nil,
                confidence: 0.79,
                sourceRefs: [partySource],
                needsReview: false
            ),
            extractedFields: [
                AlphaExtractedLegalField(
                    caseId: matterID,
                    documentId: affidavitID,
                    fieldType: .partyName,
                    label: "Party name",
                    value: "Sharma v. Rana",
                    sourceRefs: [partySource],
                    confidence: 0.63,
                    extractionMode: .caseAssociate,
                    extractionPass: .llmExtract,
                    needsReview: true
                )
            ]
        )

        let demoNotice = AlphaCaseDocument(
            id: noticeID,
            title: "Demo notice",
            fileName: "demo-notice.pdf",
            kind: .pdf,
            storedRelativePath: "seed/demo-notice.pdf",
            importedAt: noticeImportedAt,
            pageCount: 2,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: "Notice recording a filing deadline and response timeline.",
            dominantSourceSnippet: "Filing compliance should be completed before the listed date.",
            lastIndexedAt: noticeImportedAt,
            pages: (1...2).map { AlphaDocumentPage(pageNumber: $0, snippet: "Demo notice page \($0).") },
            classification: AlphaLegalDocumentClassification(
                documentId: noticeID,
                type: .notice,
                subtype: nil,
                confidence: 0.74,
                sourceRefs: [filingSource],
                needsReview: false
            ),
            extractedFields: [
                AlphaExtractedLegalField(
                    caseId: matterID,
                    documentId: noticeID,
                    fieldType: .date,
                    label: "Filing deadline",
                    value: filingDeadline.formatted(date: .abbreviated, time: .omitted),
                    sourceRefs: [filingSource],
                    confidence: 0.77,
                    extractionMode: .caseAssociate,
                    extractionPass: .llmVerify,
                    needsReview: true
                )
            ]
        )

        let demoDates = [
            AlphaMatterDate(
                caseId: matterID,
                title: "Next hearing",
                kind: .hearing,
                date: nextHearing,
                sourceRef: hearingSource
            ),
            AlphaMatterDate(
                caseId: matterID,
                title: "Filing deadline",
                kind: .filingDeadline,
                date: filingDeadline,
                sourceRef: filingSource
            ),
            AlphaMatterDate(
                caseId: matterID,
                title: "Client follow-up",
                kind: .clientFollowUp,
                date: clientFollowUp
            )
        ]

        let demoMatter = AlphaCaseMatter(
            id: matterID,
            title: "Demo Matter: Sharma v. Rana",
            forum: "District Court",
            caseNumber: "Demo/123/2026",
            partiesSummary: "Sharma v. Rana",
            judgeName: "District Judge (Demo)",
            advocateName: "Ross Demo Advocate",
            stage: .arguments,
            folderTint: .indigo,
            nextHearing: nextHearing,
            dates: demoDates,
            localNotice: "Demo matter uses sample data only. Case files stay on this device.",
            notes: "Demo matter uses sample data only.",
            summary: "This synthetic matter is ready for a morning check-in. Review the latest order, confirm the next date, prepare a hearing note, and keep filing compliance on track.",
            issueHighlights: [
                "Confirm the next hearing date from the latest order.",
                "Prepare a short hearing note before arguments.",
                "Check the filing deadline before sharing the next update."
            ],
            evidenceNotes: [
                "Demo order contains the next date and order direction.",
                "Demo affidavit still needs a quick party-name confirmation.",
                "Demo notice flags the filing deadline."
            ],
            draftTasks: [
                "Review latest order",
                "Prepare hearing note",
                "Confirm filing deadline",
                "Call client with next date"
            ],
            documents: [demoOrder, demoAffidavit, demoNotice],
            sourceRefs: [hearingSource, directionSource, partySource, filingSource],
            chatSessions: [
                AlphaChatSession(
                    createdAt: orderImportedAt,
                    updatedAt: orderImportedAt,
                    contextDocumentIDs: [orderID],
                    turns: [
                        AlphaChatTurn(
                            kind: .matterUpdate,
                            askedAt: orderImportedAt,
                            question: "Matter update",
                            answerTitle: "Good morning",
                            answerSections: [
                                "This demo matter has one next hearing, one filing deadline, and one order that still needs advocate review.",
                                "Start with the latest order, confirm the next date, then generate a short hearing note."
                            ],
                            sourceRefs: [hearingSource, directionSource],
                            selectedDocumentTitles: ["Demo order"],
                            statusNote: "Demo matter ready",
                            needsReviewWarning: "Review before relying on the next date."
                        )
                    ]
                )
            ],
            caseMemoryUpdates: [
                AlphaCaseMemoryUpdate(
                    caseId: matterID,
                    source: .manualNote,
                    summary: "Demo workspace prepared for local morning-use QA.",
                    affectedDocuments: [orderID, affidavitID, noticeID],
                    createdAt: noticeImportedAt
                )
            ],
            updatedAt: orderImportedAt
        )

        let sharedWorkspace = AlphaCaseMatter(
            id: sharedWorkspaceID,
            title: "General files",
            forum: "Available across matters",
            stage: .intake,
            nextHearing: nil,
            dates: [],
            summary: "Files placed here stay available anywhere on this device.",
            issueHighlights: [
                "Use shared files when a document should support more than one matter."
            ],
            evidenceNotes: [
                "Ross keeps these files local and ready for device-wide questions."
            ],
            draftTasks: [],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )

        let seededTasks = [
            AlphaTaskItem(
                caseId: matterID,
                title: "Review latest order",
                notes: "Confirm the next date and order direction from the demo order.",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
                priority: .high,
                source: .manual
            ),
            AlphaTaskItem(
                caseId: matterID,
                title: "Prepare hearing note",
                notes: "Generate a short note after confirming the next date.",
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: .now),
                priority: .normal,
                source: .system
            ),
            AlphaTaskItem(
                caseId: matterID,
                title: "Confirm filing deadline",
                notes: "Check the demo notice before closing the review loop.",
                dueDate: filingDeadline,
                priority: .high,
                source: .extraction
            ),
            AlphaTaskItem(
                caseId: matterID,
                title: "Call client with next date",
                notes: "Use the confirmed next date after advocate review.",
                dueDate: clientFollowUp,
                priority: .normal,
                source: .manual
            )
        ]

        return AlphaPersistedState(
            onboardingStage: .completed,
            selectedTab: .home,
            settings: .default,
            demoProfileSubject: profileSubject,
            cases: [demoMatter, sharedWorkspace],
            tasks: seededTasks,
            ledgerEntries: [
                AlphaPrivacyLedgerEntry(
                    title: "Demo workspace prepared locally",
                    detail: "Ross created synthetic sample work for local testing only.",
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://demo-seed",
                    success: true
                ),
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
            publicLawDraft: "Find Indian public-law guidance on delay condonation and filing compliance after an interim order.",
            publicLawPreview: nil,
            publicLawResults: [],
            exports: [],
            preparedWorkItems: [],
            routineRuns: [],
            routineSettings: .default,
            modelUpdateCandidates: []
        )
    }
}

private extension AlphaPersistedState {
    static func sharedWorkspaceMatter() -> AlphaCaseMatter {
        AlphaCaseMatter(
            id: UUID(uuidString: "0D9E5220-4D3C-4B49-9A67-10B42B593B7D")!,
            title: "General files",
            forum: "Available across matters",
            stage: .intake,
            nextHearing: nil,
            dates: [],
            summary: "Files placed here stay available anywhere on this device.",
            issueHighlights: [
                "Use shared files when a document should support more than one matter."
            ],
            evidenceNotes: [
                "Ross keeps these files local and ready for device-wide questions."
            ],
            draftTasks: [],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )
    }
}

extension AlphaCaseDocument {
    var hasAskUsableExtractedText: Bool {
        extractedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            dominantSourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            pages.contains {
                ($0.extractedText ?? $0.anchorText ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty == false
            }
    }

    var hasActiveTextExtraction: Bool {
        extractionRuns.contains { $0.status == .queued || $0.status == .running } ||
            effectiveIndexingStatus == .extracting
    }

    var isAwaitingReadableText: Bool {
        !hasAskUsableExtractedText && hasActiveTextExtraction
    }

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

    var processingState: AlphaDocumentProcessingState {
        let latestRun = extractionRuns.sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast) > (rhs.startedAt ?? .distantPast)
        }.first

        if effectiveIndexingStatus == .failed || ocrStatus == .failed || latestRun?.status == .failed {
            return .failed
        }

        if hasActiveTextExtraction {
            return .readingText
        }

        let hasExtractedContent = extractedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            dominantSourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            pages.contains { ($0.extractedText ?? $0.snippet ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        if !hasExtractedContent && effectiveIndexingStatus == .notStarted {
            return .imported
        }

        if classification?.type.blocksAutomaticLegalFactSaving == true || classification?.needsReview == true {
            return .needsConfirmation
        }

        let hasReviewWork = extractedFields.contains(where: \.needsReview) || extractionFindings.contains(where: { !$0.resolved })
        if hasReviewWork || latestRun?.status == .needsReview {
            return .reviewingFindings
        }

        if effectiveIndexingStatus == .indexed || ocrStatus == .nativeText || ocrStatus == .ocrComplete || latestRun?.status == .complete {
            return .ready
        }

        return .imported
    }

    var lawyerStatusTitle: String {
        if classification?.type == .fictionalGameMaterial {
            return "Fictional"
        }
        if classification?.type == .nonLegalDocument {
            return "Non-legal?"
        }
        let hasLowConfidenceScan = extractionFindings.contains {
            $0.kind == .lowConfidenceOcr || $0.kind == .languageUncertain || $0.kind == .possibleHandwriting
        }

        if hasLowConfidenceScan {
            return "Low confidence scan"
        }
        return processingState.title
    }
}

extension AlphaPrivacyLedgerEntry {
    var lawyerTitle: String {
        switch title {
        case "Model catalog checked":
            rossLocalized("privacy_ledger_assistant_catalog_checked_title")
        case "Assistant update available":
            rossLocalized("privacy_ledger_assistant_update_available_title")
        case "Private assistant download queued":
            rossLocalized("privacy_ledger_private_assistant_download_queued_title")
        case "Private assistant setup unavailable":
            rossLocalized("privacy_ledger_private_assistant_unavailable_title")
        case "Private AI Pack queued", "Private AI Pack verified":
            rossLocalized("privacy_ledger_private_assistant_setup_title")
        case "Assistant download verified", "Assistant verified", "Assistant download failed", "Assistant restored":
            rossLocalized("privacy_ledger_private_assistant_setup_title")
        case "Assistant removed", "Assistant setup removed":
            rossLocalized("privacy_ledger_assistant_removed_title")
        case "Assistant activation failed", "Assistant file verification failed":
            rossLocalized("privacy_ledger_assistant_repair_needed_title")
        case "Private assistant enabled", "Test assistant installed", "Assistant selected":
            rossLocalized("privacy_ledger_assistant_selected_title")
        case "Public-law search reviewed by user", "Legal Search reviewed by user":
            rossLocalized("privacy_ledger_public_law_reviewed_title")
        case "Public-law query sent":
            rossLocalized("privacy_ledger_public_law_sent_title")
        case "Public-law search cancelled", "Legal Search cancelled":
            rossLocalized("privacy_ledger_public_law_cancelled_title")
        case "Public-law search unavailable", "Legal Search unavailable":
            rossLocalized("privacy_ledger_public_law_unavailable_title")
        case "Local export generated":
            rossLocalized("privacy_ledger_local_export_generated_title")
        case "Export generation failed":
            rossLocalized("privacy_ledger_local_export_failed_title")
        case "Local case review run":
            rossLocalized("privacy_ledger_local_case_review_title")
        case "Document imported locally":
            rossLocalized("privacy_ledger_document_imported_title")
        case "Case created locally":
            rossLocalized("privacy_ledger_case_created_title")
        case "AI output reported":
            rossLocalized("privacy_ledger_ai_output_reported_title")
        default:
            title
        }
    }

    var lawyerDetail: String {
        switch title {
        case "Model catalog checked":
            rossLocalized("privacy_ledger_assistant_catalog_checked_detail")
        case "Assistant update available":
            rossLocalized("privacy_ledger_assistant_update_available_detail")
        case "Private assistant download queued":
            rossLocalized("privacy_ledger_private_assistant_download_queued_detail")
        case "Private assistant setup unavailable":
            rossLocalized("privacy_ledger_private_assistant_unavailable_detail")
        case "Public-law search reviewed by user", "Legal Search reviewed by user":
            rossLocalized("privacy_ledger_public_law_reviewed_detail")
        case "Public-law query sent":
            rossLocalized("privacy_ledger_public_law_sent_detail")
        case "Public-law search cancelled", "Legal Search cancelled":
            rossLocalized("privacy_ledger_public_law_cancelled_detail")
        case "Public-law search unavailable", "Legal Search unavailable":
            rossLocalized("privacy_ledger_public_law_unavailable_detail")
        case "Private AI Pack verified":
            rossLocalized("privacy_ledger_private_assistant_prepared_detail")
        case "Assistant download verified":
            rossLocalized("privacy_ledger_assistant_download_checked_detail")
        case "Assistant verified":
            rossLocalized("privacy_ledger_assistant_ready_detail")
        case "Assistant download failed":
            rossLocalized("privacy_ledger_assistant_download_failed_detail")
        case "Assistant removed":
            rossLocalized("privacy_ledger_assistant_removed_detail")
        case "Assistant setup removed":
            rossLocalized("privacy_ledger_assistant_setup_removed_detail")
        case "Assistant activation failed", "Assistant file verification failed":
            rossLocalized("privacy_ledger_assistant_repair_needed_detail")
        case "Private assistant enabled":
            rossLocalized("privacy_ledger_private_assistant_enabled_detail")
        case "Test assistant installed":
            rossLocalized("privacy_ledger_test_assistant_installed_detail")
        case "Assistant selected":
            rossLocalized("privacy_ledger_assistant_selected_detail")
        case "Local export generated":
            rossLocalized("privacy_ledger_local_export_generated_detail")
        case "Export generation failed":
            rossLocalized("privacy_ledger_local_export_failed_detail")
        case "AI output reported":
            rossLocalized("privacy_ledger_ai_output_reported_detail")
        default:
            detail
        }
    }

    var lawyerPurposeLabel: String {
        switch purpose {
        case .local_only:
            rossLocalized("privacy_ledger_purpose_local_only")
        case .public_law_search:
            rossLocalized("privacy_ledger_purpose_public_law")
        case .model_catalog, .model_download, .model_verification:
            rossLocalized("privacy_ledger_purpose_assistant_setup")
        }
    }
}
