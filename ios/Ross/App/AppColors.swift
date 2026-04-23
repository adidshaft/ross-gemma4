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
                     darkRed: 0.90, darkGreen: 0.91, darkBlue: 0.93)
    }

    static var rossAccent: Color {
        dynamicColor(lightRed: 0.18, lightGreen: 0.22, lightBlue: 0.40,
                     darkRed: 0.58, darkGreen: 0.64, darkBlue: 0.78)
    }

    static var rossHighlight: Color {
        dynamicColor(lightRed: 0.78, lightGreen: 0.68, lightBlue: 0.48,
                     darkRed: 0.74, darkGreen: 0.68, darkBlue: 0.56)
    }

    static var rossSuccess: Color {
        dynamicColor(lightRed: 0.15, lightGreen: 0.35, lightBlue: 0.25,
                     darkRed: 0.46, darkGreen: 0.72, darkBlue: 0.58)
    }

    static var rossChromeBackground: Color {
        dynamicColor(lightRed: 0.06, lightGreen: 0.08, lightBlue: 0.12,
                     darkRed: 0.08, darkGreen: 0.09, darkBlue: 0.11)
    }
    
    // Backgrounds for Hero
    static var rossHeroTop: Color {
        dynamicColor(lightRed: 0.98, lightGreen: 0.97, lightBlue: 0.95,
                     darkRed: 0.12, darkGreen: 0.13, darkBlue: 0.15)
    }

    static var rossHeroBottom: Color {
        dynamicColor(lightRed: 0.93, lightGreen: 0.92, lightBlue: 0.89,
                     darkRed: 0.08, darkGreen: 0.09, darkBlue: 0.10)
    }

    static var rossGlassFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.16, darkGreen: 0.17, darkBlue: 0.19,
            lightAlpha: 0.74,
            darkAlpha: 0.80
        )
    }

    static var rossGlassSubtleFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.19, darkGreen: 0.20, darkBlue: 0.22,
            lightAlpha: 0.56,
            darkAlpha: 0.70
        )
    }

    static var rossGlassStroke: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.86, darkGreen: 0.88, darkBlue: 0.92,
            lightAlpha: 0.64,
            darkAlpha: 0.18
        )
    }

    static var rossBackdropGlow: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.50, darkGreen: 0.54, darkBlue: 0.62,
            lightAlpha: 0.62,
            darkAlpha: 0.08
        )
    }

    static var rossShadow: Color {
        dynamicColor(
            lightRed: 0.04, lightGreen: 0.06, lightBlue: 0.1,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.16,
            darkAlpha: 0.18
        )
    }

    static var rossScrim: Color {
        dynamicColor(
            lightRed: 0, lightGreen: 0, lightBlue: 0,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.16,
            darkAlpha: 0.28
        )
    }
    
    // Gradients
    static var rossPillGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamicColor(
                    lightRed: 0.20, lightGreen: 0.25, lightBlue: 0.45,
                    darkRed: 0.34, darkGreen: 0.40, darkBlue: 0.56
                ),
                dynamicColor(
                    lightRed: 0.15, lightGreen: 0.18, lightBlue: 0.35,
                    darkRed: 0.23, darkGreen: 0.27, darkBlue: 0.39
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
            darkAlpha: 0.12
        )
    }

    static var rossCardBackground: Color {
        dynamicColor(lightRed: 1, lightGreen: 1, lightBlue: 1,
                     darkRed: 0.14, darkGreen: 0.15, darkBlue: 0.17)
    }

    static var rossGroupedBackground: Color {
        dynamicColor(lightRed: 0.97, lightGreen: 0.97, lightBlue: 0.98,
                     darkRed: 0.08, darkGreen: 0.085, darkBlue: 0.10)
    }

    static var rossSecondaryGroupedBackground: Color {
        dynamicColor(lightRed: 0.95, lightGreen: 0.95, lightBlue: 0.97,
                     darkRed: 0.12, darkGreen: 0.125, darkBlue: 0.145)
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
