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

var alphaAssistantExistingSetupRepairDetail: String {
    rossLocalized("assistant_existing_setup_repair_detail")
}

func alphaPrivateAIDocumentContextLine(_ document: AlphaCaseDocument, languageCode: String = rossSelectedLanguageCode()) -> String {
    "- \(document.title) (\(alphaPageCountLabel(document.pageCount, languageCode: languageCode)), \(document.ocrStatus.title(languageCode: languageCode)))"
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private final class AlphaAssistantPreflightRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

@discardableResult
private func alphaPurgeTemporaryAssistantDownloadFiles() -> Int64 {
    alphaSweepTemporaryAssistantDownloads()
}

struct AlphaAssistantCatalogDescriptor: Codable, Hashable, Sendable {
    let tier: AlphaCapabilityTier
    let packId: String
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    var draftArtifact: AlphaAssistantDraftArtifactDescriptor? = nil
}

struct AlphaAssistantDraftArtifactDescriptor: Codable, Hashable, Sendable {
    let fileName: String
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let downloadURLString: String
    let draftTokens: Int?
}

struct AlphaInstalledAssistantDraftArtifact: Codable, Hashable, Sendable {
    let fileName: String
    let relativePath: String
    let checksumSha256: String
    let bytes: Int64
    let artifactKind: String
    let draftTokens: Int?
}

struct AlphaAssistantDownloadDescriptor: Codable, Hashable, Sendable {
    let sessionId: String?
    let packId: String
    let tier: AlphaCapabilityTier
    let fileName: String
    let sizeBytes: Int64
    let segmentSizeBytes: Int64?
    let segmentCount: Int?
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let downloadURLString: String
    let rangeUnit: String?
    let resumeStrategy: String?
    let verified: Bool
    let releaseReady: Bool
    var draftArtifact: AlphaAssistantDraftArtifactDescriptor? = nil

    init(
        sessionId: String?,
        packId: String,
        tier: AlphaCapabilityTier,
        fileName: String,
        sizeBytes: Int64,
        segmentSizeBytes: Int64? = nil,
        segmentCount: Int? = nil,
        checksumSha256: String,
        artifactKind: String,
        runtimeMode: AlphaPackRuntimeMode,
        developmentOnly: Bool,
        downloadURLString: String,
        rangeUnit: String? = nil,
        resumeStrategy: String? = nil,
        verified: Bool,
        releaseReady: Bool,
        draftArtifact: AlphaAssistantDraftArtifactDescriptor? = nil
    ) {
        self.sessionId = sessionId
        self.packId = packId
        self.tier = tier
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.segmentSizeBytes = segmentSizeBytes
        self.segmentCount = segmentCount
        self.checksumSha256 = checksumSha256
        self.artifactKind = artifactKind
        self.runtimeMode = runtimeMode
        self.developmentOnly = developmentOnly
        self.downloadURLString = downloadURLString
        self.rangeUnit = rangeUnit
        self.resumeStrategy = resumeStrategy
        self.verified = verified
        self.releaseReady = releaseReady
        self.draftArtifact = draftArtifact
    }
}

func alphaAssistantDraftArtifactRuntimeMode(
    _ artifact: AlphaAssistantDraftArtifactDescriptor
) -> AlphaPackRuntimeMode? {
    if artifact.fileName.lowercased().hasSuffix(".gguf"),
       artifact.artifactKind.localizedCaseInsensitiveContains("local_model_artifact") {
        return .llamaCppGguf
    }
    if artifact.artifactKind == "mlx_directory" {
        return .mlxSwiftLm
    }
    return nil
}

private func alphaAssistantDraftDownloadDescriptor(
    from resolvedDownload: AlphaAssistantDownloadDescriptor,
    draftArtifact: AlphaAssistantDraftArtifactDescriptor
) -> AlphaAssistantDownloadDescriptor? {
    guard let runtimeMode = alphaAssistantDraftArtifactRuntimeMode(draftArtifact) else {
        return nil
    }
    return AlphaAssistantDownloadDescriptor(
        sessionId: resolvedDownload.sessionId,
        packId: resolvedDownload.packId,
        tier: resolvedDownload.tier,
        fileName: draftArtifact.fileName,
        sizeBytes: draftArtifact.sizeBytes,
        segmentSizeBytes: draftArtifact.sizeBytes,
        segmentCount: 1,
        checksumSha256: draftArtifact.checksumSha256,
        artifactKind: draftArtifact.artifactKind,
        runtimeMode: runtimeMode,
        developmentOnly: resolvedDownload.developmentOnly,
        downloadURLString: draftArtifact.downloadURLString,
        rangeUnit: resolvedDownload.rangeUnit,
        resumeStrategy: resolvedDownload.resumeStrategy,
        verified: resolvedDownload.verified,
        releaseReady: resolvedDownload.releaseReady,
        draftArtifact: nil
    )
}

private func alphaReusableAssistantDownloadDescriptor(
    _ descriptor: AlphaAssistantDownloadDescriptor
) -> AlphaAssistantDownloadDescriptor {
    AlphaAssistantDownloadDescriptor(
        sessionId: nil,
        packId: descriptor.packId,
        tier: descriptor.tier,
        fileName: descriptor.fileName,
        sizeBytes: descriptor.sizeBytes,
        segmentSizeBytes: descriptor.segmentSizeBytes,
        segmentCount: descriptor.segmentCount,
        checksumSha256: descriptor.checksumSha256,
        artifactKind: descriptor.artifactKind,
        runtimeMode: descriptor.runtimeMode,
        developmentOnly: descriptor.developmentOnly,
        downloadURLString: descriptor.downloadURLString,
        rangeUnit: descriptor.rangeUnit,
        resumeStrategy: descriptor.resumeStrategy,
        verified: descriptor.verified,
        releaseReady: descriptor.releaseReady,
        draftArtifact: descriptor.draftArtifact
    )
}

private func alphaBundledMLXDraftArtifact(
    from descriptor: AlphaAssistantDownloadDescriptor,
    draftTokens: Int? = nil
) -> AlphaAssistantDraftArtifactDescriptor {
    AlphaAssistantDraftArtifactDescriptor(
        fileName: descriptor.fileName,
        sizeBytes: descriptor.sizeBytes,
        checksumSha256: descriptor.checksumSha256,
        artifactKind: descriptor.artifactKind,
        downloadURLString: descriptor.downloadURLString,
        draftTokens: draftTokens
    )
}

private let alphaBundledMLXQuickStartAssistantDownloadDescriptor = AlphaAssistantDownloadDescriptor(
    sessionId: nil,
    packId: "gemma-4-e4b-mlx",
    tier: .quickStart,
    fileName: "gemma-4-E4B-it-qat-4bit",
    sizeBytes: 6_830_817_013,
    checksumSha256: "d5136c22cf188651815a37112af019d87b80ae9a778c818eb9ea1f1546fd5258",
    artifactKind: "mlx_directory",
    runtimeMode: .mlxSwiftLm,
    developmentOnly: false,
    downloadURLString: "https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-4bit",
    verified: true,
    releaseReady: true,
    draftArtifact: alphaBundledMLXDraftArtifact(
        from: alphaBundledMLXQuickStartAssistantDraftDownloadDescriptor
    )
)

private let alphaBundledMLXQuickStartAssistantDraftDownloadDescriptor = AlphaAssistantDownloadDescriptor(
    sessionId: nil,
    packId: "gemma-4-e4b-mlx-assistant",
    tier: .quickStart,
    fileName: "gemma-4-E4B-it-qat-assistant-6bit",
    sizeBytes: 97_060_772,
    checksumSha256: "4e68124531565049b030e6ed916298092959ef60902b1b378d2ba7217fa4248b",
    artifactKind: "mlx_directory",
    runtimeMode: .mlxSwiftLm,
    developmentOnly: false,
    downloadURLString: "https://huggingface.co/mlx-community/gemma-4-E4B-it-qat-assistant-6bit",
    verified: true,
    releaseReady: true
)

private let alphaBundledMLXCaseAssociateAssistantDraftDownloadDescriptor = AlphaAssistantDownloadDescriptor(
    sessionId: nil,
    packId: "gemma-4-12b-mlx-assistant",
    tier: .caseAssociate,
    fileName: "gemma-4-12B-it-qat-assistant-4bit",
    sizeBytes: 270_093_545,
    checksumSha256: "a23f17aac65a4eb32672daaab7954aff6dd49e35a3a821804bf4e7aef68f0276",
    artifactKind: "mlx_directory",
    runtimeMode: .mlxSwiftLm,
    developmentOnly: false,
    downloadURLString: "https://huggingface.co/mlx-community/gemma-4-12B-it-qat-assistant-4bit",
    verified: true,
    releaseReady: true
)

private let alphaBundledMLXCaseAssociateAssistantDownloadDescriptor = AlphaAssistantDownloadDescriptor(
    sessionId: nil,
    packId: "gemma-4-12b-mlx",
    tier: .caseAssociate,
    fileName: "gemma-4-12B-it-qat-4bit",
    sizeBytes: 11_020_138_609,
    checksumSha256: "19535ea037791e35f81f17a27c1f9c53bc3e9b61512676d6f4074270793f67e5",
    artifactKind: "mlx_directory",
    runtimeMode: .mlxSwiftLm,
    developmentOnly: false,
    downloadURLString: "https://huggingface.co/mlx-community/gemma-4-12B-it-qat-4bit",
    verified: true,
    releaseReady: true,
    draftArtifact: alphaBundledMLXDraftArtifact(
        from: alphaBundledMLXCaseAssociateAssistantDraftDownloadDescriptor
    )
)

private let alphaBundledMLXAssistantDownloadDescriptors: [AlphaCapabilityTier: AlphaAssistantDownloadDescriptor] = [
    .quickStart: alphaBundledMLXQuickStartAssistantDownloadDescriptor,
    .caseAssociate: alphaBundledMLXCaseAssociateAssistantDownloadDescriptor
]

private func alphaBundledAssistantDownloadDescriptor(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil
) -> AlphaAssistantDownloadDescriptor? {
    guard preferredRuntimeMode == .mlxSwiftLm,
          let bundled = alphaBundledMLXAssistantDownloadDescriptors[tier],
          alphaAssistantTierSupportsInstallerRuntime(bundled.tier, runtimeMode: bundled.runtimeMode) else {
        return nil
    }
    if let targetPackId,
       !targetPackId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       bundled.packId != targetPackId {
        return nil
    }
    return bundled
}

private func alphaBundledAssistantCatalogDescriptor(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil
) -> AlphaAssistantCatalogDescriptor? {
    guard let descriptor = alphaBundledAssistantDownloadDescriptor(
        for: tier,
        preferredRuntimeMode: preferredRuntimeMode,
        targetPackId: targetPackId
    ) else {
        return nil
    }
    return AlphaAssistantCatalogDescriptor(
        tier: descriptor.tier,
        packId: descriptor.packId,
        sizeBytes: descriptor.sizeBytes,
        checksumSha256: descriptor.checksumSha256,
        artifactKind: descriptor.artifactKind,
        runtimeMode: descriptor.runtimeMode,
        developmentOnly: descriptor.developmentOnly,
        draftArtifact: descriptor.draftArtifact
    )
}

private func alphaDirectMLXRepositoryArtifact(
    fileName: String,
    artifactKind: String,
    runtimeMode: AlphaPackRuntimeMode,
    downloadURLString: String
) -> Bool {
    guard runtimeMode == .mlxSwiftLm,
          artifactKind == "mlx_directory",
          !alphaPackagedMLXArchiveArtifact(
            fileName: fileName,
            artifactKind: artifactKind,
            runtimeMode: runtimeMode
          ),
          let url = URL(string: downloadURLString),
          let host = url.host?.lowercased(),
          host == "huggingface.co" else {
        return false
    }
    let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
    return components.count == 2
}

private func alphaMLXArtifactRequiresUnsupportedOptiQRuntime(
    packId: String? = nil,
    fileName: String? = nil,
    downloadURLString: String? = nil
) -> Bool {
    [packId, fileName, downloadURLString].contains { value in
        value?.localizedCaseInsensitiveContains("optiq") == true
    }
}

private func alphaDirectMLXRepositoryID(
    for descriptor: AlphaAssistantDownloadDescriptor
) -> String? {
    guard alphaDirectMLXRepositoryArtifact(
        fileName: descriptor.fileName,
        artifactKind: descriptor.artifactKind,
        runtimeMode: descriptor.runtimeMode,
        downloadURLString: descriptor.downloadURLString
    ), let url = URL(string: descriptor.downloadURLString) else {
        return nil
    }
    let components = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
    guard components.count == 2 else { return nil }
    return components.joined(separator: "/")
}

private struct AlphaHuggingFaceRepositoryTreeEntry: Decodable, Hashable, Sendable {
    let path: String
    let size: Int64?
    let type: String?
}

private func alphaIncludedDirectMLXRepositoryEntries(
    from entries: [AlphaHuggingFaceRepositoryTreeEntry]
) -> [AlphaHuggingFaceRepositoryTreeEntry] {
    entries
        .filter { entry in
            let trimmedPath = entry.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty,
                  entry.type?.localizedCaseInsensitiveCompare("directory") != .orderedSame else {
                return false
            }
            let lastComponent = (trimmedPath as NSString).lastPathComponent.lowercased()
            return lastComponent != ".gitattributes" && lastComponent != "readme.md"
        }
        .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func alphaDirectMLXRepositoryEntriesRequireUnsupportedOptiQRuntime(
    _ entries: [AlphaHuggingFaceRepositoryTreeEntry]
) -> Bool {
    entries.contains { entry in
        let trimmedPath = entry.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return false
        }
        let lastComponent = (trimmedPath as NSString).lastPathComponent.lowercased()
        return lastComponent == "kv_config.json" ||
            lastComponent == "optiq_metadata.json" ||
            lastComponent.hasPrefix("optiq_")
    }
}

private func alphaHuggingFaceRepositoryTreeURL(repoID: String) -> URL? {
    let components = repoID
        .split(separator: "/", omittingEmptySubsequences: true)
        .map(String.init)
    guard components.count == 2 else { return nil }
    var urlComponents = URLComponents()
    urlComponents.scheme = "https"
    urlComponents.host = "huggingface.co"
    urlComponents.path = "/api/models/\(components[0])/\(components[1])/tree/main"
    urlComponents.queryItems = [
        URLQueryItem(name: "recursive", value: "1"),
        URLQueryItem(name: "expand", value: "1")
    ]
    return urlComponents.url
}

private func alphaHuggingFaceRepositoryResolveURL(repoID: String, path: String) -> URL? {
    let repoComponents = repoID
        .split(separator: "/", omittingEmptySubsequences: true)
        .map(String.init)
    guard repoComponents.count == 2 else { return nil }
    let encodedPath = path
        .split(separator: "/", omittingEmptySubsequences: false)
        .map { component in
            String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
        }
        .joined(separator: "/")
    return URL(
        string: "https://huggingface.co/\(repoComponents[0])/\(repoComponents[1])/resolve/main/\(encodedPath)"
    )
}

func alphaAssistantDraftArtifactSupportsCurrentInstaller(_ artifact: AlphaAssistantDraftArtifactDescriptor) -> Bool {
    guard artifact.sizeBytes > 0,
          artifact.checksumSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil,
          !artifact.downloadURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    switch alphaAssistantDraftArtifactRuntimeMode(artifact) {
    case .llamaCppGguf:
        return artifact.fileName.lowercased().hasSuffix(".gguf") &&
            artifact.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(
            fileName: artifact.fileName,
            downloadURLString: artifact.downloadURLString
        ) else {
            return false
        }
        return alphaPackagedMLXArchiveArtifact(
            fileName: artifact.fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: .mlxSwiftLm
        ) || alphaDirectMLXRepositoryArtifact(
            fileName: artifact.fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: .mlxSwiftLm,
            downloadURLString: artifact.downloadURLString
        )
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable, nil:
        return false
    }
}

private func alphaAssistantCatalogDraftArtifactSupportsCurrentInstaller(
    _ artifact: AlphaAssistantDraftArtifactDescriptor
) -> Bool {
    guard artifact.sizeBytes > 0,
          artifact.checksumSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
        return false
    }
    switch alphaAssistantDraftArtifactRuntimeMode(artifact) {
    case .llamaCppGguf:
        return artifact.fileName.lowercased().hasSuffix(".gguf") &&
            artifact.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(
            fileName: artifact.fileName,
            downloadURLString: artifact.downloadURLString
        ) else {
            return false
        }
        return artifact.artifactKind == "mlx_directory"
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable, nil:
        return false
    }
}

private func alphaAssistantTierSupportsInstallerRuntime(
    _ tier: AlphaCapabilityTier,
    runtimeMode: AlphaPackRuntimeMode
) -> Bool {
    switch runtimeMode {
    case .mlxSwiftLm:
        return alphaAssistantTierSupportsMLXRuntime(tier)
    case .llamaCppGguf:
        return true
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaAssistantDownloadDescriptorSupportsCurrentInstaller(_ descriptor: AlphaAssistantDownloadDescriptor) -> Bool {
    guard !descriptor.developmentOnly,
          descriptor.sizeBytes > 0,
          descriptor.checksumSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil,
          alphaAssistantTierSupportsInstallerRuntime(descriptor.tier, runtimeMode: descriptor.runtimeMode),
          !descriptor.downloadURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    if let draftArtifact = descriptor.draftArtifact,
       !alphaAssistantDraftArtifactSupportsCurrentInstaller(draftArtifact) {
        return false
    }
    switch descriptor.runtimeMode {
    case .llamaCppGguf:
        return descriptor.fileName.lowercased().hasSuffix(".gguf") &&
            descriptor.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(
            packId: descriptor.packId,
            fileName: descriptor.fileName,
            downloadURLString: descriptor.downloadURLString
        ) else {
            return false
        }
        return alphaPackagedMLXArchiveArtifact(
            fileName: descriptor.fileName,
            artifactKind: descriptor.artifactKind,
            runtimeMode: descriptor.runtimeMode
        ) || alphaDirectMLXRepositoryArtifact(
            fileName: descriptor.fileName,
            artifactKind: descriptor.artifactKind,
            runtimeMode: descriptor.runtimeMode,
            downloadURLString: descriptor.downloadURLString
        )
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaAssistantCatalogDescriptorSupportsCurrentInstaller(_ descriptor: AlphaAssistantCatalogDescriptor) -> Bool {
    guard !descriptor.developmentOnly,
          descriptor.sizeBytes > 0,
          descriptor.checksumSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil,
          alphaAssistantTierSupportsInstallerRuntime(descriptor.tier, runtimeMode: descriptor.runtimeMode) else {
        return false
    }
    if let draftArtifact = descriptor.draftArtifact,
       !alphaAssistantCatalogDraftArtifactSupportsCurrentInstaller(draftArtifact) {
        return false
    }
    switch descriptor.runtimeMode {
    case .llamaCppGguf:
        return descriptor.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(packId: descriptor.packId) else {
            return false
        }
        return descriptor.artifactKind == "mlx_directory"
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaShouldReuseInstalledAssistantPack(
    _ pack: AlphaInstalledModelPack?,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil,
    preferredDescriptor: AlphaAssistantDownloadDescriptor? = nil,
    forceDownload: Bool = false
) -> Bool {
    guard let pack else { return false }
    guard !forceDownload else { return false }
    guard pack.runtimeMode == preferredRuntimeMode else { return false }

    if let targetPackId,
       !targetPackId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       pack.packId != targetPackId {
        return false
    }

    let hasExplicitTargetPack = !(targetPackId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    if !hasExplicitTargetPack,
       let preferredDescriptor,
       preferredDescriptor.runtimeMode != preferredRuntimeMode {
        return false
    }

    if let preferredDescriptor {
        return alphaInstalledAssistantPackMatchesDownloadDescriptor(pack, descriptor: preferredDescriptor)
    }

    return true
}

func alphaInstalledAssistantPackMatchesDownloadDescriptor(
    _ pack: AlphaInstalledModelPack?,
    descriptor: AlphaAssistantDownloadDescriptor,
    forceDownload: Bool = false
) -> Bool {
    guard let pack else { return false }
    guard !forceDownload else { return false }
    guard pack.tier == descriptor.tier,
          pack.packId == descriptor.packId,
          pack.artifactKind == descriptor.artifactKind,
          pack.runtimeMode == descriptor.runtimeMode,
          pack.developmentOnly == descriptor.developmentOnly else {
        return false
    }
    if !descriptor.checksumSha256.isEmpty {
        guard pack.checksumSha256.caseInsensitiveCompare(descriptor.checksumSha256) == .orderedSame else {
            return false
        }
    }
    guard let descriptorDraft = descriptor.draftArtifact else {
        return true
    }
    guard let expected = alphaExpectedDownloadedAssistantArtifact(for: pack),
          let installedDraft = expected.draftArtifact else {
        return false
    }
    return installedDraft.fileName == descriptorDraft.fileName &&
        installedDraft.bytes == descriptorDraft.sizeBytes &&
        installedDraft.artifactKind == descriptorDraft.artifactKind &&
        alphaModelAssistantChecksumMatches(
            expected: descriptorDraft.checksumSha256,
            actual: installedDraft.checksumSha256
        )
}

func alphaInstalledAssistantPackMatchesCatalogDescriptor(
    _ pack: AlphaInstalledModelPack?,
    descriptor: AlphaAssistantCatalogDescriptor,
    forceDownload: Bool = false
) -> Bool {
    guard let pack else { return false }
    guard !forceDownload else { return false }
    guard pack.tier == descriptor.tier,
          pack.packId == descriptor.packId,
          pack.artifactKind == descriptor.artifactKind,
          pack.runtimeMode == descriptor.runtimeMode,
          pack.developmentOnly == descriptor.developmentOnly else {
        return false
    }
    if !descriptor.checksumSha256.isEmpty {
        guard pack.checksumSha256.caseInsensitiveCompare(descriptor.checksumSha256) == .orderedSame else {
            return false
        }
    }
    return alphaAssistantCatalogDraftArtifactMatchesInstalledPack(pack, descriptor: descriptor)
}

private func alphaAssistantDownloadDescriptorDraftArtifact(
    _ artifact: AlphaBackendArtifactDraft?
) -> AlphaAssistantDraftArtifactDescriptor? {
    guard let artifact else { return nil }
    return AlphaAssistantDraftArtifactDescriptor(
        fileName: artifact.fileName,
        sizeBytes: artifact.sizeBytes,
        checksumSha256: artifact.finalSha256.lowercased(),
        artifactKind: artifact.artifactKind,
        downloadURLString: artifact.downloadUrl,
        draftTokens: artifact.draftTokens
    )
}

private func alphaAssistantCatalogDescriptorDraftArtifact(
    _ artifact: AlphaBackendCatalogDraftArtifact?
) -> AlphaAssistantDraftArtifactDescriptor? {
    guard let artifact else { return nil }
    return AlphaAssistantDraftArtifactDescriptor(
        fileName: artifact.fileName,
        sizeBytes: artifact.sizeBytes,
        checksumSha256: artifact.checksumSha256.lowercased(),
        artifactKind: artifact.artifactKind,
        downloadURLString: "",
        draftTokens: artifact.draftTokens
    )
}

func alphaAssistantCatalogDraftArtifactMatchesInstalledPack(
    _ pack: AlphaInstalledModelPack,
    descriptor: AlphaAssistantCatalogDescriptor
) -> Bool {
    guard let expected = alphaExpectedDownloadedAssistantArtifact(for: pack) else {
        return descriptor.draftArtifact == nil
    }
    switch (expected.draftArtifact, descriptor.draftArtifact) {
    case (nil, nil):
        return true
    case let (installed?, available?):
        return installed.fileName == available.fileName &&
            installed.bytes == available.sizeBytes &&
            installed.artifactKind == available.artifactKind &&
            alphaModelAssistantChecksumMatches(
                expected: available.checksumSha256,
                actual: installed.checksumSha256
            )
    default:
        return false
    }
}

func alphaClearedAssistantUpdateCandidates(
    _ candidates: [AlphaModelUpdateCandidate]?,
    for tier: AlphaCapabilityTier
) -> [AlphaModelUpdateCandidate] {
    (candidates ?? []).filter { $0.tier != tier }
}

func alphaPreferredAssistantDownloadFallback(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]?
) -> AlphaAssistantDownloadDescriptor {
    let cachedCandidates = (cachedDownloads ?? []).filter {
        $0.tier == tier && alphaAssistantDownloadDescriptorSupportsCurrentInstaller($0)
    }
    if let targetPackId,
       let targetedCached = cachedCandidates.first(where: { $0.packId == targetPackId }) {
        return alphaReusableAssistantDownloadDescriptor(targetedCached)
    }
    if let preferredCached = cachedCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode }) {
        return alphaReusableAssistantDownloadDescriptor(preferredCached)
    }
    if let bundledPreferred = alphaBundledAssistantDownloadDescriptor(
        for: tier,
        preferredRuntimeMode: preferredRuntimeMode,
        targetPackId: targetPackId
    ) {
        return bundledPreferred
    }
    if let fallbackCached = cachedCandidates.first {
        return alphaReusableAssistantDownloadDescriptor(fallbackCached)
    }
    return alphaDefaultAssistantDownloadDescriptor(for: tier)
}

func alphaMergedAssistantDownloadCache(
    existing: [AlphaAssistantDownloadDescriptor],
    appending descriptor: AlphaAssistantDownloadDescriptor
) -> [AlphaAssistantDownloadDescriptor] {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(descriptor.tier) ?? descriptor.tier
    var merged = existing.filter {
        let cachedTier = AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ?? $0.tier
        guard cachedTier == effectiveTier else { return true }
        if $0.packId == descriptor.packId {
            return false
        }
        return $0.runtimeMode != descriptor.runtimeMode
    }
    merged.append(descriptor)
    return merged
}

func alphaDefaultAssistantCatalogDescriptor(for tier: AlphaCapabilityTier) -> AlphaAssistantCatalogDescriptor {
    let artifact = alphaAssistantModelArtifact(for: tier)
    return AlphaAssistantCatalogDescriptor(
        tier: artifact.tier,
        packId: artifact.packId,
        sizeBytes: artifact.sizeBytes,
        checksumSha256: artifact.sha256,
        artifactKind: artifact.artifactKind,
        runtimeMode: artifact.runtimeMode,
        developmentOnly: artifact.developmentOnly,
        draftArtifact: artifact.draftArtifact
    )
}

func alphaDefaultAssistantDownloadDescriptor(for tier: AlphaCapabilityTier) -> AlphaAssistantDownloadDescriptor {
    let artifact = alphaAssistantModelArtifact(for: tier)
    return AlphaAssistantDownloadDescriptor(
        sessionId: nil,
        packId: artifact.packId,
        tier: artifact.tier,
        fileName: artifact.fileName,
        sizeBytes: artifact.sizeBytes,
        segmentSizeBytes: artifact.sizeBytes,
        segmentCount: 1,
        checksumSha256: artifact.sha256,
        artifactKind: artifact.artifactKind,
        runtimeMode: artifact.runtimeMode,
        developmentOnly: artifact.developmentOnly,
        downloadURLString: artifact.downloadURLString,
        rangeUnit: "bytes",
        resumeStrategy: "range_request_segments",
        verified: artifact.verified,
        releaseReady: artifact.releaseReady,
        draftArtifact: artifact.draftArtifact
    )
}

private func alphaAssistantCatalogDescriptor(
    from downloadDescriptor: AlphaAssistantDownloadDescriptor
) -> AlphaAssistantCatalogDescriptor {
    AlphaAssistantCatalogDescriptor(
        tier: downloadDescriptor.tier,
        packId: downloadDescriptor.packId,
        sizeBytes: downloadDescriptor.sizeBytes,
        checksumSha256: downloadDescriptor.checksumSha256,
        artifactKind: downloadDescriptor.artifactKind,
        runtimeMode: downloadDescriptor.runtimeMode,
        developmentOnly: downloadDescriptor.developmentOnly,
        draftArtifact: downloadDescriptor.draftArtifact
    )
}

private func alphaCachedPreferredAssistantSetupDescriptor(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]?,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]?
) -> AlphaAssistantCatalogDescriptor? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let catalogCandidates = (cachedCatalogs ?? []).filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
            alphaAssistantCatalogDescriptorSupportsCurrentInstaller($0)
    }
    if let preferredCatalog = catalogCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode }) {
        return preferredCatalog
    }

    let downloadCandidates = (cachedDownloads ?? []).filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
            alphaAssistantDownloadDescriptorSupportsCurrentInstaller($0)
    }
    if let preferredDownload = downloadCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode }) {
        return alphaAssistantCatalogDescriptor(from: preferredDownload)
    }
    if let bundledPreferred = alphaBundledAssistantCatalogDescriptor(
        for: tier,
        preferredRuntimeMode: preferredRuntimeMode
    ) {
        return bundledPreferred
    }
    if let fallbackCatalog = catalogCandidates.first {
        return fallbackCatalog
    }
    if let fallbackDownload = downloadCandidates.first {
        return alphaAssistantCatalogDescriptor(from: fallbackDownload)
    }
    return nil
}

func alphaPreferredAssistantSetupRuntimeMode(
    for tier: AlphaCapabilityTier,
    existingRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    systemAssistantAvailable: Bool? = nil,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> AlphaPackRuntimeMode {
    let preferredRuntime = alphaPreferredAssistantRuntimeMode(
        for: tier,
        existingRuntimeMode: existingRuntimeMode,
        isPhoneFormFactor: isPhoneFormFactor,
        physicalMemoryBytes: physicalMemoryBytes,
        freeStorageGB: freeStorageGB,
        systemAssistantAvailable: systemAssistantAvailable,
        lastInvocation: lastInvocation
    )
    guard !alphaAllowsDevelopmentModelArtifacts(),
          preferredRuntime == .mlxSwiftLm else {
        return preferredRuntime
    }
    if existingRuntimeMode == .mlxSwiftLm {
        return preferredRuntime
    }
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    if normalizedTier == .caseAssociate,
       existingRuntimeMode == nil,
       isPhoneFormFactor {
        return preferredRuntime
    }
    return .llamaCppGguf
}

struct AlphaAssistantSetupPresentation: Equatable, Sendable {
    let runtimeMode: AlphaPackRuntimeMode
    let sizeLabel: String
    let totalDownloadBytes: Int64
    let speedLabel: String?
    let contextLabel: String?
    let companionLabel: String?
    let etaLabel: String?
}

struct AlphaAssistantResolvedModelDetails: Equatable, Sendable {
    let modelLabel: String
    let sourceLabel: String?
    let draftCompanionLabel: String?
}

func alphaAssistantResolvedModelDetails(
    for pack: AlphaInstalledModelPack
) -> AlphaAssistantResolvedModelDetails? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier

    if pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model" {
        return AlphaAssistantResolvedModelDetails(
            modelLabel: "Built-in CoreAI",
            sourceLabel: rossLocalized("assistant_meta_built_in"),
            draftCompanionLabel: nil
        )
    }

    if pack.runtimeMode == .llamaCppGguf {
        let artifact = alphaAssistantModelArtifact(for: effectiveTier)
        let installedDraft = alphaExpectedDownloadedAssistantArtifact(for: pack)?.draftArtifact?.fileName
        return AlphaAssistantResolvedModelDetails(
            modelLabel: artifact.displayName,
            sourceLabel: artifact.sourceLabel,
            draftCompanionLabel: installedDraft ?? artifact.draftArtifact?.fileName
        )
    }

    if pack.runtimeMode == .mlxSwiftLm,
       let descriptor = alphaBundledAssistantDownloadDescriptor(
        for: effectiveTier,
        preferredRuntimeMode: .mlxSwiftLm,
        targetPackId: pack.packId
       ) {
        let modelLabel: String = switch effectiveTier {
        case .quickStart:
            "Gemma 4 E4B QAT 4-bit (MLX)"
        case .caseAssociate:
            "Gemma 4 12B QAT 4-bit (MLX)"
        case .seniorDraftingSupport:
            "Gemma 4 26B-A4B QAT 4-bit (MLX)"
        case .flash:
            "Gemma 4 E4B QAT 4-bit (MLX)"
        }
        let sourceLabel = alphaDirectMLXRepositoryID(for: descriptor).map { "Hugging Face · \($0)" }
        let installedDraft = alphaExpectedDownloadedAssistantArtifact(for: pack)?.draftArtifact?.fileName
        return AlphaAssistantResolvedModelDetails(
            modelLabel: modelLabel,
            sourceLabel: sourceLabel,
            draftCompanionLabel: installedDraft ?? descriptor.draftArtifact?.fileName
        )
    }

    return nil
}

func alphaAssistantSetupSpeedLabel(
    for tier: AlphaCapabilityTier,
    runtimeMode: AlphaPackRuntimeMode,
    physicalMemoryBytes: UInt64,
    deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier(),
    hasDraftCompanion: Bool,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> String? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    if let lastInvocation,
       lastInvocation.capabilityTier == effectiveTier.rawValue,
       lastInvocation.runtimeMode == runtimeMode.rawValue,
       let measuredSpeed = lastInvocation.estimatedOutputTokensPerSecond {
        return alphaAssistantTokenRateLabel(tokensPerSecond: measuredSpeed)
    }

    let memoryGB = max(2, Int(physicalMemoryBytes / 1_073_741_824))
    let baseSpeed: Double? = switch runtimeMode {
    case .appleFoundationModels:
        switch effectiveTier {
        case .flash:
            16
        case .quickStart:
            memoryGB >= 8 ? 16 : 14
        case .caseAssociate:
            memoryGB >= 16 ? 16 : 14
        case .seniorDraftingSupport:
            memoryGB >= 16 ? 14 : 12
        }
    case .mlxSwiftLm:
        AlphaMLXRuntimeProfile.estimatedAssistantTokensPerSecond(
            for: effectiveTier,
            physicalMemory: physicalMemoryBytes,
            deviceModelIdentifier: deviceModelIdentifier,
            hasDraftCompanion: hasDraftCompanion
        )
    case .llamaCppGguf:
        switch effectiveTier {
        case .flash:
            memoryGB >= 8 ? 12 : 10
        case .quickStart:
            memoryGB >= 12 ? 11 : 9
        case .caseAssociate:
            memoryGB >= 16 ? 12 : (memoryGB >= 12 ? 10 : 8)
        case .seniorDraftingSupport:
            memoryGB >= 16 ? 10 : 8
        }
    case .deterministicDev, .mediapipeLlm, .unavailable:
        nil
    }

    guard var baseSpeed else { return nil }
    if hasDraftCompanion,
       runtimeMode == .llamaCppGguf {
        baseSpeed += 1
    }
    return "~\(alphaAssistantTokenRateLabel(tokensPerSecond: baseSpeed))"
}

func alphaAssistantSetupContextTokens(
    for tier: AlphaCapabilityTier,
    runtimeMode: AlphaPackRuntimeMode,
    physicalMemoryBytes: UInt64,
    deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
) -> Int? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    switch runtimeMode {
    case .appleFoundationModels:
        return AlphaFoundationRuntimeProfile.contextWindowTokens(
            for: effectiveTier,
            physicalMemory: physicalMemoryBytes
        )
    case .mlxSwiftLm:
        return AlphaMLXRuntimeProfile.contextWindowTokens(
            for: effectiveTier,
            physicalMemory: physicalMemoryBytes,
            deviceModelIdentifier: deviceModelIdentifier
        )
    case .llamaCppGguf:
        return Int(
            AlphaLlamaRuntimeProfile.contextWindowTokens(
                forModelPath: alphaDefaultAssistantDownloadDescriptor(for: effectiveTier).fileName,
                physicalMemory: physicalMemoryBytes
            )
        )
    case .deterministicDev, .mediapipeLlm, .unavailable:
        return nil
    }
}

func alphaAssistantSetupContextLabel(
    for tier: AlphaCapabilityTier,
    runtimeMode: AlphaPackRuntimeMode,
    physicalMemoryBytes: UInt64,
    deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier()
) -> String? {
    guard let contextTokens = alphaAssistantSetupContextTokens(
        for: tier,
        runtimeMode: runtimeMode,
        physicalMemoryBytes: physicalMemoryBytes,
        deviceModelIdentifier: deviceModelIdentifier
    ) else {
        return nil
    }
    return alphaAssistantContextWindowLabel(tokens: contextTokens)
}

func alphaAssistantSetupEtaLabel(
    totalDownloadBytes: Int64,
    languageCode: String = rossSelectedLanguageCode()
) -> String? {
    guard totalDownloadBytes > 0 else { return nil }
    let assumedBytesPerSecond = 12_000_000.0 // Conservative 12 MB/s Wi-Fi estimate.
    let minutes = max(1, Int(ceil(Double(totalDownloadBytes) / assumedBytesPerSecond / 60)))
    return String(
        format: rossLocalized("assistant_setup_time_about_minutes", languageCode: languageCode),
        minutes
    )
}

func alphaAssistantSetupCompanionLabel(
    for runtimeMode: AlphaPackRuntimeMode
) -> String? {
    switch runtimeMode {
    case .mlxSwiftLm:
        return "Assistant companion included"
    case .llamaCppGguf:
        return "MTP draft acceleration"
    case .appleFoundationModels, .deterministicDev, .mediapipeLlm, .unavailable:
        return nil
    }
}

func alphaAssistantSetupCompanionCompactLabel(
    for runtimeMode: AlphaPackRuntimeMode
) -> String? {
    switch runtimeMode {
    case .mlxSwiftLm:
        return "Companion"
    case .llamaCppGguf:
        return "MTP"
    case .appleFoundationModels, .deterministicDev, .mediapipeLlm, .unavailable:
        return nil
    }
}

func alphaAssistantSetupCompactSummaryLabel(
    _ presentation: AlphaAssistantSetupPresentation
) -> String {
    let summaryParts = [
        presentation.runtimeMode.displayLabel,
        presentation.sizeLabel,
        alphaAssistantSetupCompanionCompactLabel(for: presentation.runtimeMode)
    ]
        .map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        .filter { !$0.isEmpty }

    return summaryParts.joined(separator: " · ")
}

func alphaAssistantBuiltInAlternativeHint(
    selectedRuntimeMode: AlphaPackRuntimeMode?,
    systemAssistantAvailable: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String? {
    guard systemAssistantAvailable,
          let selectedRuntimeMode,
          selectedRuntimeMode != .appleFoundationModels else {
        return nil
    }
    return rossLocalized("assistant_built_in_alternative_hint", languageCode: languageCode)
}

func alphaRecommendedAssistantSetupTier(
    baselineTier: AlphaCapabilityTier,
    systemAssistantAvailable: Bool,
    hasExistingAssistantSetup: Bool,
    hasRecentInvocation: Bool,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor()
) -> AlphaCapabilityTier {
    let normalizedBaseline = AlphaCapabilityTier.normalizedAssistantSelection(baselineTier) ?? baselineTier
    guard isPhoneFormFactor,
          systemAssistantAvailable,
          !hasExistingAssistantSetup,
          !hasRecentInvocation else {
        return normalizedBaseline
    }

    switch normalizedBaseline {
    case .seniorDraftingSupport:
        return .caseAssociate
    case .flash, .quickStart, .caseAssociate:
        return normalizedBaseline
    }
}

func alphaPreferredSelectedAssistantTier(
    activeTier: AlphaCapabilityTier?,
    installedPacks: [AlphaInstalledModelPack],
    modelJobs: [AlphaModelDownloadJob],
    baselineTier: AlphaCapabilityTier,
    systemAssistantAvailable: Bool,
    hasRecentInvocation: Bool,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor()
) -> AlphaCapabilityTier {
    if let normalizedActiveTier = AlphaCapabilityTier.normalizedAssistantSelection(activeTier) {
        return normalizedActiveTier
    }

    let normalizedInstalledTier = installedPacks
        .sorted(by: { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.checksumVerified != rhs.checksumVerified {
                return lhs.checksumVerified && !rhs.checksumVerified
            }
            return lhs.installedAt > rhs.installedAt
        })
        .compactMap { pack -> AlphaCapabilityTier? in
            guard !pack.developmentOnly else { return nil }
            return AlphaCapabilityTier.normalizedAssistantSelection(pack.tier)
        }
        .first
    if let normalizedInstalledTier {
        return normalizedInstalledTier
    }

    let normalizedJobTier = modelJobs
        .filter { job in
            !job.developmentOnly &&
                job.state != .notStarted &&
                job.state != .cancelled
        }
        .sorted(by: { $0.updatedAt > $1.updatedAt })
        .compactMap { job -> AlphaCapabilityTier? in
            AlphaCapabilityTier.normalizedAssistantSelection(job.tier)
        }
        .first
    if let normalizedJobTier {
        return normalizedJobTier
    }

    return alphaRecommendedAssistantSetupTier(
        baselineTier: baselineTier,
        systemAssistantAvailable: systemAssistantAvailable,
        hasExistingAssistantSetup: false,
        hasRecentInvocation: hasRecentInvocation,
        isPhoneFormFactor: isPhoneFormFactor
    )
}

private func alphaExistingRuntimeMode(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack]
) -> AlphaPackRuntimeMode? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    return installedPacks.first(where: {
        (AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ?? $0.tier) == effectiveTier &&
            $0.isActive
    })?.runtimeMode ?? installedPacks.first(where: {
        (AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ?? $0.tier) == effectiveTier
    })?.runtimeMode
}

private func alphaInstalledAssistantPacksForUpdateChecks(
    from installedPacks: [AlphaInstalledModelPack],
    preferredAgainst preferredInstalledPacks: [AlphaInstalledModelPack]? = nil,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> [AlphaInstalledModelPack] {
    let preferencePacks = preferredInstalledPacks ?? installedPacks
    let packsByTier = Dictionary(grouping: installedPacks) {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ?? $0.tier
    }
    let orderedTiers = alphaAssistantCatalogRefreshTiers(installedPacks: installedPacks)

    return orderedTiers.compactMap { tier in
        guard let tierPacks = packsByTier[tier], !tierPacks.isEmpty else {
            return nil
        }
        if alphaExistingRuntimeMode(for: tier, installedPacks: preferencePacks) == .appleFoundationModels {
            return nil
        }
        let preferredRuntime = alphaPreferredAssistantSetupRuntimeMode(
            for: tier,
            existingRuntimeMode: alphaExistingRuntimeMode(for: tier, installedPacks: preferencePacks),
            lastInvocation: lastInvocation
        )
        return tierPacks.first(where: \.isActive) ??
            tierPacks.first(where: { $0.runtimeMode == preferredRuntime }) ??
            tierPacks.first
    }
}

func alphaAssistantSetupPresentation(
    for tier: AlphaCapabilityTier,
    existingRuntimeMode: AlphaPackRuntimeMode? = nil,
    preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier(),
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    systemAssistantAvailable: Bool? = nil,
    lastInvocation: AlphaLocalModelInvocation? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]? = nil
) -> AlphaAssistantSetupPresentation? {
    let preferredRuntime: AlphaPackRuntimeMode
    if let preferredRuntimeMode,
       preferredRuntimeMode == .appleFoundationModels ||
        alphaAssistantTierSupportsInstallerRuntime(tier, runtimeMode: preferredRuntimeMode) {
        preferredRuntime = preferredRuntimeMode
    } else {
        preferredRuntime = alphaPreferredAssistantSetupRuntimeMode(
            for: tier,
            existingRuntimeMode: existingRuntimeMode,
            isPhoneFormFactor: isPhoneFormFactor,
            physicalMemoryBytes: physicalMemoryBytes,
            freeStorageGB: freeStorageGB,
            systemAssistantAvailable: systemAssistantAvailable,
            lastInvocation: lastInvocation
        )
    }
    if preferredRuntime == .appleFoundationModels {
        return AlphaAssistantSetupPresentation(
            runtimeMode: .appleFoundationModels,
            sizeLabel: rossLocalized("assistant_meta_no_download"),
            totalDownloadBytes: 0,
            speedLabel: alphaAssistantSetupSpeedLabel(
                for: tier,
                runtimeMode: .appleFoundationModels,
                physicalMemoryBytes: physicalMemoryBytes,
                deviceModelIdentifier: deviceModelIdentifier,
                hasDraftCompanion: false,
                lastInvocation: lastInvocation
            ),
            contextLabel: alphaAssistantSetupContextLabel(
                for: tier,
                runtimeMode: .appleFoundationModels,
                physicalMemoryBytes: physicalMemoryBytes,
                deviceModelIdentifier: deviceModelIdentifier
            ),
            companionLabel: nil,
            etaLabel: nil
        )
    }

    let defaultDescriptor = alphaDefaultAssistantCatalogDescriptor(for: tier)
    let descriptor = alphaCachedPreferredAssistantSetupDescriptor(
        for: tier,
        preferredRuntimeMode: preferredRuntime,
        cachedCatalogs: cachedCatalogs,
        cachedDownloads: cachedDownloads
    ) ?? (defaultDescriptor.runtimeMode == preferredRuntime ? defaultDescriptor : nil)
    guard let descriptor, descriptor.runtimeMode == preferredRuntime else {
        return nil
    }
    let totalDownloadBytes = descriptor.sizeBytes + Int64(descriptor.draftArtifact?.sizeBytes ?? 0)
    return AlphaAssistantSetupPresentation(
        runtimeMode: descriptor.runtimeMode,
        sizeLabel: alphaAssistantStorageSizeLabel(totalDownloadBytes),
        totalDownloadBytes: totalDownloadBytes,
        speedLabel: alphaAssistantSetupSpeedLabel(
            for: tier,
            runtimeMode: descriptor.runtimeMode,
            physicalMemoryBytes: physicalMemoryBytes,
            deviceModelIdentifier: deviceModelIdentifier,
            hasDraftCompanion: descriptor.draftArtifact != nil,
            lastInvocation: lastInvocation
        ),
        contextLabel: alphaAssistantSetupContextLabel(
            for: tier,
            runtimeMode: descriptor.runtimeMode,
            physicalMemoryBytes: physicalMemoryBytes,
            deviceModelIdentifier: deviceModelIdentifier
        ),
        companionLabel: descriptor.draftArtifact == nil ? nil : alphaAssistantSetupCompanionLabel(for: descriptor.runtimeMode),
        etaLabel: alphaAssistantSetupEtaLabel(totalDownloadBytes: totalDownloadBytes)
    )
}

func alphaAssistantAvailableSetupRuntimeModes(
    for tier: AlphaCapabilityTier,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]? = nil
) -> [AlphaPackRuntimeMode] {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    var descriptors: [AlphaAssistantCatalogDescriptor] = [
        alphaDefaultAssistantCatalogDescriptor(for: normalizedTier)
    ]

    if let bundledMLXDescriptor = alphaBundledAssistantCatalogDescriptor(
        for: normalizedTier,
        preferredRuntimeMode: .mlxSwiftLm
    ) {
        descriptors.append(bundledMLXDescriptor)
    }

    if let cachedCatalogs {
        descriptors.append(contentsOf: cachedCatalogs)
    }

    if let cachedDownloads {
        descriptors.append(contentsOf: cachedDownloads.map(alphaAssistantCatalogDescriptor(from:)))
    }

    var seen = Set<AlphaPackRuntimeMode>()
    return descriptors.compactMap { descriptor in
        guard AlphaCapabilityTier.normalizedAssistantSelection(descriptor.tier) == normalizedTier,
              !descriptor.developmentOnly,
              alphaAssistantTierSupportsInstallerRuntime(normalizedTier, runtimeMode: descriptor.runtimeMode),
              seen.insert(descriptor.runtimeMode).inserted else {
            return nil
        }
        return descriptor.runtimeMode
    }
}

private let alphaAssistantCatalogRefreshStaleInterval: TimeInterval = 86_400

func alphaAssistantCatalogRefreshIsStale(
    lastRefresh: Date?,
    now: Date = .now
) -> Bool {
    guard let lastRefresh else { return true }
    return now.timeIntervalSince(lastRefresh) >= alphaAssistantCatalogRefreshStaleInterval
}

func alphaShouldPrimeAssistantSetupCatalogs(
    visibleTiers: [AlphaCapabilityTier] = AlphaCapabilityTier.visibleAssistantTiers,
    installedPacks: [AlphaInstalledModelPack],
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]? = nil,
    lastCatalogRefresh: Date? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> Bool {
    if alphaAssistantCatalogRefreshIsStale(lastRefresh: lastCatalogRefresh) {
        return true
    }
    for tier in visibleTiers {
        let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
        let preferredRuntime = alphaPreferredAssistantSetupRuntimeMode(
            for: tier,
            existingRuntimeMode: alphaExistingRuntimeMode(for: tier, installedPacks: installedPacks),
            isPhoneFormFactor: isPhoneFormFactor,
            physicalMemoryBytes: physicalMemoryBytes,
            freeStorageGB: freeStorageGB,
            lastInvocation: lastInvocation
        )
        guard preferredRuntime != .appleFoundationModels else { continue }
        let preferredDescriptor = alphaCachedPreferredAssistantSetupDescriptor(
            for: tier,
            preferredRuntimeMode: preferredRuntime,
            cachedCatalogs: cachedCatalogs,
            cachedDownloads: cachedDownloads
        )
        let hasPreferredDescriptor = preferredDescriptor.map {
            AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
                alphaAssistantCatalogDescriptorSupportsCurrentInstaller($0) &&
                $0.runtimeMode == preferredRuntime
        } ?? false
        if !hasPreferredDescriptor {
            return true
        }
    }
    return false
}

func alphaPreferredAssistantCatalogFallback(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]?
) -> AlphaAssistantCatalogDescriptor {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let cachedCandidates = (cachedCatalogs ?? []).filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
            alphaAssistantCatalogDescriptorSupportsCurrentInstaller($0)
    }
    if let targetPackId,
       let targetedCached = cachedCandidates.first(where: { $0.packId == targetPackId }) {
        return targetedCached
    }
    if let preferredCached = cachedCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode }) {
        return preferredCached
    }
    if let bundledPreferred = alphaBundledAssistantCatalogDescriptor(
        for: tier,
        preferredRuntimeMode: preferredRuntimeMode,
        targetPackId: targetPackId
    ) {
        return bundledPreferred
    }
    if let fallbackCached = cachedCandidates.first {
        return fallbackCached
    }
    return alphaDefaultAssistantCatalogDescriptor(for: tier)
}

func alphaPreferredCachedAssistantInstalledReuseCatalogDescriptor(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]?
) -> AlphaAssistantCatalogDescriptor? {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let cachedCandidates = (cachedCatalogs ?? []).filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
            alphaAssistantCatalogDescriptorSupportsCurrentInstaller($0)
    }
    if let targetPackId,
       let targetedCached = cachedCandidates.first(where: { $0.packId == targetPackId }) {
        return targetedCached
    }
    return cachedCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode })
}

func alphaShouldResolveAssistantDownloadFromBackend(
    fallbackDownload: AlphaAssistantDownloadDescriptor,
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    targetPackId: String? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]?
) -> Bool {
    let effectiveTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let cachedCandidates = (cachedCatalogs ?? []).filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == effectiveTier &&
            alphaAssistantCatalogDescriptorSupportsCurrentInstaller($0)
    }
    if let targetPackId,
       cachedCandidates.contains(where: { $0.packId == targetPackId }) {
        return true
    }
    guard fallbackDownload.runtimeMode == preferredRuntimeMode,
          alphaDirectMLXRepositoryID(for: fallbackDownload) != nil else {
        return false
    }
    return cachedCandidates.contains {
        $0.runtimeMode == preferredRuntimeMode &&
            $0.packId != fallbackDownload.packId
    }
}

func alphaAssistantCatalogDescriptor(
    for tier: AlphaCapabilityTier,
    preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
    targetPackId: String? = nil,
    compatibleOnly: Bool = false,
    manifest: AlphaBackendCatalogManifest?
) -> AlphaAssistantCatalogDescriptor {
    guard let manifest else {
        return alphaDefaultAssistantCatalogDescriptor(for: tier)
    }

    let matchingTier = manifest.packs.filter {
        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) == AlphaCapabilityTier.normalizedAssistantSelection(tier)
            && !$0.developmentOnly
            && (!compatibleOnly || alphaBackendCatalogPackSupportsCurrentInstaller($0))
    }
    if let targetPackId,
       let targeted = matchingTier.first(where: { $0.packId == targetPackId }) {
        return AlphaAssistantCatalogDescriptor(
            tier: AlphaCapabilityTier.normalizedAssistantSelection(targeted.tier) ?? tier,
            packId: targeted.packId,
            sizeBytes: targeted.sizeBytes,
            checksumSha256: targeted.checksumSha256,
            artifactKind: targeted.artifactKind,
            runtimeMode: targeted.runtimeMode,
            developmentOnly: targeted.developmentOnly,
            draftArtifact: alphaAssistantCatalogDescriptorDraftArtifact(targeted.draftArtifact)
        )
    }
    guard let selected =
            matchingTier.first(where: { preferredRuntimeMode != nil && $0.runtimeMode == preferredRuntimeMode }) ??
            matchingTier.first else {
        return alphaDefaultAssistantCatalogDescriptor(for: tier)
    }

    return AlphaAssistantCatalogDescriptor(
        tier: AlphaCapabilityTier.normalizedAssistantSelection(selected.tier) ?? tier,
        packId: selected.packId,
        sizeBytes: selected.sizeBytes,
        checksumSha256: selected.checksumSha256,
        artifactKind: selected.artifactKind,
        runtimeMode: selected.runtimeMode,
        developmentOnly: selected.developmentOnly,
        draftArtifact: alphaAssistantCatalogDescriptorDraftArtifact(selected.draftArtifact)
    )
}

func alphaAssistantCatalogCacheDescriptors(
    for tier: AlphaCapabilityTier,
    compatibleOnly: Bool = false,
    manifest: AlphaBackendCatalogManifest?
) -> [AlphaAssistantCatalogDescriptor] {
    guard let manifest else { return [] }

    return manifest.packs.compactMap { pack in
        guard AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) == AlphaCapabilityTier.normalizedAssistantSelection(tier),
              !pack.developmentOnly,
              (!compatibleOnly || alphaBackendCatalogPackSupportsCurrentInstaller(pack)) else {
            return nil
        }
        return AlphaAssistantCatalogDescriptor(
            tier: AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? tier,
            packId: pack.packId,
            sizeBytes: pack.sizeBytes,
            checksumSha256: pack.checksumSha256,
            artifactKind: pack.artifactKind,
            runtimeMode: pack.runtimeMode,
            developmentOnly: pack.developmentOnly,
            draftArtifact: alphaAssistantCatalogDescriptorDraftArtifact(pack.draftArtifact)
        )
    }
}

func alphaAssistantUpdateCandidate(
    installedPack: AlphaInstalledModelPack,
    availableDescriptor: AlphaAssistantCatalogDescriptor,
    existingDismissed: AlphaModelUpdateCandidate?,
    systemAssistantAvailable: Bool? = nil,
    preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> AlphaModelUpdateCandidate? {
    guard !installedPack.developmentOnly,
          !installedPack.installPath.hasPrefix("system://") else {
        return nil
    }

    let preferredRuntime = preferredRuntimeMode ?? alphaPreferredAssistantSetupRuntimeMode(
        for: installedPack.tier,
        existingRuntimeMode: installedPack.runtimeMode,
        isPhoneFormFactor: isPhoneFormFactor,
        physicalMemoryBytes: physicalMemoryBytes,
        freeStorageGB: freeStorageGB,
        systemAssistantAvailable: systemAssistantAvailable,
        lastInvocation: lastInvocation
    )
    guard preferredRuntime != .appleFoundationModels else {
        return nil
    }
    guard availableDescriptor.runtimeMode == preferredRuntime else {
        return nil
    }

    let changed = installedPack.packId != availableDescriptor.packId ||
        (!availableDescriptor.checksumSha256.isEmpty &&
         installedPack.checksumSha256.caseInsensitiveCompare(availableDescriptor.checksumSha256) != .orderedSame) ||
        !alphaAssistantCatalogDraftArtifactMatchesInstalledPack(installedPack, descriptor: availableDescriptor)
    guard changed else { return nil }

    return AlphaModelUpdateCandidate(
        tier: installedPack.tier,
        installedPackId: installedPack.packId,
        availablePackId: availableDescriptor.packId,
        availableSizeBytes: availableDescriptor.sizeBytes,
        requiresWifi: true,
        dismissedAt: existingDismissed?.dismissedAt
    )
}

func alphaAssistantCatalogRefreshTiers(installedPacks: [AlphaInstalledModelPack]) -> [AlphaCapabilityTier] {
    var tiers = AlphaCapabilityTier.visibleAssistantTiers
    for pack in installedPacks {
        let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier
        if !tiers.contains(normalizedTier) {
            tiers.append(normalizedTier)
        }
    }
    return tiers
}

func alphaResolvedModelCatalogRefreshDate(
    previousRefresh: Date?,
    refreshedCatalogCount: Int,
    now: Date = .now
) -> Date? {
    refreshedCatalogCount > 0 ? now : previousRefresh
}

func alphaBackendCatalogPackSupportsCurrentInstaller(_ pack: AlphaBackendCatalogPack) -> Bool {
    guard pack.developmentOnly == false,
          pack.sizeBytes > 0,
          alphaAssistantTierSupportsInstallerRuntime(pack.tier, runtimeMode: pack.runtimeMode) else {
        return false
    }
    if let draftArtifact = pack.draftArtifact,
       !alphaAssistantCatalogDraftArtifactSupportsCurrentInstaller(
        AlphaAssistantDraftArtifactDescriptor(
            fileName: draftArtifact.fileName,
            sizeBytes: draftArtifact.sizeBytes,
            checksumSha256: draftArtifact.checksumSha256,
            artifactKind: draftArtifact.artifactKind,
            downloadURLString: "",
            draftTokens: draftArtifact.draftTokens
        )
       ) {
        return false
    }
    switch pack.runtimeMode {
    case .llamaCppGguf:
        return pack.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(packId: pack.packId) else {
            return false
        }
        return pack.artifactKind == "mlx_directory"
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaBackendArtifactSupportsCurrentInstaller(_ artifact: AlphaBackendArtifact) -> Bool {
    guard artifact.developmentOnly == false,
          artifact.sizeBytes > 0,
          artifact.finalSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil else {
        return false
    }
    if let draftArtifact = artifact.draftArtifact,
       !alphaAssistantDraftArtifactSupportsCurrentInstaller(
        AlphaAssistantDraftArtifactDescriptor(
            fileName: draftArtifact.fileName,
            sizeBytes: draftArtifact.sizeBytes,
            checksumSha256: draftArtifact.finalSha256,
            artifactKind: draftArtifact.artifactKind,
            downloadURLString: draftArtifact.downloadUrl,
            draftTokens: draftArtifact.draftTokens
        )
       ) {
        return false
    }
    let fileName = artifact.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    switch artifact.runtimeMode {
    case .llamaCppGguf:
        return fileName.lowercased().hasSuffix(".gguf") &&
            artifact.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        guard !alphaMLXArtifactRequiresUnsupportedOptiQRuntime(
            fileName: fileName,
            downloadURLString: artifact.downloadUrl
        ) else {
            return false
        }
        return alphaPackagedMLXArchiveArtifact(
            fileName: fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: artifact.runtimeMode
        ) || alphaDirectMLXRepositoryArtifact(
            fileName: fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: artifact.runtimeMode,
            downloadURLString: artifact.downloadUrl
        )
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaAssistantDownloadDescriptor(
    for tier: AlphaCapabilityTier,
    session: AlphaBackendDownloadSessionPayload?,
    resolvedURLString: String?
) -> AlphaAssistantDownloadDescriptor {
    let fallback = alphaDefaultAssistantDownloadDescriptor(for: tier)
    guard let session,
          let resolvedURLString,
          alphaBackendArtifactSupportsCurrentInstaller(session.artifact) else {
        return fallback
    }
    return AlphaAssistantDownloadDescriptor(
        sessionId: session.sessionId,
        packId: session.packId,
        tier: tier,
        fileName: session.artifact.fileName,
        sizeBytes: session.artifact.sizeBytes,
        segmentSizeBytes: session.artifact.segmentSizeBytes ?? session.artifact.segments.first?.sizeBytes ?? session.artifact.sizeBytes,
        segmentCount: session.artifact.segmentCount ?? (session.artifact.segments.isEmpty ? nil : session.artifact.segments.count),
        checksumSha256: session.artifact.finalSha256.lowercased(),
        artifactKind: session.artifact.artifactKind,
        runtimeMode: session.artifact.runtimeMode,
        developmentOnly: session.artifact.developmentOnly,
        downloadURLString: resolvedURLString,
        rangeUnit: session.artifact.rangeUnit ?? "bytes",
        resumeStrategy: session.artifact.resumeStrategy,
        verified: true,
        releaseReady: true,
        draftArtifact: alphaAssistantDownloadDescriptorDraftArtifact(session.artifact.draftArtifact)
    )
}

extension AlphaRossModel {
    func preferredSelectedAssistantTier(
        fallbackSelectedTier: AlphaCapabilityTier? = nil
    ) -> AlphaCapabilityTier {
        alphaPreferredSelectedAssistantTier(
            activeTier: persisted.settings.activeTier ?? fallbackSelectedTier,
            installedPacks: persisted.installedPacks,
            modelJobs: persisted.modelJobs,
            baselineTier: recommendedOnDeviceTier(),
            systemAssistantAvailable: systemAssistantHealth(for: .quickStart)?.available == true,
            hasRecentInvocation: alphaLastModelInvocation(in: persisted) != nil
        )
    }

    func recommendedAssistantSetupTier() -> AlphaCapabilityTier {
        let baselineTier = recommendedOnDeviceTier()
        let hasExistingAssistantSetup =
            persisted.settings.activeTier != nil ||
            persisted.installedPacks.contains(where: { !$0.developmentOnly }) ||
            persisted.modelJobs.contains(where: {
                !$0.developmentOnly &&
                    $0.state != .notStarted &&
                    $0.state != .cancelled
            })
        let hasRecentInvocation = alphaLastModelInvocation(in: persisted) != nil
        return alphaRecommendedAssistantSetupTier(
            baselineTier: baselineTier,
            systemAssistantAvailable: systemAssistantHealth(for: .quickStart)?.available == true,
            hasExistingAssistantSetup: hasExistingAssistantSetup,
            hasRecentInvocation: hasRecentInvocation
        )
    }

    private func upsertInstalledPack(
        _ pack: AlphaInstalledModelPack,
        activate: Bool
    ) {
        persisted.installedPacks.removeAll {
            $0.id == pack.id ||
                $0.packId == pack.packId ||
                $0.installPath == pack.installPath
        }
        if activate {
            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
        }
        var retainedPack = pack
        retainedPack.isActive = activate
        persisted.installedPacks.insert(retainedPack, at: 0)
        if activate {
            persisted.settings.activeTier = pack.tier
            resumePendingAskUpgradeIfReady(
                activeTier: pack.tier,
                activeRuntimeMode: pack.runtimeMode
            )
        } else if !persisted.installedPacks.contains(where: \.isActive) {
            retainedPack.isActive = true
            persisted.installedPacks[0] = retainedPack
            persisted.settings.activeTier = pack.tier
            resumePendingAskUpgradeIfReady(
                activeTier: pack.tier,
                activeRuntimeMode: pack.runtimeMode
            )
        }
    }

    func primeAssistantSetupCatalogsIfNeeded(force: Bool = false) {
        if !force,
           assistantSetupCatalogRefreshTask != nil {
            return
        }

        let lastInvocation = alphaLastModelInvocation(in: persisted)
        let shouldPrime = force || alphaShouldPrimeAssistantSetupCatalogs(
            installedPacks: persisted.installedPacks,
            cachedCatalogs: persisted.cachedAssistantCatalogs,
            cachedDownloads: persisted.cachedAssistantDownloads,
            lastCatalogRefresh: persisted.lastModelCatalogRefresh,
            lastInvocation: lastInvocation
        )
        guard shouldPrime else { return }

        assistantSetupCatalogRefreshTask?.cancel()
        assistantSetupCatalogRefreshTask = Task {
            var refreshedCatalogsByTier: [AlphaCapabilityTier: [AlphaAssistantCatalogDescriptor]] = [:]
            for tier in AlphaCapabilityTier.visibleAssistantTiers {
                do {
                    let manifest = try await backend.fetchCatalog(for: tier)
                    let cachedDescriptors = alphaAssistantCatalogCacheDescriptors(
                        for: tier,
                        compatibleOnly: true,
                        manifest: manifest
                    )
                    if !cachedDescriptors.isEmpty {
                        refreshedCatalogsByTier[tier] = cachedDescriptors
                    }
                } catch {
                    continue
                }
            }

            await MainActor.run {
                defer { self.assistantSetupCatalogRefreshTask = nil }
                guard !Task.isCancelled, !refreshedCatalogsByTier.isEmpty else { return }

                var cachedCatalogs = self.persisted.cachedAssistantCatalogs ?? []
                for (tier, descriptors) in refreshedCatalogsByTier {
                    cachedCatalogs.removeAll {
                        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ==
                            AlphaCapabilityTier.normalizedAssistantSelection(tier)
                    }
                    cachedCatalogs.append(contentsOf: descriptors)
                }
                self.persisted.cachedAssistantCatalogs = cachedCatalogs
                self.persisted.lastModelCatalogRefresh = alphaResolvedModelCatalogRefreshDate(
                    previousRefresh: self.persisted.lastModelCatalogRefresh,
                    refreshedCatalogCount: refreshedCatalogsByTier.values.reduce(0) { $0 + $1.count }
                )
                self.persist()
            }
        }
    }

    func installedPack(for tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        privateAISnapshot.installedPack(for: tier)
    }

    func assistantSetupPresentation(for tier: AlphaCapabilityTier) -> AlphaAssistantSetupPresentation? {
        let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
        let preferredRuntimeMode: AlphaPackRuntimeMode? = if AlphaCapabilityTier.assistantSelectionsMatch(
            assistantSetupRuntimeOverrideTier,
            normalizedTier
        ) {
            assistantSetupRuntimeOverrideMode
        } else {
            nil
        }
        return alphaAssistantSetupPresentation(
            for: tier,
            existingRuntimeMode: alphaExistingRuntimeMode(for: tier, installedPacks: persisted.installedPacks),
            preferredRuntimeMode: preferredRuntimeMode,
            systemAssistantAvailable: systemAssistantHealth(for: tier)?.available == true,
            lastInvocation: alphaLastModelInvocation(in: persisted),
            cachedCatalogs: persisted.cachedAssistantCatalogs,
            cachedDownloads: persisted.cachedAssistantDownloads
        )
    }

    func setAssistantSetupRuntimeOverride(
        _ runtimeMode: AlphaPackRuntimeMode?,
        for tier: AlphaCapabilityTier?
    ) {
        assistantSetupRuntimeOverrideTier = tier
        assistantSetupRuntimeOverrideMode = runtimeMode
    }

    func clearAssistantSetupRuntimeOverride(for tier: AlphaCapabilityTier? = nil) {
        guard let tier else {
            assistantSetupRuntimeOverrideTier = nil
            assistantSetupRuntimeOverrideMode = nil
            return
        }
        guard AlphaCapabilityTier.assistantSelectionsMatch(assistantSetupRuntimeOverrideTier, tier) else {
            return
        }
        assistantSetupRuntimeOverrideTier = nil
        assistantSetupRuntimeOverrideMode = nil
    }

    var activeRuntimeHealth: AlphaLocalRuntimeHealth? {
        if let fallbackPack = alphaRecoveredAssistantExecutionFallback(
            from: persisted,
            selectedTier: persisted.settings.activeTier ?? selectedTier,
            currentPack: privateAISnapshot.activePack ?? alphaOptimisticActivePack(from: persisted)
        ) {
            return AlphaLocalModelRuntime.runtimeHealth(
                activePack: fallbackPack,
                requestedTier: fallbackPack.tier,
                runtimeEnvironment: alphaLocalRuntimeEnvironment(
                    activePack: fallbackPack,
                    requestedTier: fallbackPack.tier,
                    installedPacks: persisted.installedPacks,
                    lastInvocation: alphaLastModelInvocation(in: persisted)
                )
            )
        }
        return privateAISnapshot.activeRuntimeHealth
    }

    var lastModelInvocationRuntimeMode: String? {
        lastModelInvocation?.runtimeMode
    }

    var lastModelInvocation: AlphaLocalModelInvocation? {
        privateAISnapshot.lastModelInvocation
    }

    func pauseJob(_ job: AlphaModelDownloadJob) {
        guard job.state == .queued || job.state == .downloading else { return }

        if let taskBox = assistantDownloadTaskBoxes[job.id] {
            taskBox.pausedByUser = true
            taskBox.progressTask?.cancel()
            taskBox.session?.invalidateAndCancel()
            AlphaBackgroundModelDownloadCenter.shared.cancel(jobID: job.id) { [weak self] resumeData in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let shouldPersistResumeData = self.assistantDownloadTaskBoxes[job.id]?.supportsResumePersistence ?? true
                    self.assistantDownloadTaskBoxes[job.id]?.resumeData = shouldPersistResumeData ? resumeData : nil
                    let resumePath: String?
                    if let resumeData, shouldPersistResumeData {
                        resumePath = try? await self.store.saveModelResumeData(resumeData, for: job.id)
                    } else {
                        resumePath = nil
                    }
                    self.assistantDownloadTaskBoxes[job.id]?.task = nil
                    self.updateJob(job.id) {
                        $0.state = .pausedUser
                        $0.resumeDataRelativePath = resumePath ?? $0.resumeDataRelativePath
                        $0.updatedAt = .now
                    }
                    self.persist()
                }
            }
            return
        }

        updateJob(job.id) {
            $0.state = .pausedUser
            $0.resumeDataRelativePath = $0.resumeDataRelativePath
            $0.updatedAt = .now
        }
        persist()
    }

    func resumeJob(_ job: AlphaModelDownloadJob) {
        guard job.state == .pausedUser ||
            job.state == .pausedWaitingForWifi ||
            job.state == .pausedError ||
            job.state == .pausedNoStorage ||
            job.state == .failed else { return }
        assistantDownloadTaskBoxes[job.id]?.pausedByUser = false
        Task {
            do {
                if let resumeData = try await store.loadModelResumeData(relativePath: job.resumeDataRelativePath) {
                    let taskBox = assistantDownloadTaskBoxes[job.id] ?? AlphaAssistantDownloadTaskBox()
                    taskBox.resumeData = resumeData
                    assistantDownloadTaskBoxes[job.id] = taskBox
                } else if job.resumeDataRelativePath != nil {
                    recordMissingResumeData(for: job.id)
                }
            } catch {
                recordMissingResumeData(for: job.id)
            }
            await startPackDownload(
                for: job.tier,
                mobileAllowed: job.networkPolicy == .mobileAllowed,
                existingJobID: job.id
            )
        }
    }

    private func recordMissingResumeData(for jobID: UUID) {
        updateJob(jobID) {
            $0.resumeDataRelativePath = nil
            $0.bytesDownloaded = 0
            $0.failureReason = rossLocalized("assistant_download_resume_missing_restart")
            $0.updatedAt = .now
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_assistant_download_resume_restarted_title"),
                detail: rossLocalized("assistant_download_resume_missing_restart_detail"),
                purpose: .model_download,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-resume",
                success: false
            ),
            at: 0
        )
        persist()
    }

    private func recordStaleResumeDataRestart(for jobID: UUID) async {
        let existingPath = persisted.modelJobs.first(where: { $0.id == jobID })?.resumeDataRelativePath
        await store.removeModelResumeData(relativePath: existingPath)
        assistantDownloadTaskBoxes[jobID]?.resumeData = nil
        updateJob(jobID) {
            $0.resumeDataRelativePath = nil
            $0.bytesDownloaded = 0
            $0.failureReason = nil
            $0.updatedAt = .now
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: rossLocalized("privacy_ledger_assistant_download_resume_restarted_title"),
                detail: rossLocalized("assistant_download_resume_stale_restart_detail"),
                purpose: .model_download,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-resume",
                success: false
            ),
            at: 0
        )
        persist()
    }

    func shouldRestartAssistantDownloadWithoutResumeData(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        switch error.code {
        case NSURLErrorCannotDecodeRawData,
             NSURLErrorCannotDecodeContentData,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCancelled:
            return true
        default:
            return false
        }
    }

    func removeInstalledPack(_ pack: AlphaInstalledModelPack) {
        let storedPack = persisted.installedPacks.first(where: { $0.id == pack.id }) ?? pack
        if !storedPack.installPath.hasPrefix("system://") {
            alphaRemoveDownloadedPackArtifact(relativePath: storedPack.installPath)
        }
        let removedWasActive = storedPack.isActive
        persisted.installedPacks.removeAll { $0.id == storedPack.id }
        if removedWasActive {
            if let sameTierReplacement = persisted.installedPacks.first(where: { $0.tier == storedPack.tier }) {
                persisted.installedPacks = persisted.installedPacks.map {
                    var copy = $0
                    copy.isActive = copy.id == sameTierReplacement.id
                    return copy
                }
                persisted.settings.activeTier = sameTierReplacement.tier
            } else if !persisted.installedPacks.isEmpty {
                persisted.installedPacks = persisted.installedPacks.enumerated().map { index, retainedPack in
                    var copy = retainedPack
                    copy.isActive = index == 0
                    return copy
                }
                persisted.settings.activeTier = persisted.installedPacks.first?.tier
            } else {
                persisted.settings.activeTier = nil
            }
        } else if !persisted.installedPacks.contains(where: \.isActive), !persisted.installedPacks.isEmpty {
            persisted.installedPacks[0].isActive = true
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant removed",
                detail: "\(storedPack.tier.setupTitle) was removed from local storage.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-remove",
                success: true
            ),
            at: 0
        )
        persist()
    }

    func removeAllDownloadedModelFiles() {
        for (jobID, taskBox) in assistantDownloadTaskBoxes {
            taskBox.pausedByUser = true
            taskBox.progressTask?.cancel()
            taskBox.session?.invalidateAndCancel()
            AlphaBackgroundModelDownloadCenter.shared.cancel(jobID: jobID) { _ in }
        }
        assistantDownloadTaskBoxes.removeAll()
        persisted.installedPacks.removeAll { !$0.installPath.hasPrefix("system://") }
        persisted.modelJobs.removeAll { !$0.developmentOnly && $0.artifactKind != "system_model" }
        persisted.settings.activeTier = persisted.installedPacks.first(where: \.isActive)?.tier
        persisted.modelUpdateCandidates = []
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant setup removed",
                detail: "Assistant setup files and resume data were deleted from this device.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-remove",
                success: true
            ),
            at: 0
        )
        persist(workspaceChanged: true)
        Task {
            await store.removeAllModelArtifacts()
            _ = alphaSweepTemporaryAssistantDownloads()
        }
    }

    func reclaimAssistantStorageLeaks() async -> Int64 {
        let keptResumePaths = Set(persisted.modelJobs.compactMap(\.resumeDataRelativePath))
        let before = await store.assistantStorageBreakdown().totalBytes
        await store.sweepTemporaryAssistantDownloads()
        await store.sweepModelResumeData(keeping: keptResumePaths)
        let after = await store.assistantStorageBreakdown().totalBytes
        return max(0, before - after)
    }

    func checkForAssistantModelUpdates(force: Bool = false) {
        guard persisted.settings.autoModelUpdateChecksEnabled || force else { return }
        let cachedCatalogIsStale = alphaAssistantCatalogRefreshIsStale(
            lastRefresh: persisted.lastModelCatalogRefresh
        )
        if !force, !cachedCatalogIsStale {
            return
        }
        let allInstalledPacks = persisted.installedPacks.filter { !$0.developmentOnly }
        let installedPacks = allInstalledPacks.filter { !$0.installPath.hasPrefix("system://") }
        let dismissedCandidates = persisted.modelUpdateCandidates ?? []
        let lastInvocation = alphaLastModelInvocation(in: persisted)
        let refreshTiers = alphaAssistantCatalogRefreshTiers(installedPacks: installedPacks)
        let updateCheckPacks = alphaInstalledAssistantPacksForUpdateChecks(
            from: installedPacks,
            preferredAgainst: allInstalledPacks,
            lastInvocation: lastInvocation
        )
        let fallbackCandidates: [AlphaModelUpdateCandidate]
        if cachedCatalogIsStale {
            fallbackCandidates = []
        } else {
            fallbackCandidates = updateCheckPacks.compactMap { pack in
                let resolvedTier = AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier
                let preferredRuntime = alphaPreferredAssistantSetupRuntimeMode(
                    for: resolvedTier,
                    existingRuntimeMode: alphaExistingRuntimeMode(for: resolvedTier, installedPacks: allInstalledPacks),
                    lastInvocation: lastInvocation
                )
                let fallbackDescriptor = alphaPreferredAssistantCatalogFallback(
                    for: resolvedTier,
                    preferredRuntimeMode: preferredRuntime,
                    cachedCatalogs: persisted.cachedAssistantCatalogs
                )
                let dismissed = dismissedCandidates.first {
                    $0.tier == pack.tier &&
                        $0.availablePackId == fallbackDescriptor.packId &&
                        $0.dismissedAt != nil
                }
                return alphaAssistantUpdateCandidate(
                    installedPack: pack,
                    availableDescriptor: fallbackDescriptor,
                    existingDismissed: dismissed,
                    lastInvocation: lastInvocation
                )
            }
        }

        persisted.modelUpdateCandidates = fallbackCandidates
        if !fallbackCandidates.isEmpty {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant update available",
                    detail: rossLocalized("privacy_ledger_assistant_update_available_detail"),
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-update-check",
                    success: true
                ),
                at: 0
            )
        }
        persist()

        Task {
            var descriptorsByTier: [AlphaCapabilityTier: AlphaAssistantCatalogDescriptor] = [:]
            var refreshedCatalogsByTier: [AlphaCapabilityTier: [AlphaAssistantCatalogDescriptor]] = [:]
            for tier in refreshTiers {
                let preferredRuntime = alphaPreferredAssistantSetupRuntimeMode(
                    for: tier,
                    existingRuntimeMode: alphaExistingRuntimeMode(for: tier, installedPacks: allInstalledPacks),
                    lastInvocation: lastInvocation
                )
                do {
                    let manifest = try await backend.fetchCatalog(for: tier)
                    let cachedDescriptors = alphaAssistantCatalogCacheDescriptors(
                        for: tier,
                        compatibleOnly: true,
                        manifest: manifest
                    )
                    let descriptor = alphaAssistantCatalogDescriptor(
                        for: tier,
                        preferredRuntimeMode: preferredRuntime,
                        compatibleOnly: true,
                        manifest: manifest
                    )
                    descriptorsByTier[tier] = descriptor
                    refreshedCatalogsByTier[tier] = cachedDescriptors
                } catch {
                    descriptorsByTier[tier] = alphaPreferredAssistantCatalogFallback(
                        for: tier,
                        preferredRuntimeMode: preferredRuntime,
                        cachedCatalogs: self.persisted.cachedAssistantCatalogs
                    )
                }
            }

            let candidates = updateCheckPacks.compactMap { pack in
                let resolvedTier = AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier
                let descriptor = descriptorsByTier[resolvedTier] ?? alphaDefaultAssistantCatalogDescriptor(for: resolvedTier)
                let dismissed = dismissedCandidates.first {
                    $0.tier == pack.tier &&
                        $0.availablePackId == descriptor.packId &&
                        $0.dismissedAt != nil
                }
                return alphaAssistantUpdateCandidate(
                    installedPack: pack,
                    availableDescriptor: descriptor,
                    existingDismissed: dismissed,
                    lastInvocation: lastInvocation
                )
            }

            await MainActor.run {
                let shouldRecordLedger = self.persisted.modelUpdateCandidates?.isEmpty != false && !candidates.isEmpty
                var cachedCatalogs = self.persisted.cachedAssistantCatalogs ?? []
                for (tier, descriptors) in refreshedCatalogsByTier {
                    cachedCatalogs.removeAll {
                        AlphaCapabilityTier.normalizedAssistantSelection($0.tier) ==
                            AlphaCapabilityTier.normalizedAssistantSelection(tier)
                    }
                    cachedCatalogs.append(contentsOf: descriptors)
                }
                self.persisted.cachedAssistantCatalogs = cachedCatalogs
                self.persisted.modelUpdateCandidates = candidates
                self.persisted.lastModelCatalogRefresh = alphaResolvedModelCatalogRefreshDate(
                    previousRefresh: self.persisted.lastModelCatalogRefresh,
                    refreshedCatalogCount: refreshedCatalogsByTier.values.reduce(0) { $0 + $1.count }
                )
                if shouldRecordLedger {
                    self.persisted.ledgerEntries.insert(
                        AlphaPrivacyLedgerEntry(
                            title: "Assistant update available",
                            detail: rossLocalized("privacy_ledger_assistant_update_available_detail"),
                            purpose: .model_catalog,
                            payloadClass: .no_case_data,
                            endpointLabel: "device://model-update-check",
                            success: true
                        ),
                        at: 0
                    )
                }
                self.persist()
            }
        }
    }

    func dismissAssistantModelUpdate(_ candidate: AlphaModelUpdateCandidate) {
        persisted.modelUpdateCandidates = (persisted.modelUpdateCandidates ?? []).map {
            var copy = $0
            if copy.id == candidate.id {
                copy.dismissedAt = .now
            }
            return copy
        }
        persist()
    }

    func startAssistantModelUpdate(_ candidate: AlphaModelUpdateCandidate, mobileAllowed: Bool = false) {
        Task {
            await startPackDownload(
                for: candidate.tier,
                mobileAllowed: mobileAllowed,
                forceRefreshInstalledPack: true,
                targetPackId: candidate.availablePackId
            )
        }
    }

    func repairAssistantPack(for tier: AlphaCapabilityTier, mobileAllowed: Bool = false) async {
        if let pack = persisted.installedPacks.first(where: {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier) && $0.isActive
        }) ?? persisted.installedPacks.first(where: {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier)
        }) {
            removeInstalledPack(pack)
            persisted.modelJobs.removeAll { job in
                job.packId == pack.packId &&
                    (job.state == .installed || job.state == .failed || job.state == .cancelled)
            }
        } else {
            persisted.modelJobs.removeAll { job in
                AlphaCapabilityTier.assistantSelectionsMatch(job.tier, tier) &&
                    (job.state == .installed || job.state == .failed || job.state == .cancelled)
            }
        }
        persisted.settings.activeTier = persisted.installedPacks.first(where: \.isActive)?.tier
        persist(workspaceChanged: true)
        await startPackDownload(for: tier, mobileAllowed: mobileAllowed)
    }

    func activateInstalledPack(_ pack: AlphaInstalledModelPack) {
        clearAssistantSetupRuntimeOverride(for: pack.tier)
        guard installedPackPassesRuntimeValidation(pack) else {
            let message = AlphaLocalModelRuntime.runtimeHealth(
                activePack: pack,
                requestedTier: pack.tier
            )?.userFacingStatus ?? rossLocalized("runtime_health_llama_needs_repair")
            persisted.modelJobs = persisted.modelJobs.map { job in
                var copy = job
                if AlphaCapabilityTier.assistantSelectionsMatch(job.tier, pack.tier), job.state == .installed {
                    copy.state = .failed
                    copy.failureReason = message
                    copy.updatedAt = .now
                }
                return copy
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant activation failed",
                    detail: message,
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: false
                ),
                at: 0
            )
            persist()
            return
        }
        persisted.installedPacks = persisted.installedPacks.map {
            var copy = $0
            copy.isActive = copy.id == pack.id
            if copy.id == pack.id,
               !copy.developmentOnly,
               let expected = alphaExpectedDownloadedAssistantArtifact(for: copy),
               alphaModelAssistantChecksumMatches(expected: expected.checksumSha256, actual: copy.checksumSha256) {
                copy.checksumVerified = true
            }
            return copy
        }
        persisted.modelJobs.removeAll { job in
            AlphaCapabilityTier.assistantSelectionsMatch(job.tier, pack.tier) && job.state != .installed
        }
        persisted.settings.activeTier = pack.tier
        resumePendingAskUpgradeIfReady(
            activeTier: pack.tier,
            activeRuntimeMode: pack.runtimeMode
        )
        persist()
    }

    func canActivateAssistantRuntimeImmediately(
        for tier: AlphaCapabilityTier,
        runtimeMode: AlphaPackRuntimeMode
    ) -> Bool {
        if let installed = persisted.installedPacks.first(where: {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier) &&
                $0.runtimeMode == runtimeMode
        }) {
            return installedPackPassesRuntimeValidation(installed)
        }

        return runtimeMode == .appleFoundationModels &&
            systemAssistantReadyForActivation(for: tier)
    }

    func activateAssistantRuntimeIfAvailable(
        for tier: AlphaCapabilityTier,
        runtimeMode: AlphaPackRuntimeMode
    ) -> Bool {
        if let installed = persisted.installedPacks.first(where: {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier) &&
                $0.runtimeMode == runtimeMode
        }) {
            guard canActivateAssistantRuntimeImmediately(for: tier, runtimeMode: runtimeMode) else {
                return false
            }
            activateInstalledPack(installed)
            return true
        }

        guard canActivateAssistantRuntimeImmediately(for: tier, runtimeMode: runtimeMode) else {
            return false
        }

        clearAssistantSetupRuntimeOverride(for: tier)
        upsertInstalledPack(alphaSystemAssistantPack(for: tier), activate: true)
        persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
            persisted.modelUpdateCandidates,
            for: tier
        )
        persist(workspaceChanged: true)
        return true
    }

    func installedPackPassesRuntimeValidation(_ pack: AlphaInstalledModelPack) -> Bool {
        alphaInstalledAssistantPackPassesRuntimeValidation(pack)
    }

    func prepareSystemAssistantPack(for tier: AlphaCapabilityTier, jobID: UUID) -> Bool {
        let installed = alphaSystemAssistantPack(for: tier)
        guard let health = AlphaLocalModelRuntime.runtimeHealth(
            activePack: installed,
            requestedTier: tier
        ), health.runtimeMode == .appleFoundationModels else {
            return false
        }

        updateJob(jobID) {
            $0.state = .verifying
            $0.packId = installed.packId
            $0.totalBytes = 0
            $0.bytesDownloaded = 0
            $0.checksumSha256 = installed.checksumSha256
            $0.artifactKind = installed.artifactKind
            $0.runtimeMode = installed.runtimeMode
            $0.developmentOnly = installed.developmentOnly
            $0.failureReason = nil
            $0.updatedAt = .now
        }
        persist()

        guard health.available else {
            if alphaSupportsDownloadedAssistantModels() || alphaAllowsDevelopmentModelArtifacts() {
                updateJob(jobID) {
                    $0.state = .queued
                    $0.packId = installed.packId
                    $0.totalBytes = 0
                    $0.bytesDownloaded = 0
                    $0.checksumSha256 = installed.checksumSha256
                    $0.artifactKind = installed.artifactKind
                    $0.runtimeMode = installed.runtimeMode
                    $0.developmentOnly = installed.developmentOnly
                    $0.failureReason = nil
                    $0.updatedAt = .now
                }
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Private assistant download queued",
                        detail: rossLocalized("privacy_ledger_private_assistant_download_queued_detail"),
                        purpose: .model_catalog,
                        payloadClass: .no_case_data,
                        endpointLabel: "device://private-assistant",
                        success: true
                    ),
                    at: 0
                )
                persist()
                return false
            }

            updateJob(jobID) {
                $0.state = .failed
                $0.failureReason = rossLocalized("runtime_health_foundation_unavailable")
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Private assistant setup unavailable",
                    detail: rossLocalized("privacy_ledger_private_assistant_unavailable_detail"),
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://private-assistant",
                    success: false
                ),
                at: 0
            )
            persist()
            return true
        }

        upsertInstalledPack(installed, activate: true)
        persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
            persisted.modelUpdateCandidates,
            for: tier
        )
        updateJob(jobID) {
            $0.state = .installed
            $0.bytesDownloaded = 0
            $0.totalBytes = 0
            $0.completedAt = .now
            $0.updatedAt = .now
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Private assistant enabled",
                detail: "Ross turned on the on-device assistant supplied by this iPhone. Case files stayed on this device.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://private-assistant",
                success: true
            ),
            at: 0
        )
        persist()
        return true
    }

    func installDevelopmentPackForTestRun(tier: AlphaCapabilityTier, jobID: UUID) async -> Bool {
        guard alphaAllowsDevelopmentModelArtifacts() else { return false }
        do {
            let fallback = try await store.writeDevPackArtifact(for: tier)
            let installed = AlphaInstalledModelPack(
                packId: "\(tier.rawValue)-test-pack",
                tier: tier,
                installPath: fallback.relativePath,
                checksumSha256: fallback.checksum,
                artifactKind: "test_only_tiny_artifact",
                runtimeMode: .deterministicDev,
                developmentOnly: true,
                isActive: true
            )
            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
            persisted.installedPacks.removeAll {
                AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier)
            }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
            resumePendingAskUpgradeIfReady(
                activeTier: tier,
                activeRuntimeMode: .deterministicDev
            )
            updateJob(jobID) {
                $0.state = .installed
                $0.packId = installed.packId
                $0.bytesDownloaded = fallback.bytes
                $0.totalBytes = fallback.bytes
                $0.checksumSha256 = fallback.checksum
                $0.artifactKind = installed.artifactKind
                $0.runtimeMode = installed.runtimeMode
                $0.developmentOnly = installed.developmentOnly
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Test assistant installed",
                    detail: "A tiny test-only assistant setup was installed for automated tests. Device setup uses private assistant setup files.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://private-assistant-test",
                    success: true
                ),
                at: 0
            )
            persist()
            return true
        } catch {
            return false
        }
    }

    func downloadAssistantModelArtifact(
        _ artifact: AlphaAssistantDownloadDescriptor,
        tier: AlphaCapabilityTier,
        jobID: UUID,
        progressOffsetBytes: Int64 = 0,
        progressTotalBytes: Int64? = nil,
        allowsResumePersistence: Bool = true
    ) async throws -> URL {
        alphaPurgeTemporaryAssistantDownloadFiles()
        let isRealMode = true
        if isRealMode && (artifact.downloadURLString.contains("__REPLACE_WITH_VERIFIED") || !artifact.verified || !artifact.releaseReady) {
            throw AlphaAssistantDownloadError.invalidURL
        }

        if let directMLXRepositoryID = alphaDirectMLXRepositoryID(for: artifact) {
            return try await downloadDirectMLXRepositoryArtifact(
                artifact,
                repoID: directMLXRepositoryID,
                tier: tier,
                jobID: jobID,
                progressOffsetBytes: progressOffsetBytes,
                progressTotalBytes: progressTotalBytes
            )
        }

        guard let url = URL(string: artifact.downloadURLString) else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10_800
        request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let taskBox = assistantDownloadTaskBoxes[jobID] ?? {
            let created = AlphaAssistantDownloadTaskBox()
            assistantDownloadTaskBoxes[jobID] = created
            return created
        }()
        taskBox.pausedByUser = false
        taskBox.supportsResumePersistence = allowsResumePersistence
        taskBox.lastPublishedProgressBytes = 0
        taskBox.lastPublishedProgressAt = .distantPast
        let fileExtension = (artifact.fileName as NSString).pathExtension.isEmpty
            ? "gguf"
            : (artifact.fileName as NSString).pathExtension
        let baseName = artifact.fileName
            .replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ross-pending-\(tier.rawValue)-\(baseName.isEmpty ? artifact.packId : baseName)")
            .appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: destinationURL)

        let persistedResumeData = allowsResumePersistence
            ? (try? await store.loadModelResumeData(
                relativePath: persisted.modelJobs.first(where: { $0.id == jobID })?.resumeDataRelativePath
            ))
            : nil
        let resumeData = taskBox.resumeData ?? persistedResumeData
        let allowsMobileData = persisted.modelJobs.first(where: { $0.id == jobID })?.networkPolicy == .mobileAllowed
        taskBox.resumeData = nil

        return try await withTaskCancellationHandler {
            do {
                let progress: AlphaBackgroundModelDownloadCenter.ProgressHandler = { [weak self] received, expected in
                    await MainActor.run {
                        guard let self else { return }
                        let expectedBytes = progressTotalBytes ?? (expected > 0 ? expected : artifact.sizeBytes)
                        let minimumByteDelta = max(Int64(8 * 1024 * 1024), expectedBytes / 200)
                        let now = Date()
                        let combinedReceived = max(0, progressOffsetBytes + received)
                        let finished = expectedBytes > 0 && combinedReceived >= expectedBytes
                        let byteDelta = combinedReceived - taskBox.lastPublishedProgressBytes
                        guard finished ||
                            byteDelta >= minimumByteDelta ||
                            now.timeIntervalSince(taskBox.lastPublishedProgressAt) >= 0.75 else {
                            return
                        }
                        taskBox.lastPublishedProgressBytes = combinedReceived
                        taskBox.lastPublishedProgressAt = now
                        self.updateJob(jobID) {
                            $0.bytesDownloaded = combinedReceived
                            if let progressTotalBytes {
                                $0.totalBytes = progressTotalBytes
                            } else if expected > 0 {
                                $0.totalBytes = expected
                            }
                            $0.updatedAt = .now
                        }
                    }
                }
                let fileURL: URL
                do {
                    fileURL = try await AlphaBackgroundModelDownloadCenter.shared.download(
                        request: request,
                        jobID: jobID,
                        resumeData: resumeData,
                        allowsMobileData: allowsMobileData,
                        destinationURL: destinationURL,
                        progress: progress
                    )
                } catch {
                    let nsError = error as NSError
                    if resumeData != nil, shouldRestartAssistantDownloadWithoutResumeData(nsError) {
                        await recordStaleResumeDataRestart(for: jobID)
                        fileURL = try await AlphaBackgroundModelDownloadCenter.shared.download(
                            request: request,
                            jobID: jobID,
                            resumeData: nil,
                            allowsMobileData: allowsMobileData,
                            destinationURL: destinationURL,
                            progress: progress
                        )
                    } else if resumeData == nil, shouldRetryAssistantDownloadInForeground(nsError) {
                        fileURL = try await foregroundDownloadAssistantModelArtifact(
                            request: request,
                            jobID: jobID,
                            destinationURL: destinationURL,
                            progress: progress
                        )
                    } else {
                        throw error
                    }
                }
                taskBox.resumeData = nil
                if allowsResumePersistence {
                    await store.removeModelResumeData(
                        relativePath: persisted.modelJobs.first(where: { $0.id == jobID })?.resumeDataRelativePath
                    )
                }
                updateJob(jobID) {
                    if allowsResumePersistence {
                        $0.resumeDataRelativePath = nil
                    }
                    $0.updatedAt = .now
                }
                _ = alphaSweepTemporaryAssistantDownloads()
                return fileURL
            } catch {
                _ = alphaSweepTemporaryAssistantDownloads()
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain,
                   nsError.code == NSURLErrorCancelled,
                   taskBox.pausedByUser {
                    throw AlphaAssistantDownloadError.pausedByUser
                }
                throw error
            }
        } onCancel: {
            taskBox.progressTask?.cancel()
            taskBox.task?.cancel()
            AlphaBackgroundModelDownloadCenter.shared.cancel(jobID: jobID) { _ in }
            _ = alphaSweepTemporaryAssistantDownloads()
        }
    }

    private func directMLXRepositoryEntries(
        repoID: String,
        expectedBytes: Int64
    ) async throws -> [AlphaHuggingFaceRepositoryTreeEntry] {
        guard let url = alphaHuggingFaceRepositoryTreeURL(repoID: repoID) else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 120
        request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        guard (200...299).contains(http.statusCode) else {
            throw AlphaAssistantDownloadError.httpStatus(http.statusCode)
        }

        let entries = try JSONDecoder().decode([AlphaHuggingFaceRepositoryTreeEntry].self, from: data)
        let includedEntries = alphaIncludedDirectMLXRepositoryEntries(from: entries)
        let reportedBytes = includedEntries.reduce(into: Int64(0)) { total, entry in
            total += max(entry.size ?? 0, 0)
        }
        guard !includedEntries.isEmpty, reportedBytes > 0 else {
            throw AlphaAssistantDownloadError.preflightMissingSize
        }
        guard !alphaDirectMLXRepositoryEntriesRequireUnsupportedOptiQRuntime(includedEntries) else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        guard expectedBytes <= 0 || reportedBytes == expectedBytes else {
            throw AlphaAssistantDownloadError.preflightSizeMismatch(expected: expectedBytes, reported: reportedBytes)
        }
        return includedEntries
    }

    private func downloadDirectMLXRepositoryArtifact(
        _ artifact: AlphaAssistantDownloadDescriptor,
        repoID: String,
        tier: AlphaCapabilityTier,
        jobID: UUID,
        progressOffsetBytes: Int64 = 0,
        progressTotalBytes: Int64? = nil
    ) async throws -> URL {
        let entries = try await directMLXRepositoryEntries(repoID: repoID, expectedBytes: artifact.sizeBytes)
        let taskBox = assistantDownloadTaskBoxes[jobID] ?? {
            let created = AlphaAssistantDownloadTaskBox()
            assistantDownloadTaskBoxes[jobID] = created
            return created
        }()
        taskBox.pausedByUser = false
        taskBox.supportsResumePersistence = false
        taskBox.resumeData = nil
        taskBox.lastPublishedProgressBytes = 0
        taskBox.lastPublishedProgressAt = .distantPast

        let safeBaseName = artifact.fileName
            .replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ross-pending-\(tier.rawValue)-\(safeBaseName.isEmpty ? artifact.packId : safeBaseName)", isDirectory: true)
        try? FileManager.default.removeItem(at: destinationDirectory)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let session = URLSession(configuration: .ephemeral)
        taskBox.session = session

        do {
            let expectedTotalBytes = progressTotalBytes ?? artifact.sizeBytes
            var combinedReceived = progressOffsetBytes
            for entry in entries {
                try Task.checkCancellation()
                guard let fileURL = alphaHuggingFaceRepositoryResolveURL(repoID: repoID, path: entry.path) else {
                    throw AlphaAssistantDownloadError.invalidURL
                }
                var request = URLRequest(url: fileURL)
                request.httpMethod = "GET"
                request.timeoutInterval = 10_800
                request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")
                request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

                let localFileURL = destinationDirectory.appendingPathComponent(entry.path)
                try FileManager.default.createDirectory(
                    at: localFileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let (temporaryURL, response) = try await session.download(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AlphaAssistantDownloadError.invalidURL
                }
                guard (200...299).contains(http.statusCode) else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    throw AlphaAssistantDownloadError.httpStatus(http.statusCode)
                }

                let downloadedBytes = downloadedFileSize(at: temporaryURL)
                let expectedFileBytes = max(entry.size ?? 0, 0)
                guard expectedFileBytes <= 0 || downloadedBytes == expectedFileBytes else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    throw AlphaAssistantDownloadError.preflightSizeMismatch(expected: expectedFileBytes, reported: downloadedBytes)
                }

                try? FileManager.default.removeItem(at: localFileURL)
                try FileManager.default.moveItem(at: temporaryURL, to: localFileURL)

                combinedReceived += downloadedBytes
                updateJob(jobID) {
                    $0.bytesDownloaded = combinedReceived
                    $0.totalBytes = expectedTotalBytes
                    $0.updatedAt = .now
                }
            }
            taskBox.session = nil
            session.finishTasksAndInvalidate()
            return destinationDirectory
        } catch {
            taskBox.session = nil
            session.invalidateAndCancel()
            try? FileManager.default.removeItem(at: destinationDirectory)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled,
               taskBox.pausedByUser {
                throw AlphaAssistantDownloadError.pausedByUser
            }
            throw error
        }
    }

    func preflightAssistantModelArtifact(_ artifact: AlphaAssistantDownloadDescriptor, jobID: UUID) async throws -> AlphaAssistantDownloadPreflight {
        guard let url = URL(string: artifact.downloadURLString) else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 45
        request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        updateJob(jobID) {
            $0.failureReason = nil
            $0.updatedAt = .now
        }

        let (_, response) = try await URLSession.shared.data(
            for: request,
            delegate: AlphaAssistantPreflightRedirectDelegate()
        )
        guard let http = response as? HTTPURLResponse else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        let preflight = try AlphaAssistantDownloadPreflight.parse(response: http, expectedBytes: artifact.sizeBytes)
        updateJob(jobID) {
            $0.totalBytes = preflight.reportedBytes
            if let checksum = artifact.checksumSha256.isEmpty ? preflight.effectiveChecksumSha256 : artifact.checksumSha256 {
                $0.checksumSha256 = checksum
            }
            $0.updatedAt = .now
        }
        return preflight
    }

    func probeAssistantModelRange(_ artifact: AlphaAssistantDownloadDescriptor, preflight: AlphaAssistantDownloadPreflight) async throws -> AlphaAssistantRangeProbe {
        guard let url = URL(string: artifact.downloadURLString) else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        let probeLength = min(Int64(64 * 1024), preflight.reportedBytes)
        let startByte = max(0, preflight.reportedBytes - probeLength)
        let endByte = max(startByte, preflight.reportedBytes - 1)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("bytes=\(startByte)-\(endByte)", forHTTPHeaderField: "Range")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        return try AlphaAssistantRangeProbe.parse(
            response: http,
            receivedBytes: Int64(data.count),
            expectedStart: startByte,
            expectedEnd: endByte,
            expectedTotal: preflight.reportedBytes
        )
    }

    func shouldRetryAssistantDownloadInForeground(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        switch error.code {
        case NSURLErrorUnknown,
             NSURLErrorCancelled,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotDecodeRawData,
             NSURLErrorCannotDecodeContentData:
            return true
        default:
            return false
        }
    }

    func foregroundDownloadAssistantModelArtifact(
        request: URLRequest,
        jobID: UUID,
        destinationURL: URL,
        progress: @escaping AlphaBackgroundModelDownloadCenter.ProgressHandler
    ) async throws -> URL {
        updateJob(jobID) {
            $0.failureReason = nil
            $0.updatedAt = .now
        }
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: temporaryURL)
            _ = alphaSweepTemporaryAssistantDownloads()
            throw AlphaAssistantDownloadError.httpStatus(http.statusCode)
        }
        let bytes = downloadedFileSize(at: temporaryURL)
        await progress(bytes, bytes)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        _ = alphaSweepTemporaryAssistantDownloads()
        return destinationURL
    }

    func downloadedFileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    func verifiedExistingAssistantArtifact(
        for tier: AlphaCapabilityTier,
        artifact: AlphaAssistantDownloadDescriptor
    ) async -> (relativePath: String, checksum: String, bytes: Int64)? {
        let usesPackagedDirectory = alphaPackagedMLXArchiveArtifact(
            fileName: artifact.fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: artifact.runtimeMode
        )
        let installedName = usesPackagedDirectory
            ? alphaNormalizedInstalledDirectoryName(
                requestedFileName: artifact.fileName,
                fallbackName: artifact.fileName
            )
            : artifact.fileName
        let relativePath = "model-packs/\(tier.rawValue)/\(installedName)"
        let fileURL = alphaAbsoluteURL(for: relativePath)
        let expectedBytes = artifact.sizeBytes
        let expectedChecksum = artifact.checksumSha256

        return await Task.detached(priority: .utility) { () -> (relativePath: String, checksum: String, bytes: Int64)? in
            guard let verified = alphaModelArtifactVerification(at: fileURL) else {
                return nil
            }
            if usesPackagedDirectory {
                guard let manifest = alphaModelArtifactManifest(forFileAt: fileURL),
                      manifest.packId == artifact.packId,
                      manifest.tier == tier,
                      manifest.relativePath == relativePath,
                      manifest.artifactKind == artifact.artifactKind,
                      manifest.runtimeMode == artifact.runtimeMode,
                      manifest.developmentOnly == artifact.developmentOnly,
                      manifest.bytes == verified.bytes,
                      manifest.checksumSha256.caseInsensitiveCompare(verified.checksum) == .orderedSame else {
                    return nil
                }
                return (relativePath, verified.checksum, verified.bytes)
            }

            if let expectedDraftArtifact = artifact.draftArtifact {
                let expectedDraftURL = alphaAbsoluteURL(
                    for: "model-packs/\(tier.rawValue)/\(expectedDraftArtifact.fileName)"
                )
                guard let verifiedDraft = alphaModelArtifactVerification(at: expectedDraftURL),
                      verifiedDraft.bytes == expectedDraftArtifact.sizeBytes,
                      verifiedDraft.checksum.caseInsensitiveCompare(expectedDraftArtifact.checksumSha256) == .orderedSame else {
                    return nil
                }
            }

            guard verified.bytes == expectedBytes else { return nil }
            guard !expectedChecksum.isEmpty else {
                return (relativePath, "catalog-size:\(artifact.fileName):\(verified.bytes)", verified.bytes)
            }
            guard verified.checksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
                return nil
            }
            return (relativePath, verified.checksum, verified.bytes)
        }.value
    }

    func assistantDownloadFailureMessage(_ error: any Error) -> String {
        let nsError = error as NSError
        if let message = alphaAssistantNetworkDownloadFailureMessage(nsError: nsError) {
            return message
        }
        let technicalMarkers = [
            "nserror",
            "nsurlerrordomain",
            "nscocoaerrordomain",
            "rossalphapack",
            "checksum",
            "error domain",
            "error code",
            " error "
        ]
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty,
           description.localizedCaseInsensitiveContains("unknown error") == false {
            let lowercasedDescription = description.lowercased()
            if !technicalMarkers.contains(where: lowercasedDescription.contains) {
                return description
            }
        }
        let message = error.localizedDescription
        let lowercasedMessage = message.lowercased()
        if !message.isEmpty,
           message.localizedCaseInsensitiveContains("unknown error") == false,
           !technicalMarkers.contains(where: lowercasedMessage.contains) {
            return message
        }

        switch (nsError.domain, nsError.code) {
        default:
            return rossLocalized("assistant_download_error_verification_failed")
        }
    }

    func startPackDownload(
        for tier: AlphaCapabilityTier,
        mobileAllowed: Bool,
        requestedRuntimeMode: AlphaPackRuntimeMode? = nil
    ) async {
        await startPackDownload(
            for: tier,
            mobileAllowed: mobileAllowed,
            existingJobID: nil,
            requestedRuntimeMode: requestedRuntimeMode
        )
    }

    func systemAssistantHealth(for tier: AlphaCapabilityTier) -> AlphaLocalRuntimeHealth? {
        guard !alphaAllowsDevelopmentModelArtifacts() else { return nil }
        let installed = alphaSystemAssistantPack(for: tier)
        guard let health = AlphaLocalModelRuntime.runtimeHealth(
            activePack: installed,
            requestedTier: tier
        ), health.runtimeMode == .appleFoundationModels else {
            return nil
        }
        return health
    }

    private func systemAssistantReadyForActivation(for tier: AlphaCapabilityTier) -> Bool {
        systemAssistantHealth(for: tier)?.available == true
    }

    func startPackDownload(
        for tier: AlphaCapabilityTier,
        mobileAllowed: Bool,
        existingJobID: UUID? = nil,
        forceRefreshInstalledPack: Bool = false,
        targetPackId: String? = nil,
        requestedRuntimeMode: AlphaPackRuntimeMode? = nil
    ) async {
        cancelPrivateAISnapshotValidation()
        let artifact = alphaAssistantModelArtifact(for: tier)
        let lastInvocation = alphaLastModelInvocation(in: persisted)
        let preferredRuntime = requestedRuntimeMode ?? alphaPreferredAssistantSetupRuntimeMode(
            for: tier,
            existingRuntimeMode: alphaExistingRuntimeMode(for: tier, installedPacks: persisted.installedPacks),
            lastInvocation: lastInvocation
        )
        clearAssistantSetupRuntimeOverride(for: tier)
        let fallbackDownload = alphaPreferredAssistantDownloadFallback(
            for: tier,
            preferredRuntimeMode: preferredRuntime,
            targetPackId: targetPackId,
            cachedDownloads: persisted.cachedAssistantDownloads
        )
        let cachedReuseCatalog = alphaPreferredCachedAssistantInstalledReuseCatalogDescriptor(
            for: tier,
            preferredRuntimeMode: preferredRuntime,
            targetPackId: targetPackId,
            cachedCatalogs: persisted.cachedAssistantCatalogs
        )
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let existingJob = existingJobID.flatMap { requestedID in
            persisted.modelJobs.first { $0.id == requestedID }
        } ?? persisted.modelJobs.first { job in
            AlphaCapabilityTier.assistantSelectionsMatch(job.tier, tier) &&
                (targetPackId == nil || job.packId == targetPackId) &&
                (job.state == .queued ||
                 job.state == .downloading ||
                 job.state == .verifying ||
                 job.state == .pausedWaitingForWifi ||
                 job.state == .pausedUser ||
                 job.state == .pausedNoStorage ||
                 job.state == .pausedError)
        }

        let job: AlphaModelDownloadJob
        let shouldRecordSelection: Bool
        if let existingJob {
            var reusedJob = existingJob
            let requiresReset =
                !AlphaCapabilityTier.assistantSelectionsMatch(existingJob.tier, tier) ||
                existingJob.packId != fallbackDownload.packId ||
                existingJob.runtimeMode != fallbackDownload.runtimeMode ||
                existingJob.artifactKind != fallbackDownload.artifactKind
            reusedJob.tier = tier
            reusedJob.packId = fallbackDownload.packId
            reusedJob.networkPolicy = policy
            reusedJob.totalBytes = fallbackDownload.sizeBytes
            reusedJob.checksumSha256 = fallbackDownload.checksumSha256
            reusedJob.artifactKind = fallbackDownload.artifactKind
            reusedJob.runtimeMode = fallbackDownload.runtimeMode
            reusedJob.developmentOnly = fallbackDownload.developmentOnly
            reusedJob.updatedAt = .now
            if requiresReset {
                reusedJob.state = .queued
                reusedJob.bytesDownloaded = 0
                reusedJob.failureReason = nil
                reusedJob.resumeDataRelativePath = nil
                reusedJob.completedAt = nil
            }
            job = reusedJob
            shouldRecordSelection = false
        } else {
            let sessionId = "hf-\(UUID().uuidString.prefix(8))"
            job = AlphaModelDownloadJob(
                sessionId: sessionId,
                packId: fallbackDownload.packId,
                tier: tier,
                state: .queued,
                networkPolicy: policy,
                bytesDownloaded: 0,
                totalBytes: fallbackDownload.sizeBytes,
                checksumSha256: fallbackDownload.checksumSha256,
                artifactKind: fallbackDownload.artifactKind,
                runtimeMode: fallbackDownload.runtimeMode,
                developmentOnly: fallbackDownload.developmentOnly
            )
            shouldRecordSelection = true
        }

        upsertJob(job)
        if preferredRuntime == .appleFoundationModels,
           systemAssistantReadyForActivation(for: tier),
           prepareSystemAssistantPack(for: tier, jobID: job.id) {
            return
        }

        if let existingInstalled = persisted.installedPacks.first(where: { pack in
            AlphaCapabilityTier.assistantSelectionsMatch(pack.tier, tier) &&
                installedModelPackFileIsUsable(pack) &&
                (
                    alphaShouldReuseInstalledAssistantPack(
                        pack,
                        preferredRuntimeMode: preferredRuntime,
                        targetPackId: targetPackId,
                        preferredDescriptor: fallbackDownload,
                        forceDownload: forceRefreshInstalledPack
                    ) ||
                    cachedReuseCatalog.map {
                        alphaInstalledAssistantPackMatchesCatalogDescriptor(
                            pack,
                            descriptor: $0,
                            forceDownload: forceRefreshInstalledPack
                        )
                    } ?? false
                )
        }) {
            activateInstalledPack(existingInstalled)
            return
        }

        let keptResumePaths = Set(persisted.modelJobs.compactMap(\.resumeDataRelativePath))
        Task {
            await store.sweepModelResumeData(keeping: keptResumePaths)
        }
        if shouldRecordSelection {
            persisted.lastModelCatalogRefresh = .now
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant selected",
                    detail: rossLocalized("privacy_ledger_assistant_selected_detail"),
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant",
                    success: true
                ),
                at: 0
            )
            persist()
        }

        if preferredRuntime == .appleFoundationModels,
           !alphaAllowsDevelopmentModelArtifacts(),
           prepareSystemAssistantPack(for: tier, jobID: job.id) {
            return
        }

        let resolvedDownload: AlphaAssistantDownloadDescriptor
        if alphaDirectMLXRepositoryID(for: fallbackDownload) != nil,
           !alphaShouldResolveAssistantDownloadFromBackend(
            fallbackDownload: fallbackDownload,
            for: tier,
            preferredRuntimeMode: preferredRuntime,
            targetPackId: targetPackId,
            cachedCatalogs: persisted.cachedAssistantCatalogs
           ) {
            resolvedDownload = fallbackDownload
        } else {
            do {
                let catalog = try await backend.fetchCatalog(for: tier)
                let preferredCatalog = alphaAssistantCatalogDescriptor(
                    for: tier,
                    preferredRuntimeMode: preferredRuntime,
                    targetPackId: targetPackId,
                    compatibleOnly: true,
                    manifest: catalog
                )
                let session = try await backend.createDownloadSession(for: preferredCatalog.packId)
                let resolvedURL = try await backend.resolveArtifactURL(for: session.artifact)
                resolvedDownload = alphaAssistantDownloadDescriptor(
                    for: tier,
                    session: session,
                    resolvedURLString: resolvedURL.absoluteString
                )
            } catch {
                resolvedDownload = fallbackDownload
            }
        }

        if resolvedDownload.sessionId != nil,
           alphaAssistantDownloadDescriptorSupportsCurrentInstaller(resolvedDownload) {
            let cachedDescriptor = alphaReusableAssistantDownloadDescriptor(resolvedDownload)
            persisted.cachedAssistantDownloads = alphaMergedAssistantDownloadCache(
                existing: persisted.cachedAssistantDownloads ?? [],
                appending: cachedDescriptor
            )
        }

        let isResumingPartialDownload = assistantDownloadTaskBoxes[job.id]?.resumeData != nil

        updateJob(job.id) {
            if let sessionId = resolvedDownload.sessionId {
                $0.sessionId = sessionId
            }
            $0.packId = resolvedDownload.packId
            $0.networkPolicy = policy
            $0.totalBytes = resolvedDownload.sizeBytes
            if !isResumingPartialDownload {
                $0.bytesDownloaded = 0
                $0.resumeDataRelativePath = nil
            }
            $0.checksumSha256 = resolvedDownload.checksumSha256
            $0.artifactKind = resolvedDownload.artifactKind
            $0.runtimeMode = resolvedDownload.runtimeMode
            $0.developmentOnly = resolvedDownload.developmentOnly
            $0.failureReason = nil
            $0.updatedAt = .now
        }
        persist()

        if alphaAllowsDevelopmentModelArtifacts() {
            _ = await installDevelopmentPackForTestRun(tier: tier, jobID: job.id)
            return
        }

        if let existingInstalled = persisted.installedPacks.first(where: { pack in
            pack.tier == tier &&
                installedModelPackFileIsUsable(pack) &&
                alphaInstalledAssistantPackMatchesDownloadDescriptor(
                    pack,
                    descriptor: resolvedDownload,
                    forceDownload: forceRefreshInstalledPack
                )
        }) {
            activateInstalledPack(existingInstalled)
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = resolvedDownload.sizeBytes
                $0.totalBytes = resolvedDownload.sizeBytes
                $0.checksumSha256 = existingInstalled.checksumSha256
                $0.artifactKind = existingInstalled.artifactKind
                $0.runtimeMode = existingInstalled.runtimeMode
                $0.developmentOnly = existingInstalled.developmentOnly
                $0.failureReason = nil
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persist()
            return
        }

        updateJob(job.id) {
            $0.state = .verifying
            $0.failureReason = nil
            $0.updatedAt = .now
        }
        persist()

        if let existingArtifact = await verifiedExistingAssistantArtifact(for: tier, artifact: resolvedDownload) {
            let installed = AlphaInstalledModelPack(
                packId: resolvedDownload.packId,
                tier: tier,
                installPath: existingArtifact.relativePath,
                checksumSha256: existingArtifact.checksum,
                artifactKind: resolvedDownload.artifactKind,
                runtimeMode: resolvedDownload.runtimeMode,
                developmentOnly: resolvedDownload.developmentOnly,
                checksumVerified: true,
                isActive: true
            )
            guard alphaDownloadedAssistantArtifactPassesRuntimeValidation(installed) else {
                await store.removeDownloadedPackArtifact(relativePath: existingArtifact.relativePath)
                updateJob(job.id) {
                    $0.state = .failed
                    $0.bytesDownloaded = existingArtifact.bytes
                    $0.totalBytes = existingArtifact.bytes
                    $0.checksumSha256 = existingArtifact.checksum
                    $0.failureReason = assistantDownloadFailureMessage(
                        NSError(
                            domain: "RossAlphaPack",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: alphaAssistantExistingSetupRepairDetail]
                        )
                    )
                    $0.updatedAt = .now
                }
                persisted.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Assistant file verification failed",
                        detail: alphaAssistantExistingSetupRepairDetail,
                        purpose: .model_verification,
                        payloadClass: .no_case_data,
                        endpointLabel: "device://model-verify",
                        success: false
                    ),
                    at: 0
                )
                persist()
                return
            }
            upsertInstalledPack(installed, activate: true)
            persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
                persisted.modelUpdateCandidates,
                for: tier
            )
            persisted.modelJobs.removeAll {
                AlphaCapabilityTier.assistantSelectionsMatch($0.tier, tier) &&
                    $0.state != .installed &&
                    $0.id != job.id
            }
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = existingArtifact.bytes
                $0.totalBytes = existingArtifact.bytes
                $0.checksumSha256 = existingArtifact.checksum
                $0.artifactKind = installed.artifactKind
                $0.runtimeMode = installed.runtimeMode
                $0.developmentOnly = installed.developmentOnly
                $0.failureReason = nil
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant verified",
                    detail: "\(tier.setupTitle) was already downloaded and passed local verification.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
            assistantDownloadTaskBoxes[job.id] = nil
            persist()
            return
        }

        let availableStorageGB = alphaAvailableStorageInGigabytes()
        let companionBytes = resolvedDownload.draftArtifact?.sizeBytes ?? 0
        let requiredFreeSpaceGB = max(
            artifact.requiredFreeSpaceGB,
            Int(ceil(Double(resolvedDownload.sizeBytes + companionBytes) / 1_000_000_000)) + 1
        )
        guard availableStorageGB >= requiredFreeSpaceGB else {
            assistantDownloadTaskBoxes[job.id] = nil
            updateJob(job.id) {
                $0.state = .pausedNoStorage
                $0.failureReason = AlphaAssistantDownloadError.insufficientStorage(
                    requiredGB: requiredFreeSpaceGB,
                    availableGB: availableStorageGB
                ).errorDescription
                $0.updatedAt = .now
            }
            persist()
            return
        }

        do {
            let isDirectMLXRepository = alphaDirectMLXRepositoryID(for: resolvedDownload) != nil
            let preflight: AlphaAssistantDownloadPreflight?
            let expectedChecksum: String
            if isDirectMLXRepository {
                preflight = nil
                expectedChecksum = resolvedDownload.checksumSha256
            } else {
                let verifiedPreflight = try await preflightAssistantModelArtifact(resolvedDownload, jobID: job.id)
                expectedChecksum = try verifiedPreflight.expectedChecksum(catalogChecksum: resolvedDownload.checksumSha256)
                _ = try await probeAssistantModelRange(resolvedDownload, preflight: verifiedPreflight)
                preflight = verifiedPreflight
            }
            let draftPreflight: AlphaAssistantDownloadPreflight?
            if let draftArtifact = resolvedDownload.draftArtifact {
                guard let draftDescriptor = alphaAssistantDraftDownloadDescriptor(
                    from: resolvedDownload,
                    draftArtifact: draftArtifact
                ) else {
                    throw AlphaAssistantDownloadError.invalidURL
                }
                if alphaDirectMLXRepositoryID(for: draftDescriptor) != nil {
                    draftPreflight = nil
                } else {
                    let verifiedDraftPreflight = try await preflightAssistantModelArtifact(
                        draftDescriptor,
                        jobID: job.id
                    )
                    _ = try await probeAssistantModelRange(
                        draftDescriptor,
                        preflight: verifiedDraftPreflight
                    )
                    draftPreflight = verifiedDraftPreflight
                }
            } else {
                draftPreflight = nil
            }
            let combinedExpectedBytes =
                (preflight?.reportedBytes ?? resolvedDownload.sizeBytes) +
                (draftPreflight?.reportedBytes ?? resolvedDownload.draftArtifact?.sizeBytes ?? 0)

            updateJob(job.id) {
                $0.state = .downloading
                $0.failureReason = nil
                $0.totalBytes = combinedExpectedBytes
                $0.checksumSha256 = expectedChecksum
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant download verified",
                    detail: "Ross checked the assistant setup download before starting. Case files stayed on this device.",
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant-download",
                    success: true
                ),
                at: 0
            )
            persist()

            let downloadedFileURL = try await downloadAssistantModelArtifact(
                resolvedDownload,
                tier: tier,
                jobID: job.id,
                progressTotalBytes: combinedExpectedBytes,
                allowsResumePersistence: true
            )
            let downloadedBytes = downloadedFileSize(at: downloadedFileURL)
            let draftDownloadedFileURL: URL?
            let downloadedDraftBytes: Int64
            if let draftArtifact = resolvedDownload.draftArtifact {
                guard let draftDescriptor = alphaAssistantDraftDownloadDescriptor(
                    from: resolvedDownload,
                    draftArtifact: draftArtifact
                ) else {
                    throw AlphaAssistantDownloadError.invalidURL
                }
                draftDownloadedFileURL = try await downloadAssistantModelArtifact(
                    draftDescriptor,
                    tier: tier,
                    jobID: job.id,
                    progressOffsetBytes: downloadedBytes > 0 ? downloadedBytes : resolvedDownload.sizeBytes,
                    progressTotalBytes: combinedExpectedBytes,
                    allowsResumePersistence: false
                )
                downloadedDraftBytes = draftDownloadedFileURL.map { downloadedFileSize(at: $0) } ?? 0
            } else {
                draftDownloadedFileURL = nil
                downloadedDraftBytes = 0
            }

            guard persisted.modelJobs.first(where: { $0.id == job.id })?.state != .pausedUser else {
                return
            }

            updateJob(job.id) {
                $0.state = .verifying
                let verifiedMainBytes = downloadedBytes > 0 ? downloadedBytes : resolvedDownload.sizeBytes
                let verifiedDraftBytes = resolvedDownload.draftArtifact == nil
                    ? 0
                    : (
                        downloadedDraftBytes > 0
                            ? downloadedDraftBytes
                            : (draftPreflight?.reportedBytes ?? resolvedDownload.draftArtifact?.sizeBytes ?? 0)
                    )
                $0.bytesDownloaded = verifiedMainBytes + verifiedDraftBytes
                $0.totalBytes = combinedExpectedBytes
                $0.updatedAt = .now
            }
            persist()

            let installedArtifact = try await store.installDownloadedPackArtifact(
                for: tier,
                fileName: resolvedDownload.fileName,
                downloadedFileURL: downloadedFileURL,
                expectedChecksum: expectedChecksum,
                expectedBytes: preflight?.reportedBytes ?? resolvedDownload.sizeBytes,
                packId: resolvedDownload.packId,
                artifactKind: resolvedDownload.artifactKind,
                runtimeMode: resolvedDownload.runtimeMode,
                developmentOnly: resolvedDownload.developmentOnly,
                draftArtifact: resolvedDownload.draftArtifact,
                draftDownloadedFileURL: draftDownloadedFileURL
            )
            let installed = AlphaInstalledModelPack(
                packId: resolvedDownload.packId,
                tier: tier,
                installPath: installedArtifact.relativePath,
                checksumSha256: installedArtifact.checksum,
                artifactKind: resolvedDownload.artifactKind,
                runtimeMode: resolvedDownload.runtimeMode,
                developmentOnly: resolvedDownload.developmentOnly,
                checksumVerified: true,
                isActive: true
            )
            guard alphaDownloadedAssistantArtifactPassesRuntimeValidation(installed) else {
                throw NSError(
                    domain: "RossAlphaPack",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: alphaAssistantExistingSetupRepairDetail]
                )
            }

            upsertInstalledPack(installed, activate: true)
            persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
                persisted.modelUpdateCandidates,
                for: tier
            )
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = combinedExpectedBytes
                $0.totalBytes = combinedExpectedBytes
                $0.checksumSha256 = installedArtifact.checksum
                $0.artifactKind = installed.artifactKind
                $0.runtimeMode = installed.runtimeMode
                $0.developmentOnly = installed.developmentOnly
                $0.failureReason = nil
                $0.updatedAt = .now
                $0.completedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant verified",
                    detail: "\(tier.setupTitle) finished downloading and passed local verification.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
            assistantDownloadTaskBoxes[job.id] = nil
            persist()
        } catch AlphaAssistantDownloadError.pausedByUser {
            alphaPurgeTemporaryAssistantDownloadFiles()
            persist()
        } catch {
            alphaPurgeTemporaryAssistantDownloadFiles()
            updateJob(job.id) {
                $0.state = .failed
                $0.failureReason = assistantDownloadFailureMessage(error)
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant download failed",
                    detail: assistantDownloadFailureMessage(error),
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant-download",
                    success: false
                ),
                at: 0
            )
            if assistantDownloadTaskBoxes[job.id]?.resumeData == nil {
                assistantDownloadTaskBoxes[job.id] = nil
            }
            persist()
        }
    }

    func exportBodyLines(kind: String, caseMatter: AlphaCaseMatter?) -> [String] {
        let title = caseMatter?.title ?? "Ross"
        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        let generatedLine = String(format: rossLocalized("export_generated"), generatedDate)
        let draftReviewLine = rossLocalized("export_draft_review")
        let localReviewFooter = rossLocalized("export_generated_locally_verify")
        guard let caseMatter else {
            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_no_case_selected"),
                "",
                localReviewFooter
            ]
        }

        let documents = caseMatter.documents
        let ignoredFieldIDs = Set(
            caseMatter.advocateCorrections
                .filter { $0.correctionType == .ignoreField }
                .compactMap(\.fieldId)
        )
        let allFields = documents
            .flatMap(\.extractedFields)
            .filter { !ignoredFieldIDs.contains($0.id) }
        let verifiedFields = allFields.filter { !$0.needsReview || $0.userCorrected }
        let pendingFields = allFields.filter(\.needsReview)
        let unresolvedFindings = documents.flatMap(\.extractionFindings).filter { !$0.resolved }
        let refs = caseMatter.sourceRefs.prefix(8).map { "- \($0.label): \($0.detail)" }
        let documentLines = documents.map { alphaPrivateAIDocumentContextLine($0) }
        let missingSourceLabel = rossLocalized("no_linked_source_yet")
        let missingSourceLine = "- \(missingSourceLabel)"

        func uniqueValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            Array(Set(fields.filter { $0.fieldType == type }.map(\.value))).sorted()
        }

        func sourcedValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            fields
                .filter { $0.fieldType == type }
                .map { field in
                    let sourceLabel = field.sourceRefs.first?.label ?? missingSourceLabel
                    return "- \(field.value) (\(sourceLabel))"
                }
        }

        switch kind {
        case "chronology_report":
            let chronologyLines = verifiedFields
                .filter { $0.fieldType == .date || $0.fieldType == .nextDate }
                .sorted { ($0.normalizedValue ?? $0.value) < ($1.normalizedValue ?? $1.value) }
                .map { "- \($0.label): \($0.value) (\($0.sourceRefs.first?.label ?? missingSourceLabel))" }
            let warningLines = unresolvedFindings.map { "- \($0.message)" }
            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_chronology_candidates"),
            ] + (chronologyLines.isEmpty ? [rossLocalized("export_no_chronology_candidates")] : chronologyLines) + [
                "",
                rossLocalized("export_review_warnings"),
            ] + (warningLines.isEmpty ? [rossLocalized("export_no_unresolved_warnings")] : warningLines) + [
                "",
                rossLocalized("export_source_references"),
            ] + (refs.isEmpty ? [missingSourceLine] : refs) + [
                "",
                localReviewFooter
            ]

        case "case_note":
            let missingValue = rossLocalized("export_not_found")
            let court = uniqueValues(for: .court, in: verifiedFields).joined(separator: " | ").ifEmpty(missingValue)
            let caseNumbers = uniqueValues(for: .caseNumber, in: verifiedFields).joined(separator: " | ").ifEmpty(missingValue)
            let parties = uniqueValues(for: .partyName, in: verifiedFields).joined(separator: " | ").ifEmpty(missingValue)
            let dateLines = sourcedValues(for: .date, in: verifiedFields)
            let pendingLines = pendingFields.map { "- \($0.label): \($0.value)" }
            let metadataLines = [
                "\(rossLocalized("export_court")): \(court)",
                "\(rossLocalized("export_case_number")): \(caseNumbers)",
                "\(rossLocalized("export_parties")): \(parties)"
            ]

            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_case_metadata"),
            ] + metadataLines + [
                "",
                rossLocalized("export_document_list"),
            ] + (documentLines.isEmpty ? [rossLocalized("export_no_imported_documents")] : documentLines) + [
                "",
                rossLocalized("export_key_dates"),
            ] + (dateLines.isEmpty ? [rossLocalized("export_no_key_dates")] : dateLines) + [
                "",
                rossLocalized("export_pending_review_fields"),
            ] + (pendingLines.isEmpty ? [rossLocalized("export_no_pending_review_fields")] : pendingLines) + [
                "",
                rossLocalized("export_source_references"),
            ] + (refs.isEmpty ? [missingSourceLine] : refs) + [
                "",
                localReviewFooter
            ]

        case "order_summary":
            let directions = sourcedValues(for: .orderDirection, in: verifiedFields)
            let nextDates = sourcedValues(for: .nextDate, in: verifiedFields)
            let compliance = unresolvedFindings
                .filter { $0.kind == .ambiguousOrderDirection || $0.kind == .dateConflict }
                .map { "- \($0.message)" }
            let pendingLines = pendingFields
                .filter { $0.fieldType == .orderDirection || $0.fieldType == .nextDate || $0.fieldType == .date }
                .map { "- \($0.label): \($0.value)" }

            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_operative_directions"),
            ] + (directions.isEmpty ? [rossLocalized("export_no_operative_directions")] : directions) + [
                "",
                rossLocalized("export_next_date"),
            ] + (nextDates.isEmpty ? ["- \(rossLocalized("export_not_found"))"] : nextDates) + [
                "",
                rossLocalized("export_compliance_requirements"),
            ] + (compliance.isEmpty ? [rossLocalized("export_review_operative_directions")] : compliance) + [
                "",
                rossLocalized("export_please_confirm"),
            ] + (pendingLines.isEmpty ? [rossLocalized("export_no_pending_order_flags")] : pendingLines) + [
                "",
                rossLocalized("export_source_references"),
            ] + (refs.isEmpty ? [missingSourceLine] : refs) + [
                "",
                localReviewFooter
            ]

        case "chat_transcript":
            let turns = caseMatter.chatSessions
                .flatMap(\.turns)
                .sorted { $0.askedAt < $1.askedAt }

            let transcriptLines = turns.flatMap { turn -> [String] in
                var lines = [String(format: rossLocalized("export_chat_question"), turn.question)]
                lines.append(contentsOf: turn.answerSections.map { String(format: rossLocalized("export_chat_answer"), $0) })
                if !turn.sourceRefs.isEmpty {
                    lines.append(String(format: rossLocalized("export_chat_sources"), turn.sourceRefs.map(\.label).joined(separator: " | ")))
                }
                lines.append("")
                return lines
            }

            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_thread_transcript"),
            ] + (transcriptLines.isEmpty ? [rossLocalized("export_no_chat_turns"), ""] : transcriptLines) + [
                localReviewFooter
            ]

        default:
            let notes = caseMatter.draftTasks.map { "- \($0)" }
            return [
                title,
                generatedLine,
                draftReviewLine,
                "",
                rossLocalized("export_summary"),
                caseMatter.summary,
                "",
                rossLocalized("export_working_notes"),
            ] + (notes.isEmpty ? [rossLocalized("export_no_tasks")] : notes) + [
                "",
                rossLocalized("export_source_references"),
            ] + (refs.isEmpty ? [missingSourceLine] : refs) + [
                "",
                localReviewFooter
            ]
        }
    }

    func assistantRuntimeDecision(selectedTier: AlphaCapabilityTier? = nil) -> AlphaAssistantRuntimeDecision {
        let selected = AlphaCapabilityTier.normalizedAssistantSelection(selectedTier ?? self.selectedTier) ?? .quickStart
        let recommended = AlphaCapabilityTier.normalizedAssistantSelection(recommendedOnDeviceTier()) ?? .quickStart
        let effective = selected.rank > recommended.rank ? recommended : selected
        let activeJob = persisted.modelJobs.first {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, effective)
        }
        let installed = persisted.installedPacks.contains {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, effective) && $0.isActive
        }
        let installState: AlphaAssistantInstallState
        if installed {
            installState = .installed
        } else {
            switch activeJob?.state {
            case .queued, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError:
                installState = .queued
            case .downloading, .verifying:
                installState = .downloading
            case .installed:
                installState = .installed
            case .failed:
                installState = .failed
            case .cancelled, .notStarted, .none:
                installState = .notStarted
            }
        }

        let deviceSupportState: AlphaAssistantDeviceSupportState = effective == selected ? .supported : .autoDowngraded
        let reason: String
        if effective == selected {
            reason = "\(selected.title) is suitable for this device."
        } else {
            reason = "\(selected.title) is heavier than this device should run comfortably, so Ross will use \(effective.title) unless storage and memory improve."
        }

        return AlphaAssistantRuntimeDecision(
            selectedTier: selected,
            recommendedTier: recommended,
            effectiveTier: effective,
            displayName: effective.title,
            deviceSupportState: deviceSupportState,
            modelPackId: "\(effective.rawValue)-pack",
            installState: installState,
            reason: reason
        )
    }

    var recommendedAssistantTitle: String {
        switch recommendedOnDeviceTier() {
        case .quickStart:
            return "Phone-optimized reading"
        case .caseAssociate:
            return "Balanced local matter review"
        case .seniorDraftingSupport:
            return "Deeper drafting and review"
        case .flash:
            return "Phone-optimized reading"
        }
    }

    var recommendedAssistantDetail: String {
        let totalMemoryGB = max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let freeStorageGB = max(4, alphaAvailableStorageInGigabytes())
        let summary: String
        switch recommendedOnDeviceTier() {
        case .quickStart:
            summary = "Ross will keep setup lighter on this phone so imports, case review, and short legal questions stay responsive."
        case .caseAssociate:
            summary = "Ross will use a balanced on-device assistant for matter summaries, chronology work, Q&A from your files, and everyday legal review."
        case .seniorDraftingSupport:
            summary = "Ross can prepare a deeper on-device assistant on this phone for longer bundles, hearing prep, and richer drafting support."
        case .flash:
            summary = "Ross will keep setup lighter on this phone so imports, case review, and short legal questions stay responsive."
        }
        return "\(summary) (\(totalMemoryGB) GB memory · \(freeStorageGB) GB free)"
    }

    var recommendedAssistantSetupNote: String {
        switch recommendedOnDeviceTier() {
        case .quickStart:
            return rossLocalized("assistant_setup_note_quick_start")
        case .caseAssociate:
            return rossLocalized("assistant_setup_note_case_associate")
        case .seniorDraftingSupport:
            return rossLocalized("assistant_setup_note_senior_drafting")
        case .flash:
            return rossLocalized("assistant_setup_note_quick_start")
        }
    }

    func alphaAvailableStorageInGigabytes() -> Int {
        let values = try? URL.homeDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let bytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return Int(bytes / 1_073_741_824)
    }

    func alphaCurrentLowPowerMode() -> Bool {
        #if canImport(UIKit)
        ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        false
        #endif
    }

    func buildLocalAskResult(question: String, scopeCaseID: UUID?) -> AlphaAskResult {
        let selectedDocuments = selectedAskDocuments(for: scopeCaseID)
        let selectedDocumentIDs = Set(selectedDocuments.map(\.id))
        let scopedCases: [AlphaCaseMatter]
        if let scopeCaseID {
            scopedCases = persisted.cases.filter { $0.id == scopeCaseID || $0.id == alphaSharedWorkspaceID }
        } else {
            scopedCases = persisted.cases
        }
        let lowered = question.lowercased()
        let asksAboutSchedule = lowered.contains("next date") || lowered.contains("hearing")
        let asksAboutTasks = lowered.contains("task") || lowered.contains("today") || lowered.contains("reminder") || lowered.contains("due")
        let asksAboutReview = lowered.contains("review") || lowered.contains("document") || lowered.contains("order") || lowered.contains("party")
        let asksForMatterSummary = lowered.contains("status of this matter") || lowered.contains("status of this case") || lowered.contains("summarize this matter") || lowered.contains("summarise this matter") || lowered.contains("matter summary")
        let asksForDocumentSummary = lowered.contains("summarize this document") ||
            lowered.contains("summarise this document") ||
            lowered.contains("what is this document about") ||
            lowered.contains("what is the document about") ||
            lowered.contains("what is this file about") ||
            lowered.contains("what did the latest order say") ||
            lowered.contains("latest order") ||
            lowered.contains("current document") ||
            alphaAskQuestionTargetsSelectedDocument(question)
        let asksForImportantDates = lowered.contains("important dates") || lowered.contains("list important dates") || lowered.contains("list dates")
        let asksForNextActions = lowered.contains("what should i do next") || lowered.contains("next actions") || lowered.contains("suggest next action") || lowered.contains("what tasks should i create") || lowered.contains("needs my attention today")
        let asksAboutAssistantSetup = alphaAskQuestionTargetsAssistantSetup(question)
        if asksAboutAssistantSetup {
            return AlphaAskResult(
                chatSessionID: nil,
                chatTurnID: nil,
                kind: .userAsk,
                question: question,
                scopeCaseID: scopeCaseID,
                scopeLabel: scopeLabel(for: scopeCaseID),
                selectedDocumentTitles: [],
                answerTitle: rossLocalized("ask_assistant_setup_title"),
                answerSections: [
                    rossLocalized("ask_assistant_setup_before_detail"),
                    rossLocalized("ask_assistant_setup_after_detail"),
                    rossLocalized("ask_assistant_setup_open_settings_detail")
                ],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: rossLocalized("private_assistant"),
                needsReviewWarning: nil
            )
        }
        let scopedPrimaryCase = scopeCaseID.flatMap { id in persisted.cases.first(where: { $0.id == id }) }
        let selectedDocumentTarget = selectedOrLatestAskDocument(for: scopeCaseID)
        let selectedDocumentsAwaitingExtraction = selectedDocuments.filter { option in
            guard let document = persisted.cases.first(where: { $0.id == option.caseId })?.documents.first(where: { $0.id == option.id }) else {
                return false
            }
            return (document.processingState == .readingText || document.processingState == .imported) &&
                !document.hasAskUsableExtractedText
        }
        if !selectedDocuments.isEmpty && selectedDocumentsAwaitingExtraction.count == selectedDocuments.count {
            let titles = selectedDocumentsAwaitingExtraction.prefix(3).map(\.title)
            let waitingList = titles.joined(separator: ", ")
            let isSingleDocument = selectedDocuments.count == 1
            return AlphaAskResult(
                chatSessionID: nil,
                chatTurnID: nil,
                kind: .userAsk,
                question: question,
                scopeCaseID: scopeCaseID,
                scopeLabel: scopeLabel(for: scopeCaseID),
                selectedDocumentTitles: selectedDocuments.map(\.title),
                answerTitle: alphaAskStillReadingTitle(isSingleDocument: isSingleDocument),
                answerSections: [
                    alphaAskStillReadingDetail(waitingList, isSingleDocument: isSingleDocument),
                    alphaAskWaitForReadableTextDetail(isSingleDocument: isSingleDocument)
                ],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: rossLocalized("reading"),
                needsReviewWarning: nil
            )
        }
        if let target = selectedDocumentTarget,
           target.document.processingState == .readingText || target.document.processingState == .imported,
           !target.document.hasAskUsableExtractedText,
           selectedDocuments.count <= 1,
           asksForDocumentSummary || asksAboutReview {
            return AlphaAskResult(
                chatSessionID: nil,
                chatTurnID: nil,
                kind: .userAsk,
                question: question,
                scopeCaseID: scopeCaseID,
                scopeLabel: scopeLabel(for: scopeCaseID),
                selectedDocumentTitles: [target.document.title],
                answerTitle: alphaAskStillReadingTitle(isSingleDocument: true),
                answerSections: [
                    alphaAskStillReadingDocumentSummaryDetail(target.document.title),
                    rossLocalized("no_public_law_search_used")
                ],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: rossLocalized("reading"),
                needsReviewWarning: nil
            )
        }
        let matchedSources = scopedCases
            .flatMap(\.sourceRefs)
            .filter { selectedDocumentIDs.isEmpty || selectedDocumentIDs.contains($0.documentId) }
            .filter {
                asksAboutSchedule ||
                    asksAboutTasks ||
                    asksAboutReview ||
                    asksForDocumentSummary ||
                    lowered.contains($0.documentTitle.lowercased()) ||
                    lowered.contains(($0.textSnippet ?? "").lowercased())
            }
        let openScopedTasks = tasks(for: scopeCaseID).filter { $0.status == .open }
        let scopedReviewItems = reviewQueue(caseId: scopeCaseID)
            .filter { selectedDocumentIDs.isEmpty || selectedDocumentIDs.contains($0.documentId) }

        var sections: [String] = []
        if asksForMatterSummary, let scopedPrimaryCase {
            sections.append(scopedPrimaryCase.summary)
            if let nextHearing = scopedPrimaryCase.nextHearing {
                sections.append(String(format: rossLocalized("ask_local_next_hearing"), nextHearing.formatted(date: .abbreviated, time: .omitted)))
            }
            if !scopedPrimaryCase.draftTasks.isEmpty {
                let actions = scopedPrimaryCase.draftTasks.prefix(2).joined(separator: "; ")
                sections.append(String(format: rossLocalized("ask_local_next_actions"), actions))
            }
        }
        if asksForDocumentSummary, let target = selectedDocumentTarget {
            let visibleFields = visibleExtractedFields(caseId: target.caseMatter.id, documentId: target.document.id)
            let directionValues = visibleFields
                .filter { [.orderDirection, .issue, .relief].contains($0.fieldType) }
                .map(\.value)
            sections.append(String(format: rossLocalized("ask_local_document_available"), target.document.title))
            if let nextDate = visibleFields.first(where: { $0.fieldType == .nextDate })?.value {
                sections.append(String(format: rossLocalized("ask_local_next_date_found"), nextDate))
            }
            if let direction = directionValues.first {
                sections.append(direction)
            } else if let firstPage = target.document.pages.first?.snippet, !firstPage.isEmpty {
                sections.append(firstPage)
            }
        }
        if asksForImportantDates {
            let dateLines = scopedCases
                .filter { $0.id != alphaSharedWorkspaceID }
                .flatMap { caseMatter in
                    caseMatter.dates
                        .filter { $0.status == .scheduled }
                        .sorted { $0.date < $1.date }
                        .prefix(2)
                        .map { "\(caseMatter.title): \($0.title) on \($0.date.formatted(date: .abbreviated, time: .omitted))" }
                }
            sections.append(contentsOf: dateLines.prefix(3))
        }
        if asksForNextActions, let scopedPrimaryCase {
            let nextActions = scopedPrimaryCase.draftTasks.isEmpty
                ? openScopedTasks.prefix(3).map(\.title)
                : Array(scopedPrimaryCase.draftTasks.prefix(3))
            sections.append(contentsOf: nextActions)
        }
        if asksAboutSchedule {
            let dateLines = cases
                .filter { scopeCaseID == nil || $0.id == scopeCaseID }
                .compactMap { caseMatter -> String? in
                guard let nextDate = caseMatter.nextHearing else { return nil }
                return "\(caseMatter.title): \(nextDate.formatted(date: .abbreviated, time: .omitted))"
            }
            sections.append(contentsOf: dateLines.prefix(2))
        }
        if asksAboutTasks {
            let taskLines = openScopedTasks.prefix(3).map { task in
                if let dueDate = task.dueDate {
                    return "\(task.title) by \(dueDate.formatted(date: .abbreviated, time: .omitted))"
                }
                return task.title
            }
            sections.append(contentsOf: taskLines)
        }
        if asksAboutReview {
            let reviewItems = scopedReviewItems
                .prefix(3)
                .map { "\($0.title): \($0.detail)" }
            sections.append(contentsOf: reviewItems)
        }

        let warnings = scopedReviewItems
        let notFound = sections.isEmpty && matchedSources.isEmpty
        let language = alphaAnswerLanguage(for: question)
        let answerKind = alphaLocalAskFallbackAnswerKind(
            notFound: notFound,
            asksForMatterSummary: asksForMatterSummary,
            asksForDocumentSummary: asksForDocumentSummary,
            asksForImportantDates: asksForImportantDates || asksAboutSchedule,
            asksForNextActions: asksForNextActions,
            asksAboutTasks: asksAboutTasks,
            asksAboutReview: asksAboutReview
        )
        let answerTitle = alphaLocalAskFallbackTitle(for: answerKind, language: language)
        return AlphaAskResult(
            chatSessionID: nil,
            chatTurnID: nil,
            kind: .userAsk,
            question: question,
            scopeCaseID: scopeCaseID,
            scopeLabel: scopeLabel(for: scopeCaseID),
            selectedDocumentTitles: selectedDocuments.map(\.title),
            answerTitle: answerTitle,
            answerSections: notFound ? [alphaLocalAskFallbackNotFoundDetail(language: language)] : Array(sections.prefix(3)),
            caseFileSources: Array(matchedSources.prefix(3)),
            publicLawPreview: nil,
            publicLawResults: [],
            statusNote: alphaLocalAskFallbackStatus(notFound: notFound, hasSelectedDocuments: !selectedDocuments.isEmpty, language: language),
            needsReviewWarning: warnings.isEmpty ? nil : alphaLocalAskFallbackReviewWarning(warnings.count, language: language)
        )
    }

    func updateJob(_ jobID: UUID, transform: (inout AlphaModelDownloadJob) -> Void) {
        guard let index = persisted.modelJobs.firstIndex(where: { $0.id == jobID }) else { return }
        transform(&persisted.modelJobs[index])
    }
}

func alphaAskStillReadingTitle(
    isSingleDocument: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    rossLocalized(
        isSingleDocument ? "ask_still_reading_file_title" : "ask_still_reading_files_title",
        languageCode: languageCode
    )
}

func alphaAskStillReadingDetail(
    _ waitingList: String,
    isSingleDocument: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(
        format: rossLocalized(
            isSingleDocument ? "ask_still_reading_file_detail" : "ask_still_reading_files_detail",
            languageCode: languageCode
        ),
        waitingList
    )
}

func alphaAskWaitForReadableTextDetail(
    isSingleDocument: Bool,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    rossLocalized(
        isSingleDocument ? "ask_wait_file_ready_detail" : "ask_wait_files_ready_detail",
        languageCode: languageCode
    )
}

func alphaAskStillReadingDocumentSummaryDetail(
    _ title: String,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    String(format: rossLocalized("ask_still_reading_summary_detail", languageCode: languageCode), title)
}

enum AlphaLocalAskFallbackAnswerKind {
    case notFound
    case matterSummary
    case documentSummary
    case importantDates
    case nextActions
    case tasks
    case reviewItems
    case drafted
}

func alphaLocalAskFallbackAnswerKind(
    notFound: Bool,
    asksForMatterSummary: Bool,
    asksForDocumentSummary: Bool,
    asksForImportantDates: Bool,
    asksForNextActions: Bool,
    asksAboutTasks: Bool,
    asksAboutReview: Bool
) -> AlphaLocalAskFallbackAnswerKind {
    if notFound { return .notFound }
    if asksForMatterSummary { return .matterSummary }
    if asksForDocumentSummary { return .documentSummary }
    if asksForImportantDates { return .importantDates }
    if asksForNextActions { return .nextActions }
    if asksAboutTasks { return .tasks }
    if asksAboutReview { return .reviewItems }
    return .drafted
}

func alphaLocalAskFallbackTitle(
    for kind: AlphaLocalAskFallbackAnswerKind,
    language: AlphaRossModel.AlphaMatterAskFallbackLanguage
) -> String {
    let languageCode = alphaLanguageCode(for: language)
    let key: String
    switch kind {
    case .notFound:
        key = "ask_local_not_found_title"
    case .matterSummary:
        key = "ask_local_matter_summary_title"
    case .documentSummary:
        key = "ask_local_document_summary_title"
    case .importantDates:
        key = "ask_local_important_dates_title"
    case .nextActions:
        key = "ask_local_next_actions_title"
    case .tasks:
        key = "ask_local_tasks_title"
    case .reviewItems:
        key = "ask_local_review_items_title"
    case .drafted:
        key = "ask_local_drafted_title"
    }
    return rossLocalized(key, languageCode: languageCode)
}

func alphaLocalAskFallbackNotFoundDetail(language: AlphaRossModel.AlphaMatterAskFallbackLanguage) -> String {
    rossLocalized("ask_local_not_found_detail", languageCode: alphaLanguageCode(for: language))
}

func alphaLocalAskFallbackStatus(
    notFound: Bool,
    hasSelectedDocuments: Bool,
    language: AlphaRossModel.AlphaMatterAskFallbackLanguage
) -> String {
    let key: String
    if notFound {
        key = "ask_local_legal_search_off_status"
    } else if hasSelectedDocuments {
        key = "ask_local_answered_selected_files_status"
    } else {
        key = "ask_local_answered_files_status"
    }
    return rossLocalized(key, languageCode: alphaLanguageCode(for: language))
}

func alphaLocalAskFallbackReviewWarning(
    _ count: Int,
    language: AlphaRossModel.AlphaMatterAskFallbackLanguage
) -> String {
    String(
        format: rossLocalized("ask_local_review_items_still_need_review", languageCode: alphaLanguageCode(for: language)),
        alphaReviewItemCountLabel(count)
    )
}

func alphaLanguageCode(for language: AlphaRossModel.AlphaMatterAskFallbackLanguage) -> String {
    switch language {
    case .english:
        return "en"
    case .hindi:
        return "hi"
    case .bengali:
        return "bn"
    case .tamil:
        return "ta"
    case .telugu:
        return "te"
    }
}
