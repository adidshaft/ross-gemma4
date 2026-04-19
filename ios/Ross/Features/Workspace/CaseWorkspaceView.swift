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
                VStack(alignment: .leading, spacing: 32) {
                    if let selectedCase {
                        WorkspaceHeroCard(caseFile: selectedCase)

                        CaseSwitcherRail(
                            caseFiles: state.caseFiles,
                            selectedCaseID: state.selectedCaseID,
                            onSelect: { selectedId in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    state.selectedCaseID = selectedId 
                                }
                            }
                        )

                        WorkspaceStatusStrip(caseFile: selectedCase)

                        if selectedCase.captureInboxCount > 0 {
                            Button {
                                route = .quickCapture
                            } label: {
                                Label(
                                    "You have \(selectedCase.captureInboxCount) captured note\(selectedCase.captureInboxCount == 1 ? "" : "s") to file",
                                    systemImage: "doc.viewfinder"
                                )
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color.rossHighlight.opacity(0.08))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.rossHighlight.opacity(0.3), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 20) {
                                WorkspaceSummaryCard(snapshot: selectedCase.workspace)
                                WorkspaceSourcesCard(snapshot: selectedCase.workspace)
                            }

                            VStack(spacing: 20) {
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
                .padding(24)
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationTitle("Workspace")
            .rossInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: askRossToolbarPlacement) {
                    Button {
                        route = .askCase
                    } label: {
                        Label("Ask Ross", systemImage: "bubble.left.and.text.bubble.right")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { route == .askCase },
                set: { if !$0 { route = nil } }
            )) {
                AskCaseView(
                    localRuntimeService: localRuntimeService,
                    state: state,
                    settingsStore: settingsStore
                )
            }
            .navigationDestination(isPresented: Binding(
                get: { route == .quickCapture },
                set: { if !$0, route == .quickCapture { route = nil } }
            )) {
                QuickCaptureReviewView(
                    caseRepository: caseRepository,
                    privacyLedger: privacyLedger,
                    state: state
                )
            }
        }
    }

    private var selectedCase: CaseFile? {
        state.selectedCase
    }

    private var askRossToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .navigationBarTrailing
        #endif
    }
}

private struct WorkspaceHeroCard: View {
    let caseFile: CaseFile

    var body: some View {
        RossHeroCard(
            eyebrow: caseFile.forum,
            title: caseFile.title,
            detail: nil
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    RossInfoPill(title: caseFile.stage.title, systemImage: "briefcase")
                    RossInfoPill(title: nextHearingText, systemImage: "calendar")
                    RossInfoPill(title: "Stored on this phone", systemImage: "lock.shield")
                }

                VStack(alignment: .leading, spacing: 10) {
                    RossInfoPill(title: caseFile.stage.title, systemImage: "briefcase")
                    RossInfoPill(title: nextHearingText, systemImage: "calendar")
                    RossInfoPill(title: "Stored on this phone", systemImage: "lock.shield")
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Open matters")
                .font(.rossSerifHeadline())
                .foregroundStyle(Color.rossInk)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(caseFiles) { caseFile in
                        Button {
                            onSelect(caseFile.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(caseFile.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.rossInk)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(caseFile.stage.title)
                                        .font(.caption.weight(.bold))
                                        .tracking(1)
                                        .foregroundStyle(Color.rossAccent)

                                    Text(caseFile.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(Color.rossInk.opacity(0.5))
                                }
                            }
                            .padding(20)
                            .frame(width: 240, height: 160, alignment: .leading)
                            .background(caseFile.id == selectedCaseID ? Color.rossAccent.opacity(0.04) : Color.rossCardBackground)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        caseFile.id == selectedCaseID ? Color.rossAccent : Color.rossBorder,
                                        lineWidth: caseFile.id == selectedCaseID ? 2 : 1
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: caseFile.id == selectedCaseID ? Color.rossAccent.opacity(0.1) : Color.black.opacity(0.03), radius: caseFile.id == selectedCaseID ? 12 : 8, y: caseFile.id == selectedCaseID ? 6 : 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, -4)
        }
    }
}

private struct WorkspaceStatusStrip: View {
    let caseFile: CaseFile

    var body: some View {
        let indexedCount = caseFile.documents.filter(\.isIndexedLocally).count
        let total = caseFile.documents.count
        let allReady = indexedCount == total

        VStack(alignment: .leading, spacing: 6) {
            if !allReady {
                Label(
                    "Ross has read \(indexedCount) of \(total) documents",
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.subheadline)
                .foregroundStyle(Color.rossInk.opacity(0.7))
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
            VStack(alignment: .leading, spacing: 24) {
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
            title: "References",
            subtitle: nil
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.sourceAnchors) { source in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text(source.note)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.6))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rossGroupedBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.rossBorder, lineWidth: 1)
                    }
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
        VStack(alignment: .leading, spacing: 12) {
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
            subtitle: "A quick scan of what Ross has read and what still needs attention."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(documents) { document in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(document.title)
                                .font(.headline)
                                .foregroundStyle(Color.rossInk)

                            Text("\(document.category) • \(document.pageCount) pages")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.6))

                            Text(document.importedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.rossInk.opacity(0.4))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(document.isIndexedLocally ? Color.rossSuccess.opacity(0.1) : Color.rossHighlight.opacity(0.1))
                                    .frame(width: 40, height: 40)

                                Image(systemName: document.isIndexedLocally ? "checkmark.shield.fill" : "clock.badge")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(document.isIndexedLocally ? Color.rossSuccess : Color.rossHighlight)
                            }

                            if !document.isIndexedLocally {
                                Text("Not yet read by Ross")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.rossHighlight)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rossGroupedBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.rossBorder, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }
}
