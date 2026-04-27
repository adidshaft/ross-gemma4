import Foundation

enum CaptureSource: String, Hashable, Sendable {
    case camera
    case files
    case shareSheet

    var title: String {
        switch self {
        case .camera:
            "Camera"
        case .files:
            "Files"
        case .shareSheet:
            "Share Sheet"
        }
    }
}

struct QuickCaptureDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    let captureTitle: String
    let source: CaptureSource
    let receivedAt: Date
    let extractedHighlights: [String]
    let redactionChecklist: [String]
    let filingRecommendation: String
    let destinationCaseTitle: String?
}

struct AskCaseSection: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let body: String

    init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

struct AskCaseResponse: Hashable, Sendable {
    let headline: String
    let draftNotice: String
    let sections: [AskCaseSection]
    let citations: [SourceAnchor]
}

struct InstantModeAssessment: Hashable, Sendable {
    let title: String
    let detail: String
    let isAvailable: Bool
    let isBlocking: Bool
    let guidance: String
}

struct SanitizedPublicQueryPreview: Hashable, Sendable {
    let publicQuery: String
    let purpose: String
    let removedElements: [String]
    let confirmationNote: String
}

struct PublicLawResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let citation: String
    let snippet: String
    let sourceName: String
    let linkLabel: String

    init(
        id: UUID = UUID(),
        title: String,
        citation: String,
        snippet: String,
        sourceName: String,
        linkLabel: String
    ) {
        self.id = id
        self.title = title
        self.citation = citation
        self.snippet = snippet
        self.sourceName = sourceName
        self.linkLabel = linkLabel
    }
}
