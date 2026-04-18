import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol DeviceCapabilityProviding {
    func currentCapability() -> DeviceCapability
}

struct DefaultDeviceCapabilityService: DeviceCapabilityProviding {
    func currentCapability() -> DeviceCapability {
        let totalMemoryGB = max(2, Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
        let freeStorageGB = max(4, availableStorageInGigabytes())
        let lowPowerModeEnabled = currentLowPowerMode()
        let thermalCondition = currentThermalCondition()

        let recommendedTier: CapabilityTier
        if lowPowerModeEnabled || totalMemoryGB <= 4 || freeStorageGB < 14 {
            recommendedTier = .quickStart
        } else if totalMemoryGB >= 12 && freeStorageGB >= 32 && thermalCondition == "Nominal" {
            recommendedTier = .seniorDraftingSupport
        } else {
            recommendedTier = .caseAssociate
        }

        let performanceClass: DevicePerformanceClass
        if totalMemoryGB <= 4 {
            performanceClass = .compact
        } else if totalMemoryGB >= 12 {
            performanceClass = .advanced
        } else {
            performanceClass = .balanced
        }

        let supportsInstantMode = !lowPowerModeEnabled && recommendedTier != .seniorDraftingSupport
        let instantModeReason: String
        if supportsInstantMode {
            instantModeReason = "Short local prompts can stay responsive on this device."
        } else if lowPowerModeEnabled {
            instantModeReason = "Instant Mode is reduced while Low Power Mode is on."
        } else {
            instantModeReason = "This device is better suited to deeper local review than the fastest short-turn mode."
        }

        return DeviceCapability(
            deviceLabel: currentDeviceLabel(),
            performanceClass: performanceClass,
            totalMemoryGB: totalMemoryGB,
            freeStorageGB: freeStorageGB,
            lowPowerModeEnabled: lowPowerModeEnabled,
            thermalCondition: thermalCondition,
            recommendedTier: recommendedTier,
            recommendationReason: recommendationReason(
                recommendedTier: recommendedTier,
                totalMemoryGB: totalMemoryGB,
                freeStorageGB: freeStorageGB
            ),
            supportsInstantMode: supportsInstantMode,
            instantModeReason: instantModeReason
        )
    }

    private func availableStorageInGigabytes() -> Int {
        let values = try? URL.homeDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        let bytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return Int(bytes / 1_073_741_824)
    }

    private func recommendationReason(
        recommendedTier: CapabilityTier,
        totalMemoryGB: Int,
        freeStorageGB: Int
    ) -> String {
        switch recommendedTier {
        case .quickStart:
            return "Recommended to keep the install light and preserve responsive local review on this device."
        case .caseAssociate:
            return "Recommended for balanced source-backed case work with \(totalMemoryGB) GB memory and \(freeStorageGB) GB free storage."
        case .seniorDraftingSupport:
            return "Recommended because this device has room for longer local drafting sessions and larger pack storage."
        }
    }

    private func currentDeviceLabel() -> String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        Host.current().localizedName ?? "This device"
        #endif
    }

    private func currentLowPowerMode() -> Bool {
        #if canImport(UIKit)
        ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        false
        #endif
    }

    private func currentThermalCondition() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            "Nominal"
        case .fair:
            "Fair"
        case .serious:
            "Serious"
        case .critical:
            "Critical"
        @unknown default:
            "Unknown"
        }
    }
}
