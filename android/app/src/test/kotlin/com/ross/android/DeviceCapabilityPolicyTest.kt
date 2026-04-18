package com.ross.android

import com.ross.android.core.domain.DefaultDeviceCapabilityRecommender
import com.ross.android.core.model.DeviceCapabilitySnapshot
import com.ross.android.core.model.SetupMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceCapabilityPolicyTest {
    private val recommender = DefaultDeviceCapabilityRecommender()

    @Test
    fun `low memory devices default to instant mode`() {
        val recommendation = recommender.recommend(
            DeviceCapabilitySnapshot(
                memoryGb = 4,
                freeStorageGb = 32,
                batterySaverEnabled = false,
                prefersOfflineOnly = false,
            ),
        )

        assertEquals(SetupMode.Instant, recommendation.recommendedMode)
        assertTrue(recommendation.showInstantModeBanner)
    }

    @Test
    fun `offline capable devices can recommend full local`() {
        val recommendation = recommender.recommend(
            DeviceCapabilitySnapshot(
                memoryGb = 12,
                freeStorageGb = 64,
                batterySaverEnabled = false,
                prefersOfflineOnly = true,
            ),
        )

        assertEquals(SetupMode.FullLocal, recommendation.recommendedMode)
    }
}
