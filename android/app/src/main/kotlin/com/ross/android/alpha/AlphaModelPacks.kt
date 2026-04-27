package com.ross.android.alpha

import java.io.File
import java.io.FileInputStream
import java.util.UUID

data class AlphaModelPackProgress(
    val job: AlphaModelDownloadJob,
    val installedPack: AlphaInstalledPack? = null,
    val ledgerEntries: List<AlphaPrivacyLedgerEntry>,
)

object AlphaModelPackManager {
    private data class AndroidPackDescriptor(
        val packId: String,
        val sizeBytes: Long,
        val checksumSha256: String,
    )

    private val androidProductionPacks = mapOf(
        AlphaCapabilityTier.QuickStart to AndroidPackDescriptor(
            packId = "gemma3-quick-start-mediapipe-task",
            sizeBytes = 303_950_933L,
            checksumSha256 = "0f7147f1c22eaf758b819bbf7841793e4c90096c9352cde7fbe5c631f2265ef5",
        ),
        AlphaCapabilityTier.CaseAssociate to AndroidPackDescriptor(
            packId = "gemma3-case-associate-mediapipe-task",
            sizeBytes = 554_661_246L,
            checksumSha256 = "ddfaf1210d8b4d1b812b5fadb6652999e852c8be6dd9abe353b9213a25262c10",
        ),
        AlphaCapabilityTier.SeniorDraftingSupport to AndroidPackDescriptor(
            packId = "gemma3-senior-drafting-support-mediapipe-task",
            sizeBytes = 689_308_662L,
            checksumSha256 = "036e15114d1868fc7be7ccc552fc8da2fe31d64af02b48847ff99f0185d37891",
        ),
    )

    fun totalBytesFor(tier: AlphaCapabilityTier): Long =
        androidProductionPacks.getValue(tier).sizeBytes

    fun stageJob(
        tier: AlphaCapabilityTier,
        mobileAllowed: Boolean,
        existingJob: AlphaModelDownloadJob?,
        now: String,
    ): AlphaModelDownloadJob {
        val descriptor = androidProductionPacks.getValue(tier)
        val totalBytes = descriptor.sizeBytes
        val resumeBytes = existingJob?.bytesDownloaded?.coerceAtMost(totalBytes) ?: 0L
        val waitingForWifi = false

        return AlphaModelDownloadJob(
            id = existingJob?.id ?: UUID.randomUUID().toString(),
            sessionId = existingJob?.sessionId ?: "mdl-${UUID.randomUUID().toString().take(8)}",
            packId = existingJob?.packId ?: descriptor.packId,
            tier = tier,
            state = if (waitingForWifi) AlphaDownloadState.PausedWaitingForWifi else AlphaDownloadState.Downloading,
            networkPolicy = if (mobileAllowed) AlphaDownloadPolicy.MobileAllowed else AlphaDownloadPolicy.WifiOnly,
            bytesDownloaded = resumeBytes,
            totalBytes = totalBytes,
            checksumSha256 = descriptor.checksumSha256,
            artifactKind = existingJob?.artifactKind ?: "huggingface_gated_model_artifact",
            runtimeMode = existingJob?.runtimeMode ?: AlphaPackRuntimeMode.MediapipeLlm,
            developmentOnly = existingJob?.developmentOnly ?: false,
            minimumAppVersion = existingJob?.minimumAppVersion ?: "0.1.0",
            failureReason = null,
            createdAt = existingJob?.createdAt ?: now,
            updatedAt = now,
            completedAt = null,
        )
    }

    fun finalizeInstall(
        rootDir: File,
        job: AlphaModelDownloadJob,
        artifactBytes: ByteArray,
        fileName: String? = null,
        now: String,
    ): AlphaModelPackProgress {
        val actualChecksum = sha256Bytes(artifactBytes)
        if (!matchesExpectedChecksum(job.checksumSha256, artifactBytes)) {
            val failed = job.copy(
                state = AlphaDownloadState.Failed,
                bytesDownloaded = minOf(job.bytesDownloaded, job.totalBytes),
                failureReason = "Checksum verification failed",
                updatedAt = now,
            )
            return AlphaModelPackProgress(
                job = failed,
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Private AI Pack verification failed",
                        detail = "Checksum verification failed locally, so Ross blocked installation.",
                        purpose = AlphaPrivacyPurpose.ModelVerification,
                        payloadClass = AlphaPayloadClass.NoCaseData,
                        endpointLabel = "device://model-verify",
                        success = false,
                    )
                ),
            )
        }

        val folder = File(File(rootDir, "model-packs"), job.tier.tierId).apply { mkdirs() }
        val artifact = File(folder, safeArtifactFileName(fileName, job)).apply { writeBytes(artifactBytes) }
        val installedPack = AlphaInstalledPack(
            packId = job.packId,
            tier = job.tier,
            installRelativePath = artifact.relativeTo(rootDir).path,
            checksumSha256 = actualChecksum,
            artifactKind = job.artifactKind,
            runtimeMode = job.runtimeMode,
            developmentOnly = job.developmentOnly,
            checksumVerified = true,
            minimumAppVersion = job.minimumAppVersion,
            installedAt = now,
            isActive = true,
        )
        val completedJob = job.copy(
            state = AlphaDownloadState.Installed,
            bytesDownloaded = job.totalBytes,
            updatedAt = now,
            completedAt = now,
            failureReason = null,
        )
        return AlphaModelPackProgress(
            job = completedJob,
            installedPack = installedPack,
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Private AI Pack installed",
                    detail = "Checksum and install metadata were prepared locally.",
                    purpose = AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "device://model-verify",
                    success = true,
                )
            ),
        )
    }

    fun finalizeInstallFromFile(
        rootDir: File,
        job: AlphaModelDownloadJob,
        downloadedFile: File,
        fileName: String? = null,
        now: String,
    ): AlphaModelPackProgress {
        val actualChecksum = sha256File(downloadedFile)
        if (!job.checksumSha256.equals(actualChecksum, ignoreCase = true)) {
            val failed = job.copy(
                state = AlphaDownloadState.Failed,
                bytesDownloaded = minOf(job.bytesDownloaded, job.totalBytes),
                failureReason = "Checksum verification failed",
                updatedAt = now,
            )
            return AlphaModelPackProgress(
                job = failed,
                ledgerEntries = listOf(
                    AlphaPrivacyLedgerEntry(
                        title = "Private AI Pack verification failed",
                        detail = "Checksum verification failed locally, so Ross blocked installation.",
                        purpose = AlphaPrivacyPurpose.ModelVerification,
                        payloadClass = AlphaPayloadClass.NoCaseData,
                        endpointLabel = "device://model-verify",
                        success = false,
                    )
                ),
            )
        }

        val folder = File(File(rootDir, "model-packs"), job.tier.tierId).apply { mkdirs() }
        val artifact = File(folder, safeArtifactFileName(fileName, job))
        if (artifact.exists()) artifact.delete()
        if (!downloadedFile.renameTo(artifact)) {
            downloadedFile.copyTo(artifact, overwrite = true)
            downloadedFile.delete()
        }
        val installedPack = AlphaInstalledPack(
            packId = job.packId,
            tier = job.tier,
            installRelativePath = artifact.relativeTo(rootDir).path,
            checksumSha256 = actualChecksum,
            artifactKind = job.artifactKind,
            runtimeMode = job.runtimeMode,
            developmentOnly = job.developmentOnly,
            checksumVerified = true,
            minimumAppVersion = job.minimumAppVersion,
            installedAt = now,
            isActive = true,
        )
        val completedJob = job.copy(
            state = AlphaDownloadState.Installed,
            bytesDownloaded = job.totalBytes,
            updatedAt = now,
            completedAt = now,
            failureReason = null,
        )
        return AlphaModelPackProgress(
            job = completedJob,
            installedPack = installedPack,
            ledgerEntries = listOf(
                AlphaPrivacyLedgerEntry(
                    title = "Private AI Pack installed",
                    detail = "Checksum and install metadata were prepared locally.",
                    purpose = AlphaPrivacyPurpose.ModelVerification,
                    payloadClass = AlphaPayloadClass.NoCaseData,
                    endpointLabel = "device://model-verify",
                    success = true,
                )
            ),
        )
    }

    fun matchesExpectedChecksum(expectedSha256: String, artifactBytes: ByteArray): Boolean =
        expectedSha256.equals(sha256Bytes(artifactBytes), ignoreCase = true)

    private fun safeArtifactFileName(fileName: String?, job: AlphaModelDownloadJob): String {
        val candidate = fileName
            ?.substringAfterLast('/')
            ?.substringAfterLast('\\')
            ?.replace(Regex("""[^A-Za-z0-9._-]"""), "_")
            ?.takeIf { it.isNotBlank() }
        if (candidate != null) return candidate
        return if (job.runtimeMode == AlphaPackRuntimeMode.MediapipeLlm || job.artifactKind == "external_debug_model") {
            "model.task"
        } else {
            "pack.dev"
        }
    }
}

private fun sha256Bytes(value: ByteArray): String =
    java.security.MessageDigest.getInstance("SHA-256")
        .digest(value)
        .joinToString("") { "%02x".format(it) }

private fun sha256File(file: File): String {
    val digest = java.security.MessageDigest.getInstance("SHA-256")
    FileInputStream(file).use { input ->
        val buffer = ByteArray(1024 * 1024)
        while (true) {
            val read = input.read(buffer)
            if (read <= 0) break
            digest.update(buffer, 0, read)
        }
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}
