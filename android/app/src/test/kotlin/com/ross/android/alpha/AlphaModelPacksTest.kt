package com.ross.android.alpha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class AlphaModelPacksTest {
    @Test
    fun `large packs pause for wifi when mobile data is not allowed`() {
        val job = AlphaModelPackManager.stageJob(
            tier = AlphaCapabilityTier.CaseAssociate,
            mobileAllowed = false,
            existingJob = null,
            now = nowIso(),
        )

        assertEquals(AlphaDownloadState.PausedWaitingForWifi, job.state)
        assertEquals(AlphaDownloadPolicy.WifiOnly, job.networkPolicy)
    }

    @Test
    fun `checksum mismatch blocks install`() {
        val rootDir = Files.createTempDirectory("ross-alpha-pack").toFile()
        val staged = AlphaModelPackManager.stageJob(
            tier = AlphaCapabilityTier.QuickStart,
            mobileAllowed = true,
            existingJob = null,
            now = nowIso(),
        )

        val result = AlphaModelPackManager.finalizeInstall(
            rootDir = rootDir,
            job = staged,
            artifactBytes = "tampered".toByteArray(),
            now = nowIso(),
        )

        assertEquals(AlphaDownloadState.Failed, result.job.state)
        assertNull(result.installedPack)
        assertTrue(result.ledgerEntries.any { it.success.not() })
    }
}
