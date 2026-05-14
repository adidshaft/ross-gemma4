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

struct AlphaGlassPlusButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.rossAccent)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossAccent.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create matter")
    }
}

struct AlphaMatterFolderGlyph: View {
    let tint: AlphaMatterTint
    var size: CGFloat = 44

    var body: some View {
        let color = alphaMatterTintColor(tint)

        ZStack(alignment: .bottomTrailing) {
            RossGlassIconView(.folder, size: size * 0.8, fallbackSystemImage: "folder.fill")
                .frame(width: size, height: size, alignment: .center)

            Circle()
                .fill(color)
                .frame(width: max(8, size * 0.22), height: max(8, size * 0.22))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                }
                .offset(x: -2, y: -2)
        }
        .frame(width: size, height: size)
    }
}

func alphaDocumentTint(_ kind: AlphaDocumentKind) -> Color {
    switch kind {
    case .pdf:
        return Color.rossAccent
    case .image:
        return Color.rossHighlight
    case .text:
        return Color.rossSuccess
    case .unknown:
        return Color.rossInk.opacity(0.56)
    }
}

func alphaDocumentFallbackSymbolName(_ kind: AlphaDocumentKind) -> String {
    switch kind {
    case .pdf:
        return "doc.richtext.fill"
    case .image:
        return "photo.fill"
    case .text:
        return "doc.text.fill"
    case .unknown:
        return "doc.fill"
    }
}

func alphaTierGlassIcon(_ tier: AlphaCapabilityTier) -> (RossGlassIconName, RossGlassIconVariant, String) {
    switch tier {
    case .flash:
        return (.badgeSparkle, .accent, "paperplane.fill")
    case .quickStart:
        return (.badgeSparkle, .accent, "sparkles")
    case .caseAssociate:
        return (.bookOpen, .neutral, "books.vertical.fill")
    case .seniorDraftingSupport:
        return (.timelineVertical, .neutral, "square.and.pencil")
    }
}

func alphaDocumentGlassIcon(_ kind: AlphaDocumentKind) -> (RossGlassIconName, RossGlassIconVariant, String) {
    switch kind {
    case .pdf:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .image:
        return (.files, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .text:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    case .unknown:
        return (.file, .neutral, alphaDocumentFallbackSymbolName(kind))
    }
}

func alphaDocumentKindBadgeTitle(_ kind: AlphaDocumentKind) -> String {
    switch kind {
    case .pdf:
        return "PDF"
    case .image:
        return "PHOTO"
    case .text:
        return "TEXT"
    case .unknown:
        return "FILE"
    }
}

func alphaDocumentImportedLabel(_ document: AlphaCaseDocument) -> String {
    document.importedAt.formatted(date: .abbreviated, time: .omitted)
}

struct AlphaFolderArtwork: View {
    let tint: Color
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let fallbackSystemImage: String
    let topTagText: String?
    let badgeText: String?

    var body: some View {
        ZStack {
            RossGlassIconView(icon, variant: variant, size: 64, fallbackSystemImage: fallbackSystemImage)
                .padding(.leading, 2)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let topTagText {
                Text(topTagText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(tint.opacity(0.94))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.7)
                    }
                    .padding(.top, 2)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if let badgeText {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.45), lineWidth: 0.7)
                    }
                    .padding(.leading, 2)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }
}

struct AlphaDocumentLayoutMenu: View {
    @Binding var layoutMode: AlphaDocumentLayoutMode

    var body: some View {
        Menu {
            ForEach(AlphaDocumentLayoutMode.allCases) { option in
                Button(option.title) {
                    layoutMode = option
                }
            }
        } label: {
            Image(systemName: layoutMode.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rossInk)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossBorder, lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose document view")
    }
}

struct AlphaDocumentCollectionView: View {
    let documents: [AlphaCaseDocument]
    let caseTitle: String?
    let layoutMode: AlphaDocumentLayoutMode
    @Binding var expandedDocumentIDs: Set<UUID>
    let onOpen: (UUID) -> Void
    let onMoveDocument: (UUID, Int) -> Void
    var onOpenChat: ((UUID) -> Void)? = nil
    var onStartReviewChat: ((UUID) -> Void)? = nil

    var body: some View {
        switch layoutMode {
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 126), spacing: 14)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    Button {
                        onOpen(document.id)
                    } label: {
                        AlphaDocumentFolderTile(document: document)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open document") {
                            onOpen(document.id)
                        }

                        if let onOpenChat {
                            Button("Continue in chat") {
                                onOpenChat(document.id)
                            }
                        }

                        if let onStartReviewChat {
                            Button("Start review chat") {
                                onStartReviewChat(document.id)
                            }
                        }

                        if index > 0 {
                            Button("Move earlier") {
                                onMoveDocument(document.id, -1)
                            }
                        }

                        if index < documents.count - 1 {
                            Button("Move later") {
                                onMoveDocument(document.id, 1)
                            }
                        }
                    }
                }
            }
        case .list:
            LazyVStack(spacing: 10) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    AlphaExpandableDocumentRow(
                        caseTitle: caseTitle,
                        document: document,
                        isExpanded: expandedDocumentIDs.contains(document.id),
                        canMoveEarlier: index > 0,
                        canMoveLater: index < documents.count - 1,
                        onToggle: {
                            withAnimation(.snappy(duration: 0.24)) {
                                if expandedDocumentIDs.contains(document.id) {
                                    expandedDocumentIDs.remove(document.id)
                                } else {
                                    expandedDocumentIDs.insert(document.id)
                                }
                            }
                        },
                        onOpen: { onOpen(document.id) },
                        onOpenChat: { onOpenChat?(document.id) },
                        onStartReviewChat: { onStartReviewChat?(document.id) },
                        onMoveEarlier: { onMoveDocument(document.id, -1) },
                        onMoveLater: { onMoveDocument(document.id, 1) }
                    )
                }
            }
        }
    }
}

struct AlphaDocumentFolderTile: View {
    let document: AlphaCaseDocument

    var body: some View {
        let tint = alphaDocumentTint(document.kind)
        let glassIcon = alphaDocumentGlassIcon(document.kind)

        VStack(alignment: .leading, spacing: 9) {
            AlphaFolderArtwork(
                tint: tint,
                icon: glassIcon.0,
                variant: glassIcon.1,
                fallbackSystemImage: glassIcon.2,
                topTagText: document.title.localizedCaseInsensitiveContains("demo") ? "SAMPLE" : alphaDocumentKindBadgeTitle(document.kind),
                badgeText: document.pageCount == 1 ? "1 page" : "\(document.pageCount)"
            )

            Text(document.fileName.isEmpty ? document.title : document.fileName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            AlphaDocumentStatusLight(state: document.processingState, label: document.lawyerStatusTitle)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(11)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 0.9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AlphaExpandableDocumentRow: View {
    let caseTitle: String?
    let document: AlphaCaseDocument
    let isExpanded: Bool
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onOpenChat: () -> Void
    let onStartReviewChat: () -> Void
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void

    var body: some View {
        let tint = alphaDocumentTint(document.kind)
        let glassIcon = alphaDocumentGlassIcon(document.kind)

        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    RossGlassIconView(glassIcon.0, variant: glassIcon.1, size: 28, fallbackSystemImage: glassIcon.2)
                        .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)

                        if let caseTitle {
                            Text(caseTitle)
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.56))
                                .lineLimit(1)
                        }

                        Text("\(document.kind.title) • \(alphaPageCountLabel(document.pageCount))")
                            .font(.caption)
                            .foregroundStyle(tint.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.42))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Imported \(alphaDocumentImportedLabel(document))")
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.58))

                    if let snippet = document.displaySourceSnippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.72))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        Button("Open", action: onOpen)
                            .buttonStyle(.borderedProminent)

                        Button("Chat", action: onOpenChat)
                            .buttonStyle(.bordered)

                        Button("New review chat", action: onStartReviewChat)
                            .buttonStyle(.bordered)

                        if canMoveEarlier {
                            Button {
                                onMoveEarlier()
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Move document earlier")
                        }

                        if canMoveLater {
                            Button {
                                onMoveLater()
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Move document later")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.rossCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.snappy(duration: 0.24), value: isExpanded)
    }
}

struct AlphaDocumentStatusLight: View {
    let state: AlphaDocumentProcessingState
    let label: String

    private var tint: Color {
        switch state {
        case .ready:
            Color.green
        case .readingText, .imported:
            Color.yellow
        case .reviewingFindings, .needsConfirmation:
            Color.orange
        case .failed:
            Color.red
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.35), radius: 4, y: 1)

            Text(label)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(Color.rossInk.opacity(0.72))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.13), in: Capsule())
    }
}

struct AlphaMatterContextMenu: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter
    @Binding var renameTarget: AlphaCaseMatter?
    @Binding var renameDraft: String
    @Binding var deleteTarget: AlphaCaseMatter?

    var body: some View {
        Button {
            renameTarget = caseMatter
            renameDraft = caseMatter.title
        } label: {
            Label("Rename matter", systemImage: "pencil")
        }

        Menu("Folder color") {
            ForEach(AlphaMatterTint.allCases) { tint in
                Button {
                    model.setFolderTint(tint, for: caseMatter.id)
                } label: {
                    Label(
                        alphaMatterTintTitle(tint),
                        systemImage: tint == caseMatter.folderTint ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        }

        Button {
            model.archiveCase(caseMatter.id)
        } label: {
            Label("Archive matter", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            deleteTarget = caseMatter
        } label: {
            Label("Delete matter", systemImage: "trash")
        }
    }
}

func alphaTierTint(_ tier: AlphaCapabilityTier) -> Color {
    switch tier {
    case .flash:
        return Color.rossHighlight
    case .quickStart:
        return Color.rossHighlight
    case .caseAssociate:
        return Color.rossAccent
    case .seniorDraftingSupport:
        return Color.rossSuccess
    }
}

struct AlphaTierGlyph: View {
    let tier: AlphaCapabilityTier

    var body: some View {
        let tint = alphaTierTint(tier)
        let glassIcon = alphaTierGlassIcon(tier)

        RossGlassIconView(glassIcon.0, variant: glassIcon.1, size: 22, fallbackSystemImage: glassIcon.2)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct AlphaMatterStarterCard: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        RossSectionCard(title: "Start with your first matter", subtitle: "Name it now. Ross can extract the details from the first file.") {
            VStack(spacing: 12) {
                TextField("Matter name", text: $model.caseDraftTitle)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.rossInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color.rossGlassSubtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.rossGlassStroke.opacity(0.72), lineWidth: 1)
                    }

                Button("Save matter and open") {
                    model.createCase()
                }
                .rossPrimaryButtonStyle()
                .disabled(model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct AlphaAssistantActivityStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let detail: String
    let statusLabel: String
    let tint: Color
    var progressValue: Double?
    var showsIndeterminateProgress: Bool = false

    private var clampedProgress: Double? {
        progressValue.map { min(max($0, 0), 1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                RossGlassIconView(.sparkle3, variant: .accent, size: 30, fallbackSystemImage: "brain.head.profile")
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let clampedProgress {
                ProgressView(value: clampedProgress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .accessibilityLabel(statusLabel)
            } else if showsIndeterminateProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)

                    Text(statusLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.2))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(colorScheme == .dark ? 0.1 : 0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
        }
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: 12, y: 6)
    }
}

struct AlphaDisclosureCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let badge: String?
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        RossSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.rossSerifHeadline())
                                .foregroundStyle(Color.rossInk)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rossInk.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 12)

                        HStack(spacing: 10) {
                            if let badge, !badge.isEmpty {
                                Text(badge)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.rossAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.rossAccent.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.rossInk.opacity(0.45))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    content
                }
            }
        }
    }
}

@MainActor
func alphaSortedCases(for sortMode: AlphaCaseSortMode, model: AlphaRossModel) -> [AlphaCaseMatter] {
    switch sortMode {
    case .recentlyViewed:
        return model.cases
    case .lastAdded:
        return model.cases
    case .earliestActionNeeded:
        return model.cases.sorted { lhs, rhs in
            let lhsDate = model.nextActionDate(for: lhs.id)
            let rhsDate = model.nextActionDate(for: rhs.id)
            switch (lhsDate, rhsDate) {
            case let (.some(lhsDate), .some(rhsDate)):
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}

@MainActor
func alphaNextActionDate(for caseMatter: AlphaCaseMatter, model: AlphaRossModel) -> Date? {
    model.nextActionDate(for: caseMatter.id)
}

@MainActor
func alphaActiveSetupJob(_ model: AlphaRossModel) -> AlphaModelDownloadJob? {
    if model.activeRuntimeHealth?.available == true {
        return model.persisted.modelJobs.first {
            switch $0.state {
            case .queued, .downloading, .pausedWaitingForWifi, .verifying:
                return true
            case .pausedUser, .pausedNoStorage, .pausedError, .failed, .notStarted, .installed, .cancelled:
                return false
            }
        }
    }
    return model.persisted.modelJobs.first {
        switch $0.state {
        case .queued, .downloading, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .verifying, .failed:
            true
        case .notStarted, .installed, .cancelled:
            false
        }
    }
}

func alphaAssistantActivityDetail(for state: AlphaDownloadState) -> String {
    switch state {
    case .queued, .downloading:
        "Ross is preparing the private assistant. You can keep using the app."
    case .verifying:
        "Ross is checking that the on-device assistant is ready before turning it on."
    case .pausedWaitingForWifi:
        "Ross is waiting for Wi-Fi before continuing the assistant setup."
    case .pausedUser:
        "The assistant setup is paused. Open device setup to resume it."
    case .pausedNoStorage:
        "Ross needs more free space before the assistant can finish setting up."
    case .pausedError, .failed:
        "Ross could not start the private assistant. Please retry when the issue is fixed."
    case .notStarted, .installed, .cancelled:
        "No setup is running right now."
    }
}

func alphaAssistantStateLabel(_ state: AlphaDownloadState) -> String {
    switch state {
    case .queued, .downloading:
        "Preparing"
    case .verifying:
        "Checking"
    case .pausedWaitingForWifi:
        "Waiting for Wi-Fi"
    case .pausedUser:
        "Paused"
    case .pausedNoStorage:
        "Needs space"
    case .pausedError, .failed:
        "Needs retry"
    case .installed:
        "Ready"
    case .cancelled:
        "Cancelled"
    case .notStarted:
        "Not started"
    }
}

func alphaAssistantActivityTitle(for job: AlphaModelDownloadJob) -> String {
    switch job.state {
    case .pausedError, .failed:
        "Private assistant needs a retry"
    case .pausedWaitingForWifi, .pausedUser, .pausedNoStorage:
        "\(job.tier.title) setup is paused"
    default:
        "\(job.tier.title) is preparing"
    }
}

func alphaDownloadProgressValue(_ job: AlphaModelDownloadJob) -> Double? {
    guard job.totalBytes > 0 else { return nil }
    switch job.state {
    case .downloading:
        return job.bytesDownloaded > 0 ? job.progress : nil
    case .verifying:
        return job.progress
    case .queued, .notStarted, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .installed, .failed, .cancelled:
        return nil
    }
}

func alphaDownloadShowsIndeterminateProgress(_ job: AlphaModelDownloadJob) -> Bool {
    switch job.state {
    case .queued, .verifying:
        return job.totalBytes == 0
    case .downloading:
        return job.totalBytes == 0 || job.bytesDownloaded == 0
    case .notStarted, .pausedWaitingForWifi, .pausedUser, .pausedNoStorage, .pausedError, .installed, .failed, .cancelled:
        return false
    }
}
