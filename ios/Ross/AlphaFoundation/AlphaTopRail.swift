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

struct AlphaTabShell: View {
    @Bindable var model: AlphaRossModel
    let authController: RossAuthController?

    var body: some View {
        Group {
            switch model.persisted.selectedTab {
            case .today, .home:
                AlphaTodayWorkbenchScreen(model: model)
            case .matters:
                AlphaMattersWorkbenchScreen(model: model)
            case .files:
                AlphaFilesWorkbenchScreen(model: model)
            case .work:
                AlphaPreparedWorkScreen(model: model)
            case .settings:
                AlphaSettingsScreen(model: model, authController: authController)
            }
        }
            .safeAreaInset(edge: .top, spacing: 0) {
                AlphaRootTopRail(
                    model: model,
                    onCompose: { model.openAsk() },
                    onCreateMatter: { model.path.append(.createCase) }
                )
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 6)
                .background {
                    Rectangle()
                        .fill(Color.clear)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent.opacity(0.08),
                            shape: Rectangle(),
                            fallbackFillOpacity: 0.36,
                            fallbackStrokeOpacity: 0.14
                        )
                        .ignoresSafeArea(edges: .top)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if model.persisted.selectedTab != .settings {
                        AlphaRootAskDock(
                            model: model,
                            fixedScopeCaseID: nil,
                            showsInlineResponseCard: true,
                            collapsesWhenIdle: true
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }

                    AlphaWorkbenchTabBar(model: model)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                .background {
                    Rectangle()
                        .fill(Color.clear)
                        .rossNativeGlassSurface(
                            tint: Color.rossAccent.opacity(0.08),
                            shape: Rectangle(),
                            fallbackFillOpacity: 0.78,
                            fallbackStrokeOpacity: 0.16
                        )
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .tint(Color.rossAccent)
    }
}

struct AlphaWorkbenchTabBar: View {
    @Bindable var model: AlphaRossModel

    private let tabs: [AlphaAppTab] = [.today, .matters, .files, .work, .settings]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.rawValue) { tab in
                let isSelected = tab == model.persisted.selectedTab || (tab == .today && model.persisted.selectedTab == .home)
                Button {
                    alphaHaptic(.selection)
                    model.persisted.selectedTab = tab
                    model.persist(workspaceChanged: false)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? Color.rossAccent : Color.rossInk.opacity(0.56))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .rossNativeGlassSurface(
                        tint: isSelected ? Color.rossAccent : Color.rossInk.opacity(0.22),
                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: isSelected ? 0.72 : 0.18,
                        fallbackStrokeOpacity: isSelected ? 0.38 : 0.16
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(4)
        .rossGlassSurface(
            tint: Color.rossAccent,
            cornerRadius: 14,
            shadowOpacity: 0.10,
            shadowRadius: 10,
            shadowY: 4,
            fillOpacity: 0.78,
            strokeOpacity: 0.48
        )
    }
}

struct AlphaTodayWorkbenchScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        let work = model.preparedWorkNeedingAttention()
        let visibleWork = Array(work.prefix(3))
        let todayDates = model.todayDateRows()
        let todayTasks = model.todayTasks()
        let upcomingDates = model.upcomingDateRows()
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
                LazyVStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    RossHeroCard(
                    eyebrow: alphaGreeting(),
                    title: work.isEmpty ? "No prepared work needs review" : alphaPreparedWorkHeadline(work.count),
                    detail: nil,
                    showsMedia: false,
                    mediaHeight: 108,
                    logoSize: 58
                ) {
                    AlphaLocalPrivacyBadge()
                }

                if let setupJob = alphaActiveAssistantSetupJob(from: model.persisted.modelJobs) {
                    AlphaAssistantSetupProgressCard(model: model, job: setupJob)
                }

                if visibleWork.isEmpty {
                    AlphaHonestEmptyCard(title: "Nothing prepared yet", detail: "Import matter files or ask Ross to prepare today. Ross will not invent work without local matter state.")
                } else {
                    ForEach(visibleWork) { item in
                        AlphaPreparedWorkCard(model: model, item: item, prominent: visibleWork.first?.id == item.id)
                    }

                    if work.count > visibleWork.count {
                        Button {
                            alphaHaptic(.selection)
                            model.persisted.selectedTab = .work
                            model.persist(workspaceChanged: false)
                        } label: {
                            HStack(spacing: 10) {
                                Text("View all \(alphaPreparedWorkCountLabel(work.count))")
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(Color.rossInk)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .rossGlassSurface(
                                tint: Color.rossAccent,
                                cornerRadius: 18,
                                interactive: true,
                                shadowOpacity: 0.08,
                                shadowRadius: 8,
                                shadowY: 3,
                                fillOpacity: 0.82,
                                strokeOpacity: 0.48
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                AlphaTodayDatesCard(title: "Upcoming dates and urgent tasks", dates: todayDates + Array(upcomingDates.prefix(3)), tasks: Array(todayTasks.prefix(3)), model: model)
                }
                .padding(alphaScreenPadding)
                .padding(.bottom, 116)
            }
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaMattersWorkbenchScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        let matters = model.cases.filter { $0.id != alphaSharedWorkspaceID }
        ScrollView {
            RossGlassGroup(spacing: 14) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    AlphaInlineHeader(eyebrow: "Matters", title: "Matter workspaces", detail: "\(matters.count) active")
                if matters.isEmpty {
                    AlphaMatterStarterCard(model: model)
                } else {
                    ForEach(matters) { caseMatter in
                        Button {
                            model.focusCase(caseMatter.id)
                            model.path.append(.caseWorkspace(caseMatter.id))
                        } label: {
                            AlphaCaseSummaryCard(model: model, caseMatter: caseMatter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                }
                .padding(alphaScreenPadding)
                .padding(.bottom, 116)
            }
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaFilesWorkbenchScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        let documents = model.recentDocumentItems()
        ScrollView {
            RossGlassGroup(spacing: 14) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    AlphaInlineHeader(eyebrow: "Files", title: "Local file room", detail: "\(documents.count) file(s) across matters")
                if documents.isEmpty {
                    AlphaHonestEmptyCard(title: "No files imported", detail: "Files you import stay inspectable here after local extraction.")
                } else {
                    ForEach(documents) { entry in
                        Button {
                            model.focusCase(entry.caseId)
                            model.path.append(.documentViewer(entry.caseId, entry.document.id, 1))
                        } label: {
                            AlphaDocumentRow(caseTitle: entry.caseTitle, document: entry.document, showChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                }
                .padding(alphaScreenPadding)
                .padding(.bottom, 116)
            }
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaPreparedWorkScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var statusFilter: AlphaPreparedWorkStatus?

    var body: some View {
        let items = model.preparedWorkItems(includeDismissed: true)
            .filter { statusFilter == nil || $0.status == statusFilter }
        let grouped = Dictionary(grouping: items, by: { $0.matterName })
        ScrollView {
            RossGlassGroup(spacing: 14) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack {
                    AlphaInlineHeader(eyebrow: "Work", title: "Prepared work inbox", detail: alphaPreparedWorkCountLabel(items.count))
                    Spacer(minLength: 0)
                    Menu {
                        Button("All") { statusFilter = nil }
                        ForEach(AlphaPreparedWorkStatus.allCases, id: \.rawValue) { status in
                            Button(status.title) { statusFilter = status }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 34, height: 34)
                            .rossGlassSurface(
                                tint: Color.rossAccent,
                                cornerRadius: 17,
                                interactive: true,
                                shadowOpacity: 0.07,
                                shadowRadius: 7,
                                shadowY: 3,
                                fillOpacity: 0.80,
                                strokeOpacity: 0.46
                            )
                    }
                }

                if items.isEmpty {
                    AlphaHonestEmptyCard(title: "No prepared work", detail: "Ross only shows prepared work generated from real saved matters, files, dates, tasks, drafts, public-law previews, and source refs.")
                } else {
                    ForEach(grouped.keys.sorted(), id: \.self) { matterName in
                        VStack(alignment: .leading, spacing: 10) {
                            AlphaWorkspaceSectionLabel(title: matterName, detail: alphaPreparedWorkCountLabel(grouped[matterName]?.count ?? 0))
                            ForEach(grouped[matterName] ?? []) { item in
                                AlphaPreparedWorkCard(model: model, item: item, prominent: false)
                            }
                        }
                    }
                }
                }
                .padding(alphaScreenPadding)
                .padding(.bottom, 116)
            }
        }
        .rossHideNavigationBarIfSupported()
    }
}

struct AlphaLocalPrivacyBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 13, weight: .semibold))
            Text("Works locally on this device")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.rossInk.opacity(0.76))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .rossGlassSurface(
            tint: Color.rossAccent,
            cornerRadius: 16,
            shadowOpacity: 0.06,
            shadowRadius: 6,
            shadowY: 2,
            fillOpacity: 0.80,
            strokeOpacity: 0.46
        )
    }
}

struct AlphaPreparedWorkCard: View {
    @Bindable var model: AlphaRossModel
    let item: AlphaPreparedWorkItem
    let prominent: Bool

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.matterName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.rossInk.opacity(0.58))
                        Text(item.title)
                            .font((prominent ? Font.headline : Font.subheadline).weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                        Text(item.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text(item.badge.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(alphaPreparedBadgeColor(item.badge))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .rossNativeGlassSurface(
                            tint: alphaPreparedBadgeColor(item.badge),
                            shape: Capsule(),
                            fallbackFillOpacity: 0.68,
                            fallbackStrokeOpacity: 0.36
                        )
                }

                if !item.sourceRefs.isEmpty {
                    AlphaSourceRefChips(sourceRefs: item.sourceRefs, contextDocumentTitle: nil) { sourceRef in
                        model.path.append(.documentViewer(sourceRef.caseId, sourceRef.documentId, sourceRef.pageNumber))
                    }
                }

                HStack(spacing: 8) {
                    Button(item.primaryAction) {
                        alphaHaptic(.selection)
                        alphaHandlePreparedPrimaryAction(item, model: model)
                    }
                    .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14)

                    Button("Accept") {
                        model.setPreparedWorkStatus(item.id, status: .accepted)
                    }
                    .rossGlassButtonStyle(tint: Color.rossSuccess, cornerRadius: 14, expandsHorizontally: false)

                    Button("Edit") {
                        alphaHandlePreparedEdit(item, model: model)
                    }
                    .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 14, expandsHorizontally: false)

                    Button("Dismiss") {
                        model.setPreparedWorkStatus(item.id, status: .dismissed)
                    }
                    .rossGlassButtonStyle(tint: Color.rossInk.opacity(0.42), cornerRadius: 14, expandsHorizontally: false)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}

struct AlphaTodayDatesCard: View {
    let title: String
    let dates: [AlphaUpcomingDateRow]
    let tasks: [AlphaTaskItem]
    @Bindable var model: AlphaRossModel

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                AlphaWorkspaceSectionLabel(title: title, detail: alphaPlainItemCountLabel(dates.count + tasks.count))
                if dates.isEmpty && tasks.isEmpty {
                    Text("No dates or urgent tasks saved for today.")
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.66))
                } else {
                    ForEach(Array(dates.enumerated()), id: \.offset) { _, row in
                        AlphaSummaryRow(title: row.title, detail: row.detail, tint: Color.rossAccent)
                    }
                    ForEach(tasks) { task in
                        AlphaTaskRow(task: task, onToggle: { model.toggleTaskDone(task.id) })
                    }
                }
            }
        }
    }
}

struct AlphaHonestEmptyCard: View {
    let title: String
    let detail: String

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AlphaAssistantSetupProgressCard: View {
    @Bindable var model: AlphaRossModel
    let job: AlphaModelDownloadJob

    var body: some View {
        RossSectionCard(title: "Setting up Ross", subtitle: alphaAssistantStateLabel(job.state)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(job.tier.title) is being prepared on this iPhone. You can keep using Ross while setup continues.")
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if let progress = alphaDownloadProgressValue(job) {
                    ProgressView(value: progress)
                        .tint(Color.rossAccent)
                    Text(alphaAssistantSetupProgressLabel(job))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                }

                Button("Open assistant setup") {
                    alphaHaptic(.selection)
                    model.path.append(.privateAISettings)
                }
                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
            }
        }
    }
}

private func alphaActiveAssistantSetupJob(from jobs: [AlphaModelDownloadJob]) -> AlphaModelDownloadJob? {
    jobs
        .filter {
            $0.state == .queued ||
                $0.state == .downloading ||
                $0.state == .verifying ||
                $0.state == .pausedWaitingForWifi ||
                $0.state == .pausedNoStorage ||
                $0.state == .pausedError
        }
        .sorted { $0.updatedAt > $1.updatedAt }
        .first
}

private func alphaAssistantSetupProgressLabel(_ job: AlphaModelDownloadJob) -> String {
    guard job.totalBytes > 0 else { return alphaAssistantStateLabel(job.state) }
    let downloaded = max(0, job.bytesDownloaded)
    let downloadedLabel = ByteCountFormatter.string(fromByteCount: downloaded, countStyle: .file)
    let totalLabel = ByteCountFormatter.string(fromByteCount: job.totalBytes, countStyle: .file)
    return "\(downloadedLabel) of \(totalLabel)"
}

private func alphaPreparedWorkHeadline(_ count: Int) -> String {
    count == 1 ? "1 prepared item needs review" : "\(count) prepared items need review"
}

private func alphaPreparedWorkCountLabel(_ count: Int) -> String {
    count == 1 ? "1 prepared item" : "\(count) prepared items"
}

private func alphaPlainItemCountLabel(_ count: Int) -> String {
    count == 1 ? "1 item" : "\(count) items"
}

private func alphaPreparedBadgeColor(_ badge: AlphaPreparedWorkBadge) -> Color {
    switch badge {
    case .sourceBacked:
        Color.green
    case .preparedLocally:
        Color.rossAccent
    case .needsReview:
        Color.orange
    case .approvalRequired:
        Color.red
    }
}

@MainActor
private func alphaHandlePreparedPrimaryAction(_ item: AlphaPreparedWorkItem, model: AlphaRossModel) {
    if item.type == .publicLawQueryAwaitingApproval {
        Task { await model.confirmPendingPublicLawSearch() }
        return
    }
    if let ref = item.sourceRefs.first {
        model.path.append(.documentViewer(ref.caseId, ref.documentId, ref.pageNumber))
        model.setPreparedWorkStatus(item.id, status: .reviewed)
        return
    }
    if let caseId = item.caseId {
        model.path.append(.caseWorkspace(caseId))
        model.setPreparedWorkStatus(item.id, status: .reviewed)
    }
}

@MainActor
private func alphaHandlePreparedEdit(_ item: AlphaPreparedWorkItem, model: AlphaRossModel) {
    if let caseId = item.caseId {
        model.openAsk(scopeCaseID: caseId)
    } else {
        model.openAsk()
    }
    model.setPreparedWorkStatus(item.id, status: .reviewed)
}

struct AlphaRootTopRail: View {
    @Bindable var model: AlphaRossModel
    let onCompose: () -> Void
    let onCreateMatter: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image("RossLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        fallbackFillOpacity: 0.82,
                        fallbackStrokeOpacity: 0.48
                    )

                Text("Ross")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
            }

            Spacer(minLength: 0)

            AlphaTopRailIconButton(
                systemImage: "square.and.pencil",
                accessibilityLabel: "Compose chat",
                action: {
                    alphaHaptic(.selection)
                    onCompose()
                }
            )

            AlphaGlassPlusButton {
                alphaHaptic(.selection)
                onCreateMatter()
            }

            AlphaTopRailIconButton(
                systemImage: "slider.horizontal.3",
                accessibilityLabel: "Settings",
                action: {
                    alphaHaptic(.selection)
                    model.persisted.selectedTab = .settings
                    model.persist()
                }
            )
        }
    }
}

struct AlphaTopRailIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.rossInk)
                .frame(width: 34, height: 34)
                .rossGlassSurface(
                    tint: Color.rossAccent,
                    cornerRadius: 17,
                    interactive: true,
                    shadowOpacity: 0.07,
                    shadowRadius: 7,
                    shadowY: 3,
                    fillOpacity: 0.80,
                    strokeOpacity: 0.46
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
