import Foundation
import Observation

@MainActor
@Observable
final class LocalSettingsStore {
    var settings: AppSettings

    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }

    func activatePack(_ tier: CapabilityTier) {
        settings.activePackTier = tier
        settings.instantModeEnabled = tier.supportsInstantMode
    }

    func resetPrivacyDefaults() {
        settings.backgroundModelDownloadsEnabled = true
        settings.wifiOnlyDownloads = true
        settings.requirePublicLawApproval = true
        settings.privateByDefault = true
    }
}
