import SwiftUI

// MARK: - Typography

public extension Font {
    /// Large serif display — hero headlines
    static func rossSerifTitle() -> Font {
        .system(size: 28, weight: .bold, design: .serif)
    }
    
    /// Medium serif headline — card titles, section headers
    static func rossSerifHeadline() -> Font {
        .system(size: 17, weight: .semibold, design: .serif)
    }

    /// Navigation & chrome title
    static func rossInlineTitle() -> Font {
        .system(size: 18, weight: .semibold, design: .default)
    }
}

// MARK: - Surface Tokens (iOS 26: generous radius, floating surfaces)

public enum RossSurface {
    /// Default card / container corner radius
    public static let cornerRadius: CGFloat = 20
    public static let compactCornerRadius: CGFloat = 14
    public static let largeCornerRadius: CGFloat = 26
    /// Icon container radius
    public static let iconRadius: CGFloat = 13
}

public enum RossSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum RossCorner {
    public static let sm: CGFloat = 14
    public static let md: CGFloat = 20
    public static let lg: CGFloat = 26
}

// MARK: - Card Style (iOS 26: deeper material, specular top edge, lens lift)

public struct RossCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: RossSurface.cornerRadius, style: .continuous)

        content
            .padding(18)
            .background {
                if colorScheme == .dark {
                    ZStack {
                        shape.fill(.ultraThinMaterial)

                        // Tinted glass body
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.rossGlassSubtleFill.opacity(0.88),
                                    Color.rossGlassFill.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                        // Lens specular sheen
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    Color.clear,
                                    Color.white.opacity(0.015)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ).blendMode(.screen)
                    }
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color.white.opacity(0.72))
                        shape.fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.60), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    }
                }
            }
            .overlay {
                // Primary lens edge — bright specular on top, darker base
                shape.strokeBorder(
                    colorScheme == .dark
                        ? LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.06),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color.rossBorder.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: colorScheme == .dark ? 1 : 0.75
                )
            }
            // Top specular highlight only
            .overlay(alignment: .top) {
                if colorScheme == .dark {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.14), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .padding(.horizontal, 0.5)
                }
            }
            .clipShape(shape)
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.28)
                    : Color.rossShadow.opacity(0.12),
                radius: colorScheme == .dark ? 18 : 14,
                x: 0,
                y: colorScheme == .dark ? 10 : 7
            )
            // Outer ambient glow (iOS 26 "lift")
            .shadow(
                color: colorScheme == .dark
                    ? Color.rossBackdropGlow.opacity(0.08)
                    : Color.rossBackdropGlow.opacity(0.10),
                radius: 32,
                x: 0,
                y: 8
            )
    }
}

// MARK: - Primary Button Style (iOS 26: pill-shaped, gradient fill, specular top)

public struct RossPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                Capsule()
                    .fill(Color.rossPillGradient)
                    .overlay {
                        // Specular top highlight
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.rossAccent.opacity(configuration.isPressed ? 0.12 : 0.28),
                radius: configuration.isPressed ? 6 : 14,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

// MARK: - Glass Button Style (iOS 26: real lens surface, refractive edges)

public struct RossGlassButtonStyle: ButtonStyle {
    public var tint: Color
    public var cornerRadius: CGFloat
    public var expandsHorizontally: Bool

    public init(
        tint: Color? = nil,
        cornerRadius: CGFloat = RossSurface.cornerRadius,
        expandsHorizontally: Bool = true
    ) {
        self.tint = tint ?? Color.rossAccent
        self.cornerRadius = cornerRadius
        self.expandsHorizontally = expandsHorizontally
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rossInk)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.rossGlassFill.opacity(isPressed ? 0.60 : 0.82),
                                tint.opacity(isPressed ? 0.04 : 0.08),
                                Color.rossGlassSubtleFill.opacity(isPressed ? 0.58 : 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // Specular inner sheen
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isPressed ? 0.08 : 0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.rossGlassStroke.opacity(isPressed ? 0.30 : 0.58),
                            tint.opacity(isPressed ? 0.08 : 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.rossShadow.opacity(isPressed ? 0.06 : 0.14),
                radius: isPressed ? 4 : 10,
                y: isPressed ? 2 : 5
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
    }
}

// MARK: - Typography Helpers

public extension View {
    func rossDisplay() -> some View {
        self.font(.system(size: 32, weight: .bold, design: .serif))
    }

    func rossTitle() -> some View {
        self.font(.system(size: 21, weight: .semibold, design: .serif))
    }

    func rossHeadline() -> some View {
        self.font(.system(size: 16, weight: .semibold))
    }

    func rossBody() -> some View {
        self.font(.system(size: 15, weight: .regular))
    }

    func rossCaption() -> some View {
        self.font(.system(size: 13, weight: .medium))
    }

    func rossMicro() -> some View {
        self.font(.system(size: 11, weight: .regular))
    }

    func rossLabel() -> some View {
        self.font(.system(size: 14, weight: .semibold))
    }

    func rossCardStyle() -> some View {
        self.modifier(RossCardStyle())
    }

    func rossPrimaryButtonStyle() -> some View {
        self.buttonStyle(RossPrimaryButtonStyle())
    }

    func rossGlassButtonStyle(
        tint: Color? = nil,
        cornerRadius: CGFloat = RossSurface.cornerRadius,
        expandsHorizontally: Bool = true
    ) -> some View {
        self.buttonStyle(
            RossGlassButtonStyle(
                tint: tint ?? Color.rossAccent,
                cornerRadius: cornerRadius,
                expandsHorizontally: expandsHorizontally
            )
        )
    }

    func rossSecondaryButtonStyle() -> some View {
        self.buttonStyle(RossSecondaryButtonStyle())
    }

    func rossDestructiveButtonStyle() -> some View {
        self.buttonStyle(RossDestructiveButtonStyle())
    }
}

// MARK: - Secondary Button

public struct RossSecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.rossAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.rossAccent.opacity(configuration.isPressed ? 0.14 : 0.08),
                in: RoundedRectangle(cornerRadius: RossCorner.sm, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: RossCorner.sm, style: .continuous)
                    .stroke(Color.rossAccent.opacity(configuration.isPressed ? 0.26 : 0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button

public struct RossDestructiveButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: RossCorner.md, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.18 : 0.09))
            )
            .overlay {
                RoundedRectangle(cornerRadius: RossCorner.md, style: .continuous)
                    .stroke(Color.red.opacity(0.24), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .heavy), trigger: configuration.isPressed)
    }
}

// MARK: - Icon Action Button

public struct RossIconActionButtonStyle: ButtonStyle {
    public var tint: Color
    public var size: CGFloat

    public init(tint: Color? = nil, size: CGFloat = 30) {
        self.tint = tint ?? Color.rossAccent
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                tint.opacity(configuration.isPressed ? 0.24 : 0.13),
                in: Circle()
            )
            .overlay {
                Circle().stroke(tint.opacity(0.22), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.60), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

// MARK: - Progress Bar (iOS 26: pill track, glowing fill)

public struct RossProgressBar: View {
    public let value: Double
    public var tint: Color = .rossAccent
    public var showsPercentage: Bool = false
    public var height: CGFloat = 6

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.12))
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.78), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(proxy.size.width * CGFloat(min(max(value, 0), 1)), height),
                        height: height
                    )
                    .shadow(color: tint.opacity(0.36), radius: 4, y: 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: value)
            }
        }
        .frame(height: height)
        .overlay(alignment: .trailing) {
            if showsPercentage {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.52))
                    .padding(.trailing, 4)
            }
        }
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// MARK: - Spinner (iOS 26: arc, tinted glow)

public struct RossSpinner: View {
    public var tint: Color = .rossAccent
    public var size: CGFloat = 20

    @State private var rotation: Double = 0

    public var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.82)
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size)
            .shadow(color: tint.opacity(0.36), radius: 4)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Shimmer Block

public struct RossShimmerBlock: View {
    @State private var phase: CGFloat = -1

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            shimmerLine(widthFraction: 0.92)
            shimmerLine(widthFraction: 0.72)
            shimmerLine(widthFraction: 0.52)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func shimmerLine(widthFraction: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.rossInk.opacity(0.055))
                .frame(width: proxy.size.width * widthFraction, height: 12)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.rossInk.opacity(0.10), .clear],
                                startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                                endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                            )
                        )
                }
        }
        .frame(height: 12)
    }
}

// MARK: - Phase Step Indicator

public struct RossPhaseStepIndicator: View {
    public let phases: [String]
    public let currentPhase: Int

    @State private var pulseScale: CGFloat = 1

    public init(phases: [String], currentPhase: Int) {
        self.phases = phases
        self.currentPhase = currentPhase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                index < currentPhase ? Color.rossSuccess :
                                index == currentPhase ? Color.rossAccent :
                                Color.rossInk.opacity(0.12)
                            )
                            .frame(width: 9, height: 9)

                        if index == currentPhase {
                            Circle()
                                .stroke(Color.rossAccent.opacity(0.28), lineWidth: 2.5)
                                .frame(width: 16, height: 16)
                                .scaleEffect(pulseScale)
                        }

                        if index < currentPhase {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 18, height: 18)

                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            index <= currentPhase
                                ? Color.rossInk.opacity(0.86)
                                : Color.rossInk.opacity(0.36)
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
        }
    }
}

// MARK: - Empty State

public struct RossEmptyState: View {
    public let icon: String
    public let title: String
    public let detail: String
    public var actionTitle: String? = nil
    public var action: (() -> Void)? = nil

    public init(
        icon: String, title: String, detail: String,
        actionTitle: String? = nil, action: (() -> Void)? = nil
    ) {
        self.icon = icon; self.title = title; self.detail = detail
        self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Color.rossAccent.opacity(0.45))
                .padding(.bottom, 2)

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.rossInk)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(RossPrimaryButtonStyle())
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Success Banner (iOS 26: capsule, glow)

public struct RossSuccessBanner: View {
    public let message: String
    @Binding public var isVisible: Bool

    public init(message: String, isVisible: Binding<Bool>) {
        self.message = message
        self._isVisible = isVisible
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.rossSuccess)
                    .shadow(color: Color.rossSuccess.opacity(0.45), radius: 6)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rossInk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.52),
                                Color.rossSuccess.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.rossSuccess.opacity(0.18), radius: 16, y: 6)
            .shadow(color: Color.rossShadow.opacity(0.10), radius: 10, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .top)))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}
