package com.ross.android.alpha

import java.io.File
import java.util.UUID

data class AlphaModelPackProgress(
    val job: AlphaModelDownloadJob,
    val installedPack: AlphaInstalledPack? = null,
    val ledgerEntries: List<AlphaPrivacyLedgerEntry>,
)

object AlphaModelPackManager {
    fun totalBytesFor(tier: AlphaCapabilityTier): Long = when (tier) {
        AlphaCapabilityTier.QuickStart -> 1_200_000_000L
        AlphaCapabilityTier.CaseAssociate -> 2_800_000_000L
        AlphaCapabilityTier.SeniorDraftingSupport -> 4_600_000_000L
    }

    fun stageJob(
        tier: AlphaCapabilityTier,
        mobileAllowed: Boolean,
        existingJob: AlphaModelDownloadJob?,
        now: String,
    ): AlphaModelDownloadJob {
        val totalBytes = totalBytesFor(tier)
        val resumeBytes = existingJob?.bytesDownloaded?.coerceAtMost(totalBytes) ?: 0L
        val waitingForWifi = !mobileAllowed && tier != AlphaCapabilityTier.QuickStart
        val expectedChecksum = sha256Bytes(devArtifactBytes(tier))

        return AlphaModelDownloadJob(
            id = existingJob?.id ?: UUID.randomUUID().toString(),
            sessionId = existingJob?.sessionId ?: "mdl-${UUID.randomUUID().toString().take(8)}",
            packId = existingJob?.packId ?: "${tier.tierId}-pack",
            tier = tier,
            state = if (waitingForWifi) AlphaDownloadState.PausedWaitingForWifi else AlphaDownloadState.Downloading,
            networkPolicy = if (mobileAllowed) AlphaDownloadPolicy.MobileAllowed else AlphaDownloadPolicy.WifiOnly,
            bytesDownloaded = if (waitingForWifi) resumeBytes else maxOf(resumeBytes, totalBytes / 3),
            totalBytes = totalBytes,
            checksumSha256 = expectedChecksum,
            failureReason = null,
            createdAt = existingJob?.createdAt ?: now,
            updatedAt = now,
            completedAt = null,
        )
    }

    fun finalizeInstall(
        rootDir: File,
        job: AlphaModelDownloadJob,
        artifactBytes: ByteArray = devArtifactBytes(job.tier),
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
        val artifact = File(folder, "pack.dev").apply { writeBytes(artifactBytes) }
        val installedPack = AlphaInstalledPack(
            packId = job.packId,
            tier = job.tier,
            installRelativePath = artifact.relativeTo(rootDir).path,
            checksumSha256 = actualChecksum,
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

    internal fun devArtifactBytes(tier: AlphaCapabilityTier): ByteArray =
        buildString {
            append("Ross private alpha artifact\n")
            append("tier=")
            append(tier.tierId)
            append('\n')
            append("privacy=no-case-data\n")
        }.toByteArray()
}

private fun sha256Bytes(value: ByteArray): String =
    java.security.MessageDigest.getInstance("SHA-256")
        .digest(value)
        .joinToString("") { "%02x".format(it) }
