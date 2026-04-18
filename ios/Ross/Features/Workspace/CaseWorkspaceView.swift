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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let selectedCase {
                        WorkspaceHeroCard(caseFile: selectedCase)

                        CaseSwitcherRail(
                            caseFiles: state.caseFiles,
                            selectedCaseID: state.selectedCaseID,
                            onSelect: { state.selectedCaseID = $0 }
                        )

                        WorkspaceStatusStrip(caseFile: selectedCase)

                        WorkspaceActionRow(
                            captureCount: selectedCase.captureInboxCount,
                            onOpenCapture: { route = .quickCapture },
                            onAskCase: { route = .askCase }
                        )

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                WorkspaceSummaryCard(snapshot: selectedCase.workspace)
                                WorkspaceSourcesCard(snapshot: selectedCase.workspace)
                            }

                            VStack(spacing: 16) {
                                WorkspaceSummaryCard(snapshot: selectedCase.workspace)
                                WorkspaceSourcesCard(snapshot: selectedCase.workspace)
                            }
                        }

                        WorkspaceDocumentsCard(documents: selectedCase.documents)
                    } else {
                        ContentUnavailableView(
                            "No case selected",
                            systemImage: "folder.badge.questionmark",
                            description: Text("Create or select a case to open the local workbench.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }
                }
                .padding(20)
            }
            .background(Color.rossGroupedBackground)
            .navigationTitle("Workspace")
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
        }
    }

    private var selectedCase: CaseFile? {
        state.selectedCase
    }
}

private struct WorkspaceHeroCard: View {
    let caseFile: CaseFile

    var body: some View {
        RossHeroCard(
            eyebrow: caseFile.forum,
            title: caseFile.title,
            detail: "A private case dashboard with source-backed working notes, local status, and the next hearing posture kept close at hand."
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    RossInfoPill(title: caseFile.stage.title, systemImage: "briefcase")
                    RossInfoPill(title: nextHearingText, systemImage: "calendar")
                    RossInfoPill(title: caseFile.localNotice, systemImage: "lock")
                }

                VStack(alignment: .leading, spacing: 10) {
                    RossInfoPill(title: caseFile.stage.title, systemImage: "briefcase")
                    RossInfoPill(title: nextHearingText, systemImage: "calendar")
                    RossInfoPill(title: caseFile.localNotice, systemImage: "lock")
                }
            }
        }
    }

    private var nextHearingText: String {
        guard let nextHearing = caseFile.nextHearing else {
            return "Next hearing not extracted"
        }

        return "Next hearing \(nextHearing.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct CaseSwitcherRail: View {
    let caseFiles: [CaseFile]
    let selectedCaseID: CaseFile.ID?
    let onSelect: (CaseFile.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open matters")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(caseFiles) { caseFile in
                        Button {
                            onSelect(caseFile.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(caseFile.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.rossInk)
                                    .lineLimit(2)

                                Text(caseFile.stage.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(caseFile.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(width: 230, alignment: .leading)
                            .background(caseFile.id == selectedCaseID ? Color.rossAccent.opacity(0.08) : Color.rossCardBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(
                                        caseFile.id == selectedCaseID ? Color.rossAccent : Color.rossBorder,
                                        lineWidth: caseFile.id == selectedCaseID ? 2 : 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct WorkspaceStatusStrip: View {
    let caseFile: CaseFile

    var body: some View {
        let indexedCount = caseFile.documents.filter(\.isIndexedLocally).count

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                RossMetricTile(label: "Indexed", value: "\(indexedCount)/\(caseFile.documents.count) docs", tint: .rossAccent)
                RossMetricTile(label: "Pending capture", value: "\(caseFile.captureInboxCount)", tint: .rossHighlight)
                RossMetricTile(label: "Updated", value: caseFile.lastUpdated.formatted(date: .abbreviated, time: .shortened), tint: .rossSuccess)
            }

            VStack(spacing: 12) {
                RossMetricTile(label: "Indexed", value: "\(indexedCount)/\(caseFile.documents.count) docs", tint: .rossAccent)
                RossMetricTile(label: "Pending capture", value: "\(caseFile.captureInboxCount)", tint: .rossHighlight)
                RossMetricTile(label: "Updated", value: caseFile.lastUpdated.formatted(date: .abbreviated, time: .shortened), tint: .rossSuccess)
            }
        }
    }
}

private struct WorkspaceActionRow: View {
    let captureCount: Int
    let onOpenCapture: () -> Void
    let onAskCase: () -> Void

    var body: some View {
        RossSectionCard(
            title: "Workbench actions",
            subtitle: "Jump into the two tasks advocates tend to need most during a live matter review."
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    RossActionTile(
                        title: "Quick Capture Review",
                        detail: captureCount == 0 ? "No pending captures right now." : "\(captureCount) capture item(s) waiting for filing.",
                        systemImage: "doc.viewfinder",
                        tint: .rossHighlight,
                        action: onOpenCapture
                    )

                    RossActionTile(
                        title: "Ask This Case",
                        detail: "Run a source-backed local review over the indexed file.",
                        systemImage: "text.bubble",
                        tint: .rossAccent,
                        action: onAskCase
                    )
                }

                VStack(spacing: 12) {
                    RossActionTile(
                        title: "Quick Capture Review",
                        detail: captureCount == 0 ? "No pending captures right now." : "\(captureCount) capture item(s) waiting for filing.",
                        systemImage: "doc.viewfinder",
                        tint: .rossHighlight,
                        action: onOpenCapture
                    )

                    RossActionTile(
                        title: "Ask This Case",
                        detail: "Run a source-backed local review over the indexed file.",
                        systemImage: "text.bubble",
                        tint: .rossAccent,
                        action: onAskCase
                    )
                }
            }
        }
    }
}

private struct WorkspaceSummaryCard: View {
    let snapshot: WorkspaceSnapshot

    var body: some View {
        RossSectionCard(
            title: "Working summary",
            subtitle: snapshot.chronologySummary
        ) {
            VStack(alignment: .leading, spacing: 16) {
                WorkspaceListBlock(
                    title: "Issue highlights",
                    items: snapshot.issueHighlights
                )
                WorkspaceListBlock(
                    title: "Evidence notes",
                    items: snapshot.evidenceNotes
                )
                WorkspaceListBlock(
                    title: "Draft tasks",
                    items: snapshot.draftTasks
                )
            }
        }
    }
}

private struct WorkspaceSourcesCard: View {
    let snapshot: WorkspaceSnapshot

    var body: some View {
        RossSectionCard(
            title: "Source chips",
            subtitle: "Tap-through references should stay close to the working answer."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.sourceAnchors) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(source.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rossSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct WorkspaceListBlock: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.rossInk)

            ForEach(items, id: \.self) { item in
                RossBulletRow(text: item)
            }
        }
    }
}

private struct WorkspaceDocumentsCard: View {
    let documents: [CaseDocument]

    var body: some View {
        RossSectionCard(
            title: "Documents",
            subtitle: "A quick scan of what is already indexed locally and what still needs attention."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(documents) { document in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(document.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rossInk)

                            Text("\(document.category) • \(document.pageCount) pages")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text(document.importedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: document.isIndexedLocally ? "checkmark.shield.fill" : "clock.badge")
                            .font(.title3)
                            .foregroundStyle(document.isIndexedLocally ? Color.rossSuccess : Color.rossHighlight)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rossSecondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
