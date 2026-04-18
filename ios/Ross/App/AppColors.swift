import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    // Modern Legal Premiere Palette
    static let rossInk = Color(red: 0.05, green: 0.07, blue: 0.10)        // Deep Onyx
    static let rossAccent = Color(red: 0.18, green: 0.22, blue: 0.40)      // Deep Indigo
    static let rossHighlight = Color(red: 0.85, green: 0.65, blue: 0.25)   // Refined Gold/Camel
    static let rossSuccess = Color(red: 0.15, green: 0.35, blue: 0.25)
    
    // Backgrounds for Hero
    static let rossHeroTop = Color(red: 0.98, green: 0.98, blue: 0.99)
    static let rossHeroBottom = Color(red: 0.91, green: 0.92, blue: 0.95)
    
    // Gradients
    static var rossPillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.25, blue: 0.45), // Lighter Indigo
                Color(red: 0.15, green: 0.18, blue: 0.35)  // Darker Indigo
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static let rossBorder = Color.primary.opacity(0.08)

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
        Color(.sRGB, red: 0.97, green: 0.97, blue: 0.98, opacity: 1)
        #endif
    }

    static var rossSecondaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.sRGB, red: 0.94, green: 0.95, blue: 0.96, opacity: 1)
        #endif
    }

    static var rossSecondaryGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97, opacity: 1)
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
