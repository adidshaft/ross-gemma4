package com.privatedigitalclerk.android.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = InkBlue,
    onPrimary = Chalk,
    primaryContainer = Stone,
    onPrimaryContainer = InkBlue,
    secondary = Brass,
    onSecondary = Chalk,
    secondaryContainer = Paper,
    onSecondaryContainer = InkBlue,
    tertiary = LedgerGreen,
    onTertiary = Chalk,
    background = Chalk,
    onBackground = InkBlue,
    surface = Paper,
    onSurface = InkBlue,
    surfaceVariant = Stone,
    onSurfaceVariant = Slate,
    outline = CourtBlue,
)

private val DarkColors = darkColorScheme(
    primary = Stone,
    onPrimary = Night,
    primaryContainer = CourtBlue,
    onPrimaryContainer = Chalk,
    secondary = WarmGray,
    onSecondary = Night,
    secondaryContainer = Brass,
    onSecondaryContainer = Chalk,
    tertiary = LedgerGreen,
    onTertiary = Chalk,
    background = Night,
    onBackground = Chalk,
    surface = NightPanel,
    onSurface = Chalk,
    surfaceVariant = CourtBlue,
    onSurfaceVariant = WarmGray,
    outline = WarmGray,
)

@Composable
fun PrivateDigitalClerkTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = PrivateDigitalClerkTypography,
        content = content,
    )
}
