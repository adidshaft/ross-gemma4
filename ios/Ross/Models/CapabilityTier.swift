import Foundation

enum CapabilityTier: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case quickStart = "quick_start"
    case caseAssociate = "case_associate"
    case seniorDraftingSupport = "senior_drafting_support"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickStart:
            "Quick Start"
        case .caseAssociate:
            "Case Associate"
        case .seniorDraftingSupport:
            "Senior Drafting Support"
        }
    }

    var summary: String {
        switch self {
        case .quickStart:
            "Lighter private assistant for quick local review, short summaries, and faster short-turn Ask Ross work."
        case .caseAssociate:
            "Recommended private assistant for most matters, larger files, chronologies, and source-backed Ask Ross answers."
        case .seniorDraftingSupport:
            "Highest-capability private assistant for larger bundles, deeper review, and drafting support."
        }
    }

    var focusAreas: [String] {
        switch self {
        case .quickStart:
            ["Quick capture review", "Short summaries", "Faster responses for shorter prompts"]
        case .caseAssociate:
            ["Source-backed case Q&A", "Chronologies and issue review", "Orders, notices, and evidence review"]
        case .seniorDraftingSupport:
            ["Larger-bundle drafting", "Hearing notes", "Deeper bilingual drafting support"]
        }
    }

    var storageGuidance: String {
        switch self {
        case .quickStart:
            "Lightest of the three assistant downloads"
        case .caseAssociate:
            "Balanced storage and capability"
        case .seniorDraftingSupport:
            "Largest local download and footprint"
        }
    }

    var instantModeSummary: String {
        switch self {
        case .quickStart:
            "Keeps short local prompts responsive for immediate review."
        case .caseAssociate:
            "Keeps short case questions responsive while preserving source-backed answers."
        case .seniorDraftingSupport:
            "Prioritizes deeper drafting tasks over the fastest short-turn review."
        }
    }

    var supportsInstantMode: Bool {
        self != .seniorDraftingSupport
    }
}

struct TechnicalModelComponent: Identifiable, Hashable, Sendable {
    let name: String
    let purpose: String

    var id: String { name }
}

struct ModelPack: Identifiable, Hashable, Sendable {
    let tier: CapabilityTier
    let downloadSize: String
    let installedFootprint: String
    let recommendedFor: String
    let technicalDetails: [TechnicalModelComponent]

    var id: CapabilityTier { tier }
}

enum ModelDownloadPhase: String, Hashable, Sendable {
    case queued
    case scheduled
    case running
    case paused
    case completed
    case failed

    var displayTitle: String {
        switch self {
        case .queued:
            "Waiting to start"
        case .scheduled:
            "Ready to download"
        case .running:
            "Downloading..."
        case .paused:
            "Paused"
        case .completed:
            "Complete"
        case .failed:
            "Failed - tap to retry"
        }
    }
}

struct ModelDownloadJob: Identifiable, Hashable, Sendable {
    let id: UUID
    let packTier: CapabilityTier
    let plannedSize: String
    var phase: ModelDownloadPhase
    var progress: Double
    var deliveryNote: String
    var isBackgroundEligible: Bool

    init(
        id: UUID = UUID(),
        packTier: CapabilityTier,
        plannedSize: String,
        phase: ModelDownloadPhase,
        progress: Double,
        deliveryNote: String,
        isBackgroundEligible: Bool
    ) {
        self.id = id
        self.packTier = packTier
        self.plannedSize = plannedSize
        self.phase = phase
        self.progress = progress
        self.deliveryNote = deliveryNote
        self.isBackgroundEligible = isBackgroundEligible
    }
}
