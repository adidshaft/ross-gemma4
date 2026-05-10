import SwiftUI

public extension Font {
    static func rossSerifTitle() -> Font {
        .system(size: 28, weight: .bold, design: .serif)
    }
    
    static func rossSerifHeadline() -> Font {
        .system(size: 18, weight: .bold, design: .serif)
    }

    static func rossInlineTitle() -> Font {
        .system(size: 20, weight: .semibold, design: .default)
    }
}

public enum RossSurface {
    public static let cornerRadius: CGFloat = 16
    public static let compactCornerRadius: CGFloat = 12
    public static let largeCornerRadius: CGFloat = 20
}

public enum RossSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum RossCorner {
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
}

public struct RossCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        content
            .padding(18)
            .background {
                if colorScheme == .dark {
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial)

                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.045),
                                        Color.rossGlassSubtleFill.opacity(0.94),
                                        Color.rossGlassFill.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.045),
                                        Color.clear,
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    }
                } else {
                    shape.fill(Color.rossCardBackground)
                }
            }
            .overlay {
                shape.strokeBorder(
                    colorScheme == .dark
                        ? LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                Color.white.opacity(0.045),
                                Color.black.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.rossBorder.opacity(0.9), Color.rossBorder.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    lineWidth: colorScheme == .dark ? 1 : 0.75
                )
            }
            .overlay(alignment: .top) {
                if colorScheme == .dark {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
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
                color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.rossShadow.opacity(0.14),
                radius: colorScheme == .dark ? 12 : 10,
                x: 0,
                y: colorScheme == .dark ? 6 : 5
            )
    }
}

public struct RossPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.rossPillGradient.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .shadow(
                color: Color.rossAccent.opacity(configuration.isPressed ? 0.18 : 0.3),
                radius: configuration.isPressed ? 6 : 10,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

public struct RossGlassButtonStyle: ButtonStyle {
    public var tint: Color
    public var cornerRadius: CGFloat
    public var expandsHorizontally: Bool

    public init(
        tint: Color? = nil,
        cornerRadius: CGFloat = 18,
        expandsHorizontally: Bool = true
    ) {
        self.tint = tint ?? Color.rossAccent
        self.cornerRadius = cornerRadius
        self.expandsHorizontally = expandsHorizontally
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rossInk)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.rossGlassFill.opacity(isPressed ? 0.70 : 0.90),
                                    tint.opacity(isPressed ? 0.035 : 0.075),
                                    Color.rossGlassSubtleFill.opacity(isPressed ? 0.66 : 0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.rossGlassStroke.opacity(isPressed ? 0.32 : 0.54),
                                tint.opacity(isPressed ? 0.10 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.rossShadow.opacity(isPressed ? 0.10 : 0.16),
                radius: isPressed ? 6 : 12,
                y: isPressed ? 3 : 6
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.18), value: isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
    }
}

public extension View {
    func rossDisplay() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .serif))
    }

    func rossTitle() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .serif))
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
        cornerRadius: CGFloat = 18,
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

// MARK: - Secondary Button Style

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
                    .stroke(Color.rossAccent.opacity(configuration.isPressed ? 0.24 : 0.14), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style

public struct RossDestructiveButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: RossCorner.md, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: RossCorner.md, style: .continuous)
                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .heavy), trigger: configuration.isPressed)
    }
}

// MARK: - Icon Action Button Style

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
                tint.opacity(configuration.isPressed ? 0.22 : 0.12),
                in: Circle()
            )
            .overlay {
                Circle().stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

// MARK: - Branded Progress Bar

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
                            colors: [tint.opacity(0.7), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(proxy.size.width * CGFloat(min(max(value, 0), 1)), height),
                        height: height
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
        .overlay(alignment: .trailing) {
            if showsPercentage {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
                    .padding(.trailing, 4)
            }
        }
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// MARK: - Branded Spinner

public struct RossSpinner: View {
    public var tint: Color = .rossAccent
    public var size: CGFloat = 20

    @State private var rotation: Double = 0

    public var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.8)
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Shimmer Block (Inference Skeleton)

public struct RossShimmerBlock: View {
    @State private var phase: CGFloat = -1

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            shimmerLine(widthFraction: 0.92)
            shimmerLine(widthFraction: 0.72)
            shimmerLine(widthFraction: 0.54)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func shimmerLine(widthFraction: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.rossInk.opacity(0.06))
                .frame(width: proxy.size.width * widthFraction, height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.rossInk.opacity(0.08), .clear],
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
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                index < currentPhase ? Color.rossSuccess :
                                index == currentPhase ? Color.rossAccent :
                                Color.rossInk.opacity(0.15)
                            )
                            .frame(width: 8, height: 8)

                        if index == currentPhase {
                            Circle()
                                .stroke(Color.rossAccent.opacity(0.3), lineWidth: 2)
                                .frame(width: 14, height: 14)
                                .scaleEffect(pulseScale)
                        }

                        if index < currentPhase {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 16, height: 16)

                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            index <= currentPhase ?
                                Color.rossInk.opacity(0.82) :
                                Color.rossInk.opacity(0.38)
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
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
        icon: String,
        title: String,
        detail: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.rossAccent.opacity(0.5))
                .padding(.bottom, 4)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.rossInk)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rossInk.opacity(0.58))
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
        .padding(.vertical, 32)
    }
}

// MARK: - Success Banner

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

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rossInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Color.rossSuccess.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.rossShadow.opacity(0.12), radius: 12, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}
