import SwiftUI

public extension Font {
    static func rossSerifTitle() -> Font {
        .custom("Baskerville", size: 34, relativeTo: .largeTitle)
    }
    
    static func rossSerifHeadline() -> Font {
        .custom("Baskerville", size: 24, relativeTo: .title2)
    }
}

public struct RossCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(24)
            .background(Color.rossCardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.rossBorder, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

public struct RossPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
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

public extension View {
    func rossCardStyle() -> some View {
        self.modifier(RossCardStyle())
    }
    
    func rossPrimaryButtonStyle() -> some View {
        self.buttonStyle(RossPrimaryButtonStyle())
    }
}
