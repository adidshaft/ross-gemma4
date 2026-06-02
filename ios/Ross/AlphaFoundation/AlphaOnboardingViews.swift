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

// MARK: - Primary Button Style

struct AlphaSetupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background {
                shape.fill(Color.rossAccent.opacity(configuration.isPressed ? 0.74 : 0.86))
            }
            .rossNativeGlassSurface(
                tint: Color.rossAccent,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: configuration.isPressed ? 0.70 : 0.88,
                fallbackStrokeOpacity: 0.48
            )
            .overlay {
                shape.strokeBorder(Color.white.opacity(configuration.isPressed ? 0.18 : 0.32), lineWidth: 1)
            }
            .shadow(
                color: Color.rossAccent.opacity(configuration.isPressed ? 0.12 : 0.24),
                radius: configuration.isPressed ? 8 : 18,
                y: configuration.isPressed ? 4 : 10
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

// MARK: - Onboarding Screen

struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var didChooseAssistantOption = false

    private var recommendedTier: AlphaCapabilityTier {
        // First-run setup must be the fastest reliable path. Larger packs remain
        // available explicitly from assistant settings after Ross is usable.
        .flash
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
                        .buttonStyle(AlphaSetupPrimaryButtonStyle())
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
    let selectedTier: AlphaCapabilityTier
    let recommendedTier: AlphaCapabilityTier
    let compact: Bool
    let onSelect: (AlphaCapabilityTier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack {
                Text(rossLocalized("choose_private_assistant"))
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .foregroundStyle(Color.rossInk)
                Spacer(minLength: 0)
                Text("\(selectedTier.downloadSizeLabel)")
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
            }

            ForEach(AlphaCapabilityTier.allCases, id: \.self) { tier in
                AlphaOnboardingModelChoiceRow(
                    tier: tier,
                    isSelected: tier == selectedTier,
                    isRecommended: tier == recommendedTier,
                    compact: compact
                ) {
                    onSelect(tier)
                }
            }
        }
        .padding(compact ? 9 : 11)
        .rossGlassSurface(cornerRadius: compact ? 16 : 18, strokeOpacity: 0.62)
    }
}

struct AlphaOnboardingModelChoiceRow: View {
    let tier: AlphaCapabilityTier
    let isSelected: Bool
    let isRecommended: Bool
    let compact: Bool
    let onSelect: () -> Void

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
                        Text(tier.title)
                            .font(.system(size: compact ? 11 : 13, weight: .bold))
                            .foregroundStyle(Color.rossInk)
                            .lineLimit(1)

                        Text(tier.downloadSizeLabel)
                            .font(.system(size: compact ? 9 : 11, weight: .semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.56))
                            .lineLimit(1)

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
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 9 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .rossGlassSurface(
                tint: isSelected ? Color.rossAccent.opacity(0.22) : Color.rossAccent.opacity(0.08),
                cornerRadius: compact ? 11 : 12,
                interactive: true,
                shadowOpacity: isSelected ? 0.12 : 0.06,
                shadowRadius: isSelected ? 10 : 6,
                shadowY: isSelected ? 4 : 2,
                fillOpacity: isSelected ? 0.82 : 0.68,
                strokeOpacity: isSelected ? 0.62 : 0.42
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension AlphaCapabilityTier {
    var setupSymbolName: String {
        switch self {
        case .flash: "paperplane.fill"
        case .quickStart: "bolt.fill"
        case .caseAssociate: "brain"
        case .seniorDraftingSupport: "star.fill"
        }
    }

    var setupOneLine: String {
        switch self {
        case .flash:
            "Fastest setup for quick questions and simple checklists."
        case .quickStart:
            "Short orders, notices, and lighter document review."
        case .caseAssociate:
            "Everyday matters, summaries, dates, and source-backed Ask."
        case .seniorDraftingSupport:
            "Long bundles, deeper review, hearing prep, and drafting."
        }
    }
}

struct AlphaOnboardingSetupNotes: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 7) {
            AlphaOnboardingSetupNoteRow(
                icon: "lock.fill",
                title: "Works locally on this device",
                detail: "Matter files and assistant work stay on this phone.",
                compact: compact
            )
            AlphaOnboardingSetupNoteRow(
                icon: "wifi",
                title: "Use Wi-Fi for assistant setup",
                detail: "Large downloads can pause and resume if interrupted.",
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
        .rossGlassSurface(cornerRadius: 12, shadowOpacity: 0.05, shadowRadius: 6, shadowY: 2, strokeOpacity: 0.50)
    }
}

// MARK: - Download Info Card

struct AlphaOnboardingDownloadCard: View {
    let tier: AlphaCapabilityTier
    var compact = false

    private var etaLabel: String {
        switch tier {
        case .flash:              return "~1 min"
        case .quickStart:         return "~3 min"
        case .caseAssociate:      return "~10 min"
        case .seniorDraftingSupport: return "~30 min"
        }
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
                    .rossGlassSurface(tint: Color.rossAccent.opacity(0.16), cornerRadius: compact ? 10 : 12, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 1, strokeOpacity: 0.45)

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
        .rossGlassSurface(cornerRadius: compact ? 16 : 20, shadowOpacity: 0.12, shadowRadius: 16, shadowY: 6, strokeOpacity: 0.62)
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
        .rossGlassSurface(cornerRadius: compact ? 12 : 14, shadowOpacity: 0.06, shadowRadius: 7, shadowY: 2, strokeOpacity: 0.58)
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

                        ForEach(AlphaCapabilityTier.allCases, id: \.self) { tier in
                            AlphaModelPickerRow(
                                model: model,
                                tier: tier,
                                isRecommended: tier == model.recommendedOnDeviceTier()
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

    private var etaLabel: String {
        switch tier {
        case .flash:                 return "~1 min"
        case .quickStart:            return "~3 min"
        case .caseAssociate:         return "~10 min"
        case .seniorDraftingSupport: return "~30 min"
        }
    }

    private var tierIcon: String {
        switch tier {
        case .flash:                 return "paperplane.fill"
        case .quickStart:            return "bolt.fill"
        case .caseAssociate:         return "brain"
        case .seniorDraftingSupport: return "star.fill"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: tierIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rossAccent)
                        .frame(width: 36, height: 36)
                        .rossGlassSurface(tint: Color.rossAccent.opacity(0.16), cornerRadius: 10, shadowOpacity: 0.05, shadowRadius: 5, shadowY: 1, strokeOpacity: 0.42)

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

                        AlphaAssistantSetupMetaLabels(
                            sizeLabel: tier.downloadSizeLabel,
                            etaLabel: etaLabel,
                            freeSpaceLabel: model.freeDiskSpaceLabel,
                            font: .caption.weight(.medium)
                        )
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
            .rossGlassSurface(
                tint: isRecommended ? Color.rossAccent.opacity(0.18) : Color.rossAccent.opacity(0.08),
                cornerRadius: 18,
                interactive: true,
                shadowOpacity: 0.10,
                shadowRadius: 12,
                shadowY: 4,
                strokeOpacity: isRecommended ? 0.72 : 0.54
            )
        }
        .buttonStyle(.plain)
    }
}

struct AlphaAssistantSetupMetaLabels: View {
    let sizeLabel: String
    var etaLabel: String?
    let freeSpaceLabel: String
    var font: Font = .caption.weight(.medium)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                metaLabel(sizeLabel, systemImage: "arrow.down.circle")
                if let etaLabel {
                    metaLabel(etaLabel, systemImage: "wifi")
                }
                metaLabel(freeSpaceLabel, systemImage: "internaldrive")
            }

            VStack(alignment: .leading, spacing: 4) {
                metaLabel(sizeLabel, systemImage: "arrow.down.circle")
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
