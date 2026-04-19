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
                            onSelect: { selectedId in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    state.selectedCaseID = selectedId 
                                }
                            }
                        )

                        VStack(alignment: .leading, spacing: 8) {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        WorkspaceSummaryCard(snapshot: selectedCase.workspace)

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
        VStack(alignment: .leading, spacing: 4) {
            Text(caseFile.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.rossInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(caseFile.forum)
                Text("·")
                Text(caseFile.stage.title)
                if let nextHearing = caseFile.nextHearing {
                    Text("·")
                    Text("Hearing \(nextHearing.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(Color.rossAccent)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.rossInk.opacity(0.55))
        }
        .padding(.bottom, 4)
    }
}

private struct CaseSwitcherRail: View {
    let caseFiles: [CaseFile]
    let selectedCaseID: CaseFile.ID?
    let onSelect: (CaseFile.ID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(caseFiles) { caseFile in
                    Button {
                        onSelect(caseFile.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(caseFile.title)
                                .font(.headline)
                                .foregroundStyle(Color.rossInk)
                                .lineLimit(1)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(caseFile.stage.title)
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(Color.rossAccent)
                        }
                        .padding(14)
                        .frame(width: 160, height: 90, alignment: .leading)
                        .background(caseFile.id == selectedCaseID ? Color.rossAccent.opacity(0.04) : Color.rossCardBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    caseFile.id == selectedCaseID ? Color.rossAccent : Color.rossBorder,
                                    lineWidth: caseFile.id == selectedCaseID ? 2 : 1
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: caseFile.id == selectedCaseID ? Color.rossAccent.opacity(0.1) : Color.black.opacity(0.03), radius: caseFile.id == selectedCaseID ? 10 : 6, y: caseFile.id == selectedCaseID ? 4 : 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }
}

private struct WorkspaceStatusStrip: View {
    let caseFile: CaseFile

    var body: some View {
        let indexedCount = caseFile.documents.filter(\.isIndexedLocally).count
        let total = caseFile.documents.count
        let allReady = indexedCount == total

        if total > 0 {
            if allReady {
                Label(
                    "Ross has read all your documents",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(Color.rossSuccess)
            } else {
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
        VStack(alignment: .leading, spacing: 20) {
            Text(snapshot.chronologySummary)
                .font(.subheadline)
                .foregroundStyle(Color.rossInk.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            SummaryBlock(title: "Issue highlights", items: snapshot.issueHighlights)
            SummaryBlock(title: "Evidence notes", items: snapshot.evidenceNotes)
            SummaryBlock(title: "Things to do", items: snapshot.draftTasks)
        }
    }
}

private struct SummaryBlock: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.rossInk.opacity(0.4))

            ForEach(Array(items.prefix(2)), id: \.self) { item in
                Text("· \(item)")
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WorkspaceDocumentsCard: View {
    let documents: [CaseDocument]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DOCUMENTS")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.rossInk.opacity(0.4))
                .padding(.bottom, 10)

            ForEach(documents) { document in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.rossInk)
                            .lineLimit(1)

                        Text("\(document.category) · \(document.pageCount) pages")
                            .font(.caption)
                            .foregroundStyle(Color.rossInk.opacity(0.45))
                    }

                    Spacer()

                    if document.isIndexedLocally {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossSuccess)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Image(systemName: "clock")
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.3))
                            Text("Not yet read")
                                .font(.caption2)
                                .foregroundStyle(Color.rossInk.opacity(0.45))
                        }
                    }
                }
                .padding(.vertical, 10)

                if document.id != documents.last?.id {
                    Divider()
                        .overlay(Color.rossBorder.opacity(0.5))
                }
            }
        }
    }
}
