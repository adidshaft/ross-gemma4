package com.ross.android.alpha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.security.MessageDigest

class AlphaModelPacksTest {
    @Test
    fun `private assistant tiers use android local runtime download sizes without exposing model names`() {
        assertEquals(303_950_933L, AlphaModelPackManager.totalBytesFor(AlphaCapabilityTier.QuickStart))
        assertEquals(554_661_246L, AlphaModelPackManager.totalBytesFor(AlphaCapabilityTier.CaseAssociate))
        assertEquals(689_308_662L, AlphaModelPackManager.totalBytesFor(AlphaCapabilityTier.SeniorDraftingSupport))

        assertEquals("about 304 MB", AlphaCapabilityTier.QuickStart.downloadSizeLabel)
        assertEquals("about 555 MB", AlphaCapabilityTier.CaseAssociate.downloadSizeLabel)
        assertEquals("about 690 MB", AlphaCapabilityTier.SeniorDraftingSupport.downloadSizeLabel)

        val forbidden = Regex("Gemma 4 E2B Q4|Gemma 4 Q4|Q4|Q4|gemma_local_runtime|EmbeddingGemma|LiteRT|checksum|artifact|deterministic_dev|mediapipe_llm", RegexOption.IGNORE_CASE)
        AlphaCapabilityTier.values().forEach { tier ->
            val userFacingCopy = listOf(
                tier.title,
                tier.summary,
                tier.downloadSizeLabel,
                tier.installedSizeLabel,
                tier.compactSetupSummary,
                tier.storageNote,
                tier.bestFor,
                tier.setupTimeLabel,
                tier.extractionQuality,
            ).joinToString("\n")

            assertTrue("Technical model term leaked for ${tier.title}", !forbidden.containsMatchIn(userFacingCopy))
        }
    }

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

    @Test
    fun `real mediapipe artifact keeps task filename for runtime loading`() {
        val rootDir = Files.createTempDirectory("ross-alpha-mediapipe-pack").toFile()
        val artifactBytes = "real mediapipe task bytes".toByteArray()
        val staged = AlphaModelPackManager.stageJob(
            tier = AlphaCapabilityTier.CaseAssociate,
            mobileAllowed = true,
            existingJob = null,
            now = nowIso(),
        ).copy(
            checksumSha256 = sha256(artifactBytes),
            artifactKind = "external_debug_model",
            runtimeMode = AlphaPackRuntimeMode.MediapipeLlm,
        )

        val result = AlphaModelPackManager.finalizeInstall(
            rootDir = rootDir,
            job = staged,
            artifactBytes = artifactBytes,
            fileName = "case-associate-local-debug.task",
            now = nowIso(),
        )

        assertEquals(AlphaDownloadState.Installed, result.job.state)
        assertNotNull(result.installedPack)
        assertTrue(result.installedPack?.installRelativePath?.endsWith(".task") == true)
    }

    private fun sha256(value: ByteArray): String =
        MessageDigest.getInstance("SHA-256")
            .digest(value)
            .joinToString("") { "%02x".format(it) }
}
