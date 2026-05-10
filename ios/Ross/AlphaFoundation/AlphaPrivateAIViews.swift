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

struct AlphaPrivateAISettingsScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var downloadPreferencesExpanded = false

    private var visibleSetupJobs: [AlphaModelDownloadJob] {
        model.persisted.modelJobs.filter { job in
            switch job.state {
            case .queued, .downloading, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .verifying, .failed:
                true
            case .notStarted, .installed, .cancelled:
                false
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

    var body: some View {
        let assistantStatus = alphaAssistantStatusSnapshot(model)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RossSectionCard(
                    title: "Ross assistant",
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
                        VStack(alignment: .leading, spacing: 0) {
                            AlphaSettingsToggleRow(
                                title: "Use Wi-Fi for larger downloads",
                                detail: "Ross waits for Wi-Fi before downloading larger private assistant files.",
                                isOn: wifiOnlyDownloadsBinding
                            )
                            Divider()
                            AlphaSettingsToggleRow(
                                title: "Allow mobile data",
                                detail: "Only use cellular data for assistant setup when you choose to.",
                                isOn: allowMobileDataBinding
                            )
                        }
                        .padding(.top, 10)
                    } label: {
                        AlphaSettingsValueRow(label: "Network", value: model.persisted.settings.allowMobileDataForLargePacks ? "Wi-Fi or mobile data" : "Wi-Fi preferred")
                    }
                    .tint(Color.rossAccent)
                }

                AlphaPrivateAITechnicalDiagnosticsCard(model: model)
            }
            .padding(alphaScreenPadding)
        }
        .navigationTitle("Ross assistant")
        .rossInlineNavigationTitle()
    }
}

struct AlphaPrivateAITechnicalDiagnosticsCard: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        RossSectionCard(title: "Advanced") {
            DisclosureGroup("Technical diagnostics") {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.persisted.installedPacks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.persisted.installedPacks) { pack in
                                AlphaPrivateAIInstalledPackCard(model: model, pack: pack)
                            }
                        }
                        Divider()
                    }

                    if let runtimeHealth = model.activeRuntimeHealth {
                        let lastInvocation = model.lastModelInvocation
                        let lastPreview = model.persisted.publicLawPreview
                        let resetCount = model.persisted.ledgerEntries.filter { $0.title.localizedCaseInsensitiveContains("reset") }.count

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
            .tint(Color.rossAccent)
        }
    }
}

struct AlphaPrivacyLedgerScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        ScrollView {
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
            return "Needs attention"
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
        isActive || activeButRuntimeUnavailable || isSettingUp
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
            }

            if let latestJob,
               (latestJob.state == .failed || latestJob.state == .pausedError || latestJob.state == .pausedNoStorage),
               let failureReason = latestJob.failureReason {
                Text(failureReason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if activeButRuntimeUnavailable, let runtimeStatus = model.activeRuntimeHealth?.userFacingStatus {
                Text(runtimeStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(actionTitle) {
                Task {
                    if let installedPack {
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
        .background(Color.rossGlassSubtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isActive
                        ? Color.rossAccent.opacity(0.24)
                        : Color.rossGlassStroke.opacity(0.7),
                    lineWidth: 1
                )
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.tier.title)
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)

                    Text(alphaAssistantStateLabel(job.state))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                }

                Spacer(minLength: 8)

                AlphaPrivateAIInlineBadge(title: alphaAssistantStateLabel(job.state), tint: .orange)
            }

            Text(alphaAssistantActivityDetail(for: job.state))
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            if let failureReason = job.failureReason,
               job.state == .failed || job.state == .pausedError || job.state == .pausedNoStorage {
                Text(failureReason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progressValue = alphaDownloadProgressValue(job) {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progressValue, total: 1)
                        .progressViewStyle(.linear)
                        .tint(Color.rossAccent)

                    if let estimateLabel = alphaDownloadEstimateLabel(job) {
                        Text(estimateLabel)
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.6))
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

            if canPause || canResume {
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
        .padding(14)
        .background(Color.rossGlassSubtleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.72), lineWidth: 1)
        }
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

                    Text(isReady ? "Ross assistant is ready" : "Ross assistant needs attention")
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
        .padding(14)
        .background(Color.rossGlassSubtleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.72), lineWidth: 1)
        }
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
            .background(tint.opacity(0.1), in: Capsule())
    }
}

func alphaDownloadEstimateLabel(_ job: AlphaModelDownloadJob) -> String? {
    switch job.state {
    case .downloading:
        guard job.totalBytes > 0 else { return "Ross will update the estimate once the download starts moving." }
        let remainingFraction = max(0, min(1, 1 - job.progress))
        let baselineMinutes: Double
        switch job.tier {
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
