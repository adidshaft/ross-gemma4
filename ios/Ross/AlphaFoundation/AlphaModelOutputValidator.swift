import Foundation

struct AlphaVerificationPayload: Codable, Hashable, Sendable {
    var fields: [AlphaExtractedLegalField]
    var findings: [AlphaExtractionFinding]
}

enum AlphaModelOutputValidator {
    static func repairedJSON(from output: AlphaLocalModelOutput) -> String? {
        if let parsed = output.parsedJson { return parsed }
        let raw = output.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if (raw.hasPrefix("{") && raw.hasSuffix("}")) || (raw.hasPrefix("[") && raw.hasSuffix("]")) {
            return raw
        }
        return nil
    }

    static func parseClassification(from output: AlphaLocalModelOutput, using decoder: JSONDecoder) -> AlphaLegalDocumentClassification? {
        guard let json = repairedJSON(from: output), let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(AlphaLegalDocumentClassification.self, from: data)
    }

    static func parseFields(from output: AlphaLocalModelOutput, using decoder: JSONDecoder) -> [AlphaExtractedLegalField] {
        guard let json = repairedJSON(from: output), let data = json.data(using: .utf8) else { return [] }
        return (try? decoder.decode([AlphaExtractedLegalField].self, from: data)) ?? []
    }

    static func parseVerification(from output: AlphaLocalModelOutput, using decoder: JSONDecoder) -> AlphaVerificationPayload? {
        guard let json = repairedJSON(from: output), let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(AlphaVerificationPayload.self, from: data)
    }

    static func parseCaseMemory(from output: AlphaLocalModelOutput, using decoder: JSONDecoder) -> [AlphaCaseMemoryUpdate] {
        guard let json = repairedJSON(from: output), let data = json.data(using: .utf8) else { return [] }
        return (try? decoder.decode([AlphaCaseMemoryUpdate].self, from: data)) ?? []
    }

    static func fieldsHaveSourceRefs(_ fields: [AlphaExtractedLegalField]) -> Bool {
        fields.allSatisfy { !$0.sourceRefs.isEmpty }
    }
}
