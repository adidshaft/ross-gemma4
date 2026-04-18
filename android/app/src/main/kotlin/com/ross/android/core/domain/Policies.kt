package com.ross.android.core.domain

import com.ross.android.core.model.AiPackOffer
import com.ross.android.core.model.DeviceCapabilityRecommendation
import com.ross.android.core.model.DeviceCapabilitySnapshot
import com.ross.android.core.model.InstantModeBanner
import com.ross.android.core.model.OnboardingPackCard
import com.ross.android.core.model.SetupMode

class DefaultDeviceCapabilityRecommender : DeviceCapabilityRecommender {
    override fun recommend(snapshot: DeviceCapabilitySnapshot): DeviceCapabilityRecommendation {
        return when {
            snapshot.batterySaverEnabled || snapshot.memoryGb <= 6 -> DeviceCapabilityRecommendation(
                headline = "Instant mode is the safest default for this device.",
                reason = "We will keep the desk responsive, defer heavier downloads, and let you begin intakes immediately.",
                recommendedMode = SetupMode.Instant,
                suggestedOfferId = "intake-ready",
                showInstantModeBanner = true,
            )

            snapshot.prefersOfflineOnly && snapshot.freeStorageGb >= 18 -> DeviceCapabilityRecommendation(
                headline = "This device can keep the full desk local.",
                reason = "There is enough room for a deeper offline pack without exposing case notes during setup.",
                recommendedMode = SetupMode.FullLocal,
                suggestedOfferId = "full-library",
                showInstantModeBanner = false,
            )

            else -> DeviceCapabilityRecommendation(
                headline = "Balanced local setup is recommended.",
                reason = "You will have fast drafting and protected research without delaying the first case review.",
                recommendedMode = SetupMode.Balanced,
                suggestedOfferId = "balanced-counsel",
                showInstantModeBanner = false,
            )
        }
    }
}

class DefaultInstantModeAdvisor : InstantModeAdvisor {
    override fun bannerFor(recommendation: DeviceCapabilityRecommendation): InstantModeBanner? {
        if (!recommendation.showInstantModeBanner) {
            return null
        }

        return InstantModeBanner(
            title = "Instant mode is active",
            body = "Core intake, capture, and ledger tools stay available while heavier local packs finish in the background.",
            actionLabel = "Keep working",
        )
    }
}

object OnboardingCopyPolicy {
    fun toCard(offer: AiPackOffer): OnboardingPackCard {
        return OnboardingPackCard(
            offerId = offer.internalPackId,
            title = offer.displayName,
            body = offer.promise,
            storageNote = "Storage: ${offer.diskFootprintLabel}",
            privacyNote = offer.privacyLabel,
            recommended = offer.suggested,
        )
    }
}
