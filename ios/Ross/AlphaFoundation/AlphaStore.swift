import CryptoKit
import CoreGraphics
import CoreText
import Foundation
import Security
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Vision)
import Vision
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
    private let encryptedStateURL: URL
    private let legacyStateURL: URL
    private let recoveryURL: URL
    private let documentsURL: URL
    private let modelPacksURL: URL
    private let exportsURL: URL
    private let keychainAccount = "ross.ios.alpha.state"

    init() {
        rootURL = alphaSupportRootURL()
        encryptedStateURL = rootURL.appendingPathComponent("state.enc")
        legacyStateURL = rootURL.appendingPathComponent("state.json")
        recoveryURL = rootURL.appendingPathComponent("recovery", isDirectory: true)
        documentsURL = rootURL.appendingPathComponent("documents", isDirectory: true)
        modelPacksURL = rootURL.appendingPathComponent("model-packs", isDirectory: true)
        exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
    }

    func load() throws -> AlphaPersistedState {
        try ensureFolders()

        if fileManager.fileExists(atPath: encryptedStateURL.path()) {
            do {
                let data = try Data(contentsOf: encryptedStateURL)
                return try decryptState(from: data)
            } catch {
                try stashCorruptState()

                if fileManager.fileExists(atPath: legacyStateURL.path()) {
                    let migrated = try loadLegacyPlaintext()
                    let upgraded = migrated.withStorageLedger(
                        title: "Alpha state encrypted locally",
                        detail: "Legacy alpha state was moved into encrypted app-private storage."
                    )
                    try save(upgraded)
                    return upgraded
                }

                let recovered = AlphaPersistedState.seed().withStorageLedger(
                    title: "Alpha state recovered locally",
                    detail: "Encrypted alpha state was unreadable, so Ross reset local alpha state and kept a recovery copy in app-private storage."
                )
                try save(recovered)
                return recovered
            }
        }

        if fileManager.fileExists(atPath: legacyStateURL.path()) {
            let migrated = try loadLegacyPlaintext()
            let upgraded = migrated.withStorageLedger(
                title: "Alpha state encrypted locally",
                detail: "Legacy alpha state was moved into encrypted app-private storage."
            )
            try save(upgraded)
            return upgraded
        }

        let seed = AlphaPersistedState.seed()
        try save(seed)
        return seed
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

        let title = sourceURL.deletingPathExtension().lastPathComponent
        let extraction = try extractDocumentContent(kind: kind, from: destinationURL)
        let pageCount = max(extraction.pages.count, 1)
        let pages = extraction.pages.isEmpty
            ? [AlphaDocumentPage(pageNumber: 1, snippet: "Imported source reference.")]
            : extraction.pages

        let document = AlphaCaseDocument(
            title: title,
            fileName: sourceURL.lastPathComponent,
            kind: kind,
            storedRelativePath: relativePath(for: destinationURL),
            importedAt: .now,
            pageCount: pageCount,
            ocrStatus: extraction.ocrStatus,
            indexingStatus: extraction.indexingStatus,
            extractedText: extraction.extractedText,
            dominantSourceSnippet: extraction.dominantSourceSnippet,
            lastIndexedAt: extraction.extractedText == nil ? nil : .now,
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

    func installDownloadedPackArtifact(
        for tier: AlphaCapabilityTier,
        fileName: String,
        data: Data,
        expectedChecksum: String
    ) throws -> (relativePath: String, checksum: String, bytes: Int64) {
        try ensureFolders()
        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard checksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
            throw NSError(domain: "RossAlphaPack", code: 2, userInfo: [NSLocalizedDescriptionKey: "Checksum verification failed."])
        }

        let folder = modelPacksURL.appendingPathComponent(tier.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let artifactURL = folder.appendingPathComponent(fileName)
        try data.write(to: artifactURL, options: .atomic)
        return (relativePath(for: artifactURL), checksum, Int64(data.count))
    }

    func createPDFExport(title: String, kind: String, caseId: UUID?, bodyLines: [String]) throws -> AlphaExportedReport {
        try ensureFolders()
        let fileName = "\(safeFileName(title))-\(UUID().uuidString.prefix(8)).pdf"
        let targetURL = exportsURL.appendingPathComponent(fileName)
        try writePDF(to: targetURL, title: title, bodyLines: bodyLines)
        return AlphaExportedReport(caseId: caseId, title: title, kind: kind, relativePath: relativePath(for: targetURL))
    }

    private func save(_ state: AlphaPersistedState) throws {
        try ensureFolders()
        let data = try JSONEncoder.ross.encode(state)
        try encryptState(data).write(to: encryptedStateURL, options: .atomic)
        if fileManager.fileExists(atPath: legacyStateURL.path()) {
            try? fileManager.removeItem(at: legacyStateURL)
        }
    }

    private func ensureFolders() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: recoveryURL, withIntermediateDirectories: true)
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

    private func loadLegacyPlaintext() throws -> AlphaPersistedState {
        let data = try Data(contentsOf: legacyStateURL)
        let state = try JSONDecoder.ross.decode(AlphaPersistedState.self, from: data)
        try? fileManager.removeItem(at: legacyStateURL)
        return state
    }

    private func extractDocumentContent(kind: AlphaDocumentKind, from url: URL) throws -> AlphaDocumentExtraction {
        switch kind {
        case .pdf:
            #if canImport(PDFKit)
            return extractPDFContent(from: url)
            #else
            return AlphaDocumentExtraction(
                pages: [AlphaDocumentPage(pageNumber: 1, snippet: "PDF imported locally. Native text extraction is unavailable in this build.")],
                extractedText: nil,
                dominantSourceSnippet: nil,
                ocrStatus: .placeholder,
                indexingStatus: .notStarted
            )
            #endif
        case .image:
            return extractImageContent(from: url)
        case .text:
            let text = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = compactSnippet(from: text)
            return AlphaDocumentExtraction(
                pages: [
                    AlphaDocumentPage(
                        pageNumber: 1,
                        snippet: snippet,
                        extractedText: text.isEmpty ? nil : text,
                        anchorText: snippet,
                        ocrConfidence: 1,
                        ocrStatus: text.isEmpty ? .failed : .nativeText,
                        indexingStatus: text.isEmpty ? .failed : .indexed
                    )
                ],
                extractedText: text.isEmpty ? nil : text,
                dominantSourceSnippet: snippet,
                ocrStatus: text.isEmpty ? .failed : .nativeText,
                indexingStatus: text.isEmpty ? .failed : .indexed
            )
        case .unknown:
            return AlphaDocumentExtraction(
                pages: [AlphaDocumentPage(pageNumber: 1, snippet: "Imported source reference.")],
                extractedText: nil,
                dominantSourceSnippet: nil,
                ocrStatus: .placeholder,
                indexingStatus: .notStarted
            )
        }
    }

    #if canImport(PDFKit)
    private func extractPDFContent(from url: URL) -> AlphaDocumentExtraction {
        guard let pdf = PDFDocument(url: url) else {
            return AlphaDocumentExtraction(
                pages: [AlphaDocumentPage(pageNumber: 1, snippet: "PDF imported locally. Text extraction is unavailable for this file.")],
                extractedText: nil,
                dominantSourceSnippet: nil,
                ocrStatus: .failed,
                indexingStatus: .failed
            )
        }

        let pageCount = max(pdf.pageCount, 1)
        var pages: [AlphaDocumentPage] = []
        var extractedChunks: [String] = []
        var pagesWithText = 0

        for pageIndex in 0..<pageCount {
            let pageNumber = pageIndex + 1
            let nativeText = compactExtractedText(pdf.page(at: pageIndex)?.string)
            let snippet = compactSnippet(from: nativeText)
            if let nativeText, !nativeText.isEmpty {
                extractedChunks.append(nativeText)
                pagesWithText += 1
            }

            pages.append(
                AlphaDocumentPage(
                    pageNumber: pageNumber,
                    snippet: snippet ?? "Imported page \(pageNumber).",
                    extractedText: nativeText,
                    anchorText: snippet,
                    ocrConfidence: nativeText == nil ? nil : 0.99,
                    ocrStatus: nativeText == nil ? .placeholder : .nativeText,
                    indexingStatus: nativeText == nil ? .notStarted : .indexed
                )
            )
        }

        let extractedText = extractedChunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let overallStatus: AlphaOcrStatus
        let indexingStatus: AlphaIndexingStatus
        switch pagesWithText {
        case 0:
            overallStatus = .placeholder
            indexingStatus = .notStarted
        case pageCount:
            overallStatus = .nativeText
            indexingStatus = .indexed
        default:
            overallStatus = .partial
            indexingStatus = .partial
        }

        return AlphaDocumentExtraction(
            pages: pages,
            extractedText: extractedText.isEmpty ? nil : extractedText,
            dominantSourceSnippet: compactSnippet(from: extractedText),
            ocrStatus: overallStatus,
            indexingStatus: indexingStatus
        )
    }
    #endif

    private func extractImageContent(from url: URL) -> AlphaDocumentExtraction {
        #if canImport(Vision)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(url: url).perform([request])
            let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            let text = candidates.map(\.string).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let confidence = candidates.isEmpty ? nil : Double(candidates.map(\.confidence).reduce(0, +) / Float(candidates.count))
            let snippet = compactSnippet(from: text)

            return AlphaDocumentExtraction(
                pages: [
                    AlphaDocumentPage(
                        pageNumber: 1,
                        snippet: snippet ?? "Imported image page.",
                        extractedText: text.isEmpty ? nil : text,
                        anchorText: snippet,
                        ocrConfidence: confidence,
                        ocrStatus: text.isEmpty ? .failed : .ocrComplete,
                        indexingStatus: text.isEmpty ? .failed : .indexed
                    )
                ],
                extractedText: text.isEmpty ? nil : text,
                dominantSourceSnippet: snippet,
                ocrStatus: text.isEmpty ? .failed : .ocrComplete,
                indexingStatus: text.isEmpty ? .failed : .indexed
            )
        } catch {
            return AlphaDocumentExtraction(
                pages: [AlphaDocumentPage(pageNumber: 1, snippet: "Imported image page. OCR could not run locally.")],
                extractedText: nil,
                dominantSourceSnippet: nil,
                ocrStatus: .failed,
                indexingStatus: .failed
            )
        }
        #else
        return AlphaDocumentExtraction(
            pages: [AlphaDocumentPage(pageNumber: 1, snippet: "Imported image page. OCR is unavailable in this build.")],
            extractedText: nil,
            dominantSourceSnippet: nil,
            ocrStatus: .placeholder,
            indexingStatus: .notStarted
        )
        #endif
    }

    private func writePDF(to url: URL, title: String, bodyLines: [String]) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "RossAlphaPDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create PDF context."])
        }

        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 18, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .left
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.alignment = .left
        bodyParagraph.lineBreakMode = .byWordWrapping

        let attributed = NSMutableAttributedString(
            string: "\(title)\n\n",
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): titleFont,
                .paragraphStyle: titleParagraph
            ]
        )
        attributed.append(
            NSAttributedString(
                string: bodyLines.joined(separator: "\n"),
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): bodyFont,
                    .paragraphStyle: bodyParagraph
                ]
            )
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var currentRange = CFRange(location: 0, length: 0)
        let insetRect = CGRect(x: 40, y: 40, width: mediaBox.width - 80, height: mediaBox.height - 80)

        repeat {
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)

            let path = CGMutablePath()
            path.addRect(insetRect)
            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            currentRange.location += visibleRange.length
            context.endPDFPage()
        } while currentRange.location < attributed.length

        context.closePDF()
    }

    private func encryptState(_ data: Data) throws -> Data {
        let key = try fetchOrCreateStateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        let envelope = AlphaEncryptedEnvelope(version: 1, combinedData: sealedBox.combined ?? Data())
        return try JSONEncoder().encode(envelope)
    }

    private func decryptState(from data: Data) throws -> AlphaPersistedState {
        let envelope = try JSONDecoder().decode(AlphaEncryptedEnvelope.self, from: data)
        let key = try fetchOrCreateStateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: envelope.combinedData)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder.ross.decode(AlphaPersistedState.self, from: decrypted)
    }

    private func fetchOrCreateStateKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ross.ios.alpha.state",
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }

        let keyData = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "ross.ios.alpha.state",
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            return try fetchOrCreateStateKey()
        }
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }

        return SymmetricKey(data: keyData)
    }

    private func stashCorruptState() throws {
        guard fileManager.fileExists(atPath: encryptedStateURL.path()) else { return }
        let target = recoveryURL.appendingPathComponent("state-\(Int(Date().timeIntervalSince1970)).enc.bad")
        try? fileManager.copyItem(at: encryptedStateURL, to: target)
        try? fileManager.removeItem(at: encryptedStateURL)
    }
}

private struct AlphaDocumentExtraction {
    let pages: [AlphaDocumentPage]
    let extractedText: String?
    let dominantSourceSnippet: String?
    let ocrStatus: AlphaOcrStatus
    let indexingStatus: AlphaIndexingStatus
}

private func compactExtractedText(_ value: String?) -> String? {
    let trimmed = value?.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
}

private func compactSnippet(from value: String?) -> String? {
    guard let text = compactExtractedText(value) else { return nil }
    return String(text.prefix(180))
}

private struct AlphaEncryptedEnvelope: Codable {
    let version: Int
    let combinedBase64: String

    init(version: Int, combinedData: Data) {
        self.version = version
        self.combinedBase64 = combinedData.base64EncodedString()
    }

    var combinedData: Data {
        Data(base64Encoded: combinedBase64) ?? Data()
    }
}

private extension AlphaPersistedState {
    func withStorageLedger(title: String, detail: String) -> AlphaPersistedState {
        let entry = AlphaPrivacyLedgerEntry(
            title: title,
            detail: detail,
            purpose: .local_only,
            payloadClass: .local_only,
            endpointLabel: "device://storage",
            success: true
        )
        if ledgerEntries.contains(where: { $0.title == entry.title && $0.detail == entry.detail }) {
            return self
        }
        var copy = self
        copy.ledgerEntries.insert(entry, at: 0)
        return copy
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
