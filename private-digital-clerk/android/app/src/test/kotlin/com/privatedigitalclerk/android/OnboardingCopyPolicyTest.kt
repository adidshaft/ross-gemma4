package com.privatedigitalclerk.android

import com.privatedigitalclerk.android.core.domain.OnboardingCopyPolicy
import com.privatedigitalclerk.android.core.model.AiPackOffer
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingCopyPolicyTest {
    @Test
    fun `onboarding cards expose privacy copy rather than internal ids`() {
        val offer = AiPackOffer(
            internalPackId = "hidden_technical_pack_name",
            displayName = "Balanced counsel desk",
            promise = "Protected drafting and research.",
            diskFootprintLabel = "Moderate",
            privacyLabel = "Case-safe default.",
            suggested = true,
        )

        val card = OnboardingCopyPolicy.toCard(offer)
        val visibleCopy = "${card.title} ${card.body} ${card.storageNote} ${card.privacyNote}"

        assertTrue(card.recommended)
        assertFalse(visibleCopy.contains(offer.internalPackId))
    }
}
