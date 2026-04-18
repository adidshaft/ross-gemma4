package com.ross.android.alpha

import com.google.gson.GsonBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

class AlphaStorageTest {
    private val gson = GsonBuilder().setPrettyPrinting().create()

    @Test
    fun `encrypted state store round trips and hides fake secrets`() {
        val rootDir = Files.createTempDirectory("ross-alpha-storage").toFile()
        val store = AlphaEncryptedStateStore(
            gson = gson,
            rootDir = rootDir,
            aadLabel = "com.ross.android.test",
            secretKeyProvider = TestSecretKeyProvider(),
        )
        val state = fakeSecretState()

        store.save(state)
        val restored = store.load { AlphaPersistedState() }
        val encryptedText = rootDir.resolve("state.enc").readText()

        assertEquals(state.cases.first().title, restored.cases.first().title)
        assertFalse(encryptedText.contains("Raghav Fakepriv"))
        assertFalse(encryptedText.contains("9876501234"))
        assertFalse(encryptedText.contains("fakepriv@example.com"))
        assertFalse(encryptedText.contains("FAKE/123/2026"))
        assertFalse(encryptedText.contains("blue suitcase near temple"))
    }

    @Test
    fun `legacy plaintext state migrates into encrypted store`() {
        val rootDir = Files.createTempDirectory("ross-alpha-migration").toFile()
        rootDir.mkdirs()
        val legacy = rootDir.resolve("state.json")
        legacy.writeText(gson.toJson(fakeSecretState()))
        val store = AlphaEncryptedStateStore(
            gson = gson,
            rootDir = rootDir,
            aadLabel = "com.ross.android.test",
            secretKeyProvider = TestSecretKeyProvider(),
        )

        val migrated = store.load { AlphaPersistedState() }

        assertEquals("Raghav Fakepriv", migrated.cases.first().title)
        assertTrue(rootDir.resolve("state.enc").exists())
        assertFalse("Legacy plaintext state should be removed after migration", legacy.exists())
    }

    @Test
    fun `corrupt encrypted state recovers safely`() {
        val rootDir = Files.createTempDirectory("ross-alpha-corrupt").toFile()
        rootDir.resolve("state.enc").writeText("not-json")
        val store = AlphaEncryptedStateStore(
            gson = gson,
            rootDir = rootDir,
            aadLabel = "com.ross.android.test",
            secretKeyProvider = TestSecretKeyProvider(),
        )

        val recovered = store.load { AlphaPersistedState() }
        val recoveryCopy = rootDir.resolve("recovery").listFiles().orEmpty().firstOrNull()

        assertNotNull(recoveryCopy)
        assertTrue(recovered.ledgerEntries.any { it.title == "Alpha state recovered locally" })
    }
}

private class TestSecretKeyProvider : AlphaSecretKeyProvider {
    private val secretKey: SecretKey by lazy {
        KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    }

    override fun getOrCreate(): SecretKey = secretKey
}

private fun fakeSecretState(): AlphaPersistedState {
    val case = AlphaCaseMatter(
        title = "Raghav Fakepriv",
        forum = "Forum pending",
        stage = AlphaCaseStage.Intake,
        summary = "Contact 9876501234 or fakepriv@example.com about blue suitcase near temple.",
        issueHighlights = listOf("FAKE/123/2026 should never appear in plaintext."),
        evidenceNotes = listOf("blue suitcase near temple"),
        draftTasks = listOf("Keep it local"),
        documents = listOf(
            AlphaCaseDocument(
                title = "Confidential Note",
                fileName = "confidential-note.txt",
                kind = AlphaDocumentKind.Text,
                storedRelativePath = "documents/confidential-note.txt",
                pageCount = 1,
                ocrStatus = AlphaOcrStatus.Indexed,
                extractedText = "blue suitcase near temple",
                pages = listOf(AlphaDocumentPage(pageNumber = 1, snippet = "blue suitcase near temple")),
            )
        ),
        sourceRefs = emptyList(),
    )
    return AlphaPersistedState(cases = listOf(case), ledgerEntries = emptyList())
}
