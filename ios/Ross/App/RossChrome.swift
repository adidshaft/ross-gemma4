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

    var body: some View {
        ZStack {
            RossAuthBackdrop()

            VStack(spacing: 12) {
                Image("RossLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .shadow(color: colorScheme == .dark ? Color.clear : Color.white.opacity(0.42), radius: 12, y: -2)
                    .shadow(color: Color.rossShadow.opacity(0.14), radius: 12, y: 8)

                Text("Ross")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.rossInk)

                Text(rossLocalized("private_legal_work_splash"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.rossInk.opacity(0.62))
            }
        }
    }
}

struct RossSectionCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
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
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let title {
                        Text(title)
                            .font(.rossSerifHeadline())
                            .foregroundStyle(Color.rossInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.rossInk.opacity(0.66))
                            .lineSpacing(3.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
            }

            content
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rossGlassSurface(
            tint: colorScheme == .dark ? Color.rossHighlight : Color.white,
            cornerRadius: RossSurface.cornerRadius,
            shadowOpacity: colorScheme == .dark ? 0.18 : 0.08,
            shadowRadius: 14,
            shadowY: 6,
            fillOpacity: colorScheme == .dark ? 0.74 : 0.9,
            strokeOpacity: colorScheme == .dark ? 0.26 : 0.68
        )
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
        let shape = RoundedRectangle(cornerRadius: RossSurface.largeCornerRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            if showsMedia {
                ZStack(alignment: .center) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.rossHeroTop,
                                    Color.rossAccent.opacity(0.30),
                                    Color.rossHeroBottom
                                ],
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
                                    .fill(Color.rossSecondaryGroupedBackground)
                                    .frame(width: logoSize, height: logoSize)
                                    .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                                Text("R")
                                    .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.rossHighlight, Color.rossInk.opacity(0.72)],
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
                                    .fill(Color.rossSecondaryGroupedBackground)
                                    .frame(width: logoSize, height: logoSize)
                                    .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                                Text("R")
                                    .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.rossHighlight, Color.rossInk.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        #else
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.rossSecondaryGroupedBackground)
                                .frame(width: logoSize, height: logoSize)
                                .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
                            Text("R")
                                .font(.system(size: logoSize * 0.54, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.rossHighlight, Color.rossInk.opacity(0.72)],
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(Color.clear)
                    .rossNativeGlassSurface(
                        tint: Color.rossHeroTop.opacity(0.28),
                        shape: shape,
                        interactive: false,
                        fallbackFillOpacity: 0.28,
                        fallbackStrokeOpacity: 0.30
                    )
                LinearGradient(
                    colors: [
                        Color.rossHeroTop,
                        Color.rossHeroTop.opacity(0.72),
                        Color.rossHeroBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if colorScheme == .light {
                    Color.rossAccent.opacity(0.04)
                }

                // Subtle lens sheen
                LinearGradient(
                    colors: [Color.white.opacity(colorScheme == .dark ? 0.05 : 0.30), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .overlay {
            // Specular top edge
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.20 : 0.75),
                        Color.rossGlassStroke.opacity(colorScheme == .dark ? 0.10 : 0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .clipShape(shape)
        .shadow(color: Color.rossShadow.opacity(0.16), radius: 28, y: 14)
        .shadow(color: Color.rossBackdropGlow.opacity(0.14), radius: 40, y: 10)
    }
}

struct RossInfoPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    private let cornerRadius: CGFloat = RossSurface.cornerRadius

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.rossHighlight)
                .frame(width: 30, height: 30)
                .rossGlassSurface(
                    tint: Color.rossHighlight.opacity(colorScheme == .dark ? 0.24 : 0.16),
                    cornerRadius: RossSurface.iconRadius,
                    shadowOpacity: 0.04,
                    shadowRadius: 4,
                    shadowY: 1,
                    fillOpacity: 0.66,
                    strokeOpacity: 0.34
                )
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
        .frame(minHeight: 60, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .rossGlassSurface(
            tint: Color.rossHighlight.opacity(0.10),
            cornerRadius: cornerRadius,
            shadowOpacity: colorScheme == .dark ? 0.18 : 0.12,
            shadowRadius: 12,
            shadowY: 5,
            fillOpacity: 0.72,
            strokeOpacity: 0.50
        )
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
        .rossGlassSurface(
            tint: tint.opacity(0.12),
            cornerRadius: 14,
            shadowOpacity: 0.04,
            shadowRadius: 4,
            shadowY: 1,
            fillOpacity: 0.62,
            strokeOpacity: 0.36
        )
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
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 50, height: 50)
                    .rossGlassSurface(
                        tint: tint.opacity(0.16),
                        cornerRadius: RossSurface.iconRadius,
                        shadowOpacity: 0.05,
                        shadowRadius: 5,
                        shadowY: 1,
                        fillOpacity: 0.70,
                        strokeOpacity: 0.38
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rossInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.rossInk.opacity(0.58))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.rossInk.opacity(0.26))
            }
            .padding(18)
            .rossGlassSurface(
                tint: tint.opacity(0.14),
                cornerRadius: RossSurface.cornerRadius,
                interactive: true,
                shadowOpacity: 0.10,
                shadowRadius: 10,
                shadowY: 4,
                fillOpacity: 0.78,
                strokeOpacity: 0.52
            )
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
