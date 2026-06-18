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
        return model.persisted.modelJobs.filter { job in
            switch job.state {
            case .queued, .downloading, .pausedWaitingForWifi, .pausedUser, .verifying:
                return true
            case .notStarted, .installed, .cancelled:
                return false
            case .pausedNoStorage, .pausedError, .failed:
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

    private var askUpgradeSummary: (title: String, detail: String?)? {
        alphaAskUpgradeSetupSummary(
            expectedTier: model.pendingAskUpgradeExpectedTier,
            expectedRuntimeMode: model.pendingAskUpgradeExpectedRuntimeMode,
            currentRoute: model.path.last
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
                        if let askUpgradeSummary {
                            AlphaAssistantUpgradeSummaryRow(
                                title: askUpgradeSummary.title,
                                detail: askUpgradeSummary.detail
                            )
                        }

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
        .task {
            model.primeAssistantSetupCatalogsIfNeeded()
        }
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

func alphaAssistantSupportStatusDetail(
    runtimeHealth: AlphaLocalRuntimeHealth,
    languageCode: String = rossSelectedLanguageCode()
) -> String {
    if runtimeHealth.available {
        return rossLocalized("ready_for_private_answers_on_iphone", languageCode: languageCode)
    }
    return alphaPrivateAIVisibleRecoveryText(
        runtimeHealth.userFacingStatus,
        languageCode: languageCode,
        fallback: rossLocalized("runtime_health_llama_needs_repair", languageCode: languageCode)
    )
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

    private var latestSmokeReport: AlphaLocalInferenceSmokeReport? {
        model.localInferenceSmokeReport ?? model.localInferenceSmokeReports.first
    }

    private var latestMatterBundleComparison: AlphaMatterBundleComparisonReport? {
        model.matterBundleComparisonReport ?? model.matterBundleComparisonReports.first
    }

    private var latestMatterBundleComparisonExport: AlphaExportedReport? {
        model.persisted.exports.first { $0.kind == AlphaRossModel.matterBundleComparisonExportKind }
    }

    private var deviceProofProfile: AlphaPrivateAIDeviceProofProfile {
        alphaCurrentPrivateAIDeviceProofProfile()
    }

    private var comparisonTier: AlphaCapabilityTier? {
        model.activePack?.tier ?? model.persisted.settings.activeTier ?? model.selectedTier
    }

    private var downloadDeliverySummary: AlphaAssistantDownloadDeliveryVerificationSummary? {
        guard let comparisonTier else { return nil }
        let preferredRuntimeMode: AlphaPackRuntimeMode = if model.activePack?.runtimeMode == .mlxSwiftLm {
            .mlxSwiftLm
        } else {
            .llamaCppGguf
        }
        return alphaAssistantPreferredDeliveryVerificationSummary(
            for: comparisonTier,
            preferredRuntimeMode: preferredRuntimeMode,
            cachedDownloads: model.persisted.cachedAssistantDownloads,
            ledgerEntries: model.persisted.ledgerEntries
        )
    }

    private var comparisonRuntimeOptions: [AlphaAssistantVariantOption] {
        guard let comparisonTier else { return [] }
        return alphaAssistantComparisonRuntimeOptions(
            for: comparisonTier,
            installedPacks: model.privateAISnapshot.installedPacks,
            activePack: model.activePack,
            systemAssistantAvailable: model.systemAssistantHealth(for: comparisonTier)?.available == true,
            preferredRuntimeMode: model.activePack?.runtimeMode,
            cachedCatalogs: model.persisted.cachedAssistantCatalogs,
            cachedDownloads: model.persisted.cachedAssistantDownloads,
            canActivateRuntime: { runtimeMode in
                model.canActivateAssistantRuntimeImmediately(for: comparisonTier, runtimeMode: runtimeMode)
            }
        )
    }

    private var laneReadinessStatuses: [AlphaPrivateAIRuntimeLaneReadinessStatus] {
        guard let comparisonTier else { return [] }
        return alphaPrivateAIRuntimeLaneReadinessStatuses(
            for: comparisonTier,
            installedPacks: model.privateAISnapshot.installedPacks,
            activePack: model.activePack,
            systemAssistantAvailable: model.systemAssistantHealth(for: comparisonTier)?.available == true,
            canActivateRuntime: { runtimeMode in
                model.canActivateAssistantRuntimeImmediately(for: comparisonTier, runtimeMode: runtimeMode)
            }
        )
    }

    private var comparisonRuntimeChoiceLabel: String? {
        guard let comparisonTier,
              let selectedRuntimeMode = model.activePack?.runtimeMode ?? model.activeRuntimeHealth?.runtimeMode else {
            return nil
        }
        let label = alphaAssistantRuntimeChoiceLabel(
            selectedRuntimeMode: selectedRuntimeMode,
            tier: comparisonTier,
            existingRuntimeMode: model.activePack?.runtimeMode,
            systemAssistantAvailable: model.systemAssistantHealth(for: comparisonTier)?.available == true,
            lastInvocation: model.lastModelInvocation
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
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
                let activePack = model.activePack
                let resolvedModelDetails = activePack.flatMap(alphaAssistantResolvedModelDetails)

                AlphaSettingsValueRow(label: rossLocalized("status"), value: alphaAssistantSupportStatusDetail(runtimeHealth: runtimeHealth))
                AlphaSettingsValueRow(label: rossLocalized("assistant_can_answer"), value: runtimeHealth.available ? rossLocalized("yes") : rossLocalized("no"))
                AlphaSettingsValueRow(label: rossLocalized("setup_file_present"), value: runtimeHealth.modelPathPresent ? rossLocalized("yes") : rossLocalized("no"))
                if let resolvedModelDetails {
                    AlphaSettingsValueRow(label: rossLocalized("assistant_model"), value: resolvedModelDetails.modelLabel)
                    if let sourceLabel = resolvedModelDetails.sourceLabel {
                        AlphaSettingsValueRow(label: rossLocalized("assistant_model_source"), value: sourceLabel)
                    }
                    if let draftCompanionLabel = resolvedModelDetails.draftCompanionLabel {
                        AlphaSettingsValueRow(label: rossLocalized("assistant_mtp_companion"), value: draftCompanionLabel)
                    }
                }
                if let contextTokens = runtimeHealth.estimatedContextTokens {
                    AlphaSettingsValueRow(label: rossLocalized("runtime_context_window"), value: alphaAssistantContextWindowLabel(tokens: contextTokens))
                }
                if let maxInputChars = runtimeHealth.maxInputChars {
                    AlphaSettingsValueRow(label: rossLocalized("runtime_input_budget"), value: alphaAssistantInputBudgetLabel(chars: maxInputChars))
                }
                if runtimeHealth.accelerationMode != nil {
                    AlphaSettingsValueRow(label: rossLocalized("runtime_acceleration"), value: alphaAssistantAccelerationLabel(runtimeHealth: runtimeHealth))
                }

                if let lastInvocation {
                    AlphaSettingsValueRow(label: rossLocalized("last_answer_check"), value: assistantLastUsedLabel)
                    AlphaSettingsValueRow(label: rossLocalized("last_check_result"), value: lastInvocation.status == .complete ? rossLocalized("completed") : rossLocalized("started_but_did_not_finish"))
                    if let durationMs = lastInvocation.durationMs {
                        AlphaSettingsValueRow(label: rossLocalized("approx_time"), value: alphaAssistantDurationLabel(milliseconds: durationMs))
                    }
                    if let firstTokenMs = lastInvocation.timeToFirstTokenMs {
                        AlphaSettingsValueRow(label: rossLocalized("runtime_first_response"), value: alphaAssistantFirstResponseLabel(milliseconds: firstTokenMs))
                    }
                    if let outputSpeed = lastInvocation.estimatedOutputTokensPerSecond {
                        AlphaSettingsValueRow(label: rossLocalized("runtime_output_speed"), value: alphaAssistantTokenRateLabel(tokensPerSecond: outputSpeed))
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

            Divider()
            AlphaPrivateAIDeviceProofProfileSection(profile: deviceProofProfile)

            if let downloadDeliverySummary {
                Divider()
                AlphaAssistantDownloadDeliverySummarySection(summary: downloadDeliverySummary)
            }

            Button(model.localInferenceSmokeRunning ? rossLocalized("checking_private_assistant_sample_file") : rossLocalized("check_private_assistant_with_sample_file")) {
                model.runLocalInferenceSmoke()
            }
            .rossGlassButtonStyle(tint: Color.rossAccent)
            .disabled(model.localInferenceSmokeRunning)

            if let latestSmokeReport {
                Divider()
                AlphaPrivateAISmokeReportCard(report: latestSmokeReport)
            }

            if model.localInferenceSmokeReports.count > 1 {
                Divider()
                AlphaPrivateAISmokeHistorySection(reports: Array(model.localInferenceSmokeReports.dropFirst()))
            }

            if !model.localInferenceSmokeReports.isEmpty {
                Divider()
                AlphaPrivateAISmokeRuntimeSummarySection(reports: model.localInferenceSmokeReports)
            }

            if let comparisonTier, comparisonRuntimeOptions.count > 1 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(rossLocalized("private_assistant_runtime_comparison_title"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    AlphaSettingsValueRow(label: rossLocalized("assistant_used"), value: comparisonTier.setupTitle)
                    AlphaSettingsValueRow(
                        label: rossLocalized("runtime_used"),
                        value: alphaLocalInferenceSmokeRuntimeLabel(
                            model.activePack?.runtimeMode.rawValue ?? model.activeRuntimeHealth?.runtimeMode.rawValue ?? AlphaPackRuntimeMode.unavailable.rawValue
                        )
                    )

                    if let comparisonRuntimeChoiceLabel {
                        Text(comparisonRuntimeChoiceLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(rossLocalized("private_assistant_runtime_comparison_hint"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(comparisonRuntimeOptions) { option in
                                AlphaAssistantVariantChip(
                                    option: option,
                                    action: {
                                        _ = model.activateAssistantRuntimeIfAvailable(
                                            for: comparisonTier,
                                            runtimeMode: option.runtimeMode
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !laneReadinessStatuses.isEmpty {
                Divider()
                AlphaPrivateAIRuntimeLaneReadinessSection(statuses: laneReadinessStatuses)
            }

            if !model.matterBundleComparisonReports.isEmpty {
                Divider()
                AlphaMatterBundleComparisonRuntimeSummarySection(
                    reports: model.matterBundleComparisonReports
                )

                Button(
                    model.matterBundleComparisonExportRunning
                    ? rossLocalized("saving_private_assistant_runtime_comparison_note")
                    : rossLocalized("save_private_assistant_runtime_comparison_note")
                ) {
                    model.saveMatterBundleComparisonExport()
                }
                .rossGlassButtonStyle(tint: Color.rossAccent)
                .disabled(model.matterBundleComparisonExportRunning)

                if let latestMatterBundleComparisonExport {
                    VStack(alignment: .leading, spacing: 8) {
                        AlphaSettingsValueRow(
                            label: rossLocalized("notes_drafts_metadata_saved_file"),
                            value: URL(fileURLWithPath: latestMatterBundleComparisonExport.relativePath).lastPathComponent
                        )
                        AlphaSettingsValueRow(
                            label: rossLocalized("notes_drafts_metadata_created"),
                            value: latestMatterBundleComparisonExport.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )
                        Text(rossLocalized("ask_open_notes_drafts_to_review_pdf"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let exportErrorMessage = model.matterBundleComparisonExportErrorMessage, !exportErrorMessage.isEmpty {
                    Text(exportErrorMessage)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !model.privateAIDeviceComparisonProofRecords.isEmpty || !model.matterBundleComparisonReports.isEmpty {
                Divider()
                AlphaPrivateAIDeviceComparisonProofCoverageSection(
                    records: model.privateAIDeviceComparisonProofRecords
                )
            }

            if !model.localInferenceSmokeReports.isEmpty || !model.matterBundleComparisonReports.isEmpty {
                Divider()
                AlphaPrivateAIRuntimeCoverageSection(
                    smokeReports: model.localInferenceSmokeReports,
                    comparisonReports: model.matterBundleComparisonReports
                )
            }

            Divider()

            Button(model.matterBundleComparisonRunning ? rossLocalized("checking_private_assistant_longer_bundle") : rossLocalized("check_private_assistant_with_longer_bundle")) {
                model.runMatterBundleComparison()
            }
            .rossGlassButtonStyle(tint: Color.rossInk)
            .disabled(model.matterBundleComparisonRunning)

            if let latestMatterBundleComparison {
                Divider()
                AlphaMatterBundleComparisonReportCard(report: latestMatterBundleComparison)
            }

            if model.matterBundleComparisonReports.count > 1 {
                Divider()
                AlphaMatterBundleComparisonHistorySection(reports: Array(model.matterBundleComparisonReports.dropFirst()))
            }
        }
        .padding(.top, 12)
    }
}

private struct AlphaPrivateAISmokeReportCard: View {
    let report: AlphaLocalInferenceSmokeReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rossLocalized("private_assistant_sample_file_check_report_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            AlphaSettingsValueRow(label: rossLocalized("status"), value: alphaLocalInferenceSmokeStatusLabel(report))
            AlphaSettingsValueRow(label: rossLocalized("runtime_used"), value: alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))
            AlphaSettingsValueRow(
                label: rossLocalized("schema_valid"),
                value: report.schemaValid ? rossLocalized("yes") : rossLocalized("no")
            )
            if let durationMs = report.durationMs {
                AlphaSettingsValueRow(label: rossLocalized("approx_time"), value: alphaAssistantDurationLabel(milliseconds: durationMs))
            }
            if let timeToFirstTokenMs = report.timeToFirstTokenMs {
                AlphaSettingsValueRow(
                    label: rossLocalized("runtime_first_response"),
                    value: alphaAssistantFirstResponseLabel(milliseconds: timeToFirstTokenMs)
                )
            }
            if let estimatedOutputTokensPerSecond = report.estimatedOutputTokensPerSecond {
                AlphaSettingsValueRow(
                    label: rossLocalized("runtime_output_speed"),
                    value: alphaAssistantTokenRateLabel(tokensPerSecond: estimatedOutputTokensPerSecond)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: rossLocalized("fields_found_count"), report.fieldsFound))
                Text(String(format: rossLocalized("fields_verified_count"), report.fieldsVerified))
                Text(String(format: rossLocalized("fields_needing_review_count"), report.fieldsNeedingReview))
                Text(String(format: rossLocalized("unsupported_accepted_count"), report.unsupportedAccepted))
            }
            .font(.caption)
            .foregroundStyle(Color.rossInk.opacity(0.72))

            Text(report.message)
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AlphaPrivateAISmokeHistorySection: View {
    let reports: [AlphaLocalInferenceSmokeReport]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_sample_file_check_recent_runs"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            ForEach(Array(reports.prefix(AlphaRossModel.localInferenceSmokeHistoryLimit - 1).enumerated()), id: \.offset) { _, report in
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        "\(report.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(alphaLocalInferenceSmokeStatusLabel(report)) · \(alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                    Text(alphaLocalInferenceSmokeMetricsSummary(report))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct AlphaMatterBundleComparisonReportCard: View {
    let report: AlphaMatterBundleComparisonReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rossLocalized("private_assistant_matter_bundle_check_report_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            AlphaSettingsValueRow(label: rossLocalized("status"), value: alphaMatterBundleComparisonStatusLabel(report))
            AlphaSettingsValueRow(label: rossLocalized("runtime_used"), value: alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))
            AlphaSettingsValueRow(
                label: rossLocalized("schema_valid"),
                value: report.schemaValid ? rossLocalized("yes") : rossLocalized("no")
            )
            if let assistantDisplayName = report.assistantDisplayName, !assistantDisplayName.isEmpty {
                AlphaSettingsValueRow(label: rossLocalized("assistant_used"), value: assistantDisplayName)
            }
            if let runtimeSelectionReason = report.runtimeSelectionReason, !runtimeSelectionReason.isEmpty {
                AlphaSettingsValueRow(label: rossLocalized("runtime_choice"), value: runtimeSelectionReason)
            }
            if let executionPathLabel = report.executionPathLabel, !executionPathLabel.isEmpty {
                AlphaSettingsValueRow(label: rossLocalized("execution_path"), value: executionPathLabel)
            }
            if let accelerationSummary = report.accelerationSummary, !accelerationSummary.isEmpty {
                AlphaSettingsValueRow(label: rossLocalized("runtime_acceleration"), value: accelerationSummary)
            }
            if let durationMs = report.durationMs {
                AlphaSettingsValueRow(label: rossLocalized("approx_time"), value: alphaAssistantDurationLabel(milliseconds: durationMs))
            }
            if let timeToFirstTokenMs = report.timeToFirstTokenMs {
                AlphaSettingsValueRow(
                    label: rossLocalized("runtime_first_response"),
                    value: alphaAssistantFirstResponseLabel(milliseconds: timeToFirstTokenMs)
                )
            }
            if let estimatedOutputTokensPerSecond = report.estimatedOutputTokensPerSecond {
                AlphaSettingsValueRow(
                    label: rossLocalized("runtime_output_speed"),
                    value: alphaAssistantTokenRateLabel(tokensPerSecond: estimatedOutputTokensPerSecond)
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: rossLocalized("selected_files_count"), report.selectedDocumentCount))
                Text(String(format: rossLocalized("source_blocks_count"), report.sourceBlockCount))
                Text(String(format: rossLocalized("source_refs_count"), report.sourceRefsReturned))
            }
            .font(.caption)
            .foregroundStyle(Color.rossInk.opacity(0.72))

            if let answerHeadline = report.answerHeadline, !answerHeadline.isEmpty {
                Text(answerHeadline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
            }
            if let answerPreview = report.answerPreview, !answerPreview.isEmpty {
                Text(answerPreview)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let needsReviewWarning = report.needsReviewWarning, !needsReviewWarning.isEmpty {
                Text(needsReviewWarning)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(report.message)
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AlphaPrivateAIDeviceProofProfileSection: View {
    let profile: AlphaPrivateAIDeviceProofProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_device_profile_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            AlphaSettingsValueRow(
                label: rossLocalized("private_assistant_device_capture_source_label"),
                value: profile.captureSource.localizedLabel
            )
            AlphaSettingsValueRow(label: rossLocalized("private_assistant_device_model_label"), value: profile.deviceModelLabel)
            AlphaSettingsValueRow(label: rossLocalized("private_assistant_device_system_label"), value: profile.systemVersionLabel)
            AlphaSettingsValueRow(label: rossLocalized("private_assistant_device_memory_label"), value: "\(profile.memoryGB) GB")
            AlphaSettingsValueRow(
                label: rossLocalized("private_assistant_device_representative_class_label"),
                value: profile.representativeClass.localizedLabel
            )
            AlphaSettingsValueRow(label: rossLocalized("private_assistant_device_storage_label"), value: "\(profile.freeStorageGB) GB")
            AlphaSettingsValueRow(
                label: rossLocalized("private_assistant_device_low_power_label"),
                value: profile.lowPowerModeEnabled ? rossLocalized("yes") : rossLocalized("no")
            )
            AlphaSettingsValueRow(label: rossLocalized("private_assistant_device_thermal_label"), value: profile.thermalCondition)

            Text(rossLocalized("private_assistant_device_profile_note"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AlphaAssistantDownloadDeliverySummarySection: View {
    let summary: AlphaAssistantDownloadDeliveryVerificationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_download_delivery_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            AlphaSettingsValueRow(
                label: rossLocalized("assistant_model"),
                value: summary.fileName
            )
            AlphaSettingsValueRow(
                label: rossLocalized("assistant_model_source"),
                value: summary.sourceLabel
            )
            AlphaSettingsValueRow(
                label: rossLocalized("private_assistant_download_delivery_contract_label"),
                value: summary.contractLabel
            )
            AlphaSettingsValueRow(
                label: rossLocalized("private_assistant_download_delivery_status_label"),
                value: summary.statusLabel
            )
            if let lastCheckedLabel = summary.lastCheckedLabel {
                AlphaSettingsValueRow(
                    label: rossLocalized("private_assistant_download_delivery_last_checked_label"),
                    value: lastCheckedLabel
                )
            }
        }
    }
}

private struct AlphaPrivateAIRuntimeLaneReadinessSection: View {
    let statuses: [AlphaPrivateAIRuntimeLaneReadinessStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_runtime_lane_readiness_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.runtimeMode.displayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaPrivateAIRuntimeLaneReadinessSummary(status))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct AlphaPrivateAIDeviceComparisonProofCoverageSection: View {
    let records: [AlphaPrivateAIDeviceComparisonProofRecord]

    private var statuses: [AlphaPrivateAIDeviceComparisonProofStatus] {
        alphaPrivateAIDeviceComparisonProofStatuses(records)
    }

    private var missingTargetLabels: String? {
        let labels = alphaPrivateAIDeviceComparisonMissingTargetLabels(records)
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ", ")
    }

    private var nextSteps: [String] {
        alphaPrivateAIDeviceComparisonNextSteps(records)
    }

    private var decisionReadinessSummary: String {
        alphaPrivateAIDeviceComparisonDecisionReadinessSummary(records)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_device_comparison_coverage_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            Text(rossLocalized("private_assistant_device_comparison_coverage_note"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)

            if let missingTargetLabels {
                Text(String(format: rossLocalized("private_assistant_device_comparison_coverage_missing"), missingTargetLabels))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(rossLocalized("private_assistant_device_comparison_coverage_ready"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.target.localizedLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaPrivateAIDeviceComparisonProofSummary(status))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    if let latestSavedRecord = status.latestSavedRecord,
                       let deliveryStatus = alphaPrivateAIDeviceComparisonSavedDeliveryStatus(latestSavedRecord) {
                        Text(rossLocalized("private_assistant_device_comparison_delivery_status_label") + ": " + deliveryStatus)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latestSavedRecord = status.latestSavedRecord {
                        Text(
                            rossLocalized("private_assistant_device_comparison_saved_captured_at_label") +
                                ": " +
                                alphaPrivateAIDeviceComparisonSavedCapturedAt(latestSavedRecord)
                        )
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latestSavedRecord = status.latestSavedRecord {
                        Text(
                            rossLocalized("private_assistant_device_comparison_saved_system_label") +
                                ": " +
                                latestSavedRecord.profile.systemVersionLabel
                        )
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latestSavedRecord = status.latestSavedRecord {
                        Text(
                            rossLocalized("private_assistant_device_comparison_saved_device_state_label") +
                                ": " +
                                alphaPrivateAIDeviceComparisonSavedDeviceStateSummary(latestSavedRecord)
                        )
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latestSavedRecord = status.latestSavedRecord,
                       let savedFileName = alphaPrivateAIDeviceComparisonSavedFileName(latestSavedRecord) {
                        Text(rossLocalized("notes_drafts_metadata_saved_file") + ": " + savedFileName)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latestSavedRecord = status.latestSavedRecord,
                       let deliveryContract = alphaPrivateAIDeviceComparisonSavedDeliveryContract(latestSavedRecord) {
                        Text(rossLocalized("private_assistant_device_comparison_delivery_contract_label") + ": " + deliveryContract)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(rossLocalized("private_assistant_device_comparison_next_steps_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                if nextSteps.isEmpty {
                    Text(rossLocalized("private_assistant_device_comparison_next_steps_ready"))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(nextSteps.enumerated()), id: \.offset) { _, step in
                        Text(step)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(rossLocalized("private_assistant_ladder_decision_readiness_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(decisionReadinessSummary)
                    .font(.caption2)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AlphaPrivateAIRuntimeCoverageSection: View {
    let smokeReports: [AlphaLocalInferenceSmokeReport]
    let comparisonReports: [AlphaMatterBundleComparisonReport]

    private var statuses: [AlphaPrivateAIRuntimeCoverageStatus] {
        alphaPrivateAIRuntimeCoverageStatuses(
            smokeReports: smokeReports,
            comparisonReports: comparisonReports
        )
    }

    private var missingLabels: String? {
        let labels = alphaPrivateAIRuntimeCoverageMissingLabels(
            smokeReports: smokeReports,
            comparisonReports: comparisonReports
        )
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ", ")
    }

    private var nextSteps: [String] {
        alphaPrivateAIRuntimeCoverageNextSteps(
            smokeReports: smokeReports,
            comparisonReports: comparisonReports
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_runtime_coverage_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            if let missingLabels {
                Text(String(format: rossLocalized("private_assistant_runtime_coverage_missing"), missingLabels))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(rossLocalized("private_assistant_runtime_coverage_ready"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.runtimeMode.displayLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaPrivateAIRuntimeCoverageSummary(status))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                }
                .padding(.vertical, 2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(rossLocalized("private_assistant_runtime_next_steps_title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                if nextSteps.isEmpty {
                    Text(rossLocalized("private_assistant_runtime_next_steps_ready"))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(nextSteps.enumerated()), id: \.offset) { _, step in
                        Text(step)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct AlphaPrivateAISmokeRuntimeSummarySection: View {
    let reports: [AlphaLocalInferenceSmokeReport]

    private var latestReports: [AlphaLocalInferenceSmokeReport] {
        alphaLocalInferenceSmokeLatestReportsByRuntime(reports)
    }

    private var missingRuntimeLabels: String? {
        let labels = alphaLocalInferenceSmokeMissingRuntimeLabels(reports)
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_sample_runtime_summary_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            if let missingRuntimeLabels {
                Text(String(format: rossLocalized("private_assistant_sample_runtime_summary_missing"), missingRuntimeLabels))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(rossLocalized("private_assistant_sample_runtime_summary_ready"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(latestReports.enumerated()), id: \.offset) { _, report in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaLocalInferenceSmokeMetricsSummary(report))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))

                    Text(report.message)
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct AlphaMatterBundleComparisonRuntimeSummarySection: View {
    let reports: [AlphaMatterBundleComparisonReport]

    private var latestReports: [AlphaMatterBundleComparisonReport] {
        alphaMatterBundleLatestReportsByRuntime(reports)
    }

    private var missingRuntimeLabels: String? {
        let labels = alphaMatterBundleMissingRuntimeLabels(reports)
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ", ")
    }

    private var decisionHints: [String] {
        alphaMatterBundleDecisionHints(reports)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_runtime_summary_title"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            if let missingRuntimeLabels {
                Text(String(format: rossLocalized("private_assistant_runtime_summary_missing"), missingRuntimeLabels))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(rossLocalized("private_assistant_runtime_summary_ready"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(latestReports.enumerated()), id: \.offset) { _, report in
                VStack(alignment: .leading, spacing: 4) {
                    Text(alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    Text(alphaMatterBundleComparisonMetricsSummary(report))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))

                    if let runtimeSelectionReason = report.runtimeSelectionReason?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !runtimeSelectionReason.isEmpty {
                        Text(runtimeSelectionReason)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }

            if !decisionHints.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(rossLocalized("private_assistant_runtime_summary_readout"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk)

                    ForEach(Array(decisionHints.enumerated()), id: \.offset) { _, hint in
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct AlphaMatterBundleComparisonHistorySection: View {
    let reports: [AlphaMatterBundleComparisonReport]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("private_assistant_matter_bundle_check_recent_runs"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)

            ForEach(Array(reports.prefix(AlphaRossModel.matterBundleComparisonHistoryLimit - 1).enumerated()), id: \.offset) { _, report in
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        "\(report.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(alphaMatterBundleComparisonStatusLabel(report)) · \(alphaLocalInferenceSmokeRuntimeLabel(report.runtimeUsed))"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                    Text(alphaMatterBundleComparisonMetricsSummary(report))
                        .font(.caption2)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                }
                .padding(.vertical, 2)
            }
        }
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

func alphaAssistantFirstResponseLabel(milliseconds: Int) -> String {
    alphaAssistantDurationLabel(milliseconds: milliseconds)
}

func alphaAssistantTokenRateLabel(tokensPerSecond: Double) -> String {
    let clamped = max(tokensPerSecond, 0)
    if clamped >= 10 {
        return String(format: "%.0f tok/s", clamped)
    }
    return String(format: "%.1f tok/s", clamped)
}

func alphaAssistantContextWindowLabel(tokens: Int) -> String {
    "\(tokens.formatted()) tokens"
}

func alphaAssistantInputBudgetLabel(chars: Int) -> String {
    "\(chars.formatted()) chars"
}

func alphaLocalInferenceSmokeRuntimeLabel(_ runtimeRawValue: String) -> String {
    AlphaPackRuntimeMode(rawValue: runtimeRawValue)?.displayLabel ?? runtimeRawValue
}

func alphaLocalInferenceSmokeStatusLabel(_ report: AlphaLocalInferenceSmokeReport) -> String {
    report.ran ? rossLocalized("completed") : rossLocalized("not_run")
}

func alphaLocalInferenceSmokeMetricsSummary(_ report: AlphaLocalInferenceSmokeReport) -> String {
    var parts = [
        String(format: rossLocalized("fields_found_count"), report.fieldsFound),
        String(format: rossLocalized("fields_verified_count"), report.fieldsVerified)
    ]
    if let timeToFirstTokenMs = report.timeToFirstTokenMs {
        parts.append("\(rossLocalized("runtime_first_response")): \(alphaAssistantFirstResponseLabel(milliseconds: timeToFirstTokenMs))")
    }
    if let estimatedOutputTokensPerSecond = report.estimatedOutputTokensPerSecond {
        parts.append("\(rossLocalized("runtime_output_speed")): \(alphaAssistantTokenRateLabel(tokensPerSecond: estimatedOutputTokensPerSecond))")
    }
    return parts.joined(separator: " · ")
}

func alphaLocalInferenceSmokeLatestReportsByRuntime(_ reports: [AlphaLocalInferenceSmokeReport]) -> [AlphaLocalInferenceSmokeReport] {
    var latestByRuntime: [AlphaPackRuntimeMode: AlphaLocalInferenceSmokeReport] = [:]
    for report in reports {
        guard let runtimeMode = AlphaPackRuntimeMode(rawValue: report.runtimeUsed) else { continue }
        if latestByRuntime[runtimeMode] == nil {
            latestByRuntime[runtimeMode] = report
        }
    }
    let orderedModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]
    return orderedModes.compactMap { latestByRuntime[$0] }
}

func alphaLocalInferenceSmokeMissingRuntimeLabels(_ reports: [AlphaLocalInferenceSmokeReport]) -> [String] {
    let presentModes = Set(alphaLocalInferenceSmokeLatestReportsByRuntime(reports).compactMap { AlphaPackRuntimeMode(rawValue: $0.runtimeUsed) })
    let requiredModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]
    return requiredModes
        .filter { !presentModes.contains($0) }
        .map(\.displayLabel)
}

struct AlphaPrivateAIRuntimeCoverageStatus: Hashable {
    let runtimeMode: AlphaPackRuntimeMode
    let latestSmokeReport: AlphaLocalInferenceSmokeReport?
    let latestComparisonReport: AlphaMatterBundleComparisonReport?

    var hasSampleProof: Bool { latestSmokeReport != nil }
    var hasLongerBundleProof: Bool { latestComparisonReport != nil }
}

enum AlphaPrivateAIDeviceComparisonProofTarget: CaseIterable, Hashable {
    case class8GB
    case class12GBOrHigher

    var localizedLabel: String {
        switch self {
        case .class8GB:
            return rossLocalized("private_assistant_device_representative_class_8gb")
        case .class12GBOrHigher:
            return rossLocalized("private_assistant_device_representative_class_12gb")
        }
    }

    var representativeClass: AlphaPrivateAIDeviceProofRepresentativeClass {
        switch self {
        case .class8GB:
            return .class8GB
        case .class12GBOrHigher:
            return .class12GBOrHigher
        }
    }
}

struct AlphaPrivateAIDeviceComparisonProofStatus: Hashable {
    let target: AlphaPrivateAIDeviceComparisonProofTarget
    let latestSavedRecord: AlphaPrivateAIDeviceComparisonProofRecord?
}

enum AlphaPrivateAIRuntimeLaneReadinessState: Hashable {
    case activeNow
    case readyNow
    case needsSetup
    case needsRepair
    case builtInUnavailable
    case unavailableOnThisIPhone
}

struct AlphaPrivateAIRuntimeLaneReadinessStatus: Hashable {
    let runtimeMode: AlphaPackRuntimeMode
    let state: AlphaPrivateAIRuntimeLaneReadinessState
}

func alphaAssistantRuntimeSupportedOnCurrentDevice(
    runtimeMode: AlphaPackRuntimeMode,
    tier: AlphaCapabilityTier,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    systemAssistantAvailable: Bool
) -> Bool {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    switch runtimeMode {
    case .appleFoundationModels:
        return systemAssistantAvailable
    case .mlxSwiftLm:
        return alphaAssistantTierSupportsMLXRuntime(normalizedTier)
    case .llamaCppGguf:
        guard isPhoneFormFactor else { return true }
        let artifact = alphaAssistantModelArtifact(for: normalizedTier)
        let minimumMemoryBytes = UInt64(artifact.minimumMemoryGB) * 1_073_741_824
        return physicalMemoryBytes >= minimumMemoryBytes
    case .deterministicDev, .mediapipeLlm, .unavailable:
        return false
    }
}

func alphaPrivateAIRuntimeLaneReadinessStatuses(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack],
    activePack: AlphaInstalledModelPack?,
    systemAssistantAvailable: Bool,
    canActivateRuntime: (AlphaPackRuntimeMode) -> Bool
) -> [AlphaPrivateAIRuntimeLaneReadinessStatus] {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    let orderedModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]

    return orderedModes.map { runtimeMode in
        let installedPack = installedPacks.first {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, normalizedTier) &&
                $0.runtimeMode == runtimeMode
        }
        let isActive = activePack?.runtimeMode == runtimeMode &&
            AlphaCapabilityTier.assistantSelectionsMatch(activePack?.tier, normalizedTier)
        let canActivate = canActivateRuntime(runtimeMode)
        let supportedOnCurrentDevice = alphaAssistantRuntimeSupportedOnCurrentDevice(
            runtimeMode: runtimeMode,
            tier: normalizedTier,
            systemAssistantAvailable: systemAssistantAvailable
        )

        let state: AlphaPrivateAIRuntimeLaneReadinessState
        if isActive && canActivate {
            state = .activeNow
        } else if canActivate {
            state = .readyNow
        } else if runtimeMode == .appleFoundationModels {
            state = systemAssistantAvailable ? .readyNow : .builtInUnavailable
        } else if !supportedOnCurrentDevice {
            state = .unavailableOnThisIPhone
        } else if installedPack != nil {
            state = .needsRepair
        } else {
            state = .needsSetup
        }

        return AlphaPrivateAIRuntimeLaneReadinessStatus(runtimeMode: runtimeMode, state: state)
    }
}

func alphaPrivateAIRuntimeLaneReadinessSummary(_ status: AlphaPrivateAIRuntimeLaneReadinessStatus) -> String {
    switch status.state {
    case .activeNow:
        return rossLocalized("private_assistant_runtime_lane_active_now")
    case .readyNow:
        return rossLocalized("private_assistant_runtime_lane_ready_now")
    case .needsSetup:
        return rossLocalized("private_assistant_runtime_lane_needs_setup")
    case .needsRepair:
        return rossLocalized("private_assistant_runtime_lane_needs_repair")
    case .builtInUnavailable:
        return rossLocalized("private_assistant_runtime_lane_built_in_unavailable")
    case .unavailableOnThisIPhone:
        return rossLocalized("private_assistant_runtime_lane_unavailable_on_this_iphone")
    }
}

func alphaPrivateAIDeviceComparisonProofStatuses(
    _ records: [AlphaPrivateAIDeviceComparisonProofRecord]
) -> [AlphaPrivateAIDeviceComparisonProofStatus] {
    AlphaPrivateAIDeviceComparisonProofTarget.allCases.map { target in
        let latestSavedRecord = records
            .filter { record in
                record.profile.captureSource == .physicalIPhone &&
                    record.profile.representativeClass == target.representativeClass
            }
            .max(by: { lhs, rhs in
                lhs.createdAt < rhs.createdAt
            })
        return AlphaPrivateAIDeviceComparisonProofStatus(
            target: target,
            latestSavedRecord: latestSavedRecord
        )
    }
}

func alphaPrivateAIDeviceComparisonProofSummary(_ status: AlphaPrivateAIDeviceComparisonProofStatus) -> String {
    guard let latestSavedRecord = status.latestSavedRecord else {
        return rossLocalized("private_assistant_device_comparison_not_saved")
    }

    if latestSavedRecord.runtimeCoverageComplete && latestSavedRecord.downloadDeliveryVerified {
        return String(
            format: rossLocalized("private_assistant_device_comparison_saved_complete_with_delivery"),
            latestSavedRecord.profile.deviceModelLabel
        )
    }

    if latestSavedRecord.runtimeCoverageComplete && !latestSavedRecord.downloadDeliveryVerified {
        return String(
            format: rossLocalized("private_assistant_device_comparison_saved_missing_delivery"),
            latestSavedRecord.profile.deviceModelLabel
        )
    }

    let missingLabels = latestSavedRecord.missingRuntimeCoverageLabels.joined(separator: ", ")
    if !missingLabels.isEmpty && !latestSavedRecord.downloadDeliveryVerified {
        return String(
            format: rossLocalized("private_assistant_device_comparison_saved_missing_runtime_and_delivery"),
            latestSavedRecord.profile.deviceModelLabel,
            missingLabels
        )
    }

    if !missingLabels.isEmpty {
        return String(
            format: rossLocalized("private_assistant_device_comparison_saved_missing_runtime"),
            latestSavedRecord.profile.deviceModelLabel,
            missingLabels
        )
    }

    return String(
        format: rossLocalized("private_assistant_device_comparison_saved_partial"),
        latestSavedRecord.profile.deviceModelLabel
    )
}

func alphaPrivateAIDeviceComparisonSavedDeliveryStatus(
    _ record: AlphaPrivateAIDeviceComparisonProofRecord
) -> String? {
    let trimmed = record.downloadDeliveryStatusLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

func alphaPrivateAIDeviceComparisonSavedCapturedAt(
    _ record: AlphaPrivateAIDeviceComparisonProofRecord
) -> String {
    record.createdAt.formatted(date: .abbreviated, time: .shortened)
}

func alphaPrivateAIDeviceComparisonSavedFileName(
    _ record: AlphaPrivateAIDeviceComparisonProofRecord
) -> String? {
    let trimmed = record.exportRelativePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else { return nil }
    return URL(fileURLWithPath: trimmed).lastPathComponent
}

func alphaPrivateAIDeviceComparisonSavedDeviceStateSummary(
    _ record: AlphaPrivateAIDeviceComparisonProofRecord
) -> String {
    [
        "\(record.profile.freeStorageGB) GB free",
        "\(rossLocalized("private_assistant_device_low_power_label")): \(record.profile.lowPowerModeEnabled ? rossLocalized("yes") : rossLocalized("no"))",
        "\(rossLocalized("private_assistant_device_thermal_label")): \(record.profile.thermalCondition)"
    ].joined(separator: " · ")
}

func alphaPrivateAIDeviceComparisonSavedDeliveryContract(
    _ record: AlphaPrivateAIDeviceComparisonProofRecord
) -> String? {
    let trimmed = record.downloadDeliveryContractLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

func alphaPrivateAIDeviceComparisonMissingTargetLabels(
    _ records: [AlphaPrivateAIDeviceComparisonProofRecord]
) -> [String] {
    alphaPrivateAIDeviceComparisonProofStatuses(records).compactMap { status in
        guard let latestSavedRecord = status.latestSavedRecord else {
            return status.target.localizedLabel
        }
        return latestSavedRecord.runtimeCoverageComplete && latestSavedRecord.downloadDeliveryVerified
            ? nil
            : status.target.localizedLabel
    }
}

func alphaPrivateAIDeviceComparisonRerunStep(
    target: AlphaPrivateAIDeviceComparisonProofTarget,
    latestSavedRecord: AlphaPrivateAIDeviceComparisonProofRecord
) -> String {
    let missingLabels = latestSavedRecord.missingRuntimeCoverageLabels.joined(separator: ", ")
    if !missingLabels.isEmpty && !latestSavedRecord.downloadDeliveryVerified {
        return String(
            format: rossLocalized("private_assistant_device_comparison_next_step_rerun_missing_runtime_and_delivery"),
            target.localizedLabel,
            latestSavedRecord.profile.deviceModelLabel,
            missingLabels
        )
    }

    if !missingLabels.isEmpty {
        return String(
            format: rossLocalized("private_assistant_device_comparison_next_step_rerun_missing_runtime"),
            target.localizedLabel,
            latestSavedRecord.profile.deviceModelLabel,
            missingLabels
        )
    }

    if !latestSavedRecord.downloadDeliveryVerified {
        return String(
            format: rossLocalized("private_assistant_device_comparison_next_step_rerun_missing_delivery"),
            target.localizedLabel,
            latestSavedRecord.profile.deviceModelLabel
        )
    }

    return String(
        format: rossLocalized("private_assistant_device_comparison_next_step_rerun"),
        target.localizedLabel,
        latestSavedRecord.profile.deviceModelLabel
    )
}

func alphaPrivateAIDeviceComparisonNextSteps(
    _ records: [AlphaPrivateAIDeviceComparisonProofRecord]
) -> [String] {
    alphaPrivateAIDeviceComparisonProofStatuses(records).compactMap { status in
        switch status.target {
        case .class8GB:
            guard let latestSavedRecord = status.latestSavedRecord else {
                return rossLocalized("private_assistant_device_comparison_next_step_save_8gb")
            }
            guard !(latestSavedRecord.runtimeCoverageComplete && latestSavedRecord.downloadDeliveryVerified) else { return nil }
            return alphaPrivateAIDeviceComparisonRerunStep(
                target: status.target,
                latestSavedRecord: latestSavedRecord
            )
        case .class12GBOrHigher:
            guard let latestSavedRecord = status.latestSavedRecord else {
                return rossLocalized("private_assistant_device_comparison_next_step_save_12gb")
            }
            guard !(latestSavedRecord.runtimeCoverageComplete && latestSavedRecord.downloadDeliveryVerified) else { return nil }
            return alphaPrivateAIDeviceComparisonRerunStep(
                target: status.target,
                latestSavedRecord: latestSavedRecord
            )
        }
    }
}

func alphaPrivateAIDeviceComparisonDecisionReadinessSummary(
    _ records: [AlphaPrivateAIDeviceComparisonProofRecord]
) -> String {
    let missingTargetLabels = alphaPrivateAIDeviceComparisonMissingTargetLabels(records)
    if missingTargetLabels.isEmpty {
        return rossLocalized("private_assistant_ladder_decision_ready")
    }
    return String(
        format: rossLocalized("private_assistant_ladder_decision_waiting"),
        missingTargetLabels.joined(separator: ", ")
    )
}

func alphaPrivateAIRuntimeCoverageStatuses(
    smokeReports: [AlphaLocalInferenceSmokeReport],
    comparisonReports: [AlphaMatterBundleComparisonReport]
) -> [AlphaPrivateAIRuntimeCoverageStatus] {
    let latestSmokeByRuntime = Dictionary(
        uniqueKeysWithValues: alphaLocalInferenceSmokeLatestReportsByRuntime(smokeReports).compactMap { report in
            AlphaPackRuntimeMode(rawValue: report.runtimeUsed).map { ($0, report) }
        }
    )
    let latestComparisonByRuntime = Dictionary(
        uniqueKeysWithValues: alphaMatterBundleLatestReportsByRuntime(comparisonReports).compactMap { report in
            AlphaPackRuntimeMode(rawValue: report.runtimeUsed).map { ($0, report) }
        }
    )
    let orderedModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]
    return orderedModes.map { runtimeMode in
        AlphaPrivateAIRuntimeCoverageStatus(
            runtimeMode: runtimeMode,
            latestSmokeReport: latestSmokeByRuntime[runtimeMode],
            latestComparisonReport: latestComparisonByRuntime[runtimeMode]
        )
    }
}

func alphaPrivateAIRuntimeCoverageMissingLabels(
    smokeReports: [AlphaLocalInferenceSmokeReport],
    comparisonReports: [AlphaMatterBundleComparisonReport]
) -> [String] {
    alphaPrivateAIRuntimeCoverageStatuses(
        smokeReports: smokeReports,
        comparisonReports: comparisonReports
    ).compactMap { status in
        switch (status.hasSampleProof, status.hasLongerBundleProof) {
        case (true, true):
            return nil
        case (false, false):
            return String(
                format: rossLocalized("private_assistant_runtime_coverage_missing_both"),
                status.runtimeMode.displayLabel
            )
        case (false, true):
            return String(
                format: rossLocalized("private_assistant_runtime_coverage_missing_sample"),
                status.runtimeMode.displayLabel
            )
        case (true, false):
            return String(
                format: rossLocalized("private_assistant_runtime_coverage_missing_bundle"),
                status.runtimeMode.displayLabel
            )
        }
    }
}

func alphaPrivateAIRuntimeCoverageSummary(_ status: AlphaPrivateAIRuntimeCoverageStatus) -> String {
    [
        "\(rossLocalized("private_assistant_sample_file_short_label")): \(status.hasSampleProof ? rossLocalized("completed") : rossLocalized("not_run"))",
        "\(rossLocalized("private_assistant_longer_bundle_short_label")): \(status.hasLongerBundleProof ? rossLocalized("completed") : rossLocalized("not_run"))"
    ].joined(separator: " · ")
}

func alphaPrivateAIRuntimeCoverageNextSteps(
    smokeReports: [AlphaLocalInferenceSmokeReport],
    comparisonReports: [AlphaMatterBundleComparisonReport]
) -> [String] {
    alphaPrivateAIRuntimeCoverageStatuses(
        smokeReports: smokeReports,
        comparisonReports: comparisonReports
    ).compactMap { status in
        switch (status.hasSampleProof, status.hasLongerBundleProof) {
        case (true, true):
            return nil
        case (false, false):
            return String(
                format: rossLocalized("private_assistant_runtime_next_step_run_sample_then_bundle"),
                status.runtimeMode.displayLabel
            )
        case (false, true):
            return String(
                format: rossLocalized("private_assistant_runtime_next_step_run_sample"),
                status.runtimeMode.displayLabel
            )
        case (true, false):
            return String(
                format: rossLocalized("private_assistant_runtime_next_step_run_bundle"),
                status.runtimeMode.displayLabel
            )
        }
    }
}

func alphaMatterBundleComparisonStatusLabel(_ report: AlphaMatterBundleComparisonReport) -> String {
    report.ran ? rossLocalized("completed") : rossLocalized("not_run")
}

func alphaMatterBundleComparisonMetricsSummary(_ report: AlphaMatterBundleComparisonReport) -> String {
    var parts = [
        String(format: rossLocalized("selected_files_count"), report.selectedDocumentCount),
        String(format: rossLocalized("source_blocks_count"), report.sourceBlockCount),
        String(format: rossLocalized("source_refs_count"), report.sourceRefsReturned)
    ]
    if let executionPathLabel = report.executionPathLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
       !executionPathLabel.isEmpty {
        parts.append(executionPathLabel)
    }
    if let timeToFirstTokenMs = report.timeToFirstTokenMs {
        parts.append("\(rossLocalized("runtime_first_response")): \(alphaAssistantFirstResponseLabel(milliseconds: timeToFirstTokenMs))")
    }
    if let estimatedOutputTokensPerSecond = report.estimatedOutputTokensPerSecond {
        parts.append("\(rossLocalized("runtime_output_speed")): \(alphaAssistantTokenRateLabel(tokensPerSecond: estimatedOutputTokensPerSecond))")
    }
    return parts.joined(separator: " · ")
}

func alphaMatterBundleLatestReportsByRuntime(_ reports: [AlphaMatterBundleComparisonReport]) -> [AlphaMatterBundleComparisonReport] {
    var latestByRuntime: [AlphaPackRuntimeMode: AlphaMatterBundleComparisonReport] = [:]
    for report in reports {
        guard let runtimeMode = AlphaPackRuntimeMode(rawValue: report.runtimeUsed) else { continue }
        if latestByRuntime[runtimeMode] == nil {
            latestByRuntime[runtimeMode] = report
        }
    }
    let orderedModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]
    return orderedModes.compactMap { latestByRuntime[$0] }
}

func alphaMatterBundleMissingRuntimeLabels(_ reports: [AlphaMatterBundleComparisonReport]) -> [String] {
    let presentModes = Set(alphaMatterBundleLatestReportsByRuntime(reports).compactMap { AlphaPackRuntimeMode(rawValue: $0.runtimeUsed) })
    let requiredModes: [AlphaPackRuntimeMode] = [.appleFoundationModels, .mlxSwiftLm, .llamaCppGguf]
    return requiredModes
        .filter { !presentModes.contains($0) }
        .map(\.displayLabel)
}

func alphaMatterBundleDecisionHints(_ reports: [AlphaMatterBundleComparisonReport]) -> [String] {
    let latestReports = alphaMatterBundleLatestReportsByRuntime(reports)
    guard latestReports.count >= 2 else { return [] }

    var hints: [String] = []

    if let fastestFirstResponse = latestReports
        .filter({ $0.timeToFirstTokenMs != nil })
        .min(by: { ($0.timeToFirstTokenMs ?? .max) < ($1.timeToFirstTokenMs ?? .max) }),
       let firstResponseMs = fastestFirstResponse.timeToFirstTokenMs {
        hints.append(
            String(
                format: rossLocalized("private_assistant_runtime_summary_fastest_first_response"),
                alphaLocalInferenceSmokeRuntimeLabel(fastestFirstResponse.runtimeUsed),
                alphaAssistantFirstResponseLabel(milliseconds: firstResponseMs)
            )
        )
    }

    if let fastestTokenSpeed = latestReports
        .filter({ $0.estimatedOutputTokensPerSecond != nil })
        .max(by: { ($0.estimatedOutputTokensPerSecond ?? 0) < ($1.estimatedOutputTokensPerSecond ?? 0) }),
       let tokenSpeed = fastestTokenSpeed.estimatedOutputTokensPerSecond {
        hints.append(
            String(
                format: rossLocalized("private_assistant_runtime_summary_fastest_token_speed"),
                alphaLocalInferenceSmokeRuntimeLabel(fastestTokenSpeed.runtimeUsed),
                alphaAssistantTokenRateLabel(tokensPerSecond: tokenSpeed)
            )
        )
    }

    if let broadestCoverage = latestReports.max(by: { lhs, rhs in
        let lhsScore = (lhs.sourceRefsReturned, lhs.sourceBlockCount)
        let rhsScore = (rhs.sourceRefsReturned, rhs.sourceBlockCount)
        return lhsScore < rhsScore
    }) {
        hints.append(
            String(
                format: rossLocalized("private_assistant_runtime_summary_broadest_coverage"),
                alphaLocalInferenceSmokeRuntimeLabel(broadestCoverage.runtimeUsed),
                broadestCoverage.sourceRefsReturned,
                broadestCoverage.sourceBlockCount
            )
        )
    }

    if let cleanestRun = latestReports.first(where: {
        $0.schemaValid && ($0.needsReviewWarning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }) {
        hints.append(
            String(
                format: rossLocalized("private_assistant_runtime_summary_cleanest_run"),
                alphaLocalInferenceSmokeRuntimeLabel(cleanestRun.runtimeUsed)
            )
        )
    }

    return hints
}

func alphaAssistantComparisonRuntimeOptions(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack],
    activePack: AlphaInstalledModelPack?,
    systemAssistantAvailable: Bool,
    preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]? = nil,
    canActivateRuntime: (AlphaPackRuntimeMode) -> Bool
) -> [AlphaAssistantVariantOption] {
    alphaAssistantVariantOptions(
        for: tier,
        installedPacks: installedPacks,
        activePack: activePack,
        systemAssistantAvailable: systemAssistantAvailable,
        preferredRuntimeMode: preferredRuntimeMode,
        cachedCatalogs: cachedCatalogs,
        cachedDownloads: cachedDownloads
    )
    .filter { canActivateRuntime($0.runtimeMode) }
}

func alphaAssistantAccelerationLabel(
    mode: AlphaLocalRuntimeAccelerationMode?,
    draftTokens: Int?,
    draftLabel: String?,
    emptyFallback: String? = nil
) -> String? {
    let cleanedDraftLabel = draftLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

    switch mode {
    case .draftModelSpeculative:
        if let tokens = draftTokens, let cleanedDraftLabel {
            return "Draft model x\(tokens) (\(cleanedDraftLabel))"
        }
        if let cleanedDraftLabel {
            return "Draft model (\(cleanedDraftLabel))"
        }
        if let tokens = draftTokens {
            return "Draft model x\(tokens)"
        }
        return "Draft model"
    case .standard:
        if let cleanedDraftLabel {
            return "Standard generation (draft head ready: \(cleanedDraftLabel))"
        }
        if draftTokens != nil {
            return "Standard generation (draft head ready)"
        }
        return "Standard generation"
    case nil:
        return emptyFallback
    }
}

func alphaAssistantAccelerationLabel(runtimeHealth: AlphaLocalRuntimeHealth) -> String {
    alphaAssistantAccelerationLabel(
        mode: runtimeHealth.accelerationMode,
        draftTokens: runtimeHealth.accelerationDraftTokens,
        draftLabel: runtimeHealth.draftModelPathLabel,
        emptyFallback: rossLocalized("none_yet")
    ) ?? rossLocalized("none_yet")
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

    private var mobileAllowed: Bool {
        model.persisted.settings.allowMobileDataForLargePacks || offer.tier == .quickStart
    }

    private var latestJob: AlphaModelDownloadJob? {
        model.persisted.modelJobs.first {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, offer.tier)
        }
    }

    private var installedPack: AlphaInstalledModelPack? {
        model.installedPack(for: offer.tier)
    }

    private var variantOptions: [AlphaAssistantVariantOption] {
        alphaAssistantVariantOptions(
            for: offer.tier,
            installedPacks: model.privateAISnapshot.installedPacks,
            activePack: model.activePack,
            systemAssistantAvailable: systemAssistantAvailable,
            preferredRuntimeMode: setupPresentation?.runtimeMode,
            cachedCatalogs: model.persisted.cachedAssistantCatalogs,
            cachedDownloads: model.persisted.cachedAssistantDownloads
        )
    }

    private var preferredInstalledPack: AlphaInstalledModelPack? {
        alphaAssistantPreferredInstalledPack(
            variantOptions: variantOptions,
            preferredRuntimeMode: setupPresentation?.runtimeMode
        )
    }

    private var systemAssistantAvailable: Bool {
        model.systemAssistantHealth(for: offer.tier)?.available == true
    }

    private var setupPresentation: AlphaAssistantSetupPresentation? {
        model.assistantSetupPresentation(for: offer.tier)
    }

    private var isActive: Bool {
        guard let activePack = model.activePack else { return false }
        return AlphaCapabilityTier.assistantSelectionsMatch(activePack.tier, offer.tier) &&
            (!activePack.developmentOnly || alphaAllowsDevelopmentModelArtifacts()) &&
            model.activeRuntimeHealth?.available == true
    }

    private var activeButRuntimeUnavailable: Bool {
        guard let activePack = model.activePack else { return false }
        return AlphaCapabilityTier.assistantSelectionsMatch(activePack.tier, offer.tier) &&
            (!activePack.developmentOnly || !alphaAllowsDevelopmentModelArtifacts()) &&
            model.activeRuntimeHealth?.available != true
    }

    private var isInstalledButInactive: Bool {
        installedPack != nil && !isActive && !activeButRuntimeUnavailable
    }

    private var prefersBuiltInActivation: Bool {
        alphaAssistantOfferPrefersBuiltInActivation(
            preferredRuntimeMode: setupPresentation?.runtimeMode,
            systemAssistantAvailable: systemAssistantAvailable,
            isActive: isActive,
            activeButRuntimeUnavailable: activeButRuntimeUnavailable
        )
    }

    private var runtimeChoiceLabel: String? {
        guard let runtimeMode = setupPresentation?.runtimeMode else { return nil }
        let label = alphaAssistantRuntimeChoiceLabel(
            selectedRuntimeMode: runtimeMode,
            tier: offer.tier,
            existingRuntimeMode: installedPack?.runtimeMode,
            systemAssistantAvailable: systemAssistantAvailable,
            lastInvocation: model.lastModelInvocation
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    private var runtimeTradeoffHint: String? {
        guard let runtimeMode = setupPresentation?.runtimeMode else { return nil }
        return alphaAssistantRuntimeTradeoffHint(
            selectedRuntimeMode: runtimeMode,
            tier: offer.tier
        )
    }

    private var builtInAlternativeHint: String? {
        alphaAssistantBuiltInAlternativeHint(
            selectedRuntimeMode: setupPresentation?.runtimeMode,
            systemAssistantAvailable: systemAssistantAvailable
        )
    }

    private var showsBuiltInQuickAction: Bool {
        builtInAlternativeHint != nil
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
        if prefersBuiltInActivation {
            return (alphaAssistantOfferBadge(.builtIn), Color.rossAccent)
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
        if offer.tier == model.recommendedAssistantSetupTier() {
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
        if targetsCurrentAskUpgrade {
            return alphaAssistantOfferAction(.useForThisAsk)
        }
        if prefersBuiltInActivation {
            return alphaAssistantOfferAction(.useOnThisIPhone)
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

    private var targetsCurrentAskUpgrade: Bool {
        alphaAssistantOfferTargetsCurrentAskUpgrade(
            expectedTier: model.pendingAskUpgradeExpectedTier,
            expectedRuntimeMode: model.pendingAskUpgradeExpectedRuntimeMode,
            offerTier: offer.tier,
            offerRuntimeMode: setupPresentation?.runtimeMode,
            currentRoute: model.path.last
        )
    }

    private var actionDisabled: Bool {
        isActive || (isSettingUp && !prefersBuiltInActivation)
    }

    private func activateVariant(_ option: AlphaAssistantVariantOption) {
        guard !option.isSelected else { return }
        if option.runtimeMode == .appleFoundationModels {
            Task {
                await model.startPackDownload(
                    for: offer.tier,
                    mobileAllowed: mobileAllowed,
                    requestedRuntimeMode: .appleFoundationModels
                )
            }
        } else if let pack = option.pack {
            model.activateInstalledPack(pack)
        } else {
            model.setAssistantSetupRuntimeOverride(option.runtimeMode, for: offer.tier)
        }
    }

    private func activateBuiltInAlternative() {
        Task {
            await model.startPackDownload(
                for: offer.tier,
                mobileAllowed: mobileAllowed,
                requestedRuntimeMode: .appleFoundationModels
            )
        }
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

                if prefersBuiltInActivation {
                    AlphaAssistantBuiltInMetaLabels(
                        speedLabel: setupPresentation?.speedLabel,
                        contextLabel: setupPresentation?.contextLabel,
                        font: .caption2.weight(.medium)
                    )
                        .padding(.top, 2)
                } else {
                    AlphaAssistantSetupMetaLabels(
                        sizeLabel: setupPresentation?.sizeLabel ?? rossLocalized("assistant_state_checking"),
                        runtimeLabel: setupPresentation?.runtimeMode.displayLabel,
                        speedLabel: setupPresentation?.speedLabel,
                        contextLabel: setupPresentation?.contextLabel,
                        companionLabel: setupPresentation?.companionLabel,
                        etaLabel: setupPresentation?.etaLabel,
                        freeSpaceLabel: model.freeDiskSpaceLabel,
                        font: .caption2.weight(.medium)
                    )
                    .padding(.top, 2)
                }

                if let runtimeChoiceLabel {
                    Text(runtimeChoiceLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                if let runtimeTradeoffHint {
                    Text(runtimeTradeoffHint)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let builtInAlternativeHint {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(builtInAlternativeHint)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)

                        if showsBuiltInQuickAction {
                            HStack {
                                Button {
                                    activateBuiltInAlternative()
                                } label: {
                                    Label(alphaAssistantOfferAction(.useOnThisIPhone), systemImage: "iphone")
                                }
                                .rossSecondaryButtonStyle()

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                if variantOptions.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rossLocalized("assistant_available_runtimes"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.60))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(variantOptions) { option in
                                    AlphaAssistantVariantChip(
                                        option: option,
                                        action: { activateVariant(option) }
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if !prefersBuiltInActivation,
               let latestJob,
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
            } else if prefersBuiltInActivation {
                Text(rossLocalized("assistant_built_in_offer_detail"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(actionTitle) {
                Task {
                    if activeButRuntimeUnavailable {
                        await model.repairAssistantPack(
                            for: offer.tier,
                            mobileAllowed: mobileAllowed
                        )
                    } else if prefersBuiltInActivation {
                        await model.startPackDownload(
                            for: offer.tier,
                            mobileAllowed: mobileAllowed,
                            requestedRuntimeMode: .appleFoundationModels
                        )
                    } else if let preferredInstalledPack {
                        model.activateInstalledPack(preferredInstalledPack)
                    } else if let latestJob, canResume {
                        model.resumeJob(latestJob)
                    } else {
                        await model.startPackDownload(
                            for: offer.tier,
                            mobileAllowed: mobileAllowed,
                            requestedRuntimeMode: setupPresentation?.runtimeMode
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

func alphaAssistantOfferPrefersBuiltInActivation(
    preferredRuntimeMode: AlphaPackRuntimeMode?,
    systemAssistantAvailable: Bool,
    isActive: Bool,
    activeButRuntimeUnavailable: Bool
) -> Bool {
    guard systemAssistantAvailable, !isActive, !activeButRuntimeUnavailable else {
        return false
    }
    return preferredRuntimeMode == .appleFoundationModels
}

func alphaAssistantOfferTargetsCurrentAskUpgrade(
    expectedTier: AlphaCapabilityTier?,
    expectedRuntimeMode: AlphaPackRuntimeMode?,
    offerTier: AlphaCapabilityTier,
    offerRuntimeMode: AlphaPackRuntimeMode?,
    currentRoute: AlphaRoute?
) -> Bool {
    guard alphaAskUpgradeSetupSummary(
        expectedTier: expectedTier,
        expectedRuntimeMode: expectedRuntimeMode,
        currentRoute: currentRoute
    ) != nil else {
        return false
    }
    guard let expectedTier,
          AlphaCapabilityTier.assistantSelectionsMatch(offerTier, expectedTier),
          let offerRuntimeMode else {
        return false
    }
    if let expectedRuntimeMode {
        return offerRuntimeMode == expectedRuntimeMode
    }
    return true
}

struct AlphaAssistantVariantOption: Identifiable, Hashable, Sendable {
    let pack: AlphaInstalledModelPack?
    let runtimeMode: AlphaPackRuntimeMode
    let isActive: Bool
    let isBuiltIn: Bool
    let isSelected: Bool
    let detailLabel: String?

    var id: String {
        if let pack {
            return pack.id.uuidString
        }
        return "\(isBuiltIn ? "system" : "setup")-\(runtimeMode.rawValue)"
    }
}

func alphaAssistantVariantOptions(
    for tier: AlphaCapabilityTier,
    installedPacks: [AlphaInstalledModelPack],
    activePack: AlphaInstalledModelPack?,
    systemAssistantAvailable: Bool,
    preferredRuntimeMode: AlphaPackRuntimeMode? = nil,
    cachedCatalogs: [AlphaAssistantCatalogDescriptor]? = nil,
    cachedDownloads: [AlphaAssistantDownloadDescriptor]? = nil,
    isPhoneFormFactor: Bool = alphaAssistantUsesPhoneFormFactor(),
    physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
) -> [AlphaAssistantVariantOption] {
    let normalizedTier = AlphaCapabilityTier.normalizedAssistantSelection(tier) ?? tier
    func runtimeSupported(_ runtimeMode: AlphaPackRuntimeMode) -> Bool {
        alphaAssistantRuntimeSupportedOnCurrentDevice(
            runtimeMode: runtimeMode,
            tier: normalizedTier,
            isPhoneFormFactor: isPhoneFormFactor,
            physicalMemoryBytes: physicalMemoryBytes,
            systemAssistantAvailable: systemAssistantAvailable
        )
    }
    var options = installedPacks
        .filter {
            AlphaCapabilityTier.assistantSelectionsMatch($0.tier, normalizedTier) &&
                runtimeSupported($0.runtimeMode)
        }
        .map { pack in
            let isActive = activePack?.id == pack.id
            return AlphaAssistantVariantOption(
                pack: pack,
                runtimeMode: pack.runtimeMode,
                isActive: isActive,
                isBuiltIn: pack.runtimeMode == .appleFoundationModels || pack.artifactKind == "system_model",
                isSelected: isActive || (activePack == nil && preferredRuntimeMode == pack.runtimeMode),
                detailLabel: alphaAssistantVariantDetailLabel(
                    runtimeMode: pack.runtimeMode,
                    tier: normalizedTier,
                    isPhoneFormFactor: isPhoneFormFactor,
                    physicalMemoryBytes: physicalMemoryBytes
                )
            )
        }

    let availableSetupRuntimeModes = alphaAssistantAvailableSetupRuntimeModes(
        for: normalizedTier,
        cachedCatalogs: cachedCatalogs,
        cachedDownloads: cachedDownloads
    )
    for runtimeMode in availableSetupRuntimeModes where !options.contains(where: { $0.runtimeMode == runtimeMode }) {
        guard runtimeSupported(runtimeMode) else { continue }
        options.append(
            AlphaAssistantVariantOption(
                pack: nil,
                runtimeMode: runtimeMode,
                isActive: false,
                isBuiltIn: false,
                isSelected: activePack == nil && preferredRuntimeMode == runtimeMode,
                detailLabel: alphaAssistantVariantDetailLabel(
                    runtimeMode: runtimeMode,
                    tier: normalizedTier,
                    isPhoneFormFactor: isPhoneFormFactor,
                    physicalMemoryBytes: physicalMemoryBytes
                )
            )
        )
    }

    let hasSystemOption = options.contains { $0.isBuiltIn || $0.runtimeMode == .appleFoundationModels }
    if systemAssistantAvailable && !hasSystemOption {
        options.append(
            AlphaAssistantVariantOption(
                pack: nil,
                runtimeMode: .appleFoundationModels,
                isActive: activePack?.runtimeMode == .appleFoundationModels &&
                    AlphaCapabilityTier.assistantSelectionsMatch(activePack?.tier, normalizedTier),
                isBuiltIn: true,
                isSelected: activePack == nil && preferredRuntimeMode == .appleFoundationModels,
                detailLabel: alphaAssistantVariantDetailLabel(
                    runtimeMode: .appleFoundationModels,
                    tier: normalizedTier,
                    isPhoneFormFactor: isPhoneFormFactor,
                    physicalMemoryBytes: physicalMemoryBytes
                )
            )
        )
    }

    func runtimeRank(_ runtimeMode: AlphaPackRuntimeMode) -> Int {
        switch runtimeMode {
        case .appleFoundationModels:
            return 0
        case .mlxSwiftLm:
            return 1
        case .llamaCppGguf:
            return 2
        case .mediapipeLlm:
            return 3
        case .deterministicDev, .unavailable:
            return 4
        }
    }

    return options.sorted { lhs, rhs in
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        if lhs.isSelected != rhs.isSelected {
            return lhs.isSelected && !rhs.isSelected
        }
        let lhsMatchesPreferred = preferredRuntimeMode == lhs.runtimeMode
        let rhsMatchesPreferred = preferredRuntimeMode == rhs.runtimeMode
        if lhsMatchesPreferred != rhsMatchesPreferred {
            return lhsMatchesPreferred && !rhsMatchesPreferred
        }
        let lhsRank = runtimeRank(lhs.runtimeMode)
        let rhsRank = runtimeRank(rhs.runtimeMode)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.id < rhs.id
    }
}

private func alphaAssistantVariantDetailLabel(
    runtimeMode: AlphaPackRuntimeMode,
    tier: AlphaCapabilityTier,
    isPhoneFormFactor: Bool,
    physicalMemoryBytes: UInt64
) -> String? {
    if runtimeMode == .appleFoundationModels {
        if let contextLabel = alphaAssistantSetupContextLabel(
            for: tier,
            runtimeMode: runtimeMode,
            physicalMemoryBytes: physicalMemoryBytes
        ) {
            return "\(rossLocalized("assistant_meta_no_download")) · \(contextLabel)"
        }
        return rossLocalized("assistant_meta_no_download")
    }

    let hasDraftCompanion: Bool = switch runtimeMode {
    case .mlxSwiftLm:
        true
    case .llamaCppGguf:
        true
    case .appleFoundationModels, .deterministicDev, .mediapipeLlm, .unavailable:
        false
    }

    let speedLabel = alphaAssistantSetupSpeedLabel(
        for: tier,
        runtimeMode: runtimeMode,
        physicalMemoryBytes: physicalMemoryBytes,
        hasDraftCompanion: hasDraftCompanion
    )
    let contextLabel = alphaAssistantSetupContextLabel(
        for: tier,
        runtimeMode: runtimeMode,
        physicalMemoryBytes: physicalMemoryBytes
    )
    let compactCompanionLabel = alphaAssistantSetupCompanionCompactLabel(for: runtimeMode)

    let detailParts = [
        speedLabel,
        contextLabel,
        compactCompanionLabel
    ]
        .map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        .filter { !$0.isEmpty }
    if !detailParts.isEmpty {
        return detailParts.joined(separator: " · ")
    }

    switch runtimeMode {
    case .mlxSwiftLm:
        return isPhoneFormFactor ? "Fast on-device replies" : "Local MLX runtime"
    case .llamaCppGguf:
        return "Broader device compatibility"
    case .appleFoundationModels:
        return rossLocalized("assistant_meta_no_download")
    case .deterministicDev:
        return "Developer runtime"
    case .mediapipeLlm:
        return "MediaPipe runtime"
    case .unavailable:
        return nil
    }
}

func alphaAssistantPreferredInstalledPack(
    variantOptions: [AlphaAssistantVariantOption],
    preferredRuntimeMode: AlphaPackRuntimeMode?
) -> AlphaInstalledModelPack? {
    let installedOptions = variantOptions.filter { !$0.isBuiltIn && $0.pack != nil }

    if let preferredRuntimeMode,
       let preferredMatch = installedOptions.first(where: { $0.runtimeMode == preferredRuntimeMode })?.pack {
        return preferredMatch
    }

    return installedOptions.first?.pack
}

struct AlphaAssistantVariantChip: View {
    let option: AlphaAssistantVariantOption
    let action: () -> Void

    private var tint: Color {
        if option.isSelected {
            return Color.rossAccent
        }
        if option.isBuiltIn {
            return Color.rossHighlight
        }
        return Color.rossInk.opacity(0.42)
    }

    private var iconName: String {
        option.isBuiltIn ? "iphone" : "cpu"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption2.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(option.runtimeMode.displayLabel)
                            .font(.caption2.weight(.semibold))
                        if option.isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    if let detailLabel = option.detailLabel {
                        Text(detailLabel)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.rossInk.opacity(option.isSelected ? 0.62 : 0.50))
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(option.isSelected ? Color.rossAccent : Color.rossInk.opacity(0.70))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .rossNativeGlassSurface(
                tint: tint,
                shape: Capsule(),
                interactive: !option.isSelected,
                fallbackFillOpacity: option.isSelected ? 0.84 : 0.66,
                fallbackStrokeOpacity: option.isSelected ? 0.48 : 0.30
            )
        }
        .buttonStyle(.plain)
        .disabled(option.isSelected)
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

struct AlphaAssistantBuiltInMetaLabels: View {
    var speedLabel: String? = nil
    var contextLabel: String? = nil
    var font: Font = .caption.weight(.medium)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metaLabel(rossLocalized("assistant_meta_no_download"), systemImage: "checkmark.circle")
                metaLabel(rossLocalized("assistant_meta_built_in"), systemImage: "iphone")
                if let speedLabel {
                    metaLabel(speedLabel, systemImage: "speedometer")
                }
                if let contextLabel {
                    metaLabel(contextLabel, systemImage: "square.stack.3d.up")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                metaLabel(rossLocalized("assistant_meta_no_download"), systemImage: "checkmark.circle")
                metaLabel(rossLocalized("assistant_meta_built_in"), systemImage: "iphone")
                if let speedLabel {
                    metaLabel(speedLabel, systemImage: "speedometer")
                }
                if let contextLabel {
                    metaLabel(contextLabel, systemImage: "square.stack.3d.up")
                }
            }
        }
        .font(font)
        .foregroundStyle(Color.rossInk.opacity(0.55))
        .lineLimit(1)
        .minimumScaleFactor(0.86)
    }

    private func metaLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
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

struct AlphaAssistantUpgradeSummaryRow: View {
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossAccent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

    private var runtimeSummaryLabel: String? {
        alphaAssistantInstalledPackRuntimeSummaryLabel(
            for: pack,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            lastInvocation: model.lastModelInvocation
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.tier.setupTitle)
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

            if let runtimeSummaryLabel {
                Text(runtimeSummaryLabel)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
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

func alphaAssistantInstalledPackRuntimeSummaryLabel(
    for pack: AlphaInstalledModelPack,
    physicalMemoryBytes: UInt64,
    deviceModelIdentifier: String = alphaCurrentDeviceModelIdentifier(),
    lastInvocation: AlphaLocalModelInvocation? = nil
) -> String? {
    let hasDraftCompanion = switch pack.runtimeMode {
    case .mlxSwiftLm:
        true
    case .llamaCppGguf:
        alphaExpectedDownloadedAssistantArtifact(for: pack)?.draftArtifact != nil
    case .appleFoundationModels, .deterministicDev, .mediapipeLlm, .unavailable:
        false
    }

    let speedLabel = alphaAssistantSetupSpeedLabel(
        for: pack.tier,
        runtimeMode: pack.runtimeMode,
        physicalMemoryBytes: physicalMemoryBytes,
        deviceModelIdentifier: deviceModelIdentifier,
        hasDraftCompanion: hasDraftCompanion,
        lastInvocation: lastInvocation
    )
    let contextLabel = alphaAssistantSetupContextLabel(
        for: pack.tier,
        runtimeMode: pack.runtimeMode,
        physicalMemoryBytes: physicalMemoryBytes,
        deviceModelIdentifier: deviceModelIdentifier
    )

    let rawSummaryParts: [String?] = [
        pack.runtimeMode.displayLabel,
        speedLabel,
        contextLabel,
        alphaAssistantSetupCompanionCompactLabel(for: pack.runtimeMode)
    ]
    let summaryParts: [String] = rawSummaryParts.compactMap { value -> String? in
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    return summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · ")
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
    case builtIn
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
    case .builtIn:
        return rossLocalized("assistant_badge_built_in", languageCode: languageCode)
    case .needsAttention:
        return rossLocalized("assistant_badge_needs_attention", languageCode: languageCode)
    case .settingUp:
        return rossLocalized("assistant_badge_setting_up", languageCode: languageCode)
    }
}

enum AlphaAssistantOfferActionKind {
    case using
    case useForThisAsk
    case useOnThisIPhone
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
    case .useForThisAsk:
        return "Use this for the current ask"
    case .useOnThisIPhone:
        return rossLocalized("assistant_action_use_on_this_iphone", languageCode: languageCode)
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
