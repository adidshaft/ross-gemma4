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

    // Ross muted green-black palette
    static var rossInk: Color {
        dynamicColor(lightRed: 0.043, lightGreen: 0.071, lightBlue: 0.071,
                     darkRed: 0.93, darkGreen: 0.92, darkBlue: 0.95)
    }

    static var rossAccent: Color {
        dynamicColor(lightRed: 0.165, lightGreen: 0.188, lightBlue: 0.180,
                     darkRed: 0.800, darkGreen: 0.792, darkBlue: 0.820)
    }

    static var rossHighlight: Color {
        dynamicColor(lightRed: 0.376, lightGreen: 0.396, lightBlue: 0.396,
                     darkRed: 0.800, darkGreen: 0.792, darkBlue: 0.820)
    }

    static var rossSuccess: Color {
        dynamicColor(lightRed: 0.227, lightGreen: 0.251, lightBlue: 0.243,
                     darkRed: 0.63, darkGreen: 0.73, darkBlue: 0.68)
    }

    static var rossChromeBackground: Color {
        dynamicColor(lightRed: 0.227, lightGreen: 0.251, lightBlue: 0.243,
                     darkRed: 0.043, darkGreen: 0.071, darkBlue: 0.071)
    }
    
    // Backgrounds for Hero
    static var rossHeroTop: Color {
        dynamicColor(lightRed: 0.965, lightGreen: 0.961, lightBlue: 0.973,
                     darkRed: 0.106, darkGreen: 0.133, darkBlue: 0.125)
    }

    static var rossHeroBottom: Color {
        dynamicColor(lightRed: 0.906, lightGreen: 0.902, lightBlue: 0.918,
                     darkRed: 0.043, darkGreen: 0.071, darkBlue: 0.071)
    }

    static var rossGlassFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.106, darkGreen: 0.133, darkBlue: 0.125,
            lightAlpha: 0.74,
            darkAlpha: 0.84
        )
    }

    static var rossGlassSubtleFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.165, darkGreen: 0.188, darkBlue: 0.180,
            lightAlpha: 0.56,
            darkAlpha: 0.72
        )
    }

    static var rossGlassStroke: Color {
        dynamicColor(
            lightRed: 0.376, lightGreen: 0.396, lightBlue: 0.396,
            darkRed: 0.800, darkGreen: 0.792, darkBlue: 0.820,
            lightAlpha: 0.20,
            darkAlpha: 0.18
        )
    }

    static var rossBackdropGlow: Color {
        dynamicColor(
            lightRed: 0.800, lightGreen: 0.792, lightBlue: 0.820,
            darkRed: 0.376, darkGreen: 0.396, darkBlue: 0.396,
            lightAlpha: 0.52,
            darkAlpha: 0.16
        )
    }

    static var rossShadow: Color {
        dynamicColor(
            lightRed: 0.043, lightGreen: 0.071, lightBlue: 0.071,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.18,
            darkAlpha: 0.28
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
                    lightRed: 0.227, lightGreen: 0.251, lightBlue: 0.243,
                    darkRed: 0.376, darkGreen: 0.396, darkBlue: 0.396
                ),
                dynamicColor(
                    lightRed: 0.043, lightGreen: 0.071, lightBlue: 0.071,
                    darkRed: 0.227, darkGreen: 0.251, darkBlue: 0.243
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var rossBorder: Color {
        dynamicColor(
            lightRed: 0.376, lightGreen: 0.396, lightBlue: 0.396,
            darkRed: 0.800, darkGreen: 0.792, darkBlue: 0.820,
            lightAlpha: 0.18,
            darkAlpha: 0.14
        )
    }

    static var rossCardBackground: Color {
        dynamicColor(lightRed: 0.984, lightGreen: 0.980, lightBlue: 0.992,
                     darkRed: 0.106, darkGreen: 0.133, darkBlue: 0.125)
    }

    static var rossGroupedBackground: Color {
        dynamicColor(lightRed: 0.965, lightGreen: 0.961, lightBlue: 0.973,
                     darkRed: 0.043, darkGreen: 0.071, darkBlue: 0.071)
    }

    static var rossSecondaryGroupedBackground: Color {
        dynamicColor(lightRed: 0.925, lightGreen: 0.922, lightBlue: 0.941,
                     darkRed: 0.165, darkGreen: 0.188, darkBlue: 0.180)
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
