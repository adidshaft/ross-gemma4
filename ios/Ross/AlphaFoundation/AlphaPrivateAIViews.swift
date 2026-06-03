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

var alphaPrivateAIBackgroundDownloadsDetail: String { rossLocalized("assistant_background_downloads_detail") }
var alphaPrivateAIUpdateDetail: String { rossLocalized("assistant_update_detail") }
var alphaPrivateAIStorageTitle: String { rossLocalized("assistant_storage_title") }
var alphaPrivateAIStorageDetail: String { rossLocalized("assistant_storage_detail") }
var alphaPrivateAIDeleteDownloadsTitle: String { rossLocalized("assistant_delete_setup_files_title") }
var alphaPrivateAIDeleteDownloadsDetail: String { rossLocalized("assistant_delete_setup_files_detail") }
var alphaPrivateAIUpdateChecksTitle: String { rossLocalized("assistant_update_checks_title") }
var alphaPrivateAIUpdateChecksDetail: String { rossLocalized("assistant_update_checks_detail") }
var alphaPrivateAIVerifiedStorageLabel: String { rossLocalized("assistant_verified_storage_label") }

func alphaAssistantUpdateAvailableLabel(_ tierTitle: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("assistant_update_available", languageCode: languageCode), tierTitle)
}

func alphaPrivateAIVisibleRecoveryText(
    _ rawText: String?,
    languageCode: String = rossSelectedLanguageCode(),
    fallback: String
) -> String {
    guard let rawText = rawText?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawText.isEmpty else {
        return fallback
    }

    let technicalMarkers = [
        "nserror",
        "nsurlerror",
        "runtime",
        "checksum",
        "gguf",
        "llama",
        "gemma",
        "artifact",
        "model",
        "provider",
        "byte-range"
    ]
    let lowercased = rawText.lowercased()
    guard !technicalMarkers.contains(where: lowercased.contains) else {
        return fallback
    }

    let normalizedCode = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
    if normalizedCode != "en" && !alphaPrivateAITextContainsSupportedLocalScript(rawText) {
        return fallback
    }

    return rawText
}

private func alphaPrivateAITextContainsSupportedLocalScript(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x0900...0x097F, 0x0980...0x09FF, 0x0B80...0x0BFF, 0x0C00...0x0C7F:
            return true
        default:
            return false
        }
    }
}

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
                    title: rossLocalized("my_assistant"),
                    subtitle: rossLocalized("assistant_local_answers_need_setup")
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
                    RossSectionCard(title: rossLocalized("assistant_setup_section")) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(visibleSetupJobs) { job in
                                AlphaPrivateAIJobCard(model: model, job: job)
                            }
                        }
                    }
                }

                RossSectionCard(
                    title: rossLocalized("assistant_setup_on_phone"),
                    subtitle: rossLocalized("assistant_choose_option_files")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AlphaPackOffer.catalog) { offer in
                            AlphaPrivateAIOfferCard(model: model, offer: offer)
                        }
                    }
                }

                RossSectionCard(title: rossLocalized("assistant_wifi_section")) {
                    DisclosureGroup(isExpanded: $downloadPreferencesExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaSettingsToggleRow(
                                title: rossLocalized("assistant_wifi_larger_downloads"),
                                detail: rossLocalized("assistant_wifi_larger_downloads_detail"),
                                isOn: wifiOnlyDownloadsBinding
                            )
                            AlphaSettingsToggleRow(
                                title: rossLocalized("assistant_allow_mobile_data"),
                                detail: rossLocalized("assistant_allow_mobile_data_detail"),
                                isOn: allowMobileDataBinding
                            )
                            AlphaSettingsToggleRow(
                                title: rossLocalized("assistant_background_downloads"),
                                detail: rossLocalized("assistant_background_downloads_detail"),
                                isOn: backgroundWorkBinding
                            )
                            AlphaSettingsToggleRow(
                                title: rossLocalized("assistant_update_checks_title"),
                                detail: rossLocalized("assistant_update_checks_detail"),
                                isOn: autoUpdatesBinding
                            )
                            AlphaSettingsToggleRow(
                                title: rossLocalized("assistant_device_cache"),
                                detail: rossLocalized("assistant_device_cache_detail"),
                                isOn: deviceCacheBinding
                            )
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(
                            label: rossLocalized("assistant_network"),
                            value: model.persisted.settings.allowMobileDataForLargePacks
                                ? rossLocalized("assistant_network_wifi_mobile")
                                : rossLocalized("assistant_network_wifi_preferred")
                        )
                    }
                    .tint(Color.rossAccent)
                }

                if let update = (model.persisted.modelUpdateCandidates ?? []).first(where: { $0.dismissedAt == nil }) {
                    RossSectionCard(title: rossLocalized("assistant_update_title")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(alphaAssistantUpdateAvailableLabel(update.tier.title))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)
                            Text(rossLocalized("assistant_update_detail"))
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                            RossGlassGroup(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button(rossLocalized("assistant_update_on_wifi")) {
                                        model.startAssistantModelUpdate(update, mobileAllowed: false)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)

                                    Button(rossLocalized("dismiss")) {
                                        model.dismissAssistantModelUpdate(update)
                                    }
                                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16, expandsHorizontally: false)
                                }
                            }
                        }
                    }
                }

                RossSectionCard(title: rossLocalized("assistant_storage_title")) {
                    VStack(alignment: .leading, spacing: 12) {
                        AlphaAssistantStorageFootprintRow(model: model)
                        Text(rossLocalized("assistant_storage_detail"))
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
                                    Text(rossLocalized("assistant_delete_setup_files_title"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rossHighlight)
                                    Text(rossLocalized("assistant_delete_setup_files_detail"))
                                        .font(.caption)
                                        .foregroundStyle(Color.rossInk.opacity(0.68))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .modifier(AlphaPrivateAIDestructiveStorageSurface())
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
        .navigationTitle(rossLocalized("my_assistant"))
        .rossInlineNavigationTitle()
    }
}

private struct AlphaPrivateAIDestructiveStorageSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let tint = Color.rossHighlight.opacity(0.16)

        content
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: 0.78,
                fallbackStrokeOpacity: 0.46
            )
            .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 2)
    }
}

struct AlphaPrivateAITechnicalDiagnosticsCard: View {
    @Bindable var model: AlphaRossModel

    private var assistantCheckStatus: String {
        guard let runtimeHealth = model.activeRuntimeHealth else {
            return rossLocalized("assistant_check_after_setup")
        }
        if runtimeHealth.available {
            return rossLocalized("ready_for_private_answers_on_iphone")
        }
        return alphaPrivateAIVisibleRecoveryText(
            runtimeHealth.userFacingStatus,
            fallback: rossLocalized("runtime_health_llama_needs_repair")
        )
    }

    private var assistantLastUsedLabel: String {
        guard let lastInvocation = model.lastModelInvocation else {
            return rossLocalized("no_private_answer_recorded_yet")
        }
        if let completedAt = lastInvocation.completedAt {
            return completedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return rossLocalized("started_but_did_not_finish")
    }

    var body: some View {
        RossSectionCard(title: rossLocalized("assistant_check")) {
            VStack(alignment: .leading, spacing: 12) {
                AlphaSettingsValueRow(label: rossLocalized("status"), value: assistantCheckStatus)
                Divider()
                AlphaSettingsValueRow(
                    label: rossLocalized("local_file"),
                    value: alphaAssistantVerificationSummary(
                        runtimeHealth: model.activeRuntimeHealth,
                        activePack: model.activePack
                    )
                )
                Divider()
                AlphaSettingsValueRow(label: rossLocalized("last_private_answer"), value: assistantLastUsedLabel)
                Divider()
                AlphaSettingsValueRow(label: rossLocalized("setup_resets"), value: "\(model.privateAISnapshot.resetCount)")

                #if DEBUG
                DisclosureGroup(rossLocalized("settings_support_details")) {
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
    activePack: AlphaInstalledModelPack?,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    guard let activePack else {
        return rossLocalized("assistant_verification_no_setup", languageCode: languageCode)
    }
    if activePack.developmentOnly {
        return alphaAllowsDevelopmentModelArtifacts()
            ? rossLocalized("assistant_verification_test_active", languageCode: languageCode)
            : rossLocalized("assistant_verification_test_disabled", languageCode: languageCode)
    }
    guard let runtimeHealth else {
        return rossLocalized("assistant_verification_pending", languageCode: languageCode)
    }
    if runtimeHealth.available && runtimeHealth.checksumVerified {
        return rossLocalized("assistant_verification_ready", languageCode: languageCode)
    }
    if runtimeHealth.available {
        return rossLocalized("assistant_verification_opened", languageCode: languageCode)
    }
    if runtimeHealth.modelPathPresent {
        return rossLocalized("assistant_verification_needs_repair", languageCode: languageCode)
    }
    return rossLocalized("assistant_verification_missing", languageCode: languageCode)
}

#if DEBUG
private struct AlphaPrivateAIInternalDiagnostics: View {
    @Bindable var model: AlphaRossModel

    private var assistantLastUsedLabel: String {
        guard let lastInvocation = model.lastModelInvocation else {
            return rossLocalized("no_private_answer_recorded_yet")
        }
        if let completedAt = lastInvocation.completedAt {
            return completedAt.formatted(date: .abbreviated, time: .shortened)
        }
        return rossLocalized("started_but_did_not_finish")
    }

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

                AlphaSettingsValueRow(label: rossLocalized("status"), value: runtimeHealth.userFacingStatus)
                AlphaSettingsValueRow(label: rossLocalized("assistant_can_answer"), value: runtimeHealth.available ? rossLocalized("yes") : rossLocalized("no"))
                AlphaSettingsValueRow(label: rossLocalized("setup_file_present"), value: runtimeHealth.modelPathPresent ? rossLocalized("yes") : rossLocalized("no"))

                if let lastInvocation {
                    AlphaSettingsValueRow(label: rossLocalized("last_answer_check"), value: assistantLastUsedLabel)
                    AlphaSettingsValueRow(label: rossLocalized("last_check_result"), value: lastInvocation.status == .complete ? rossLocalized("completed") : rossLocalized("started_but_did_not_finish"))
                    if let durationMs = lastInvocation.durationMs {
                        AlphaSettingsValueRow(label: rossLocalized("approx_time"), value: alphaAssistantDurationLabel(milliseconds: durationMs))
                    }
                } else {
                    AlphaSettingsValueRow(label: rossLocalized("last_answer_check"), value: rossLocalized("no_private_answer_recorded_yet"))
                }
                if let lastPreview {
                    AlphaSettingsValueRow(label: rossLocalized("public_law_check"), value: lastPreview.query)
                } else {
                    AlphaSettingsValueRow(label: rossLocalized("public_law_check"), value: rossLocalized("none_yet"))
                }
                AlphaSettingsValueRow(label: rossLocalized("workspace_refreshes"), value: "\(resetCount)")
            } else {
                AlphaSettingsValueRow(label: rossLocalized("status"), value: rossLocalized("assistant_check_after_setup"))
            }

            Button(model.localInferenceSmokeRunning ? rossLocalized("checking_private_assistant_sample_file") : rossLocalized("check_private_assistant_with_sample_file")) {
                model.runLocalInferenceSmoke()
            }
            .rossGlassButtonStyle(tint: Color.rossAccent)
            .disabled(model.localInferenceSmokeRunning)
        }
        .padding(.top, 12)
    }
}
#endif

func alphaAssistantDurationLabel(milliseconds: Int) -> String {
    let seconds = max(0.1, Double(milliseconds) / 1_000)
    if seconds < 10 {
        return String(format: "%.1f s", seconds)
    }
    return "\(Int(seconds.rounded())) s"
}

struct AlphaPrivacyLedgerScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    RossSectionCard(title: rossLocalized("privacy_summary")) {
                        Text(rossLocalized("privacy_summary_detail"))
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.persisted.ledgerEntries.isEmpty {
                        RossSectionCard {
                            Text(rossLocalized("privacy_ledger_empty"))
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

                                    Text(entry.success ? rossLocalized("completed") : rossLocalized("needs_attention"))
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
        .navigationTitle(rossLocalized("activity_log"))
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
        .modifier(AlphaSettingsToggleSurface())
    }
}

private struct AlphaSettingsToggleSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        content
            .rossNativeGlassSurface(
                tint: Color.rossAccent,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: 0.74,
                fallbackStrokeOpacity: 0.44
            )
            .shadow(color: Color.rossShadow.opacity(0.04), radius: 4, y: 1)
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
            return (alphaAssistantOfferBadge(.active), Color.rossSuccess)
        }
        if activeButRuntimeUnavailable {
            return (alphaAssistantOfferBadge(.needsAttention), .orange)
        }
        if isInstalledButInactive {
            return (alphaAssistantStateLabel(.installed), Color.rossSuccess)
        }
        if isSettingUp {
            return (alphaAssistantOfferBadge(.settingUp), Color.rossAccent)
        }
        if canResume {
            return (alphaAssistantStateLabel(.failed), .orange)
        }
        if offer.tier == model.recommendedOnDeviceTier() {
            return (rossLocalized("recommended"), Color.rossAccent)
        }
        return nil
    }

    private var actionTitle: String {
        if isActive {
            return alphaAssistantOfferAction(.using)
        }
        if activeButRuntimeUnavailable {
            return alphaAssistantOfferAction(.repair)
        }
        if isInstalledButInactive {
            return alphaAssistantOfferAction(.use)
        }
        if isSettingUp {
            return alphaAssistantOfferBadge(.settingUp)
        }
        if canResume {
            return alphaAssistantOfferAction(.resumeSetup)
        }
        return alphaAssistantOfferAction(.setUpOption)
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
                Text(alphaPrivateAIVisibleRecoveryText(
                    failureReason,
                    fallback: latestJob.state == .pausedNoStorage
                        ? rossLocalized("assistant_status_storage_detail")
                        : rossLocalized("assistant_status_retry_detail")
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let recoveryHint = alphaAssistantSetupRecoveryHint(for: latestJob.state) {
                    AlphaPrivateAIRecoveryHintRow(text: recoveryHint)
                }
            } else if activeButRuntimeUnavailable, let runtimeStatus = model.activeRuntimeHealth?.userFacingStatus {
                Text(alphaPrivateAIVisibleRecoveryText(
                    runtimeStatus,
                    fallback: rossLocalized("runtime_health_llama_needs_repair")
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                AlphaPrivateAIRecoveryHintRow(
                    text: rossLocalized("assistant_repair_setup_removes_broken")
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
        .modifier(AlphaPrivateAIOfferSurface(isActive: isActive))
    }
}

private struct AlphaPrivateAIOfferSurface: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let tint = isActive ? Color.rossAccent : Color.rossInk.opacity(0.42)

        content
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                fallbackFillOpacity: 0.82,
                fallbackStrokeOpacity: isActive ? 0.58 : 0.42
            )
            .shadow(
                color: Color.rossShadow.opacity(isActive ? 0.12 : 0.07),
                radius: isActive ? 10 : 7,
                y: isActive ? 4 : 3
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
        .modifier(AlphaPrivateAIRecoveryHintSurface())
    }
}

private struct AlphaPrivateAIRecoveryHintSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        content
            .rossNativeGlassSurface(
                tint: Color.rossAccent,
                shape: shape,
                fallbackFillOpacity: 0.74,
                fallbackStrokeOpacity: 0.44
            )
            .shadow(color: Color.rossShadow.opacity(0.04), radius: 4, y: 1)
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
        return alphaDownloadBytesProgressLabel(downloadedBytes: downloaded, totalBytes: job.totalBytes)
    }

    private var etaLabel: String? {
        alphaDownloadPreciseEtaLabel(job)
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
                phases: alphaAssistantSetupPhases(),
                currentPhase: alphaAssistantSetupPhaseIndex(for: job.state)
            )
            .padding(.vertical, 2)
            .accessibilityLabel(alphaAssistantSetupPhaseAccessibilityLabel(for: job.state))

            if let failureReason = job.failureReason,
               job.state == .failed || job.state == .pausedError || job.state == .pausedNoStorage {
                Text(alphaPrivateAIVisibleRecoveryText(
                    failureReason,
                    fallback: job.state == .pausedNoStorage
                        ? rossLocalized("assistant_status_storage_detail")
                        : rossLocalized("assistant_status_retry_detail")
                ))
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
                                .fill(LinearGradient(
                                    colors: [Color.rossAccent.opacity(0.80), Color.rossAccent],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(7, geo.size.width * CGFloat(progressValue)), height: 7)
                                .shadow(color: Color.rossAccent.opacity(0.35), radius: 4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressValue)
                        }
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent.opacity(0.18),
                            shape: Capsule(),
                            fallbackFillOpacity: 0.62,
                            fallbackStrokeOpacity: 0.34
                        )
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
                            Button(alphaAssistantJobAction(.pause)) { model.pauseJob(job) }
                                .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16)
                        }
                        if canResume {
                            Button(alphaAssistantJobAction(job.state == .failed ? .retry : .resume)) { model.resumeJob(job) }
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
                    Text(alphaAssistantDownloadWifiAdvisory())
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.44))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .modifier(AlphaPrivateAIJobSurface())
    }
}

private struct AlphaPrivateAIJobSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        content
            .rossNativeGlassSurface(
                tint: Color.rossAccent,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.68
            )
            .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
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

                    Text(isReady ? rossLocalized("my_assistant_ready") : rossLocalized("my_assistant_needs_attention"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isReady ? Color.rossSuccess : Color.orange)
                }

                Spacer(minLength: 8)

                AlphaPrivateAIInlineBadge(title: isReady ? rossLocalized("ready") : rossLocalized("needs_attention"), tint: isReady ? Color.rossSuccess : Color.orange)
            }

            if runtimeUnavailable, let runtimeStatus = model.activeRuntimeHealth?.userFacingStatus {
                Text(alphaPrivateAIVisibleRecoveryText(
                    runtimeStatus,
                    fallback: rossLocalized("runtime_health_llama_needs_repair")
                ))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RossGlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    Button(rossLocalized("use_this_option")) {
                        model.activateInstalledPack(pack)
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                    .disabled(!canActivate)

                    Button(rossLocalized("remove"), role: .destructive) {
                        model.removeInstalledPack(pack)
                    }
                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 16)
                }
            }
        }
        .padding(14)
        .modifier(AlphaPrivateAIInstalledPackSurface(isReady: isReady))
    }
}

private struct AlphaPrivateAIInstalledPackSurface: ViewModifier {
    let isReady: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let tint = isReady ? Color.rossSuccess : Color.orange

        content
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                fallbackFillOpacity: 0.82,
                fallbackStrokeOpacity: 0.48
            )
            .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
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

func alphaDownloadEstimateLabel(
    _ job: AlphaModelDownloadJob,
    languageCode: String = rossSelectedLanguageCode()
) -> String? {
    switch job.state {
    case .downloading:
        guard job.totalBytes > 0 else {
            return rossLocalized("assistant_download_waiting_estimate", languageCode: languageCode)
        }
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
        return String(
            format: rossLocalized("assistant_download_minutes_left", languageCode: languageCode),
            remainingMinutes
        )
    case .verifying:
        return rossLocalized("assistant_download_final_check", languageCode: languageCode)
    default:
        return nil
    }
}

func alphaDownloadPreciseEtaLabel(
    _ job: AlphaModelDownloadJob,
    languageCode: String = rossSelectedLanguageCode()
) -> String? {
    guard job.state == .downloading, job.totalBytes > 0, job.progress > 0 else { return nil }
    let remaining = max(0, 1 - job.progress)
    let assumedBytesPerSec: Double = 12_000_000 // Conservative 12 MB/s on Wi-Fi.
    let seconds = Double(job.totalBytes) * remaining / assumedBytesPerSec
    if seconds < 90 {
        return String(
            format: rossLocalized("assistant_download_seconds_left", languageCode: languageCode),
            max(1, Int(seconds))
        )
    } else if seconds < 3600 {
        return String(
            format: rossLocalized("assistant_download_precise_minutes_left", languageCode: languageCode),
            Int(ceil(seconds / 60))
        )
    } else {
        return String(
            format: rossLocalized("assistant_download_hours_left", languageCode: languageCode),
            Int(ceil(seconds / 3600))
        )
    }
}

func alphaAssistantDownloadWifiAdvisory(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("assistant_download_wifi_advisory", languageCode: languageCode)
}

enum AlphaAssistantOfferBadgeKind {
    case active
    case needsAttention
    case settingUp
}

func alphaAssistantOfferBadge(
    _ kind: AlphaAssistantOfferBadgeKind,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    switch kind {
    case .active:
        return rossLocalized("assistant_badge_active", languageCode: languageCode)
    case .needsAttention:
        return rossLocalized("assistant_badge_needs_attention", languageCode: languageCode)
    case .settingUp:
        return rossLocalized("assistant_badge_setting_up", languageCode: languageCode)
    }
}

enum AlphaAssistantOfferActionKind {
    case using
    case repair
    case use
    case resumeSetup
    case setUpOption
}

func alphaAssistantOfferAction(
    _ kind: AlphaAssistantOfferActionKind,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    switch kind {
    case .using:
        return rossLocalized("assistant_action_using", languageCode: languageCode)
    case .repair:
        return rossLocalized("assistant_action_repair", languageCode: languageCode)
    case .use:
        return rossLocalized("assistant_action_use", languageCode: languageCode)
    case .resumeSetup:
        return rossLocalized("assistant_action_resume_setup", languageCode: languageCode)
    case .setUpOption:
        return rossLocalized("assistant_action_set_up_option", languageCode: languageCode)
    }
}

enum AlphaAssistantJobActionKind {
    case pause
    case retry
    case resume
}

func alphaAssistantJobAction(
    _ kind: AlphaAssistantJobActionKind,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    switch kind {
    case .pause:
        return rossLocalized("assistant_action_pause", languageCode: languageCode)
    case .retry:
        return rossLocalized("assistant_action_retry", languageCode: languageCode)
    case .resume:
        return rossLocalized("assistant_action_resume", languageCode: languageCode)
    }
}

func alphaAssistantSetupPhases(languageCode: String = rossSelectedLanguageCode()) -> [String] {
    [
        rossLocalized("assistant_setup_phase_download", languageCode: languageCode),
        rossLocalized("assistant_setup_phase_check", languageCode: languageCode),
        rossLocalized("assistant_setup_phase_ready", languageCode: languageCode)
    ]
}

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

func alphaAssistantSetupPhaseAccessibilityLabel(
    for state: AlphaDownloadState,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    let phases = alphaAssistantSetupPhases(languageCode: languageCode)
    let phase = phases[alphaAssistantSetupPhaseIndex(for: state)]
    switch state {
    case .pausedWaitingForWifi:
        return String(format: rossLocalized("assistant_setup_paused_wifi", languageCode: languageCode), phase)
    case .pausedNoStorage:
        return String(format: rossLocalized("assistant_setup_paused_storage", languageCode: languageCode), phase)
    case .pausedUser:
        return String(format: rossLocalized("assistant_setup_paused", languageCode: languageCode), phase)
    case .pausedError, .failed:
        return String(format: rossLocalized("assistant_setup_retry", languageCode: languageCode), phase)
    case .installed:
        return rossLocalized("assistant_setup_complete", languageCode: languageCode)
    default:
        return String(
            format: rossLocalized("assistant_setup_step", languageCode: languageCode),
            phase,
            phases.joined(separator: ", ")
        )
    }
}

func alphaAssistantSetupRecoveryHint(
    for state: AlphaDownloadState,
    languageCode: String = rossSelectedLanguageCode()
) -> String? {
    switch state {
    case .failed, .pausedError:
        return rossLocalized("assistant_setup_retry_hint", languageCode: languageCode)
    case .pausedNoStorage:
        return rossLocalized("assistant_setup_storage_hint", languageCode: languageCode)
    case .pausedUser:
        return rossLocalized("assistant_setup_resume_hint", languageCode: languageCode)
    case .pausedWaitingForWifi:
        return rossLocalized("assistant_setup_wifi_hint", languageCode: languageCode)
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
        return rossLocalized("attention_under_control")
    case 1:
        return rossLocalized("attention_one_item")
    default:
        return String(format: rossLocalized("attention_many_items"), count)
    }
}

func alphaIsImportantReviewField(_ type: AlphaExtractedLegalFieldType) -> Bool {
    alphaFieldSortRank(type) <= 8
}

func alphaConfidenceLabel(confidence: Double, needsReview: Bool) -> String {
    if needsReview {
        return rossLocalized("please_confirm")
    }
    if confidence < 0.84 {
        return rossLocalized("low_confidence")
    }
    return rossLocalized("verified")
}

func alphaConfidenceTint(confidence: Double, needsReview: Bool) -> Color {
    if needsReview {
        return .orange
    }
    if confidence < 0.84 {
        return Color.rossAccent
    }
    return Color.rossSuccess
}

func alphaConfidenceSupportText(confidence: Double, needsReview: Bool) -> String {
    if needsReview {
        return rossLocalized("confirmation_needed_before_rely")
    }
    if confidence < 0.84 {
        return rossLocalized("confidence_double_check")
    }
    return rossLocalized("verified_from_file")
}

func alphaFileSizeLabel(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
}

func alphaDownloadBytesProgressLabel(
    downloadedBytes: Int64,
    totalBytes: Int64,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    let downloadedLabel = alphaFileSizeLabel(downloadedBytes)
    let totalLabel = alphaFileSizeLabel(totalBytes)
    return String(
        format: rossLocalized("assistant_download_bytes_progress", languageCode: languageCode),
        downloadedLabel,
        totalLabel
    )
}

private struct AlphaAssistantStorageFootprintRow: View {
    @Bindable var model: AlphaRossModel
    @State private var breakdown = AlphaAssistantStorageBreakdown(
        modelPackBytes: 0,
        resumeBytes: 0,
        pendingDownloadBytes: 0,
        deviceCacheBytes: 0
    )
    @State private var isReclaiming = false
    @State private var reclaimStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rossLocalized("assistant_files"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                    Text(alphaFileSizeLabel(breakdown.totalBytes))
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.66))
                }
                Spacer(minLength: 0)
                RossGlassGroup(spacing: 8) {
                    Button(isReclaiming ? rossLocalized("cleaning") : rossLocalized("reclaim")) {
                        Task { await reclaimStorage() }
                    }
                    .font(.caption.weight(.semibold))
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14, expandsHorizontally: false)
                    .disabled(isReclaiming)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                storageDetail(alphaPrivateAIVerifiedStorageLabel, bytes: breakdown.modelPackBytes)
                storageDetail(rossLocalized("interrupted_downloads"), bytes: breakdown.pendingDownloadBytes)
                storageDetail(rossLocalized("resume_data"), bytes: breakdown.resumeBytes)
                storageDetail(rossLocalized("device_cache"), bytes: breakdown.deviceCacheBytes)
            }

            if let reclaimStatus {
                Text(reclaimStatus)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
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

    private func reclaimStorage() async {
        guard !isReclaiming else { return }
        isReclaiming = true
        reclaimStatus = rossLocalized("cleaning_interrupted_setup_files")
        let reclaimedBytes = await model.reclaimAssistantStorageLeaks()
        await refresh()
        reclaimStatus = reclaimedBytes > 0
            ? alphaReclaimedAssistantStorageLabel(alphaFileSizeLabel(reclaimedBytes))
            : rossLocalized("no_extra_assistant_setup_files")
        isReclaiming = false
    }
}

func alphaSamplerSettingsExplanation(languageCode: String = rossSelectedLanguageCode()) -> String {
    rossLocalized("answer_style_tuning_detail", languageCode: languageCode)
}

func alphaReclaimedAssistantStorageLabel(_ sizeLabel: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("reclaimed_assistant_storage", languageCode: languageCode), sizeLabel)
}

private struct AlphaSamplerSettingsCard: View {
    @Bindable var model: AlphaRossModel
    @State private var advancedTuningExpanded = false

    var body: some View {
        let settings = model.persisted.settings.llamaSamplerSettings
        RossSectionCard(title: rossLocalized("answer_style")) {
            VStack(alignment: .leading, spacing: 12) {
                AlphaSettingsValueRow(label: rossLocalized("current_style"), value: rossLocalized("grounded_legal_answers"))

                Text(rossLocalized("answer_style_detail"))
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                DisclosureGroup(isExpanded: $advancedTuningExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(alphaSamplerSettingsExplanation())
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.66))

                        samplerSlider(
                            title: rossLocalized("creativity"),
                            value: settings.temperature,
                            range: 0.0...1.0,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.temperature = newValue }
                        }

                        samplerSlider(
                            title: rossLocalized("focus"),
                            value: settings.topP,
                            range: 0.5...1.0,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.topP = newValue }
                        }

                        samplerSlider(
                            title: rossLocalized("repetition_control"),
                            value: settings.repeatPenalty,
                            range: 1.0...1.4,
                            step: 0.05
                        ) { newValue in
                            model.updateSettings { $0.llamaSamplerSettings.repeatPenalty = newValue }
                        }

                        HStack(spacing: 10) {
                            Text(rossLocalized("candidate_limit"))
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

                        Button(rossLocalized("restore_recommended_style")) {
                            model.updateSettings { $0.llamaSamplerSettings = .legalQA }
                        }
                        .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14)
                    }
                    .padding(.top, 12)
                } label: {
                    AlphaSettingsValueRow(label: rossLocalized("advanced_tuning"), value: advancedTuningExpanded ? rossLocalized("shown") : rossLocalized("hidden"))
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
