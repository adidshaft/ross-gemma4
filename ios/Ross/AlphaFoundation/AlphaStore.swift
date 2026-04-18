import CryptoKit
import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

func alphaSupportRootURL() -> URL {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return supportURL.appendingPathComponent("RossAlpha", isDirectory: true)
}

func alphaAbsoluteURL(for relativePath: String) -> URL {
    alphaSupportRootURL().appendingPathComponent(relativePath)
}

struct AlphaImportedDocument {
    let document: AlphaCaseDocument
    let storedFileURL: URL
}

actor AlphaRossStore {
    private let fileManager = FileManager.default
    private let rootURL: URL
    private let stateURL: URL
    private let documentsURL: URL
    private let modelPacksURL: URL
    private let exportsURL: URL

    init() {
        rootURL = alphaSupportRootURL()
        stateURL = rootURL.appendingPathComponent("state.json")
        documentsURL = rootURL.appendingPathComponent("documents", isDirectory: true)
        modelPacksURL = rootURL.appendingPathComponent("model-packs", isDirectory: true)
        exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
    }

    func load() throws -> AlphaPersistedState {
        try ensureFolders()

        guard fileManager.fileExists(atPath: stateURL.path()) else {
            let seed = AlphaPersistedState.seed()
            try save(seed)
            return seed
        }

        let data = try Data(contentsOf: stateURL)
        return try JSONDecoder.ross.decode(AlphaPersistedState.self, from: data)
    }

    @discardableResult
    func mutate(_ transform: (inout AlphaPersistedState) -> Void) throws -> AlphaPersistedState {
        var state = try load()
        transform(&state)
        try save(state)
        return state
    }

    func replace(with state: AlphaPersistedState) throws {
        try save(state)
    }

    func importDocument(from sourceURL: URL, into caseId: UUID) throws -> AlphaImportedDocument {
        let ext = sourceURL.pathExtension.lowercased()
        let kind: AlphaDocumentKind
        switch ext {
        case "pdf":
            kind = .pdf
        case "png", "jpg", "jpeg", "heic":
            kind = .image
        case "txt", "md":
            kind = .text
        default:
            kind = .unknown
        }

        let documentFolder = documentsURL.appendingPathComponent(caseId.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: documentFolder, withIntermediateDirectories: true)

        let storedFileName = "\(UUID().uuidString).\(ext.isEmpty ? "bin" : ext)"
        let destinationURL = documentFolder.appendingPathComponent(storedFileName)

        if fileManager.fileExists(atPath: destinationURL.path()) {
            try fileManager.removeItem(at: destinationURL)
        }

        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let pageCount: Int
        #if canImport(PDFKit)
        if kind == .pdf, let pdf = PDFDocument(url: destinationURL) {
            pageCount = max(pdf.pageCount, 1)
        } else {
            pageCount = 1
        }
        #else
        pageCount = 1
        #endif

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let pages = (1...pageCount).map { AlphaDocumentPage(pageNumber: $0, snippet: pageCount == 1 ? "Imported source reference." : "Imported page \($0).") }

        let extractedText: String?
        if kind == .text {
            extractedText = try? String(contentsOf: destinationURL).prefix(2_000).description
        } else {
            extractedText = nil
        }

        let document = AlphaCaseDocument(
            title: title,
            fileName: sourceURL.lastPathComponent,
            kind: kind,
            storedRelativePath: relativePath(for: destinationURL),
            importedAt: .now,
            pageCount: pageCount,
            ocrStatus: kind == .text ? .indexed : .placeholder,
            extractedText: extractedText,
            pages: pages
        )

        return AlphaImportedDocument(document: document, storedFileURL: destinationURL)
    }

    func writeDevPackArtifact(for tier: AlphaCapabilityTier) throws -> (relativePath: String, checksum: String, bytes: Int64) {
        try ensureFolders()
        let folder = modelPacksURL.appendingPathComponent(tier.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let artifactURL = folder.appendingPathComponent("pack.dev")
        let payload = """
        Ross Private AI Pack
        tier=\(tier.rawValue)
        generated_at=\(Date().ISO8601Format())
        note=development artifact for checksum and install-state plumbing
        """
        let data = Data(payload.utf8)
        try data.write(to: artifactURL, options: .atomic)
        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return (relativePath(for: artifactURL), checksum, Int64(data.count))
    }

    func createTextExport(title: String, kind: String, caseId: UUID?, body: String) throws -> AlphaExportedReport {
        try ensureFolders()
        let fileName = "\(safeFileName(title))-\(UUID().uuidString.prefix(8)).txt"
        let targetURL = exportsURL.appendingPathComponent(fileName)
        try body.write(to: targetURL, atomically: true, encoding: .utf8)
        return AlphaExportedReport(caseId: caseId, title: title, kind: kind, relativePath: relativePath(for: targetURL))
    }

    private func save(_ state: AlphaPersistedState) throws {
        try ensureFolders()
        let data = try JSONEncoder.ross.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    private func ensureFolders() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelPacksURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    }

    private func safeFileName(_ value: String) -> String {
        let sanitized = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return sanitized.isEmpty ? "ross-export" : sanitized
    }

    private func relativePath(for url: URL) -> String {
        String(url.path().dropFirst(rootURL.path().count + 1))
    }
}

private extension JSONEncoder {
    static var ross: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var ross: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
