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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

@discardableResult
private func alphaPurgeTemporaryAssistantDownloadFiles() -> Int64 {
    alphaSweepTemporaryAssistantDownloads()
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
                title: "Assistant download resume restarted",
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
                title: "Assistant download resume restarted",
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
        persisted.modelJobs.removeAll { $0.artifactKind == "local_model_artifact" || $0.runtimeMode == .llamaCppGguf }
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

        let candidates = persisted.installedPacks.compactMap { pack -> AlphaModelUpdateCandidate? in
            guard !pack.developmentOnly,
                  !pack.installPath.hasPrefix("system://") else { return nil }
            let artifact = alphaAssistantModelArtifact(for: pack.tier)
            let changed = pack.packId != artifact.packId ||
                (!artifact.sha256.isEmpty && pack.checksumSha256.caseInsensitiveCompare(artifact.sha256) != .orderedSame)
            guard changed else { return nil }
            let existingDismissed = persisted.modelUpdateCandidates?.first {
                $0.tier == pack.tier &&
                    $0.availablePackId == artifact.packId &&
                    $0.dismissedAt != nil
            }
            return AlphaModelUpdateCandidate(
                tier: pack.tier,
                installedPackId: pack.packId,
                availablePackId: artifact.packId,
                availableSizeBytes: artifact.sizeBytes,
                requiresWifi: true,
                dismissedAt: existingDismissed?.dismissedAt
            )
        }
        persisted.modelUpdateCandidates = candidates
        persisted.lastModelCatalogRefresh = .now
        if !candidates.isEmpty {
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant update available",
                    detail: "Ross found a newer assistant setup listing. No case files were read or sent.",
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-update-check",
                    success: true
                ),
                at: 0
            )
        }
        persist()
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
            await startPackDownload(for: candidate.tier, mobileAllowed: mobileAllowed)
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
            let message = rossLocalized("runtime_health_llama_needs_repair")
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
               copy.checksumSha256.caseInsensitiveCompare(alphaAssistantModelArtifact(for: copy.tier).sha256) == .orderedSame {
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
        guard pack.runtimeMode == .llamaCppGguf, !pack.developmentOnly else {
            return true
        }
        guard installedModelPackFileIsUsable(pack) else {
            return false
        }
        do {
            try AlphaLlamaCppProvider.validateModelCanLoad(at: alphaAbsoluteURL(for: pack.installPath).path)
            return true
        } catch {
            return false
        }
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
                        detail: "The system assistant was unavailable, so Ross will prepare a private on-device assistant without reading case files.",
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
                    detail: "Ross checked this iPhone's on-device assistant and did not send case files.",
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

    func downloadAssistantModelArtifact(_ artifact: AlphaAssistantModelArtifact, tier: AlphaCapabilityTier, jobID: UUID) async throws -> URL {
        alphaPurgeTemporaryAssistantDownloadFiles()
        let isRealMode = true
        if isRealMode && (artifact.downloadURLString.contains("__REPLACE_WITH_VERIFIED") || !artifact.verified || !artifact.releaseReady) {
            throw AlphaAssistantDownloadError.invalidURL
        }

        guard let url = artifact.downloadURL else {
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
            _ = alphaSweepTemporaryAssistantDownloads()
        }
    }

    func preflightAssistantModelArtifact(_ artifact: AlphaAssistantModelArtifact, jobID: UUID) async throws -> AlphaAssistantDownloadPreflight {
        guard let url = artifact.downloadURL else {
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

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        let preflight = try AlphaAssistantDownloadPreflight.parse(response: http, expectedBytes: artifact.sizeBytes)
        updateJob(jobID) {
            $0.totalBytes = preflight.reportedBytes
            if let checksum = artifact.sha256.isEmpty ? preflight.effectiveChecksumSha256 : artifact.sha256 {
                $0.checksumSha256 = checksum
            }
            $0.updatedAt = .now
        }
        return preflight
    }

    func probeAssistantModelRange(_ artifact: AlphaAssistantModelArtifact, preflight: AlphaAssistantDownloadPreflight) async throws -> AlphaAssistantRangeProbe {
        guard let url = artifact.downloadURL else {
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
        artifact: AlphaAssistantModelArtifact
    ) async -> (relativePath: String, checksum: String, bytes: Int64)? {
        let relativePath = "model-packs/\(tier.rawValue)/\(artifact.fileName)"
        let fileURL = alphaAbsoluteURL(for: relativePath)
        let expectedBytes = artifact.sizeBytes
        let expectedChecksum = artifact.sha256

        return await Task.detached(priority: .utility) {
            let path = fileURL.path()
            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            guard let bytes = (attributes?[.size] as? NSNumber)?.int64Value,
                  bytes == expectedBytes else {
                return nil
            }
            guard !expectedChecksum.isEmpty else {
                return (relativePath, "catalog-size:\(artifact.fileName):\(bytes)", bytes)
            }
            guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
            defer { try? handle.close() }

            var hasher = SHA256()
            do {
                while true {
                    let data = try handle.read(upToCount: 1024 * 1024)
                    guard let data, !data.isEmpty else { break }
                    hasher.update(data: data)
                }
            } catch {
                return nil
            }

            let checksum = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard checksum.caseInsensitiveCompare(expectedChecksum) == .orderedSame else {
                return nil
            }
            return (relativePath, checksum, bytes)
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

    func startPackDownload(for tier: AlphaCapabilityTier, mobileAllowed: Bool, existingJobID: UUID?) async {
        let artifact = alphaAssistantModelArtifact(for: tier)
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        if let existingInstalled = persisted.installedPacks.first(where: { $0.tier == tier && installedModelPackFileIsUsable($0) }) {
            activateInstalledPack(existingInstalled)
            return
        }
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
                packId: artifact.packId,
                tier: tier,
                state: .queued,
                networkPolicy: policy,
                bytesDownloaded: 0,
                totalBytes: artifact.sizeBytes,
                checksumSha256: artifact.sha256,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false
            )
            shouldRecordSelection = true
        }

        upsertJob(job)
        let keptResumePaths = Set(persisted.modelJobs.compactMap(\.resumeDataRelativePath))
        Task {
            await store.sweepModelResumeData(keeping: keptResumePaths)
        }
        if shouldRecordSelection {
            persisted.lastModelCatalogRefresh = .now
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant selected",
                    detail: "\(tier.title) was selected. Ross has not read any case files.",
                    purpose: .model_catalog,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant",
                    success: true
                ),
                at: 0
            )
            persist()
        }

        let isResumingPartialDownload = assistantDownloadTaskBoxes[job.id]?.resumeData != nil

        updateJob(job.id) {
            $0.packId = artifact.packId
            $0.networkPolicy = policy
            $0.totalBytes = artifact.sizeBytes
            if !isResumingPartialDownload {
                $0.bytesDownloaded = 0
                $0.resumeDataRelativePath = nil
            }
            $0.checksumSha256 = artifact.sha256
            $0.artifactKind = "local_model_artifact"
            $0.runtimeMode = .llamaCppGguf
            $0.developmentOnly = false
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

        if let existingArtifact = await verifiedExistingAssistantArtifact(for: tier, artifact: artifact) {
            do {
                try AlphaLlamaCppProvider.validateModelCanLoad(at: alphaAbsoluteURL(for: existingArtifact.relativePath).path)
            } catch {
                await store.removeDownloadedPackArtifact(relativePath: existingArtifact.relativePath)
                updateJob(job.id) {
                    $0.state = .failed
                    $0.bytesDownloaded = existingArtifact.bytes
                    $0.totalBytes = existingArtifact.bytes
                    $0.checksumSha256 = existingArtifact.checksum
                    $0.failureReason = assistantDownloadFailureMessage(error)
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
            let installed = AlphaInstalledModelPack(
                packId: artifact.packId,
                tier: tier,
                installPath: existingArtifact.relativePath,
                checksumSha256: existingArtifact.checksum,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
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
        guard availableStorageGB >= artifact.requiredFreeSpaceGB else {
            updateJob(job.id) {
                $0.state = .pausedNoStorage
                $0.failureReason = AlphaAssistantDownloadError.insufficientStorage(
                    requiredGB: artifact.requiredFreeSpaceGB,
                    availableGB: availableStorageGB
                ).errorDescription
                $0.updatedAt = .now
            }
            persist()
            return
        }

        do {
            let preflight = try await preflightAssistantModelArtifact(artifact, jobID: job.id)
            let expectedChecksum = try preflight.expectedChecksum(catalogChecksum: artifact.sha256)
            _ = try await probeAssistantModelRange(artifact, preflight: preflight)

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

            let downloadedFileURL = try await downloadAssistantModelArtifact(artifact, tier: tier, jobID: job.id)
            let downloadedBytes = downloadedFileSize(at: downloadedFileURL)

            guard persisted.modelJobs.first(where: { $0.id == job.id })?.state != .pausedUser else {
                return
            }

            updateJob(job.id) {
                $0.state = .verifying
                $0.bytesDownloaded = downloadedBytes > 0 ? downloadedBytes : artifact.sizeBytes
                $0.updatedAt = .now
            }
            persist()

            let installedArtifact = try await store.installDownloadedPackArtifact(
                for: tier,
                fileName: artifact.fileName,
                downloadedFileURL: downloadedFileURL,
                expectedChecksum: expectedChecksum,
                expectedBytes: preflight.reportedBytes
            )
            try AlphaLlamaCppProvider.validateModelCanLoad(at: alphaAbsoluteURL(for: installedArtifact.relativePath).path)
            let installed = AlphaInstalledModelPack(
                packId: artifact.packId,
                tier: tier,
                installPath: installedArtifact.relativePath,
                checksumSha256: installedArtifact.checksum,
                artifactKind: "local_model_artifact",
                runtimeMode: .llamaCppGguf,
                developmentOnly: false,
                checksumVerified: true,
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
        guard let caseMatter else {
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "No case selected.",
                "",
                "Generated locally for advocate review. Verify all citations."
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
        let documentLines = documents.map { "- \($0.title) (\($0.pageCount) pages, \($0.ocrStatus.title))" }

        func uniqueValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            Array(Set(fields.filter { $0.fieldType == type }.map(\.value))).sorted()
        }

        func sourcedValues(for type: AlphaExtractedLegalFieldType, in fields: [AlphaExtractedLegalField]) -> [String] {
            fields
                .filter { $0.fieldType == type }
                .map { field in
                    let sourceLabel = field.sourceRefs.first?.label ?? "Source pending"
                    return "- \(field.value) (\(sourceLabel))"
                }
        }

        switch kind {
        case "chronology_report":
            let chronologyLines = verifiedFields
                .filter { $0.fieldType == .date || $0.fieldType == .nextDate }
                .sorted { ($0.normalizedValue ?? $0.value) < ($1.normalizedValue ?? $1.value) }
                .map { "- \($0.label): \($0.value) (\($0.sourceRefs.first?.label ?? "Source pending"))" }
            let warningLines = unresolvedFindings.map { "- \($0.message)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "Chronology candidates",
            ] + (chronologyLines.isEmpty ? ["- No verified chronology candidates found yet."] : chronologyLines) + [
                "",
                "Review warnings",
            ] + (warningLines.isEmpty ? ["- No unresolved warnings."] : warningLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "case_note":
            let court = uniqueValues(for: .court, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let caseNumbers = uniqueValues(for: .caseNumber, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let parties = uniqueValues(for: .partyName, in: verifiedFields).joined(separator: " | ").ifEmpty("Not found")
            let dateLines = sourcedValues(for: .date, in: verifiedFields)
            let pendingLines = pendingFields.map { "- \($0.label): \($0.value)" }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "Court / case metadata",
                "Court: \(court)",
                "Case number: \(caseNumbers)",
                "Parties: \(parties)",
                "",
                "Document list",
            ] + (documentLines.isEmpty ? ["- No imported documents yet."] : documentLines) + [
                "",
                "Key dates",
            ] + (dateLines.isEmpty ? ["- No verified key dates found yet."] : dateLines) + [
                "",
                "Pending review fields",
            ] + (pendingLines.isEmpty ? ["- No pending review fields."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
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
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "Operative directions",
            ] + (directions.isEmpty ? ["- No verified operative directions found yet."] : directions) + [
                "",
                "Next date",
            ] + (nextDates.isEmpty ? ["- Not found"] : nextDates) + [
                "",
                "Compliance requirements",
            ] + (compliance.isEmpty ? ["- Review operative directions against cited source pages."] : compliance) + [
                "",
                "Please confirm",
            ] + (pendingLines.isEmpty ? ["- No pending review flags for order details."] : pendingLines) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]

        case "chat_transcript":
            let turns = caseMatter.chatSessions
                .flatMap(\.turns)
                .sorted { $0.askedAt < $1.askedAt }

            let transcriptLines = turns.flatMap { turn -> [String] in
                var lines = ["Q: \(turn.question)"]
                lines.append(contentsOf: turn.answerSections.map { "A: \($0)" })
                if !turn.sourceRefs.isEmpty {
                    lines.append("Sources: \(turn.sourceRefs.map(\.label).joined(separator: " | "))")
                }
                lines.append("")
                return lines
            }

            return [
                title,
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "Ross thread transcript",
            ] + (transcriptLines.isEmpty ? ["No chat turns are saved for this matter yet.", ""] : transcriptLines) + [
                "Generated locally for advocate review. Verify all citations."
            ]

        default:
            let notes = caseMatter.draftTasks.map { "- \($0)" }
            return [
                title,
                "Generated: \(generatedDate)",
                "Draft — please review",
                "",
                "Summary",
                caseMatter.summary,
                "",
                "Working notes",
            ] + (notes.isEmpty ? ["- No tasks yet."] : notes) + [
                "",
                "Source references",
            ] + (refs.isEmpty ? ["- No source references available yet."] : refs) + [
                "",
                "Generated locally for advocate review. Verify all citations."
            ]
        }
    }

    func assistantRuntimeDecision(selectedTier: AlphaCapabilityTier? = nil) -> AlphaAssistantRuntimeDecision {
        let selected = selectedTier ?? self.selectedTier
        let recommended = recommendedOnDeviceTier()
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
        case .flash:
            return "Ultra-fast flash setup"
        case .quickStart:
            return "Phone-optimized reading"
        case .caseAssociate:
            return "Balanced local matter review"
        case .seniorDraftingSupport:
            return "Deeper drafting and review"
        }
    }

    var recommendedAssistantDetail: String {
        let totalMemoryGB = max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let freeStorageGB = max(4, alphaAvailableStorageInGigabytes())
        let summary: String
        switch recommendedOnDeviceTier() {
        case .flash:
            summary = "Ross will use the lightest, fastest assistant for immediate short answers and basic review."
        case .quickStart:
            summary = "Ross will keep setup lighter on this phone so imports, case review, and short legal questions stay responsive."
        case .caseAssociate:
            summary = "Ross will use a balanced on-device assistant for matter summaries, chronology work, Q&A from your files, and everyday legal review."
        case .seniorDraftingSupport:
            summary = "Ross can prepare a deeper on-device assistant on this phone for longer bundles, hearing prep, and richer drafting support."
        }
        return "\(summary) (\(totalMemoryGB) GB memory · \(freeStorageGB) GB free)"
    }

    var recommendedAssistantSetupNote: String {
        switch recommendedOnDeviceTier() {
        case .flash:
            return "This will be the fastest to download and set up."
        case .quickStart:
            return "Setup stays smaller and mobile-friendly for this device."
        case .caseAssociate:
            return "This is the best default for most day-to-day legal work on phone."
        case .seniorDraftingSupport:
            return "Ross found enough room on this device for longer local drafting sessions."
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
                sections.append("Next hearing: \(nextHearing.formatted(date: .abbreviated, time: .omitted)).")
            }
            if !scopedPrimaryCase.draftTasks.isEmpty {
                sections.append("Next actions: \(scopedPrimaryCase.draftTasks.prefix(2).joined(separator: "; ")).")
            }
        }
        if asksForDocumentSummary, let target = selectedDocumentTarget {
            let visibleFields = visibleExtractedFields(caseId: target.caseMatter.id, documentId: target.document.id)
            let directionValues = visibleFields
                .filter { [.orderDirection, .issue, .relief].contains($0.fieldType) }
                .map(\.value)
            sections.append("\(target.document.title) is available in this matter.")
            if let nextDate = visibleFields.first(where: { $0.fieldType == .nextDate })?.value {
                sections.append("Next date found: \(nextDate).")
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
