import Foundation

protocol CaseRepository: Sendable {
    func loadCases() async -> [CaseFile]
    func fileQuickCapture(_ draft: QuickCaptureDraft, into caseID: CaseFile.ID?) async -> CaseFile?
}

actor InMemoryCaseRepository: CaseRepository {
    private var cases: [CaseFile]

    init(seed: [CaseFile]) {
        cases = seed
    }

    func loadCases() async -> [CaseFile] {
        cases.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    func fileQuickCapture(_ draft: QuickCaptureDraft, into caseID: CaseFile.ID?) async -> CaseFile? {
        guard let caseID else {
            return nil
        }

        guard let index = cases.firstIndex(where: { $0.id == caseID }) else {
            return nil
        }

        let filedDocument = CaseDocument(
            title: draft.captureTitle,
            category: "Quick Capture",
            pageCount: 3,
            importedAt: Date(),
            isIndexedLocally: false
        )

        cases[index].documents.insert(filedDocument, at: 0)
        cases[index].captureInboxCount = max(0, cases[index].captureInboxCount - 1)
        cases[index].lastUpdated = Date()

        return cases[index]
    }
}
