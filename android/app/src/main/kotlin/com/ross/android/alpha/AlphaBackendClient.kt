package com.ross.android.alpha

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

internal class AlphaBackendClient(
    private val gson: Gson = Gson(),
    private val configuration: AlphaBackendConfiguration = AlphaBackendConfiguration(),
) {
    suspend fun fetchCatalog(state: AlphaPersistedState): AlphaBackendCatalogManifest = withContext(Dispatchers.IO) {
        val payload = AlphaPayloadShaper.buildModelCatalogPayload(state)
        val baseUrl = "${configuration.baseUrl.trimEnd('/')}/model-catalog?platform=android"
        val tierQuery = payload.requestedTier?.let { "&tier=$it" }.orEmpty()
        val request = (URL(baseUrl + tierQuery).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = configuration.timeoutMs
            readTimeout = configuration.timeoutMs
        }

        try {
            request.connect()
            if (request.responseCode !in 200..299) throw AlphaBackendError.Unavailable(request.responseCode)
            val body = request.inputStream.bufferedReader().use { it.readText() }
            gson.fromJson(body, AlphaBackendCatalogResponse::class.java).manifest.payload
        } finally {
            request.disconnect()
        }
    }

    suspend fun createDownloadSession(job: AlphaModelDownloadJob): AlphaBackendDownloadSessionPayload = withContext(Dispatchers.IO) {
        val payload = AlphaPayloadShaper.buildModelDownloadPayload(job).toRequest(configuration)
        val request = (URL("${configuration.baseUrl.trimEnd('/')}/model-download/session").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = configuration.timeoutMs
            readTimeout = configuration.timeoutMs
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }

        try {
            request.outputStream.use { it.write(gson.toJson(payload).toByteArray()) }
            if (request.responseCode !in 200..299) throw AlphaBackendError.Unavailable(request.responseCode)
            val body = request.inputStream.bufferedReader().use { it.readText() }
            gson.fromJson(body, AlphaBackendDownloadSessionResponse::class.java).downloadSession.payload
        } finally {
            request.disconnect()
        }
    }

    suspend fun searchPublicLaw(preview: AlphaPublicLawPreview): List<AlphaPublicLawResult> = withContext(Dispatchers.IO) {
        val payload = AlphaPayloadShaper.buildPublicLawPayload(preview).toRequest()
        val request = (URL("${configuration.baseUrl.trimEnd('/')}/public-law/search").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = configuration.timeoutMs
            readTimeout = configuration.timeoutMs
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        }

        try {
            request.outputStream.use { it.write(gson.toJson(payload).toByteArray()) }
            if (request.responseCode !in 200..299) throw AlphaBackendError.Unavailable(request.responseCode)
            val body = request.inputStream.bufferedReader().use { it.readText() }
            gson.fromJson(body, AlphaBackendPublicLawResponse::class.java).results.map {
                AlphaPublicLawResult(
                    title = it.title,
                    citation = it.citation,
                    snippet = it.snippet,
                    sourceName = it.source,
                )
            }
        } finally {
            request.disconnect()
        }
    }

    suspend fun downloadArtifact(
        session: AlphaBackendDownloadSessionPayload,
        onProgress: suspend (Long) -> Unit,
    ): AlphaDownloadedArtifact = withContext(Dispatchers.IO) {
        val artifactUrl = resolveArtifactUrl(session.artifact)
        val output = ByteArrayOutputStream()

        for (segment in session.artifact.segments) {
            val request = (artifactUrl.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = configuration.timeoutMs
                readTimeout = configuration.timeoutMs
                setRequestProperty("Range", segment.rangeHeader)
            }

            try {
                if (request.responseCode !in 200..299) throw AlphaBackendError.Unavailable(request.responseCode)
                BufferedInputStream(request.inputStream).use { input ->
                    val bytes = input.readBytes()
                    if (sha256(bytes) != segment.sha256.lowercase()) throw AlphaBackendError.SegmentIntegrity
                    output.write(bytes)
                    onProgress(output.size().toLong())
                }
            } finally {
                request.disconnect()
            }
        }

        val allBytes = output.toByteArray()
        if (allBytes.size.toLong() != session.artifact.sizeBytes) throw AlphaBackendError.InvalidResponse
        if (sha256(allBytes) != session.artifact.finalSha256.lowercase()) throw AlphaBackendError.FinalIntegrity

        AlphaDownloadedArtifact(allBytes, allBytes.size.toLong())
    }

    private fun resolveArtifactUrl(artifact: AlphaBackendArtifact): URL {
        val relative = artifact.downloadPath?.removePrefix("/")
        return when {
            relative != null -> URL("${configuration.baseUrl.trimEnd('/')}/$relative")
            artifact.downloadUrl.startsWith("https://downloads.example.invalid/") -> {
                URL("${configuration.baseUrl.trimEnd('/')}/${artifact.downloadUrl.removePrefix("https://downloads.example.invalid/").removePrefix("/")}")
            }
            else -> URL(artifact.downloadUrl)
        }
    }
}

internal data class AlphaBackendConfiguration(
    val baseUrl: String = System.getProperty("ross.backend.baseUrl") ?: "http://10.0.2.2:8080",
    val timeoutMs: Int = 10_000,
    val accountToken: String = "acct_alpha_ross_local",
    val deviceIdHash: String = "a1b2c3d4e5f6a7b8",
    val appVersion: String = "0.1.0",
)

internal sealed class AlphaBackendError(message: String) : IOException(message) {
    data class Unavailable(val code: Int) : AlphaBackendError("Backend unavailable with status $code")
    data object SegmentIntegrity : AlphaBackendError("Segment integrity verification failed")
    data object FinalIntegrity : AlphaBackendError("Artifact integrity verification failed")
    data object InvalidResponse : AlphaBackendError("Backend response was incomplete")
}

internal data class AlphaBackendCatalogResponse(val manifest: AlphaSignedEnvelope<AlphaBackendCatalogManifest>)
internal data class AlphaBackendDownloadSessionResponse(val downloadSession: AlphaSignedEnvelope<AlphaBackendDownloadSessionPayload>)
internal data class AlphaBackendPublicLawResponse(val results: List<AlphaBackendPublicLawResult>)

internal data class AlphaSignedEnvelope<T>(
    val signature: String,
    val payload: T,
)

internal data class AlphaBackendCatalogManifest(
    val manifestId: String,
    val platform: String,
    val issuedAt: String,
    val expiresAt: String,
    val packs: List<AlphaBackendCatalogPack>,
)

internal data class AlphaBackendCatalogPack(
    val packId: String,
    val displayName: String,
    val tier: String,
    val sizeBytes: Long,
    val technicalModels: List<String>,
    val checksumSha256: String,
    val segmentSizeBytes: Long,
    val segmentCount: Int,
    val contentType: String,
    val artifactKind: String,
    val developmentOnly: Boolean,
    val resumable: Boolean,
    val deliveryBoundary: String,
)

internal data class AlphaBackendDownloadSessionPayload(
    val sessionId: String,
    val packId: String,
    val displayName: String,
    val tier: String,
    val deliveryBoundary: String,
    val deliveryMode: String,
    val artifact: AlphaBackendArtifact,
    val issuedAt: String,
    val expiresAt: String,
)

internal data class AlphaBackendArtifact(
    val artifactId: String,
    val fileName: String,
    val contentType: String,
    val sizeBytes: Long,
    val finalSha256: String,
    val segmentSizeBytes: Long,
    val segmentCount: Int,
    val downloadPath: String?,
    val downloadUrl: String,
    val rangeUnit: String,
    val resumeStrategy: String,
    val segments: List<AlphaBackendArtifactSegment>,
)

internal data class AlphaBackendArtifactSegment(
    val index: Int,
    val startByte: Long,
    val endByteInclusive: Long,
    val sizeBytes: Long,
    val sha256: String,
    val rangeHeader: String,
)

internal data class AlphaDownloadedArtifact(
    val data: ByteArray,
    val bytes: Long,
)

internal data class AlphaBackendPublicLawResult(
    val title: String,
    val citation: String,
    val snippet: String,
    val source: String,
)

internal data class AlphaBackendModelDownloadRequest(
    val accountToken: String,
    val packId: String,
    val platform: String,
    val deviceIdHash: String,
    val appVersion: String,
)

internal data class AlphaBackendPublicLawRequest(
    val query: String,
    val jurisdiction: String,
    val language: String,
    @SerializedName("confirmedPublicPreview") val confirmedPublicPreview: Boolean,
)

private fun AlphaModelDownloadPayload.toRequest(configuration: AlphaBackendConfiguration) = AlphaBackendModelDownloadRequest(
    accountToken = configuration.accountToken,
    packId = packId,
    platform = "android",
    deviceIdHash = configuration.deviceIdHash,
    appVersion = configuration.appVersion,
)

private fun AlphaPublicLawSearchPayload.toRequest() = AlphaBackendPublicLawRequest(
    query = query,
    jurisdiction = "IN-ALL",
    language = "en",
    confirmedPublicPreview = true,
)

private fun sha256(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
