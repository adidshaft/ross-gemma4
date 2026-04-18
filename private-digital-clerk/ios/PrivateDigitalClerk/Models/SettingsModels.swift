import Foundation

struct AppSettings: Hashable, Sendable {
    var activePackTier: CapabilityTier?
    var instantModeEnabled: Bool
    var backgroundModelDownloadsEnabled: Bool
    var wifiOnlyDownloads: Bool
    var requirePublicLawApproval: Bool
    var privateByDefault: Bool
    var showTechnicalDetails: Bool

    static let defaults = AppSettings(
        activePackTier: nil,
        instantModeEnabled: true,
        backgroundModelDownloadsEnabled: true,
        wifiOnlyDownloads: true,
        requirePublicLawApproval: true,
        privateByDefault: true,
        showTechnicalDetails: false
    )
}
