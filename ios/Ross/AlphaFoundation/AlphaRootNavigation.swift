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

struct AlphaRossRootView: View {
    @State private var model: AlphaRossModel
    @State private var showingLaunchSplash = true
    @Environment(\.scenePhase) private var scenePhase
    private let authController: RossAuthController?

    init(initialModel: AlphaRossModel = AlphaRossModel(), authController: RossAuthController? = nil) {
        _model = State(initialValue: initialModel)
        self.authController = authController
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $model.path) {
                Group {
                    switch model.persisted.onboardingStage {
                    case .onboarding:
                        AlphaOnboardingScreen(model: model)
                    case .privateAIPack:
                        AlphaOnboardingScreen(model: model)
                    case .completed:
                        AlphaTabShell(model: model, authController: authController)
                    }
                }
                .background(Color.rossGroupedBackground.ignoresSafeArea())
                .navigationDestination(for: AlphaRoute.self) { route in
                    switch route {
                    case .createCase:
                        AlphaCreateCaseScreen(model: model)
                    case .caseWorkspace(let caseId):
                        AlphaCaseWorkspaceScreen(model: model, caseId: caseId)
                    case .documentList(let caseId):
                        AlphaDocumentListScreen(model: model, caseId: caseId)
                    case .documentViewer(let caseId, let documentId, let page):
                        AlphaDocumentViewerScreen(model: model, caseId: caseId, documentId: documentId, initialPage: page)
                    case .askRoss:
                        AlphaAskRossScreen(model: model)
                    case .askCase(let caseId):
                        AlphaAskCaseScreen(model: model, caseId: caseId)
                    case .exports(let caseId):
                        AlphaExportsScreen(model: model, caseId: caseId)
                    case .privacyLedger:
                        AlphaPrivacyLedgerScreen(model: model)
                    case .privateAISettings:
                        AlphaPrivateAISettingsScreen(model: model)
                    }
                }
            }

            if showingLaunchSplash {
                RossLaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task(id: authController?.session?.subject) {
            let loadTask = Task {
                await model.loadIfNeeded()
            }
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                if showingLaunchSplash {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showingLaunchSplash = false
                    }
                }
            }
            await loadTask.value
            await MainActor.run {
                model.syncWorkspaceForSession(authController?.session)
                model.runMorningRoutineIfNeeded()
                model.checkForAssistantModelUpdates()
                if showingLaunchSplash {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showingLaunchSplash = false
                    }
                }
            }
        }
        .onChange(of: model.path) { _, newPath in
            model.clearStaleAskState(for: newPath.last)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.runMorningRoutineIfNeeded()
        }
        .preferredColorScheme(model.persisted.settings.appearanceMode.preferredColorScheme)
    }
}

extension AlphaAppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .auto:
            nil
        case .dark:
            .dark
        case .light:
            .light
        }
    }
}
