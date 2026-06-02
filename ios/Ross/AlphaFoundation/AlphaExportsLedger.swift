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

struct AlphaAskCaseScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID

    var body: some View {
        AlphaAskConversationScreen(model: model, fixedScopeCaseID: caseId)
    }
}

struct AlphaExportsScreen: View {
    @Bindable var model: AlphaRossModel
    let caseId: UUID?

    private var visibleReports: [AlphaExportedReport] {
        model.persisted.exports.filter { report in
            caseId == nil || report.caseId == caseId
        }
    }

    var body: some View {
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    AlphaInlineHeader(
                        eyebrow: nil,
                        title: rossLocalized("notes_drafts_title"),
                        detail: rossLocalized("notes_drafts_detail")
                    )

                RossSectionCard(title: rossLocalized("notes_drafts_generate")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(rossLocalized("notes_drafts_generate_detail"))
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.72))

                        RossGlassGroup(spacing: 10) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_chronology"), systemImage: "list.bullet.rectangle") {
                                        Task { await model.generateExport(kind: "chronology_report", caseId: caseId) }
                                    }
                                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_case_note"), systemImage: "square.and.pencil") {
                                        Task { await model.generateExport(kind: "case_note", caseId: caseId) }
                                    }
                                }

                                HStack(spacing: 10) {
                                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_order_summary"), systemImage: "doc.plaintext") {
                                        Task { await model.generateExport(kind: "order_summary", caseId: caseId) }
                                    }
                                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_transcript"), systemImage: "bubble.left.and.text.bubble.right") {
                                        Task { await model.generateExport(kind: "chat_transcript", caseId: caseId) }
                                    }
                                }
                            }
                        }
                    }
                }

                RossSectionCard(title: rossLocalized("notes_drafts_before_file")) {
                    Text(rossLocalized("notes_drafts_ai_review_warning"))
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if visibleReports.isEmpty {
                    RossSectionCard(title: rossLocalized("notes_drafts_empty_title")) {
                        Text(rossLocalized("notes_drafts_empty_detail"))
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }

                ForEach(visibleReports) { report in
                    RossSectionCard(title: report.title, subtitle: report.kind.replacingOccurrences(of: "_", with: " ").capitalized) {
                        VStack(alignment: .leading, spacing: 12) {
                            AlphaExportReviewMetadata(report: report)

                            Text(rossLocalized("notes_drafts_share_detail"))
                                .font(.caption)
                                .foregroundStyle(Color.rossInk.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)

                            ShareLink(item: model.exportURL(for: report)) {
                                Label(rossLocalized("notes_drafts_share_action"), systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 16)
                        }
                    }
                }
                }
                .padding(alphaScreenPadding)
            }
        }
        .navigationTitle(rossLocalized("notes_drafts_title"))
        .rossInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AlphaAskToolbarButton(systemImage: "bubble.right", accessibilityLabel: rossLocalized("open_ask_ross")) {
                    if let caseId {
                        model.openAsk(scopeCaseID: caseId)
                    } else {
                        model.openAsk()
                    }
                }
            }
        }
    }
}

private struct AlphaExportReviewMetadata: View {
    let report: AlphaExportedReport

    private var createdLabel: String {
        report.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var kindLabel: String {
        report.kind.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var fileName: String {
        URL(fileURLWithPath: report.relativePath).lastPathComponent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlphaSettingsValueRow(label: rossLocalized("notes_drafts_metadata_type"), value: kindLabel)
            AlphaSettingsValueRow(label: rossLocalized("notes_drafts_metadata_created"), value: createdLabel)
            AlphaSettingsValueRow(label: rossLocalized("notes_drafts_metadata_saved_file"), value: fileName)
        }
        .padding(12)
        .rossGlassSurface(
            tint: Color.rossHighlight.opacity(0.12),
            cornerRadius: 16,
            shadowOpacity: 0.05,
            shadowRadius: 5,
            shadowY: 2,
            strokeOpacity: 0.46
        )
    }
}
