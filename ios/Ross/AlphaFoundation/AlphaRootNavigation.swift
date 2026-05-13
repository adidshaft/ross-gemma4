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
            await model.loadIfNeeded()
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
        .onOpenURL { url in
            model.queueIncomingDocumentURL(url)
        }
        .sheet(isPresented: Binding(
            get: { !model.pendingIncomingDocumentURLs.isEmpty },
            set: { if !$0 { model.clearIncomingDocumentQueue() } }
        )) {
            AlphaIncomingDocumentsSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(model.persisted.settings.appearanceMode.preferredColorScheme)
    }
}

private struct AlphaIncomingDocumentsSheet: View {
    @Bindable var model: AlphaRossModel
    @Environment(\.dismiss) private var dismiss
    @State private var newMatterTitle = ""

    private var matterOptions: [AlphaCaseMatter] {
        model.cases.filter { $0.id != alphaSharedWorkspaceID }
    }

    private var incomingFileNames: [String] {
        model.pendingIncomingDocumentURLs.map { $0.lastPathComponent }
    }

    private var defaultMatterTitle: String {
        model.pendingIncomingDocumentURLs.first.map {
            $0.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
        } ?? "New matter"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add shared files to Ross")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                        Text("Choose an existing matter, or create a new one before Ross copies the files into private storage.")
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(incomingFileNames.count) file\(incomingFileNames.count == 1 ? "" : "s") ready")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.rossInk.opacity(0.58))
                        ForEach(incomingFileNames, id: \.self) { fileName in
                            Label(fileName, systemImage: "doc")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(Color.rossInk)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    if !matterOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Existing matters")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.rossInk.opacity(0.58))
                            ForEach(matterOptions) { matter in
                                Button {
                                    model.importQueuedIncomingDocuments(to: matter.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "folder")
                                            .foregroundStyle(Color.rossAccent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(matter.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.rossInk)
                                            Text(matter.forum)
                                                .font(.caption)
                                                .foregroundStyle(Color.rossInk.opacity(0.58))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.rossInk.opacity(0.38))
                                    }
                                    .padding(12)
                                    .background(Color.rossCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Create a new matter")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.rossInk.opacity(0.58))
                        TextField(defaultMatterTitle, text: $newMatterTitle)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            model.createMatterForQueuedIncomingDocuments(
                                title: newMatterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultMatterTitle : newMatterTitle
                            )
                            dismiss()
                        } label: {
                            Label("Create matter and import", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .rossPrimaryButtonStyle()
                    }
                }
                .padding(alphaScreenPadding)
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationTitle("Shared files")
            .rossInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.clearIncomingDocumentQueue()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if newMatterTitle.isEmpty {
                    newMatterTitle = defaultMatterTitle
                }
            }
        }
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
