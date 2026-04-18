import Foundation

@MainActor
protocol PublicLawSearchServicing {
    func buildPreview(for prompt: String, caseFile: CaseFile?) async -> SanitizedPublicQueryPreview
    func search(for preview: SanitizedPublicQueryPreview) async -> [PublicLawResult]
}

@MainActor
struct StubPublicLawSearchService: PublicLawSearchServicing {
    private let privacyLedger: PrivacyLedgerService

    init(privacyLedger: PrivacyLedgerService) {
        self.privacyLedger = privacyLedger
    }

    func buildPreview(for prompt: String, caseFile: CaseFile?) async -> SanitizedPublicQueryPreview {
        let sanitizedQuery = sanitizePrompt(prompt, caseFile: caseFile)

        return SanitizedPublicQueryPreview(
            publicQuery: sanitizedQuery,
            purpose: "Public-law search remains optional and distinct from private case work.",
            removedElements: [
                "Case title and forum references",
                "Any long factual passage or raw local text",
                "Case identifiers and personal contact details"
            ],
            confirmationNote: "Review this query before any network request. Only the sanitized public query should leave the device."
        )
    }

    func search(for preview: SanitizedPublicQueryPreview) async -> [PublicLawResult] {
        await MainActor.run {
            privacyLedger.recordNetwork(
                title: "Public-law query sent",
                detail: "Only the sanitized public query crossed the network boundary.",
                boundary: .publicLaw,
                dataClass: .sanitizedPublicQuery,
                direction: .outbound
            )
        }

        return [
            PublicLawResult(
                title: "Delay condonation and documented diligence",
                citation: "(2024) 7 SCC 112",
                snippet: "The Court emphasized that diligence, chronology, and the absence of strategic delay remain central to condonation review.",
                sourceName: "Supreme Court Cases",
                linkLabel: "Open citation"
            ),
            PublicLawResult(
                title: "Administrative fairness in filing-delay matters",
                citation: "2023 SCC OnLine SC 881",
                snippet: "A brief administrative disruption may be weighed differently where the record shows prompt corrective action and contemporaneous documentation.",
                sourceName: "SCC OnLine",
                linkLabel: "Open report"
            )
        ]
    }

    private func sanitizePrompt(_ prompt: String, caseFile: CaseFile?) -> String {
        var sanitized = prompt

        if let caseFile {
            sanitized = sanitized.replacingOccurrences(
                of: caseFile.title,
                with: "",
                options: [.caseInsensitive]
            )
            sanitized = sanitized.replacingOccurrences(
                of: caseFile.forum,
                with: "",
                options: [.caseInsensitive]
            )
        }

        sanitized = sanitized.replacingOccurrences(
            of: "\\b\\d{2,}\\b",
            with: "",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.isEmpty {
            return "Find current public-law guidance relevant to delay condonation where diligence is documented."
        }

        return sanitized
    }
}
