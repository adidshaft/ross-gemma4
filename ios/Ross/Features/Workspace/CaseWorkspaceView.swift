import SwiftUI

// MARK: - Main Case Screen (no scroll, single glanceable view)

struct CaseWorkspaceView: View {
    let caseRepository: any CaseRepository
    let privacyLedger: PrivacyLedgerService
    let localRuntimeService: any LocalRuntimeServicing
    @Bindable var state: AppState
    @Bindable var settingsStore: LocalSettingsStore

    @State private var showCaseSwitcher = false
    @State private var showAskRoss = false
    @State private var showDocuments = false

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                if let c = selectedCase {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Court · Stage ────────────────────────────────
                        Text("\(c.forum.uppercased()) · \(c.stage.title.uppercased())")
                            .font(.caption.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(Color.rossInk.opacity(0.4))
                            .padding(.top, 16)
                            .padding(.horizontal, 20)

                        Spacer()

                        // ── Next hearing ─────────────────────────────────
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next hearing")
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.4))
                            if let nextHearing = c.nextHearing {
                                Text(nextHearing.formatted(date: .long, time: .omitted))
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Color.rossAccent)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Not scheduled")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(Color.rossInk.opacity(0.25))
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()

                        Divider()
                            .padding(.horizontal, 20)
                            .opacity(0.35)

                        Spacer()

                        // ── Things to do ─────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("THINGS TO DO")
                                .font(.caption.weight(.semibold))
                                .tracking(0.6)
                                .foregroundStyle(Color.rossInk.opacity(0.4))

                            ForEach(c.workspace.draftTasks.prefix(2), id: \.self) { task in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("·")
                                        .foregroundStyle(Color.rossInk.opacity(0.35))
                                    Text(task)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.rossInk.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()

                        // ── Status line ──────────────────────────────────
                        WorkspaceStatusLine(caseFile: c)
                            .padding(.horizontal, 20)

                        Spacer()

                        Divider()
                            .padding(.horizontal, 20)
                            .opacity(0.35)

                        Spacer().frame(height: 20)

                        // ── Primary action ───────────────────────────────
                        Button { showAskRoss = true } label: {
                            Text("Ask Ross")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .rossPrimaryButtonStyle()
                        .padding(.horizontal, 20)

                        // ── Secondary text links ─────────────────────────
                        HStack(spacing: 6) {
                            Button("Capture a note") {
                                state.selectedTab = .capture
                            }
                            Text("·")
                                .foregroundStyle(Color.rossInk.opacity(0.25))
                            Button("Documents") {
                                showDocuments = true
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.rossAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                        .padding(.bottom, 28)

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    // No case selected state
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundStyle(Color.rossInk.opacity(0.2))
                        Text("No matter selected")
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.rossGroupedBackground.ignoresSafeArea())
            .navigationTitle(selectedCase?.title ?? "Ross")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.rossSuccess)
                        .font(.subheadline)
                }
                ToolbarItem(placement: leadingPlacement) {
                    Button { showCaseSwitcher = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.rossAccent)
                    }
                }
            }
            .sheet(isPresented: $showAskRoss) {
                AskCaseView(
                    localRuntimeService: localRuntimeService,
                    state: state,
                    settingsStore: settingsStore
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCaseSwitcher) {
                CaseSwitcherSheet(
                    caseFiles: state.caseFiles,
                    selectedCaseID: state.selectedCaseID,
                    onSelect: { id in
                        state.selectedCaseID = id
                        showCaseSwitcher = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: $showDocuments) {
                DocumentListView(documents: selectedCase?.documents ?? [])
            }
        }
    }

    private var selectedCase: CaseFile? { state.selectedCase }

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .navigationBarTrailing
        #endif
    }

    private var leadingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .cancellationAction
        #else
        .navigationBarLeading
        #endif
    }
}

// MARK: - Status Line

private struct WorkspaceStatusLine: View {
    let caseFile: CaseFile

    var body: some View {
        let indexed = caseFile.documents.filter(\.isIndexedLocally).count
        let total = caseFile.documents.count
        if total == 0 { return AnyView(EmptyView()) }
        let allReady = indexed == total
        return AnyView(
            Label(
                allReady
                    ? "Ross has read all your documents"
                    : "Ross has read \(indexed) of \(total) documents",
                systemImage: allReady ? "checkmark.circle.fill" : "doc.text.magnifyingglass"
            )
            .font(.caption)
            .foregroundStyle(allReady ? Color.rossSuccess : Color.rossInk.opacity(0.5))
        )
    }
}
