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

public struct RossPrimaryButtonStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.rossPillGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.rossAccent.opacity(0.3), radius: 10, y: 4)
    }
}

public extension View {
    func rossCardStyle() -> some View {
        self.modifier(RossCardStyle())
    }
    
    func rossPrimaryButtonStyle() -> some View {
        self.modifier(RossPrimaryButtonStyle())
    }
}
