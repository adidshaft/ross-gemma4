import CryptoKit
import Observation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

let alphaPrivateAIBackgroundDownloadsDetail = "Keep assistant downloads eligible to continue when Ross is backgrounded."
let alphaPrivateAIUpdateDetail = "Ross will download it with the same resumable Wi-Fi-first rules. Existing assistant setup stays until the new setup verifies."
let alphaPrivateAIStorageTitle = "Assistant storage"
let alphaPrivateAIStorageDetail = "App updates keep assistant setup files in Ross storage. A full uninstall removes the app container; iOS does not let Ross ask a question during uninstall."
let alphaPrivateAIDeleteDownloadsTitle = "Delete assistant setup files"
let alphaPrivateAIDeleteDownloadsDetail = "Keeps matters and drafts, removes local assistant setup files and resume data."
let alphaPrivateAIUpdateChecksTitle = "Check for assistant updates"
let alphaPrivateAIUpdateChecksDetail = "Ross checks assistant listings and asks before replacing assistant setup."
let alphaPrivateAIVerifiedStorageLabel = "Verified assistant setup"

struct AlphaPrivateAISettingsScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var downloadPreferencesExpanded = false

    private var visibleSetupJobs: [AlphaModelDownloadJob] {
        let activeTier = model.activePack?.tier
        let activeRuntimeReady = model.activeRuntimeHealth?.available == true
        return model.persisted.modelJobs.filter { job in
            switch job.state {
            case .queued, .downloading, .pausedWaitingForWifi, .verifying:
                return true
            case .pausedUser, .pausedNoStorage, .pausedError, .failed:
                return !activeRuntimeReady || job.tier == activeTier
            case .notStarted, .installed, .cancelled:
                return false
            }
        }
    }

    private var wifiOnlyDownloadsBinding: Binding<Bool> {
        Binding(
            get: { model.persisted.settings.wifiOnlyDownloads },
            set: { newValue in
                model.updateSettings { settings in
                    settings.wifiOnlyDownloads = newValue
                }
            }
        )
    }

    private var allowMobileDataBinding: Binding<Bool> {
        Binding(
            get: { model.persisted.settings.allowMobileDataForLargePacks },
            set: { newValue in
                model.updateSettings { settings in
                    settings.allowMobileDataForLargePacks = newValue
                }
            }
        )
    }

    private var backgroundWorkBinding: Binding<Bool> {
        Binding(
            get: { model.persisted.settings.backgroundWorkEnabled },
            set: { newValue in
                model.updateSettings { settings in
                    settings.backgroundWorkEnabled = newValue
                }
            }
        )
    }

    private var autoUpdatesBinding: Binding<Bool> {
        Binding(
            get: { model.persisted.settings.autoModelUpdateChecksEnabled },
            set: { newValue in
                model.updateSettings { settings in
                    settings.autoModelUpdateChecksEnabled = newValue
                }
                if newValue {
                    model.checkForAssistantModelUpdates(force: true)
                }
            }
        )
    }

    private var deviceCacheBinding: Binding<Bool> {
        Binding(
            get: { model.persisted.settings.deviceCacheEnabled },
            set: { newValue in
                model.updateSettings { settings in
                    settings.deviceCacheEnabled = newValue
                }
                model.persist(workspaceChanged: true)
            }
        )
    }

    var body: some View {
        let assistantStatus = alphaAssistantStatusSnapshot(model)

        ScrollView {
            RossGlassGroup(spacing: 12) {
                LazyVStack(alignment: .leading, spacing: 12) {
                RossSectionCard(
                    title: "My assistant",
                    subtitle: "Local answers need setup on this iPhone."
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(assistantStatus.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(assistantStatus.detail)
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !visibleSetupJobs.isEmpty {
                    RossSectionCard(title: "Setup") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(visibleSetupJobs) { job in
                                AlphaPrivateAIJobCard(model: model, job: job)
                            }
                        }
                    }
                }

                RossSectionCard(
                    title: "Set up on this iPhone",
                    subtitle: "Choose the option that fits the files you usually handle."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AlphaPackOffer.catalog) { offer in
                            AlphaPrivateAIOfferCard(model: model, offer: offer)
                        }
                    }
                }

                RossSectionCard(title: "Wi-Fi") {
                    DisclosureGroup(isExpanded: $downloadPreferencesExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaSettingsToggleRow(
                                title: "Use Wi-Fi for larger downloads",
                                detail: "Ross waits for Wi-Fi before downloading larger assistant setup files.",
                                isOn: wifiOnlyDownloadsBinding
                            )
                            AlphaSettingsToggleRow(
                                title: "Allow mobile data",
                                detail: "Only use cellular data for assistant setup when you choose to.",
                                isOn: allowMobileDataBinding
                            )
                            AlphaSettingsToggleRow(
                                title: "Background downloads",
                                detail: alphaPrivateAIBackgroundDownloadsDetail,
                                isOn: backgroundWorkBinding
                            )
                            AlphaSettingsToggleRow(
                                title: alphaPrivateAIUpdateChecksTitle,
                                detail: alphaPrivateAIUpdateChecksDetail,
                                isOn: autoUpdatesBinding
                            )
                            AlphaSettingsToggleRow(
                                title: "Device cache",
                                detail: "Keep local workspace indexes on this device so Ross opens faster.",
                                isOn: deviceCacheBinding
                            )
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(label: "Network", value: model.persisted.settings.allowMobileDataForLargePacks ? "Wi-Fi or mobile data" : "Wi-Fi preferred")
                    }
                    .tint(Color.rossAccent)
                }

                if let update = (model.persisted.modelUpdateCandidates ?? []).first(where: { $0.dismissedAt == nil }) {
                    RossSectionCard(title: "Assistant update") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(update.tier.title) has a newer assistant setup available.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(alphaPrivateAIUpdateDetail)
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                            RossGlassGroup(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button("Update on Wi-Fi") {
                                        model.startAssistantModelUpdate(update, mobileAllowed: false)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)

                                    Button("Dismiss") {
                                        model.dismissAssistantModelUpdate(update)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16, expandsHorizontally: false)
                                }
                            }
                        }
                    }
                }

                RossSectionCard(title: alphaPrivateAIStorageTitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaAssistantStorageFootprintRow(model: model)
                        Text(alphaPrivateAIStorageDetail)
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(role: .destructive) {
                            model.removeAllDownloadedModelFiles()
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.rossHighlight)
                                    .frame(width: 30, height: 30)
                                    .rossNativeGlassSurface(
                                        tint: Color.rossHighlight.opacity(0.24),
                                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                                        interactive: true,
                                        fallbackFillOpacity: 0.84,
                                        fallbackStrokeOpacity: 0.48
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(alphaPrivateAIDeleteDownloadsTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rossHighlight)
                                    Text(alphaPrivateAIDeleteDownloadsDetail)
                                        .font(.caption)
                                        .foregroundStyle(Color.rossInk.opacity(0.68))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .rossGlassSurface(
                                tint: Color.rossHighlight.opacity(0.16),
                                cornerRadius: 16,
                                interactive: true,
                                shadowOpacity: 0.05,
                                shadowRadius: 5,
                                shadowY: 2,
                                fillOpacity: 0.78,
                                strokeOpacity: 0.46
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                    AlphaSamplerSettingsCard(model: model)
                    AlphaPrivateAITechnicalDiagnosticsCard(model: model)
                }
            }
            .padding(alphaScreenPadding)
        }
        .navigationTitle("My assistant")
        .rossInlineNavigationTitle()
    }
}

struct AlphaPrivateAITechnicalDiagnosticsCard: View {
    @Bindable var model: AlphaRossModel

    private var assistantCheckStatus: String {
        guard let runtimeHealth = model.activeRuntimeHealth else {
            return "Ross will check the assistant after setup."
        }
        if runtimeHealth.available {
            return "Ready for private answers on this iPhone."
        }
        return runtimeHealth.userFacingStatus
    }

    private var assistantLastUsedLabel: String {
        guard let lastInvocation = model.lastModelInvocation else {
            return "No private answer recorded yet"
        }
        if let completedAt = lastInvocation.completedAt {
            return completedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Started but did not finish"
    }

    var body: some View {
        RossSectionCard(title: "Assistant check") {
            VStack(alignment: .leading, spacing: 12) {
                AlphaSettingsValueRow(label: "Status", value: assistantCheckStatus)
                Divider()
                AlphaSettingsValueRow(
                    label: "Local file",
                    value: alphaAssistantVerificationSummary(
                        runtimeHealth: model.activeRuntimeHealth,
                        activePack: model.activePack
                    )
                )
                Divider()
                AlphaSettingsValueRow(label: "Last private answer", value: assistantLastUsedLabel)
                Divider()
                AlphaSettingsValueRow(label: "Setup resets", value: "\(model.privateAISnapshot.resetCount)")

                #if DEBUG
                DisclosureGroup("Support details") {
                    AlphaPrivateAIInternalDiagnostics(model: model)
                }
                .tint(Color.rossAccent)
                #endif
            }
        }
    }
}

func alphaAssistantVerificationSummary(
    runtimeHealth: AlphaLocalRuntimeHealth?,
    activePack: AlphaInstalledModelPack?
) -> String {
    guard let activePack else {
        return "No assistant setup is active yet."
    }
    if activePack.developmentOnly {
        return alphaAllowsDevelopmentModelArtifacts()
            ? "Test assistant setup is active for this build."
            : "Test assistant setup is disabled for this build."
    }
    guard let runtimeHealth else {
        return "Ross will verify assistant setup after setup finishes."
    }
    if runtimeHealth.available && runtimeHealth.checksumVerified {
        return "Assistant setup opened and verified on this iPhone."
    }
    if runtimeHealth.available {
        return "Assistant setup opened on this iPhone."
    }
    if runtimeHealth.modelPathPresent {
        return "Assistant setup needs Repair setup before Ross can use it."
    }
    return "Assistant setup is missing. Open My assistant and set up again."
}

#if DEBUG
private struct AlphaPrivateAIInternalDiagnostics: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.privateAISnapshot.installedPacks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.privateAISnapshot.installedPacks) { pack in
                        AlphaPrivateAIInstalledPackCard(model: model, pack: pack)
                    }
                }
                Divider()
            }

            if let runtimeHealth = model.activeRuntimeHealth {
                let lastInvocation = model.lastModelInvocation
                let lastPreview = model.persisted.publicLawPreview
                let resetCount = model.privateAISnapshot.resetCount

                AlphaSettingsValueRow(label: "Runtime mode", value: runtimeHealth.runtimeMode.rawValue)
                AlphaSettingsValueRow(label: "Artifact kind", value: model.activePack?.artifactKind ?? "Missing")
                AlphaSettingsValueRow(label: "Checksum verified", value: runtimeHealth.checksumVerified ? "Yes" : "No")
                AlphaSettingsValueRow(label: "Runtime available", value: runtimeHealth.available ? "Yes" : "No")
                AlphaSettingsValueRow(label: "Model path", value: runtimeHealth.modelPathPresent ? "Configured" : "Missing")

                if let activePack = model.activePack {
                    let artifact = alphaAssistantModelArtifact(for: activePack.tier)
                    AlphaSettingsValueRow(label: "Technical model", value: artifact.displayName)
                    AlphaSettingsValueRow(label: "Repository", value: artifact.repository)
                    AlphaSettingsValueRow(label: "File", value: artifact.fileName)
                    AlphaSettingsValueRow(label: "Quantization", value: artifact.quantization)
                    AlphaSettingsValueRow(label: "Checksum", value: artifact.sha256)
                }

                if let modelPathLabel = runtimeHealth.modelPathLabel {
                    AlphaSettingsValueRow(label: "Model file", value: modelPathLabel)
                }
                if let lastErrorCategory = runtimeHealth.lastErrorCategory {
                    AlphaSettingsValueRow(label: "Last error", value: lastErrorCategory)
                }
                if let lastInvocationRuntimeMode = model.lastModelInvocationRuntimeMode {
                    AlphaSettingsValueRow(label: "Last runtime", value: lastInvocationRuntimeMode)
                }
                if let lastInvocation {
                    AlphaSettingsValueRow(label: "Last task", value: lastInvocation.task.rawValue)
                    AlphaSettingsValueRow(label: "Last status", value: lastInvocation.status.rawValue)
                    AlphaSettingsValueRow(label: "Prompt hash", value: lastInvocation.promptHash)
                    AlphaSettingsValueRow(label: "Input hash", value: lastInvocation.inputHash)
                    if let outputHash = lastInvocation.outputHash {
                        AlphaSettingsValueRow(label: "Output hash", value: outputHash)
                    }
                    if let estimatedInputTokens = lastInvocation.estimatedInputTokens {
                        AlphaSettingsValueRow(label: "Estimated input tokens", value: "\(estimatedInputTokens)")
                    }
                    if let estimatedOutputTokens = lastInvocation.estimatedOutputTokens {
                        AlphaSettingsValueRow(label: "Estimated output tokens", value: "\(estimatedOutputTokens)")
                    }
                    if let durationMs = lastInvocation.durationMs {
                        let tokenTotal = (lastInvocation.estimatedInputTokens ?? 0) + (lastInvocation.estimatedOutputTokens ?? 0)
                        let tokensPerSecond = durationMs > 0 ? Double(tokenTotal) / (Double(durationMs) / 1_000) : 0
                        AlphaSettingsValueRow(label: "Last duration", value: "\(durationMs) ms")
                        AlphaSettingsValueRow(label: "Approx speed", value: String(format: "%.1f tok/s", tokensPerSecond))
                    }
                } else {
                    AlphaSettingsValueRow(label: "Last local inference", value: "No model invocation recorded yet")
                }
                if let lastPreview {
                    AlphaSettingsValueRow(label: "Last public-law query", value: lastPreview.query)
                    AlphaSettingsValueRow(label: "Sanitizer removals", value: "\(lastPreview.removed.count)")
                } else {
                    AlphaSettingsValueRow(label: "Last public-law query", value: "None")
                }
                AlphaSettingsValueRow(label: "Workspace resets", value: "\(resetCount)")
            } else {
                AlphaSettingsValueRow(label: "Runtime", value: "Not checked yet")
            }

            Button(model.localInferenceSmokeRunning ? "Running local inference smoke..." : "Run local inference smoke") {
                model.runLocalInferenceSmoke()
            }
            .rossGlassButtonStyle(tint: Color.rossAccent)
            .disabled(model.localInferenceSmokeRunning)
        }
        .padding(.top, 12)
    }
}
#endif

struct AlphaPrivacyLedgerScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    RossSectionCard(title: "Privacy summary") {
                    Text("In the last 30 days, 0 case details left this phone. Legal Search only used sanitized legal queries.")
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if model.persisted.ledgerEntries.isEmpty {
                    RossSectionCard {
                        Text("Ross has not logged any local or network actions yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                } else {
                    ForEach(model.persisted.ledgerEntries) { entry in
                        RossSectionCard(title: entry.lawyerTitle, subtitle: entry.lawyerDetail) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(entry.lawyerPurposeLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.rossInk.opacity(0.68))

                                Spacer(minLength: 8)

                                Text(entry.success ? "Completed" : "Needs attention")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(entry.success ? Color.rossSuccess : .orange)
                            }
                        }
                    }
                }
                }
                .padding(alphaScreenPadding)
            }
        }
        .navigationTitle("Activity Log")
        .rossInlineNavigationTitle()
    }
}

struct AlphaSettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
        }
        .tint(Color.rossAccent)
        .padding(.horizontal, 12)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.10),
            cornerRadius: 16,
            interactive: true,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1,
            fillOpacity: 0.74,
            strokeOpacity: 0.44
        )
    }
}

struct AlphaPrivateAIOfferCard: View {
    @Bindable var model: AlphaRossModel
    let offer: AlphaPackOffer

    private var latestJob: AlphaModelDownloadJob? {
        model.persisted.modelJobs.first { $0.tier == offer.tier }
    }

    private var installedPack: AlphaInstalledModelPack? {
        model.installedPack(for: offer.tier)
    }

    private var isActive: Bool {
        guard let activePack = model.activePack else { return false }
        return activePack.tier == offer.tier &&
            (!activePack.developmentOnly || alphaAllowsDevelopmentModelArtifacts()) &&
            model.activeRuntimeHealth?.available == true
    }

    private var activeButRuntimeUnavailable: Bool {
        guard let activePack = model.activePack else { return false }
        return activePack.tier == offer.tier &&
            (!activePack.developmentOnly || !alphaAllowsDevelopmentModelArtifacts()) &&
            model.activeRuntimeHealth?.available != true
    }

    private var isInstalledButInactive: Bool {
        installedPack != nil && !isActive && !activeButRuntimeUnavailable
    }

    private var isSettingUp: Bool {
        if installedPack != nil {
            return false
        }
        guard let latestJob else { return false }
        switch latestJob.state {
        case .queued, .downloading, .verifying, .pausedWaitingForWifi:
            return true
        case .notStarted, .pausedUser, .pausedNoStorage, .pausedError, .installed, .failed, .cancelled:
            return false
        }
    }

    private var canResume: Bool {
        if installedPack != nil {
            return false
        }
        guard let latestJob else { return false }
        switch latestJob.state {
        case .pausedUser, .pausedError, .pausedNoStorage, .failed:
            return true
        case .notStarted, .queued, .downloading, .pausedWaitingForWifi, .verifying, .installed, .cancelled:
            return false
        }
    }

    private var statusBadge: (String, Color)? {
        if isActive {
            return ("Active", Color.rossSuccess)
        }
        if activeButRuntimeUnavailable {
            return ("Needs attention", .orange)
        }
        if isInstalledButInactive {
            return ("Ready", Color.rossSuccess)
        }
        if isSettingUp {
            return ("Setting up", Color.rossAccent)
        }
        if canResume {
            return ("Needs retry", .orange)
        }
        if offer.tier == model.recommendedOnDeviceTier() {
            return ("Recommended", Color.rossAccent)
        }
        return nil
    }

    private var actionTitle: String {
        if isActive {
            return "Using this option"
        }
        if activeButRuntimeUnavailable {
            return "Repair setup"
        }
        if isInstalledButInactive {
            return "Use this option"
        }
        if isSettingUp {
            return "Setting up"
        }
        if canResume {
            return "Resume setup"
        }
        return "Set up this option"
    }

    private var actionDisabled: Bool {
        isActive || isSettingUp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(offer.tier.setupTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if let statusBadge {
                        AlphaPrivateAIInlineBadge(title: statusBadge.0, tint: statusBadge.1)
                    }

                    Spacer(minLength: 0)
                }

                Text(offer.tier.summary)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                AlphaAssistantSetupMetaLabels(
                    sizeLabel: offer.tier.downloadSizeLabel,
                    freeSpaceLabel: model.freeDiskSpaceLabel,
                    font: .caption2.weight(.medium)
                )
                .padding(.top, 2)
            }

            if let latestJob,
               (latestJob.state == .failed || latestJob.state == .pausedError || latestJob.state == .pausedNoStorage),
               let failureReason = latestJob.failureReason {
                Text(failureReason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let recoveryHint = alphaAssistantSetupRecoveryHint(for: latestJob.state) {
                    AlphaPrivateAIRecoveryHintRow(text: recoveryHint)
                }
            } else if activeButRuntimeUnavailable, let runtimeStatus = model.activeRuntimeHealth?.userFacingStatus {
                Text(runtimeStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                AlphaPrivateAIRecoveryHintRow(
                    text: "Repair setup removes the broken assistant setup and starts a fresh local check."
                )
            }

            Button(actionTitle) {
                Task {
                    if activeButRuntimeUnavailable {
                        await model.repairAssistantPack(
                            for: offer.tier,
                            mobileAllowed: model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart
                        )
                    } else if let installedPack {
                        model.activateInstalledPack(installedPack)
                    } else if let latestJob, canResume {
                        model.resumeJob(latestJob)
                    } else {
                        await model.startPackDownload(
                            for: offer.tier,
                            mobileAllowed: model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart
                        )
                    }
                }
            }
            .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14)
            .disabled(actionDisabled)
        }
        .padding(10)
        .rossGlassSurface(
            tint: isActive ? Color.rossAccent : Color.rossInk.opacity(0.42),
            cornerRadius: 16,
            shadowOpacity: isActive ? 0.12 : 0.07,
            shadowRadius: isActive ? 10 : 7,
            shadowY: isActive ? 4 : 3,
            fillOpacity: 0.82,
            strokeOpacity: isActive ? 0.58 : 0.42
        )
    }
}

struct AlphaPrivateAIRecoveryHintRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.rossAccent)
                .padding(.top, 1)

            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .rossGlassSurface(
            tint: Color.rossAccent.opacity(0.10),
            cornerRadius: 14,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1,
            fillOpacity: 0.74,
            strokeOpacity: 0.44
        )
    }
}

struct AlphaPrivateAIJobCard: View {
    @Bindable var model: AlphaRossModel
    let job: AlphaModelDownloadJob

    private var canPause: Bool {
        job.state == .queued || job.state == .downloading
    }

    private var canResume: Bool {
        job.state == .pausedUser ||
            job.state == .pausedWaitingForWifi ||
            job.state == .pausedNoStorage ||
            job.state == .pausedError ||
            job.state == .failed
    }

    private var downloadedBytesLabel: String? {
        guard job.totalBytes > 0, job.progress > 0 else { return nil }
        let downloaded = Int64(Double(job.totalBytes) * job.progress)
        let dl = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
        let tot = ByteCountFormatter.string(fromByteCount: job.totalBytes, countStyle: .file)
        return "\(dl) of \(tot)"
    }

    private var etaLabel: String? {
        guard job.state == .downloading, job.totalBytes > 0, job.progress > 0 else { return nil }
        let remaining = max(0, 1 - job.progress)
        let assumedBytesPerSec: Double = 12_000_000 // conservative 12 MB/s on Wi-Fi
        let seconds = Double(job.totalBytes) * remaining / assumedBytesPerSec
        if seconds < 90 {
            return "About \(max(1, Int(seconds))) sec left"
        } else if seconds < 3600 {
            return "About \(Int(ceil(seconds / 60))) min left"
        } else {
            return "About \(Int(ceil(seconds / 3600))) hr left"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(job.tier.setupTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaAssistantStateLabel(job.state))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }

                Spacer(minLength: 8)

                AlphaPrivateAIInlineBadge(
                    title: alphaAssistantStateLabel(job.state),
                    tint: (job.state == .failed || job.state == .pausedError) ? .orange : Color.rossAccent
                )
            }

            // Detail
            Text(alphaAssistantActivityDetail(for: job.state))
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)

            RossPhaseStepIndicator(
                phases: alphaAssistantSetupPhases,
                currentPhase: alphaAssistantSetupPhaseIndex(for: job.state)
            )
            .padding(.vertical, 2)
            .accessibilityLabel(alphaAssistantSetupPhaseAccessibilityLabel(for: job.state))

            if let failureReason = job.failureReason,
               job.state == .failed || job.state == .pausedError || job.state == .pausedNoStorage {
                Text(failureReason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                if let recoveryHint = alphaAssistantSetupRecoveryHint(for: job.state) {
                    AlphaPrivateAIRecoveryHintRow(text: recoveryHint)
                }
            }

            // Progress
            if let progressValue = alphaDownloadProgressValue(job) {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.rossAccent.opacity(0.12))
                                .frame(height: 7)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.rossAccent.opacity(0.80), Color.rossAccent],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(7, geo.size.width * CGFloat(progressValue)), height: 7)
                                .shadow(color: Color.rossAccent.opacity(0.35), radius: 4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressValue)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        if let bytesLabel = downloadedBytesLabel {
                            Text(bytesLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.55))
                        }
                        Spacer(minLength: 8)
                        if let eta = etaLabel {
                            Text(eta)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.rossAccent.opacity(0.80))
                        } else if let estimateLabel = alphaDownloadEstimateLabel(job) {
                            Text(estimateLabel)
                                .font(.caption2)
                                .foregroundStyle(Color.rossInk.opacity(0.50))
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            } else if alphaDownloadShowsIndeterminateProgress(job) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.rossAccent)
                    Text(alphaAssistantStateLabel(job.state))
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                }
                .accessibilityElement(children: .combine)
            }

            // Actions
            if canPause || canResume {
                RossGlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        if canPause {
                            Button("Pause") { model.pauseJob(job) }
                                .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16)
                        }
                        if canResume {
                            Button(job.state == .failed ? "Retry" : "Resume") { model.resumeJob(job) }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                        }
                    }
                }
            }

            // Wi-Fi advisory during active download
            if job.state == .downloading || job.state == .queued {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.36))
                    Text("Stay on Wi-Fi — the download resumes automatically if interrupted.")
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.44))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .rossGlassSurface(cornerRadius: 18, interactive: true, strokeOpacity: 0.68)
    }
}


struct AlphaPrivateAIInstalledPackCard: View {
    @Bindable var model: AlphaRossModel
    let pack: AlphaInstalledModelPack

    private var canActivate: Bool {
        !pack.developmentOnly || alphaAllowsDevelopmentModelArtifacts()
    }

    private var developmentPackIsUsable: Bool {
        pack.developmentOnly && alphaAllowsDevelopmentModelArtifacts()
    }

    private var runtimeUnavailable: Bool {
        pack.isActive &&
            !pack.developmentOnly &&
            model.activeRuntimeHealth?.available != true
    }

    private var isReady: Bool {
        !runtimeUnavailable && (!pack.developmentOnly || developmentPackIsUsable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.tier.title)
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)

                    Text(isReady ? "My assistant is ready" : "My assistant needs attention")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isReady ? Color.rossSuccess : Color.orange)
                }

                Spacer(minLength: 8)

                AlphaPrivateAIInlineBadge(title: isReady ? "Ready" : "Needs attention", tint: isReady ? Color.rossSuccess : Color.orange)
            }

            if runtimeUnavailable, let runtimeStatus = model.activeRuntimeHealth?.userFacingStatus {
                Text(runtimeStatus)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RossGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    Button("Use this option") {
                        model.activateInstalledPack(pack)
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                    .disabled(!canActivate)

                    Button("Remove", role: .destructive) {
                        model.removeInstalledPack(pack)
                    }
                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16)
                }
            }
        }
        .padding(14)
        .rossGlassSurface(
            tint: isReady ? Color.rossSuccess : Color.orange,
            cornerRadius: 18,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.48
        )
    }
}

struct AlphaPrivateAIInlineBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .rossNativeGlassSurface(
                tint: tint,
                shape: Capsule(),
                fallbackFillOpacity: 0.68,
                fallbackStrokeOpacity: 0.36
            )
    }
}

func alphaDownloadEstimateLabel(_ job: AlphaModelDownloadJob) -> String? {
    switch job.state {
    case .downloading:
        guard job.totalBytes > 0 else { return "Ross will update the estimate once the download starts moving." }
        let remainingFraction = max(0, min(1, 1 - job.progress))
        let baselineMinutes: Double
        switch job.tier {
        case .flash:
            baselineMinutes = 1
        case .quickStart:
            baselineMinutes = 2
        case .caseAssociate:
            baselineMinutes = 4
        case .seniorDraftingSupport:
            baselineMinutes = 7
        }
        let remainingMinutes = max(1, Int(ceil(baselineMinutes * remainingFraction)))
        return "Setting up. About \(remainingMinutes) min left on good Wi-Fi."
    case .verifying:
        return "Final check usually takes less than a minute."
    default:
        return nil
    }
}

let alphaAssistantSetupPhases = ["Download", "Check", "Ready"]

func alphaAssistantSetupPhaseIndex(for state: AlphaDownloadState) -> Int {
    switch state {
    case .queued, .downloading, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .failed, .notStarted, .cancelled:
        return 0
    case .verifying:
        return 1
    case .installed:
        return 2
    }
}

func alphaAssistantSetupPhaseAccessibilityLabel(for state: AlphaDownloadState) -> String {
    let phase = alphaAssistantSetupPhases[alphaAssistantSetupPhaseIndex(for: state)]
    switch state {
    case .pausedWaitingForWifi:
        return "Assistant setup paused at \(phase). Waiting for Wi-Fi."
    case .pausedNoStorage:
        return "Assistant setup paused at \(phase). More device storage is needed."
    case .pausedUser:
        return "Assistant setup paused at \(phase)."
    case .pausedError, .failed:
        return "Assistant setup needs retry at \(phase)."
    case .installed:
        return "Assistant setup complete. Ready."
    default:
        return "Assistant setup step \(phase) of \(alphaAssistantSetupPhases.joined(separator: ", "))."
    }
}

func alphaAssistantSetupRecoveryHint(for state: AlphaDownloadState) -> String? {
    switch state {
    case .failed, .pausedError:
        return "Retry keeps your matters and files, then starts assistant setup again."
    case .pausedNoStorage:
        return "Free storage on this iPhone, then resume setup from here."
    case .pausedUser:
        return "Resume setup when you are ready; your existing progress stays on this iPhone."
    case .pausedWaitingForWifi:
        return "Reconnect to Wi-Fi, then resume setup from here."
    case .queued, .downloading, .verifying, .installed, .notStarted, .cancelled:
        return nil
    }
}

func alphaFieldSortRank(_ type: AlphaExtractedLegalFieldType) -> Int {
    switch type {
    case .caseNumber:
        return 0
    case .court:
        return 1
    case .partyName:
        return 2
    case .date:
        return 3
    case .nextDate:
        return 4
    case .orderDirection:
        return 5
    case .section:
        return 6
    case .exhibitNumber:
        return 7
    case .relief:
        return 8
    case .prayer:
        return 9
    case .amount:
        return 10
    case .issue:
        return 11
    case .advocateName:
        return 12
    case .judgeName:
        return 13
    case .limitationDate:
        return 14
    case .fact:
        return 15
    case .unknown:
        return 16
    }
}

func alphaAttentionHeadline(_ count: Int) -> String {
    switch count {
    case 0:
        return "Today is under control"
    case 1:
        return "1 item needs attention"
    default:
        return "\(count) items need attention"
    }
}

func alphaIsImportantReviewField(_ type: AlphaExtractedLegalFieldType) -> Bool {
    alphaFieldSortRank(type) <= 8
}

func alphaConfidenceLabel(confidence: Double, needsReview: Bool) -> String {
    if needsReview {
        return "Please confirm"
    }
    if confidence < 0.84 {
        return "Low confidence"
    }
    return "Verified"
}

func alphaConfidenceTint(_ label: String) -> Color {
    switch label {
    case "Verified":
        return Color.rossSuccess
    case "Low confidence":
        return Color.rossAccent
    default:
        return .orange
    }
}

func alphaConfidenceSupportText(confidence: Double, needsReview: Bool) -> String {
    switch alphaConfidenceLabel(confidence: confidence, needsReview: needsReview) {
    case "Verified":
        return "Verified from the file"
    case "Low confidence":
        return "Ross found this, but the wording should be double-checked"
    default:
        return "Needs your confirmation before you rely on it"
    }
}

func alphaFileSizeLabel(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
}

private struct AlphaAssistantStorageFootprintRow: View {
    @Bindable var model: AlphaRossModel
    @State private var breakdown = AlphaAssistantStorageBreakdown(
        modelPackBytes: 0,
        resumeBytes: 0,
        pendingDownloadBytes: 0,
        deviceCacheBytes: 0
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Assistant files")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(alphaFileSizeLabel(breakdown.totalBytes))
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.66))
                }
                Spacer(minLength: 0)
                RossGlassGroup(spacing: 8) {
                    Button("Reclaim") {
                        model.reclaimAssistantStorageLeaks()
                        Task { await refresh() }
                    }
                    .font(.caption.weight(.semibold))
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14, expandsHorizontally: false)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                storageDetail(alphaPrivateAIVerifiedStorageLabel, bytes: breakdown.modelPackBytes)
                storageDetail("Interrupted downloads", bytes: breakdown.pendingDownloadBytes)
                storageDetail("Resume data", bytes: breakdown.resumeBytes)
                storageDetail("Device cache", bytes: breakdown.deviceCacheBytes)
            }
        }
        .task { await refresh() }
    }

    private func storageDetail(_ label: String, bytes: Int64) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer(minLength: 8)
            Text(alphaFileSizeLabel(bytes))
        }
        .font(.caption)
        .foregroundStyle(bytes > 0 ? Color.rossInk.opacity(0.72) : Color.rossInk.opacity(0.42))
    }

    private func refresh() async {
        breakdown = await model.store.assistantStorageBreakdown()
    }
}

let alphaSamplerSettingsExplanation = "Tune how boldly the private assistant writes. The recommended defaults keep answers grounded and concise."

private struct AlphaSamplerSettingsCard: View {
    @Bindable var model: AlphaRossModel
    @State private var advancedTuningExpanded = false

    var body: some View {
        let settings = model.persisted.settings.llamaSamplerSettings
        RossSectionCard(title: "Answer style") {
            VStack(alignment: .leading, spacing: 12) {
                AlphaSettingsValueRow(label: "Current style", value: "Grounded legal answers")

                Text("Ross uses conservative defaults for legal Q&A so answers stay concise and tied to your files.")
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                DisclosureGroup(isExpanded: $advancedTuningExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(alphaSamplerSettingsExplanation)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.66))

                        samplerSlider(
                            title: "Creativity",
                            value: settings.temperature,
                            range: 0.0...1.0,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.temperature = newValue }
                        }

                        samplerSlider(
                            title: "Focus",
                            value: settings.topP,
                            range: 0.5...1.0,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.topP = newValue }
                        }

                        samplerSlider(
                            title: "Repetition control",
                            value: settings.repeatPenalty,
                            range: 1.0...1.4,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.repeatPenalty = newValue }
                        }

                        HStack(spacing: 10) {
                            Text("Candidate limit")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Spacer(minLength: 8)
                            Stepper("\(settings.topK)", value: Binding(
                                get: { model.persisted.settings.llamaSamplerSettings.topK },
                                set: { value in
                                    model.updateSettings { $0.llamaSamplerSettings.topK = max(1, min(value, 200)) }
                                }
                            ), in: 1...200, step: 5)
                            .labelsHidden()
                            Text("\(settings.topK)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Color.rossInk.opacity(0.7))
                        }

                        Button("Restore recommended style") {
                            model.updateSettings { $0.llamaSamplerSettings = .legalQA }
                        }
                        .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14)
                    }
                    .padding(.top, 12)
                } label: {
                    AlphaSettingsValueRow(label: "Advanced tuning", value: advancedTuningExpanded ? "Shown" : "Hidden")
                }
                .tint(Color.rossAccent)
            }
        }
    }

    private func samplerSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Spacer(minLength: 8)
                Text(String(format: "%.2f", value))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color.rossInk.opacity(0.7))
            }
            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: range, step: step)
            .tint(Color.rossAccent)
        }
    }
}

func alphaFileSize(relativePath: String?) -> Int64 {
    guard let relativePath, !relativePath.isEmpty else { return 0 }
    let url = alphaAbsoluteURL(for: relativePath)
    let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey])
    if values?.isRegularFile == true {
        if let allocated = values?.totalFileAllocatedSize {
            return Int64(allocated)
        }
        if let fileSize = values?.fileSize {
            return Int64(fileSize)
        }
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
}

@MainActor
func alphaStorageSnapshot(_ model: AlphaRossModel) -> AlphaStorageSnapshot {
    let documents = model.persisted.cases.flatMap(\.documents)
    let documentBytes = documents.reduce(into: Int64(0)) { total, document in
        total += alphaFileSize(relativePath: document.storedRelativePath)
    }
    let exportBytes = model.persisted.exports.reduce(into: Int64(0)) { total, report in
        total += alphaFileSize(relativePath: report.relativePath)
    }
    let assistantBytes = model.persisted.installedPacks.reduce(into: Int64(0)) { total, pack in
        total += alphaFileSize(relativePath: pack.installPath)
    }
    return AlphaStorageSnapshot(
        documentCount: documents.count,
        exportCount: model.persisted.exports.count,
        documentBytes: documentBytes,
        exportBytes: exportBytes,
        assistantBytes: assistantBytes
    )
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func caseInsensitiveContains(_ value: String) -> Bool {
        range(of: value, options: [.caseInsensitive]) != nil
    }
}
