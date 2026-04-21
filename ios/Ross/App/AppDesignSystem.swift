import SwiftUI

public extension Font {
    static func rossSerifTitle() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }
    
    static func rossSerifHeadline() -> Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }

    static func rossInlineTitle() -> Font {
        .system(size: 19, weight: .semibold, design: .rounded)
    }
}

public struct RossCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                Color.rossCardBackground.opacity(0.88)
                    .background(.ultraThinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.rossBorder.opacity(0.9), lineWidth: 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.rossShadow.opacity(0.45), radius: 14, x: 0, y: 8)
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
                                    Color.rossGlassFill.opacity(isPressed ? 0.72 : 0.94),
                                    tint.opacity(isPressed ? 0.05 : 0.1),
                                    Color.rossGlassSubtleFill.opacity(isPressed ? 0.7 : 0.88)
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
                                Color.rossGlassStroke.opacity(isPressed ? 0.42 : 0.72),
                                tint.opacity(isPressed ? 0.14 : 0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.rossShadow.opacity(isPressed ? 0.12 : 0.22),
                radius: isPressed ? 8 : 18,
                y: isPressed ? 4 : 10
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
