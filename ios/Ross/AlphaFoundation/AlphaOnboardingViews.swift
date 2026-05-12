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
            .fill(Color.rossGroupedBackground.opacity(0.34))
            .background(.ultraThinMaterial)
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
                .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .background(Color.rossGlassFill, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.rossGlassStroke.opacity(0.84), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Primary Button Style

struct AlphaSetupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.rossAccent.opacity(configuration.isPressed ? 0.82 : 0.94),
                                Color.rossAccent.opacity(configuration.isPressed ? 0.7 : 0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .rossGlassSurface(
                tint: Color.rossAccent,
                cornerRadius: 16,
                interactive: true,
                shadowOpacity: configuration.isPressed ? 0.2 : 0.28,
                shadowRadius: configuration.isPressed ? 8 : 18,
                shadowY: configuration.isPressed ? 4 : 10,
                fillOpacity: configuration.isPressed ? 0.7 : 0.88,
                strokeOpacity: 0.45
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

// MARK: - Onboarding Screen

struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var showModelPicker = false

    private var recommendedTier: AlphaCapabilityTier {
        model.recommendedOnDeviceTier()
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
            let topGap: CGFloat = compact ? 18 : 44
            let logoSize: CGFloat = compact ? 58 : 78
            let titleSize: CGFloat = compact ? 32 : 38
            let heroGap: CGFloat = compact ? 8 : 16

            ZStack {
                AlphaSetupBackdrop()
                VStack(spacing: 0) {
                    AlphaTopSafeAreaGlass(height: proxy.safeAreaInsets.top + 18)
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + topGap, compact ? 54 : 72))

                    VStack(spacing: heroGap) {
                        RossAuthHeroMark(size: logoSize)

                        VStack(spacing: compact ? 4 : 8) {
                            Text("Ross")
                                .font(.system(size: titleSize, weight: .bold, design: .serif))
                                .foregroundStyle(Color.rossInk)

                            Text("Your private legal workbench.")
                                .font((compact ? Font.callout : Font.title3).weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.70))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: compact ? 14 : 28)

                    AlphaOnboardingDownloadCard(tier: recommendedTier, compact: compact)

                    Spacer(minLength: compact ? 10 : 16)

                    VStack(spacing: compact ? 6 : 8) {
                        AlphaOnboardingPrivacyPill(icon: "lock.fill", text: "Everything stays on this device", compact: compact)
                        AlphaOnboardingPrivacyPill(icon: "network.slash", text: "No cloud after setup - fully offline", compact: compact)
                        AlphaOnboardingPrivacyPill(icon: "arrow.down.circle", text: "One download, then always private", compact: compact)
                    }

                    Spacer(minLength: compact ? 12 : 22)

                    VStack(spacing: compact ? 8 : 12) {
                        Button {
                            model.selectedTier = recommendedTier
                            model.finishPackSetup()
                        } label: {
                            Text(rossLocalized("setup_assistant"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AlphaSetupPrimaryButtonStyle())
                        .frame(height: compact ? 48 : 52)

                        Button("Choose a different model") {
                            showModelPicker = true
                        }
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(Color.rossAccent.opacity(0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                        Button("Skip for now") {
                            model.skipPackSetup()
                        }
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .foregroundStyle(Color.rossInk.opacity(0.44))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: max(proxy.safeAreaInsets.bottom + (compact ? 8 : 18), compact ? 18 : 28))
                }
                .frame(width: contentWidth)
                .position(x: viewportWidth / 2, y: proxy.size.height / 2)
                .clipped()
            }
            .frame(width: viewportWidth, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .sheet(isPresented: $showModelPicker) {
            AlphaModelPickerSheet(model: model, isPresented: $showModelPicker)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

// MARK: - Download Info Card

struct AlphaOnboardingDownloadCard: View {
    @Environment(\.colorScheme) private var colorScheme
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
        let shape = RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)

        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            // Header
            HStack(spacing: compact ? 9 : 12) {
                Image(systemName: tierIcon)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
                    .foregroundStyle(Color.rossAccent)
                    .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                            .stroke(Color.rossAccent.opacity(0.22), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.setupTitle)
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("Recommended for your device")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(Color.rossAccent.opacity(0.80))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("Recommended")
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(Color.rossAccent)
                    .padding(.horizontal, compact ? 7 : 8)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(Color.rossAccent.opacity(0.10), in: Capsule())
            }

            Divider()
                .opacity(0.45)

            HStack(spacing: 0) {
                AlphaOnboardingStatCell(label: "Download size", value: tier.downloadSizeLabel, icon: "arrow.down.circle.fill", compact: compact)
                Divider().frame(height: compact ? 28 : 36).opacity(0.38)
                AlphaOnboardingStatCell(label: "On fast Wi-Fi", value: etaLabel, icon: "wifi", compact: compact)
            }

            // Model description
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

                Text("Connect to Wi-Fi for the fastest setup. The download resumes automatically if interrupted.")
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.50))
                    .lineLimit(compact ? 2 : 3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 13 : 18)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.rossCardBackground.opacity(colorScheme == .dark ? 0.72 : 0.88))
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.16 : 0.88),
                        Color.rossBorder.opacity(0.42)
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .clipShape(shape)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.58), lineWidth: 1)
        }
    }
}

// MARK: - Model Picker Sheet

struct AlphaModelPickerSheet: View {
    @Bindable var model: AlphaRossModel
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Context header
                    VStack(spacing: 6) {
                        Text("Choose your model")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(Color.rossInk)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("All models run fully on this device. Bigger models are slower to download but smarter.")
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

                    Text("You can change this later in Settings → Ross assistant.")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.44))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("Models")
            .rossInlineNavigationTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.rossAccent)
                }
                #endif
            }
        }
    }
}

struct AlphaModelPickerRow: View {
    @Environment(\.colorScheme) private var colorScheme
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
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: tierIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.rossAccent)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.rossAccent.opacity(0.18), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tier.setupTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)

                            if isRecommended {
                                Text("Recommended")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.rossAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.rossAccent.opacity(0.10), in: Capsule())
                            }
                        }

                        HStack(spacing: 10) {
                            Label(tier.downloadSizeLabel, systemImage: "arrow.down.circle")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.55))

                            Label(etaLabel, systemImage: "wifi")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.55))

                            Label(model.freeDiskSpaceLabel, systemImage: "internaldrive")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.55))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Color.rossCardBackground.opacity(colorScheme == .dark ? 0.72 : 0.88))
                    if isRecommended {
                        shape.fill(Color.rossAccent.opacity(colorScheme == .dark ? 0.05 : 0.03))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    isRecommended
                        ? LinearGradient(colors: [Color.rossAccent.opacity(0.35), Color.rossAccent.opacity(0.12)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.14 : 0.72), Color.rossBorder.opacity(0.40)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .clipShape(shape)
            .shadow(color: Color.rossShadow.opacity(0.10), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
