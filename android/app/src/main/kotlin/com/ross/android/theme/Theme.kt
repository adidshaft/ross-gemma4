package com.ross.android.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = RossAccent,
    onPrimary = RossWhite,
    primaryContainer = RossOffWhite,
    onPrimaryContainer = RossAccent,
    secondary = RossHighlight,
    onSecondary = RossWhite,
    secondaryContainer = RossOffWhite,
    onSecondaryContainer = RossHighlight,
    tertiary = RossSuccess,
    onTertiary = RossWhite,
    background = RossWhite,
    onBackground = RossInk,
    surface = RossWhite,
    onSurface = RossInk,
    surfaceVariant = RossOffWhite,
    onSurfaceVariant = RossTextMuted,
    outline = RossBorderLight,
)

private val DarkColors = darkColorScheme(
    primary = RossAccentDark,
    onPrimary = RossWhite,
    primaryContainer = RossDarkSurface,
    onPrimaryContainer = RossWhite,
    secondary = RossHighlightDark,
    onSecondary = RossWhite,
    secondaryContainer = RossDarkSurface,
    onSecondaryContainer = RossHighlightDark,
    tertiary = RossSuccessDark,
    onTertiary = RossWhite,
    background = RossDarkBg,
    onBackground = RossWhite,
    surface = RossDarkBg,
    onSurface = RossWhite,
    surfaceVariant = RossDarkSurface,
    onSurfaceVariant = Color(0xFFA1A1AA),
    outline = RossBorderDark,
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
