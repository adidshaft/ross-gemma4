import Foundation

enum CaseStage: String, Codable, Hashable, Sendable {
    case intake
    case pleadings
    case evidence
    case arguments
    case reserved

    var title: String {
        switch self {
        case .intake:
            "Intake"
        case .pleadings:
            "Pleadings"
        case .evidence:
            "Evidence"
        case .arguments:
            "Arguments"
        case .reserved:
            "Reserved"
        }
    }
}

struct SourceAnchor: Identifiable, Hashable, Sendable {
    let id: UUID
    let label: String
    let note: String

    init(id: UUID = UUID(), label: String, note: String) {
        self.id = id
        self.label = label
        self.note = note
    }
}

struct CaseDocument: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let category: String
    let pageCount: Int
    let importedAt: Date
    let isIndexedLocally: Bool

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        pageCount: Int,
        importedAt: Date,
        isIndexedLocally: Bool
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.pageCount = pageCount
        self.importedAt = importedAt
        self.isIndexedLocally = isIndexedLocally
    }
}

struct WorkspaceSnapshot: Hashable, Sendable {
    let chronologySummary: String
    let issueHighlights: [String]
    let evidenceNotes: [String]
    let draftTasks: [String]
    let sourceAnchors: [SourceAnchor]
}

struct CaseFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let forum: String
    let stage: CaseStage
    let nextHearing: Date?
    var lastUpdated: Date
    var documents: [CaseDocument]
    let workspace: WorkspaceSnapshot
    let localNotice: String
    var captureInboxCount: Int
}
