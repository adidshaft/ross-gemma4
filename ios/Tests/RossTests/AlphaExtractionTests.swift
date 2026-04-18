import XCTest
@testable import Ross

final class AlphaExtractionTests: XCTestCase {
    func testLocalExtractionDetectsMixedLanguageProfile() async {
        let store = AlphaRossStore()
        let caseId = UUID()
        let document = AlphaCaseDocument(
            title: "Bilingual Order",
            fileName: "bilingual-order.pdf",
            kind: .pdf,
            storedRelativePath: "tests/bilingual-order.pdf",
            importedAt: .now,
            pageCount: 2,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: nil,
            dominantSourceSnippet: nil,
            lastIndexedAt: .now,
            pages: [
                AlphaDocumentPage(pageNumber: 1, snippet: "IN THE HIGH COURT OF DELHI\nCommercial Courts Act section 13."),
                AlphaDocumentPage(pageNumber: 2, snippet: "अगली तारीख 12/05/2026\nयाचिकाकर्ता बनाम प्रतिवादी")
            ]
        )

        let result = await store.runLocalExtraction(caseId: caseId, document: document, activeTier: .caseAssociate)

        XCTAssertEqual(result.languageProfile?.primaryLanguage, .mixed)
        XCTAssertTrue(result.languageProfile?.scriptsDetected.contains("latin") == true)
        XCTAssertTrue(result.languageProfile?.scriptsDetected.contains("devanagari") == true)
    }

    func testBasicModeSkipsModelStyleIssueExtraction() async {
        let store = AlphaRossStore()
        let caseId = UUID()
        let document = AlphaCaseDocument(
            title: "Issue Note",
            fileName: "issue-note.txt",
            kind: .text,
            storedRelativePath: "tests/issue-note.txt",
            importedAt: .now,
            pageCount: 1,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: "Issue: Delay in filing written statement under Commercial Courts Act.\nNext date 12/05/2026.",
            dominantSourceSnippet: nil,
            lastIndexedAt: .now,
            pages: [
                AlphaDocumentPage(
                    pageNumber: 1,
                    snippet: "Issue: Delay in filing written statement under Commercial Courts Act.\nNext date 12/05/2026.",
                    extractedText: "Issue: Delay in filing written statement under Commercial Courts Act.\nNext date 12/05/2026.",
                    anchorText: "Issue: Delay in filing written statement under Commercial Courts Act."
                )
            ]
        )

        let basic = await store.runLocalExtraction(caseId: caseId, document: document, activeTier: nil)
        let advanced = await store.runLocalExtraction(caseId: caseId, document: document, activeTier: .caseAssociate)

        XCTAssertFalse(basic.extractedFields.contains { $0.fieldType == .issue })
        XCTAssertTrue(advanced.extractedFields.contains { $0.fieldType == .issue })
    }

    func testExtractedFieldsAlwaysRetainSourceRefs() async {
        let store = AlphaRossStore()
        let caseId = UUID()
        let document = AlphaCaseDocument(
            title: "Order",
            fileName: "order.pdf",
            kind: .pdf,
            storedRelativePath: "tests/order.pdf",
            importedAt: .now,
            pageCount: 2,
            ocrStatus: .nativeText,
            indexingStatus: .indexed,
            extractedText: nil,
            dominantSourceSnippet: nil,
            lastIndexedAt: .now,
            pages: [
                AlphaDocumentPage(pageNumber: 1, snippet: "IN THE HIGH COURT OF DELHI\nCS No. 45/2026"),
                AlphaDocumentPage(pageNumber: 2, snippet: "Listed on 12/05/2026\nIt is directed that reply be filed within two weeks.")
            ]
        )

        let result = await store.runLocalExtraction(caseId: caseId, document: document, activeTier: .caseAssociate)

        XCTAssertFalse(result.extractedFields.isEmpty)
        XCTAssertTrue(result.extractedFields.allSatisfy { !$0.sourceRefs.isEmpty })
        XCTAssertTrue(result.extractedFields.contains { field in
            (field.fieldType == .date || field.fieldType == .nextDate || field.fieldType == .orderDirection)
                && field.sourceRefs.contains(where: { $0.pageNumber == 2 })
        })
    }
}
