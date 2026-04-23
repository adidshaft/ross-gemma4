import SwiftUI

public extension Font {
    static func rossSerifTitle() -> Font {
        .system(size: 22, weight: .semibold, design: .serif)
    }
    
    static func rossSerifHeadline() -> Font {
        .system(size: 17, weight: .semibold, design: .serif)
    }

    static func rossInlineTitle() -> Font {
        .system(size: 19, weight: .semibold, design: .rounded)
    }
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
    }
}

public extension View {
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
}
