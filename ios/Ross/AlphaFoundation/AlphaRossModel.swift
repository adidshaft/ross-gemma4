import CryptoKit
import Observation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif


private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func caseInsensitiveContains(_ value: String) -> Bool {
        range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
enum AlphaHapticFeedback {
    case light
    case medium
    case selection
    case warning
}

@MainActor
func alphaHaptic(_ feedback: AlphaHapticFeedback) {
#if canImport(UIKit)
    switch feedback {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .selection:
        UISelectionFeedbackGenerator().selectionChanged()
    case .warning:
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
#endif
}

enum AlphaRoute: Hashable {
    case createCase
    case caseWorkspace(UUID)
    case documentList(UUID)
    case documentViewer(UUID, UUID, Int?)
    case askRoss
    case askCase(UUID)
    case exports(UUID?)
    case privacyLedger
    case privateAISettings
}

extension AlphaRoute {
    var isAskRoute: Bool {
        switch self {
        case .askRoss, .askCase:
            true
        default:
            false
        }
    }
}

extension View {
    @ViewBuilder
    func alphaDismissesKeyboardOnScroll() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

struct AlphaLocalInferenceSmokeReport: Hashable {
    var ran: Bool
    var runtimeUsed: String
    var schemaValid: Bool
    var fieldsFound: Int
    var fieldsVerified: Int
    var fieldsNeedingReview: Int
    var unsupportedAccepted: Int
    var exportRelativePath: String?
    var message: String
    var createdAt: Date = .now
}

struct AlphaPrivateAISnapshot: Hashable, Sendable {
    var installedPacks: [AlphaInstalledModelPack] = []
    var activePack: AlphaInstalledModelPack?
    var activeRuntimeHealth: AlphaLocalRuntimeHealth?
    var recommendedTier: AlphaCapabilityTier = .caseAssociate
    var freeDiskSpaceLabel = "Checking available space..."
    var lastModelInvocation: AlphaLocalModelInvocation?
    var resetCount = 0

    func installedPack(for tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        installedPacks.first { $0.tier == tier }
    }
}

struct AlphaPrivateAISnapshotRefreshKey: Hashable, Sendable {
    var installedPacks: [AlphaInstalledModelPack]
    var activeTier: AlphaCapabilityTier?
    var ledgerCount: Int
    var documentInvocationCount: Int
    var chatInvocationCount: Int
}

struct AlphaAskResult: Hashable {
    var chatSessionID: UUID?
    var chatTurnID: UUID?
    var kind: AlphaChatTurnKind
    var question: String
    var scopeCaseID: UUID?
    var scopeLabel: String
    var selectedDocumentTitles: [String]
    var answerTitle: String
    var answerSections: [String]
    var caseFileSources: [AlphaSourceRef]
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult]
    var statusNote: String?
    var needsReviewWarning: String?
}

enum AlphaPublicLawSearchStatus: Hashable {
    case idle
    case reviewing
    case running
    case complete
    case failed
}

struct AlphaMatterAskRuntimePayload: Codable, Hashable {
    var headline: String
    var sections: [String]
    var statusNote: String?
}

enum AlphaMatterAskPayloadParser {
    static func parse(
        output: AlphaLocalModelOutput,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let sanitizedRawText = sanitizedResponseText(output.rawText)
        let candidates = [
            output.parsedJson,
            extractLikelyJSON(from: sanitizedRawText),
            sanitizedRawText
        ]
            .compactMap { candidate in
                candidate?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
            }

        for candidate in candidates {
            if let payload = decodedPayload(from: candidate, baseResult: baseResult) {
                return payload
            }
            if let payload = salvagedPayload(from: candidate, baseResult: baseResult) {
                return payload
            }
            if let payload = lenientPayload(from: candidate, baseResult: baseResult) {
                return payload
            }
        }

        return plainTextPayload(from: sanitizedRawText, baseResult: baseResult)
    }

    static func displaySections(from sections: [String]) -> [String] {
        sections.flatMap { displaySections(from: $0) }
    }

    static func decodedPayload(
        from candidate: String,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let decoder = JSONDecoder()
        guard let data = candidate.data(using: .utf8),
              let payload = try? decoder.decode(AlphaMatterAskRuntimePayload.self, from: data) else {
            return nil
        }
        return normalizedPayload(payload, baseResult: baseResult)
    }

    static func normalizedPayload(
        _ payload: AlphaMatterAskRuntimePayload,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let headline = payload.headline
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(baseResult.answerTitle)
        let sections = payload.sections
            .map {
                $0
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            .filter {
                !$0.isEmpty &&
                !$0.caseInsensitiveContains("<think") &&
                !looksLikeStructuredOutput($0)
            }
        guard !sections.isEmpty else { return nil }
        let statusNote = payload.statusNote?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(baseResult.statusNote ?? "Private assistant")
        return AlphaMatterAskRuntimePayload(
            headline: headline,
            sections: Array(sections.prefix(3)),
            statusNote: statusNote
        )
    }

    static func sanitizedResponseText(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: #"(?is)<think\b[^>]*>.*?</think>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)</?think\b[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)(</?\s*(start|end)\s*_\s*of\s*_\s*turn\s*>|start\s*of\s*turn|end\s*of\s*turn).*$"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<\s*bos\s*>"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractLikelyJSON(from text: String) -> String? {
        let normalizedText = text.replacingOccurrences(
            of: #"(?i)^\s*json\s*(?=[\{\[])"#,
            with: "",
            options: .regularExpression
        )
        guard let startIndex = normalizedText.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let candidate = normalizedText[startIndex...]
        var depth = 0
        var inString = false
        var escaped = false
        for index in candidate.indices {
            let character = candidate[index]
            if escaped {
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                continue
            }
            if character == "\"" {
                inString.toggle()
                continue
            }
            guard !inString else { continue }
            if character == "{" || character == "[" {
                depth += 1
            } else if character == "}" || character == "]" {
                depth -= 1
                if depth == 0 {
                    return String(candidate[...index])
                }
            }
        }
        return nil
    }

    static func salvagedPayload(
        from text: String,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let headline = extractJSONStringValue(for: "headline", in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(baseResult.answerTitle) ?? baseResult.answerTitle
        let statusNote = extractJSONStringValue(for: "statusNote", in: text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(baseResult.statusNote ?? "Private assistant")
        let sections = extractJSONStringArray(for: "sections", in: text)
        guard !sections.isEmpty else { return nil }
        return normalizedPayload(
            AlphaMatterAskRuntimePayload(
                headline: headline,
                sections: sections,
                statusNote: statusNote
            ),
            baseResult: baseResult
        )
    }

    static func extractJSONStringValue(for key: String, in text: String) -> String? {
        let pattern = #""\#(key)"\s*:\s*("(?:\\.|[^"\\])*")"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.matches(in: text, range: nsRange).last,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return decodeJSONStringLiteral(String(text[range]))
    }

    static func extractJSONStringArray(for key: String, in text: String) -> [String] {
        let pattern = #""\#(key)"\s*:\s*\[(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range(at: 1), in: text) else {
            return []
        }
        let arrayBody = String(text[range])
        guard let literalRegex = try? NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#) else {
            return []
        }
        let literalRange = NSRange(arrayBody.startIndex..., in: arrayBody)
        return literalRegex.matches(in: arrayBody, range: literalRange).compactMap { match in
            guard let range = Range(match.range, in: arrayBody) else { return nil }
            let prefix = arrayBody[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = arrayBody[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard prefix.last != ":" else { return nil }
            guard suffix.first != ":" else { return nil }
            return decodeJSONStringLiteral(String(arrayBody[range]))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }
    }

    static func decodeJSONStringLiteral(_ literal: String) -> String? {
        guard let data = literal.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    static func humanReadableParagraphs(from text: String) -> [String] {
        plainTextFragments(from: text, preserveHeadline: true)
    }

    static func looksLikeStructuredOutput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.first == "{" || trimmed.first == "[" {
            return true
        }
        if trimmed.contains(#""headline""#) || trimmed.contains(#""sections""#) || trimmed.contains(#""statusNote""#) {
            return true
        }
        return false
    }

    static func displaySections(from rawSection: String) -> [String] {
        let sanitized = sanitizedResponseText(rawSection)
        guard !sanitized.isEmpty else { return [] }

        let candidates = [
            extractLikelyJSON(from: sanitized),
            sanitized
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

        for candidate in candidates {
            if let data = candidate.data(using: .utf8),
               let payload = try? JSONDecoder().decode(AlphaMatterAskRuntimePayload.self, from: data) {
                return normalizedDisplaySections(payload.sections)
            }

            let salvaged = extractJSONStringArray(for: "sections", in: candidate)
            if !salvaged.isEmpty {
                return normalizedDisplaySections(salvaged)
            }
            if let payload = lenientPayload(from: candidate, baseResult: alphaEmptyMatterAskBaseResult()) {
                return normalizedDisplaySections(payload.sections)
            }
        }

        guard !looksLikeStructuredOutput(sanitized) else { return [] }
        return humanReadableParagraphs(from: sanitized)
    }

    static func normalizedDisplaySections(_ sections: [String]) -> [String] {
        sections
            .map(sanitizedResponseText)
            .map(cleanPlainTextFragment)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                !$0.caseInsensitiveContains("<think") &&
                !looksLikeStructuredOutput($0)
            }
    }

    static func plainTextPayload(
        from text: String,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let fragments = plainTextFragments(from: text, preserveHeadline: true)
        guard !fragments.isEmpty else { return nil }

        var headline = baseResult.answerTitle
        var sections = fragments
        if let first = sections.first, isLikelyPlainTextHeadline(first) {
            headline = cleanPlainTextHeadline(first).ifEmpty(baseResult.answerTitle)
            sections.removeFirst()
        }

        sections = sections
            .map(cleanPlainTextFragment)
            .filter { !$0.isEmpty && $0 != headline }
        guard !sections.isEmpty else { return nil }

        return normalizedPayload(
            AlphaMatterAskRuntimePayload(
                headline: headline,
                sections: Array(sections.prefix(3)),
                statusNote: baseResult.statusNote ?? "Private assistant"
            ),
            baseResult: baseResult
        )
    }

    static func plainTextFragments(from text: String, preserveHeadline: Bool) -> [String] {
        let sanitized = sanitizedResponseText(text)
            .replacingOccurrences(of: "```", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty, !looksLikeStructuredOutput(sanitized) else { return [] }

        let bulletSeparated = sanitized
            .replacingOccurrences(of: #"(^|\s)[\*•]\s+"#, with: "\n- ", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*-\s+"#, with: "\n- ", options: .regularExpression)

        let blockFragments: [String]
        if bulletSeparated.contains("\n- ") {
            blockFragments = bulletSeparated
                .components(separatedBy: "\n- ")
                .map { block in
                    block
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                }
                .map(cleanPlainTextFragment)
                .filter { !$0.isEmpty }
        } else {
            blockFragments = []
        }

        let rawFragments = blockFragments.isEmpty
            ? bulletSeparated
                .components(separatedBy: .newlines)
                .flatMap { line -> [String] in
                    let cleanedLine = cleanPlainTextFragment(line)
                    guard !cleanedLine.isEmpty else { return [] }
                    if cleanedLine.contains(" - ") {
                        return cleanedLine
                            .components(separatedBy: " - ")
                            .map(cleanPlainTextFragment)
                            .filter { !$0.isEmpty }
                    }
                    return [cleanedLine]
                }
            : blockFragments

        return rawFragments
            .map { preserveHeadline ? $0 : cleanPlainTextHeadline($0) }
            .filter {
                !$0.isEmpty &&
                !$0.caseInsensitiveContains("<think") &&
                !looksLikeStructuredOutput($0)
            }
    }

    static func cleanPlainTextHeadline(_ text: String) -> String {
        cleanPlainTextFragment(text)
            .replacingOccurrences(
                of: #"(?i)^(heading|headline|title|answer)\s*:\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanPlainTextFragment(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"(?i)^\s*json\s*(?=\{)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*[\-•\*]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;:!?\)])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([\(\[])\s+"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\w)\s*-\s*(?=\w)"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isLikelyPlainTextHeadline(_ text: String) -> Bool {
        let cleaned = cleanPlainTextFragment(text)
        guard !cleaned.isEmpty else { return false }
        if cleaned.range(of: #"(?i)^(heading|headline|title|answer)\s*:"#, options: .regularExpression) != nil {
            return true
        }
        if cleaned.count <= 72,
           cleaned.components(separatedBy: ". ").count == 1,
           cleaned.range(of: #"(?i)\b(date|next steps|should|must|because|source)\b"#, options: .regularExpression) == nil {
            return true
        }
        return false
    }

    static func lenientPayload(
        from text: String,
        baseResult: AlphaAskResult
    ) -> AlphaMatterAskRuntimePayload? {
        let normalized = text
            .replacingOccurrences(of: #"(?i)^\s*json\s*(?=\{)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("headline") || normalized.contains("sections") else { return nil }

        let headline = extractLenientScalar(for: "headline", in: normalized)?
            .ifEmpty(baseResult.answerTitle) ?? baseResult.answerTitle
        let statusNote = extractLenientScalar(for: "statusNote", in: normalized)?
            .ifEmpty(baseResult.statusNote ?? "Private assistant")
        let strictSections = extractLenientSections(in: normalized)
        let sections = strictSections.isEmpty ? extractLooseQuotedSections(in: normalized) : strictSections
        guard !sections.isEmpty else { return nil }

        return normalizedPayload(
            AlphaMatterAskRuntimePayload(
                headline: headline,
                sections: sections,
                statusNote: statusNote
            ),
            baseResult: baseResult
        )
    }

    static func extractLenientScalar(for key: String, in text: String) -> String? {
        let quotedPattern = #"(?is)\b\#(key)\b\s*:?\s*"((?:\\.|[^"\\])*)""#
        if let value = firstRegexCapture(pattern: quotedPattern, in: text) {
            return value
                .replacingOccurrences(of: #"\""#, with: #"""#)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }

        let barePattern = #"(?is)\b\#(key)\b\s*:?\s*([^,\]\}]+)"#
        return firstRegexCapture(pattern: barePattern, in: text)?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: #""'"#)))
            .nilIfEmpty
    }

    static func extractLenientSections(in text: String) -> [String] {
        guard let body = firstRegexCapture(pattern: #"(?is)\bsections\b\s*:?\s*\[(.*?)\]"#, in: text) else {
            return []
        }

        let quoted = extractJSONStringArray(for: "sections", in: #""sections":[\#(body)]"#)
        if !quoted.isEmpty { return quoted }

        return body
            .components(separatedBy: ".,")
            .flatMap { $0.components(separatedBy: "\n") }
            .map {
                $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: #","'"#)))
            }
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty }
    }

    static func extractLooseQuotedSections(in text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: #"(?i)^\s*json\s*(?=\{)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "```", with: " ")
        guard normalized.contains("headline") else { return [] }
        guard let regex = try? NSRegularExpression(pattern: #""((?:\\.|[^"\\])*)""#, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(normalized.startIndex..., in: normalized)
        let fragments = regex.matches(in: normalized, range: nsRange).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: normalized) else { return nil }
            let raw = String(normalized[range])
                .replacingOccurrences(of: #"\""#, with: #"""#)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = raw.lowercased()
            guard raw.count >= 20 else { return nil }
            guard !["headline", "sections", "statusnote", "status note"].contains(lowered) else { return nil }
            return raw
        }

        return Array(fragments.prefix(3))
    }

    static func firstRegexCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}

private func alphaEmptyMatterAskBaseResult() -> AlphaAskResult {
    AlphaAskResult(
        kind: .userAsk,
        question: "",
        scopeCaseID: nil,
        scopeLabel: "",
        selectedDocumentTitles: [],
        answerTitle: "",
        answerSections: [],
        caseFileSources: [],
        publicLawPreview: nil,
        publicLawResults: [],
        statusNote: nil
    )
}

struct AlphaReviewQueueItem: Identifiable, Hashable {
    var caseId: UUID
    var documentId: UUID
    var caseTitle: String
    var title: String
    var detail: String
    var sourceRef: AlphaSourceRef?
    var target: AlphaReviewQueueTarget

    var id: String {
        "\(caseId.uuidString)-\(documentId.uuidString)-\(target.idSuffix)"
    }
}

enum AlphaReviewQueueTarget: Hashable {
    case extractedField(UUID)
    case finding(UUID)

    var idSuffix: String {
        switch self {
        case .extractedField(let id):
            "field-\(id.uuidString)"
        case .finding(let id):
            "finding-\(id.uuidString)"
        }
    }
}

typealias AlphaPublicLawSearchAction = @Sendable (AlphaPublicLawPreview) async throws -> [AlphaPublicLawResult]

let alphaScreenPadding: CGFloat = 16
let alphaDocumentScreenHorizontalPadding: CGFloat = 12
let alphaSectionSpacing: CGFloat = 16
let alphaReviewAccentWidth: CGFloat = 3
let alphaRossSuggestedTaskNotePrefix = "ross-overview::"
let alphaSharedWorkspaceID = UUID(uuidString: "0D9E5220-4D3C-4B49-9A67-10B42B593B7D")!

struct AlphaAskDocumentOption: Identifiable, Hashable {
    let id: UUID
    let caseId: UUID
    let caseTitle: String
    let title: String
    let fileName: String
    let kind: AlphaDocumentKind
    let isShared: Bool

    var displayTitle: String {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFileName.isEmpty ? title : trimmedFileName
    }

    var badgeTitle: String {
        let ext = (displayTitle as NSString).pathExtension.uppercased()
        if !ext.isEmpty {
            return ext
        }
        switch kind {
        case .pdf:
            return "PDF"
        case .image:
            return "IMG"
        case .text:
            return "TXT"
        case .unknown:
            return "FILE"
        }
    }

    func compactDetail(scopeCaseID: UUID?) -> String {
        let location: String
        if isShared {
            location = "General files"
        } else if scopeCaseID == nil {
            location = caseTitle
        } else {
            location = "This matter"
        }
        return "\(kind.title) · \(location)"
    }
}

func alphaAskCompactSnippet(from value: String?) -> String? {
    guard let value else { return nil }
    let cleaned = value
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return nil }
    return String(cleaned.prefix(180))
}

struct AlphaRecentDocumentItem: Identifiable {
    let caseId: UUID
    let caseTitle: String
    let document: AlphaCaseDocument

    var id: UUID { document.id }
}

struct AlphaAssistantStatusSnapshot {
    let title: String
    let detail: String
    let tint: Color
}

struct AlphaStorageSnapshot {
    let documentCount: Int
    let exportCount: Int
    let documentBytes: Int64
    let exportBytes: Int64
    let assistantBytes: Int64

    var totalBytes: Int64 {
        documentBytes + exportBytes + assistantBytes
    }
}

@MainActor
@Observable
final class AlphaRossModel {
    enum DockCommandAction: Hashable {
        case addTask(title: String, dueDate: Date?)
        case completeTask(title: String)
        case addMatterDate(title: String, kind: AlphaMatterDateKind, date: Date)
        case generateExport(kind: String, label: String)
        case rerunDocumentReview
        case createTasksFromDocument
        case runRoutine(AlphaRoutineKind)
        case guidance(title: String, detail: String)
    }

    let store: AlphaRossStore
    @ObservationIgnored let backend: AlphaBackendClient
    @ObservationIgnored let publicLawSearchAction: AlphaPublicLawSearchAction

    var persisted = AlphaPersistedState.empty() {
        didSet {
            // Hot-path performance: every persisted-state write (including a
            // single chat-turn field update) fires this didSet. We MUST keep
            // the body cheap. The expensive O(N*M*K) refresh-key computation
            // and disk-recovery snapshot rebuild are scheduled via a debounced
            // task instead of running synchronously here. See
            // scheduleDebouncedPrivateAISnapshotRefresh().
            invalidateWorkspaceDerivedState()
            syncPrivateAISnapshotFromPersisted()
            scheduleDebouncedPrivateAISnapshotRefresh()
        }
    }
    var path: [AlphaRoute] = []
    var selectedCaseID: UUID?
    var selectedTier: AlphaCapabilityTier = .flash
    var caseDraftTitle = ""
    var askDrafts: [UUID: String] = [:]
    var globalAskDraft = ""
    var askSelectedScopeCaseID: UUID?
    var askSelectedDocumentIDs: [UUID: Set<UUID>] = [:]
    var globalAskSelectedDocumentIDs: Set<UUID> = []
    var askWebEnabled = false
    var pendingIncomingDocumentURLs: [URL] = []
    var pendingPublicLawQuestion: String?
    var pendingPublicLawScopeCaseID: UUID?
    var pendingPublicLawSessionID: UUID?
    var pendingPublicLawTurnID: UUID?
    var latestAskResult: AlphaAskResult?
    var askHistory: [AlphaAskResult] = []
    var publicLawDraft = ""
    var publicLawPreview: AlphaPublicLawPreview?
    var publicLawResults: [AlphaPublicLawResult] = []
    var publicLawSearchStatus: AlphaPublicLawSearchStatus = .idle
    var publicLawSearchInFlight: Bool { publicLawSearchStatus == .running }
    var localInferenceSmokeReport: AlphaLocalInferenceSmokeReport?
    var localInferenceSmokeRunning = false
    var privateAISnapshot = AlphaPrivateAISnapshot()
    var refreshingCaseOverviewIDs: Set<UUID> = []
    var loaded = false
    @ObservationIgnored var workspaceRevision: UInt64 = 0
    @ObservationIgnored var cachedWorkspaceRevision: UInt64 = .max
    @ObservationIgnored var workspaceDerivedState = AlphaWorkspaceDerivedState()
    @ObservationIgnored var assistantDownloadTaskBoxes: [UUID: AlphaAssistantDownloadTaskBox] = [:]
    @ObservationIgnored var privateAISnapshotTask: Task<Void, Never>?
    @ObservationIgnored var privateAISnapshotRefreshKey: AlphaPrivateAISnapshotRefreshKey?
    @ObservationIgnored var pendingPersistTask: Task<Void, Never>?
    @ObservationIgnored var debouncedSnapshotRefreshTask: Task<Void, Never>?

    init(
        store: AlphaRossStore = AlphaRossStore(),
        publicLawSearchAction: AlphaPublicLawSearchAction? = nil,
        previewState: AlphaPersistedState? = nil,
        previewPath: [AlphaRoute] = []
    ) {
        self.store = store
        let backend = AlphaBackendClient()
        self.backend = backend
        self.publicLawSearchAction = publicLawSearchAction ?? { preview in
            try await backend.searchPublicLaw(preview: preview)
        }
        self.globalAskDraft = ""

        if let previewState {
            persisted = normalizeLoadedState(previewState)
            invalidateWorkspaceDerivedState()
            path = previewPath
            syncDerivedStateFromPersisted()
            syncPrivateAISnapshotFromPersisted()
            refreshPrivateAISnapshot(forceValidation: true)
            loaded = true
        }
    }
}

actor AlphaBackendClient {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    func fetchCatalog(for tier: AlphaCapabilityTier) async throws -> AlphaBackendCatalogManifest {
        let configuration = AlphaBackendConfiguration()
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent("model-catalog"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "tier", value: tier.rawValue)
        ]
        guard let url = components?.url else {
            throw AlphaBackendError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeout
        applySessionHeaders(to: &request, configuration: configuration)

        let response: AlphaBackendCatalogResponse = try await send(request, expecting: AlphaBackendCatalogResponse.self)
        return response.manifest.payload
    }

    func createDownloadSession(for packId: String) async throws -> AlphaBackendDownloadSessionPayload {
        let configuration = AlphaBackendConfiguration()
        let requestBody = AlphaBackendDownloadSessionRequest(
            accountToken: configuration.accountToken,
            packId: packId,
            platform: "ios",
            deviceIdHash: configuration.deviceIdHash,
            appVersion: configuration.appVersion
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("model-download/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        applySessionHeaders(to: &request, configuration: configuration)

        let response: AlphaBackendDownloadSessionResponse = try await send(request, expecting: AlphaBackendDownloadSessionResponse.self)
        return response.downloadSession.payload
    }

    func searchPublicLaw(preview: AlphaPublicLawPreview) async throws -> [AlphaPublicLawResult] {
        let configuration = AlphaBackendConfiguration()
        let requestBody = AlphaBackendPublicLawSearchRequest(
            query: preview.query,
            jurisdiction: "IN-ALL",
            language: "en",
            confirmedPublicPreview: true,
            consent: AlphaBackendPublicLawConsent(
                mode: "settings_web_search_enabled",
                version: "2026-04-store-v1"
            )
        )

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("public-law/search"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        applySessionHeaders(to: &request, configuration: configuration)

        let response: AlphaBackendPublicLawResponse = try await send(request, expecting: AlphaBackendPublicLawResponse.self)
        return response.results.map {
            AlphaPublicLawResult(
                title: $0.title,
                citation: $0.citation,
                snippet: $0.snippet,
                sourceName: $0.source
            )
        }
    }

    func downloadArtifact(
        session: AlphaBackendDownloadSessionPayload,
        onProgress: @escaping @Sendable (Int64) async -> Void
    ) async throws -> AlphaDownloadedArtifact {
        let configuration = AlphaBackendConfiguration()
        let artifactURL = try resolveArtifactURL(for: session.artifact, configuration: configuration)
        var downloaded = Data()
        downloaded.reserveCapacity(Int(session.artifact.sizeBytes))

        for segment in session.artifact.segments {
            var request = URLRequest(url: artifactURL)
            request.httpMethod = "GET"
            request.timeoutInterval = configuration.requestTimeout
            request.setValue(segment.rangeHeader, forHTTPHeaderField: "Range")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw AlphaBackendError.unavailable
            }
            guard sha256Hex(data) == segment.sha256.lowercased() else {
                throw AlphaBackendError.segmentIntegrityFailed
            }

            downloaded.append(data)
            await onProgress(Int64(downloaded.count))
        }

        guard Int64(downloaded.count) == session.artifact.sizeBytes else {
            throw AlphaBackendError.invalidResponse
        }
        guard sha256Hex(downloaded) == session.artifact.finalSha256.lowercased() else {
            throw AlphaBackendError.finalIntegrityFailed
        }

        return AlphaDownloadedArtifact(data: downloaded, bytes: Int64(downloaded.count))
    }

    func resolveArtifactURL(
        for artifact: AlphaBackendArtifact,
        configuration: AlphaBackendConfiguration = AlphaBackendConfiguration()
    ) throws -> URL {
        if let downloadPath = artifact.downloadPath {
            return configuration.baseURL.appendingPathComponent(downloadPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        guard let url = URL(string: artifact.downloadUrl) else {
            throw AlphaBackendError.invalidResponse
        }

        if url.host == "downloads.example.invalid" {
            return configuration.baseURL.appendingPathComponent(url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        return url
    }

    func applySessionHeaders(
        to request: inout URLRequest,
        configuration: AlphaBackendConfiguration = AlphaBackendConfiguration()
    ) {
        request.setValue(configuration.accountToken, forHTTPHeaderField: "X-Ross-Account-Token")
        if let accessToken = configuration.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    func send<Response: Decodable>(_ request: URLRequest, expecting type: Response.Type) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaBackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AlphaBackendError.unavailable
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AlphaBackendError.invalidResponse
        }
    }
}

struct AlphaBackendConfiguration {
    let baseURL: URL
    let requestTimeout: TimeInterval = 25
    var accountToken: String {
        RossAuthSessionSnapshot.shared.accountToken(fallback: "acct_local_alpha_device")
    }
    var accessToken: String? {
        RossAuthSessionSnapshot.shared.accessToken()
    }
    let appVersion = "0.1.0-alpha"
    let deviceIdHash = sha256Hex(Data("ross-ios-alpha-device".utf8))

    init() {
        baseURL = rossBackendBaseURL()
    }
}

struct AlphaBackendSignedEnvelope<Payload: Codable>: Codable {
    let payload: Payload
}

struct AlphaBackendCatalogResponse: Codable {
    let manifest: AlphaBackendSignedEnvelope<AlphaBackendCatalogManifest>
}

struct AlphaBackendCatalogManifest: Codable {
    let packs: [AlphaBackendCatalogPack]
}

struct AlphaBackendCatalogPack: Codable {
    let packId: String
    let displayName: String
    let tier: AlphaCapabilityTier
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
}

struct AlphaBackendDownloadSessionRequest: Codable {
    let accountToken: String
    let packId: String
    let platform: String
    let deviceIdHash: String
    let appVersion: String
}

struct AlphaBackendDownloadSessionResponse: Codable {
    let downloadSession: AlphaBackendSignedEnvelope<AlphaBackendDownloadSessionPayload>
}

struct AlphaBackendDownloadSessionPayload: Codable {
    let sessionId: String
    let packId: String
    let artifact: AlphaBackendArtifact
}

struct AlphaBackendArtifact: Codable {
    let fileName: String
    let sizeBytes: Int64
    let finalSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let downloadPath: String?
    let downloadUrl: String
    let segments: [AlphaBackendArtifactSegment]
}

struct AlphaBackendArtifactSegment: Codable {
    let index: Int
    let startByte: Int64
    let endByteInclusive: Int64
    let sizeBytes: Int64
    let sha256: String
    let rangeHeader: String
}

struct AlphaBackendPublicLawSearchRequest: Codable {
    let query: String
    let jurisdiction: String
    let language: String
    let confirmedPublicPreview: Bool
    let consent: AlphaBackendPublicLawConsent
}

struct AlphaBackendPublicLawConsent: Codable {
    let mode: String
    let version: String
}

struct AlphaBackendPublicLawResponse: Codable {
    let results: [AlphaBackendPublicLawResult]
}

struct AlphaBackendPublicLawResult: Codable {
    let source: String
    let title: String
    let citation: String
    let snippet: String
}

struct AlphaDownloadedArtifact {
    let data: Data
    let bytes: Int64
}

struct AlphaAssistantModelArtifact: Hashable, Sendable {
    let tier: AlphaCapabilityTier
    let packId: String
    let displayName: String
    let repository: String
    let fileName: String
    let quantization: String
    let downloadURLString: String
    let sizeBytes: Int64
    let sha256: String
    let minimumMemoryGB: Int
    let recommendedMemoryGB: Int
    let requiredFreeSpaceGB: Int
    let recommendedPhone: String
    let sourcePageURLString: String
    let downloadSource: String
    let verified: Bool
    let releaseReady: Bool
    let licenseNotice: String
    let safetyNotice: String
    let isActiveTier: Bool

    var downloadURL: URL? {
        URL(string: downloadURLString)
    }

    var sourceLabel: String {
        "Hugging Face · \(repository)"
    }

    var sizeLabel: String {
        switch tier {
        case .flash:
            "about 3.0 GB"
        case .quickStart:
            "about 3.5 GB"
        case .caseAssociate:
            "about 5.4 GB"
        case .seniorDraftingSupport:
            "about 17.0 GB"
        }
    }

    var requirementLabel: String {
        "Min \(minimumMemoryGB) GB memory · Rec \(recommendedMemoryGB) GB · \(requiredFreeSpaceGB) GB free"
    }
}

let alphaAssistantModelArtifacts: [AlphaCapabilityTier: AlphaAssistantModelArtifact] = [
    .flash: AlphaAssistantModelArtifact(
        tier: .flash,
        packId: "gemma-4-e2b-q2",
        displayName: "Gemma 4 E2B Q2_K",
        repository: "bartowski/google_gemma-4-E2B-it-GGUF",
        fileName: "google_gemma-4-E2B-it-Q2_K.gguf",
        quantization: "Q2_K",
        downloadURLString: "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q2_K.gguf",
        sizeBytes: 3_020_052_224,
        sha256: "a7cfc9f9b305b54a4ba2a681ff8795f594eafbe8c2c9df25d2f030a64d97bda6",
        minimumMemoryGB: 3,
        recommendedMemoryGB: 4,
        requiredFreeSpaceGB: 4,
        recommendedPhone: "Fastest setup — simple answers.",
        sourcePageURLString: "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF",
        downloadSource: "huggingface",
        verified: true,
        releaseReady: true,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    ),
    .quickStart: AlphaAssistantModelArtifact(
        tier: .quickStart,
        packId: "gemma-4-e2b-q4",
        displayName: "Gemma 4 E2B Q4_K_M",
        repository: "bartowski/google_gemma-4-E2B-it-GGUF",
        fileName: "google_gemma-4-E2B-it-Q4_K_M.gguf",
        quantization: "Q4_K_M",
        downloadURLString: "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q4_K_M.gguf",
        sizeBytes: 3_462_678_272,
        sha256: "b5310340b3a23d31655d7119d100d5df1b2d8ee17b3ca8b0a23ad7e9eb5fa705",
        minimumMemoryGB: 3,
        recommendedMemoryGB: 4,
        requiredFreeSpaceGB: 4,
        recommendedPhone: "Fastest setup — intake, checklists, quick summaries.",
        sourcePageURLString: "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF",
        downloadSource: "huggingface",
        verified: true,
        releaseReady: true,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    ),
    .caseAssociate: AlphaAssistantModelArtifact(
        tier: .caseAssociate,
        packId: "gemma-4-e4b-q4",
        displayName: "Gemma 4 E4B Q4_K_M",
        repository: "bartowski/google_gemma-4-E4B-it-GGUF",
        fileName: "google_gemma-4-E4B-it-Q4_K_M.gguf",
        quantization: "Q4_K_M",
        downloadURLString: "https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF/resolve/main/google_gemma-4-E4B-it-Q4_K_M.gguf",
        sizeBytes: 5_405_168_384,
        sha256: "51865750adafd22de56994a343d5a887cc1a589b9bae41d62b748c8bd0ca9c76",
        minimumMemoryGB: 4,
        recommendedMemoryGB: 6,
        requiredFreeSpaceGB: 6,
        recommendedPhone: "Chronology, issue extraction, missing-fact analysis, longer notes.",
        sourcePageURLString: "https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF",
        downloadSource: "huggingface",
        verified: true,
        releaseReady: true,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    ),
    .seniorDraftingSupport: AlphaAssistantModelArtifact(
        tier: .seniorDraftingSupport,
        packId: "gemma-4-26b-a4b-q4",
        displayName: "Gemma 4 26B-A4B Q4_K_M",
        repository: "bartowski/google_gemma-4-26B-A4B-it-GGUF",
        fileName: "google_gemma-4-26B-A4B-it-Q4_K_M.gguf",
        quantization: "Q4_K_M",
        downloadURLString: "https://huggingface.co/bartowski/google_gemma-4-26B-A4B-it-GGUF/resolve/main/google_gemma-4-26B-A4B-it-Q4_K_M.gguf",
        sizeBytes: 17_035_038_112,
        sha256: "e718536fe9b4bd505b07d44ded8f1595053a5d5407315bccf555ce592f33c140",
        minimumMemoryGB: 12,
        recommendedMemoryGB: 20,
        requiredFreeSpaceGB: 18,
        recommendedPhone: "Advanced drafting, workstation or high-end device mode.",
        sourcePageURLString: "https://huggingface.co/bartowski/google_gemma-4-26B-A4B-it-GGUF",
        downloadSource: "huggingface",
        verified: true,
        releaseReady: true,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    )
]

func alphaAssistantModelArtifact(for tier: AlphaCapabilityTier) -> AlphaAssistantModelArtifact {
    alphaAssistantModelArtifacts[tier] ?? alphaAssistantModelArtifacts[.caseAssociate]!
}

final class AlphaAssistantDownloadTaskBox: @unchecked Sendable {
    var task: URLSessionDownloadTask?
    var session: URLSession?
    var progressTask: Task<Void, Never>?
    var pausedByUser = false
    var resumeData: Data?
    var lastPublishedProgressBytes: Int64 = 0
    var lastPublishedProgressAt: Date = .distantPast
}

final class AlphaBackgroundModelDownloadCenter: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = AlphaBackgroundModelDownloadCenter()

    typealias ProgressHandler = @Sendable (Int64, Int64) async -> Void

    private struct Entry {
        var continuation: CheckedContinuation<URL, any Error>
        var destinationURL: URL
        var progress: ProgressHandler
        var session: URLSession
        var finishedURL: URL?
    }

    private let lock = NSLock()
    private var entries: [Int: Entry] = [:]
    private var taskIdentifierByJobID: [UUID: Int] = [:]
    private var taskByIdentifier: [Int: URLSessionDownloadTask] = [:]
    private var sessionsByIdentifier: [String: URLSession] = [:]
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

    func download(
        request: URLRequest,
        jobID: UUID,
        resumeData: Data?,
        allowsMobileData: Bool,
        destinationURL: URL,
        progress: @escaping ProgressHandler
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let configuration = URLSessionConfiguration.default
            configuration.allowsCellularAccess = allowsMobileData
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 120
            configuration.timeoutIntervalForResource = 10_800
            if #available(iOS 13.0, macOS 10.15, *) {
                configuration.allowsExpensiveNetworkAccess = allowsMobileData
                configuration.allowsConstrainedNetworkAccess = allowsMobileData
            }

            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: request)
            let entry = Entry(
                continuation: continuation,
                destinationURL: destinationURL,
                progress: progress,
                session: session
            )
            lock.lock()
            entries[task.taskIdentifier] = entry
            taskIdentifierByJobID[jobID] = task.taskIdentifier
            taskByIdentifier[task.taskIdentifier] = task
            lock.unlock()
            task.resume()
        }
    }

    func cancel(jobID: UUID, completion: @escaping @Sendable (Data?) -> Void) {
        lock.lock()
        let taskIdentifier = taskIdentifierByJobID[jobID]
        let task = taskIdentifier.flatMap { taskByIdentifier[$0] }
        lock.unlock()
        guard let task else {
            completion(nil)
            return
        }
        task.cancel { resumeData in
            completion(resumeData)
        }
    }

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void, for identifier: String) {
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        lock.lock()
        backgroundCompletionHandlers[identifier] = handler
        sessionsByIdentifier[identifier] = session
        lock.unlock()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress: ProgressHandler?
        lock.lock()
        progress = entries[downloadTask.taskIdentifier]?.progress
        lock.unlock()
        guard let progress else { return }
        Task {
            await progress(totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        let storedEntry = entries[downloadTask.taskIdentifier]
        lock.unlock()
        guard var entry = storedEntry else { return }

        do {
            try? FileManager.default.removeItem(at: entry.destinationURL)
            try FileManager.default.moveItem(at: location, to: entry.destinationURL)
            entry.finishedURL = entry.destinationURL
            lock.lock()
            entries[downloadTask.taskIdentifier] = entry
            lock.unlock()
        } catch {
            lock.lock()
            entries.removeValue(forKey: downloadTask.taskIdentifier)
            lock.unlock()
            entry.continuation.resume(throwing: error)
            session.invalidateAndCancel()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        lock.lock()
        let entry = entries.removeValue(forKey: task.taskIdentifier)
        taskByIdentifier.removeValue(forKey: task.taskIdentifier)
        taskIdentifierByJobID = taskIdentifierByJobID.filter { $0.value != task.taskIdentifier }
        if let identifier = session.configuration.identifier {
            sessionsByIdentifier.removeValue(forKey: identifier)
        }
        lock.unlock()
        guard let entry else { return }

        if let error {
            entry.continuation.resume(throwing: error)
        } else if let finishedURL = entry.finishedURL {
            entry.continuation.resume(returning: finishedURL)
        } else {
            entry.continuation.resume(throwing: AlphaAssistantDownloadError.missingDownloadedFile)
        }
        session.finishTasksAndInvalidate()
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }
        lock.lock()
        let handler = backgroundCompletionHandlers.removeValue(forKey: identifier)
        lock.unlock()
        DispatchQueue.main.async {
            handler?()
        }
    }
}

enum AlphaAssistantDownloadError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case preflightMissingSize
    case preflightSizeMismatch(expected: Int64, reported: Int64)
    case preflightNotResumable
    case preflightChecksumMismatch(catalog: String, provider: String)
    case rangeProbeInvalidStatus(Int)
    case rangeProbeInvalidLength(expected: Int64, received: Int64)
    case rangeProbeInvalidContentRange(String)
    case insufficientStorage(requiredGB: Int, availableGB: Int)
    case missingDownloadedFile
    case pausedByUser

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The selected private assistant download link is invalid."
        case .httpStatus(let status):
            return "The assistant download service returned status \(status). Try again on Wi-Fi."
        case .preflightMissingSize:
            return "Ross could not confirm the private assistant file size before downloading."
        case .preflightSizeMismatch(let expected, let reported):
            let expectedLabel = ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)
            let reportedLabel = ByteCountFormatter.string(fromByteCount: reported, countStyle: .file)
            return "The assistant download listing changed from \(expectedLabel) to \(reportedLabel). Ross stopped setup before downloading."
        case .preflightNotResumable:
            return "The assistant download cannot be safely resumed right now. Retry later on Wi-Fi."
        case .preflightChecksumMismatch:
            return "The assistant download listing changed before setup could start. Ross stopped setup before downloading."
        case .rangeProbeInvalidStatus(let status):
            return "The assistant download service could not resume from the saved position. Status \(status)."
        case .rangeProbeInvalidLength(let expected, let received):
            return "The assistant download resume check returned \(received) bytes; Ross expected \(expected)."
        case .rangeProbeInvalidContentRange(let value):
            return "The assistant download resume check returned an unexpected position: \(value)."
        case .insufficientStorage(let requiredGB, let availableGB):
            return "This private assistant needs about \(requiredGB) GB free. This iPhone currently reports \(availableGB) GB free."
        case .missingDownloadedFile:
            return "Assistant setup is missing or incomplete. Open My assistant and use Repair setup."
        case .pausedByUser:
            return "Assistant setup is paused."
        }
    }
}

struct AlphaAssistantRangeProbe: Hashable, Sendable {
    let startByte: Int64
    let endByte: Int64
    let totalBytes: Int64
    let receivedBytes: Int64

    static func parse(response: HTTPURLResponse, receivedBytes: Int64, expectedStart: Int64, expectedEnd: Int64, expectedTotal: Int64) throws -> AlphaAssistantRangeProbe {
        guard response.statusCode == 206 else {
            throw AlphaAssistantDownloadError.rangeProbeInvalidStatus(response.statusCode)
        }
        let expectedBytes = expectedEnd - expectedStart + 1
        guard receivedBytes == expectedBytes else {
            throw AlphaAssistantDownloadError.rangeProbeInvalidLength(expected: expectedBytes, received: receivedBytes)
        }
        let headers = alphaHTTPHeaders(from: response)
        guard let value = headers["content-range"] else {
            throw AlphaAssistantDownloadError.rangeProbeInvalidContentRange("missing")
        }
        let parsed = try parseContentRange(value)
        guard parsed.start == expectedStart,
              parsed.end == expectedEnd,
              expectedTotal <= 0 || parsed.total == expectedTotal else {
            throw AlphaAssistantDownloadError.rangeProbeInvalidContentRange(value)
        }
        return AlphaAssistantRangeProbe(
            startByte: parsed.start,
            endByte: parsed.end,
            totalBytes: parsed.total,
            receivedBytes: receivedBytes
        )
    }

    private static func parseContentRange(_ value: String) throws -> (start: Int64, end: Int64, total: Int64) {
        let pattern = #"^bytes\s+(\d+)-(\d+)/(\d+)$"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let startRange = Range(match.range(at: 1), in: value),
              let endRange = Range(match.range(at: 2), in: value),
              let totalRange = Range(match.range(at: 3), in: value),
              let start = Int64(value[startRange]),
              let end = Int64(value[endRange]),
              let total = Int64(value[totalRange]) else {
            throw AlphaAssistantDownloadError.rangeProbeInvalidContentRange(value)
        }
        return (start, end, total)
    }
}

struct AlphaAssistantDownloadPreflight: Hashable, Sendable {
    let reportedBytes: Int64
    let acceptsRanges: Bool
    let providerChecksumSha256: String?

    var effectiveChecksumSha256: String? {
        providerChecksumSha256
    }

    func expectedChecksum(catalogChecksum: String) throws -> String {
        let catalog = catalogChecksum.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let provider = providerChecksumSha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !catalog.isEmpty, let provider, !provider.isEmpty, catalog != provider {
            throw AlphaAssistantDownloadError.preflightChecksumMismatch(catalog: catalog, provider: provider)
        }
        if !catalog.isEmpty {
            return catalog
        }
        return provider ?? ""
    }

    static func parse(response: HTTPURLResponse, expectedBytes: Int64) throws -> AlphaAssistantDownloadPreflight {
        guard (200...299).contains(response.statusCode) else {
            throw AlphaAssistantDownloadError.httpStatus(response.statusCode)
        }
        let headers = alphaHTTPHeaders(from: response)
        let reportedBytes = headers["x-linked-size"].flatMap(Int64.init)
            ?? headers["content-length"].flatMap(Int64.init)
        guard let reportedBytes, reportedBytes > 0 else {
            throw AlphaAssistantDownloadError.preflightMissingSize
        }
        guard expectedBytes <= 0 || reportedBytes == expectedBytes else {
            throw AlphaAssistantDownloadError.preflightSizeMismatch(expected: expectedBytes, reported: reportedBytes)
        }

        let acceptRanges = alphaAcceptsByteRanges(headers["accept-ranges"])
        guard acceptRanges else {
            throw AlphaAssistantDownloadError.preflightNotResumable
        }

        let checksum = [headers["x-linked-etag"], headers["etag"], headers["x-xet-hash"]]
            .compactMap { $0?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .first(where: alphaLooksLikeSHA256Hex)

        return AlphaAssistantDownloadPreflight(
            reportedBytes: reportedBytes,
            acceptsRanges: acceptRanges,
            providerChecksumSha256: checksum?.lowercased()
        )
    }
}

private func alphaHTTPHeaders(from response: HTTPURLResponse) -> [String: String] {
    response.allHeaderFields.reduce(into: [String: String]()) { headers, item in
        guard let key = item.key as? String else { return }
        headers[key.lowercased()] = String(describing: item.value)
    }
}

private func alphaAcceptsByteRanges(_ value: String?) -> Bool {
    guard let value else { return false }
    return value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .contains("bytes")
}

private func alphaLooksLikeSHA256Hex(_ value: String) -> Bool {
    guard value.count == 64 else { return false }
    return value.unicodeScalars.allSatisfy { scalar in
        ("0"..."9").contains(Character(scalar)) ||
            ("a"..."f").contains(Character(String(scalar).lowercased()))
    }
}

enum AlphaBackendError: Error {
    case unavailable
    case invalidResponse
    case missingPack
    case segmentIntegrityFailed
    case finalIntegrityFailed
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func alphaAllowsDevelopmentModelArtifacts() -> Bool {
    // Development packs are placeholder artifacts used only for unit/UI tests.
    // They are NEVER enabled for the normal simulator/device app run, because
    // they would short-circuit the real model download and silently install a
    // fake artifact that cannot answer questions. Only opt-in explicitly via
    // env var, or implicitly via XCTest.
    let environment = ProcessInfo.processInfo.environment
    if environment["ROSS_DISABLE_DEVELOPMENT_MODEL_ARTIFACTS"] == "1" {
        return false
    }
    if environment["ROSS_ALLOW_DEVELOPMENT_MODEL_ARTIFACTS"] == "1" {
        return true
    }
    if environment["XCTestConfigurationFilePath"] != nil || environment["ROSS_RUNNING_TESTS"] == "1" {
        return true
    }
    return Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
}

func alphaSupportsDownloadedAssistantModels() -> Bool {
    return true
}

func alphaSystemAssistantPack(for tier: AlphaCapabilityTier) -> AlphaInstalledModelPack {
    let packId = "apple-foundation-models-\(tier.rawValue)"
    let checksum = sha256Hex(Data("ross-system-private-assistant:\(tier.rawValue)".utf8))
    return AlphaInstalledModelPack(
        packId: packId,
        tier: tier,
        installPath: "system://apple-foundation-models",
        checksumSha256: checksum,
        artifactKind: "system_model",
        runtimeMode: .appleFoundationModels,
        developmentOnly: false,
        checksumVerified: true,
        minimumAppVersion: "0.1.0-alpha",
        isActive: true
    )
}

extension AlphaRossModel {
    var freeDiskSpaceLabel: String {
        privateAISnapshot.freeDiskSpaceLabel
    }
}
