import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    static var clerkGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
        #endif
    }

    static var clerkSecondaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.sRGB, red: 0.92, green: 0.93, blue: 0.95, opacity: 1)
        #endif
    }

    static var clerkSecondaryGroupedBackground: Color {
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
    func clerkInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
