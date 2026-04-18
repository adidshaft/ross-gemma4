package com.ross.android.network

import com.ross.android.core.domain.ModelDownloadGateway
import com.ross.android.core.domain.PrivacyLedgerService
import com.ross.android.core.domain.PublicLawGateway
import com.ross.android.core.domain.PublicLawPreviewService
import com.ross.android.core.model.DownloadPhase
import com.ross.android.core.model.DownloadSession
import com.ross.android.core.model.LedgerLocality
import com.ross.android.core.model.PackSetupPlan
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.PublicLawPreview

class StubPublicLawGateway : PublicLawGateway {
    override fun fetchPreview(query: String): PublicLawPreview {
        val safeQuery = query.ifBlank { "open records deadline" }
        return PublicLawPreview(
            title = "Preview for $safeQuery",
            jurisdiction = "Public-law reference",
            summary = "This preview isolates statute and procedure language from the broader case workspace so legal research crosses the network boundary without client notes attached.",
            highlights = listOf(
                "Check filing or response deadlines before drafting escalation language.",
                "Prefer jurisdiction-specific triggers over broad constitutional framing on first pass.",
                "Keep factual identifiers out of outward research prompts unless strictly necessary.",
            ),
            cautionLabel = "Network boundary used: no case facts attached.",
        )
    }
}

class StubModelDownloadGateway : ModelDownloadGateway {
    override fun createSession(plan: PackSetupPlan, sessionId: String): DownloadSession {
        return DownloadSession(
            sessionId = sessionId,
            publicName = plan.publicName,
            setupMode = plan.mode,
            phase = DownloadPhase.Queued,
            progressNote = "Protected staged download queued: ${plan.readyEstimate}.",
            resumable = true,
        )
    }
}

class NetworkBackedPublicLawPreviewService(
    private val gateway: PublicLawGateway,
    private val ledgerService: PrivacyLedgerService,
) : PublicLawPreviewService {
    override fun preview(query: String): PublicLawPreview {
        val preview = gateway.fetchPreview(query)
        ledgerService.record(
            PrivacyLedgerEntry(
                id = "ledger-law-${System.currentTimeMillis()}",
                title = "Public-law preview requested",
                detail = "Sent a network-safe preview request for '${query.ifBlank { "default topic" }}'.",
                occurredAt = "Just now",
                locality = LedgerLocality.Escorted,
            ),
        )
        return preview
    }
}
