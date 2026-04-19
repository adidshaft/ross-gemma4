import SwiftUI

struct RossSectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let title {
                        Text(title)
                            .font(.rossSerifHeadline())
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.rossInk.opacity(0.65))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 4)
            }

            content
        }
        .rossCardStyle()
    }
}

struct RossHeroCard<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String?
    let content: Content

    init(
        eyebrow: String,
        title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.rossHighlight)

            Text(title)
                .font(.rossSerifTitle())
                .foregroundStyle(Color.rossInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(.title3)
                    .foregroundStyle(Color.rossInk.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
                .padding(.top, 8)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.rossHeroTop, Color.rossHeroBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.rossAccent.opacity(0.08), radius: 24, y: 12)
    }
}

struct RossInfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .foregroundStyle(Color.rossInk)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
    }
}

struct RossMetricTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(tint.opacity(0.8))

            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.rossInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct RossActionTile: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.rossInk.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.3))
            }
            .padding(16)
            .background(Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.rossBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct RossBulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.rossHighlight)
                .padding(.top, 3)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.rossInk.opacity(0.75))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RossStepTile: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.rossAccent)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .shadow(color: Color.rossAccent.opacity(0.3), radius: 4, y: 2)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.rossInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.65))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
