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

private struct AlphaPrivateAISnapshotBuildResult: Sendable {
    var recoveredState: AlphaPersistedState
    var snapshot: AlphaPrivateAISnapshot
    var stateChanged: Bool
}

private let alphaPrivateAIStartupValidationStartedAtKey = "ross.private_ai.startup_validation_started_at"
private let alphaPrivateAIStartupValidationSessionID = UUID().uuidString
private let alphaPrivateAIStartupValidationSessionField = "session_id"
private let alphaPrivateAIStartupValidationStartedAtField = "started_at"

private func alphaHadUnfinishedPrivateAIStartupValidation() -> Bool {
    guard let marker = UserDefaults.standard.object(forKey: alphaPrivateAIStartupValidationStartedAtKey) else {
        return false
    }

    if let number = marker as? NSNumber {
        return number.doubleValue > 0
    }

    if let dictionary = marker as? [String: Any] {
        if let sessionID = dictionary[alphaPrivateAIStartupValidationSessionField] as? String,
           !sessionID.isEmpty {
            return sessionID != alphaPrivateAIStartupValidationSessionID
        }
        return dictionary[alphaPrivateAIStartupValidationStartedAtField] != nil
    }

    return true
}

private func alphaMarkPrivateAIStartupValidationStarted() {
    UserDefaults.standard.set(
        [
            alphaPrivateAIStartupValidationStartedAtField: Date().timeIntervalSince1970,
            alphaPrivateAIStartupValidationSessionField: alphaPrivateAIStartupValidationSessionID
        ],
        forKey: alphaPrivateAIStartupValidationStartedAtKey
    )
}

private func alphaMarkPrivateAIStartupValidationFinished() {
    UserDefaults.standard.removeObject(forKey: alphaPrivateAIStartupValidationStartedAtKey)
}

private func alphaQuarantineActiveAssistantAfterStartupFailure(_ state: inout AlphaPersistedState) {
    let selectedTier = AlphaCapabilityTier.normalizedAssistantSelection(state.settings.activeTier)
    let affectedTier = selectedTier ?? state.installedPacks.first(where: {
        $0.isActive &&
            $0.runtimeMode == .llamaCppGguf &&
            !$0.developmentOnly
    })?.tier
    guard let affectedTier else { return }

    state.installedPacks = state.installedPacks.map { pack in
        var copy = pack
        if copy.tier == affectedTier {
            copy.isActive = false
        }
        return copy
    }
    state.settings.activeTier = nil
    state.modelJobs = state.modelJobs.map { job in
        var copy = job
        if copy.tier == affectedTier, copy.state == .installed {
            copy.failureReason = "Ross paused this assistant after the previous launch did not finish setup validation. Open My assistant to re-check setup or use Repair setup."
            copy.updatedAt = .now
        }
        return copy
    }
    if !state.ledgerEntries.contains(where: {
        $0.title == "Assistant paused" && $0.endpointLabel == "device://model-startup-recovery"
    }) {
        state.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant paused",
                detail: "Ross kept the assistant setup file on this device, but stopped auto-selecting it after startup validation did not finish on the previous launch. Open My assistant to re-check setup or use Repair setup.",
                purpose: .model_verification,
                payloadClass: .no_case_data,
                endpointLabel: "device://model-startup-recovery",
                success: false
            ),
            at: 0
        )
    }
}

private func alphaSelectedDownloadedAssistantPack(in state: AlphaPersistedState) -> AlphaInstalledModelPack? {
    let selectedTier = AlphaCapabilityTier.normalizedAssistantSelection(
        state.installedPacks.first(where: \.isActive)?.tier ?? state.settings.activeTier
    )
    let matchingPacks = state.installedPacks.filter { pack in
        pack.runtimeMode == .llamaCppGguf &&
            !pack.developmentOnly &&
            (selectedTier == nil || pack.tier == selectedTier)
    }

    return matchingPacks.sorted { lhs, rhs in
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        if lhs.checksumVerified != rhs.checksumVerified {
            return lhs.checksumVerified && !rhs.checksumVerified
        }
        return lhs.installedAt > rhs.installedAt
    }.first
}

private func alphaShouldPauseDownloadedAssistantAfterLaunch(_ state: AlphaPersistedState) -> Bool {
    if alphaHadUnfinishedPrivateAIStartupValidation(),
       alphaSelectedDownloadedAssistantPack(in: state) != nil {
        return true
    }

    guard let activePack = alphaSelectedDownloadedAssistantPack(in: state) else {
        return false
    }
    if !alphaInstalledModelPackFileIsUsable(activePack) {
        return true
    }
    guard let installedJob = state.modelJobs.first(where: {
        $0.tier == activePack.tier && $0.state == .installed
    }) else {
        return false
    }

    let expectedBytes = alphaAssistantModelArtifact(for: activePack.tier).sizeBytes
    return installedJob.totalBytes <= 1 ||
        installedJob.bytesDownloaded <= 1 ||
        (expectedBytes > 0 && installedJob.totalBytes != expectedBytes)
}

private func alphaQuarantineUnusableActiveDownloadedAssistant(_ state: inout AlphaPersistedState) {
    guard let activePack = alphaSelectedDownloadedAssistantPack(in: state),
          !alphaInstalledModelPackFileIsUsable(activePack) else {
        return
    }
    alphaQuarantineActiveAssistantAfterStartupFailure(&state)
}

private func alphaQuarantineIncompleteInstalledAssistantJob(_ state: inout AlphaPersistedState) {
    guard let activePack = alphaSelectedDownloadedAssistantPack(in: state),
          let installedJob = state.modelJobs.first(where: { $0.tier == activePack.tier && $0.state == .installed }) else {
        return
    }
    let expectedBytes = alphaAssistantModelArtifact(for: activePack.tier).sizeBytes
    guard installedJob.totalBytes <= 1 ||
            installedJob.bytesDownloaded <= 1 ||
            (expectedBytes > 0 && installedJob.totalBytes != expectedBytes) else {
        return
    }
    alphaQuarantineActiveAssistantAfterStartupFailure(&state)
}

@discardableResult
private func alphaPurgeAbandonedAssistantDownloadsFromDisk() -> Int64 {
    let fileManager = FileManager.default
    var reclaimedBytes: Int64 = 0

    func removeIfExists(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path()) else { return }
        reclaimedBytes += alphaModelFileByteCount(at: url)
        try? fileManager.removeItem(at: url)
    }

    let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    if let contents = try? fileManager.contentsOfDirectory(
        at: temporaryURL,
        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) {
        for url in contents {
            let name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            guard name.hasPrefix("CFNetworkDownload_") ||
                name.hasPrefix("ross-") ||
                ext == "tmp" ||
                ext == "part" ||
                ext == "download" else {
                continue
            }
            removeIfExists(url)
        }
    }

    // Older builds staged models in Documents/Models; current builds use app-support/model-packs.
    if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        removeIfExists(documentsURL.appendingPathComponent("Models", isDirectory: true))
    }

    let testsScratchURL = temporaryURL.appendingPathComponent("RossAlphaTests", isDirectory: true)
    let environment = ProcessInfo.processInfo.environment
    let isRunningTests = environment["XCTestConfigurationFilePath"] != nil ||
        environment["ROSS_RUNNING_TESTS"] == "1" ||
        Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
    if !isRunningTests {
        removeIfExists(testsScratchURL)
    }

    return reclaimedBytes
}

@discardableResult
private func alphaPruneUnreferencedAssistantArtifactsFromDisk(
    installedPacks: [AlphaInstalledModelPack],
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> Int64 {
    let fileManager = FileManager.default
    var reclaimedBytes: Int64 = 0
    let installedPaths = Set(installedPacks.map(\.installPath))
    let retainedFallbackManifests = alphaRetainedFallbackAssistantManifestURLs(
        installedPacks: installedPacks,
        lastInvocation: lastInvocation,
        fileManager: fileManager
    )

    func removeIfUnreferenced(_ url: URL) {
        let relativePath = url.path()
            .replacingOccurrences(of: alphaSupportRootURL().path() + "/", with: "")
        guard !installedPaths.contains(relativePath) else { return }
        reclaimedBytes += alphaModelFileByteCount(at: url)
        try? fileManager.removeItem(at: url)
    }

    for tier in AlphaCapabilityTier.allCases {
        let tierDirectory = alphaAbsoluteURL(for: "model-packs/\(tier.rawValue)")
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tierDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }
        for url in contents {
            let name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            guard name == "pack.dev" ||
                name.hasPrefix("CFNetworkDownload_") ||
                name.hasPrefix("ross-") ||
                ext == "tmp" ||
                ext == "part" ||
                ext == "download" else {
                continue
            }
            removeIfUnreferenced(url)
        }
        for manifestURL in contents where manifestURL.lastPathComponent.hasSuffix(".manifest.json") {
            guard let data = try? Data(contentsOf: manifestURL) else { continue }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let manifest = try? decoder.decode(AlphaModelArtifactManifest.self, from: data),
                  manifest.tier == tier,
                  !installedPaths.contains(manifest.relativePath) else {
                continue
            }
            if retainedFallbackManifests.contains(manifestURL.standardizedFileURL) {
                continue
            }
            let artifactURL = alphaAbsoluteURL(for: manifest.relativePath)
            reclaimedBytes += alphaModelFileByteCount(at: artifactURL)
            if let draftArtifact = manifest.draftArtifact {
                let draftURL = alphaAbsoluteURL(for: draftArtifact.relativePath)
                reclaimedBytes += alphaModelFileByteCount(at: draftURL)
                try? fileManager.removeItem(at: draftURL)
            }
            try? fileManager.removeItem(at: artifactURL)
            try? fileManager.removeItem(at: manifestURL)
        }
        if let remaining = try? fileManager.contentsOfDirectory(atPath: tierDirectory.path()),
           remaining.isEmpty {
            try? fileManager.removeItem(at: tierDirectory)
        }
    }

    return reclaimedBytes
}

private func alphaRetainedFallbackAssistantManifestURLs(
    installedPacks: [AlphaInstalledModelPack],
    lastInvocation: AlphaLocalModelInvocation?,
    fileManager: FileManager = .default
) -> Set<URL> {
    let retainedSystemTiers = Set(installedPacks.compactMap { pack -> AlphaCapabilityTier? in
        guard pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model" else {
            return nil
        }
        return AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier
    })
    guard !retainedSystemTiers.isEmpty else { return [] }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var retainedURLs = Set<URL>()

    for tier in retainedSystemTiers {
        let preferredFallbackRuntime = alphaPreferredAssistantRuntimeMode(
            for: tier,
            existingRuntimeMode: nil,
            systemAssistantAvailable: false,
            lastInvocation: lastInvocation
        )
        let tierDirectory = alphaAbsoluteURL(for: "model-packs/\(tier.rawValue)")
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tierDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }

        var retainedManifest: (url: URL, manifest: AlphaModelArtifactManifest)?
        for manifestURL in contents where manifestURL.lastPathComponent.hasSuffix(".manifest.json") {
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(AlphaModelArtifactManifest.self, from: data),
                  manifest.tier == tier,
                  !manifest.developmentOnly,
                  manifest.runtimeMode != .appleFoundationModels,
                  manifest.artifactKind != "system_model" else {
                continue
            }

            let candidate = AlphaInstalledModelPack(
                packId: manifest.packId,
                tier: manifest.tier,
                installPath: manifest.relativePath,
                checksumSha256: manifest.checksumSha256,
                artifactKind: manifest.artifactKind,
                runtimeMode: manifest.runtimeMode,
                developmentOnly: manifest.developmentOnly,
                checksumVerified: true,
                isActive: false
            )
            guard alphaInstalledModelPackFileIsUsable(candidate),
                  alphaDownloadedAssistantArtifactPassesRuntimeValidation(candidate) else {
                continue
            }

            guard let current = retainedManifest else {
                retainedManifest = (manifestURL.standardizedFileURL, manifest)
                continue
            }

            let currentMatchesPreferred = current.manifest.runtimeMode == preferredFallbackRuntime
            let candidateMatchesPreferred = manifest.runtimeMode == preferredFallbackRuntime
            if candidateMatchesPreferred != currentMatchesPreferred {
                retainedManifest = candidateMatchesPreferred ? (manifestURL.standardizedFileURL, manifest) : current
                continue
            }

            if manifest.verifiedAt != current.manifest.verifiedAt {
                retainedManifest = manifest.verifiedAt > current.manifest.verifiedAt
                    ? (manifestURL.standardizedFileURL, manifest)
                    : current
                continue
            }

            if manifest.bytes != current.manifest.bytes {
                retainedManifest = manifest.bytes > current.manifest.bytes
                    ? (manifestURL.standardizedFileURL, manifest)
                    : current
                continue
            }

            if manifestURL.lastPathComponent < current.url.lastPathComponent {
                retainedManifest = (manifestURL.standardizedFileURL, manifest)
            }
        }

        if let retainedManifest {
            retainedURLs.insert(retainedManifest.url)
        }
    }

    return retainedURLs
}

private func alphaModelFileByteCount(at url: URL) -> Int64 {
    alphaModelArtifactByteCount(at: url)
}

func alphaModelAssistantChecksumMatches(expected: String, actual: String) -> Bool {
    let normalizedExpected = expected.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedActual = actual.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedActual.isEmpty else { return false }
    guard !normalizedExpected.isEmpty else {
        return true
    }
    return normalizedActual.caseInsensitiveCompare(normalizedExpected) == .orderedSame
}

private func alphaModelSizeVerificationToken(fileName: String, bytes: Int64) -> String {
    "catalog-size:\(fileName):\(bytes)"
}

private func alphaModelLooksLikeSHA256(_ value: String?) -> Bool {
    guard let value else { return false }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count == 64 else { return false }
    return trimmed.allSatisfy { character in
        character.isNumber || ("a"..."f").contains(character.lowercased())
    }
}

func alphaModelArtifactManifest(forFileAt fileURL: URL) -> AlphaModelArtifactManifest? {
    let manifestURL = alphaModelArtifactManifestURL(forArtifactAt: fileURL)
    guard let data = try? Data(contentsOf: manifestURL) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(AlphaModelArtifactManifest.self, from: data)
}

struct AlphaExpectedDownloadedAssistantArtifact {
    let packId: String
    let tier: AlphaCapabilityTier
    let relativePath: String
    let checksumSha256: String
    let bytes: Int64
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let draftArtifact: AlphaInstalledAssistantDraftArtifact?
}

func alphaExpectedDownloadedAssistantArtifact(for pack: AlphaInstalledModelPack) -> AlphaExpectedDownloadedAssistantArtifact? {
    let fileURL = alphaAbsoluteURL(for: pack.installPath)
    if let manifest = alphaModelArtifactManifest(forFileAt: fileURL),
       manifest.tier == pack.tier,
       manifest.relativePath == pack.installPath {
        return AlphaExpectedDownloadedAssistantArtifact(
            packId: manifest.packId,
            tier: manifest.tier,
            relativePath: manifest.relativePath,
            checksumSha256: manifest.checksumSha256,
            bytes: manifest.bytes,
            artifactKind: manifest.artifactKind,
            runtimeMode: manifest.runtimeMode,
            developmentOnly: manifest.developmentOnly,
            draftArtifact: manifest.draftArtifact
        )
    }

    if pack.runtimeMode == .mlxSwiftLm || pack.artifactKind == "mlx_directory" {
        return nil
    }

    let artifact = alphaAssistantModelArtifact(for: pack.tier)
    let defaultRelativePath = "model-packs/\(pack.tier.rawValue)/\(artifact.fileName)"
    guard pack.packId == artifact.packId || pack.installPath == defaultRelativePath else {
        return nil
    }
    return AlphaExpectedDownloadedAssistantArtifact(
        packId: artifact.packId,
        tier: artifact.tier,
        relativePath: pack.installPath,
        checksumSha256: artifact.sha256,
        bytes: artifact.sizeBytes,
        artifactKind: artifact.artifactKind,
        runtimeMode: artifact.runtimeMode,
        developmentOnly: artifact.developmentOnly,
        draftArtifact: nil
    )
}

private func alphaInstalledDraftArtifactIsUsable(_ artifact: AlphaInstalledAssistantDraftArtifact) -> Bool {
    let fileURL = alphaAbsoluteURL(for: artifact.relativePath)
    guard alphaModelFileByteCount(at: fileURL) == artifact.bytes else { return false }
    guard alphaModelLooksLikeSHA256(artifact.checksumSha256),
          let verifiedArtifact = alphaModelArtifactVerification(at: fileURL),
          verifiedArtifact.bytes == artifact.bytes else {
        return false
    }
    return alphaModelAssistantChecksumMatches(
        expected: artifact.checksumSha256,
        actual: verifiedArtifact.checksum
    )
}

func alphaDownloadedAssistantArtifactPassesRuntimeValidation(_ pack: AlphaInstalledModelPack) -> Bool {
    switch pack.runtimeMode {
    case .llamaCppGguf:
        do {
            try AlphaLlamaCppProvider.validateModelCanLoad(at: alphaAbsoluteURL(for: pack.installPath).path)
            return true
        } catch {
            return false
        }
    case .mlxSwiftLm:
        return AlphaLocalModelRuntime.runtimeHealth(
            activePack: pack,
            requestedTier: pack.tier
        )?.available == true
    case .deterministicDev:
        return alphaAllowsDevelopmentModelArtifacts()
    case .appleFoundationModels:
        return AlphaLocalModelRuntime.runtimeHealth(
            activePack: pack,
            requestedTier: pack.tier
        )?.available == true
    case .mediapipeLlm, .unavailable:
        return false
    }
}

func alphaInstalledAssistantPackPassesRuntimeValidation(_ pack: AlphaInstalledModelPack) -> Bool {
    guard !pack.developmentOnly else {
        return true
    }
    if pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model" {
        return AlphaLocalModelRuntime.runtimeHealth(
            activePack: pack,
            requestedTier: pack.tier
        )?.available == true
    }
    guard alphaInstalledModelPackFileIsUsable(pack) else {
        return false
    }
    return alphaDownloadedAssistantArtifactPassesRuntimeValidation(pack)
}

private func alphaInstalledModelPackFileIsUsable(_ pack: AlphaInstalledModelPack) -> Bool {
    if pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model" {
        guard !pack.developmentOnly || alphaAllowsDevelopmentModelArtifacts() else {
            return false
        }
        return pack.installPath.hasPrefix("system://")
    }
    guard !pack.developmentOnly || alphaAllowsDevelopmentModelArtifacts() else {
        return false
    }

    let fileURL = alphaAbsoluteURL(for: pack.installPath)
    guard !pack.developmentOnly else { return alphaModelFileByteCount(at: fileURL) > 0 }
    guard let expected = alphaExpectedDownloadedAssistantArtifact(for: pack),
          expected.tier == pack.tier,
          expected.relativePath == pack.installPath,
          expected.packId == pack.packId,
          expected.artifactKind == pack.artifactKind,
          expected.runtimeMode == pack.runtimeMode,
          expected.developmentOnly == pack.developmentOnly else {
        return false
    }
    guard alphaModelFileByteCount(at: fileURL) == expected.bytes else { return false }
    if let draftArtifact = expected.draftArtifact,
       !alphaInstalledDraftArtifactIsUsable(draftArtifact) {
        return false
    }
    guard !expected.checksumSha256.isEmpty else {
        return alphaModelLooksLikeSHA256(pack.checksumSha256)
    }
    return alphaModelAssistantChecksumMatches(expected: expected.checksumSha256, actual: pack.checksumSha256)
}

private func alphaRecoveredInstalledPackFromDisk(tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
    guard tier != .flash else { return nil }
    typealias RecoveredCandidate = (pack: AlphaInstalledModelPack, verifiedAt: Date)

    func preferredRecoveredCandidate(from candidates: [RecoveredCandidate]) -> AlphaInstalledModelPack? {
        guard !candidates.isEmpty else { return nil }
        let preferredPack = alphaPreferredInstalledPack(
            for: tier,
            installedPacks: candidates.map(\.pack),
            lastInvocation: nil
        )
        return candidates.min { lhs, rhs in
            let lhsMatchesPreferred = lhs.pack.id == preferredPack?.id
            let rhsMatchesPreferred = rhs.pack.id == preferredPack?.id
            if lhsMatchesPreferred != rhsMatchesPreferred {
                return lhsMatchesPreferred && !rhsMatchesPreferred
            }
            if lhs.pack.checksumVerified != rhs.pack.checksumVerified {
                return lhs.pack.checksumVerified && !rhs.pack.checksumVerified
            }
            if lhs.verifiedAt != rhs.verifiedAt {
                return lhs.verifiedAt > rhs.verifiedAt
            }
            return lhs.pack.installPath < rhs.pack.installPath
        }?.pack
    }

    var recoveredCandidates: [RecoveredCandidate] = []
    let tierFolder = alphaAbsoluteURL(for: "model-packs/\(tier.rawValue)")
    if let contents = try? FileManager.default.contentsOfDirectory(
        at: tierFolder,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifests = contents
            .filter { $0.lastPathComponent.hasSuffix(".manifest.json") }
            .compactMap { manifestURL -> (url: URL, manifest: AlphaModelArtifactManifest)? in
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? decoder.decode(AlphaModelArtifactManifest.self, from: data),
                      manifest.tier == tier else {
                    return nil
                }
                return (manifestURL, manifest)
            }
            .sorted { lhs, rhs in
                if lhs.manifest.verifiedAt != rhs.manifest.verifiedAt {
                    return lhs.manifest.verifiedAt > rhs.manifest.verifiedAt
                }
                return lhs.url.lastPathComponent < rhs.url.lastPathComponent
            }

        for candidate in manifests {
            let manifestURL = candidate.url
            let manifest = candidate.manifest
            let fileURL = alphaAbsoluteURL(for: manifest.relativePath)
            guard alphaModelArtifactManifestURL(forArtifactAt: fileURL).standardizedFileURL == manifestURL.standardizedFileURL else {
                continue
            }
            guard alphaModelLooksLikeSHA256(manifest.checksumSha256),
                  let verifiedArtifact = alphaModelArtifactVerification(at: fileURL),
                  verifiedArtifact.bytes == manifest.bytes,
                  (manifest.draftArtifact.map(alphaInstalledDraftArtifactIsUsable) ?? true),
                  alphaModelAssistantChecksumMatches(
                    expected: manifest.checksumSha256,
                    actual: verifiedArtifact.checksum
                  ) else {
                continue
            }
            let recovered = AlphaInstalledModelPack(
                packId: manifest.packId,
                tier: manifest.tier,
                installPath: manifest.relativePath,
                checksumSha256: verifiedArtifact.checksum,
                artifactKind: manifest.artifactKind,
                runtimeMode: manifest.runtimeMode,
                developmentOnly: manifest.developmentOnly,
                checksumVerified: true,
                installedAt: manifest.verifiedAt,
                isActive: true
            )
            guard alphaDownloadedAssistantArtifactPassesRuntimeValidation(recovered) else {
                continue
            }
            recoveredCandidates.append((recovered, manifest.verifiedAt))
        }
    }

    let artifact = alphaAssistantModelArtifact(for: tier)
    if artifact.runtimeMode == .llamaCppGguf {
        let relativePath = "model-packs/\(tier.rawValue)/\(artifact.fileName)"
        let fileURL = alphaAbsoluteURL(for: relativePath)
        if alphaModelFileByteCount(at: fileURL) == artifact.sizeBytes {
            let manifest = alphaModelArtifactManifest(forFileAt: fileURL)
            let recoveredChecksum = manifest?.checksumSha256.trimmingCharacters(in: .whitespacesAndNewlines)
            let manifestMatchesPinnedArtifact = manifest == nil ||
                (manifest?.fileName == artifact.fileName && manifest?.bytes == artifact.sizeBytes)

            if manifestMatchesPinnedArtifact {
                let checksum: String?
                if artifact.sha256.isEmpty {
                    if alphaModelLooksLikeSHA256(recoveredChecksum) {
                        checksum = recoveredChecksum
                    } else if let verifiedChecksum = alphaModelSHA256Hex(forFileAt: fileURL),
                              alphaModelLooksLikeSHA256(verifiedChecksum) {
                        checksum = verifiedChecksum
                    } else {
                        checksum = nil
                    }
                } else if let recoveredChecksum, !recoveredChecksum.isEmpty,
                          alphaModelAssistantChecksumMatches(expected: artifact.sha256, actual: recoveredChecksum) {
                    checksum = recoveredChecksum
                } else if let verifiedChecksum = alphaModelSHA256Hex(forFileAt: fileURL),
                          alphaModelAssistantChecksumMatches(expected: artifact.sha256, actual: verifiedChecksum) {
                    checksum = verifiedChecksum
                } else {
                    checksum = nil
                }

                if let checksum {
                    let recovered = AlphaInstalledModelPack(
                        packId: artifact.packId,
                        tier: tier,
                        installPath: relativePath,
                        checksumSha256: checksum,
                        artifactKind: artifact.artifactKind,
                        runtimeMode: artifact.runtimeMode,
                        developmentOnly: artifact.developmentOnly,
                        checksumVerified: true,
                        installedAt: manifest?.verifiedAt ?? .distantPast,
                        isActive: true
                    )
                    if alphaDownloadedAssistantArtifactPassesRuntimeValidation(recovered) {
                        recoveredCandidates.append((recovered, manifest?.verifiedAt ?? .distantPast))
                    }
                }
            }
        }
    }

    return preferredRecoveredCandidate(from: recoveredCandidates)
}

private func alphaRecoverDownloadedAssistantArtifacts(from state: inout AlphaPersistedState) -> Bool {
    let invalidPackIDs = Set(state.installedPacks.filter { !alphaInstalledModelPackFileIsUsable($0) }.map(\.id))
    if !invalidPackIDs.isEmpty {
        state.installedPacks.removeAll { invalidPackIDs.contains($0.id) }
    }

    var recoveredPacks: [AlphaInstalledModelPack] = []
    let existingPackPaths = Set(state.installedPacks.map(\.installPath))
    let retainedDownloadedTiers = Set(
        state.installedPacks.compactMap { pack -> AlphaCapabilityTier? in
            guard pack.runtimeMode != .appleFoundationModels,
                  pack.artifactKind != "system_model" else {
                return nil
            }
            return AlphaCapabilityTier.normalizedAssistantSelection(pack.tier) ?? pack.tier
        }
    )
    let focusedRecoveryTiers: [AlphaCapabilityTier]
    if let selectedTier = AlphaCapabilityTier.normalizedAssistantSelection(
        state.installedPacks.first(where: \.isActive)?.tier ?? state.settings.activeTier
    ) {
        focusedRecoveryTiers = [selectedTier]
    } else {
        focusedRecoveryTiers = AlphaCapabilityTier.installableAssistantTiers
    }

    for tier in focusedRecoveryTiers {
        guard !retainedDownloadedTiers.contains(tier) else { continue }
        guard let recovered = alphaRecoveredInstalledPackFromDisk(tier: tier),
              !existingPackPaths.contains(recovered.installPath) else { continue }
        recoveredPacks.append(recovered)
    }

    guard !recoveredPacks.isEmpty else { return !invalidPackIDs.isEmpty }

    let hadActivePack = state.installedPacks.contains(where: \.isActive)
    state.installedPacks.append(contentsOf: recoveredPacks)

    if !hadActivePack {
        let storedPreferredTier = state.settings.activeTier
        let preferredTier: AlphaCapabilityTier?
        if let storedPreferredTier,
           recoveredPacks.contains(where: { $0.tier == storedPreferredTier }) {
            preferredTier = storedPreferredTier
        } else {
            preferredTier = recoveredPacks.first?.tier
        }
        state.installedPacks = state.installedPacks.map { pack in
            var copy = pack
            copy.isActive = pack.tier == preferredTier
            return copy
        }
        state.settings.activeTier = preferredTier
    }
    let recoveredTiers = Set(recoveredPacks.map(\.tier))
    state.modelJobs.removeAll { job in
        recoveredTiers.contains(job.tier) && job.state != .installed
    }

    let recoveredTitles = recoveredPacks.map(\.tier.setupTitle).joined(separator: ", ")
    state.ledgerEntries.insert(
        AlphaPrivacyLedgerEntry(
            title: "Assistant restored",
            detail: "Ross found and verified existing assistant setup on this device: \(recoveredTitles).",
            purpose: .model_verification,
            payloadClass: .no_case_data,
            endpointLabel: "device://model-verify",
            success: true
        ),
        at: 0
    )
    return true
}

func alphaOptimisticActivePack(from state: AlphaPersistedState) -> AlphaInstalledModelPack? {
    if let active = state.installedPacks.first(where: \.isActive) {
        return active
    }
    if let preferredTier = state.settings.activeTier,
       let preferred = alphaPreferredInstalledPack(
        for: preferredTier,
        installedPacks: state.installedPacks,
        lastInvocation: alphaLastModelInvocation(in: state)
       ) ?? state.installedPacks.first(where: { $0.tier == preferredTier }) {
        return preferred
    }
    return nil
}

func alphaRecoveredAssistantExecutionFallback(
    from state: AlphaPersistedState,
    selectedTier: AlphaCapabilityTier?,
    currentPack: AlphaInstalledModelPack?
) -> AlphaInstalledModelPack? {
    let resolvedTier = AlphaCapabilityTier.normalizedAssistantSelection(currentPack?.tier ?? selectedTier) ?? selectedTier
    guard let requestedTier = resolvedTier else {
        return nil
    }

    let currentPackAvailable = currentPack.flatMap {
        AlphaLocalModelRuntime.runtimeHealth(
            activePack: $0,
            requestedTier: requestedTier
        )?.available
    } == true

    if let currentPack, alphaInstalledAssistantPackPassesRuntimeValidation(currentPack), currentPackAvailable {
        return nil
    }

    if let preferredFallback = alphaPreferredInstalledPack(
        for: requestedTier,
        installedPacks: state.installedPacks,
        lastInvocation: alphaLastModelInvocation(in: state)
    ), preferredFallback.id != currentPack?.id {
        return preferredFallback
    }

    guard let recoveredFallback = alphaRecoveredInstalledPackFromDisk(tier: requestedTier),
          recoveredFallback.id != currentPack?.id,
          recoveredFallback.runtimeMode != .appleFoundationModels,
          recoveredFallback.artifactKind != "system_model",
          alphaInstalledAssistantPackPassesRuntimeValidation(recoveredFallback) else {
        return nil
    }
    return recoveredFallback
}

private func alphaValidatedActivePack(from state: AlphaPersistedState) -> AlphaInstalledModelPack? {
    if let active = state.installedPacks.first(where: \.isActive),
       alphaInstalledAssistantPackPassesRuntimeValidation(active) {
        return active
    }
    if let preferredTier = state.settings.activeTier,
       let preferred = alphaPreferredInstalledPack(
        for: preferredTier,
        installedPacks: state.installedPacks,
        lastInvocation: alphaLastModelInvocation(in: state)
       ) ?? state.installedPacks.first(where: {
           $0.tier == preferredTier && alphaInstalledAssistantPackPassesRuntimeValidation($0)
       }) {
        return preferred
    }
    return nil
}

private func alphaNormalizedInstalledPacks(
    from state: AlphaPersistedState,
    activePack: AlphaInstalledModelPack?
) -> [AlphaInstalledModelPack] {
    state.installedPacks.map { pack in
        var copy = pack
        copy.isActive = pack.id == activePack?.id
        return copy
    }
}

private func alphaConvergeInstalledAssistantCatalog(_ state: inout AlphaPersistedState) {
    var retainedPacksByIdentity: [String: AlphaInstalledModelPack] = [:]
    for pack in state.installedPacks {
        let identity = [
            pack.tier.rawValue,
            pack.packId,
            pack.runtimeMode.rawValue,
            pack.installPath,
            pack.artifactKind
        ].joined(separator: "|")
        if let existing = retainedPacksByIdentity[identity] {
            let shouldReplace: Bool
            if existing.isActive != pack.isActive {
                shouldReplace = pack.isActive
            } else if existing.checksumVerified != pack.checksumVerified {
                shouldReplace = pack.checksumVerified
            } else {
                shouldReplace = pack.installedAt >= existing.installedAt
            }
            if shouldReplace {
                retainedPacksByIdentity[identity] = pack
            }
        } else {
            retainedPacksByIdentity[identity] = pack
        }
    }
    state.installedPacks = retainedPacksByIdentity.values.sorted { lhs, rhs in
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        if lhs.tier != rhs.tier {
            return lhs.tier.rawValue < rhs.tier.rawValue
        }
        if lhs.installedAt != rhs.installedAt {
            return lhs.installedAt > rhs.installedAt
        }
        return lhs.packId < rhs.packId
    }

    let retainedPackKeys = Set(state.installedPacks.map {
        [$0.tier.rawValue, $0.packId, $0.runtimeMode.rawValue, $0.artifactKind].joined(separator: "|")
    })
    var keptInstalledJobIDs = Set<UUID>()
    let installedJobsByKey = Dictionary(
        grouping: state.modelJobs.enumerated().filter { entry in
            entry.element.state == .installed
        }
    ) { entry in
        let job = entry.element
        return [job.tier.rawValue, job.packId, job.runtimeMode.rawValue, job.artifactKind].joined(separator: "|")
    }

    for key in retainedPackKeys {
        guard let jobs = installedJobsByKey[key] else { continue }
        if let kept = jobs.max(by: { lhs, rhs in
            let lhsDate = lhs.element.completedAt ?? lhs.element.updatedAt
            let rhsDate = rhs.element.completedAt ?? rhs.element.updatedAt
            return lhsDate < rhsDate
        }) {
            keptInstalledJobIDs.insert(kept.element.id)
        }
    }

    state.modelJobs.removeAll { job in
        guard job.state == .installed else { return false }
        let key = [job.tier.rawValue, job.packId, job.runtimeMode.rawValue, job.artifactKind].joined(separator: "|")
        return !retainedPackKeys.contains(key) || !keptInstalledJobIDs.contains(job.id)
    }
}

private func alphaConvergeAssistantUpdateCandidates(_ state: inout AlphaPersistedState) {
    guard let candidates = state.modelUpdateCandidates, !candidates.isEmpty else {
        state.modelUpdateCandidates = []
        return
    }

    let lastInvocation = alphaLastModelInvocation(in: state)
    var converged: [AlphaModelUpdateCandidate] = []

    for tier in AlphaCapabilityTier.installableAssistantTiers {
        guard let retainedPackID = alphaPreferredInstalledPack(
            for: tier,
            installedPacks: state.installedPacks,
            lastInvocation: lastInvocation
        )?.packId else {
            continue
        }
        let tierCandidates = candidates
            .filter { candidate in
                candidate.tier == tier &&
                    retainedPackID == candidate.installedPackId
            }
            .sorted { lhs, rhs in
                let lhsDismissed = lhs.dismissedAt != nil
                let rhsDismissed = rhs.dismissedAt != nil
                if lhsDismissed != rhsDismissed {
                    return !lhsDismissed && rhsDismissed
                }
                if lhs.checkedAt != rhs.checkedAt {
                    return lhs.checkedAt > rhs.checkedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        if let candidate = tierCandidates.first {
            converged.append(candidate)
        }
    }

    state.modelUpdateCandidates = converged
}

private enum AlphaRecentRuntimeSelectionSignal {
    case keepFast(AlphaPackRuntimeMode)
    case avoidSlow(AlphaPackRuntimeMode)
}

private func alphaRecentRuntimeSelectionSignal(
    for tier: AlphaCapabilityTier,
    lastInvocation: AlphaLocalModelInvocation?
) -> AlphaRecentRuntimeSelectionSignal? {
    guard let lastInvocation,
          lastInvocation.task == .matterQuestionAnswer,
          lastInvocation.capabilityTier == tier.rawValue,
          alphaInvocationHasAdaptivePerformanceMetrics(lastInvocation),
          let runtimeMode = AlphaPackRuntimeMode(rawValue: lastInvocation.runtimeMode),
          runtimeMode == .appleFoundationModels || runtimeMode == .mlxSwiftLm || runtimeMode == .llamaCppGguf,
          let outputSpeed = lastInvocation.estimatedOutputTokensPerSecond,
          let firstTokenMs = lastInvocation.timeToFirstTokenMs else {
        return nil
    }

    if outputSpeed >= 14, firstTokenMs <= 1_500 {
        return .keepFast(runtimeMode)
    }

    if outputSpeed <= 8 || firstTokenMs >= 3_000 {
        return .avoidSlow(runtimeMode)
    }

    return nil
}

private func alphaPreferredInstalledPack(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack],
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> AlphaInstalledModelPack? {
    func systemRuntimeAvailable(_ pack: AlphaInstalledModelPack) -> Bool {
        AlphaLocalModelRuntime.runtimeHealth(
            activePack: pack,
            requestedTier: tier
        )?.available == true
    }

    var candidates = installedPacks.filter { pack in
        guard pack.tier == tier,
              alphaInstalledAssistantPackPassesRuntimeValidation(pack) else {
            return false
        }
        if pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model" {
            return systemRuntimeAvailable(pack)
        }
        return true
    }

    let systemPack = alphaSystemAssistantPack(for: tier)
    let systemAvailable = !alphaAllowsDevelopmentModelArtifacts() &&
        alphaInstalledAssistantPackPassesRuntimeValidation(systemPack) &&
        systemRuntimeAvailable(systemPack)
    if systemAvailable,
       !candidates.contains(where: {
           $0.packId == systemPack.packId &&
               $0.runtimeMode == systemPack.runtimeMode &&
               $0.artifactKind == systemPack.artifactKind &&
               $0.installPath == systemPack.installPath
       }) {
        candidates.append(systemPack)
    }

    guard !candidates.isEmpty else { return nil }

    let existingRuntimeMode = candidates.first(where: \.isActive)?.runtimeMode
    let preferredRuntime: AlphaPackRuntimeMode
    if existingRuntimeMode == .appleFoundationModels {
        preferredRuntime = alphaPreferredAssistantRuntimeMode(
            for: tier,
            existingRuntimeMode: .appleFoundationModels,
            systemAssistantAvailable: systemAvailable,
            lastInvocation: lastInvocation
        )
    } else {
        let prefersAcceleratedMLX = systemAvailable && alphaShouldPreferAcceleratedMLXInstalledPack(
            for: tier,
            installedPacks: installedPacks,
            existingRuntimeMode: existingRuntimeMode,
            lastInvocation: lastInvocation
        )
        preferredRuntime = if prefersAcceleratedMLX {
            .mlxSwiftLm
        } else if systemAvailable {
            .appleFoundationModels
        } else {
            alphaPreferredAssistantSetupRuntimeMode(
                for: tier,
                existingRuntimeMode: existingRuntimeMode,
                systemAssistantAvailable: false,
                lastInvocation: lastInvocation
            )
        }
    }
    let recentSignal = alphaRecentRuntimeSelectionSignal(for: tier, lastInvocation: lastInvocation)
    let candidateRuntimeModes = Set(candidates.map(\.runtimeMode))
    let hasComparableRuntimeChoice =
        (candidateRuntimeModes.contains(.mlxSwiftLm) && candidateRuntimeModes.contains(.llamaCppGguf)) ||
        (candidateRuntimeModes.contains(.appleFoundationModels) &&
         (candidateRuntimeModes.contains(.mlxSwiftLm) || candidateRuntimeModes.contains(.llamaCppGguf)))
    let canUseRecentRuntimeSignal = hasComparableRuntimeChoice

    func runtimeScore(_ runtimeMode: AlphaPackRuntimeMode) -> Int {
        let baseScore: Int
        if runtimeMode == preferredRuntime {
            baseScore = 0
        } else {
            switch runtimeMode {
            case .appleFoundationModels:
                baseScore = 1
            case .mlxSwiftLm:
                baseScore = 2
            case .llamaCppGguf:
                baseScore = 3
            case .deterministicDev:
                baseScore = 4
            case .mediapipeLlm, .unavailable:
                baseScore = 5
            }
        }

        guard canUseRecentRuntimeSignal, let recentSignal else {
            return baseScore
        }

        switch recentSignal {
        case .keepFast(let runtime) where runtimeMode == runtime:
            return baseScore - 4
        case .avoidSlow(let runtime) where runtimeMode == runtime:
            return baseScore + 4
        default:
            return baseScore
        }
    }

    return candidates.min { lhs, rhs in
        let lhsScore = runtimeScore(lhs.runtimeMode)
        let rhsScore = runtimeScore(rhs.runtimeMode)
        if lhsScore != rhsScore {
            return lhsScore < rhsScore
        }
        if lhs.checksumVerified != rhs.checksumVerified {
            return lhs.checksumVerified && !rhs.checksumVerified
        }
        return lhs.installedAt > rhs.installedAt
    }
}

private func alphaShouldPreferAcceleratedMLXInstalledPack(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack],
    existingRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    lowPowerMode: Bool = alphaCurrentLowPowerMode(),
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> Bool {
    let hasInstalledGGUFCandidate = installedPacks.contains { pack in
        guard pack.tier == tier,
              pack.runtimeMode == .llamaCppGguf,
              alphaInstalledAssistantPackPassesRuntimeValidation(pack) else {
            return false
        }
        return true
    }

    if !alphaAllowsDevelopmentModelArtifacts() {
        if existingRuntimeMode == .llamaCppGguf {
            return false
        }
        if existingRuntimeMode == nil && hasInstalledGGUFCandidate {
            return false
        }
    }

    guard alphaPreferredAssistantRuntimeMode(
        for: tier,
        existingRuntimeMode: .mlxSwiftLm,
        isPhoneFormFactor: isPhoneFormFactor,
        physicalMemoryBytes: physicalMemoryBytes,
        freeStorageGB: freeStorageGB,
        systemAssistantAvailable: false,
        lastInvocation: lastInvocation
    ) == .mlxSwiftLm else {
        return false
    }

    return installedPacks.contains { pack in
        guard pack.tier == tier,
              pack.runtimeMode == .mlxSwiftLm,
              alphaInstalledAssistantPackPassesRuntimeValidation(pack) else {
            return false
        }

        let runtimeEnvironment = alphaLocalRuntimeEnvironment(
            activePack: pack,
            requestedTier: tier,
            installedPacks: installedPacks,
            physicalMemoryBytes: physicalMemoryBytes,
            lowPowerMode: lowPowerMode,
            lastInvocation: lastInvocation
        )
        guard let draftModelPath = runtimeEnvironment.draftModelPath else {
            return false
        }
        return !draftModelPath.isEmpty
    }
}

private func alphaApplyPreferredInstalledRuntimeForSelectedTier(_ state: inout AlphaPersistedState) {
    let selectedTier = alphaOptimisticActivePack(from: state)?.tier ?? state.settings.activeTier
    guard let selectedTier,
          let preferredPack = alphaPreferredInstalledPack(
            for: selectedTier,
            installedPacks: state.installedPacks,
            lastInvocation: alphaLastModelInvocation(in: state)
          ) else {
        return
    }

    let existingPreferredIndex = state.installedPacks.firstIndex { pack in
        pack.id == preferredPack.id ||
            (
                pack.packId == preferredPack.packId &&
                    pack.runtimeMode == preferredPack.runtimeMode &&
                    pack.artifactKind == preferredPack.artifactKind &&
                    pack.installPath == preferredPack.installPath
            )
    }
    let currentPack = state.installedPacks.first { $0.tier == selectedTier && $0.isActive } ??
        alphaOptimisticActivePack(from: state)
    let currentMatchesPreferred =
        currentPack?.id == preferredPack.id ||
        (
            currentPack?.packId == preferredPack.packId &&
                currentPack?.runtimeMode == preferredPack.runtimeMode &&
                currentPack?.artifactKind == preferredPack.artifactKind &&
                currentPack?.installPath == preferredPack.installPath
        )
    guard !currentMatchesPreferred else {
        return
    }

    state.installedPacks = state.installedPacks.map { pack in
        var copy = pack
        if let existingPreferredIndex {
            copy.isActive = state.installedPacks[existingPreferredIndex].id == pack.id
        } else {
            copy.isActive = false
        }
        return copy
    }
    if existingPreferredIndex == nil {
        var activatedPreferredPack = preferredPack
        activatedPreferredPack.isActive = true
        state.installedPacks.insert(activatedPreferredPack, at: 0)
    } else if let existingPreferredIndex {
        state.installedPacks[existingPreferredIndex].isActive = true
    }
    state.settings.activeTier = selectedTier
    if let jobIndex = state.modelJobs.firstIndex(where: {
        $0.tier == selectedTier &&
            $0.packId == preferredPack.packId &&
            $0.runtimeMode == preferredPack.runtimeMode &&
            $0.artifactKind == preferredPack.artifactKind
    }) {
        state.modelJobs[jobIndex].state = .installed
        state.modelJobs[jobIndex].checksumSha256 = preferredPack.checksumSha256
        state.modelJobs[jobIndex].artifactKind = preferredPack.artifactKind
        state.modelJobs[jobIndex].runtimeMode = preferredPack.runtimeMode
        state.modelJobs[jobIndex].developmentOnly = preferredPack.developmentOnly
        state.modelJobs[jobIndex].failureReason = nil
        state.modelJobs[jobIndex].bytesDownloaded = preferredPack.runtimeMode == .appleFoundationModels ? 0 : state.modelJobs[jobIndex].bytesDownloaded
        state.modelJobs[jobIndex].totalBytes = preferredPack.runtimeMode == .appleFoundationModels ? 0 : state.modelJobs[jobIndex].totalBytes
        state.modelJobs[jobIndex].updatedAt = .now
        state.modelJobs[jobIndex].completedAt = state.modelJobs[jobIndex].completedAt ?? .now
    } else if preferredPack.runtimeMode == .appleFoundationModels || preferredPack.artifactKind == "system_model" {
        state.modelJobs.insert(
            AlphaModelDownloadJob(
                sessionId: "system-\(selectedTier.rawValue)",
                packId: preferredPack.packId,
                tier: selectedTier,
                state: .installed,
                networkPolicy: .wifiOnly,
                bytesDownloaded: 0,
                totalBytes: 0,
                checksumSha256: preferredPack.checksumSha256,
                artifactKind: preferredPack.artifactKind,
                runtimeMode: preferredPack.runtimeMode,
                developmentOnly: preferredPack.developmentOnly,
                completedAt: .now
            ),
            at: 0
        )
    }
}

func alphaAvailableStorageInGigabytes() -> Int {
    let values = try? URL.homeDirectory.resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey]
    )
    let bytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
    return Int(bytes / 1_073_741_824)
}

private func alphaCurrentLowPowerMode() -> Bool {
    #if canImport(UIKit)
    ProcessInfo.processInfo.isLowPowerModeEnabled
    #else
    false
    #endif
}

func alphaRecommendedOnDeviceTier(
    freeStorageGB: Int,
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    lowPowerMode: Bool = alphaCurrentLowPowerMode()
) -> AlphaCapabilityTier {
    let memoryGB = max(2, Int(physicalMemoryBytes / 1_073_741_824))

    if memoryGB >= 16, freeStorageGB >= 18, !lowPowerMode {
        return .seniorDraftingSupport
    }
    if memoryGB >= 8, freeStorageGB >= 8 {
        return lowPowerMode && memoryGB < 12 ? .quickStart : .caseAssociate
    }
    return .quickStart
}

private func alphaSystemAssistantRuntimeAvailable(for tier: AlphaCapabilityTier) -> Bool {
    guard !alphaAllowsDevelopmentModelArtifacts(),
          let health = AlphaLocalModelRuntime.runtimeHealth(
            activePack: alphaSystemAssistantPack(for: tier),
            requestedTier: tier
          ),
          health.runtimeMode == .appleFoundationModels else {
        return false
    }
    return health.available
}

func alphaAssistantTierSupportsMLXRuntime(_ tier: AlphaCapabilityTier) -> Bool {
    switch AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier {
    case .quickStart, .caseAssociate:
        return true
    case .flash, .seniorDraftingSupport:
        return false
    }
}

private func alphaShouldPreserveInstalledGGUFOnCapablePhone(
    tier: AlphaCapabilityTier,
    existingRuntimeMode: AlphaPackRuntimeMode?,
    isPhoneFormFactor: Bool,
    physicalMemoryBytes: UInt64
) -> Bool {
    guard existingRuntimeMode == .llamaCppGguf, isPhoneFormFactor else {
        return false
    }

    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    guard normalizedTier == .caseAssociate || normalizedTier == .seniorDraftingSupport else {
        return false
    }

    return physicalMemoryBytes >= 16 * 1_073_741_824
}

func alphaPreferredAssistantRuntimeMode(
    for tier: AlphaCapabilityTier,
    existingRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    systemAssistantAvailable: Bool? = nil,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> AlphaPackRuntimeMode {
    let prefersSystemAssistant = systemAssistantAvailable ?? alphaSystemAssistantRuntimeAvailable(for: tier)
    let recentSignal = alphaRecentRuntimeSelectionSignal(for: tier, lastInvocation: lastInvocation)
    let supportsMLXRuntime = alphaAssistantTierSupportsMLXRuntime(tier)
    let shouldAvoidFoundationFromRecentSignal: Bool = {
        if case .avoidSlow(.appleFoundationModels) = recentSignal {
            return true
        }
        return false
    }()

    if prefersSystemAssistant {
        switch recentSignal {
        case .keepFast(.appleFoundationModels):
            return .appleFoundationModels
        case .keepFast(let runtime):
            if runtime == .mlxSwiftLm && !supportsMLXRuntime {
                break
            }
            return runtime
        case .avoidSlow(.appleFoundationModels):
            break
        default:
            if !isPhoneFormFactor {
                return .appleFoundationModels
            }
            if existingRuntimeMode == .appleFoundationModels,
               !shouldAvoidFoundationFromRecentSignal {
                return .appleFoundationModels
            }
            if (AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier) == .quickStart,
               existingRuntimeMode == nil {
                return .appleFoundationModels
            }
            if alphaShouldPreserveInstalledGGUFOnCapablePhone(
                tier: tier,
                existingRuntimeMode: existingRuntimeMode,
                isPhoneFormFactor: isPhoneFormFactor,
                physicalMemoryBytes: physicalMemoryBytes
            ) {
                return .llamaCppGguf
            }
            let localPreferred = alphaPreferredAssistantRuntimeMode(
                for: tier,
                existingRuntimeMode: existingRuntimeMode == .appleFoundationModels ? nil : existingRuntimeMode,
                isPhoneFormFactor: isPhoneFormFactor,
                physicalMemoryBytes: physicalMemoryBytes,
                freeStorageGB: freeStorageGB,
                systemAssistantAvailable: false,
                lastInvocation: lastInvocation
            )
            if localPreferred != .appleFoundationModels {
                return localPreferred
            }
            return .appleFoundationModels
        }
    }

    if tier == .flash {
        return .llamaCppGguf
    }

    if existingRuntimeMode == .appleFoundationModels, !shouldAvoidFoundationFromRecentSignal {
        return .appleFoundationModels
    }

    guard isPhoneFormFactor else {
        if existingRuntimeMode == .mlxSwiftLm && supportsMLXRuntime {
            return .mlxSwiftLm
        }
        return .llamaCppGguf
    }

    let baselineTier = alphaRecommendedOnDeviceTier(
        freeStorageGB: freeStorageGB,
        physicalMemoryBytes: physicalMemoryBytes,
        lowPowerMode: false
    )

    if let recentSignal {
        switch recentSignal {
        case .keepFast(let runtime):
            if runtime == .mlxSwiftLm && !supportsMLXRuntime {
                break
            }
            return runtime
        case .avoidSlow(.mlxSwiftLm):
            return .llamaCppGguf
        case .avoidSlow(.llamaCppGguf):
            if supportsMLXRuntime && baselineTier != .quickStart {
                return .mlxSwiftLm
            }
        default:
            break
        }
    }

    if alphaShouldPreserveInstalledGGUFOnCapablePhone(
        tier: tier,
        existingRuntimeMode: existingRuntimeMode,
        isPhoneFormFactor: isPhoneFormFactor,
        physicalMemoryBytes: physicalMemoryBytes
    ) {
        return .llamaCppGguf
    }

    if existingRuntimeMode == .mlxSwiftLm && supportsMLXRuntime {
        return .mlxSwiftLm
    }

    return baselineTier == .quickStart || !supportsMLXRuntime ? .llamaCppGguf : .mlxSwiftLm
}

func alphaAssistantRuntimeChoiceLabel(
    selectedRuntimeMode: AlphaPackRuntimeMode,
    tier: AlphaCapabilityTier,
    existingRuntimeMode: AlphaPackRuntimeMode? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    freeStorageGB: Int = max(4, alphaAvailableStorageInGigabytes()),
    systemAssistantAvailable: Bool? = nil,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> String {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let prefersSystemAssistant = systemAssistantAvailable ?? alphaSystemAssistantRuntimeAvailable(for: tier)
    let recentSignal = alphaRecentRuntimeSelectionSignal(for: tier, lastInvocation: lastInvocation)

    if selectedRuntimeMode == .appleFoundationModels && prefersSystemAssistant {
        switch recentSignal {
        case .keepFast(.appleFoundationModels), .none:
            return isPhoneFormFactor
                ? "Built-in CoreAI preferred for instant setup with no download"
                : "Built-in CoreAI model preferred"
        case .avoidSlow(.appleFoundationModels):
            break
        default:
            break
        }
    }

    if tier == .flash && selectedRuntimeMode == .llamaCppGguf {
        return "Flash tier stays on GGUF"
    }

    if let recentSignal {
        switch recentSignal {
        case .keepFast(let runtime) where selectedRuntimeMode == runtime:
            switch runtime {
            case .appleFoundationModels:
                return "CoreAI kept after faster recent run"
            case .mlxSwiftLm:
                return "MLX kept after faster recent run with companion acceleration"
            case .llamaCppGguf:
                return "GGUF kept after faster recent run with MTP acceleration"
            default:
                break
            }
        case .avoidSlow(let runtime):
            if runtime == .appleFoundationModels && selectedRuntimeMode == .mlxSwiftLm {
                return "MLX selected after slower CoreAI run with companion acceleration"
            }
            if runtime == .appleFoundationModels && selectedRuntimeMode == .llamaCppGguf {
                return "GGUF selected after slower CoreAI run with MTP acceleration"
            }
            if runtime == .mlxSwiftLm && selectedRuntimeMode == .llamaCppGguf {
                return "GGUF selected after slower MLX run with MTP acceleration"
            }
            if runtime == .llamaCppGguf && selectedRuntimeMode == .mlxSwiftLm {
                return "MLX selected after slower GGUF run with companion acceleration"
            }
        default:
            break
        }
    }

    if selectedRuntimeMode == .llamaCppGguf,
       alphaShouldPreserveInstalledGGUFOnCapablePhone(
        tier: tier,
        existingRuntimeMode: existingRuntimeMode,
        isPhoneFormFactor: isPhoneFormFactor,
        physicalMemoryBytes: physicalMemoryBytes
       ) {
        return "Installed GGUF kept for larger on-device context"
    }

    if selectedRuntimeMode == .mlxSwiftLm,
       prefersSystemAssistant,
       alphaPreferredAssistantRuntimeMode(
           for: tier,
           existingRuntimeMode: nil,
           isPhoneFormFactor: isPhoneFormFactor,
           physicalMemoryBytes: physicalMemoryBytes,
           freeStorageGB: freeStorageGB,
           systemAssistantAvailable: true,
           lastInvocation: lastInvocation
       ) == .mlxSwiftLm {
        return "MLX preferred on this iPhone for longer local context and companion acceleration"
    }

    if !isPhoneFormFactor && selectedRuntimeMode == .llamaCppGguf {
        return "Larger devices default to GGUF for broader local context"
    }

    if selectedRuntimeMode == .llamaCppGguf,
       isPhoneFormFactor,
       normalizedTier == .seniorDraftingSupport,
       !alphaAssistantTierSupportsMLXRuntime(normalizedTier) {
        return "Senior Drafting Support stays on GGUF on iPhone for deeper local context and MTP acceleration"
    }

    let baselineTier = alphaRecommendedOnDeviceTier(
        freeStorageGB: freeStorageGB,
        physicalMemoryBytes: physicalMemoryBytes,
        lowPowerMode: false
    )

    switch selectedRuntimeMode {
    case .mlxSwiftLm:
        return baselineTier == .quickStart
            ? "MLX kept for installed assistant with companion acceleration"
            : "MLX enabled for deeper local context and companion acceleration"
    case .llamaCppGguf:
        return baselineTier == .quickStart
            ? "GGUF kept as the iPhone baseline with MTP acceleration"
            : "GGUF chosen for broader device compatibility and MTP acceleration"
    case .appleFoundationModels:
        return "Built-in CoreAI model selected"
    case .deterministicDev:
        return "Development runtime override"
    case .mediapipeLlm:
        return "MediaPipe runtime selected"
    case .unavailable:
        return "Runtime unavailable"
    }
}

func alphaAssistantRuntimeTradeoffHint(
    selectedRuntimeMode: AlphaPackRuntimeMode,
    tier: AlphaCapabilityTier,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor()
) -> String? {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier

    switch selectedRuntimeMode {
    case .appleFoundationModels:
        return isPhoneFormFactor
            ? "Best when you want instant setup and quick local answers with no download."
            : "Best when you want built-in local answers with no download."
    case .mlxSwiftLm:
        return isPhoneFormFactor
            ? "Best for longer iPhone context, larger local file coverage, and companion acceleration."
            : "Best for longer local context with the MLX runtime and companion acceleration."
    case .llamaCppGguf:
        if isPhoneFormFactor, normalizedTier == .seniorDraftingSupport {
            return "Best for the deepest iPhone context on larger bundles, longer drafting, and MTP acceleration."
        }
        return isPhoneFormFactor
            ? "Best for broader local context, larger file coverage, and MTP acceleration."
            : "Best for the broadest local context, larger file coverage, and MTP acceleration."
    case .deterministicDev:
        return "Best for development-only runtime checks."
    case .mediapipeLlm:
        return "Best for MediaPipe-based local runtime flows."
    case .unavailable:
        return nil
    }
}

func alphaAssistantUsesPhoneFormFactor() -> Bool {
    alphaCurrentDeviceModelIdentifier().lowercased().hasPrefix("iphone")
}

func alphaCurrentDeviceModelIdentifier(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> String {
    if let simulatorIdentifier = environment["SIMULATOR_MODEL_IDENTIFIER"]?.trimmingCharacters(in: .whitespacesAndNewlines),
       !simulatorIdentifier.isEmpty {
        return simulatorIdentifier
    }

    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifierBytes = mirror.children.compactMap { child -> UInt8? in
        guard let value = child.value as? Int8, value != 0 else {
            return nil
        }
        return UInt8(value)
    }
    return String(decoding: identifierBytes, as: UTF8.self)
}

private func alphaAutomaticMLXDraftPack(
    for activePack: AlphaInstalledModelPack?,
    installedPacks: [AlphaInstalledModelPack],
    physicalMemoryBytes: UInt64,
    lowPowerMode: Bool
) -> AlphaInstalledModelPack? {
    guard let activePack,
          activePack.runtimeMode == .mlxSwiftLm,
          !activePack.developmentOnly,
          !lowPowerMode else {
        return nil
    }

    let memoryGB = max(2, Int(physicalMemoryBytes / 1_073_741_824))
    let preferredTiers: [AlphaCapabilityTier]
    switch activePack.tier {
    case .quickStart, .flash:
        preferredTiers = []
    case .caseAssociate:
        preferredTiers = memoryGB >= 8 ? [.quickStart] : []
    case .seniorDraftingSupport:
        if memoryGB >= 16 {
            preferredTiers = [.caseAssociate, .quickStart]
        } else if memoryGB >= 12 {
            preferredTiers = [.quickStart]
        } else {
            preferredTiers = []
        }
    }

    for tier in preferredTiers {
        if let candidate = installedPacks.first(where: { pack in
            pack.id != activePack.id &&
                pack.tier == tier &&
                pack.runtimeMode == .mlxSwiftLm &&
                !pack.developmentOnly &&
                alphaInstalledModelPackFileIsUsable(pack)
        }) {
            return candidate
        }
    }
    return nil
}

private func alphaAutomaticMLXDraftTokens(
    for activePack: AlphaInstalledModelPack?,
    physicalMemoryBytes: UInt64,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> Int? {
    guard let activePack, activePack.runtimeMode == .mlxSwiftLm else { return nil }
    let baseTokens: Int?
    switch activePack.tier {
    case .quickStart, .flash:
        baseTokens = nil
    case .caseAssociate:
        baseTokens = AlphaMLXRuntimeProfile.defaultDraftTokens(
            for: .caseAssociate,
            physicalMemory: physicalMemoryBytes
        )
    case .seniorDraftingSupport:
        baseTokens = AlphaMLXRuntimeProfile.defaultDraftTokens(
            for: .seniorDraftingSupport,
            physicalMemory: physicalMemoryBytes
        )
    }

    guard let baseTokens else {
        return nil
    }

    guard let lastInvocation,
          lastInvocation.task == .matterQuestionAnswer,
          lastInvocation.capabilityTier == activePack.tier.rawValue,
          alphaInvocationHasAdaptivePerformanceMetrics(lastInvocation),
          lastInvocation.runtimeMode == AlphaPackRuntimeMode.mlxSwiftLm.rawValue,
          let outputSpeed = lastInvocation.estimatedOutputTokensPerSecond,
          let firstTokenMs = lastInvocation.timeToFirstTokenMs else {
        return baseTokens
    }

    if outputSpeed >= 18, firstTokenMs <= 1_000 {
        return min(
            baseTokens + 1,
            AlphaMLXRuntimeProfile.maximumAutomaticDraftTokens(
                for: activePack.tier,
                physicalMemory: physicalMemoryBytes
            )
        )
    }

    if outputSpeed <= 8 || firstTokenMs >= 3_000 {
        return max(baseTokens - 2, 4)
    }

    return baseTokens
}

private func alphaAutomaticGGUFDraftTokens(
    for activePack: AlphaInstalledModelPack?,
    physicalMemoryBytes: UInt64,
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> Int? {
    guard let activePack, activePack.runtimeMode == .llamaCppGguf else { return nil }

    let baseTokens = AlphaLlamaRuntimeProfile.defaultDraftTokens(
        for: activePack.tier,
        modelPath: alphaAbsoluteURL(for: activePack.installPath).path,
        physicalMemory: physicalMemoryBytes
    )

    guard let lastInvocation,
          lastInvocation.task == .matterQuestionAnswer,
          lastInvocation.capabilityTier == activePack.tier.rawValue,
          alphaInvocationHasAdaptivePerformanceMetrics(lastInvocation),
          lastInvocation.runtimeMode == AlphaPackRuntimeMode.llamaCppGguf.rawValue,
          let outputSpeed = lastInvocation.estimatedOutputTokensPerSecond,
          let firstTokenMs = lastInvocation.timeToFirstTokenMs else {
        return baseTokens
    }

    if outputSpeed >= 14, firstTokenMs <= 1_500 {
        return min(baseTokens + 1, 8)
    }

    let minimumTokens = switch activePack.tier {
    case .flash, .quickStart:
        2
    case .caseAssociate, .seniorDraftingSupport:
        4
    }

    if outputSpeed <= 8 || firstTokenMs >= 3_000 {
        return max(baseTokens - 2, minimumTokens)
    }

    return baseTokens
}

private func alphaInstalledGGUFDraftArtifact(
    for activePack: AlphaInstalledModelPack?
) -> AlphaInstalledAssistantDraftArtifact? {
    guard let activePack,
          activePack.runtimeMode == .llamaCppGguf,
          let expectedArtifact = alphaExpectedDownloadedAssistantArtifact(for: activePack),
          let draftArtifact = expectedArtifact.draftArtifact,
          alphaInstalledDraftArtifactIsUsable(draftArtifact) else {
        return nil
    }
    return draftArtifact
}

private func alphaInstalledMLXDraftArtifact(
    for activePack: AlphaInstalledModelPack?
) -> AlphaInstalledAssistantDraftArtifact? {
    guard let activePack,
          activePack.runtimeMode == .mlxSwiftLm,
          let expectedArtifact = alphaExpectedDownloadedAssistantArtifact(for: activePack),
          let draftArtifact = expectedArtifact.draftArtifact,
          draftArtifact.artifactKind == "mlx_directory",
          alphaInstalledDraftArtifactIsUsable(draftArtifact) else {
        return nil
    }
    return draftArtifact
}

func alphaLocalRuntimeEnvironment(
    activePack: AlphaInstalledModelPack?,
    requestedTier: AlphaCapabilityTier?,
    installedPacks: [AlphaInstalledModelPack],
    baseEnvironment: AlphaLocalRuntimeEnvironment = .fromEnvironment(ProcessInfo.processInfo.environment),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    lowPowerMode: Bool = alphaCurrentLowPowerMode(),
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> AlphaLocalRuntimeEnvironment {
    if baseEnvironment.draftModelPath != nil {
        return baseEnvironment
    }

    if let activePack,
       activePack.tier == (requestedTier ?? activePack.tier) || requestedTier == nil,
       let ggufDraftArtifact = alphaInstalledGGUFDraftArtifact(for: activePack) {
        return AlphaLocalRuntimeEnvironment(
            enableRealInference: baseEnvironment.enableRealInference,
            runtimeModeOverride: baseEnvironment.runtimeModeOverride,
            modelPath: baseEnvironment.modelPath,
            modelChecksum: baseEnvironment.modelChecksum,
            modelKind: baseEnvironment.modelKind,
            draftModelPath: alphaAbsoluteURL(for: ggufDraftArtifact.relativePath).path,
            draftModelTokens: baseEnvironment.draftModelTokens ??
                ggufDraftArtifact.draftTokens ??
                alphaAutomaticGGUFDraftTokens(
                    for: activePack,
                    physicalMemoryBytes: physicalMemoryBytes,
                    lastInvocation: lastInvocation
                )
        )
    }

    if let activePack,
       activePack.tier == (requestedTier ?? activePack.tier) || requestedTier == nil,
       let mlxDraftArtifact = alphaInstalledMLXDraftArtifact(for: activePack) {
        return AlphaLocalRuntimeEnvironment(
            enableRealInference: baseEnvironment.enableRealInference,
            runtimeModeOverride: baseEnvironment.runtimeModeOverride,
            modelPath: baseEnvironment.modelPath,
            modelChecksum: baseEnvironment.modelChecksum,
            modelKind: baseEnvironment.modelKind,
            draftModelPath: alphaAbsoluteURL(for: mlxDraftArtifact.relativePath).path,
            draftModelTokens: baseEnvironment.draftModelTokens ??
                mlxDraftArtifact.draftTokens ??
                alphaAutomaticMLXDraftTokens(
                    for: activePack,
                    physicalMemoryBytes: physicalMemoryBytes,
                    lastInvocation: lastInvocation
                )
        )
    }

    guard let activePack,
          activePack.tier == (requestedTier ?? activePack.tier) || requestedTier == nil,
          let draftPack = alphaAutomaticMLXDraftPack(
            for: activePack,
            installedPacks: installedPacks,
            physicalMemoryBytes: physicalMemoryBytes,
            lowPowerMode: lowPowerMode
          ) else {
        return baseEnvironment
    }

    return AlphaLocalRuntimeEnvironment(
        enableRealInference: baseEnvironment.enableRealInference,
        runtimeModeOverride: baseEnvironment.runtimeModeOverride,
        modelPath: baseEnvironment.modelPath,
        modelChecksum: baseEnvironment.modelChecksum,
        modelKind: baseEnvironment.modelKind,
        draftModelPath: alphaAbsoluteURL(for: draftPack.installPath).path,
        draftModelTokens: baseEnvironment.draftModelTokens ?? alphaAutomaticMLXDraftTokens(
            for: activePack,
            physicalMemoryBytes: physicalMemoryBytes,
            lastInvocation: lastInvocation
        )
    )
}

private func alphaFreeDiskSpaceLabel() -> String {
    guard let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
          let freeSize = systemAttributes[.systemFreeSize] as? NSNumber else {
        return "Unknown free space"
    }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.countStyle = .file
    return "\(formatter.string(fromByteCount: freeSize.int64Value)) available"
}

func alphaLastModelInvocation(in state: AlphaPersistedState) -> AlphaLocalModelInvocation? {
    let documentInvocations = state.cases
        .flatMap(\.documents)
        .flatMap(\.modelInvocations)
    let chatInvocations = state.cases
        .flatMap(\.chatSessions)
        .flatMap(\.turns)
        .compactMap(\.modelInvocation)
    return (documentInvocations + chatInvocations)
        .max { lhs, rhs in
            (lhs.completedAt ?? lhs.startedAt) < (rhs.completedAt ?? rhs.startedAt)
        }
}

private func alphaPrivateAISnapshotRefreshKey(for state: AlphaPersistedState) -> AlphaPrivateAISnapshotRefreshKey {
    let documentInvocationCount = state.cases.reduce(into: 0) { total, caseMatter in
        total += caseMatter.documents.reduce(into: 0) { $0 += $1.modelInvocations.count }
    }
    let chatInvocationCount = state.cases.reduce(into: 0) { total, caseMatter in
        total += caseMatter.chatSessions.reduce(into: 0) { partial, session in
            partial += session.turns.lazy.filter { $0.modelInvocation != nil }.count
        }
    }
    return AlphaPrivateAISnapshotRefreshKey(
        installedPacks: state.installedPacks,
        activeTier: state.settings.activeTier,
        ledgerCount: state.ledgerEntries.count,
        documentInvocationCount: documentInvocationCount,
        chatInvocationCount: chatInvocationCount
    )
}

private func alphaBuildPrivateAISnapshot(
    from state: AlphaPersistedState,
    allowDiskRecovery: Bool,
    hadUnfinishedStartupValidation: Bool = false
) async -> AlphaPrivateAISnapshotBuildResult {
    await Task.detached(priority: .utility) {
        var recoveredState = state
        let stateChangedByRecovery: Bool
        if allowDiskRecovery {
            stateChangedByRecovery = alphaRecoverDownloadedAssistantArtifacts(from: &recoveredState)
        } else {
            let invalidPackIDs = Set(recoveredState.installedPacks.filter { !alphaInstalledModelPackFileIsUsable($0) }.map(\.id))
            recoveredState.installedPacks.removeAll { invalidPackIDs.contains($0.id) }
            stateChangedByRecovery = !invalidPackIDs.isEmpty
        }
        if hadUnfinishedStartupValidation {
            alphaQuarantineActiveAssistantAfterStartupFailure(&recoveredState)
        }
        alphaQuarantineIncompleteInstalledAssistantJob(&recoveredState)
        alphaQuarantineUnusableActiveDownloadedAssistant(&recoveredState)
        alphaConvergeInstalledAssistantCatalog(&recoveredState)
        alphaConvergeAssistantUpdateCandidates(&recoveredState)
        alphaApplyPreferredInstalledRuntimeForSelectedTier(&recoveredState)
        let activePack = alphaValidatedActivePack(from: recoveredState)
        if let activePack,
           (activePack.runtimeMode == .appleFoundationModels || activePack.artifactKind == "system_model"),
           !recoveredState.installedPacks.contains(where: {
               $0.packId == activePack.packId &&
                   $0.runtimeMode == activePack.runtimeMode &&
                   $0.artifactKind == activePack.artifactKind &&
                   $0.installPath == activePack.installPath
           }) {
            var insertedActivePack = activePack
            insertedActivePack.isActive = true
            recoveredState.installedPacks.insert(insertedActivePack, at: 0)
            if !recoveredState.modelJobs.contains(where: {
                $0.tier == insertedActivePack.tier &&
                    $0.packId == insertedActivePack.packId &&
                    $0.runtimeMode == insertedActivePack.runtimeMode &&
                    $0.artifactKind == insertedActivePack.artifactKind &&
                    $0.state == .installed
            }) {
                recoveredState.modelJobs.insert(
                    AlphaModelDownloadJob(
                        sessionId: "system-\(insertedActivePack.tier.rawValue)",
                        packId: insertedActivePack.packId,
                        tier: insertedActivePack.tier,
                        state: .installed,
                        networkPolicy: .wifiOnly,
                        bytesDownloaded: 0,
                        totalBytes: 0,
                        checksumSha256: insertedActivePack.checksumSha256,
                        artifactKind: insertedActivePack.artifactKind,
                        runtimeMode: insertedActivePack.runtimeMode,
                        developmentOnly: insertedActivePack.developmentOnly,
                        completedAt: .now
                    ),
                    at: 0
                )
            }
        }
        recoveredState.installedPacks = alphaNormalizedInstalledPacks(from: recoveredState, activePack: activePack)
        if let activePack, recoveredState.settings.activeTier != activePack.tier {
            recoveredState.settings.activeTier = activePack.tier
        }

        let freeStorageGB = max(4, alphaAvailableStorageInGigabytes())
        let requestedTier = activePack?.tier ?? recoveredState.settings.activeTier
        let lastInvocation = alphaLastModelInvocation(in: recoveredState)
        let runtimeEnvironment = alphaLocalRuntimeEnvironment(
            activePack: activePack,
            requestedTier: requestedTier,
            installedPacks: recoveredState.installedPacks,
            lastInvocation: lastInvocation
        )
        let snapshot = AlphaPrivateAISnapshot(
            installedPacks: recoveredState.installedPacks,
            activePack: activePack,
            activeRuntimeHealth: AlphaLocalModelRuntime.runtimeHealth(
                activePack: activePack,
                requestedTier: requestedTier,
                runtimeEnvironment: runtimeEnvironment
            ),
            recommendedTier: alphaRecommendedOnDeviceTier(freeStorageGB: freeStorageGB),
            freeDiskSpaceLabel: alphaFreeDiskSpaceLabel(),
            lastModelInvocation: lastInvocation,
            resetCount: recoveredState.ledgerEntries.filter { $0.title.localizedCaseInsensitiveContains("reset") }.count
        )

        let stateChanged = stateChangedByRecovery || recoveredState != state
        return AlphaPrivateAISnapshotBuildResult(
            recoveredState: recoveredState,
            snapshot: snapshot,
            stateChanged: stateChanged
        )
    }.value
}

extension AlphaRossModel {

    func syncPrivateAISnapshotFromPersisted() {
        let existingReadyPack = privateAISnapshot.activePack
        let existingReadyHealth = privateAISnapshot.activeRuntimeHealth
        let optimisticActivePack = alphaOptimisticActivePack(from: persisted)
        privateAISnapshot.installedPacks = persisted.installedPacks
        if optimisticActivePack == nil,
           persisted.installedPacks.isEmpty,
           existingReadyHealth?.available == true {
            privateAISnapshot.activePack = existingReadyPack
            privateAISnapshot.activeRuntimeHealth = existingReadyHealth
        } else if let optimisticActivePack,
                  optimisticActivePack.runtimeMode == .llamaCppGguf,
                  !optimisticActivePack.developmentOnly {
            let runtimeLabel = URL(fileURLWithPath: optimisticActivePack.installPath).lastPathComponent
            privateAISnapshot.activePack = nil
            privateAISnapshot.activeRuntimeHealth = AlphaLocalRuntimeHealth(
                runtimeMode: .llamaCppGguf,
                available: false,
                modelPathPresent: installedModelPackFileIsUsable(optimisticActivePack),
                modelPathLabel: runtimeLabel,
                checksumVerified: optimisticActivePack.checksumVerified,
                supportedTasks: Array(Set(AlphaLocalModelTask.allCases)),
                maxInputChars: AlphaLlamaRuntimeProfile.maxInputChars(for: optimisticActivePack.tier),
                estimatedContextTokens: Int(
                    AlphaLlamaRuntimeProfile.contextWindowTokens(forModelPath: runtimeLabel)
                ),
                lastErrorCategory: "runtime_validation_pending",
                userFacingStatus: "Ross is checking assistant setup before enabling private answers.",
                explicitOptInEnabled: true
            )
        } else {
            privateAISnapshot.activePack = optimisticActivePack
            let requestedTier = optimisticActivePack?.tier ?? persisted.settings.activeTier
            let runtimeEnvironment = alphaLocalRuntimeEnvironment(
                activePack: optimisticActivePack,
                requestedTier: requestedTier,
                installedPacks: persisted.installedPacks,
                lastInvocation: alphaLastModelInvocation(in: persisted)
            )
            privateAISnapshot.activeRuntimeHealth = AlphaLocalModelRuntime.runtimeHealth(
                activePack: optimisticActivePack,
                requestedTier: requestedTier,
                runtimeEnvironment: runtimeEnvironment
            )
        }
        privateAISnapshot.resetCount = persisted.ledgerEntries.filter { $0.title.localizedCaseInsensitiveContains("reset") }.count
    }

    /// Debounce the expensive snapshot refresh so that bursty mutations
    /// (chat-turn updates, token-streamed answer edits, document edits, etc.)
    /// only trigger one snapshot refresh per quiet window. Without this,
    /// every `persisted` write recomputes an O(N*M*K) refresh key and may
    /// spawn a disk-recovery task — the dominant source of UI lag.
    func scheduleDebouncedPrivateAISnapshotRefresh() {
        debouncedSnapshotRefreshTask?.cancel()
        debouncedSnapshotRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.refreshPrivateAISnapshot()
            }
        }
    }

    func refreshPrivateAISnapshot(
        forceValidation: Bool = false,
        forceRebuild: Bool = false
    ) {
        let refreshKey = alphaPrivateAISnapshotRefreshKey(for: persisted)
        guard forceValidation || forceRebuild || privateAISnapshotRefreshKey != refreshKey else { return }

        privateAISnapshotRefreshKey = refreshKey
        let state = persisted
        let allowDiskRecovery = true
        let hadUnfinishedStartupValidation = alphaHadUnfinishedPrivateAIStartupValidation()
        if forceValidation {
            alphaMarkPrivateAIStartupValidationStarted()
        }
        privateAISnapshotTask?.cancel()
        privateAISnapshotTask = Task {
            let result = await alphaBuildPrivateAISnapshot(
                from: state,
                allowDiskRecovery: allowDiskRecovery,
                hadUnfinishedStartupValidation: hadUnfinishedStartupValidation
            )
            if forceValidation {
                alphaMarkPrivateAIStartupValidationFinished()
            }
            guard !Task.isCancelled else { return }

            privateAISnapshot = result.snapshot
            if result.stateChanged && persisted != result.recoveredState {
                var needsPersist = false
                if persisted.installedPacks != result.recoveredState.installedPacks {
                    persisted.installedPacks = result.recoveredState.installedPacks
                    needsPersist = true
                }
                if persisted.modelJobs != result.recoveredState.modelJobs {
                    persisted.modelJobs = result.recoveredState.modelJobs
                    needsPersist = true
                }
                if persisted.settings.activeTier != result.recoveredState.settings.activeTier {
                    persisted.settings.activeTier = result.recoveredState.settings.activeTier
                    needsPersist = true
                }
                if persisted.ledgerEntries != result.recoveredState.ledgerEntries {
                    persisted.ledgerEntries = result.recoveredState.ledgerEntries
                    needsPersist = true
                }
                guard needsPersist else { return }
                persist()
            }
        }
    }

    func cancelPrivateAISnapshotValidation() {
        privateAISnapshotTask?.cancel()
        privateAISnapshotTask = nil
        alphaMarkPrivateAIStartupValidationFinished()
    }

    func loadIfNeeded() async {
        guard !loaded else { return }
        do {
            let loadedState = try await store.load()
            persisted = normalizeLoadedState(loadedState)
            if persisted.installedPacks != loadedState.installedPacks ||
                persisted.modelJobs != loadedState.modelJobs ||
                persisted.settings.activeTier != loadedState.settings.activeTier {
                persist()
            }
            invalidateWorkspaceDerivedState()
            syncDerivedStateFromPersisted()
            syncPrivateAISnapshotFromPersisted()
            refreshPrivateAISnapshot(forceValidation: true)
            loaded = true
        } catch {
            syncPrivateAISnapshotFromPersisted()
            refreshPrivateAISnapshot(forceValidation: true)
            loaded = true
        }
    }

    func clearStaleAskState(for currentRoute: AlphaRoute?) {
        guard let latestAskResult else { return }

        let routeCaseID: UUID?
        switch currentRoute {
        case .caseWorkspace(let id), .askCase(let id):
            routeCaseID = id
        default:
            routeCaseID = nil
        }

        if latestAskResult.scopeCaseID != routeCaseID {
            self.latestAskResult = nil
        }
    }

    func syncWorkspaceForSession(_ session: RossAuthSession?) {
        guard loaded else { return }
        refreshPrivateAISnapshot(forceValidation: true)

        if let session, session.subject.hasPrefix("local_demo_") {
            if shouldSeedDemoWorkspace(for: session.subject) {
                let preserved = preservedWorkspaceConfiguration()
                persisted = AlphaPersistedState.demoSeed(profileSubject: session.subject)
                applyPreservedWorkspaceConfiguration(preserved)
                persist(workspaceChanged: true)
                refreshPrivateAISnapshot(forceValidation: true)
            }
            return
        }

        if let session, session.subject.hasPrefix("local_fresh_") {
            if persisted.demoProfileSubject != nil || isLegacySeedWorkspace {
                let preserved = preservedWorkspaceConfiguration()
                persisted = AlphaPersistedState.empty()
                applyPreservedWorkspaceConfiguration(preserved)
                persist(workspaceChanged: true)
                refreshPrivateAISnapshot(forceValidation: true)
            }
            return
        }

        if persisted.demoProfileSubject != nil, isCurrentWorkspaceDemoOnly {
            let preserved = preservedWorkspaceConfiguration()
            persisted = AlphaPersistedState.empty()
            applyPreservedWorkspaceConfiguration(preserved)
            persist(workspaceChanged: true)
            refreshPrivateAISnapshot(forceValidation: true)
        }
    }

    func syncDerivedStateFromPersisted() {
        selectedCaseID = cases.first?.id
        selectedTier = preferredSelectedAssistantTier()
        publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
        publicLawPreview = persisted.publicLawPreview
        publicLawResults = persisted.publicLawResults ?? []
        rebuildAskHistory()
    }

    func rebuildAskHistory() {
        askHistory = persisted.cases.flatMap { caseMatter in
            caseMatter.chatSessions.flatMap { session in
                session.turns.reversed().map { turn in
                    askResult(from: turn, in: caseMatter, chatSessionID: session.id)
                }
            }
        }
    }

    struct AlphaPreservedWorkspaceConfiguration {
        var settings: AlphaSettings
        var modelJobs: [AlphaModelDownloadJob]
        var installedPacks: [AlphaInstalledModelPack]
        var lastModelCatalogRefresh: Date?
        var cachedAssistantCatalogs: [AlphaAssistantCatalogDescriptor]?
        var cachedAssistantDownloads: [AlphaAssistantDownloadDescriptor]?
    }

    func preservedWorkspaceConfiguration() -> AlphaPreservedWorkspaceConfiguration {
        AlphaPreservedWorkspaceConfiguration(
            settings: persisted.settings,
            modelJobs: persisted.modelJobs,
            installedPacks: persisted.installedPacks,
            lastModelCatalogRefresh: persisted.lastModelCatalogRefresh,
            cachedAssistantCatalogs: persisted.cachedAssistantCatalogs,
            cachedAssistantDownloads: persisted.cachedAssistantDownloads
        )
    }

    func applyPreservedWorkspaceConfiguration(_ preserved: AlphaPreservedWorkspaceConfiguration) {
        persisted.settings = preserved.settings
        persisted.modelJobs = preserved.modelJobs
        persisted.installedPacks = preserved.installedPacks
        persisted.lastModelCatalogRefresh = preserved.lastModelCatalogRefresh
        persisted.cachedAssistantCatalogs = preserved.cachedAssistantCatalogs
        persisted.cachedAssistantDownloads = preserved.cachedAssistantDownloads
        selectedTier = preferredSelectedAssistantTier()
        publicLawDraft = persisted.publicLawDraft ?? publicLawDraft
        publicLawPreview = persisted.publicLawPreview
        publicLawResults = persisted.publicLawResults ?? []
        syncDerivedStateFromPersisted()
    }

    var visibleCasesCount: Int {
        persisted.cases.filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }.count
    }

    var isLegacySeedWorkspace: Bool {
        let titles = Set(
            persisted.cases
                .filter { $0.id != alphaSharedWorkspaceID }
                .map(\.title)
        )
        return titles == [
            "Kaveri Developers v. South Ward Municipal Corporation",
            "Arun Textiles v. State Tax Officer"
        ]
    }

    var isCurrentWorkspaceDemoOnly: Bool {
        let visibleCases = persisted.cases.filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }
        guard visibleCases.count == 1 else { return false }
        guard visibleCases.first?.title == "Demo Matter: Sharma v. Rana" else { return false }
        let exportCount = persisted.exports.filter { $0.caseId == visibleCases.first?.id }.count
        return exportCount <= 1
    }

    func shouldSeedDemoWorkspace(for subject: String) -> Bool {
        if persisted.demoProfileSubject == subject {
            return false
        }
        if visibleCasesCount == 0 || isLegacySeedWorkspace {
            return true
        }
        if persisted.demoProfileSubject != nil && isCurrentWorkspaceDemoOnly {
            return true
        }
        return false
    }

    func invalidateWorkspaceDerivedState() {
        workspaceRevision &+= 1
    }

    func ensureWorkspaceDerivedState() {
        guard cachedWorkspaceRevision != workspaceRevision else { return }
        workspaceDerivedState = AlphaWorkspaceDerivedState.build(from: persisted)
        cachedWorkspaceRevision = workspaceRevision
    }

    struct AlphaWorkspaceDerivedState {
        var visibleCases: [AlphaCaseMatter] = []
        var activeCaseIDs: Set<UUID> = []
        var nextActionDateByCase: [UUID: Date] = [:]
        var tasks: [AlphaTaskItem] = []
        var tasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var openTasks: [AlphaTaskItem] = []
        var openTaskCountByCase: [UUID: Int] = [:]
        var todayTasks: [AlphaTaskItem] = []
        var todayTasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var upcomingTasks: [AlphaTaskItem] = []
        var upcomingTasksByCase: [UUID: [AlphaTaskItem]] = [:]
        var reviewQueue: [AlphaReviewQueueItem] = []
        var reviewQueueByCase: [UUID: [AlphaReviewQueueItem]] = [:]
        var availableAskDocumentsAll: [AlphaAskDocumentOption] = []
        var availableAskDocumentsByScope: [UUID: [AlphaAskDocumentOption]] = [:]
        var recentDocumentItems: [AlphaRecentDocumentItem] = []
        var recentDocumentItemsByCase: [UUID: [AlphaRecentDocumentItem]] = [:]
        var todayDateRows: [AlphaUpcomingDateRow] = []
        var upcomingDateRows: [AlphaUpcomingDateRow] = []

        static func build(from persisted: AlphaPersistedState) -> Self {
            let visibleCases = persisted.cases
                .filter { $0.archivedAt == nil && $0.id != alphaSharedWorkspaceID }
                .sorted { $0.updatedAt > $1.updatedAt }
            let activeCaseIDs = Set(visibleCases.map(\.id))

            let allTasks = (persisted.tasks ?? [])
                .filter { task in
                    guard let caseId = task.caseId else { return true }
                    return activeCaseIDs.contains(caseId)
                }
                .sorted(by: sortTasks)

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: .now)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? .now

            var tasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var openTaskCountByCase: [UUID: Int] = [:]
            var todayTasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var upcomingTasksByCase: [UUID: [AlphaTaskItem]] = [:]
            var openTasks: [AlphaTaskItem] = []
            var todayTasks: [AlphaTaskItem] = []
            var upcomingTasks: [AlphaTaskItem] = []

            for task in allTasks {
                if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                    tasksByCase[caseId, default: []].append(task)
                }

                guard task.status == .open else { continue }
                openTasks.append(task)

                if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                    openTaskCountByCase[caseId, default: 0] += 1
                }

                guard let dueDate = task.dueDate else { continue }
                if dueDate < startOfTomorrow {
                    todayTasks.append(task)
                    if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                        todayTasksByCase[caseId, default: []].append(task)
                    }
                } else if dueDate >= startOfTomorrow {
                    upcomingTasks.append(task)
                    if let caseId = task.caseId, caseId != alphaSharedWorkspaceID {
                        upcomingTasksByCase[caseId, default: []].append(task)
                    }
                }
            }

            var reviewQueueByCase: [UUID: [AlphaReviewQueueItem]] = [:]
            var reviewQueue: [AlphaReviewQueueItem] = []
            var recentDocumentItemsByCase: [UUID: [AlphaRecentDocumentItem]] = [:]
            var recentDocumentItems: [AlphaRecentDocumentItem] = []
            var todayDateRows: [AlphaUpcomingDateRow] = []
            var upcomingDateRows: [AlphaUpcomingDateRow] = []
            var nextActionDateByCase: [UUID: Date] = [:]

            for caseMatter in visibleCases {
                let caseReviewQueue = buildReviewQueue(for: caseMatter)
                reviewQueueByCase[caseMatter.id] = caseReviewQueue
                reviewQueue.append(contentsOf: caseReviewQueue)

                let caseRecentItems = caseMatter.documents
                    .map { document in
                        AlphaRecentDocumentItem(caseId: caseMatter.id, caseTitle: caseMatter.title, document: document)
                    }
                    .sorted { $0.document.importedAt > $1.document.importedAt }
                recentDocumentItemsByCase[caseMatter.id] = caseRecentItems
                recentDocumentItems.append(contentsOf: caseRecentItems)

                let scheduledDates = caseMatter.dates
                    .filter { $0.status == .scheduled }
                    .sorted { $0.date < $1.date }
                let nextTaskDate = tasksByCase[caseMatter.id]?
                    .first { $0.status == .open && $0.dueDate != nil }?
                    .dueDate
                nextActionDateByCase[caseMatter.id] = [nextTaskDate, scheduledDates.first?.date, caseMatter.nextHearing]
                    .compactMap { $0 }
                    .min()

                let dateRows: [AlphaUpcomingDateRow]
                if scheduledDates.isEmpty, let nextHearing = caseMatter.nextHearing {
                    dateRows = [
                        AlphaUpcomingDateRow(
                            title: caseMatter.title,
                            detail: nextHearing < startOfDay
                                ? "Overdue hearing from \(nextHearing.formatted(date: .abbreviated, time: .omitted))"
                                : calendar.isDateInToday(nextHearing)
                                    ? "Hearing today"
                                    : "Next date: \(nextHearing.formatted(date: .abbreviated, time: .omitted))",
                            date: nextHearing
                        )
                    ]
                } else {
                    dateRows = scheduledDates.map { matterDate in
                        let prefix: String
                        if matterDate.date < startOfDay {
                            prefix = "Overdue"
                        } else if calendar.isDateInToday(matterDate.date) {
                            prefix = "Today"
                        } else {
                            prefix = matterDate.title
                        }
                        let detail = prefix == "Today"
                            ? "\(matterDate.title) today"
                            : "\(prefix): \(matterDate.date.formatted(date: .abbreviated, time: .omitted))"
                        return AlphaUpcomingDateRow(title: caseMatter.title, detail: detail, date: matterDate.date)
                    }
                }

                for row in dateRows {
                    if row.date < startOfTomorrow {
                        todayDateRows.append(row)
                    } else {
                        upcomingDateRows.append(row)
                    }
                }
            }

            recentDocumentItems.sort { $0.document.importedAt > $1.document.importedAt }
            todayDateRows.sort { $0.date < $1.date }
            upcomingDateRows.sort { $0.date < $1.date }

            var availableAskDocumentsByScope: [UUID: [AlphaAskDocumentOption]] = [:]
            for caseMatter in visibleCases {
                let scopedCases = persisted.cases.filter { $0.id == caseMatter.id || $0.id == alphaSharedWorkspaceID }
                availableAskDocumentsByScope[caseMatter.id] = buildAskDocumentOptions(from: scopedCases)
            }

            var state = AlphaWorkspaceDerivedState()
            state.visibleCases = visibleCases
            state.activeCaseIDs = activeCaseIDs
            state.nextActionDateByCase = nextActionDateByCase
            state.tasks = allTasks
            state.tasksByCase = tasksByCase
            state.openTasks = openTasks
            state.openTaskCountByCase = openTaskCountByCase
            state.todayTasks = todayTasks
            state.todayTasksByCase = todayTasksByCase
            state.upcomingTasks = upcomingTasks
            state.upcomingTasksByCase = upcomingTasksByCase
            state.reviewQueue = reviewQueue
            state.reviewQueueByCase = reviewQueueByCase
            state.availableAskDocumentsAll = buildAskDocumentOptions(from: persisted.cases)
            state.availableAskDocumentsByScope = availableAskDocumentsByScope
            state.recentDocumentItems = recentDocumentItems
            state.recentDocumentItemsByCase = recentDocumentItemsByCase
            state.todayDateRows = todayDateRows
            state.upcomingDateRows = upcomingDateRows
            return state
        }

        static func sortTasks(lhs: AlphaTaskItem, rhs: AlphaTaskItem) -> Bool {
            if lhs.status != rhs.status {
                return lhs.status == .open
            }
            let lhsDate = lhs.dueDate ?? .distantFuture
            let rhsDate = rhs.dueDate ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        static func buildAskDocumentOptions(from cases: [AlphaCaseMatter]) -> [AlphaAskDocumentOption] {
            cases
                .flatMap { caseMatter in
                    caseMatter.documents.map { document in
                        AlphaAskDocumentOption(
                            id: document.id,
                            caseId: caseMatter.id,
                            caseTitle: caseMatter.title,
                            title: document.title,
                            fileName: document.fileName,
                            kind: document.kind,
                            isShared: caseMatter.id == alphaSharedWorkspaceID
                        )
                    }
                }
                .sorted { lhs, rhs in
                    if lhs.isShared != rhs.isShared {
                        return lhs.isShared && !rhs.isShared
                    }
                    if lhs.caseTitle != rhs.caseTitle {
                        return lhs.caseTitle.localizedCaseInsensitiveCompare(rhs.caseTitle) == .orderedAscending
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
        }

        static func buildReviewQueue(for caseMatter: AlphaCaseMatter) -> [AlphaReviewQueueItem] {
            let ignoredFieldIDs = Set(
                caseMatter.advocateCorrections
                    .filter { $0.correctionType == .ignoreField }
                    .compactMap(\.fieldId)
            )

            return caseMatter.documents.flatMap { document in
                let visibleFields = document.extractedFields
                    .filter { !ignoredFieldIDs.contains($0.id) }
                    .sorted { lhs, rhs in
                        let lhsRank = alphaFieldSortRank(lhs.fieldType)
                        let rhsRank = alphaFieldSortRank(rhs.fieldType)
                        if lhsRank == rhsRank {
                            return lhs.createdAt < rhs.createdAt
                        }
                        return lhsRank < rhsRank
                    }

                let fields = visibleFields
                    .filter(\.needsReview)
                    .map { field in
                        AlphaReviewQueueItem(
                            caseId: caseMatter.id,
                            documentId: document.id,
                            caseTitle: caseMatter.title,
                            title: reviewTitle(for: field.fieldType),
                            detail: field.value,
                            sourceRef: field.sourceRefs.first,
                            target: .extractedField(field.id)
                        )
                    }

                let findings = document.extractionFindings
                    .filter { !$0.resolved }
                    .map { finding in
                        AlphaReviewQueueItem(
                            caseId: caseMatter.id,
                            documentId: document.id,
                            caseTitle: caseMatter.title,
                            title: reviewTitle(for: finding.kind),
                            detail: finding.message,
                            sourceRef: finding.sourceRefs.first,
                            target: .finding(finding.id)
                        )
                    }

                return fields + findings
            }
        }

        static func reviewTitle(for fieldType: AlphaExtractedLegalFieldType) -> String {
            switch fieldType {
            case .nextDate:
                rossLocalized("review_title_confirm_next_date")
            case .partyName:
                rossLocalized("review_title_review_party_name")
            case .orderDirection:
                rossLocalized("review_title_check_order_direction")
            default:
                rossLocalized("please_confirm")
            }
        }

        static func reviewTitle(for findingKind: AlphaExtractionFindingKind) -> String {
            switch findingKind {
            case .lowConfidenceOcr, .languageUncertain, .possibleHandwriting:
                rossLocalized("document_status_low_confidence_scan")
            case .ambiguousOrderDirection:
                rossLocalized("review_title_check_order_direction")
            case .dateConflict:
                rossLocalized("review_title_confirm_next_date")
            case .partyConflict:
                rossLocalized("review_title_review_party_name")
            default:
                rossLocalized("please_confirm")
            }
        }
    }

    func askResult(
        from turn: AlphaChatTurn,
        in caseMatter: AlphaCaseMatter,
        chatSessionID: UUID
    ) -> AlphaAskResult {
        let isSharedWorkspace = caseMatter.id == alphaSharedWorkspaceID
        return AlphaAskResult(
            chatSessionID: chatSessionID,
            chatTurnID: turn.id,
            kind: turn.kind,
            question: turn.question,
            scopeCaseID: isSharedWorkspace ? nil : caseMatter.id,
            scopeLabel: isSharedWorkspace ? rossLocalized("all_work") : caseMatter.title,
            selectedDocumentIDs: turn.selectedDocumentIDs ?? [],
            selectedDocumentTitles: turn.selectedDocumentTitles ?? [],
            answerTitle: turn.answerTitle,
            answerSections: turn.answerSections,
            caseFileSources: turn.sourceRefs,
            publicLawPreview: turn.publicLawPreview,
            publicLawResults: turn.publicLawResults,
            statusNote: turn.statusNote,
            needsReviewWarning: turn.needsReviewWarning,
            modelInvocation: turn.modelInvocation,
            upgradeTierHint: turn.upgradeTierHint,
            upgradeRuntimeHint: turn.upgradeRuntimeHint
        )
    }

    var cases: [AlphaCaseMatter] {
        ensureWorkspaceDerivedState()
        return workspaceDerivedState.visibleCases
    }

    func todayTasks(for caseId: UUID? = nil) -> [AlphaTaskItem] {
        ensureWorkspaceDerivedState()
        guard let caseId else { return workspaceDerivedState.todayTasks }
        return workspaceDerivedState.todayTasksByCase[caseId] ?? []
    }

    var activePack: AlphaInstalledModelPack? {
        let selectedTier = persisted.settings.activeTier ?? self.selectedTier
        let currentPack = privateAISnapshot.activePack ?? alphaOptimisticActivePack(from: persisted)
        if let fallbackPack = alphaRecoveredAssistantExecutionFallback(
            from: persisted,
            selectedTier: selectedTier,
            currentPack: currentPack
        ) {
            return fallbackPack
        }
        if let activePack = currentPack {
            return activePack
        }
        if let recovered = alphaRecoveredInstalledPackFromDisk(tier: selectedTier) {
            return recovered
        }
        return AlphaCapabilityTier.installableAssistantTiers.lazy.compactMap { alphaRecoveredInstalledPackFromDisk(tier: $0) }.first
    }

    func submitDockInput(question: String, scopeCaseID: UUID?, webEnabled: Bool) async {
        let cleaned = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        setAskDraft("", for: scopeCaseID)

        if let command = dockCommandAction(for: cleaned) {
            await runDockCommand(command, rawInput: cleaned, scopeCaseID: scopeCaseID)
            return
        }

        submitAsk(question: cleaned, scopeCaseID: scopeCaseID, webEnabled: webEnabled)
    }

    func runLocalInferenceSmoke() {
        guard !localInferenceSmokeRunning else { return }
        localInferenceSmokeRunning = true
        localInferenceSmokeReport = nil

        Task {
            let runtimeHealth = activeRuntimeHealth
            guard let runtimeHealth, runtimeHealth.available else {
                recordLocalInferenceSmokeReport(AlphaLocalInferenceSmokeReport(
                    ran: false,
                    runtimeUsed: runtimeHealth?.runtimeMode.rawValue ?? AlphaPackRuntimeMode.unavailable.rawValue,
                    schemaValid: false,
                    fieldsFound: 0,
                    fieldsVerified: 0,
                    fieldsNeedingReview: 0,
                    unsupportedAccepted: 0,
                    exportRelativePath: nil,
                    message: alphaPrivateAIVisibleRecoveryText(
                        runtimeHealth?.userFacingStatus,
                        fallback: alphaRuntimeHealthStatus(.privateAssistantUnavailable)
                    )
                ))
                localInferenceSmokeRunning = false
                return
            }

            let smokeCaseID = UUID()
            let smokeDocumentID = UUID()
            let smokeText = """
            IN THE HIGH COURT OF DELHI AT NEW DELHI
            CS(COMM) 245/2026
            Order dated 14 March 2026
            The matter concerns delay condonation and Section 138 of the Negotiable Instruments Act.
            The respondent shall file a written statement within two weeks.
            List on 28 April 2026.
            """
            let smokeDocument = AlphaCaseDocument(
                id: smokeDocumentID,
                title: "Case Associate Local Smoke",
                fileName: "case-associate-local-smoke.txt",
                kind: .text,
                storedRelativePath: "smoke/case-associate-local-smoke.txt",
                importedAt: .now,
                pageCount: 1,
                ocrStatus: .nativeText,
                indexingStatus: .indexed,
                extractedText: smokeText,
                dominantSourceSnippet: "Delay condonation and Section 138 written statement order.",
                lastIndexedAt: .now,
                pages: [
                    AlphaDocumentPage(
                        pageNumber: 1,
                        snippet: "Delay condonation and Section 138 written statement order.",
                        extractedText: smokeText,
                        anchorText: "Delay condonation and Section 138 written statement order.",
                        ocrConfidence: 0.99,
                        ocrStatus: .nativeText,
                        indexingStatus: .indexed
                    )
                ]
            )

            let result = await runLocalExtractionWithAssistantFallback(
                caseId: smokeCaseID,
                document: smokeDocument,
                requestedTier: activePack?.tier ?? persisted.settings.activeTier ?? selectedTier,
                currentPack: activePack
            )

            let export: AlphaExportedReport?
            do {
                export = try await store.createPDFExport(
                    title: rossLocalized("private_assistant_sample_file_check_report_title"),
                    kind: "case_note",
                    caseId: nil,
                    bodyLines: [
                        rossLocalized("export_draft_review"),
                        rossLocalized("private_assistant_sample_file_check_completed_on_iphone"),
                        rossLocalized("private_assistant_ready_on_device"),
                        String(format: rossLocalized("fields_found_count"), result.extractedFields.count),
                        String(format: rossLocalized("fields_verified_count"), result.extractedFields.filter { !$0.needsReview || $0.userCorrected }.count),
                        String(format: rossLocalized("fields_needing_review_count"), result.extractedFields.filter { $0.needsReview && !$0.userCorrected }.count)
                    ]
                )
            } catch {
                export = nil
            }

            if let export {
                persisted.exports.insert(export, at: 0)
                persist()
            }

            recordLocalInferenceSmokeReport(AlphaLocalInferenceSmokeReport(
                ran: true,
                runtimeUsed: result.modelInvocations.last?.runtimeMode ?? runtimeHealth.runtimeMode.rawValue,
                schemaValid: !result.modelInvocations.contains { $0.errorCategory == "invalid_model_output" },
                fieldsFound: result.extractedFields.count,
                fieldsVerified: result.extractedFields.filter { !$0.needsReview || $0.userCorrected }.count,
                fieldsNeedingReview: result.extractedFields.filter { $0.needsReview && !$0.userCorrected }.count,
                unsupportedAccepted: 0,
                durationMs: result.modelInvocations.last?.durationMs,
                timeToFirstTokenMs: result.modelInvocations.last?.timeToFirstTokenMs,
                estimatedOutputTokensPerSecond: result.modelInvocations.last?.estimatedOutputTokensPerSecond,
                exportRelativePath: export?.relativePath,
                message: rossLocalized("private_assistant_sample_file_check_completed_private")
            ))
            localInferenceSmokeRunning = false
        }
    }

    func recordLocalInferenceSmokeReport(_ report: AlphaLocalInferenceSmokeReport) {
        localInferenceSmokeReport = report
        var reports = persisted.localInferenceSmokeReports ?? []
        reports.insert(report, at: 0)
        if reports.count > Self.localInferenceSmokeHistoryLimit {
            reports.removeLast(reports.count - Self.localInferenceSmokeHistoryLimit)
        }
        persisted.localInferenceSmokeReports = reports
    }

    func advanceOnboarding() {
        selectedTier = preferredSelectedAssistantTier(fallbackSelectedTier: selectedTier)
        finishPackSetup()
    }

    func importDocument(caseId: UUID?, from sourceURL: URL, openAfterImport: Bool = true) async {
        await importDocuments(caseId: caseId, from: [sourceURL], openAfterImport: openAfterImport)
    }

    func queueIncomingDocumentURL(_ url: URL) {
        guard !pendingIncomingDocumentURLs.contains(url) else { return }
        pendingIncomingDocumentURLs.append(url)
    }

    func clearIncomingDocumentQueue() {
        pendingIncomingDocumentURLs.removeAll()
    }

    func importQueuedIncomingDocuments(to caseId: UUID) {
        let urls = pendingIncomingDocumentURLs
        pendingIncomingDocumentURLs.removeAll()
        Task {
            await importDocuments(caseId: caseId, from: urls)
        }
    }

    func createMatterForQueuedIncomingDocuments(title: String) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let matter = AlphaCaseMatter(
            title: cleanedTitle.isEmpty ? rossLocalized("new_matter") : cleanedTitle,
            forum: alphaImportedSharedFilesMatterForum(),
            stage: .intake,
            summary: alphaImportedSharedFilesMatterSummary(),
            issueHighlights: [],
            evidenceNotes: [],
            draftTasks: [alphaReviewImportedFilesTaskTitle()],
            documents: [],
            sourceRefs: []
        )
        persisted.cases.insert(matter, at: 0)
        selectedCaseID = matter.id
        askSelectedScopeCaseID = matter.id
        persist(workspaceChanged: true)
        importQueuedIncomingDocuments(to: matter.id)
    }

    func importDocuments(caseId: UUID?, from sourceURLs: [URL], openAfterImport: Bool = true) async {
        let uniqueURLs = sourceURLs.reduce(into: [URL]()) { urls, url in
            guard !urls.contains(url) else { return }
            urls.append(url)
        }
        guard !uniqueURLs.isEmpty else { return }

        var importedDocumentIDs: [UUID] = []
        for (index, sourceURL) in uniqueURLs.prefix(20).enumerated() {
            if let document = await importSingleDocument(
                caseId: caseId,
                from: sourceURL,
                openAfterImport: openAfterImport && index == 0
            ) {
                importedDocumentIDs.append(document.id)
            }
        }
        if uniqueURLs.count > 20 {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: rossLocalized("document_import_batch_limit_title"),
                    detail: alphaImportBatchLimitDetail(importedLimit: 20, skippedCount: uniqueURLs.count - 20),
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: false
                ),
                at: 0
            )
        }

        let targetCaseID = caseId ?? alphaSharedWorkspaceID
        if !importedDocumentIDs.isEmpty {
            setSelectedAskDocumentIDs(Set(importedDocumentIDs), for: targetCaseID == alphaSharedWorkspaceID ? nil : targetCaseID)
            persist(workspaceChanged: true)
        }
    }

    @discardableResult
    private func importSingleDocument(caseId: UUID?, from sourceURL: URL, openAfterImport: Bool) async -> AlphaCaseDocument? {
        let targetCaseID = caseId ?? alphaSharedWorkspaceID
        do {
            let imported = try await store.importDocument(from: sourceURL, into: targetCaseID)
            guard let caseIndex = persisted.cases.firstIndex(where: { $0.id == targetCaseID }) else { return nil }
            let document = imported.document

            var caseMatter = persisted.cases[caseIndex]
            caseMatter.documents.insert(document, at: 0)
            refreshCaseWorkspace(caseMatter: &caseMatter)
            completeImportFirstDocumentTask(caseId: targetCaseID)
            caseMatter.updatedAt = .now
            if targetCaseID != alphaSharedWorkspaceID {
                selectedCaseID = targetCaseID
                askSelectedScopeCaseID = targetCaseID
                setSelectedAskDocumentIDs([document.id], for: targetCaseID)
            } else {
                setSelectedAskDocumentIDs([document.id], for: nil)
            }

            let sourceRef = AlphaSourceRef(
                caseId: targetCaseID,
                documentId: document.id,
                documentTitle: document.title,
                pageNumber: 1,
                paragraphRange: nil,
                textSnippet: document.dominantSourceSnippet ?? document.extractedText ?? alphaImportedSourceReferenceFallback(),
                ocrConfidence: document.kind == .image ? nil : 0.92
            )
            caseMatter.sourceRefs.insert(sourceRef, at: 0)
            persisted.cases[caseIndex] = caseMatter

            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Document imported locally",
                    detail: alphaImportedDocumentLedgerDetail(document.title),
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: true
                ),
                at: 0
            )
            persist(workspaceChanged: true)
            appendMatterThreadUpdate(
                caseId: targetCaseID == alphaSharedWorkspaceID ? nil : targetCaseID,
                title: rossLocalized("file_added_to_matter_title"),
                sections: [
                    alphaFileAddedToMatterSection(document.title),
                    document.hasAskUsableExtractedText
                        ? alphaImportedFileAskReadyDetail()
                        : alphaImportedFileSourceSavedDetail()
                ],
                sourceRefs: [sourceRef],
                selectedDocumentIDs: [document.id],
                selectedDocumentTitles: [document.title],
                statusNote: alphaMatterChatImportedFileStatus(hasReadableText: document.hasAskUsableExtractedText)
            )
            if openAfterImport {
                path.append(.documentViewer(targetCaseID, document.id, 1))
            }
            return document
        } catch {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: rossLocalized("document_import_failed_title"),
                    detail: (error as? LocalizedError)?.errorDescription ?? rossLocalized("document_import_copy_failed_detail"),
                    purpose: .local_only,
                    payloadClass: .local_only,
                    endpointLabel: "device://document-import",
                    success: false
                ),
                at: 0
            )
            persist()
            return nil
        }
    }

    func buildPublicLawPreview() {
        publicLawPreview = sanitizePublicLawPreview(rawQuery: publicLawDraft, caseMatter: selectedCase)
        publicLawResults = []
        publicLawSearchStatus = .reviewing
        persisted.publicLawDraft = publicLawDraft
        persisted.publicLawPreview = publicLawPreview
        persisted.publicLawResults = publicLawResults
        persist()
    }

    var activeExtractionMode: AlphaExtractionMode {
        .fromInstalledPack(activePack)
    }

    func suggestedPublicLawQuery(for caseMatter: AlphaCaseMatter?) -> String? {
        guard let caseMatter else { return nil }
        let verifiedFields = caseMatter.documents
            .flatMap(\.extractedFields)
            .filter { !$0.needsReview || $0.userCorrected }
        let legalConcepts = verifiedFields
            .filter { $0.fieldType == .issue || $0.fieldType == .orderDirection || $0.fieldType == .relief || $0.fieldType == .section }
            .flatMap { publicLawKeywords(from: $0.value) }
        let documentFocusTerms: [String] = caseMatter.documents.compactMap { document -> String? in
            guard let classification = document.classification, !classification.needsReview else { return nil }
            return publicLawFocusTerm(for: classification.type)
        }
        let calendarTerms: [String] = {
            var terms: [String] = []
            if caseMatter.nextHearing != nil || caseMatter.dates.contains(where: { $0.kind == .hearing && $0.status == .scheduled }) {
                terms.append("court procedure and hearing dates")
            }
            if caseMatter.dates.contains(where: { $0.kind == .filingDeadline && $0.status == .scheduled }) {
                terms.append("filing compliance and limitation")
            }
            return terms
        }()
        var terms = Array(NSOrderedSet(array: calendarTerms + legalConcepts + documentFocusTerms))
            .compactMap { $0 as? String }
            .filter(isSafePublicLawTerm)
        if terms.isEmpty {
            terms = ["court procedure and filing compliance"]
        }
        return "Indian public law guidance on \(Array(terms.prefix(3)).joined(separator: ", "))"
    }

    func normalizeLoadedState(_ state: AlphaPersistedState) -> AlphaPersistedState {
        var normalized = state
        let originalInstalledPacks = state.installedPacks
        let shouldPauseDownloadedAssistantAfterLaunch = alphaShouldPauseDownloadedAssistantAfterLaunch(state)
        let pausedDownloadedAssistantPack = alphaSelectedDownloadedAssistantPack(in: state)
        normalized.settings.activeTier = AlphaCapabilityTier.normalizedAssistantSelection(normalized.settings.activeTier)
        normalized.modelJobs.removeAll { $0.tier == .flash }
        normalized.installedPacks.removeAll { $0.tier == .flash }
        normalized.modelUpdateCandidates?.removeAll { $0.tier == .flash }
        if normalized.schemaVersion != AlphaCurrentPersistedStateSchemaVersion {
            normalized.schemaVersion = AlphaCurrentPersistedStateSchemaVersion
            normalized.cases = normalized.cases.map { caseMatter in
                var copy = caseMatter
                copy.chatSessions = copy.chatSessions.map { session in
                    var sessionCopy = session
                    sessionCopy.turns.removeAll {
                        $0.answerTitle.localizedCaseInsensitiveContains("drafted this from your files") ||
                        $0.answerSections.contains { section in
                            section.localizedCaseInsensitiveContains("included for this answer")
                        }
                    }
                    return sessionCopy
                }
                return copy
            }
        }
        _ = alphaPurgeAbandonedAssistantDownloadsFromDisk()
        purgeDevelopmentModelArtifactsFromDisk()
        _ = recoverDownloadedAssistantArtifacts(from: &normalized)
        if shouldPauseDownloadedAssistantAfterLaunch {
            alphaQuarantineActiveAssistantAfterStartupFailure(&normalized)
            if let pausedDownloadedAssistantPack,
               !normalized.installedPacks.contains(where: {
                   $0.packId == pausedDownloadedAssistantPack.packId &&
                       $0.runtimeMode == pausedDownloadedAssistantPack.runtimeMode &&
                       $0.artifactKind == pausedDownloadedAssistantPack.artifactKind &&
                       $0.installPath == pausedDownloadedAssistantPack.installPath
               }) {
                var pausedPack = pausedDownloadedAssistantPack
                pausedPack.isActive = false
                normalized.installedPacks.insert(pausedPack, at: 0)
            }
        } else {
            if alphaHadUnfinishedPrivateAIStartupValidation() {
                alphaQuarantineActiveAssistantAfterStartupFailure(&normalized)
            }
            alphaQuarantineIncompleteInstalledAssistantJob(&normalized)
            alphaQuarantineUnusableActiveDownloadedAssistant(&normalized)
        }
        alphaConvergeInstalledAssistantCatalog(&normalized)
        alphaConvergeAssistantUpdateCandidates(&normalized)
        alphaApplyPreferredInstalledRuntimeForSelectedTier(&normalized)
        _ = alphaPruneUnreferencedAssistantArtifactsFromDisk(
            installedPacks: normalized.installedPacks,
            lastInvocation: alphaLastModelInvocation(in: normalized)
        )
        if shouldRestoreAssistantSetupFlow(for: normalized) {
            normalized.onboardingStage = looksLikePristineWorkspace(normalized) ? .onboarding : .privateAIPack
        }
        if !normalized.cases.contains(where: { $0.id == alphaSharedWorkspaceID }) {
            normalized.cases.append(sharedWorkspaceMatter())
        }
        if normalized.tasks == nil {
            normalized.tasks = initialTasks(from: normalized.cases)
        }
        if normalized.preparedWorkItems == nil {
            normalized.preparedWorkItems = []
        }
        if normalized.routineRuns == nil {
            normalized.routineRuns = []
        }
        if normalized.routineSettings == nil {
            normalized.routineSettings = .default
        }
        if normalized.modelUpdateCandidates == nil {
            normalized.modelUpdateCandidates = []
        }
        if let incompleteInstalledJob = normalized.modelJobs.first(where: { $0.state == .installed && !$0.developmentOnly && ($0.bytesDownloaded <= 1 || $0.totalBytes <= 1) }) {
            if normalized.settings.activeTier == incompleteInstalledJob.tier {
                normalized.settings.activeTier = nil
            }
            normalized.installedPacks = normalized.installedPacks.map { pack in
                var copy = pack
                if copy.tier == incompleteInstalledJob.tier || (copy.runtimeMode == .llamaCppGguf && !copy.developmentOnly) {
                    copy.isActive = false
                }
                return copy
            }
            if normalized.installedPacks.first(where: { $0.tier == incompleteInstalledJob.tier }) == nil,
               let originalPack = originalInstalledPacks.first(where: { $0.tier == incompleteInstalledJob.tier }) {
                var pausedPack = originalPack
                pausedPack.isActive = false
                normalized.installedPacks.insert(pausedPack, at: 0)
            }
            if !normalized.ledgerEntries.contains(where: { $0.title == "Assistant paused" }) {
                normalized.ledgerEntries.insert(
                    AlphaPrivacyLedgerEntry(
                        title: "Assistant paused",
                        detail: "Ross kept the assistant setup file on this device, but stopped auto-selecting it after startup validation did not finish on the previous launch. Open My assistant to re-check setup or use Repair setup.",
                        purpose: .model_verification,
                        payloadClass: .no_case_data,
                        endpointLabel: "device://model-startup-recovery",
                        success: false
                    ),
                    at: 0
                )
            }
        }
        normalized.routineSettings?.requirePublicLawApproval = true
        normalized.settings.requirePublicLawApproval = true
        return normalized
    }

    func removeSystemAssistantShortcutState(from state: inout AlphaPersistedState) {
        state.installedPacks.removeAll { pack in
            pack.artifactKind == "system_model" ||
                pack.runtimeMode == .appleFoundationModels ||
                (!alphaAllowsDevelopmentModelArtifacts() && pack.developmentOnly)
        }
        state.modelJobs.removeAll { job in
            job.artifactKind == "system_model" ||
                (job.runtimeMode == .appleFoundationModels && (job.state == .installed || job.totalBytes == 0)) ||
                (!alphaAllowsDevelopmentModelArtifacts() && job.developmentOnly)
        }
    }

    func purgeDevelopmentModelArtifactsFromDisk() {
        guard !alphaAllowsDevelopmentModelArtifacts() else { return }
        for tier in AlphaCapabilityTier.allCases {
            let tierDirectory = alphaAbsoluteURL(for: "model-packs/\(tier.rawValue)")
            let devPack = tierDirectory.appendingPathComponent("pack.dev")
            if FileManager.default.fileExists(atPath: devPack.path()) {
                try? FileManager.default.removeItem(at: devPack)
            }
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: tierDirectory.path()),
               contents.isEmpty {
                try? FileManager.default.removeItem(at: tierDirectory)
            }
        }
    }

    func recoverDownloadedAssistantArtifacts(from state: inout AlphaPersistedState) -> Bool {
        alphaRecoverDownloadedAssistantArtifacts(from: &state)
    }

    func installedModelPackFileIsUsable(_ pack: AlphaInstalledModelPack) -> Bool {
        alphaInstalledModelPackFileIsUsable(pack)
    }

    func alphaFileByteCount(at url: URL) -> Int64 {
        alphaModelFileByteCount(at: url)
    }

    func alphaSHA256Hex(forFileAt url: URL) -> String? {
        alphaModelSHA256Hex(forFileAt: url)
    }

    func recoveredInstalledPackFromDisk(preferredTier: AlphaCapabilityTier?) -> AlphaInstalledModelPack? {
        var seenTiers = Set<AlphaCapabilityTier>()
        let tiers = ([AlphaCapabilityTier.normalizedAssistantSelection(preferredTier)].compactMap { $0 } + AlphaCapabilityTier.installableAssistantTiers).filter { tier in
            seenTiers.insert(tier).inserted
        }
        for tier in tiers {
            if let pack = recoveredInstalledPackFromDisk(tier: tier) {
                return pack
            }
        }
        return nil
    }

    func recoveredInstalledPackFromDisk(tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        alphaRecoveredInstalledPackFromDisk(
            tier: AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? .quickStart
        )
    }

    func alphaAssistantChecksumMatches(expected: String, actual: String) -> Bool {
        alphaModelAssistantChecksumMatches(expected: expected, actual: actual)
    }

    func shouldRestoreAssistantSetupFlow(for state: AlphaPersistedState) -> Bool {
        state.onboardingStage == .completed
            && state.demoProfileSubject == nil
            && state.settings.activeTier == nil
            && state.installedPacks.isEmpty
    }

    func looksLikePristineWorkspace(_ state: AlphaPersistedState) -> Bool {
        let nonSharedCases = state.cases.filter { $0.id != alphaSharedWorkspaceID }
        let hasCaseDocuments = nonSharedCases.contains { !$0.documents.isEmpty }
        let hasChatHistory = nonSharedCases.contains { !$0.chatSessions.isEmpty }
        let hasSourceRefs = nonSharedCases.contains { !$0.sourceRefs.isEmpty }
        let hasTasks = !(state.tasks ?? []).isEmpty
        let hasExports = !state.exports.isEmpty
        let hasPublicLawHistory = !state.publicLawCache.isEmpty || !((state.publicLawResults ?? []).isEmpty)
        let hasDownloadState = !state.modelJobs.isEmpty

        return nonSharedCases.isEmpty
            && !hasCaseDocuments
            && !hasChatHistory
            && !hasSourceRefs
            && !hasTasks
            && !hasExports
            && !hasPublicLawHistory
            && !hasDownloadState
    }

    func initialTasks(from cases: [AlphaCaseMatter]) -> [AlphaTaskItem] {
        cases.filter { $0.id != alphaSharedWorkspaceID }.flatMap { caseMatter in
            caseMatter.draftTasks.enumerated().map { offset, task in
                AlphaTaskItem(
                    caseId: caseMatter.id,
                    title: task,
                    dueDate: offset == 0 ? (caseMatter.nextHearing ?? Calendar.current.date(byAdding: .day, value: 2, to: .now)) : nil,
                    priority: offset == 0 ? .high : .normal,
                    source: .system
                )
            }
        }
    }

    func isRossSuggestedTask(_ task: AlphaTaskItem) -> Bool {
        task.notes?.hasPrefix(alphaRossSuggestedTaskNotePrefix) == true
    }

    func sharedWorkspaceMatter() -> AlphaCaseMatter {
        AlphaCaseMatter(
            id: alphaSharedWorkspaceID,
            title: alphaSharedWorkspaceTitle(),
            forum: alphaSharedWorkspaceForum(),
            stage: .intake,
            nextHearing: nil,
            summary: alphaSharedWorkspaceSummary(),
            issueHighlights: [alphaSharedWorkspaceIssueHighlight()],
            evidenceNotes: [alphaSharedWorkspaceEvidenceNote()],
            draftTasks: [],
            documents: [],
            sourceRefs: [],
            updatedAt: .now
        )
    }

    func recommendedOnDeviceTier() -> AlphaCapabilityTier {
        privateAISnapshot.recommendedTier
    }

    func clearCaseSelectionState(for caseID: UUID) {
        if selectedCaseID == caseID {
            selectedCaseID = cases.first(where: { $0.id != caseID })?.id
        }
        if askSelectedScopeCaseID == caseID {
            askSelectedScopeCaseID = nil
        }
        askDrafts.removeValue(forKey: caseID)
        askSelectedDocumentIDs.removeValue(forKey: caseID)
        path.removeAll { route in
            switch route {
            case .caseWorkspace(let id), .documentList(let id), .askCase(let id):
                return id == caseID
            case .documentViewer(let id, _, _):
                return id == caseID
            case .exports(let id):
                return id == caseID
            default:
                return false
            }
        }
    }
}
