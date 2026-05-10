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
        }

        let paragraphs = humanReadableParagraphs(from: sanitizedRawText)
        guard !paragraphs.isEmpty else { return nil }
        return normalizedPayload(
            AlphaMatterAskRuntimePayload(
                headline: baseResult.answerTitle,
                sections: Array(paragraphs.prefix(3)),
                statusNote: baseResult.statusNote ?? "Private assistant"
            ),
            baseResult: baseResult
        )
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractLikelyJSON(from text: String) -> String? {
        guard let startIndex = text.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        let candidate = text[startIndex...]
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
        text.components(separatedBy: "\n\n")
            .flatMap { block -> [String] in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("\n- ") || trimmed.hasPrefix("- ") {
                    return trimmed
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
                return [trimmed]
            }
            .map {
                $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            .filter {
                !$0.isEmpty &&
                !$0.caseInsensitiveContains("<think") &&
                !looksLikeStructuredOutput($0)
            }
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
        }

        guard !looksLikeStructuredOutput(sanitized) else { return [] }
        return humanReadableParagraphs(from: sanitized)
    }

    static func normalizedDisplaySections(_ sections: [String]) -> [String] {
        sections
            .map(sanitizedResponseText)
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                !$0.caseInsensitiveContains("<think") &&
                !looksLikeStructuredOutput($0)
            }
    }
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
        case guidance(title: String, detail: String)
    }

    let store: AlphaRossStore
    @ObservationIgnored let backend: AlphaBackendClient
    @ObservationIgnored let publicLawSearchAction: AlphaPublicLawSearchAction

    var persisted = AlphaPersistedState.empty() {
        didSet {
            invalidateWorkspaceDerivedState()
        }
    }
    var path: [AlphaRoute] = []
    var selectedCaseID: UUID?
    var selectedTier: AlphaCapabilityTier = .caseAssociate
    var caseDraftTitle = ""
    var askDrafts: [UUID: String] = [:]
    var globalAskDraft = ""
    var askSelectedScopeCaseID: UUID?
    var askSelectedDocumentIDs: [UUID: Set<UUID>] = [:]
    var globalAskSelectedDocumentIDs: Set<UUID> = []
    var askWebEnabled = false
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
    var refreshingCaseOverviewIDs: Set<UUID> = []
    var loaded = false
    @ObservationIgnored var workspaceRevision: UInt64 = 0
    @ObservationIgnored var cachedWorkspaceRevision: UInt64 = .max
    @ObservationIgnored var workspaceDerivedState = AlphaWorkspaceDerivedState()

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
        case .quickStart:
            "about 430 MB"
        case .caseAssociate:
            "about 1.1-1.3 GB"
        case .seniorDraftingSupport:
            "about 2.5 GB"
        }
    }

    var requirementLabel: String {
        "Min \(minimumMemoryGB) GB memory · Rec \(recommendedMemoryGB) GB · \(requiredFreeSpaceGB) GB free"
    }
}

let alphaAssistantModelArtifacts: [AlphaCapabilityTier: AlphaAssistantModelArtifact] = [
    .quickStart: AlphaAssistantModelArtifact(
        tier: .quickStart,
        packId: "gemma-4-e2b-q4",
        displayName: "Gemma 4 E2B Q4",
        repository: "google/gemma-4-E2B-it",
        fileName: "gemma-4-e2b-q4.gguf",
        quantization: "Q4",
        downloadURLString: "__REPLACE_WITH_VERIFIED_GEMMA4_E2B_Q4_ARTIFACT_URL__",
        sizeBytes: 1_600_000_000,
        sha256: "__REPLACE_WITH_VERIFIED_SHA256__",
        minimumMemoryGB: 4,
        recommendedMemoryGB: 6,
        requiredFreeSpaceGB: 2,
        recommendedPhone: "Fastest local setup for intake and checklists.",
        sourcePageURLString: "https://huggingface.co/google/gemma-4-E2B-it",
        downloadSource: "huggingface",
        verified: false,
        releaseReady: false,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    ),
    .caseAssociate: AlphaAssistantModelArtifact(
        tier: .caseAssociate,
        packId: "gemma-4-e4b-q4",
        displayName: "Gemma 4 E4B Q4",
        repository: "google/gemma-4-E4B-it",
        fileName: "gemma-4-e4b-q4.gguf",
        quantization: "Q4",
        downloadURLString: "__REPLACE_WITH_VERIFIED_GEMMA4_E4B_Q4_ARTIFACT_URL__",
        sizeBytes: 2_800_000_000,
        sha256: "__REPLACE_WITH_VERIFIED_SHA256__",
        minimumMemoryGB: 6,
        recommendedMemoryGB: 8,
        requiredFreeSpaceGB: 4,
        recommendedPhone: "Chronology building, issue extraction, missing-fact analysis.",
        sourcePageURLString: "https://huggingface.co/google/gemma-4-E4B-it",
        downloadSource: "huggingface",
        verified: false,
        releaseReady: false,
        licenseNotice: "Gemma License",
        safetyNotice: "Review generated content.",
        isActiveTier: true
    ),
    .seniorDraftingSupport: AlphaAssistantModelArtifact(
        tier: .seniorDraftingSupport,
        packId: "gemma-4-26b-a4b-q4",
        displayName: "Gemma 4 26B-A4B Q4",
        repository: "google/gemma-4-26B-A4B-it",
        fileName: "gemma-4-26b-a4b-q4.gguf",
        quantization: "Q4",
        downloadURLString: "__REPLACE_WITH_VERIFIED_GEMMA4_26B_A4B_Q4_ARTIFACT_URL__",
        sizeBytes: 16_000_000_000,
        sha256: "__REPLACE_WITH_VERIFIED_SHA256__",
        minimumMemoryGB: 16,
        recommendedMemoryGB: 24,
        requiredFreeSpaceGB: 20,
        recommendedPhone: "Advanced drafting, clinic workstation mode.",
        sourcePageURLString: "https://huggingface.co/google/gemma-4-26B-A4B-it",
        downloadSource: "huggingface",
        verified: false,
        releaseReady: false,
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
    var progressTask: Task<Void, Never>?
    var pausedByUser = false
}

enum AlphaAssistantDownloadError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case insufficientStorage(requiredGB: Int, availableGB: Int)
    case missingDownloadedFile
    case pausedByUser

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The selected private assistant download link is invalid."
        case .httpStatus(let status):
            return "The private assistant download returned HTTP \(status)."
        case .insufficientStorage(let requiredGB, let availableGB):
            return "This private assistant needs about \(requiredGB) GB free. This iPhone currently reports \(availableGB) GB free."
        case .missingDownloadedFile:
            return "Ross could not find the downloaded assistant file."
        case .pausedByUser:
            return "Assistant setup is paused."
        }
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
    #if canImport(SwiftGemmaRuntime)
    return true
    #else
    return false
    #endif
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
