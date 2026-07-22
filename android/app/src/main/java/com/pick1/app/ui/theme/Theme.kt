package com.pick1.app.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

/**
 * Pick1 is a dark-only app on iOS (the design has no light variant), so the
 * Android theme pins the dark scheme regardless of system setting — matching
 * what users see on iPhone.
 */
private val Pick1ColorScheme = darkColorScheme(
    primary = P1.Lime,
    onPrimary = P1.LimeInk,
    secondary = P1.Lime,
    onSecondary = P1.LimeInk,
    background = P1.Ink,
    onBackground = P1.Foreground,
    surface = P1.Panel,
    onSurface = P1.Foreground,
    surfaceVariant = P1.Panel2,
    onSurfaceVariant = P1.Ink2,
    outline = P1.Line,
    error = P1.Loss,
    onError = P1.Foreground,
)

@Composable
fun Pick1Theme(
    @Suppress("UNUSED_PARAMETER") darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            // Edge-to-edge with light icons on the near-black background,
            // mirroring the iOS status-bar treatment.
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = Pick1ColorScheme,
        typography = MaterialTheme.typography,   // per-call styles come from Type.kt
        content = content,
    )
}
