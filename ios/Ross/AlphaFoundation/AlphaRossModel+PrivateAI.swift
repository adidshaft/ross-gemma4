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
}

struct AlphaAssistantDownloadDescriptor: Codable, Hashable, Sendable {
    let sessionId: String?
    let packId: String
    let tier: AlphaCapabilityTier
    let fileName: String
    let sizeBytes: Int64
    let checksumSha256: String
    let artifactKind: String
    let runtimeMode: AlphaPackRuntimeMode
    let developmentOnly: Bool
    let downloadURLString: String
    let verified: Bool
    let releaseReady: Bool
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
        checksumSha256: descriptor.checksumSha256,
        artifactKind: descriptor.artifactKind,
        runtimeMode: descriptor.runtimeMode,
        developmentOnly: descriptor.developmentOnly,
        downloadURLString: descriptor.downloadURLString,
        verified: descriptor.verified,
        releaseReady: descriptor.releaseReady
    )
}

func alphaAssistantDownloadDescriptorSupportsCurrentInstaller(_ descriptor: AlphaAssistantDownloadDescriptor) -> Bool {
    guard !descriptor.developmentOnly,
          descriptor.sizeBytes > 0,
          descriptor.checksumSha256.range(of: #"^[a-fA-F0-9]{64}$"#, options: .regularExpression) != nil,
          !descriptor.downloadURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return false
    }
    switch descriptor.runtimeMode {
    case .llamaCppGguf:
        return descriptor.fileName.lowercased().hasSuffix(".gguf") &&
            descriptor.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        return alphaPackagedMLXArchiveArtifact(
            fileName: descriptor.fileName,
            artifactKind: descriptor.artifactKind,
            runtimeMode: descriptor.runtimeMode
        )
    case .deterministicDev, .mediapipeLlm, .appleFoundationModels, .unavailable:
        return false
    }
}

func alphaShouldReuseInstalledAssistantPack(
    _ pack: AlphaInstalledModelPack?,
    preferredRuntimeMode: AlphaPackRuntimeMode,
    forceDownload: Bool = false
) -> Bool {
    guard let pack else { return false }
    guard !forceDownload else { return false }
    return pack.runtimeMode == preferredRuntimeMode
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
    cachedDownloads: [AlphaAssistantDownloadDescriptor]?
) -> AlphaAssistantDownloadDescriptor {
    let cachedCandidates = (cachedDownloads ?? []).filter {
        $0.tier == tier && alphaAssistantDownloadDescriptorSupportsCurrentInstaller($0)
    }
    if let preferredCached = cachedCandidates.first(where: { $0.runtimeMode == preferredRuntimeMode }) {
        return alphaReusableAssistantDownloadDescriptor(preferredCached)
    }
    if let fallbackCached = cachedCandidates.first {
        return alphaReusableAssistantDownloadDescriptor(fallbackCached)
    }
    return alphaDefaultAssistantDownloadDescriptor(for: tier)
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
        developmentOnly: artifact.developmentOnly
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
        checksumSha256: artifact.sha256,
        artifactKind: artifact.artifactKind,
        runtimeMode: artifact.runtimeMode,
        developmentOnly: artifact.developmentOnly,
        downloadURLString: artifact.downloadURLString,
        verified: artifact.verified,
        releaseReady: artifact.releaseReady
    )
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
            developmentOnly: targeted.developmentOnly
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
        developmentOnly: selected.developmentOnly
    )
}

func alphaAssistantUpdateCandidate(
    installedPack: AlphaInstalledModelPack,
    availableDescriptor: AlphaAssistantCatalogDescriptor,
    existingDismissed: AlphaModelUpdateCandidate?,
    systemAssistantAvailable: Bool? = nil
) -> AlphaModelUpdateCandidate? {
    guard !installedPack.developmentOnly,
          !installedPack.installPath.hasPrefix("system://") else {
        return nil
    }

    let preferredRuntime = alphaPreferredAssistantRuntimeMode(
        for: installedPack.tier,
        existingRuntimeMode: installedPack.runtimeMode,
        systemAssistantAvailable: systemAssistantAvailable
    )
    guard preferredRuntime != .appleFoundationModels else {
        return nil
    }

    let changed = installedPack.packId != availableDescriptor.packId ||
        (!availableDescriptor.checksumSha256.isEmpty &&
         installedPack.checksumSha256.caseInsensitiveCompare(availableDescriptor.checksumSha256) != .orderedSame)
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

func alphaBackendCatalogPackSupportsCurrentInstaller(_ pack: AlphaBackendCatalogPack) -> Bool {
    guard pack.developmentOnly == false,
          pack.sizeBytes > 0 else {
        return false
    }
    switch pack.runtimeMode {
    case .llamaCppGguf:
        return pack.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
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
    let fileName = artifact.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    switch artifact.runtimeMode {
    case .llamaCppGguf:
        return fileName.lowercased().hasSuffix(".gguf") &&
            artifact.artifactKind.localizedCaseInsensitiveContains("local_model_artifact")
    case .mlxSwiftLm:
        return alphaPackagedMLXArchiveArtifact(
            fileName: fileName,
            artifactKind: artifact.artifactKind,
            runtimeMode: artifact.runtimeMode
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
        checksumSha256: session.artifact.finalSha256.lowercased(),
        artifactKind: session.artifact.artifactKind,
        runtimeMode: session.artifact.runtimeMode,
        developmentOnly: session.artifact.developmentOnly,
        downloadURLString: resolvedURLString,
        verified: true,
        releaseReady: true
    )
}

extension AlphaRossModel {

    func installedPack(for tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        privateAISnapshot.installedPack(for: tier)
    }

    var activeRuntimeHealth: AlphaLocalRuntimeHealth? {
        privateAISnapshot.activeRuntimeHealth
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
            AlphaBackgroundModelDownloadCenter.shared.cancel(jobID: job.id) { [weak self] resumeData in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.assistantDownloadTaskBoxes[job.id]?.resumeData = resumeData
                    let resumePath: String?
                    if let resumeData {
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
        if !pack.installPath.hasPrefix("system://") {
            let fileURL = alphaAbsoluteURL(for: pack.installPath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        persisted.installedPacks.removeAll { $0.id == pack.id }
        if persisted.settings.activeTier == pack.tier {
            persisted.settings.activeTier = persisted.installedPacks.first?.tier
        }
        if !persisted.installedPacks.contains(where: \.isActive), !persisted.installedPacks.isEmpty {
            persisted.installedPacks[0].isActive = true
        }
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant removed",
                detail: "\(pack.tier.title) was removed from local storage.",
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
        if !force,
           let lastRefresh = persisted.lastModelCatalogRefresh,
           Date().timeIntervalSince(lastRefresh) < 86_400 {
            return
        }
        let installedPacks = persisted.installedPacks.filter { !$0.developmentOnly && !$0.installPath.hasPrefix("system://") }
        let dismissedCandidates = persisted.modelUpdateCandidates ?? []
        let tiers = Array(Set(installedPacks.map(\.tier)))
        let fallbackCandidates = installedPacks.compactMap { pack in
            let dismissed = dismissedCandidates.first {
                $0.tier == pack.tier &&
                    $0.availablePackId == alphaDefaultAssistantCatalogDescriptor(for: pack.tier).packId &&
                    $0.dismissedAt != nil
            }
            return alphaAssistantUpdateCandidate(
                installedPack: pack,
                availableDescriptor: alphaDefaultAssistantCatalogDescriptor(for: pack.tier),
                existingDismissed: dismissed
            )
        }

        persisted.modelUpdateCandidates = fallbackCandidates
        persisted.lastModelCatalogRefresh = .now
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
            for tier in tiers {
                let preferredRuntime = alphaPreferredAssistantRuntimeMode(
                    for: tier,
                    existingRuntimeMode: installedPacks.first(where: { $0.tier == tier })?.runtimeMode
                )
                do {
                    let manifest = try await backend.fetchCatalog(for: tier)
                    descriptorsByTier[tier] = alphaAssistantCatalogDescriptor(
                        for: tier,
                        preferredRuntimeMode: preferredRuntime,
                        compatibleOnly: true,
                        manifest: manifest
                    )
                } catch {
                    descriptorsByTier[tier] = alphaDefaultAssistantCatalogDescriptor(for: tier)
                }
            }

            let candidates = installedPacks.compactMap { pack in
                let descriptor = descriptorsByTier[pack.tier] ?? alphaDefaultAssistantCatalogDescriptor(for: pack.tier)
                let dismissed = dismissedCandidates.first {
                    $0.tier == pack.tier &&
                        $0.availablePackId == descriptor.packId &&
                        $0.dismissedAt != nil
                }
                return alphaAssistantUpdateCandidate(
                    installedPack: pack,
                    availableDescriptor: descriptor,
                    existingDismissed: dismissed
                )
            }

            await MainActor.run {
                let shouldRecordLedger = self.persisted.modelUpdateCandidates?.isEmpty != false && !candidates.isEmpty
                self.persisted.modelUpdateCandidates = candidates
                self.persisted.lastModelCatalogRefresh = .now
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
        if let pack = persisted.installedPacks.first(where: { $0.tier == tier }) {
            removeInstalledPack(pack)
        }
        persisted.modelJobs.removeAll { job in
            job.tier == tier && (job.state == .installed || job.state == .failed || job.state == .cancelled)
        }
        persisted.settings.activeTier = persisted.installedPacks.first(where: \.isActive)?.tier
        persist(workspaceChanged: true)
        await startPackDownload(for: tier, mobileAllowed: mobileAllowed)
    }

    func activateInstalledPack(_ pack: AlphaInstalledModelPack) {
        guard installedPackPassesRuntimeValidation(pack) else {
            let message = AlphaLocalModelRuntime.runtimeHealth(
                activePack: pack,
                requestedTier: pack.tier
            )?.userFacingStatus ?? rossLocalized("runtime_health_llama_needs_repair")
            persisted.modelJobs = persisted.modelJobs.map { job in
                var copy = job
                if job.tier == pack.tier, job.state == .installed {
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
            job.tier == pack.tier && job.state != .installed
        }
        persisted.settings.activeTier = pack.tier
        persist()
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

        persisted.installedPacks = persisted.installedPacks.map {
            var copy = $0
            copy.isActive = false
            return copy
        }
        persisted.installedPacks.removeAll { $0.tier == tier }
        persisted.installedPacks.insert(installed, at: 0)
        persisted.settings.activeTier = tier
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
            persisted.installedPacks.removeAll { $0.tier == tier }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
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

    func downloadAssistantModelArtifact(_ artifact: AlphaAssistantDownloadDescriptor, tier: AlphaCapabilityTier, jobID: UUID) async throws -> URL {
        alphaPurgeTemporaryAssistantDownloadFiles()
        let isRealMode = true
        if isRealMode && (artifact.downloadURLString.contains("__REPLACE_WITH_VERIFIED") || !artifact.verified || !artifact.releaseReady) {
            throw AlphaAssistantDownloadError.invalidURL
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
        let fileExtension = (artifact.fileName as NSString).pathExtension.isEmpty
            ? "gguf"
            : (artifact.fileName as NSString).pathExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ross-pending-\(tier.rawValue)")
            .appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: destinationURL)

        let persistedResumeData = try? await store.loadModelResumeData(
            relativePath: persisted.modelJobs.first(where: { $0.id == jobID })?.resumeDataRelativePath
        )
        let resumeData = taskBox.resumeData ?? persistedResumeData
        let allowsMobileData = persisted.modelJobs.first(where: { $0.id == jobID })?.networkPolicy == .mobileAllowed
        taskBox.resumeData = nil

        return try await withTaskCancellationHandler {
            do {
                let progress: AlphaBackgroundModelDownloadCenter.ProgressHandler = { [weak self] received, expected in
                    await MainActor.run {
                        guard let self else { return }
                        let expectedBytes = expected > 0 ? expected : artifact.sizeBytes
                        let minimumByteDelta = max(Int64(8 * 1024 * 1024), expectedBytes / 200)
                        let now = Date()
                        let finished = expectedBytes > 0 && received >= expectedBytes
                        let byteDelta = received - taskBox.lastPublishedProgressBytes
                        guard finished ||
                            byteDelta >= minimumByteDelta ||
                            now.timeIntervalSince(taskBox.lastPublishedProgressAt) >= 0.75 else {
                            return
                        }
                        taskBox.lastPublishedProgressBytes = max(0, received)
                        taskBox.lastPublishedProgressAt = now
                        self.updateJob(jobID) {
                            $0.bytesDownloaded = max(0, received)
                            if expected > 0 {
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
                await store.removeModelResumeData(
                    relativePath: persisted.modelJobs.first(where: { $0.id == jobID })?.resumeDataRelativePath
                )
                updateJob(jobID) {
                    $0.resumeDataRelativePath = nil
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

    func startPackDownload(for tier: AlphaCapabilityTier, mobileAllowed: Bool) async {
        await startPackDownload(for: tier, mobileAllowed: mobileAllowed, existingJobID: nil)
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
        targetPackId: String? = nil
    ) async {
        let artifact = alphaAssistantModelArtifact(for: tier)
        let preferredRuntime = alphaPreferredAssistantRuntimeMode(
            for: tier,
            existingRuntimeMode: persisted.installedPacks.first(where: { $0.tier == tier })?.runtimeMode
        )
        let fallbackDownload = alphaPreferredAssistantDownloadFallback(
            for: tier,
            preferredRuntimeMode: preferredRuntime,
            cachedDownloads: persisted.cachedAssistantDownloads
        )
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let existingJob = existingJobID.flatMap { requestedID in
            persisted.modelJobs.first { $0.id == requestedID }
        } ?? persisted.modelJobs.first { job in
            job.tier == tier &&
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
            job = existingJob
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
        if systemAssistantReadyForActivation(for: tier),
           prepareSystemAssistantPack(for: tier, jobID: job.id) {
            return
        }

        if let existingInstalled = persisted.installedPacks.first(where: { $0.tier == tier && installedModelPackFileIsUsable($0) }),
           alphaShouldReuseInstalledAssistantPack(
            existingInstalled,
            preferredRuntimeMode: preferredRuntime,
            forceDownload: forceRefreshInstalledPack
           ) {
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

        if !alphaAllowsDevelopmentModelArtifacts(),
           prepareSystemAssistantPack(for: tier, jobID: job.id) {
            return
        }

        let resolvedDownload: AlphaAssistantDownloadDescriptor
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

        if resolvedDownload.sessionId != nil,
           alphaAssistantDownloadDescriptorSupportsCurrentInstaller(resolvedDownload) {
            let cachedDescriptor = alphaReusableAssistantDownloadDescriptor(resolvedDownload)
            var cachedDownloads = persisted.cachedAssistantDownloads ?? []
            cachedDownloads.removeAll { $0.tier == tier }
            cachedDownloads.append(cachedDescriptor)
            persisted.cachedAssistantDownloads = cachedDownloads
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
            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
            persisted.installedPacks.removeAll { $0.tier == tier }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
            persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
                persisted.modelUpdateCandidates,
                for: tier
            )
            persisted.modelJobs.removeAll { $0.tier == tier && $0.state != .installed && $0.id != job.id }
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
                    detail: "\(tier.title) was already downloaded and passed local verification.",
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
        let requiredFreeSpaceGB = max(
            artifact.requiredFreeSpaceGB,
            Int(ceil(Double(resolvedDownload.sizeBytes) / 1_000_000_000)) + 1
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
            let preflight = try await preflightAssistantModelArtifact(resolvedDownload, jobID: job.id)
            let expectedChecksum = try preflight.expectedChecksum(catalogChecksum: resolvedDownload.checksumSha256)
            _ = try await probeAssistantModelRange(resolvedDownload, preflight: preflight)

            updateJob(job.id) {
                $0.state = .downloading
                $0.failureReason = nil
                $0.totalBytes = preflight.reportedBytes
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

            let downloadedFileURL = try await downloadAssistantModelArtifact(resolvedDownload, tier: tier, jobID: job.id)
            let downloadedBytes = downloadedFileSize(at: downloadedFileURL)

            guard persisted.modelJobs.first(where: { $0.id == job.id })?.state != .pausedUser else {
                return
            }

            updateJob(job.id) {
                $0.state = .verifying
                $0.bytesDownloaded = downloadedBytes > 0 ? downloadedBytes : resolvedDownload.sizeBytes
                $0.updatedAt = .now
            }
            persist()

            let installedArtifact = try await store.installDownloadedPackArtifact(
                for: tier,
                fileName: resolvedDownload.fileName,
                downloadedFileURL: downloadedFileURL,
                expectedChecksum: expectedChecksum,
                expectedBytes: preflight.reportedBytes,
                packId: resolvedDownload.packId,
                artifactKind: resolvedDownload.artifactKind,
                runtimeMode: resolvedDownload.runtimeMode,
                developmentOnly: resolvedDownload.developmentOnly
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

            persisted.installedPacks = persisted.installedPacks.map {
                var copy = $0
                copy.isActive = false
                return copy
            }
            persisted.installedPacks.removeAll { $0.tier == tier }
            persisted.installedPacks.insert(installed, at: 0)
            persisted.settings.activeTier = tier
            persisted.modelUpdateCandidates = alphaClearedAssistantUpdateCandidates(
                persisted.modelUpdateCandidates,
                for: tier
            )
            updateJob(job.id) {
                $0.state = .installed
                $0.bytesDownloaded = installedArtifact.bytes
                $0.totalBytes = installedArtifact.bytes
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
                    detail: "\(tier.title) finished downloading and passed local verification.",
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
        let activeJob = persisted.modelJobs.first { $0.tier == effective }
        let installed = persisted.installedPacks.contains { $0.tier == effective && $0.isActive }
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
