import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

enum RossLaunchMode {
    case interactive
    case screenshotExport

    static var current: RossLaunchMode {
        ProcessInfo.processInfo.arguments.contains("--generate-screenshots") ? .screenshotExport : .interactive
    }
}

struct ScreenshotExportView: View {
    @State private var status = "Rendering screenshots…"

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 320, minHeight: 180)
        .task {
            await export()
        }
    }

    @MainActor
    private func export() async {
        do {
            let exported = try await RossScreenshotExporter().export()
            status = "Exported \(exported) screenshot(s) to tmp/ui-screenshots"
            terminateSoon()
        } catch {
            status = "Screenshot export failed: \(error.localizedDescription)"
            terminateSoon()
        }
    }

    private func terminateSoon() {
        #if canImport(AppKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApplication.shared.terminate(nil)
        }
        #endif
    }
}

@MainActor
private struct RossScreenshotExporter {
    private let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appending(path: "tmp/ui-screenshots", directoryHint: .isDirectory)

    func export() async throws -> Int {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let onboardingContext = await makeContext(stage: .welcome)
        let packContext = await makeContext(stage: .privateAIPack)
        let workspaceContext = await makeContext(stage: .completed, activePack: .caseAssociate)
        let askCaseContext = await makeContext(stage: .completed, activePack: .caseAssociate)

        try render(
            OnboardingView(state: onboardingContext.state),
            name: "ios-onboarding",
            size: CGSize(width: 430, height: 932)
        )
        try render(
            PrivateAIPackSetupView(
                modelDownloadService: packContext.services.modelDownloadService,
                state: packContext.state,
                settingsStore: packContext.services.settingsStore
            ),
            name: "ios-private-ai-pack",
            size: CGSize(width: 430, height: 932)
        )
        try render(
            CaseWorkspaceView(
                caseRepository: workspaceContext.services.caseRepository,
                privacyLedger: workspaceContext.services.privacyLedgerService,
                localRuntimeService: workspaceContext.services.localRuntimeService,
                state: workspaceContext.state,
                settingsStore: workspaceContext.services.settingsStore
            ),
            name: "ios-workspace",
            size: CGSize(width: 430, height: 1180)
        )
        try render(
            NavigationStack {
                AskCaseView(
                    localRuntimeService: askCaseContext.services.localRuntimeService,
                    state: askCaseContext.state,
                    settingsStore: askCaseContext.services.settingsStore
                )
            },
            name: "ios-ask-case",
            size: CGSize(width: 430, height: 1180)
        )

        return 4
    }

    private func makeContext(
        stage: OnboardingStage,
        activePack: CapabilityTier? = nil
    ) async -> (services: AppServices, state: AppState) {
        let services = AppServices.bootstrap()
        let state = AppState()
        await state.bootstrap(using: services)
        state.onboardingStage = stage

        if let activePack {
            services.settingsStore.activatePack(activePack)
        }

        return (services, state)
    }

    private func render<V: View>(
        _ view: V,
        name: String,
        size: CGSize
    ) throws {
        #if canImport(AppKit)
        let hostingView = NSHostingView(
            rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color.rossGroupedBackground)
                .environment(\.colorScheme, .light)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ScreenshotExportError.renderFailed(name)
        }

        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        guard let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw ScreenshotExportError.renderFailed(name)
        }

        try pngData.write(to: outputDirectory.appending(path: "\(name).png"))
        #else
        throw ScreenshotExportError.unsupportedPlatform
        #endif
    }

    private var screenshotScale: CGFloat {
        #if canImport(AppKit)
        NSScreen.main?.backingScaleFactor ?? 2
        #else
        2
        #endif
    }
}

private enum ScreenshotExportError: LocalizedError {
    case renderFailed(String)
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case let .renderFailed(name):
            "Could not render screenshot \(name)."
        case .unsupportedPlatform:
            "Screenshot export is only configured for the macOS package host."
        }
    }
}
