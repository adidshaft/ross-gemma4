import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum RossGlassIconVariant: String {
    case neutral
    case accent
    case success
    case highlight
}

enum RossGlassIconName: String {
    case badgeSparkle = "badge-sparkle"
    case bookOpen = "book-open"
    case circleInfo = "circle-info"
    case clipboardCheck = "clipboard-check"
    case docFolder = "doc-folder"
    case earth
    case file
    case fileDownload = "file-download"
    case fileUpload = "file-upload"
    case files
    case folder
    case gearKeyhole = "gear-keyhole"
    case lock
    case magnifier
    case refresh
    case sparkle3 = "sparkle-3"
    case storage
    case tasks
    case timelineVertical = "timeline-vertical"
    case triangleWarning = "triangle-warning"
    case userMsg = "user-msg"
}

private func rossGlassAssetName(_ icon: RossGlassIconName, variant: RossGlassIconVariant) -> String {
    "ng_\(variant.rawValue)_\(icon.rawValue.replacingOccurrences(of: "-", with: "_"))"
}

private func rossGlassAssetAvailable(_ assetName: String) -> Bool {
    #if canImport(UIKit)
    return UIImage(named: assetName) != nil
    #elseif canImport(AppKit)
    return NSImage(named: assetName) != nil
    #else
    return false
    #endif
}

struct RossGlassIconView: View {
    let icon: RossGlassIconName
    let variant: RossGlassIconVariant
    let size: CGFloat
    let fallbackSystemImage: String?

    init(
        _ icon: RossGlassIconName,
        variant: RossGlassIconVariant = .neutral,
        size: CGFloat = 20,
        fallbackSystemImage: String? = nil
    ) {
        self.icon = icon
        self.variant = variant
        self.size = size
        self.fallbackSystemImage = fallbackSystemImage
    }

    var body: some View {
        let assetName = rossGlassAssetName(icon, variant: variant)

        Group {
            if rossGlassAssetAvailable(assetName) {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else if let fallbackSystemImage {
                Image(systemName: fallbackSystemImage)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: size, height: size)
    }
}

struct RossLaunchSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        ZStack {
            RossAuthBackdrop()

            if colorScheme == .light {
                Circle()
                    .fill(Color.rossAccent.opacity(0.05))
                    .frame(width: 360, height: 360)
                    .blur(radius: 54)
            }

            VStack(spacing: 18) {
                Image("RossLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 146, height: 146)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.white.opacity(0.42), radius: 12, y: -2)
                    .shadow(color: Color.rossAccent.opacity(0.1), radius: 12, y: 7)
                    .shadow(color: Color.rossShadow.opacity(0.12), radius: 8, y: 4)
                    .scaleEffect(appeared ? 1 : 0.78)
                    .opacity(appeared ? 1 : 0)

                Text("Ross")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.rossInk)
                    .offset(y: -2)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}

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
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let title {
                        Text(title)
                            .font(.rossSerifHeadline())
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.7))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .rossCardStyle()
    }
}

struct RossHeroCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let eyebrow: String
    let title: String
    let detail: String?
    let showsMedia: Bool
    let mediaHeight: CGFloat
    let logoSize: CGFloat
    let content: Content

    init(
        eyebrow: String,
        title: String,
        detail: String? = nil,
        showsMedia: Bool = true,
        mediaHeight: CGFloat = 120,
        logoSize: CGFloat = 70,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.showsMedia = showsMedia
        self.mediaHeight = mediaHeight
        self.logoSize = logoSize
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsMedia {
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.08), Color(white: 0.13)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: mediaHeight)

                    Group {
                        #if canImport(UIKit)
                        if let _ = UIImage(named: "RossLogo") {
                            Image("RossLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.black.opacity(0.38), radius: 14, y: 6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(Color(white: 0.16))
                                    .frame(width: logoSize, height: logoSize)
                                    .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                                Text("R")
                                    .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(white: 0.42), Color(white: 0.26)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        #elseif canImport(AppKit)
                        if let _ = NSImage(named: "RossLogo") {
                            Image("RossLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.black.opacity(0.38), radius: 14, y: 6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(Color(white: 0.16))
                                    .frame(width: logoSize, height: logoSize)
                                    .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                                Text("R")
                                    .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(white: 0.42), Color(white: 0.26)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        #else
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color(white: 0.16))
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                            Text("R")
                                .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(white: 0.42), Color(white: 0.26)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        #endif
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.6))

                Text(title)
                    .font(.rossSerifTitle())
                    .foregroundStyle(Color.rossInk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail {
                    Text(detail)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.rossInk.opacity(0.72))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content
                    .padding(.top, 2)
            }
            .padding(16)
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.rossHeroTop, Color.rossHeroBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if colorScheme == .light {
                    Color.rossAccent.opacity(0.06)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(0.85), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.rossShadow.opacity(0.14), radius: 24, y: 14)
    }
}

struct RossInfoPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    private let cornerRadius: CGFloat = 18

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.rossHighlight)
                .frame(width: 28, height: 28)
                .background(Color.rossHighlight.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 1)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rossInk)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 58, alignment: .topLeading)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.22))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.16),
                                    Color.rossHighlight.opacity(colorScheme == .dark ? 0.05 : 0.03),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.3 : 0.42), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.rossShadow.opacity(colorScheme == .dark ? 0.14 : 0.18), radius: 10, y: 4)
    }
}

struct RossMetricTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(tint.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.rossInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                // Nucleo-style glass icon cell
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tint.opacity(0.2), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.footnote)
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
            .shadow(color: Color.rossShadow.opacity(0.18), radius: 8, y: 2)
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
                .font(.footnote)
                .foregroundStyle(Color.rossInk.opacity(0.75))
                .lineSpacing(3)
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
