import SwiftUI

private enum WorkspaceRoute: String, Identifiable {
    case quickCapture
    case askCase

    var id: String { rawValue }
}

struct CaseWorkspaceView: View {
    let caseRepository: any CaseRepository
    let privacyLedger: PrivacyLedgerService
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore
    @State private var route: WorkspaceRoute?

    var body: some View {
        NavigationSplitView {
            List(state.caseFiles, selection: $state.selectedCaseID) { caseFile in
                CaseListRow(
                    caseFile: caseFile,
                    isSelected: state.selectedCaseID == caseFile.id
                )
                .tag(caseFile.id)
            }
            .navigationTitle("Case Workspace")
        } detail: {
            NavigationStack {
                if let selectedCase = state.selectedCase {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            WorkspaceHeaderCard(caseFile: selectedCase)

                            WorkspaceToolsCard(
                                captureCount: selectedCase.captureInboxCount,
                                onOpenCapture: { route = .quickCapture },
                                onAskCase: { route = .askCase }
                            )

                            WorkspaceSnapshotCard(snapshot: selectedCase.workspace)

                            WorkspaceDocumentCard(documents: selectedCase.documents)
                        }
                        .padding(20)
                    }
                    .navigationTitle(selectedCase.title)
                    .rossInlineNavigationTitle()
                    .navigationDestination(item: $route) { route in
                        switch route {
                        case .quickCapture:
                            QuickCaptureReviewView(
                                caseRepository: caseRepository,
                                privacyLedger: privacyLedger,
                                state: state
                            )
                        case .askCase:
                            AskCaseView(
                                localRuntimeService: localRuntimeService,
                                state: state,
                                settingsStore: settingsStore
                            )
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No case selected",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Create or select a case to open the local workbench.")
                    )
                }
            }
        }
    }
}

private struct CaseListRow: View {
    let caseFile: CaseFile
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(caseFile.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(caseFile.stage.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.rossSecondaryBackground)
                    .clipShape(Capsule())
            }

            Text(caseFile.forum)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(caseFile.localNotice)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .listRowBackground(isSelected ? Color(red: 0.92, green: 0.96, blue: 0.99) : Color.clear)
    }
}

private struct WorkspaceHeaderCard: View {
    let caseFile: CaseFile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(caseFile.forum)
                        .font(.headline)
                    Text(caseFile.localNotice)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Updated")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(caseFile.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                }
            }

            if let nextHearing = caseFile.nextHearing {
                Label(
                    "Next hearing: \(nextHearing.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(.subheadline)
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct WorkspaceToolsCard: View {
    let captureCount: Int
    let onOpenCapture: () -> Void
    let onAskCase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workbench tools")
                .font(.headline)

            HStack(spacing: 12) {
                WorkspaceToolButton(
                    title: "Quick Capture Review",
                    detail: captureCount == 0 ? "No pending captures" : "\(captureCount) item(s) waiting",
                    systemImage: "doc.viewfinder",
                    action: onOpenCapture
                )

                WorkspaceToolButton(
                    title: "Ask This Case",
                    detail: "Run source-backed local review",
                    systemImage: "text.bubble",
                    action: onAskCase
                )
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct WorkspaceToolButton: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.rossSecondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkspaceSnapshotCard: View {
    let snapshot: WorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Case workspace")
                .font(.headline)

            Text(snapshot.chronologySummary)
                .foregroundStyle(.secondary)

            WorkspaceListSection(title: "Issue highlights", items: snapshot.issueHighlights)
            WorkspaceListSection(title: "Evidence notes", items: snapshot.evidenceNotes)
            WorkspaceListSection(title: "Draft tasks", items: snapshot.draftTasks)

            VStack(alignment: .leading, spacing: 10) {
                Text("Source chips")
                    .font(.subheadline.weight(.semibold))
                ForEach(snapshot.sourceAnchors) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.label)
                            .font(.footnote.weight(.semibold))
                        Text(source.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.rossSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct WorkspaceListSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark")
                    .font(.footnote)
            }
        }
    }
}

private struct WorkspaceDocumentCard: View {
    let documents: [CaseDocument]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Documents")
                .font(.headline)

            ForEach(documents) { document in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(document.category) • \(document.pageCount) pages")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: document.isIndexedLocally ? "checkmark.shield" : "clock.badge")
                        .foregroundStyle(document.isIndexedLocally ? .green : .orange)
                }
                .padding(12)
                .background(Color.rossSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
