package com.pick1.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.pick1.app.R

/**
 * Pick1 type stack — a port of the `Font` extension in `Pick1HomeHiFi.swift`.
 *
 * iOS exposes four helpers; each maps to a family below:
 *   .anton(size)                  → [Anton]         display / scoreboard numerals
 *   .archivo(size, weight)        → [Archivo]       body copy
 *   .archivoNarrow(size, weight)  → [ArchivoNarrow] condensed caps labels
 *   .mono(size, weight)           → [JetBrainsMono] stats / tickers
 *
 * The same .ttf files ship on both platforms, so glyphs are identical.
 */

val Anton = FontFamily(Font(R.font.anton_regular, FontWeight.Normal))

val Archivo = FontFamily(
    Font(R.font.archivo_regular,   FontWeight.Normal),
    Font(R.font.archivo_medium,    FontWeight.Medium),
    Font(R.font.archivo_semibold,  FontWeight.SemiBold),
    Font(R.font.archivo_bold,      FontWeight.Bold),
    Font(R.font.archivo_extrabold, FontWeight.ExtraBold),
    Font(R.font.archivo_black,     FontWeight.Black),
)

val ArchivoNarrow = FontFamily(
    Font(R.font.archivo_narrow_medium,   FontWeight.Medium),
    Font(R.font.archivo_narrow_semibold, FontWeight.SemiBold),
    Font(R.font.archivo_narrow_bold,     FontWeight.Bold),
)

val JetBrainsMono = FontFamily(
    Font(R.font.jetbrains_mono_regular,   FontWeight.Normal),
    Font(R.font.jetbrains_mono_medium,    FontWeight.Medium),
    Font(R.font.jetbrains_mono_bold,      FontWeight.Bold),
    Font(R.font.jetbrains_mono_extrabold, FontWeight.ExtraBold),
)

/**
 * Call-site helpers so Compose code reads like the SwiftUI it mirrors:
 *   Text("PICK1", style = anton(34))
 *   Text(label, style = archivoNarrow(10, FontWeight.Bold, tracking = 2.2f))
 *
 * `tracking` is iOS's `.tracking()` — Compose calls it letterSpacing and
 * takes it in sp, which matches SwiftUI's point-based tracking 1:1.
 */
fun anton(size: Int, tracking: Float = 0f): TextStyle = TextStyle(
    fontFamily = Anton,
    fontWeight = FontWeight.Normal,
    fontSize = size.sp,
    letterSpacing = tracking.sp,
)

fun archivo(
    size: Int,
    weight: FontWeight = FontWeight.Normal,
    tracking: Float = 0f,
): TextStyle = TextStyle(
    fontFamily = Archivo,
    fontWeight = weight,
    fontSize = size.sp,
    letterSpacing = tracking.sp,
)

fun archivoNarrow(
    size: Int,
    weight: FontWeight = FontWeight.SemiBold,
    tracking: Float = 0f,
): TextStyle = TextStyle(
    fontFamily = ArchivoNarrow,
    fontWeight = weight,
    fontSize = size.sp,
    letterSpacing = tracking.sp,
)

fun mono(
    size: Int,
    weight: FontWeight = FontWeight.Bold,
    tracking: Float = 0f,
): TextStyle = TextStyle(
    fontFamily = JetBrainsMono,
    fontWeight = weight,
    fontSize = size.sp,
    letterSpacing = tracking.sp,
)

/** Convenience for the many `.sp` literals ported from CGFloat sizes. */
internal val Int.spx: TextUnit get() = this.sp
