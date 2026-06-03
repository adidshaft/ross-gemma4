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

struct AlphaAskRossScreen: View {
    @Bindable var model: AlphaRossModel

    var body: some View {
        AlphaAskConversationScreen(model: model, fixedScopeCaseID: nil)
    }
}

struct AlphaCreateCaseScreen: View {
    @Bindable var model: AlphaRossModel
    @State private var didAttemptCreate = false

    private var trimmedTitle: String {
        model.caseDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty
    }

    var body: some View {
        ScrollView {
            RossGlassGroup(spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                    VStack(alignment: .leading, spacing: 8) {
                    Text(rossLocalized("create_matter_title"))
                        .font(.rossSerifTitle())
                        .foregroundStyle(Color.rossInk)

                    Text(rossLocalized("create_matter_detail"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                RossSectionCard(title: rossLocalized("matter_details")) {
                    VStack(alignment: .leading, spacing: 18) {
                        AlphaMatterEditorField(
                            title: rossLocalized("matter_name"),
                            placeholder: rossLocalized("enter_matter_name"),
                            text: $model.caseDraftTitle,
                            validationMessage: didAttemptCreate && !canCreate ? rossLocalized("required") : nil,
                            autoFocus: true
                        )
                    }
                }

                Button(rossLocalized("create_matter")) {
                    if canCreate {
                        alphaHaptic(.light)
                        model.createCase()
                    } else {
                        alphaHaptic(.warning)
                        didAttemptCreate = true
                    }
                }
                .rossPrimaryButtonStyle()

                }
                .padding(alphaScreenPadding)
            }
        }
        .navigationTitle(rossLocalized("create_matter_title"))
        .rossInlineNavigationTitle()
    }
}

struct AlphaMatterEditorField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var validationMessage: String? = nil
    var autoFocus = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.7))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.rossInk)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .rossNativeGlassSurface(
                    tint: validationMessage == nil
                        ? (isFocused ? Color.rossAccent : Color.rossHighlight)
                        : Color.orange,
                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                    interactive: true,
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: validationMessage == nil ? (isFocused ? 0.72 : 0.56) : 0.74
                )
                .shadow(
                    color: Color.rossShadow.opacity(isFocused ? 0.10 : 0.06),
                    radius: isFocused ? 10 : 6,
                    y: isFocused ? 4 : 2
                )

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.orange)
            }
        }
        .task {
            guard autoFocus else { return }
            await Task.yield()
            isFocused = true
        }
    }
}

struct AlphaMatterEditorDateField: View {
    let title: String
    @Binding var date: Date?

    private var dateSelection: Binding<Date> {
        Binding(
            get: { date ?? .now },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.7))

            if date == nil {
                Button {
                    date = .now
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.rossAccent)

                        Text(rossLocalized("add_next_hearing_date"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.rossInk)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.52
                    )
                    .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker(
                        title,
                        selection: dateSelection,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .rossNativeGlassSurface(
                        tint: Color.rossAccent,
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        interactive: true,
                        fallbackFillOpacity: 0.84,
                        fallbackStrokeOpacity: 0.52
                    )
                    .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)

                    RossGlassGroup(spacing: 8) {
                        Button(rossLocalized("clear_date")) {
                            date = nil
                        }
                        .font(.footnote.weight(.semibold))
                        .rossGlassButtonStyle(tint: Color.rossHighlight, cornerRadius: 14, expandsHorizontally: false)
                    }
                }
            }
        }
    }
}

struct AlphaMatterEditorMultilineField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.7))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.rossInk.opacity(0.35))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .rossNativeGlassSurface(
                tint: Color.rossHighlight,
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                interactive: true,
                fallbackFillOpacity: 0.84,
                fallbackStrokeOpacity: 0.52
            )
            .shadow(color: Color.rossShadow.opacity(0.06), radius: 7, y: 3)
        }
    }
}

struct AlphaUpcomingDateRow {
    let title: String
    let detail: String
    let date: Date
}

func alphaGreeting() -> String {
    "Today"
}

func alphaOpenTaskCountLabel(_ count: Int, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized(count == 1 ? "one_open_task" : "open_tasks_count", languageCode: languageCode), count)
}

struct AlphaCaseSummaryCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AlphaMatterFolderGlyph(tint: caseMatter.folderTint, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(caseMatter.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text(caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted) ?? caseMatter.forum)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(caseMatter.nextHearing == nil ? Color.rossInk.opacity(0.72) : Color.rossHighlight)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(alphaOpenTaskCountLabel(model.openTaskCount(for: caseMatter.id)))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossAccent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .rossNativeGlassSurface(
                    tint: Color.rossAccent,
                    shape: Capsule(),
                    fallbackFillOpacity: 0.70,
                    fallbackStrokeOpacity: 0.38
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .rossNativeGlassSurface(
            tint: caseMatter.nextHearing == nil ? Color.rossAccent : Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.48
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
    }
}

struct AlphaCaseSummaryLine: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        HStack(spacing: 12) {
            AlphaMatterFolderGlyph(tint: caseMatter.folderTint, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(caseMatter.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(1)

                Text("\(caseMatter.forum) · \(alphaFileCountLabel(caseMatter.documents.count))")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? alphaOpenTaskCountLabel(model.openTaskCount(for: caseMatter.id))
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(caseMatter.nextHearing == nil ? Color.rossInk.opacity(0.55) : Color.rossAccent)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.rossInk.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .rossNativeGlassSurface(
            tint: Color.rossAccent,
            shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.80,
            fallbackStrokeOpacity: 0.44
        )
        .shadow(color: Color.rossShadow.opacity(0.07), radius: 7, y: 3)
    }
}

struct AlphaCaseFolderCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        let tint = alphaMatterTintColor(caseMatter.folderTint)

        VStack(alignment: .leading, spacing: 10) {
            AlphaFolderArtwork(
                tint: tint,
                icon: .folder,
                variant: .neutral,
                fallbackSystemImage: "folder.fill",
                topTagText: nil,
                badgeText: caseMatter.documents.isEmpty ? rossLocalized("prepared_work_status_new") : "\(caseMatter.documents.count)"
            )

            Text(caseMatter.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? alphaOpenTaskCountLabel(model.openTaskCount(for: caseMatter.id))
            )
            .font(.caption)
            .foregroundStyle(tint.opacity(0.9))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
        .padding(11)
        .rossNativeGlassSurface(
            tint: tint,
            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.42
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
    }
}

struct AlphaInlineHeader: View {
    let eyebrow: String?
    let title: String?
    let detail: String?

    init(eyebrow: String? = nil, title: String? = nil, detail: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow, !eyebrow.isEmpty {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(Color.rossAccent)
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(.rossInlineTitle())
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AlphaSummaryRow: View {
    let title: String
    let detail: String
    var tint: Color = Color.rossInk

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.65))
            }
            Spacer()
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
        }
    }
}

struct AlphaDocumentRow: View {
    let caseTitle: String?
    let document: AlphaCaseDocument
    let showChevron: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(2)

                if let caseTitle {
                    Text(caseTitle)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.55))
                }

                Text(document.lawyerStatusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .rossNativeGlassSurface(
            tint: Color.rossHighlight,
            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
            interactive: true,
            fallbackFillOpacity: 0.82,
            fallbackStrokeOpacity: 0.48
        )
        .shadow(color: Color.rossShadow.opacity(0.08), radius: 8, y: 3)
    }
}

@MainActor
func alphaPrivateAIStatus(_ model: AlphaRossModel) -> String {
    alphaAssistantStatusSnapshot(model).title
}

@MainActor
func alphaAssistantStatusSnapshot(
    _ model: AlphaRossModel,
    languageCode: String = rossSelectedLanguageCode()
) -> AlphaAssistantStatusSnapshot {
    if model.privateAISnapshot.activeRuntimeHealth?.available == true {
        return AlphaAssistantStatusSnapshot(
            title: rossLocalized("assistant_status_ready_title", languageCode: languageCode),
            detail: rossLocalized("assistant_status_ready_detail", languageCode: languageCode),
            tint: Color.rossSuccess
        )
    }

    if let job = alphaActiveSetupJob(model) {
        switch job.state {
        case .downloading, .queued, .verifying:
            return AlphaAssistantStatusSnapshot(
                title: rossLocalized("assistant_status_setting_up_title", languageCode: languageCode),
                detail: rossLocalized("assistant_status_setting_up_detail", languageCode: languageCode),
                tint: Color.rossAccent
            )
        case .pausedWaitingForWifi:
            return AlphaAssistantStatusSnapshot(
                title: alphaAssistantStateLabel(.pausedWaitingForWifi, languageCode: languageCode),
                detail: rossLocalized("assistant_status_waiting_wifi_detail", languageCode: languageCode),
                tint: Color.rossHighlight
            )
        case .pausedUser:
            return AlphaAssistantStatusSnapshot(
                title: rossLocalized("assistant_status_needs_attention_title", languageCode: languageCode),
                detail: rossLocalized("assistant_status_paused_detail", languageCode: languageCode),
                tint: .orange
            )
        case .pausedNoStorage:
            return AlphaAssistantStatusSnapshot(
                title: rossLocalized("assistant_status_needs_attention_title", languageCode: languageCode),
                detail: alphaAssistantRecoveryDetail(
                    for: job,
                    languageCode: languageCode,
                    fallback: rossLocalized("assistant_status_storage_detail", languageCode: languageCode)
                ),
                tint: .orange
            )
        case .pausedError, .failed, .cancelled:
            return AlphaAssistantStatusSnapshot(
                title: rossLocalized("assistant_status_needs_attention_title", languageCode: languageCode),
                detail: alphaAssistantRecoveryDetail(
                    for: job,
                    languageCode: languageCode,
                    fallback: rossLocalized("assistant_status_retry_detail", languageCode: languageCode)
                ),
                tint: .orange
            )
        default:
            return AlphaAssistantStatusSnapshot(
                title: rossLocalized("assistant_status_setting_up_title", languageCode: languageCode),
                detail: rossLocalized("assistant_status_preparing_detail", languageCode: languageCode),
                tint: Color.rossAccent
            )
        }
    }

    if model.activePack != nil {
        return AlphaAssistantStatusSnapshot(
            title: rossLocalized("assistant_status_needs_attention_title", languageCode: languageCode),
            detail: rossLocalized("assistant_status_needs_check_detail", languageCode: languageCode),
            tint: .orange
        )
    }

    return AlphaAssistantStatusSnapshot(
        title: rossLocalized("assistant_status_not_set_up_title", languageCode: languageCode),
        detail: rossLocalized("assistant_status_not_set_up_detail", languageCode: languageCode),
        tint: Color.rossAccent
    )
}

private func alphaAssistantRecoveryDetail(
    for job: AlphaModelDownloadJob,
    languageCode: String,
    fallback: String
) -> String {
    guard let reason = job.failureReason?.trimmingCharacters(in: .whitespacesAndNewlines),
          !reason.isEmpty else {
        return fallback
    }

    let technicalMarkers = [
        "nserror",
        "nsurlerror",
        "runtime",
        "checksum",
        "gguf",
        "llama",
        "gemma",
        "artifact",
        "model",
        "provider",
        "byte-range"
    ]
    let lowercased = reason.lowercased()
    guard !technicalMarkers.contains(where: lowercased.contains) else {
        return fallback
    }
    let normalizedCode = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
    if normalizedCode != "en" && !alphaContainsLocalizedScript(reason) {
        return fallback
    }
    return reason
}

private func alphaContainsLocalizedScript(_ value: String) -> Bool {
    value.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x0900...0x097F, 0x0980...0x09FF, 0x0B80...0x0BFF, 0x0C00...0x0C7F:
            return true
        default:
            return false
        }
    }
}
