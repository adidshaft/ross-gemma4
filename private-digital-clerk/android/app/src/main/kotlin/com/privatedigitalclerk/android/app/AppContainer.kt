package com.privatedigitalclerk.android.app

import android.content.Context
import androidx.work.WorkManager
import com.privatedigitalclerk.android.casework.InMemoryPrivacyLedgerService
import com.privatedigitalclerk.android.casework.InMemorySettingsService
import com.privatedigitalclerk.android.casework.LocalCaseWorkspaceService
import com.privatedigitalclerk.android.casework.LocalOnboardingService
import com.privatedigitalclerk.android.casework.LocalPrivateAiPackSetupService
import com.privatedigitalclerk.android.casework.LocalQuickCaptureService
import com.privatedigitalclerk.android.core.domain.DefaultDeviceCapabilityRecommender
import com.privatedigitalclerk.android.core.domain.DefaultInstantModeAdvisor
import com.privatedigitalclerk.android.core.domain.DeviceCapabilityRecommender
import com.privatedigitalclerk.android.core.domain.InstantModeAdvisor
import com.privatedigitalclerk.android.core.domain.PrivacyLedgerService
import com.privatedigitalclerk.android.core.model.DeviceCapabilitySnapshot
import com.privatedigitalclerk.android.core.work.DownloadCheckpointStore
import com.privatedigitalclerk.android.core.work.PreferencesDownloadCheckpointStore
import com.privatedigitalclerk.android.core.work.WorkManagerDeviceCapabilityScheduler
import com.privatedigitalclerk.android.core.work.WorkManagerDownloadWorkScheduler
import com.privatedigitalclerk.android.core.work.WorkManagerInstantModeBannerScheduler
import com.privatedigitalclerk.android.core.work.WorkManagerModelDownloadOrchestrator
import com.privatedigitalclerk.android.core.work.WorkManagerPrivacyLedgerScheduler
import com.privatedigitalclerk.android.network.NetworkBackedPublicLawPreviewService
import com.privatedigitalclerk.android.network.StubModelDownloadGateway
import com.privatedigitalclerk.android.network.StubPublicLawGateway

class AppContainer(context: Context) {
    private val appContext = context.applicationContext
    private val workManager = WorkManager.getInstance(appContext)
    private val publicLawGateway = StubPublicLawGateway()
    private val modelDownloadGateway = StubModelDownloadGateway()

    val privacyLedgerService: PrivacyLedgerService = InMemoryPrivacyLedgerService()
    val settingsService = InMemorySettingsService()
    val onboardingService = LocalOnboardingService()
    val packSetupService = LocalPrivateAiPackSetupService()
    val caseWorkspaceService = LocalCaseWorkspaceService()
    val quickCaptureService = LocalQuickCaptureService(privacyLedgerService)
    val publicLawPreviewService = NetworkBackedPublicLawPreviewService(
        gateway = publicLawGateway,
        ledgerService = privacyLedgerService,
    )

    val capabilityRecommender: DeviceCapabilityRecommender = DefaultDeviceCapabilityRecommender()
    val instantModeAdvisor: InstantModeAdvisor = DefaultInstantModeAdvisor()
    val downloadCheckpointStore: DownloadCheckpointStore =
        PreferencesDownloadCheckpointStore(appContext)

    val downloadWorkScheduler = WorkManagerDownloadWorkScheduler(workManager)
    val capabilityWorkScheduler = WorkManagerDeviceCapabilityScheduler(workManager)
    val instantModeBannerScheduler = WorkManagerInstantModeBannerScheduler(workManager)
    val privacyLedgerWorkScheduler = WorkManagerPrivacyLedgerScheduler(workManager)
    val downloadOrchestrator = WorkManagerModelDownloadOrchestrator(
        downloadScheduler = downloadWorkScheduler,
        downloadGateway = modelDownloadGateway,
        ledgerService = privacyLedgerService,
    )

    fun defaultDeviceSnapshot(): DeviceCapabilitySnapshot {
        return DeviceCapabilitySnapshot(
            memoryGb = 8,
            freeStorageGb = 24,
            batterySaverEnabled = false,
            prefersOfflineOnly = true,
        )
    }
}
