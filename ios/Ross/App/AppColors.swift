import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    private static func dynamicColor(
        lightRed: CGFloat, lightGreen: CGFloat, lightBlue: CGFloat,
        darkRed: CGFloat, darkGreen: CGFloat, darkBlue: CGFloat
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: 1)
                : UIColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: 1)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil, dynamicProvider: { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: 1)
                : NSColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: 1)
        }))
        #else
        return Color(red: lightRed, green: lightGreen, blue: lightBlue)
        #endif
    }

    // Modern Legal Premiere Palette
    static var rossInk: Color {
        dynamicColor(lightRed: 0.05, lightGreen: 0.07, lightBlue: 0.10,
                     darkRed: 0.95, darkGreen: 0.95, darkBlue: 0.95)
    }

    static var rossAccent: Color {
        dynamicColor(lightRed: 0.18, lightGreen: 0.22, lightBlue: 0.40,
                     darkRed: 0.50, darkGreen: 0.55, darkBlue: 0.85)
    }

    static var rossHighlight: Color {
        dynamicColor(lightRed: 0.85, lightGreen: 0.65, lightBlue: 0.25,
                     darkRed: 0.95, darkGreen: 0.75, darkBlue: 0.35)
    }

    static var rossSuccess: Color {
        dynamicColor(lightRed: 0.15, lightGreen: 0.35, lightBlue: 0.25,
                     darkRed: 0.35, darkGreen: 0.70, darkBlue: 0.55)
    }

    static var rossChromeBackground: Color {
        dynamicColor(lightRed: 0.06, lightGreen: 0.08, lightBlue: 0.12,
                     darkRed: 0.09, darkGreen: 0.11, darkBlue: 0.16)
    }
    
    // Backgrounds for Hero
    static var rossHeroTop: Color {
        dynamicColor(lightRed: 0.98, lightGreen: 0.98, lightBlue: 0.99,
                     darkRed: 0.14, darkGreen: 0.15, darkBlue: 0.18)
    }

    static var rossHeroBottom: Color {
        dynamicColor(lightRed: 0.91, lightGreen: 0.92, lightBlue: 0.95,
                     darkRed: 0.08, darkGreen: 0.09, darkBlue: 0.12)
    }
    
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
