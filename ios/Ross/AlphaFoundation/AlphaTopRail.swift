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
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background {
                    AlphaChromeEdgeFade(edge: .top)
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
                    AlphaChromeEdgeFade(edge: .bottom)
                }
            }
            .tint(Color.rossAccent)
    }
}

private struct AlphaChromeEdgeFade: View {
    enum Edge {
        case top
        case bottom
    }

    @Environment(\.colorScheme) private var colorScheme
    let edge: Edge

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .blur(radius: 18)
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }

    private var gradientColors: [Color] {
        let base = Color.rossGroupedBackground
        let shadow = colorScheme == .dark ? Color.black : Color.rossShadow
        return [
            base.opacity(colorScheme == .dark ? 0.98 : 0.92),
            base.opacity(colorScheme == .dark ? 0.82 : 0.68),
            shadow.opacity(colorScheme == .dark ? 0.34 : 0.16),
            Color.clear
        ]
    }
}

struct AlphaWorkbenchTabBar: View {
    @Bindable var model: AlphaRossModel

    private let tabs: [AlphaAppTab] = [.today, .matters, .files, .work, .settings]

    var body: some View {
        HStack(spacing: 5) {
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
                    .frame(height: 44)
                    .rossNativeGlassSurface(
                        tint: isSelected ? Color.rossAccent : Color.rossInk.opacity(0.22),
                        shape: RoundedRectangle(cornerRadius: 12, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: isSelected ? 0.72 : 0.18,
                        fallbackStrokeOpacity: isSelected ? 0.38 : 0.16
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(3)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 15, style: .continuous),
            fallbackFillOpacity: 0.46,
            fallbackStrokeOpacity: 0.34
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
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
                    VStack(alignment: .leading, spacing: 10) {
                        AlphaInlineHeader(
                            eyebrow: alphaGreeting(),
                            title: work.isEmpty ? rossLocalized("no_prepared_work_needs_review") : alphaPreparedWorkHeadline(work.count),
                            detail: nil
                        )

                        AlphaLocalPrivacyBadge()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let setupJob = alphaActiveAssistantSetupJob(from: model.persisted.modelJobs) {
                    AlphaAssistantSetupProgressCard(model: model, job: setupJob)
                }

                if visibleWork.isEmpty {
                    AlphaHonestEmptyCard(title: rossLocalized("nothing_prepared_yet"), detail: rossLocalized("nothing_prepared_yet_detail"))
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
                                Text(alphaViewAllPreparedWorkLabel(work.count))
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(Color.rossInk)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .rossNativeGlassSurface(
                                tint: Color.rossAccent,
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                interactive: true,
                                fallbackFillOpacity: 0.82,
                                fallbackStrokeOpacity: 0.48
                            )
                            .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                AlphaTodayDatesCard(title: rossLocalized("upcoming_dates_and_urgent_tasks"), dates: todayDates + Array(upcomingDates.prefix(3)), tasks: Array(todayTasks.prefix(3)), model: model)
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
                    AlphaInlineHeader(
                        eyebrow: rossLocalized("tab_matters"),
                        title: rossLocalized("matter_workspaces"),
                        detail: alphaActiveMatterCountLabel(matters.count)
                    )
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
                    AlphaInlineHeader(
                        eyebrow: rossLocalized("tab_files"),
                        title: rossLocalized("local_file_room"),
                        detail: alphaFilesAcrossMattersLabel(documents.count)
                    )
                if documents.isEmpty {
                    AlphaHonestEmptyCard(
                        title: rossLocalized("no_files_imported"),
                        detail: rossLocalized("file_room_empty_detail")
                    )
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
                    AlphaInlineHeader(eyebrow: rossLocalized("work"), title: rossLocalized("prepared_work_inbox"), detail: alphaPreparedWorkCountLabel(items.count))
                    Spacer(minLength: 0)
                    Menu {
                        Button(rossLocalized("all")) { statusFilter = nil }
                        ForEach(AlphaPreparedWorkStatus.allCases, id: \.rawValue) { status in
                            Button(status.title) { statusFilter = status }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.rossInk)
                            .frame(width: 34, height: 34)
                            .rossNativeGlassSurface(
                                tint: Color.rossAccent,
                                shape: RoundedRectangle(cornerRadius: 17, style: .continuous),
                                interactive: true,
                                fallbackFillOpacity: 0.80,
                                fallbackStrokeOpacity: 0.46
                            )
                            .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
                    }
                }

                if items.isEmpty {
                    AlphaHonestEmptyCard(title: rossLocalized("no_prepared_work"), detail: rossLocalized("no_prepared_work_detail"))
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
            Text(rossLocalized("works_locally_on_this_device"))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.rossInk.opacity(0.76))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackFillOpacity: 0.80,
            fallbackStrokeOpacity: 0.46
        )
        .shadow(color: Color.rossShadow.opacity(0.06), radius: 6, y: 2)
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

                RossGlassGroup(spacing: 8) {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                        Button(item.primaryAction) {
                            alphaHaptic(.selection)
                            alphaHandlePreparedPrimaryAction(item, model: model)
                        }
                        .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14)

                        Button(rossLocalized("accept")) {
                            model.setPreparedWorkStatus(item.id, status: .accepted)
                        }
                        .rossGlassButtonStyle(tint: Color.rossSuccess, cornerRadius: 14)

                        Button(rossLocalized("edit")) {
                            alphaHandlePreparedEdit(item, model: model)
                        }
                        .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 14)

                        Button(rossLocalized("dismiss")) {
                            model.setPreparedWorkStatus(item.id, status: .dismissed)
                        }
                        .rossGlassButtonStyle(tint: Color.rossInk.opacity(0.42), cornerRadius: 14)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
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
                    Text(rossLocalized("no_dates_or_urgent_tasks_today"))
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
        RossSectionCard(title: rossLocalized("setting_up_ross"), subtitle: alphaAssistantStateLabel(job.state)) {
            VStack(alignment: .leading, spacing: 12) {
                Text(alphaAssistantSetupPreparingLabel(job.tier.title))
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                if let progress = alphaDownloadProgressValue(job) {
                    RossProgressBar(value: progress, tint: Color.rossAccent, height: 7)
                        .frame(height: 7)
                        .accessibilityLabel(alphaAssistantSetupProgressLabel(job))
                        .accessibilityValue(Text("\(Int((progress * 100).rounded()))%"))
                    Text(alphaAssistantSetupProgressLabel(job))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                }

                Button(rossLocalized("open_assistant_setup")) {
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
    return alphaDownloadBytesProgressLabel(downloadedBytes: downloaded, totalBytes: job.totalBytes)
}

func alphaPreparedWorkHeadline(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    let key = count == 1 ? "prepared_work_headline_one" : "prepared_work_headline_many"
    return String(format: rossLocalized(key, languageCode: languageCode), count)
}

func alphaPreparedWorkCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    let key = count == 1 ? "prepared_work_count_one" : "prepared_work_count_many"
    return String(format: rossLocalized(key, languageCode: languageCode), count)
}

func alphaPlainItemCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    let key = count == 1 ? "plain_item_count_one" : "plain_item_count_many"
    return String(format: rossLocalized(key, languageCode: languageCode), count)
}

func alphaViewAllPreparedWorkLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("view_all_prepared_work", languageCode: languageCode), alphaPreparedWorkCountLabel(count, languageCode: languageCode))
}

func alphaActiveMatterCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("active_matter_count", languageCode: languageCode), count)
}

func alphaFilesAcrossMattersLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    let key = count == 1 ? "files_across_matters_count_one" : "files_across_matters_count_many"
    return String(format: rossLocalized(key, languageCode: languageCode), count)
}

func alphaAssistantSetupPreparingLabel(_ tierTitle: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("assistant_setup_preparing_detail", languageCode: languageCode), tierTitle)
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
        RossGlassGroup(spacing: 10) {
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
}

struct AlphaTopRailIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button(action: action) {
                icon
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: 17, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: 0.80,
                        fallbackStrokeOpacity: 0.46
                    )
                    .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.rossInk)
            .frame(width: 34, height: 34)
    }
}
