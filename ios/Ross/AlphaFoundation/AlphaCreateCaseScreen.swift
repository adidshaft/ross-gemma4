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
            VStack(alignment: .leading, spacing: alphaSectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create a matter")
                        .font(.rossSerifTitle())
                        .foregroundStyle(Color.rossInk)

                    Text("Start with the name. Ross can extract the court, parties, and next date after you import a file.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                RossSectionCard(title: "Matter details") {
                    VStack(alignment: .leading, spacing: 18) {
                        AlphaMatterEditorField(
                            title: "Matter name",
                            placeholder: "Enter matter name",
                            text: $model.caseDraftTitle,
                            validationMessage: didAttemptCreate && !canCreate ? "Required" : nil,
                            autoFocus: true
                        )
                    }
                }

                Button("Create matter") {
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
        .navigationTitle("Create Matter")
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
                .rossGlassSurface(
                    tint: validationMessage == nil
                        ? (isFocused ? Color.rossAccent : Color.rossHighlight)
                        : Color.orange,
                    cornerRadius: 18,
                    interactive: true,
                    shadowOpacity: isFocused ? 0.10 : 0.06,
                    shadowRadius: isFocused ? 10 : 6,
                    shadowY: isFocused ? 4 : 2,
                    fillOpacity: 0.84,
                    strokeOpacity: validationMessage == nil ? 0.52 : 0.68
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            validationMessage == nil
                                ? (isFocused ? Color.rossAccent.opacity(0.28) : Color.rossGlassStroke.opacity(0.72))
                                : Color.orange.opacity(0.7),
                            lineWidth: 1
                        )
                }

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

                        Text("Add next hearing date")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.rossInk)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .rossGlassSurface(
                        tint: Color.rossAccent,
                        cornerRadius: 18,
                        interactive: true,
                        shadowOpacity: 0.07,
                        shadowRadius: 7,
                        shadowY: 3,
                        fillOpacity: 0.84,
                        strokeOpacity: 0.52
                    )
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
                    .rossGlassSurface(
                        tint: Color.rossAccent,
                        cornerRadius: 18,
                        interactive: true,
                        shadowOpacity: 0.07,
                        shadowRadius: 7,
                        shadowY: 3,
                        fillOpacity: 0.84,
                        strokeOpacity: 0.52
                    )

                    Button("Clear date") {
                        date = nil
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.72))
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
            .rossGlassSurface(
                tint: Color.rossHighlight,
                cornerRadius: 18,
                interactive: true,
                shadowOpacity: 0.06,
                shadowRadius: 7,
                shadowY: 3,
                fillOpacity: 0.84,
                strokeOpacity: 0.52
            )
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

struct AlphaCaseSummaryCard: View {
    @Bindable var model: AlphaRossModel
    let caseMatter: AlphaCaseMatter

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AlphaMatterFolderGlyph(tint: caseMatter.folderTint)

            VStack(alignment: .leading, spacing: 5) {
                Text(caseMatter.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.rossInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted) ?? caseMatter.forum)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(caseMatter.nextHearing == nil ? Color.rossInk.opacity(0.72) : Color.rossHighlight)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Text("\(model.openTaskCount(for: caseMatter.id)) open")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.rossAccent.opacity(0.1), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .rossGlassSurface(
            tint: caseMatter.nextHearing == nil ? Color.rossAccent : Color.rossHighlight,
            cornerRadius: 16,
            interactive: true,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.48
        )
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

                Text("\(caseMatter.forum) · \(caseMatter.documents.count) files")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? "\(model.openTaskCount(for: caseMatter.id)) open"
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
        .rossGlassSurface(
            tint: Color.rossAccent,
            cornerRadius: 14,
            interactive: true,
            shadowOpacity: 0.07,
            shadowRadius: 7,
            shadowY: 3,
            fillOpacity: 0.80,
            strokeOpacity: 0.44
        )
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
                badgeText: caseMatter.documents.isEmpty ? "New" : "\(caseMatter.documents.count)"
            )

            Text(caseMatter.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.rossInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                caseMatter.nextHearing?.formatted(date: .abbreviated, time: .omitted)
                    ?? "\(model.openTaskCount(for: caseMatter.id)) open task(s)"
            )
            .font(.caption)
            .foregroundStyle(tint.opacity(0.9))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
        .padding(11)
        .rossGlassSurface(
            tint: tint,
            cornerRadius: 18,
            interactive: true,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.42
        )
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
        .rossGlassSurface(
            tint: Color.rossHighlight,
            cornerRadius: 16,
            interactive: true,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.48
        )
    }
}

@MainActor
func alphaPrivateAIStatus(_ model: AlphaRossModel) -> String {
    alphaAssistantStatusSnapshot(model).title
}

@MainActor
func alphaAssistantStatusSnapshot(_ model: AlphaRossModel) -> AlphaAssistantStatusSnapshot {
    if model.privateAISnapshot.activeRuntimeHealth?.available == true {
        return AlphaAssistantStatusSnapshot(
            title: "Ross assistant is ready",
            detail: "Ross can help read files, draft notes, and answer from local matter files on this device.",
            tint: Color.rossSuccess
        )
    }

    if let job = alphaActiveSetupJob(model) {
        switch job.state {
        case .downloading, .queued, .verifying:
            return AlphaAssistantStatusSnapshot(
                title: "Ross assistant is setting up",
                detail: "You can keep working while Ross finishes setup on this device.",
                tint: Color.rossAccent
            )
        case .pausedWaitingForWifi:
            return AlphaAssistantStatusSnapshot(
                title: "Waiting for Wi-Fi",
                detail: "Ross will continue setup when Wi-Fi is available.",
                tint: Color.rossHighlight
            )
        case .pausedUser:
            return AlphaAssistantStatusSnapshot(
                title: "Ross assistant needs attention",
                detail: "Setup is paused. You can continue working and resume whenever you are ready.",
                tint: .orange
            )
        case .pausedNoStorage:
            return AlphaAssistantStatusSnapshot(
                title: "Ross assistant needs attention",
                detail: alphaAssistantRecoveryDetail(for: job, fallback: "Free up space and try again."),
                tint: .orange
            )
        case .pausedError, .failed, .cancelled:
            return AlphaAssistantStatusSnapshot(
                title: "Ross assistant needs attention",
                detail: alphaAssistantRecoveryDetail(for: job, fallback: "Setup could not finish. Open setup to retry."),
                tint: .orange
            )
        default:
            return AlphaAssistantStatusSnapshot(
                title: "Ross assistant is setting up",
                detail: "Ross is still preparing on this device.",
                tint: Color.rossAccent
            )
        }
    }

    if model.activePack != nil {
        return AlphaAssistantStatusSnapshot(
            title: "Ross assistant needs attention",
            detail: "Ross needs to check setup before answering legal questions.",
            tint: .orange
        )
    }

    return AlphaAssistantStatusSnapshot(
        title: "Ross assistant is not set up",
        detail: "Ross can still organize matters, tasks, dates, and files. Legal answers need assistant setup.",
        tint: Color.rossAccent
    )
}

private func alphaAssistantRecoveryDetail(for job: AlphaModelDownloadJob, fallback: String) -> String {
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
        "artifact"
    ]
    let lowercased = reason.lowercased()
    guard !technicalMarkers.contains(where: lowercased.contains) else {
        return fallback
    }
    return reason
}
