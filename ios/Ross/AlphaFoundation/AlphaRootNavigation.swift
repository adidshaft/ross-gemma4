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
                .rossAppBackdrop()
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
                model.refreshPrivateAISnapshot(forceRebuild: true)
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
            model.refreshPrivateAISnapshot(forceRebuild: true)
            model.checkForAssistantModelUpdates()
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
        } ?? rossLocalized("new_matter")
    }

    private var resolvedNewMatterTitle: String {
        let trimmed = newMatterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultMatterTitle : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                RossGlassGroup(spacing: 18) {
                    VStack(alignment: .leading, spacing: 18) {
                        RossHeroCard(
                            eyebrow: alphaSharedFilesCountLabel(incomingFileNames.count),
                            title: rossLocalized("shared_files_add_to_matter"),
                            detail: rossLocalized("shared_files_private_storage_detail"),
                            showsMedia: false,
                            mediaHeight: 96,
                            logoSize: 54
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(incomingFileNames, id: \.self) { fileName in
                                    AlphaIncomingFileRow(fileName: fileName)
                                }
                            }
                        }

                        if !matterOptions.isEmpty {
                            RossSectionCard(title: rossLocalized("import_existing_matter")) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(matterOptions) { matter in
                                        Button {
                                            alphaHaptic(.light)
                                            model.importQueuedIncomingDocuments(to: matter.id)
                                            dismiss()
                                        } label: {
                                            AlphaIncomingMatterRow(matter: matter)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        RossSectionCard(title: rossLocalized("create_new_matter")) {
                            VStack(alignment: .leading, spacing: 14) {
                                AlphaIncomingMatterTitleField(
                                    placeholder: defaultMatterTitle,
                                    text: $newMatterTitle
                                )

                                Button {
                                    alphaHaptic(.light)
                                    model.createMatterForQueuedIncomingDocuments(title: resolvedNewMatterTitle)
                                    dismiss()
                                } label: {
                                    Label(rossLocalized("create_matter_import_files"), systemImage: "plus.circle.fill")
                                }
                                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 18)
                                .accessibilityHint(alphaCreateMatterImportHint(resolvedNewMatterTitle))
                            }
                        }
                    }
                    .padding(alphaScreenPadding)
                }
            }
            .rossAppBackdrop()
            .navigationTitle(rossLocalized("shared_files"))
            .rossInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(rossLocalized("cancel")) {
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

private struct AlphaIncomingFileRow: View {
    let fileName: String

    var body: some View {
        HStack(spacing: 10) {
            RossGlassIconView(.file, variant: .accent, size: 22, fallbackSystemImage: "doc")
            Text(fileName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.rossInk)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Image(systemName: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.42))
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .rossNativeGlassSurface(
            tint: Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
            fallbackFillOpacity: 0.78,
            fallbackStrokeOpacity: 0.42
        )
        .shadow(color: Color.rossShadow.opacity(0.05), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(alphaIncomingFileReadyLabel(fileName))
    }
}

private struct AlphaIncomingMatterTitleField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rossLocalized("matter_name"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.64))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.rossInk)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .rossNativeGlassSurface(
                    tint: isFocused ? Color.rossAccent : Color.rossHighlight,
                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                    interactive: true,
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: 0.52
                )
                .shadow(color: Color.rossShadow.opacity(isFocused ? 0.10 : 0.06), radius: isFocused ? 10 : 6, y: isFocused ? 4 : 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isFocused ? Color.rossAccent.opacity(0.28) : Color.rossGlassStroke.opacity(0.72),
                            lineWidth: 1
                        )
                }
                .accessibilityLabel(rossLocalized("matter_name"))
                .submitLabel(.done)
        }
    }
}

func alphaSharedFilesCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("shared_files_count", languageCode: languageCode), count)
}

func alphaIncomingFileReadyLabel(_ fileName: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("incoming_file_ready", languageCode: languageCode), fileName)
}

func alphaCreateMatterImportHint(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("create_matter_import_hint", languageCode: languageCode), title)
}

private struct AlphaIncomingMatterRow: View {
    let matter: AlphaCaseMatter

    var body: some View {
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
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.76,
            fallbackStrokeOpacity: 0.44
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
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
