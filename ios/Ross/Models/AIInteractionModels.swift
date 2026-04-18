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

    static let fixture = QuickCaptureDraft(
        id: UUID(),
        captureTitle: "Handwritten hearing note and annexure photo set",
        source: .camera,
        receivedAt: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now,
        extractedHighlights: [
            "Detected a short hearing note with two date references.",
            "Captured an annexure label and one visible signature block.",
            "Suggested a case link based on the selected workspace."
        ],
        redactionChecklist: [
            "Confirm whether the visible signature block should be blurred before export.",
            "Check if any phone number appears on the annexure edge.",
            "Verify that the case title stays local and is not reused in public-law search."
        ],
        filingRecommendation: "File into the selected case after confirming the visible identifiers.",
        destinationCaseTitle: CaseFile.fixtureCases.first?.title
    )
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
