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

// MARK: - Setup Backdrop

struct AlphaSetupBackdrop: View {
    var body: some View {
        RossAuthBackdrop()
    }
}

struct AlphaTopSafeAreaGlass: View {
    let height: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .rossNativeGlassSurface(
                tint: Color.rossAccent.opacity(0.08),
                shape: Rectangle(),
                fallbackFillOpacity: 0.34,
                fallbackStrokeOpacity: 0.14
            )
            .frame(height: max(height, 0))
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

struct AlphaSetupWordmarkRow: View {
    let title: String
    let stepLabel: String?

    init(title: String, stepLabel: String? = nil) {
        self.title = title
        self.stepLabel = stepLabel
    }

    var body: some View {
        HStack(spacing: 10) {
            Image("RossLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(4)
                .rossNativeGlassSurface(
                    tint: Color.rossAccent,
                    shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    fallbackFillOpacity: 0.82,
                    fallbackStrokeOpacity: 0.48
                )
                .shadow(color: Color.rossShadow.opacity(0.45), radius: 10, y: 4)

            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(2.4)
                .foregroundStyle(Color.rossAccent)

            Spacer(minLength: 0)

            if let stepLabel, !stepLabel.isEmpty {
                Text(stepLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: Capsule(),
                        fallbackFillOpacity: 0.82,
                        fallbackStrokeOpacity: 0.48
                    )
            }
        }
    }
}

// MARK: - Onboarding Screen

struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var didChooseAssistantOption = false

    private var recommendedTier: AlphaCapabilityTier {
        model.recommendedAssistantSetupTier()
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            #if canImport(UIKit)
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            #else
            let viewportWidth = proxy.size.width
            #endif
            let contentWidth = min(max(viewportWidth - (horizontalPadding * 2), 280), 430)
            let compact = proxy.size.height < 880
            let logoSize: CGFloat = compact ? 38 : 52
            let titleSize: CGFloat = compact ? 24 : 30
            let heroGap: CGFloat = compact ? 6 : 8
            let topPadding = max(proxy.safeAreaInsets.top + (compact ? 14 : 18), compact ? 72 : 82)
            let bottomPadding = max(proxy.safeAreaInsets.bottom + (compact ? 10 : 14), compact ? 22 : 28)
            let displayedTier = didChooseAssistantOption ? model.selectedTier : recommendedTier

            ZStack {
                AlphaSetupBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: heroGap) {
                        RossAuthHeroMark(size: logoSize)

                        VStack(spacing: compact ? 4 : 8) {
                            Text("Ross")
                                .font(.system(size: titleSize, weight: .bold, design: .serif))
                                .foregroundStyle(Color.rossInk)

                            Text(rossLocalized("private_legal_workbench"))
                                .font((compact ? Font.callout : Font.title3).weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.70))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: compact ? 14 : 18)

                    AlphaOnboardingModelSelector(
                        model: model,
                        selectedTier: displayedTier,
                        recommendedTier: recommendedTier,
                        compact: compact
                    ) { tier in
                        withAnimation(.snappy(duration: 0.18)) {
                            didChooseAssistantOption = true
                            model.selectedTier = tier
                        }
                    }

                    Spacer(minLength: compact ? 12 : 14)

                    AlphaOnboardingSetupNotes(compact: compact)

                    Spacer(minLength: compact ? 14 : 18)

                    VStack(spacing: compact ? 7 : 9) {
                        Button {
                            if !didChooseAssistantOption {
                                model.selectedTier = recommendedTier
                            }
                            model.finishPackSetup()
                        } label: {
                            Text(rossLocalized("setup_assistant"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RossPrimaryButtonStyle())
                        .frame(height: compact ? 50 : 54)

                        Button(rossLocalized("skip_for_now")) {
                            model.skipPackSetup()
                        }
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .foregroundStyle(Color.rossInk.opacity(0.44))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    }
                }
                .frame(width: contentWidth)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(width: viewportWidth, height: proxy.size.height, alignment: .top)
                .position(x: viewportWidth / 2, y: proxy.size.height / 2)
            }
            .frame(width: viewportWidth, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .onAppear {
            if !didChooseAssistantOption {
                model.selectedTier = recommendedTier
            }
        }
        .onChange(of: recommendedTier) { _, newValue in
            if !didChooseAssistantOption {
                model.selectedTier = newValue
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        #endif
    }
}

struct AlphaOnboardingModelSelector: View {
    let model: AlphaRossModel
    let selectedTier: AlphaCapabilityTier
    let recommendedTier: AlphaCapabilityTier
    let compact: Bool
    let onSelect: (AlphaCapabilityTier) -> Void

    private var selectedSetupSummaryLabel: String {
        if let setupPresentation = selectedSetupPresentation {
            return alphaAssistantSetupCompactSummaryLabel(setupPresentation)
        }
        return rossLocalized("assistant_state_checking")
    }

    private var selectedSetupPresentation: AlphaAssistantSetupPresentation? {
        model.assistantSetupPresentation(for: selectedTier)
    }

    private var selectedRuntimeLabel: String? {
        selectedSetupPresentation?.runtimeMode.displayLabel
    }

    private var selectedEtaLabel: String? {
        selectedSetupPresentation?.etaLabel
    }

    private var selectedSpeedLabel: String? {
        selectedSetupPresentation?.speedLabel
    }

    private var selectedContextLabel: String? {
        selectedSetupPresentation?.contextLabel
    }

    private var selectedCompanionLabel: String? {
        selectedSetupPresentation?.companionLabel
    }

    private var selectedSizeLabel: String {
        selectedSetupPresentation?.sizeLabel ??
            rossLocalized("assistant_state_checking")
    }

    private var selectedSystemAssistantAvailable: Bool {
        model.systemAssistantHealth(for: selectedTier)?.available == true
    }

    private var selectedVariantOptions: [AlphaAssistantVariantOption] {
        alphaAssistantVariantOptions(
            for: selectedTier,
            installedPacks: model.privateAISnapshot.installedPacks,
            activePack: model.activePack,
            systemAssistantAvailable: selectedSystemAssistantAvailable,
            preferredRuntimeMode: selectedSetupPresentation?.runtimeMode,
            cachedCatalogs: model.persisted.cachedAssistantCatalogs,
            cachedDownloads: model.persisted.cachedAssistantDownloads
        )
    }

    private var selectedRuntimeChoiceLabel: String? {
        guard let runtimeMode = selectedSetupPresentation?.runtimeMode else { return nil }
        let label = alphaAssistantRuntimeChoiceLabel(
            selectedRuntimeMode: runtimeMode,
            tier: selectedTier,
            existingRuntimeMode: model.installedPack(for: selectedTier)?.runtimeMode,
            systemAssistantAvailable: selectedSystemAssistantAvailable,
            lastInvocation: model.lastModelInvocation
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? nil : label
    }

    private var selectedBuiltInHint: String? {
        alphaAssistantBuiltInAlternativeHint(
            selectedRuntimeMode: selectedSetupPresentation?.runtimeMode,
            systemAssistantAvailable: selectedSystemAssistantAvailable
        )
    }

    private func selectRuntime(_ option: AlphaAssistantVariantOption) {
        guard !option.isSelected else { return }
        model.setAssistantSetupRuntimeOverride(option.runtimeMode, for: selectedTier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack {
                Text(rossLocalized("choose_private_assistant"))
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .foregroundStyle(Color.rossInk)
                Spacer(minLength: 0)
                Text(selectedSetupSummaryLabel)
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
                    .multilineTextAlignment(.trailing)
            }

            ForEach(AlphaCapabilityTier.visibleAssistantTiers, id: \.self) { tier in
                AlphaOnboardingModelChoiceRow(
                    model: model,
                    tier: tier,
                    isSelected: tier == selectedTier,
                    isRecommended: tier == recommendedTier,
                    compact: compact
                ) {
                    onSelect(tier)
                }
            }

            AlphaAssistantSetupMetaLabels(
                sizeLabel: selectedSizeLabel,
                runtimeLabel: selectedRuntimeLabel,
                speedLabel: selectedSpeedLabel,
                contextLabel: selectedContextLabel,
                companionLabel: selectedCompanionLabel,
                etaLabel: selectedEtaLabel,
                freeSpaceLabel: model.freeDiskSpaceLabel,
                font: (compact ? Font.caption2 : Font.caption).weight(.medium)
            )
            .padding(.top, 2)

            if let selectedRuntimeChoiceLabel {
                Text(selectedRuntimeChoiceLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selectedVariantOptions.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(rossLocalized("assistant_available_runtimes"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.60))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedVariantOptions) { option in
                                AlphaAssistantVariantChip(
                                    option: option,
                                    action: { selectRuntime(option) }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 2)
            }

            if let selectedBuiltInHint {
                Text(selectedBuiltInHint)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 9 : 11)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.62
        )
        .task {
            model.primeAssistantSetupCatalogsIfNeeded()
        }
    }
}

struct AlphaOnboardingModelChoiceRow: View {
    let model: AlphaRossModel
    let tier: AlphaCapabilityTier
    let isSelected: Bool
    let isRecommended: Bool
    let compact: Bool
    let onSelect: () -> Void

    private var setupSummaryLabel: String {
        if let setupPresentation = model.assistantSetupPresentation(for: tier) {
            return alphaAssistantSetupCompactSummaryLabel(setupPresentation)
        }
        return rossLocalized("assistant_state_checking")
    }

    private var runtimeLabel: String? {
        model.assistantSetupPresentation(for: tier)?.runtimeMode.displayLabel
    }

    private var etaLabel: String? {
        model.assistantSetupPresentation(for: tier)?.etaLabel
    }

    private var speedLabel: String? {
        model.assistantSetupPresentation(for: tier)?.speedLabel
    }

    private var contextLabel: String? {
        model.assistantSetupPresentation(for: tier)?.contextLabel
    }

    private var companionLabel: String? {
        model.assistantSetupPresentation(for: tier)?.companionLabel
    }

    private var sizeLabel: String {
        model.assistantSetupPresentation(for: tier)?.sizeLabel ??
            rossLocalized("assistant_state_checking")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: compact ? 8 : 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : tier.setupSymbolName)
                    .font(.system(size: compact ? 14 : 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.50))
                    .frame(width: compact ? 20 : 22, height: compact ? 20 : 22)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                    HStack(spacing: 6) {
                        Text(tier.setupTitle)
                            .font(.system(size: compact ? 11 : 13, weight: .bold))
                            .foregroundStyle(Color.rossInk)
                            .lineLimit(1)

                        Text(setupSummaryLabel)
                            .font(.system(size: compact ? 9 : 11, weight: .semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.56))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        if isRecommended {
                            Text(rossLocalized("recommended"))
                                .font(.system(size: compact ? 9 : 10, weight: .bold))
                                .foregroundStyle(Color.rossAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .rossNativeGlassSurface(
                                    tint: Color.rossAccent,
                                    shape: Capsule(),
                                    fallbackFillOpacity: 0.68,
                                    fallbackStrokeOpacity: 0.36
                                )
                        }
                    }

                    Text(tier.setupOneLine)
                        .font(.system(size: compact ? 9 : 10, weight: .medium))
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)

                    AlphaAssistantSetupMetaLabels(
                        sizeLabel: sizeLabel,
                        runtimeLabel: runtimeLabel,
                        speedLabel: speedLabel,
                        contextLabel: contextLabel,
                        companionLabel: companionLabel,
                        etaLabel: etaLabel,
                        freeSpaceLabel: model.freeDiskSpaceLabel,
                        font: .caption2.weight(.medium)
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 9 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .modifier(
                AlphaOnboardingModelChoiceSurface(
                    isSelected: isSelected,
                    cornerRadius: compact ? 11 : 12
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AlphaOnboardingModelChoiceSurface: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tint = isSelected ? Color.rossAccent.opacity(0.22) : Color.rossAccent.opacity(0.08)

        content
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: isSelected ? 0.82 : 0.68,
                fallbackStrokeOpacity: isSelected ? 0.62 : 0.42
            )
            .shadow(
                color: Color.rossShadow.opacity(isSelected ? 0.12 : 0.06),
                radius: isSelected ? 10 : 6,
                y: isSelected ? 4 : 2
            )
    }
}

extension AlphaCapabilityTier {
    var setupSymbolName: String {
        switch self {
        case .flash: "paperplane.fill"
        case .quickStart: "bolt.fill"
        case .caseAssociate: "brain"
        case .seniorDraftingSupport: "star.fill"
        }
    }

    var setupOneLine: String {
        setupOneLine(languageCode: rossSelectedLanguageCode())
    }

    func setupOneLine(languageCode: String) -> String {
        switch self {
        case .flash:
            rossLocalized("tier_flash_summary", languageCode: languageCode)
        case .quickStart:
            rossLocalized("tier_quick_start_summary", languageCode: languageCode)
        case .caseAssociate:
            rossLocalized("tier_case_associate_summary", languageCode: languageCode)
        case .seniorDraftingSupport:
            rossLocalized("tier_senior_drafting_summary", languageCode: languageCode)
        }
    }
}

struct AlphaOnboardingSetupNotes: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 7) {
            AlphaOnboardingSetupNoteRow(
                icon: "lock.fill",
                title: rossLocalized("setup_note_local_title"),
                detail: rossLocalized("setup_note_local_detail"),
                compact: compact
            )
            AlphaOnboardingSetupNoteRow(
                icon: "wifi",
                title: rossLocalized("setup_note_wifi_title"),
                detail: rossLocalized("setup_note_wifi_detail"),
                compact: compact
            )
        }
    }
}

struct AlphaOnboardingSetupNoteRow: View {
    let icon: String
    let title: String
    let detail: String
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 8 : 10) {
            Image(systemName: icon)
                .font(.system(size: compact ? 10 : 11, weight: .bold))
                .foregroundStyle(Color.rossAccent.opacity(0.78))
                .frame(width: compact ? 18 : 20, height: compact ? 18 : 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(detail)
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.54))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 7 : 8)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.50
        )
        .shadow(color: Color.rossShadow.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Download Info Card

struct AlphaOnboardingDownloadCard: View {
    let tier: AlphaCapabilityTier
    var compact = false

    private var etaLabel: String {
        tier.setupTimeLabel
    }

    private var tierIcon: String {
        switch tier {
        case .flash:              return "paperplane.fill"
        case .quickStart:         return "bolt.fill"
        case .caseAssociate:      return "brain"
        case .seniorDraftingSupport: return "star.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            // Header
            HStack(spacing: compact ? 9 : 12) {
                Image(systemName: tierIcon)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
                    .foregroundStyle(Color.rossAccent)
                    .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous),
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.45
                    )
                    .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.setupTitle)
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(rossLocalized("recommended_for_device"))
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(Color.rossAccent.opacity(0.80))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(rossLocalized("recommended"))
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
                    .padding(.horizontal, compact ? 7 : 8)
                    .padding(.vertical, compact ? 3 : 4)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: Capsule(),
                        fallbackFillOpacity: 0.68,
                        fallbackStrokeOpacity: 0.36
                    )
            }

            Divider()
                .opacity(0.45)

            HStack(spacing: 0) {
                AlphaOnboardingStatCell(label: rossLocalized("download_size"), value: tier.downloadSizeLabel, icon: "arrow.down.circle.fill", compact: compact)
                Divider().frame(height: compact ? 28 : 36).opacity(0.38)
                AlphaOnboardingStatCell(label: rossLocalized("on_fast_wifi"), value: etaLabel, icon: "wifi", compact: compact)
            }

            // Assistant option description
            Text(tier.summary)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(Color.rossInk.opacity(0.65))
                .lineLimit(compact ? 2 : 3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(compact ? 1.5 : 3)

            // Wi-Fi advisory
            HStack(spacing: compact ? 6 : 8) {
                Image(systemName: "wifi")
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.44))

                Text(rossLocalized("wifi_setup_advisory"))
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.50))
                    .lineLimit(compact ? 2 : 3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 13 : 18)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.62
        )
        .shadow(color: Color.rossShadow.opacity(0.12), radius: 16, y: 6)
    }
}

struct AlphaOnboardingStatCell: View {
    let label: String
    let value: String
    let icon: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(systemName: icon)
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(Color.rossAccent.opacity(0.70))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                    .foregroundStyle(Color.rossInk)
                Text(label)
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.50))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AlphaOnboardingPrivacyPill: View {
    let icon: String
    let text: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(Color.rossAccent.opacity(0.70))
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)

            Text(text)
                .font((compact ? Font.caption : Font.subheadline).weight(.medium))
                .foregroundStyle(Color.rossInk.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 8 : 11)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous),
            fallbackFillOpacity: 0.84,
            fallbackStrokeOpacity: 0.58
        )
        .shadow(color: Color.rossShadow.opacity(0.06), radius: 7, y: 2)
    }
}

// MARK: - Assistant Picker Sheet

struct AlphaModelPickerSheet: View {
    @Bindable var model: AlphaRossModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                RossGlassGroup(spacing: 14) {
                    VStack(spacing: 14) {
                        VStack(spacing: 6) {
                            Text(rossLocalized("choose_your_private_assistant"))
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(Color.rossInk)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(rossLocalized("assistant_picker_detail"))
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.60))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)

                        ForEach(AlphaCapabilityTier.visibleAssistantTiers, id: \.self) { tier in
                            AlphaModelPickerRow(
                                model: model,
                                tier: tier,
                                isRecommended: tier == model.recommendedAssistantSetupTier()
                            ) {
                                model.selectedTier = tier
                                model.finishPackSetup()
                                isPresented = false
                            }
                        }

                        Text(rossLocalized("assistant_picker_later"))
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.44))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(rossLocalized("assistant"))
            .rossInlineNavigationTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(rossLocalized("cancel")) { isPresented = false }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.rossAccent)
                }
                #endif
            }
        }
    }
}

struct AlphaModelPickerRow: View {
    @Bindable var model: AlphaRossModel
    let tier: AlphaCapabilityTier
    let isRecommended: Bool
    let onSelect: () -> Void

    private var tierIcon: String {
        switch tier {
        case .flash:                 return "paperplane.fill"
        case .quickStart:            return "bolt.fill"
        case .caseAssociate:         return "brain"
        case .seniorDraftingSupport: return "star.fill"
        }
    }

    private var setupPresentation: AlphaAssistantSetupPresentation? {
        model.assistantSetupPresentation(for: tier)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: tierIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rossAccent)
                        .frame(width: 36, height: 36)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent,
                            shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                            fallbackFillOpacity: 0.84,
                            fallbackStrokeOpacity: 0.42
                        )
                        .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 1)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tier.setupTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)

                            if isRecommended {
                                Text(rossLocalized("recommended"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.rossAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .rossNativeGlassSurface(
                                        tint: Color.rossAccent,
                                        shape: Capsule(),
                                        fallbackFillOpacity: 0.68,
                                        fallbackStrokeOpacity: 0.36
                                    )
                            }
                        }

                        if let setupPresentation {
                            AlphaAssistantSetupMetaLabels(
                                sizeLabel: setupPresentation.sizeLabel,
                                runtimeLabel: setupPresentation.runtimeMode.displayLabel,
                                companionLabel: setupPresentation.companionLabel,
                                etaLabel: setupPresentation.etaLabel,
                                freeSpaceLabel: model.freeDiskSpaceLabel,
                                font: .caption.weight(.medium)
                            )
                        } else {
                            AlphaAssistantSetupMetaLabels(
                                sizeLabel: rossLocalized("assistant_state_checking"),
                                freeSpaceLabel: model.freeDiskSpaceLabel,
                                font: .caption.weight(.medium)
                            )
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.rossInk.opacity(0.24))
                }

                Text(tier.summary)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2.5)
            }
            .padding(16)
            .modifier(AlphaModelPickerRowSurface(isRecommended: isRecommended))
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaModelPickerRowSurface: ViewModifier {
    let isRecommended: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let tint = isRecommended ? Color.rossAccent.opacity(0.18) : Color.rossAccent.opacity(0.08)

        content
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: isRecommended ? 0.82 : 0.72,
                fallbackStrokeOpacity: isRecommended ? 0.72 : 0.54
            )
            .shadow(color: Color.rossShadow.opacity(0.10), radius: 12, y: 4)
    }
}

struct AlphaAssistantSetupMetaLabels: View {
    let sizeLabel: String
    var runtimeLabel: String?
    var speedLabel: String? = nil
    var contextLabel: String? = nil
    var companionLabel: String? = nil
    var etaLabel: String?
    let freeSpaceLabel: String
    var font: Font = .caption.weight(.medium)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metaLabel(sizeLabel, systemImage: "arrow.down.circle")
                if let runtimeLabel {
                    metaLabel(runtimeLabel, systemImage: "cpu")
                }
                if let speedLabel {
                    metaLabel(speedLabel, systemImage: "speedometer")
                }
                if let contextLabel {
                    metaLabel(contextLabel, systemImage: "square.stack.3d.up")
                }
                if let companionLabel {
                    metaLabel(companionLabel, systemImage: "bolt.circle")
                }
                if let etaLabel {
                    metaLabel(etaLabel, systemImage: "wifi")
                }
                metaLabel(freeSpaceLabel, systemImage: "internaldrive")
            }

            VStack(alignment: .leading, spacing: 4) {
                metaLabel(sizeLabel, systemImage: "arrow.down.circle")
                if let runtimeLabel {
                    metaLabel(runtimeLabel, systemImage: "cpu")
                }
                if let speedLabel {
                    metaLabel(speedLabel, systemImage: "speedometer")
                }
                if let contextLabel {
                    metaLabel(contextLabel, systemImage: "square.stack.3d.up")
                }
                if let companionLabel {
                    metaLabel(companionLabel, systemImage: "bolt.circle")
                }
                if let etaLabel {
                    metaLabel(etaLabel, systemImage: "wifi")
                }
                metaLabel(freeSpaceLabel, systemImage: "internaldrive")
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
