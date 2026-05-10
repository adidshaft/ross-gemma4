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
                Text("Matter chat")
                    .font(.subheadline.weight(.semibold))
                Text(
                    session == nil
                        ? "Keep questions, file follow-up, and next steps together for this matter."
                        : "Continue in the current matter thread to keep related work in one place."
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

                        Text("\(alphaUpdateCountLabel(session.turns.count)) · \(sessionSubtitle ?? "Recent activity")")
                            .font(.caption2)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.rossGlassFill.opacity(0.84), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.rossGlassStroke.opacity(0.8), lineWidth: 1)
                }
            } else {
                Text("No matter chat yet. Ross will start one when you import a file, review a document, or ask the first question here.")
                    .font(.footnote)
                    .foregroundStyle(Color.rossInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(session == nil ? "Open chat" : "Continue chat", action: onOpenChat)
                .font(.footnote.weight(.semibold))
                .rossGlassButtonStyle(tint: Color.rossAccent, cornerRadius: 14, expandsHorizontally: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.rossGlassSubtleFill.opacity(0.94))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.82), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                .background(Color.rossGlassFill, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.rossGlassStroke.opacity(0.65), lineWidth: 1)
                }
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
                Text("Use Ask Ross below")
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
        .background(Color.rossCardBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
        }
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
        .background(Color.rossCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.8), lineWidth: 1)
        }
    }
}

struct AlphaCompactDraftActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .background(Color.rossGlassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.rossGlassStroke.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AlphaMatterDraftActionStrip: View {
    let onGenerateChronology: () -> Void
    let onGenerateCaseNote: () -> Void
    let onGenerateOrderSummary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AlphaCompactDraftActionButton(title: "Chronology", systemImage: "list.bullet.rectangle") {
                    onGenerateChronology()
                }
                AlphaCompactDraftActionButton(title: "Case note", systemImage: "square.and.pencil") {
                    onGenerateCaseNote()
                }
            }

            AlphaCompactDraftActionButton(title: "Order summary", systemImage: "doc.plaintext") {
                onGenerateOrderSummary()
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
            Button(action: onToggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(task.status == .done ? Color.rossSuccess : Color.rossAccent)
            }
            .buttonStyle(.plain)

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
        .background(Color.rossCardBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
        }
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
            .background(Color.rossSecondaryGroupedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.rossBorder.opacity(0.82), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
                    Text("Ross found: \(item.title)")
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

            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Label("Correct", systemImage: "checkmark")
                }
                .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossSuccess))

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossAccent))

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                }
                .buttonStyle(AlphaCompactNudgeButtonStyle(tint: Color.rossInk.opacity(0.68)))
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(12)
        .background(Color.rossSecondaryGroupedBackground.opacity(0.76), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.82), lineWidth: 1)
        }
    }
}

struct AlphaCompactNudgeButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                tint.opacity(configuration.isPressed ? 0.22 : 0.10),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(tint.opacity(configuration.isPressed ? 0.30 : 0.18), lineWidth: 1)
            }
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
        .padding(14)
        .background(Color.rossCardBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.rossBorder.opacity(0.9), lineWidth: 1)
        }
    }
}
