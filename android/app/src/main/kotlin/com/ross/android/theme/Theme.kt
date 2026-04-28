package com.ross.android.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = RossAccent,
    onPrimary = RossLightSurface,
    primaryContainer = RossLightSurfaceVariant,
    onPrimaryContainer = RossAccent,
    secondary = RossHighlight,
    onSecondary = RossWhite,
    secondaryContainer = RossLightSurfaceVariant,
    onSecondaryContainer = RossAccent,
    tertiary = RossSuccess,
    onTertiary = RossWhite,
    background = RossOffWhite,
    onBackground = RossInk,
    surface = RossLightSurface,
    onSurface = RossInk,
    surfaceVariant = RossLightSurfaceVariant,
    onSurfaceVariant = RossTextMuted,
    outline = RossBorderLight,
    outlineVariant = RossBorderLight,
    surfaceTint = RossAccent,
)

private val DarkColors = darkColorScheme(
    primary = RossAccentDark,
    onPrimary = RossRuinedSmores,
    primaryContainer = RossDarkSurfaceVariant,
    onPrimaryContainer = RossInkDark,
    secondary = RossHighlightDark,
    onSecondary = RossRuinedSmores,
    secondaryContainer = RossDarkSurfaceVariant,
    onSecondaryContainer = RossInkDark,
    tertiary = RossSuccessDark,
    onTertiary = RossRuinedSmores,
    background = RossDarkBg,
    onBackground = RossInkDark,
    surface = RossDarkSurface,
    onSurface = RossInkDark,
    surfaceVariant = RossDarkSurfaceVariant,
    onSurfaceVariant = RossChromeChalice,
    outline = RossBorderDark,
    outlineVariant = RossTamahagane,
    surfaceTint = RossAccentDark,
)

@Composable
fun RossTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = RossTypography,
        content = content,
    )
}
