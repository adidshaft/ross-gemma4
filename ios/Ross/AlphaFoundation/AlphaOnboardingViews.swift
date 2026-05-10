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

struct AlphaSetupPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
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
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.rossGlassStroke.opacity(0.45), lineWidth: 1)
                    }
            )
            .shadow(color: Color.rossShadow.opacity(configuration.isPressed ? 0.2 : 0.28), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

struct AlphaOnboardingScreen: View {
    @Bindable var model: AlphaRossModel

    private let featurePills: [(String, String)] = [
        ("Files stay on this device", "lock"),
        ("From your files", "paperclip"),
        ("Web search is opt-in", "shield")
    ]

    private var recommendedTier: AlphaCapabilityTier {
        model.recommendedOnDeviceTier()
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 24

            ZStack {
                AlphaSetupBackdrop()
                VStack(spacing: 0) {
                    AlphaTopSafeAreaGlass(height: proxy.safeAreaInsets.top + 18)
                    Spacer(minLength: 0)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer(minLength: max(proxy.safeAreaInsets.top + 18, 44))

                        VStack(spacing: 12) {
                            RossAuthHeroMark(size: 78)

                            Text("Set up Ross")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.rossInk)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text("A private legal workbench for your matters.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 430)

                        VStack(spacing: 10) {
                            ForEach(Array(featurePills.enumerated()), id: \.offset) { _, pill in
                                RossInfoPill(title: pill.0, systemImage: pill.1)
                            }
                        }
                        .frame(maxWidth: 430)

                        Spacer(minLength: 16)

                        Button("Set up Ross") {
                            model.selectedTier = recommendedTier
                            model.finishPackSetup()
                        }
                        .buttonStyle(AlphaSetupPrimaryButtonStyle())
                        .frame(maxWidth: 430)

                        Button("Skip for now") {
                            model.skipPackSetup()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.62))

                        Text("No matter files leave this phone during setup.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.rossInk.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 430)

                        Spacer(minLength: max(proxy.safeAreaInsets.bottom + 18, 36))
                    }
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
