package com.ross.android.app

import android.content.Context
import androidx.work.WorkManager
import com.ross.android.casework.InMemoryPrivacyLedgerService
import com.ross.android.casework.InMemorySettingsService
import com.ross.android.casework.LocalCaseWorkspaceService
import com.ross.android.casework.LocalOnboardingService
import com.ross.android.casework.LocalPrivateAiPackSetupService
import com.ross.android.casework.LocalQuickCaptureService
import com.ross.android.core.domain.DefaultDeviceCapabilityRecommender
import com.ross.android.core.domain.DefaultInstantModeAdvisor
import com.ross.android.core.domain.DeviceCapabilityRecommender
import com.ross.android.core.domain.InstantModeAdvisor
import com.ross.android.core.domain.PrivacyLedgerService
import com.ross.android.core.model.DeviceCapabilitySnapshot
import com.ross.android.core.work.DownloadCheckpointStore
import com.ross.android.core.work.PreferencesDownloadCheckpointStore
import com.ross.android.core.work.WorkManagerDeviceCapabilityScheduler
import com.ross.android.core.work.WorkManagerDownloadWorkScheduler
import com.ross.android.core.work.WorkManagerInstantModeBannerScheduler
import com.ross.android.core.work.WorkManagerModelDownloadOrchestrator
import com.ross.android.core.work.WorkManagerPrivacyLedgerScheduler
import com.ross.android.network.NetworkBackedPublicLawPreviewService
import com.ross.android.network.StubModelDownloadGateway
import com.ross.android.network.StubPublicLawGateway

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
