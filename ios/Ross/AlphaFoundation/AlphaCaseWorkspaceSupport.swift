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

struct AlphaActiveMatterChatCard: View {
    let session: AlphaChatSession?
    let sessionTitle: String?
    let sessionSubtitle: String?
    let onOpenChat: () -> Void
    let onStartNewChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(rossLocalized("matter_chat"))
                    .font(.subheadline.weight(.semibold))
                Text(
                    session == nil
                        ? rossLocalized("matter_chat_empty_detail")
                        : rossLocalized("matter_chat_continue_detail")
                )
                .font(.caption)
                .foregroundStyle(Color.rossInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            }

            if let session, let sessionTitle {
                HStack(alignment: .top, spacing: 12) {
                    RossGlassIconView(.userMsg, variant: .accent, size: 20, fallbackSystemImage: "bubble.left.and.text.bubble.right.fill")
                        .frame(width: 28, height: 28)
                        .background(Color.rossAccent.opacity(0.1), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sessionTitle)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rossInk)

                        Text("\(alphaUpdateCountLabel(session.turns.count)) · \(sessionSubtitle ?? rossLocalized("recent_activity"))")
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .rossGlassSurface(cornerRadius: 14, shadowOpacity: 0.06, shadowRadius: 6, shadowY: 2, fillOpacity: 0.82, strokeOpacity: 0.52)
            } else {
                Text(rossLocalized("no_matter_chat_detail"))
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            AlphaMatterChatActionButton(
                title: session == nil ? rossLocalized("open_chat") : rossLocalized("continue_chat"),
                action: onOpenChat
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .rossGlassSurface(cornerRadius: 18, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.84, strokeOpacity: 0.56)
    }
}

private struct AlphaMatterChatActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(title, action: action)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.glass)
                .tint(Color.rossAccent)
        } else {
            Button(title, action: action)
                .font(.footnote.weight(.semibold))
                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14, expandsHorizontally: false)
        }
    }
}

struct AlphaWorkspaceSectionLabel: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rossInk.opacity(0.7))

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AlphaCompactRowActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var tint: Color = Color.rossInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .rossNativeGlassSurface(
                    tint: tint,
                    shape: Circle(),
                    interactive: true,
                    fallbackFillOpacity: 0.84,
                    fallbackStrokeOpacity: 0.48
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AlphaMatterCommandHintCard: View {
    let detail: String
    var actionSystemImage: String?
    var actionLabel: String?
    var actionDisabled = false
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rossLocalized("use_ask_ross_below"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
            }

            Spacer(minLength: 8)

            if let actionSystemImage, let actionLabel, let action {
                AlphaCompactRowActionButton(
                    systemImage: actionSystemImage,
                    accessibilityLabel: actionLabel,
                    tint: actionDisabled ? Color.rossInk.opacity(0.35) : Color.rossInk,
                    action: action
                )
                .disabled(actionDisabled)
                .opacity(actionDisabled ? 0.45 : 1)
            }
        }
        .padding(14)
        .rossGlassSurface(
            tint: Color.rossAccent,
            cornerRadius: 18,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.84,
            strokeOpacity: 0.48
        )
    }
}

struct AlphaDraftPreviewRow: View {
    let export: AlphaExportedReport

    private var createdLabel: String {
        export.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            RossGlassIconView(.file, variant: .accent, size: 18, fallbackSystemImage: "doc.text.fill")

            VStack(alignment: .leading, spacing: 4) {
                Text(export.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rossInk)
                    .lineLimit(2)

                Text("\(export.kind) · \(createdLabel)")
                    .font(.caption)
                    .foregroundStyle(Color.rossInk.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.rossInk.opacity(0.32))
        }
        .padding(12)
        .modifier(AlphaDraftPreviewRowSurface())
    }
}

private struct AlphaDraftPreviewRowSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(Color.rossHighlight.opacity(0.12))
                        .interactive(),
                    in: .rect(cornerRadius: 16)
                )
        } else {
            content
                .rossGlassSurface(
                    tint: Color.rossHighlight,
                    cornerRadius: 16,
                    interactive: true,
                    shadowOpacity: 0.08,
                    shadowRadius: 8,
                    shadowY: 3,
                    fillOpacity: 0.82,
                    strokeOpacity: 0.46
                )
        }
    }
}

struct AlphaCompactDraftActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                label
            }
            .buttonStyle(.glass)
            .tint(Color.rossAccent)
        } else {
            Button(action: action) {
                label
                    .rossGlassSurface(
                        tint: Color.rossAccent,
                        cornerRadius: 14,
                        interactive: true,
                        shadowOpacity: 0.06,
                        shadowRadius: 6,
                        shadowY: 2,
                        fillOpacity: 0.82,
                        strokeOpacity: 0.52
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .foregroundStyle(Color.rossInk)
        .padding(.horizontal, 12)
    }
}

struct AlphaMatterDraftActionStrip: View {
    let onGenerateChronology: () -> Void
    let onGenerateCaseNote: () -> Void
    let onGenerateOrderSummary: () -> Void

    var body: some View {
        RossGlassGroup(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_chronology"), systemImage: "list.bullet.rectangle") {
                        onGenerateChronology()
                    }
                    AlphaCompactDraftActionButton(title: rossLocalized("draft_action_case_note"), systemImage: "square.and.pencil") {
                        onGenerateCaseNote()
                    }
                }

                AlphaCompactDraftActionButton(title: rossLocalized("draft_action_order_summary"), systemImage: "doc.plaintext") {
                    onGenerateOrderSummary()
                }
            }
        }
    }
}

struct AlphaTaskRow: View {
    let task: AlphaTaskItem
    let onToggle: () -> Void
    var onSnooze: (() -> Void)? = nil

    private var visibleNotes: String? {
        guard let notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty else {
            return nil
        }
        guard notes.hasPrefix(alphaRossSuggestedTaskNotePrefix) == false else {
            return nil
        }
        return notes
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AlphaTaskToggleButton(
                isDone: task.status == .done,
                action: onToggle
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                if let notes = visibleNotes {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                }
                if let dueDate = task.dueDate {
                    Text(alphaTaskDueLabel(dueDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.rossInk.opacity(0.6))
                }
            }

            Spacer(minLength: 8)

            if task.status == .open, let onSnooze {
                AlphaCompactRowActionButton(
                    systemImage: "clock.arrow.circlepath",
                    accessibilityLabel: "Snooze task by one day",
                    action: onSnooze
                )
            }
        }
        .padding(14)
        .rossGlassSurface(
            tint: task.status == .done ? Color.rossSuccess : Color.rossAccent,
            cornerRadius: 18,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.46
        )
    }
}

private struct AlphaTaskToggleButton: View {
    let isDone: Bool
    let action: () -> Void

    private var tint: Color {
        isDone ? Color.rossSuccess : Color.rossAccent
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                icon
            }
            .buttonStyle(.glass)
            .tint(tint)
            .accessibilityLabel(isDone ? rossLocalized("completed") : "Mark done")
        } else {
            Button(action: action) {
                icon
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? rossLocalized("completed") : "Mark done")
        }
    }

    private var icon: some View {
        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
    }
}

func alphaTaskDueLabel(_ dueDate: Date) -> String {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: .now)
    if dueDate < startOfDay {
        return "Overdue since \(dueDate.formatted(date: .abbreviated, time: .omitted))"
    }
    if calendar.isDateInToday(dueDate) {
        return "Due today"
    }
    return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
}

struct AlphaReviewRow: View {
    let item: AlphaReviewQueueItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.orange.opacity(0.78))
                    .frame(width: 2)
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.65))
                        .lineLimit(2)
                    Text(item.caseTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.35))
            }
            .padding(12)
            .modifier(AlphaReviewQueueRowSurface())
        }
        .buttonStyle(.plain)
    }
}

private struct AlphaReviewQueueRowSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(Color.orange.opacity(0.12))
                        .interactive(),
                    in: .rect(cornerRadius: 16)
                )
        } else {
            content
                .rossGlassSurface(
                    tint: Color.orange,
                    cornerRadius: 16,
                    interactive: true,
                    shadowOpacity: 0.07,
                    shadowRadius: 7,
                    shadowY: 3,
                    fillOpacity: 0.78,
                    strokeOpacity: 0.48
                )
        }
    }
}

struct AlphaReviewNudgeCard: View {
    let item: AlphaReviewQueueItem
    let onAccept: () -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .frame(width: 24, height: 24)
                    .background(Color.orange.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(alphaRossFoundLabel(item.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .lineLimit(2)

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(Color.rossInk.opacity(0.68))
                        .lineLimit(2)

                    Text(item.caseTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.rossAccent)
                        .lineLimit(1)
                }
            }

            RossGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: onAccept) {
                        Label(rossLocalized("correct"), systemImage: "checkmark")
                    }
                    .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossSuccess))

                    Button(action: onEdit) {
                        Label(rossLocalized("edit"), systemImage: "pencil")
                    }
                    .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossAccent))

                    Button(action: onDismiss) {
                        Label(rossLocalized("dismiss"), systemImage: "xmark")
                    }
                    .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossInk.opacity(0.68)))
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(12)
        .rossGlassSurface(tint: Color.orange, cornerRadius: 16, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.5)
    }
}

func alphaRossFoundLabel(_ title: String, languageCode: String = rossSelectedLanguageCode()) -> String {
    String(format: rossLocalized("ross_found_title", languageCode: languageCode), title)
}

struct AlphaCompactNudgeButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule()

        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .rossNativeGlassSurface(
                tint: tint,
                shape: shape,
                interactive: true,
                fallbackFillOpacity: configuration.isPressed ? 0.58 : 0.70,
                fallbackStrokeOpacity: configuration.isPressed ? 0.32 : 0.44
            )
            .shadow(
                color: tint.opacity(configuration.isPressed ? 0.08 : 0.12),
                radius: configuration.isPressed ? 2 : 6,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

struct AlphaMatterDateRow: View {
    let matterDate: AlphaMatterDate
    let onMarkDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(matterDate.title)
                    .font(.subheadline.weight(.semibold))
                Text(matterDate.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rossInk.opacity(0.68))
                if let notes = matterDate.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.62))
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(matterDate.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.rossAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.rossAccent.opacity(0.12))
                    .clipShape(Capsule())

                RossGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        AlphaCompactRowActionButton(
                            systemImage: "checkmark",
                            accessibilityLabel: "Mark date done",
                            tint: Color.rossSuccess,
                            action: onMarkDone
                        )
                        AlphaCompactRowActionButton(
                            systemImage: "xmark",
                            accessibilityLabel: "Cancel date",
                            tint: Color.orange,
                            action: onCancel
                        )
                    }
                }
            }
        }
        .padding(14)
        .rossGlassSurface(
            tint: matterDate.kind == .hearing ? Color.rossAccent : Color.rossHighlight,
            cornerRadius: 18,
            shadowOpacity: 0.08,
            shadowRadius: 8,
            shadowY: 3,
            fillOpacity: 0.82,
            strokeOpacity: 0.46
        )
    }
}
