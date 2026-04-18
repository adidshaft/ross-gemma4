import Foundation

enum DevicePerformanceClass: String, Hashable, Sendable {
    case compact
    case balanced
    case advanced

    var title: String {
        switch self {
        case .compact:
            "Compact"
        case .balanced:
            "Balanced"
        case .advanced:
            "Advanced"
        }
    }
}

struct DeviceCapability: Hashable, Sendable {
    let deviceLabel: String
    let performanceClass: DevicePerformanceClass
    let totalMemoryGB: Int
    let freeStorageGB: Int
    let lowPowerModeEnabled: Bool
    let thermalCondition: String
    let recommendedTier: CapabilityTier
    let recommendationReason: String
    let supportsInstantMode: Bool
    let instantModeReason: String

    static let placeholder = DeviceCapability(
        deviceLabel: "This device",
        performanceClass: .balanced,
        totalMemoryGB: 8,
        freeStorageGB: 24,
        lowPowerModeEnabled: false,
        thermalCondition: "Nominal",
        recommendedTier: .caseAssociate,
        recommendationReason: "Balanced local review with room for source-backed case questions and chronologies.",
        supportsInstantMode: true,
        instantModeReason: "Short local prompts can run immediately with a lighter pack."
    )
}
