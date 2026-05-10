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
}

extension AlphaRossModel {

    func installedPack(for tier: AlphaCapabilityTier) -> AlphaInstalledModelPack? {
        persisted.installedPacks.first { pack in
            pack.tier == tier && installedModelPackFileIsUsable(pack)
        }
    }

    var activeRuntimeHealth: AlphaLocalRuntimeHealth? {
        AlphaLocalModelRuntime.runtimeHealth(
            activePack: activePack,
            requestedTier: activePack?.tier ?? persisted.settings.activeTier
        )
    }

    var lastModelInvocationRuntimeMode: String? {
        lastModelInvocation?.runtimeMode
    }

    var lastModelInvocation: AlphaLocalModelInvocation? {
        let documentInvocations = persisted.cases
            .flatMap(\.documents)
            .flatMap(\.modelInvocations)
        let chatInvocations = persisted.cases
            .flatMap(\.chatSessions)
            .flatMap(\.turns)
            .compactMap(\.modelInvocation)
        return (documentInvocations + chatInvocations)
            .max { lhs, rhs in
                (lhs.completedAt ?? lhs.startedAt) < (rhs.completedAt ?? rhs.startedAt)
            }
    }

    func pauseJob(_ job: AlphaModelDownloadJob) {
        guard job.state == .queued || job.state == .downloading else { return }
        updateJob(job.id) {
            $0.state = .pausedUser
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
        Task { await startPackDownload(for: job.tier, mobileAllowed: job.networkPolicy == .mobileAllowed) }
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
                title: "Private AI Pack removed",
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

    func activateInstalledPack(_ pack: AlphaInstalledModelPack) {
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
                $0.failureReason = "The on-device private assistant is not available on this iPhone yet. A real local model is required for legal answers."
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
                    detail: "A tiny test-only assistant file was installed for automated tests. Device setup uses private assistant files.",
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

    func downloadAssistantModelArtifact(_ artifact: AlphaAssistantModelArtifact, jobID: UUID) async throws -> URL {
        guard let url = artifact.downloadURL else {
            throw AlphaAssistantDownloadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10_800
        request.setValue("Ross-iOS/0.1 model-downloader", forHTTPHeaderField: "User-Agent")

        let taskBox = AlphaAssistantDownloadTaskBox()
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ross-\(artifact.packId)-\(UUID().uuidString)")
            .appendingPathExtension((artifact.fileName as NSString).pathExtension.isEmpty ? "gguf" : (artifact.fileName as NSString).pathExtension)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = URLSession.shared.downloadTask(with: request) { temporaryURL, response, error in
                    taskBox.progressTask?.cancel()

                    if let error {
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain,
                           nsError.code == NSURLErrorCancelled,
                           taskBox.pausedByUser {
                            continuation.resume(throwing: AlphaAssistantDownloadError.pausedByUser)
                            return
                        }

                        continuation.resume(throwing: error)
                        return
                    }

                    if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                        continuation.resume(throwing: AlphaAssistantDownloadError.httpStatus(httpResponse.statusCode))
                        return
                    }

                    guard let temporaryURL else {
                        continuation.resume(throwing: AlphaAssistantDownloadError.missingDownloadedFile)
                        return
                    }

                    do {
                        try? FileManager.default.removeItem(at: destinationURL)
                        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                taskBox.task = task
                taskBox.progressTask = Task { @MainActor in
                    var lastReceived: Int64 = -1
                    var lastExpected: Int64 = -1
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard !Task.isCancelled else { break }

                        if persisted.modelJobs.first(where: { $0.id == jobID })?.state == .pausedUser {
                            taskBox.pausedByUser = true
                            task.cancel()
                            break
                        }

                        let received = max(0, task.countOfBytesReceived)
                        let expected = task.countOfBytesExpectedToReceive
                        guard received != lastReceived || expected != lastExpected else { continue }
                        lastReceived = received
                        lastExpected = expected

                        updateJob(jobID) {
                            $0.bytesDownloaded = received
                            if expected > 0 {
                                $0.totalBytes = expected
                            }
                            $0.updatedAt = .now
                        }
                        persist()

                        if task.state == .completed {
                            break
                        }
                    }
                }
                task.resume()
            }
        } onCancel: {
            taskBox.progressTask?.cancel()
            taskBox.task?.cancel()
        }
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
                  bytes == expectedBytes,
                  let handle = try? FileHandle(forReadingFrom: fileURL) else {
                return nil
            }
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
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        let message = error.localizedDescription
        return message.isEmpty ? "Ross could not download and verify the selected private assistant." : message
    }

    func startPackDownload(for tier: AlphaCapabilityTier, mobileAllowed: Bool) async {
        let artifact = alphaAssistantModelArtifact(for: tier)
        let policy: AlphaDownloadPolicy = mobileAllowed ? .mobileAllowed : .wifiOnly
        let sessionId = "hf-\(UUID().uuidString.prefix(8))"

        let job = AlphaModelDownloadJob(
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

        upsertJob(job)
        persisted.lastModelCatalogRefresh = .now
        persisted.ledgerEntries.insert(
            AlphaPrivacyLedgerEntry(
                title: "Assistant model selected",
                detail: "\(tier.title) was selected. Ross has not read any case files.",
                purpose: .model_catalog,
                payloadClass: .no_case_data,
                endpointLabel: "model-provider://private-assistant",
                success: true
            ),
            at: 0
        )
        persist()

        updateJob(job.id) {
            $0.packId = artifact.packId
            $0.totalBytes = artifact.sizeBytes
            $0.bytesDownloaded = 0
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
                    title: "Assistant model verified",
                    detail: "\(tier.title) was already downloaded and passed checksum verification locally.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
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
            updateJob(job.id) {
                $0.state = .downloading
                $0.failureReason = nil
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant model download started",
                    detail: "Ross started downloading the selected private assistant. Case files stayed on this device.",
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant-download",
                    success: true
                ),
                at: 0
            )
            persist()

            let downloadedFileURL = try await downloadAssistantModelArtifact(artifact, jobID: job.id)
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
                expectedChecksum: artifact.sha256
            )
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
                    title: "Assistant model verified",
                    detail: "\(tier.title) finished downloading and passed checksum verification locally.",
                    purpose: .model_verification,
                    payloadClass: .no_case_data,
                    endpointLabel: "device://model-verify",
                    success: true
                ),
                at: 0
            )
            persist()
        } catch AlphaAssistantDownloadError.pausedByUser {
            persist()
        } catch {
            updateJob(job.id) {
                $0.state = .failed
                $0.failureReason = assistantDownloadFailureMessage(error)
                $0.updatedAt = .now
            }
            persisted.ledgerEntries.insert(
                AlphaPrivacyLedgerEntry(
                    title: "Assistant model download failed",
                    detail: assistantDownloadFailureMessage(error),
                    purpose: .model_download,
                    payloadClass: .no_case_data,
                    endpointLabel: "model-provider://private-assistant-download",
                    success: false
                ),
                at: 0
            )
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
            lowered.contains("current document")
        let asksForImportantDates = lowered.contains("important dates") || lowered.contains("list important dates") || lowered.contains("list dates")
        let asksForNextActions = lowered.contains("what should i do next") || lowered.contains("next actions") || lowered.contains("suggest next action") || lowered.contains("what tasks should i create") || lowered.contains("needs my attention today")
        let asksAboutAssistantSetup = lowered.contains("private assistant") ||
            lowered.contains("assistant setup") ||
            lowered.contains("setting up") ||
            lowered.contains("setup assistant") ||
            lowered.contains("before setup") ||
            lowered.contains("without setup")
        if asksAboutAssistantSetup {
            return AlphaAskResult(
                chatSessionID: nil,
                chatTurnID: nil,
                kind: .userAsk,
                question: question,
                scopeCaseID: scopeCaseID,
                scopeLabel: scopeLabel(for: scopeCaseID),
                selectedDocumentTitles: [],
                answerTitle: "Private assistant setup",
                answerSections: [
                    "Before setup, Ross can still organize matters, tasks, dates, and files on this device.",
                    "After setup, the private assistant adds stronger document review, summaries, chronologies, and answers from your files.",
                    "Open Settings, then My assistant, to choose Basic, Standard, or Advanced."
                ],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: "Private assistant",
                needsReviewWarning: nil
            )
        }
        let scopedPrimaryCase = scopeCaseID.flatMap { id in persisted.cases.first(where: { $0.id == id }) }
        let selectedDocumentTarget = selectedOrLatestAskDocument(for: scopeCaseID)
        if let target = selectedDocumentTarget,
           target.document.processingState == .readingText || target.document.processingState == .imported,
           asksForDocumentSummary || asksAboutReview {
            return AlphaAskResult(
                chatSessionID: nil,
                chatTurnID: nil,
                kind: .userAsk,
                question: question,
                scopeCaseID: scopeCaseID,
                scopeLabel: scopeLabel(for: scopeCaseID),
                selectedDocumentTitles: [target.document.title],
                answerTitle: "Ross is still reading this file",
                answerSections: [
                    "Ross is still reading \(target.document.title). You can ask about extracted pages after it finishes reading.",
                    "No public-law search was used."
                ],
                caseFileSources: [],
                publicLawPreview: nil,
                publicLawResults: [],
                statusNote: "Reading",
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

        if sections.isEmpty, !selectedDocuments.isEmpty {
            sections.append(contentsOf: selectedDocuments.prefix(3).map { option in
                option.isShared ? "\(option.title): shared across matters." : "\(option.title): included for this answer."
            })
        }

        let warnings = scopedReviewItems
        let notFound = sections.isEmpty && matchedSources.isEmpty
        let answerTitle: String
        if notFound {
            answerTitle = "I could not find this in your case files."
        } else if asksForMatterSummary {
            answerTitle = "Matter summary"
        } else if asksForDocumentSummary {
            answerTitle = "Document summary"
        } else if asksForImportantDates || asksAboutSchedule {
            answerTitle = "Important dates"
        } else if asksForNextActions {
            answerTitle = "Next actions"
        } else if asksAboutTasks {
            answerTitle = "Tasks from your files"
        } else if asksAboutReview {
            answerTitle = "Review items from your files"
        } else {
            answerTitle = "Ross drafted this from your files"
        }
        return AlphaAskResult(
            chatSessionID: nil,
            chatTurnID: nil,
            kind: .userAsk,
            question: question,
            scopeCaseID: scopeCaseID,
            scopeLabel: scopeLabel(for: scopeCaseID),
            selectedDocumentTitles: selectedDocuments.map(\.title),
            answerTitle: answerTitle,
            answerSections: notFound ? ["I could not find this in your case files."] : Array(sections.prefix(3)),
            caseFileSources: Array(matchedSources.prefix(3)),
            publicLawPreview: nil,
            publicLawResults: [],
            statusNote: notFound ? "Legal Search is off" : selectedDocuments.isEmpty ? "Answered from your files" : "Answered from selected files",
            needsReviewWarning: warnings.isEmpty ? nil : "\(alphaReviewItemCountLabel(warnings.count)) still need review."
        )
    }

    func updateJob(_ jobID: UUID, transform: (inout AlphaModelDownloadJob) -> Void) {
        guard let index = persisted.modelJobs.firstIndex(where: { $0.id == jobID }) else { return }
        transform(&persisted.modelJobs[index])
    }
}
