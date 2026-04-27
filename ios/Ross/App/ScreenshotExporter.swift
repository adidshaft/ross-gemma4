import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

enum RossLaunchMode {
    case interactive
    case screenshotExport
    case localModelSmoke

    static var current: RossLaunchMode {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--generate-screenshots") {
            return .screenshotExport
        }
        if arguments.contains("--local-model-smoke") {
            return .localModelSmoke
        }
        return .interactive
    }
}

struct RossLocalModelSmokeView: View {
    @State private var status = "Running local model smoke..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .task {
            await runSmoke()
        }
    }

    @MainActor
    private func runSmoke() async {
        let model = AlphaRossModel()
        await model.loadIfNeeded()

        guard let activePack = model.activePack else {
            status = "No active local model pack."
            print("ROSS_LOCAL_MODEL_SMOKE_FAIL no_active_pack")
            return
        }

        let health = model.activeRuntimeHealth
        print(
            "ROSS_LOCAL_MODEL_SMOKE_HEALTH runtime=\(health?.runtimeMode.rawValue ?? "nil") available=\(health?.available == true) model=\(health?.modelPathLabel ?? "nil") checksum=\(health?.checksumVerified == true)"
        )

        guard let provider = AlphaLocalModelRuntime.resolveProvider(
            activePack: activePack,
            requestedTier: activePack.tier,
            executor: { _ in
                AlphaLocalModelOutput(
                    rawText: "",
                    parsedJson: nil,
                    schemaValid: false,
                    warnings: ["Smoke fallback should not run."],
                    sourceRefs: [],
                    errorCategory: "smoke_fallback_used"
                )
            }
        ), provider.runtimeMode != .deterministicDev else {
            status = "Real local provider unavailable."
            print("ROSS_LOCAL_MODEL_SMOKE_FAIL provider_unavailable runtime=\(model.activeRuntimeHealth?.runtimeMode.rawValue ?? "nil")")
            return
        }

        let sourceRef = AlphaSourceRef(
            caseId: UUID(),
            documentId: UUID(),
            documentTitle: "Local Smoke Source",
            pageNumber: 1,
            textSnippet: "Article 417 requires the advocate to verify citations before filing."
        )
        let sourceBoundInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "Answer from the supplied source. What does Article 417 require? Return JSON with headline, sections, and statusNote.",
            sourcePack: [
                AlphaSourceTextBlock(
                    sourceRef: sourceRef,
                    text: "Local smoke source: Article 417 requires the advocate to verify citations before filing. It does not authorize automatic legal advice.",
                    pageNumber: 1,
                    languageHint: "en",
                    ocrConfidence: 1
                )
            ],
            expectedSchema: #"{"headline":"short string","sections":["one concise string"],"statusNote":"short string"}"#,
            maxOutputTokens: 192,
            languageProfile: nil,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: true
        )
        let generalInput = AlphaLocalModelInput(
            task: .matterQuestionAnswer,
            instruction: "No matter document is supplied. Answer cautiously: what should an advocate know when someone asks 'What is Article 417?' Return JSON with headline, sections, and statusNote.",
            sourcePack: [],
            expectedSchema: #"{"headline":"short string","sections":["one concise string"],"statusNote":"short string"}"#,
            maxOutputTokens: 192,
            languageProfile: nil,
            documentClassification: nil,
            extractionMode: .fromInstalledPack(activePack),
            requireSourceRefs: false
        )

        let started = Date()
        let sourceBoundOutput = await provider.run(sourceBoundInput)
        let generalOutput = await provider.run(generalInput)
        let elapsed = Date().timeIntervalSince(started)
        let rawPreview = String(sourceBoundOutput.rawText.replacingOccurrences(of: "\n", with: " ").prefix(500))
        let parsedPreview = String((sourceBoundOutput.parsedJson ?? "").prefix(500))
        let generalParsedPreview = String((generalOutput.parsedJson ?? generalOutput.rawText).replacingOccurrences(of: "\n", with: " ").prefix(500))

        if sourceBoundOutput.schemaValid,
           sourceBoundOutput.errorCategory == nil,
           generalOutput.schemaValid,
           generalOutput.errorCategory == nil {
            status = "Local model smoke passed."
            print("ROSS_LOCAL_MODEL_SMOKE_PASS runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_raw=\(rawPreview) source_parsed=\(parsedPreview) general_parsed=\(generalParsedPreview)")
        } else {
            status = "Local model smoke failed."
            print("ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=\(provider.runtimeMode.rawValue) tier=\(activePack.tier.rawValue) elapsed=\(String(format: "%.2f", elapsed))s source_error=\(sourceBoundOutput.errorCategory ?? "nil") general_error=\(generalOutput.errorCategory ?? "nil") source_warnings=\(sourceBoundOutput.warnings.joined(separator: " | ")) general_warnings=\(generalOutput.warnings.joined(separator: " | ")) source_raw=\(rawPreview) general_raw=\(generalParsedPreview)")
        }
    }
}

struct ScreenshotExportView: View {
    @State private var status = "Rendering screenshots..."

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
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try clearExistingScreenshots(using: fileManager)

        let onboardingState = makePreviewState(stage: .onboarding)
        let assistantSetupState = makePreviewState(stage: .privateAIPack)
        let homeState = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        let importState = makePreviewState(stage: .completed, selectedTab: .capture, activePack: .caseAssociate)
        let workspaceState = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        let reviewFixture = makeReviewFixtureState()

        var exportedCount = 0

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: onboardingState)),
            name: "ios-onboarding",
            size: CGSize(width: 430, height: 932)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: assistantSetupState)),
            name: "ios-private-assistant",
            size: CGSize(width: 430, height: 932)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: homeState)),
            name: "ios-home",
            size: CGSize(width: 430, height: 1180)
        )
        exportedCount += 1

        try render(
            AlphaRossRootView(initialModel: AlphaRossModel(previewState: importState)),
            name: "ios-import",
            size: CGSize(width: 430, height: 1180)
        )
        exportedCount += 1

        if let workspaceCaseID = workspaceState.cases.first?.id {
            try render(
                AlphaRossRootView(
                    initialModel: AlphaRossModel(
                        previewState: workspaceState,
                        previewPath: [.caseWorkspace(workspaceCaseID)]
                    )
                ),
                name: "ios-case-workspace",
                size: CGSize(width: 430, height: 1180)
            )
            exportedCount += 1
        }

        try render(
            AlphaRossRootView(
                initialModel: AlphaRossModel(
                    previewState: reviewFixture.state,
                    previewPath: [.documentViewer(reviewFixture.caseID, reviewFixture.documentID, 4)]
                )
            ),
            name: "ios-document-review",
            size: CGSize(width: 430, height: 1320)
        )
        exportedCount += 1

        return exportedCount
    }

    private func clearExistingScreenshots(using fileManager: FileManager) throws {
        let existingFiles = try fileManager.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)
        for file in existingFiles where file.pathExtension.lowercased() == "png" {
            try fileManager.removeItem(at: file)
        }
    }

    private func makePreviewState(
        stage: AlphaOnboardingStage,
        selectedTab: AlphaAppTab = .home,
        activePack: AlphaCapabilityTier? = nil
    ) -> AlphaPersistedState {
        var state = AlphaPersistedState.seed()
        state.onboardingStage = stage
        state.selectedTab = selectedTab

        if let activePack {
            state.settings.activeTier = activePack
            state.installedPacks = [
                AlphaInstalledModelPack(
                    packId: "\(activePack.rawValue)-pack",
                    tier: activePack,
                    installPath: "preview/\(activePack.rawValue).pack",
                    checksumSha256: String(repeating: "a", count: 64),
                    isActive: true
                )
            ]
            state.modelJobs = []
        }

        return state
    }

    private func makeReviewFixtureState() -> (state: AlphaPersistedState, caseID: UUID, documentID: UUID) {
        var state = makePreviewState(stage: .completed, selectedTab: .home, activePack: .caseAssociate)
        guard var caseMatter = state.cases.first, var document = state.cases.first?.documents.first else {
            return (state, UUID(), UUID())
        }

        let reviewDateSource = AlphaSourceRef(
            caseId: caseMatter.id,
            documentId: document.id,
            documentTitle: document.title,
            pageNumber: 4,
            paragraphRange: "¶2",
            textSnippet: "List the matter on 28 April 2026 for compliance and hearing directions.",
            ocrConfidence: 0.94
        )
        let reviewDirectionSource = AlphaSourceRef(
            caseId: caseMatter.id,
            documentId: document.id,
            documentTitle: document.title,
            pageNumber: 6,
            paragraphRange: "¶4",
            textSnippet: "Reply shall be filed within two weeks with indexed annexures.",
            ocrConfidence: 0.91
        )

        document.languageProfile = AlphaDocumentLanguageProfile(
            documentId: document.id,
            primaryLanguage: .english,
            scriptsDetected: ["latin"],
            confidence: 0.97,
            pageProfiles: [
                AlphaDocumentLanguageProfilePage(pageNumber: 4, language: .english, script: .latin, confidence: 0.97),
                AlphaDocumentLanguageProfilePage(pageNumber: 6, language: .english, script: .latin, confidence: 0.95)
            ]
        )
        document.classification = AlphaLegalDocumentClassification(
            documentId: document.id,
            type: .order,
            subtype: "interim order",
            confidence: 0.73,
            sourceRefs: [reviewDateSource],
            needsReview: true
        )
        document.extractedFields = [
            AlphaExtractedLegalField(
                caseId: caseMatter.id,
                documentId: document.id,
                fieldType: .nextDate,
                label: "Next date",
                value: "28 April 2026",
                sourceRefs: [reviewDateSource],
                confidence: 0.58,
                extractionMode: .caseAssociate,
                extractionPass: .llmExtract,
                needsReview: true
            ),
            AlphaExtractedLegalField(
                caseId: caseMatter.id,
                documentId: document.id,
                fieldType: .orderDirection,
                label: "Order direction",
                value: "Reply to be filed within two weeks with indexed annexures.",
                sourceRefs: [reviewDirectionSource],
                confidence: 0.86,
                extractionMode: .caseAssociate,
                extractionPass: .llmVerify,
                needsReview: false
            )
        ]
        document.extractionFindings = [
            AlphaExtractionFinding(
                caseId: caseMatter.id,
                documentId: document.id,
                kind: .dateConflict,
                message: "The next date should be confirmed against the signed order page before final use.",
                sourceRefs: [reviewDateSource],
                severity: .warning
            )
        ]
        document.extractionRuns = [
            AlphaExtractionRun(
                caseId: caseMatter.id,
                documentId: document.id,
                mode: .caseAssociate,
                status: .needsReview,
                progressState: .needsReview,
                startedAt: .now.addingTimeInterval(-420),
                completedAt: .now.addingTimeInterval(-120),
                pagesProcessed: document.pageCount,
                totalPages: document.pageCount,
                fieldsExtracted: document.extractedFields.count,
                fieldsNeedingReview: 1,
                warnings: ["Next date still needs advocate confirmation."]
            )
        ]
        document.extractedText = """
        Interim order. Reply shall be filed within two weeks with indexed annexures.
        List the matter on 28 April 2026 for compliance and further hearing.
        """
        document.indexingStatus = .indexed
        document.ocrStatus = .nativeText
        document.lastIndexedAt = .now.addingTimeInterval(-120)
        document.dominantSourceSnippet = "Reply shall be filed within two weeks with indexed annexures."

        caseMatter.documents[0] = document
        caseMatter.sourceRefs = [reviewDateSource, reviewDirectionSource] + caseMatter.sourceRefs.filter { $0.documentId != document.id }
        caseMatter.issueHighlights = [
            "Confirm the next date directly from the signed order page.",
            "Use the order direction when preparing the short compliance note."
        ]
        caseMatter.draftTasks = [
            "Confirm the next date in the signed order.",
            "Prepare a short compliance note for reply filing."
        ]
        caseMatter.caseMemoryUpdates.insert(
            AlphaCaseMemoryUpdate(
                caseId: caseMatter.id,
                source: .extractionRun,
                summary: "Ross found an order direction and a next date that still needs advocate confirmation.",
                affectedDocuments: [document.id]
            ),
            at: 0
        )
        caseMatter.updatedAt = .now
        state.cases[0] = caseMatter
        state.tasks = (state.tasks ?? []) + [
            AlphaTaskItem(
                caseId: caseMatter.id,
                title: "Confirm next date in order",
                notes: "Verify the next date from the signed order page before sharing it.",
                dueDate: .now,
                priority: .high,
                source: .extraction
            )
        ]

        return (state, caseMatter.id, document.id)
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

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotExportError.renderFailed(name)
        }

        try pngData.write(to: outputDirectory.appending(path: "\(name).png"))
        #else
        throw ScreenshotExportError.unsupportedPlatform
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
