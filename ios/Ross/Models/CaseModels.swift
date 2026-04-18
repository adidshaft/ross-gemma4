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

extension CaseFile {
    static let fixtureCases: [CaseFile] = [
        CaseFile(
            id: UUID(),
            title: "Kaveri Developers v. South Ward Municipal Corporation",
            forum: "Karnataka High Court",
            stage: .pleadings,
            nextHearing: Calendar.current.date(byAdding: .day, value: 6, to: .now),
            lastUpdated: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now,
            documents: [
                CaseDocument(
                    title: "Writ Petition Draft",
                    category: "Pleading",
                    pageCount: 28,
                    importedAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
                    isIndexedLocally: true
                ),
                CaseDocument(
                    title: "Impugned Notice",
                    category: "Order",
                    pageCount: 6,
                    importedAt: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
                    isIndexedLocally: true
                ),
                CaseDocument(
                    title: "Inspection Photographs",
                    category: "Evidence",
                    pageCount: 14,
                    importedAt: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now,
                    isIndexedLocally: false
                )
            ],
            workspace: WorkspaceSnapshot(
                chronologySummary: "The file shows an inspection notice, a follow-up representation, and a recent municipal demand. The chronology is sufficiently complete for a next-hearing note, but the compliance sequence still needs one clean page reference set.",
                issueHighlights: [
                    "Whether the demand proceeds without addressing the representation already on record.",
                    "Whether the inspection materials and notice timing support a procedural fairness argument."
                ],
                evidenceNotes: [
                    "Photographs are present but not yet indexed locally.",
                    "Representation acknowledgment page should be surfaced as a source chip for the hearing note."
                ],
                draftTasks: [
                    "Prepare a short chronology for the next hearing.",
                    "Extract the representation acknowledgment and annexure references.",
                    "Draft a focused note on procedural fairness."
                ],
                sourceAnchors: [
                    SourceAnchor(label: "WP Draft p. 4", note: "Representation and reply timeline"),
                    SourceAnchor(label: "Notice p. 2", note: "Inspection grounds and compliance window"),
                    SourceAnchor(label: "Bundle Index p. 1", note: "Current annexure map")
                ]
            ),
            localNotice: "Designed to keep case files on this device",
            captureInboxCount: 2
        ),
        CaseFile(
            id: UUID(),
            title: "Arun Textiles v. State Tax Officer",
            forum: "Madras High Court",
            stage: .evidence,
            nextHearing: Calendar.current.date(byAdding: .day, value: 14, to: .now),
            lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            documents: [
                CaseDocument(
                    title: "Assessment Order",
                    category: "Order",
                    pageCount: 19,
                    importedAt: Calendar.current.date(byAdding: .day, value: -15, to: .now) ?? .now,
                    isIndexedLocally: true
                ),
                CaseDocument(
                    title: "Reconciliation Statement",
                    category: "Evidence",
                    pageCount: 23,
                    importedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
                    isIndexedLocally: true
                )
            ],
            workspace: WorkspaceSnapshot(
                chronologySummary: "The file is ready for an evidence-focused review. The latest local indexing pass captured the assessment order and the reconciliation note, making this a strong candidate for source-backed issue extraction.",
                issueHighlights: [
                    "Mismatch between the assessment reasoning and the reconciliation schedule.",
                    "Need to isolate whether the authority engaged with the clarification already supplied."
                ],
                evidenceNotes: [
                    "Reconciliation statement is indexed locally.",
                    "A short hearing-preparation note can be generated once the discrepancy pages are pinned."
                ],
                draftTasks: [
                    "Map discrepancy pages against the order reasoning.",
                    "Extract hearing-ready bullet points with page references."
                ],
                sourceAnchors: [
                    SourceAnchor(label: "Order p. 11", note: "Reasoning on discrepancy"),
                    SourceAnchor(label: "Reconciliation p. 5", note: "Counterpoint for hearing note")
                ]
            ),
            localNotice: "Works locally on this device",
            captureInboxCount: 0
        )
    ]
}
