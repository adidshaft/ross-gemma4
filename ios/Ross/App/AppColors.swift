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

    // MARK: - Core Palette (iOS 26 Liquid Glass inspired — deeper, more luminous)
    
    /// Near-black in light, near-white in dark — primary text and foreground
    static var rossInk: Color {
        dynamicColor(lightRed: 0.032, lightGreen: 0.052, lightBlue: 0.062,
                     darkRed: 0.96, darkGreen: 0.955, darkBlue: 0.975)
    }

    /// Muted midtone — secondary text, tinted glass surfaces
    static var rossAccent: Color {
        dynamicColor(lightRed: 0.18, lightGreen: 0.20, lightBlue: 0.22,
                     darkRed: 0.78, darkGreen: 0.80, darkBlue: 0.84)
    }

    static var rossHighlight: Color {
        dynamicColor(lightRed: 0.36, lightGreen: 0.40, lightBlue: 0.44,
                     darkRed: 0.72, darkGreen: 0.76, darkBlue: 0.82)
    }

    static var rossSuccess: Color {
        dynamicColor(lightRed: 0.18, lightGreen: 0.52, lightBlue: 0.36,
                     darkRed: 0.28, darkGreen: 0.80, darkBlue: 0.56)
    }

    static var rossChromeBackground: Color {
        dynamicColor(lightRed: 0.98, lightGreen: 0.975, lightBlue: 0.99,
                     darkRed: 0.045, darkGreen: 0.048, darkBlue: 0.055)
    }

    // MARK: - Hero Background Gradient (richer, more saturated sky-to-depth)
    static var rossHeroTop: Color {
        dynamicColor(lightRed: 0.96, lightGreen: 0.958, lightBlue: 0.974,
                     darkRed: 0.09, darkGreen: 0.10, darkBlue: 0.14)
    }

    static var rossHeroBottom: Color {
        dynamicColor(lightRed: 0.905, lightGreen: 0.900, lightBlue: 0.928,
                     darkRed: 0.035, darkGreen: 0.038, darkBlue: 0.052)
    }

    // MARK: - Glass Surfaces (iOS 26: true lens-on-glass layering, more luminous)
    
    /// Primary glass fill — bright inner surface, optically floating
    static var rossGlassFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.14, darkGreen: 0.148, darkBlue: 0.18,
            lightAlpha: 0.82,
            darkAlpha: 0.78
        )
    }

    /// Subtle secondary glass fill — nested glass within glass
    static var rossGlassSubtleFill: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 0.18, darkGreen: 0.19, darkBlue: 0.24,
            lightAlpha: 0.60,
            darkAlpha: 0.62
        )
    }

    /// Glass edge stroke — crisp specular highlight on lens boundary
    static var rossGlassStroke: Color {
        dynamicColor(
            lightRed: 1, lightGreen: 1, lightBlue: 1,
            darkRed: 1, darkGreen: 1, darkBlue: 1,
            lightAlpha: 0.46,
            darkAlpha: 0.14
        )
    }

    /// Soft ambient glow behind floating surfaces
    static var rossBackdropGlow: Color {
        dynamicColor(
            lightRed: 0.70, lightGreen: 0.68, lightBlue: 0.88,
            darkRed: 0.35, darkGreen: 0.38, darkBlue: 0.55,
            lightAlpha: 0.38,
            darkAlpha: 0.22
        )
    }

    // MARK: - Shadow & Scrim
    static var rossShadow: Color {
        dynamicColor(
            lightRed: 0.10, lightGreen: 0.12, lightBlue: 0.20,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.14,
            darkAlpha: 0.36
        )
    }

    static var rossScrim: Color {
        dynamicColor(
            lightRed: 0, lightGreen: 0, lightBlue: 0,
            darkRed: 0, darkGreen: 0, darkBlue: 0,
            lightAlpha: 0.18,
            darkAlpha: 0.30
        )
    }

    // MARK: - Gradients
    
    /// Primary action gradient — rich dark-to-mid, lens-glass feel
    static var rossPillGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamicColor(
                    lightRed: 0.18, lightGreen: 0.22, lightBlue: 0.28,
                    darkRed: 0.50, darkGreen: 0.54, darkBlue: 0.62
                ),
                dynamicColor(
                    lightRed: 0.08, lightGreen: 0.10, lightBlue: 0.14,
                    darkRed: 0.28, darkGreen: 0.30, darkBlue: 0.38
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Structural Borders
    static var rossBorder: Color {
        dynamicColor(
            lightRed: 0.32, lightGreen: 0.35, lightBlue: 0.42,
            darkRed: 0.78, darkGreen: 0.80, darkBlue: 0.88,
            lightAlpha: 0.14,
            darkAlpha: 0.12
        )
    }

    // MARK: - Card & Grouped Backgrounds
    static var rossCardBackground: Color {
        dynamicColor(lightRed: 0.992, lightGreen: 0.988, lightBlue: 0.998,
                     darkRed: 0.11, darkGreen: 0.118, darkBlue: 0.148)
    }

    static var rossGroupedBackground: Color {
        dynamicColor(lightRed: 0.962, lightGreen: 0.958, lightBlue: 0.975,
                     darkRed: 0.038, darkGreen: 0.040, darkBlue: 0.052)
    }

    static var rossSecondaryGroupedBackground: Color {
        dynamicColor(lightRed: 0.920, lightGreen: 0.915, lightBlue: 0.940,
                     darkRed: 0.16, darkGreen: 0.168, darkBlue: 0.208)
    }
}

// MARK: - View Helpers

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
