import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    static let rossInk = Color(red: 0.11, green: 0.18, blue: 0.27)
    static let rossAccent = Color(red: 0.12, green: 0.34, blue: 0.55)
    static let rossHighlight = Color(red: 0.70, green: 0.56, blue: 0.32)
    static let rossSuccess = Color(red: 0.23, green: 0.45, blue: 0.35)
    static let rossHeroTop = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let rossHeroBottom = Color(red: 0.88, green: 0.93, blue: 0.97)
    static let rossBorder = Color.black.opacity(0.06)

    static var rossCardBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .textBackgroundColor)
        #else
        .white
        #endif
    }

    static var rossGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
        #endif
    }

    static var rossSecondaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.sRGB, red: 0.92, green: 0.93, blue: 0.95, opacity: 1)
        #endif
    }

    static var rossSecondaryGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(.sRGB, red: 0.94, green: 0.94, blue: 0.96, opacity: 1)
        #endif
    }
}

extension View {
    @ViewBuilder
    func rossInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
