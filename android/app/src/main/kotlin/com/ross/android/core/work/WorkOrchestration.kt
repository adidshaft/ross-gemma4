package com.ross.android.core.work

import android.content.Context
import android.content.SharedPreferences
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.ross.android.app.RossApplication
import com.ross.android.core.domain.DeviceCapabilityWorkScheduler
import com.ross.android.core.domain.DownloadWorkScheduler
import com.ross.android.core.domain.InstantModeBannerScheduler
import com.ross.android.core.domain.ModelDownloadGateway
import com.ross.android.core.domain.ModelDownloadOrchestrator
import com.ross.android.core.domain.PrivacyLedgerService
import com.ross.android.core.domain.PrivacyLedgerWorkScheduler
import com.ross.android.core.model.DeviceCapabilityRecommendation
import com.ross.android.core.model.DeviceCapabilitySnapshot
import com.ross.android.core.model.DownloadCheckpoint
import com.ross.android.core.model.DownloadSession
import com.ross.android.core.model.LedgerLocality
import com.ross.android.core.model.PackSetupPlan
import com.ross.android.core.model.PrivacyLedgerEntry
import java.util.UUID
import java.util.concurrent.TimeUnit

interface DownloadCheckpointStore {
    fun read(sessionId: String): DownloadCheckpoint?
    fun write(checkpoint: DownloadCheckpoint)
}

class PreferencesDownloadCheckpointStore(
    context: Context,
) : DownloadCheckpointStore {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("ross-download-checkpoints", Context.MODE_PRIVATE)

    override fun read(sessionId: String): DownloadCheckpoint? {
        val totalSegments = prefs.getInt("${sessionId}_total", 0)
        if (totalSegments == 0) {
            return null
        }

        return DownloadCheckpoint(
            sessionId = sessionId,
            publicName = prefs.getString("${sessionId}_name", "") ?: "",
            completedSegments = prefs.getInt("${sessionId}_done", 0),
            totalSegments = totalSegments,
        )
    }

    override fun write(checkpoint: DownloadCheckpoint) {
        prefs.edit()
            .putString("${checkpoint.sessionId}_name", checkpoint.publicName)
            .putInt("${checkpoint.sessionId}_done", checkpoint.completedSegments)
            .putInt("${checkpoint.sessionId}_total", checkpoint.totalSegments)
            .apply()
    }
}

class WorkManagerDownloadWorkScheduler(
    private val workManager: WorkManager,
) : DownloadWorkScheduler {
    override fun enqueue(plan: PackSetupPlan): String {
        val sessionId = UUID.randomUUID().toString()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(
                if (plan.requiresWifi) NetworkType.UNMETERED else NetworkType.CONNECTED,
            )
            .build()

        val requests = (1..plan.totalSegments).map { segmentIndex ->
            OneTimeWorkRequestBuilder<ModelDownloadWorker>()
                .setConstraints(constraints)
                .setInputData(
                    workDataOf(
                        KEY_SESSION_ID to sessionId,
                        KEY_PUBLIC_NAME to plan.publicName,
                        KEY_SEGMENT_INDEX to segmentIndex,
                        KEY_TOTAL_SEGMENTS to plan.totalSegments,
                    ),
                )
                .addTag(TAG_MODEL_DOWNLOAD)
                .build()
        }

        var continuation = workManager.beginUniqueWork(
            "model-download-$sessionId",
            ExistingWorkPolicy.REPLACE,
            requests.first(),
        )
        requests.drop(1).forEach { request ->
            continuation = continuation.then(request)
        }
        continuation.enqueue()

        return sessionId
    }
}

class WorkManagerDeviceCapabilityScheduler(
    private val workManager: WorkManager,
) : DeviceCapabilityWorkScheduler {
    override fun schedule(
        snapshot: DeviceCapabilitySnapshot,
        recommendation: DeviceCapabilityRecommendation,
    ) {
        val request = OneTimeWorkRequestBuilder<DeviceCapabilityWorker>()
            .setInputData(
                workDataOf(
                    "memory_gb" to snapshot.memoryGb,
                    "free_storage_gb" to snapshot.freeStorageGb,
                    "recommended_mode" to recommendation.recommendedMode.name,
                ),
            )
            .build()

        workManager.enqueueUniqueWork(
            "device-capability-assessment",
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }
}

class WorkManagerInstantModeBannerScheduler(
    private val workManager: WorkManager,
) : InstantModeBannerScheduler {
    override fun schedule(recommendation: DeviceCapabilityRecommendation) {
        val request = PeriodicWorkRequestBuilder<InstantModeBannerWorker>(12, TimeUnit.HOURS)
            .setInputData(workDataOf("instant_mode_active" to recommendation.showInstantModeBanner))
            .build()

        workManager.enqueueUniquePeriodicWork(
            "instant-mode-banner",
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }
}

class WorkManagerPrivacyLedgerScheduler(
    private val workManager: WorkManager,
) : PrivacyLedgerWorkScheduler {
    override fun scheduleMaintenance() {
        val request = PeriodicWorkRequestBuilder<PrivacyLedgerWorker>(1, TimeUnit.DAYS).build()
        workManager.enqueueUniquePeriodicWork(
            "privacy-ledger-maintenance",
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }
}

class WorkManagerModelDownloadOrchestrator(
    private val downloadScheduler: DownloadWorkScheduler,
    private val downloadGateway: ModelDownloadGateway,
    private val ledgerService: PrivacyLedgerService,
) : ModelDownloadOrchestrator {
    private var latest: DownloadSession? = null

    override fun schedule(plan: PackSetupPlan): DownloadSession {
        val sessionId = downloadScheduler.enqueue(plan)
        val session = downloadGateway.createSession(plan, sessionId)
        latest = session
        ledgerService.record(
            PrivacyLedgerEntry(
                id = "ledger-download-$sessionId",
                title = "Protected download queued",
                detail = "Queued '${plan.publicName}' in ${plan.totalSegments} resumable segments.",
                occurredAt = "Just now",
                locality = LedgerLocality.DeviceOnly,
            ),
        )
        return session
    }

    override fun latestSession(): DownloadSession? = latest
}

class ModelDownloadWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        val sessionId = inputData.getString(KEY_SESSION_ID) ?: return Result.failure()
        val publicName = inputData.getString(KEY_PUBLIC_NAME) ?: "Private pack"
        val segmentIndex = inputData.getInt(KEY_SEGMENT_INDEX, 1)
        val totalSegments = inputData.getInt(KEY_TOTAL_SEGMENTS, 1)
        val checkpointStore = applicationContext.appContainer.downloadCheckpointStore
        val previous = checkpointStore.read(sessionId)

        checkpointStore.write(
            DownloadCheckpoint(
                sessionId = sessionId,
                publicName = publicName,
                completedSegments = segmentIndex,
                totalSegments = totalSegments,
            ),
        )

        if (previous == null || segmentIndex == totalSegments) {
            applicationContext.appContainer.privacyLedgerService.record(
                PrivacyLedgerEntry(
                    id = "ledger-download-segment-$sessionId-$segmentIndex",
                    title = if (segmentIndex == totalSegments) "Protected download finished" else "Protected download started",
                    detail = if (segmentIndex == totalSegments) {
                        "'$publicName' finished staged local setup."
                    } else {
                        "'$publicName' started segment-by-segment setup."
                    },
                    occurredAt = "Background",
                    locality = LedgerLocality.DeviceOnly,
                ),
            )
        }

        setProgressAsync(
            Data.Builder()
                .putString(KEY_SESSION_ID, sessionId)
                .putInt(KEY_SEGMENT_INDEX, segmentIndex)
                .putInt(KEY_TOTAL_SEGMENTS, totalSegments)
                .build(),
        )

        return Result.success(
            workDataOf(
                KEY_SESSION_ID to sessionId,
                KEY_SEGMENT_INDEX to segmentIndex,
                KEY_TOTAL_SEGMENTS to totalSegments,
            ),
        )
    }
}

class DeviceCapabilityWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result = Result.success()
}

class InstantModeBannerWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result = Result.success()
}

class PrivacyLedgerWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result = Result.success()
}

private val Context.appContainer
    get() = (applicationContext as RossApplication).appContainer

private const val KEY_SESSION_ID = "session_id"
private const val KEY_PUBLIC_NAME = "public_name"
private const val KEY_SEGMENT_INDEX = "segment_index"
private const val KEY_TOTAL_SEGMENTS = "total_segments"
private const val TAG_MODEL_DOWNLOAD = "protected-model-download"
