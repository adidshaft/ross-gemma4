package com.ross.android.alpha

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets.UTF_8
import java.security.KeyStore
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal interface AlphaSecretKeyProvider {
    fun getOrCreate(): SecretKey
}

internal class AndroidKeystoreAlphaSecretKeyProvider : AlphaSecretKeyProvider {
    private val alias = "ross.android.alpha.state"

    override fun getOrCreate(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = (keyStore.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.secretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }
}

internal data class AlphaEncryptedEnvelope(
    val version: Int,
    val algorithm: String,
    val ivBase64: String,
    val ciphertextBase64: String,
)

internal class AlphaEncryptedStateStore(
    private val gson: Gson,
    private val rootDir: File,
    private val aadLabel: String,
    private val secretKeyProvider: AlphaSecretKeyProvider = AndroidKeystoreAlphaSecretKeyProvider(),
    private val now: () -> String = ::nowIso,
) {
    private val encryptedStateFile = File(rootDir, "state.enc")
    private val legacyPlaintextStateFile = File(rootDir, "state.json")
    private val recoveryDir = File(rootDir, "recovery")
    private val random = SecureRandom()

    fun load(seedFactory: () -> AlphaPersistedState): AlphaPersistedState {
        ensureFolders()

        encryptedStateFile.takeIf { it.exists() }?.let { encrypted ->
            val decrypted = runCatching { decrypt(encrypted.readText()) }
                .mapCatching { json -> gson.fromJson(json, AlphaPersistedState::class.java) }
                .getOrNull()
            if (decrypted != null) {
                sanitizeLegacyPlaintext()
                return decrypted
            }

            stashCorruptEncryptedState(encrypted)

            legacyPlaintextStateFile.takeIf { it.exists() }?.let { legacy ->
                loadLegacyPlaintext(legacy)?.let { migrated ->
                    val upgraded = migrated.withStorageLedger(
                        title = "Alpha state encrypted locally",
                        detail = "Legacy alpha state was moved into encrypted app-private storage.",
                        timestamp = now(),
                    )
                    save(upgraded)
                    return upgraded
                }
            }

            val recovered = seedFactory().withStorageLedger(
                title = "Alpha state recovered locally",
                detail = "Encrypted alpha state was unreadable, so Ross reset local alpha state and kept a recovery copy in app-private storage.",
                timestamp = now(),
            )
            save(recovered)
            return recovered
        }

        legacyPlaintextStateFile.takeIf { it.exists() }?.let { legacy ->
            loadLegacyPlaintext(legacy)?.let { migrated ->
                val upgraded = migrated.withStorageLedger(
                    title = "Alpha state encrypted locally",
                    detail = "Legacy alpha state was moved into encrypted app-private storage.",
                    timestamp = now(),
                )
                save(upgraded)
                return upgraded
            }
        }

        val seed = seedFactory()
        save(seed)
        return seed
    }

    fun save(state: AlphaPersistedState) {
        ensureFolders()
        val payload = encrypt(gson.toJson(state))
        writeAtomically(encryptedStateFile, payload.toByteArray(UTF_8))
        sanitizeLegacyPlaintext()
    }

    private fun loadLegacyPlaintext(file: File): AlphaPersistedState? {
        val migrated = runCatching {
            gson.fromJson(file.readText(), AlphaPersistedState::class.java)
        }.recoverCatching {
            if (it is JsonSyntaxException) null else throw it
        }.getOrNull()
        sanitizeLegacyPlaintext()
        return migrated
    }

    private fun encrypt(json: String): String {
        val iv = ByteArray(12).also(random::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKeyProvider.getOrCreate(), GCMParameterSpec(128, iv))
        cipher.updateAAD(aad())
        val ciphertext = cipher.doFinal(json.toByteArray(UTF_8))
        return gson.toJson(
            AlphaEncryptedEnvelope(
                version = 1,
                algorithm = "AES/GCM/NoPadding",
                ivBase64 = Base64.getEncoder().encodeToString(iv),
                ciphertextBase64 = Base64.getEncoder().encodeToString(ciphertext),
            )
        )
    }

    private fun decrypt(payload: String): String {
        val envelope = gson.fromJson(payload, AlphaEncryptedEnvelope::class.java)
        require(envelope.version == 1) { "Unsupported alpha state envelope version." }
        val iv = Base64.getDecoder().decode(envelope.ivBase64)
        val ciphertext = Base64.getDecoder().decode(envelope.ciphertextBase64)
        val cipher = Cipher.getInstance(envelope.algorithm)
        cipher.init(Cipher.DECRYPT_MODE, secretKeyProvider.getOrCreate(), GCMParameterSpec(128, iv))
        cipher.updateAAD(aad())
        return cipher.doFinal(ciphertext).toString(UTF_8)
    }

    private fun aad() = "$aadLabel:ross-alpha-state:v1".toByteArray(UTF_8)

    private fun stashCorruptEncryptedState(file: File) {
        recoveryDir.mkdirs()
        val recoveryFile = File(recoveryDir, "state-${System.currentTimeMillis()}.enc.bad")
        file.copyTo(recoveryFile, overwrite = true)
        file.delete()
    }

    private fun sanitizeLegacyPlaintext() {
        if (!legacyPlaintextStateFile.exists()) return
        runCatching {
            FileOutputStream(legacyPlaintextStateFile, false).use { stream ->
                stream.write("{\"migrated\":true}".toByteArray(UTF_8))
                stream.fd.sync()
            }
        }
        legacyPlaintextStateFile.delete()
    }

    private fun writeAtomically(target: File, bytes: ByteArray) {
        val temp = File(target.parentFile, "${target.name}.tmp")
        temp.outputStream().use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        if (target.exists()) target.delete()
        temp.renameTo(target)
    }

    private fun ensureFolders() {
        rootDir.mkdirs()
        recoveryDir.mkdirs()
    }
}

internal fun AlphaPersistedState.withStorageLedger(
    title: String,
    detail: String,
    timestamp: String,
): AlphaPersistedState {
    val entry = AlphaPrivacyLedgerEntry(
        title = title,
        detail = detail,
        timestamp = timestamp,
        purpose = AlphaPrivacyPurpose.LocalOnly,
        payloadClass = AlphaPayloadClass.LocalOnly,
        endpointLabel = "device://storage",
        success = true,
    )
    return if (ledgerEntries.any { it.title == entry.title && it.detail == entry.detail }) {
        this
    } else {
        copy(ledgerEntries = listOf(entry) + ledgerEntries)
    }
}
