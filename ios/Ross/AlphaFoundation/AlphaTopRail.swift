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

struct AlphaTabShell: View {
    @Bindable var model: AlphaRossModel
    let authController: RossAuthController?
    @State private var showingSettings = false

    var body: some View {
        AlphaFeedScreen(model: model)
            .safeAreaInset(edge: .top, spacing: 0) {
                AlphaRootTopRail(
                    model: model,
                    onCompose: { model.openAsk() },
                    onOpenSettings: { showingSettings = true },
                    onCreateMatter: { model.path.append(.createCase) }
                )
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 6)
                .background {
                    Rectangle()
                        .fill(Color.rossGroupedBackground.opacity(0.36))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AlphaRootAskDock(
                    model: model,
                    fixedScopeCaseID: nil,
                    showsInlineResponseCard: true,
                    collapsesWhenIdle: true
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    AlphaSettingsScreen(model: model, authController: authController)
                        .navigationDestination(for: AlphaRoute.self) { route in
                            switch route {
                            case .privacyLedger:
                                AlphaPrivacyLedgerScreen(model: model)
                            case .privateAISettings:
                                AlphaPrivateAISettingsScreen(model: model)
                            default:
                                EmptyView()
                            }
                        }
                }
            }
            .tint(Color.rossAccent)
    }
}

struct AlphaRootTopRail: View {
    @Bindable var model: AlphaRossModel
    let onCompose: () -> Void
    let onOpenSettings: () -> Void
    let onCreateMatter: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image("RossLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Ross")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
            }

            Spacer(minLength: 0)

            AlphaTopRailIconButton(
                systemImage: "square.and.pencil",
                accessibilityLabel: "Compose chat",
                action: {
                    alphaHaptic(.selection)
                    onCompose()
                }
            )

            AlphaGlassPlusButton {
                alphaHaptic(.selection)
                onCreateMatter()
            }

            Button {
                alphaHaptic(.selection)
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.rossInk)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }
}

struct AlphaTopRailIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.rossInk)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
