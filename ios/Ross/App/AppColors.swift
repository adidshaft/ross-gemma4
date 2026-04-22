import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    private static func dynamicColor(
        lightRed: CGFloat, lightGreen: CGFloat, lightBlue: CGFloat,
        darkRed: CGFloat, darkGreen: CGFloat, darkBlue: CGFloat,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
                : UIColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: lightAlpha)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil, dynamicProvider: { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
                : NSColor(red: lightRed, green: lightGreen, blue: lightBlue, alpha: lightAlpha)
        }))
        #else
        return Color(.sRGB, red: lightRed, green: lightGreen, blue: lightBlue, opacity: lightAlpha)
        #endif
    }

    // Modern Legal Premiere Palette
    static var rossInk: Color {
        dynamicColor(lightRed: 0.05, lightGreen: 0.07, lightBlue: 0.10,
                     darkRed: 0.95, darkGreen: 0.95, darkBlue: 0.95)
    }

    static var rossAccent: Color {
        dynamicColor(lightRed: 0.18, lightGreen: 0.22, lightBlue: 0.40,
                     darkRed: 0.52, darkGreen: 0.56, darkBlue: 0.94)
    }

    static var rossHighlight: Color {
        dynamicColor(lightRed: 0.60, lightGreen: 0.54, lightBlue: 0.46,
                     darkRed: 0.86, darkGreen: 0.80, darkBlue: 0.70)
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
        dynamicColor(lightRed: 0.98, lightGreen: 0.97, lightBlue: 0.95,
                     darkRed: 0.14, darkGreen: 0.15, darkBlue: 0.18)
    }

    static var rossHeroBottom: Color {
        dynamicColor(lightRed: 0.93, lightGreen: 0.92, lightBlue: 0.89,
                     darkRed: 0.08, darkGreen: 0.09, darkBlue: 0.12)
    }

    static var rossGlassFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.16, darkGreen: 0.18, darkBlue: 0.23,
            lightAlpha: 0.74,
            darkAlpha: 0.84
        )
    }

    static var rossGlassSubtleFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.19, darkGreen: 0.21, darkBlue: 0.27,
            lightAlpha: 0.56,
            darkAlpha: 0.74
        )
    }

    static var rossGlassStroke: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.84, darkGreen: 0.88, darkBlue: 0.96,
            lightAlpha: 0.64,
            darkAlpha: 0.38
        )
    }

    static var rossBackdropGlow: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.34, darkGreen: 0.40, darkBlue: 0.54,
            lightAlpha: 0.62,
            darkAlpha: 0.26
        )
    }

    static var rossShadow: Color {
        dynamicColor(
            lightRed: 0.04, lightGreen: 0.06, lightBlue: 0.1,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.16,
            darkAlpha: 0.32
        )
    }

    static var rossScrim: Color {
        dynamicColor(
            lightRed: 0, lightGreen: 0, lightBlue: 0,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.16,
            darkAlpha: 0.42
        )
    }
    
    // Gradients
    static var rossPillGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamicColor(
                    lightRed: 0.20, lightGreen: 0.25, lightBlue: 0.45,
                    darkRed: 0.32, darkGreen: 0.38, darkBlue: 0.64
                ),
                dynamicColor(
                    lightRed: 0.15, lightGreen: 0.18, lightBlue: 0.35,
                    darkRed: 0.22, darkGreen: 0.27, darkBlue: 0.50
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var rossBorder: Color {
        dynamicColor(
            lightRed: 0, lightGreen: 0, lightBlue: 0,
            darkRed: 1, darkGreen: 1, darkBlue: 1,
            lightAlpha: 0.07,
            darkAlpha: 0.16
        )
    }

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

    @ViewBuilder
    func rossHideNavigationBarIfSupported() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
